#!/usr/bin/env bash
# Offline test for bee-context-nudge, every sub-agent's PostToolUse context hook. Each case builds
# a project dir with a main transcript and <sid>/subagents/agent-<id>.jsonl in the real shape (several
# lines per message.id, one repeated usage), pipes a hook input to the script with its own TMPDIR and
# asserts the exact hookSpecificOutput. Lock cases hold the per-agent lock from a helper process that
# signals ready and waits for release over fifos, never sleeps.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/../scripts/bee-context-nudge"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail=0

new_case() { # new_case <name>: fresh project dir, session id and TMPDIR
  case_dir="$TMP/$1"; sid="sid-$1"; msg=0
  mkdir -p "$case_dir/proj/$sid/subagents" "$case_dir/tmp"
  : > "$case_dir/proj/$sid.jsonl"
}
respond() { # respond <agent> <context> [lines]: one API response spread over [lines] lines, then its tool result
  local f="$case_dir/proj/$sid/subagents/agent-$1.jsonl" i
  msg=$((msg + 1))
  for ((i = 0; i < ${3:-2}; i++)); do
    jq -nc --arg a "$1" --arg s "$sid" --arg m "msg_$msg" --argjson c "$2" '{type: "assistant", isSidechain: true,
      agentId: $a, sessionId: $s, message: {id: $m, role: "assistant", content: [{type: "text", text: "step"}],
      usage: {input_tokens: 3, cache_creation_input_tokens: 1000, cache_read_input_tokens: ($c - 1003), output_tokens: 40}}}'
  done >> "$f"
  jq -nc --arg a "$1" --arg s "$sid" '{type: "user", isSidechain: true, agentId: $a, sessionId: $s,
    message: {role: "user", content: [{type: "tool_result", tool_use_id: "toolu_1", content: "ok"}]}}' >> "$f"
}
call() { # call <agent|""> [VAR=value …]: runs the hook; sets $out and $code
  local agent=$1; shift
  out=$(jq -nc --arg s "$sid" --arg t "$case_dir/proj/$sid.jsonl" --arg a "$agent" '{session_id: $s, transcript_path: $t,
      cwd: "/tmp", hook_event_name: "PostToolUse", tool_name: "Read", tool_input: {}, tool_response: {}}
      + if $a == "" then {} else {agent_id: $a, agent_type: "bee-opus-low"} end' \
    | env TMPDIR="$case_dir/tmp" "$@" "$SCRIPT" 2>&1); code=$?
}
warn() { jq -nc --arg t "Context at $1k: finish the current step; if more than a few steps of your task remain, plan to stop at $2k." \
  '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $t}}'; }
pause() { jq -nc --arg t "Context at $1k: stop at the next safe point and return what is done and what remains, or pause as your standing rules say if you have them." \
  '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $t}}'; }
expect() { # expect <label> <want-json|"">: compares the last call's output and exit 0
  local got; got=$(jq -c . <<<"$out" 2>/dev/null || echo "$out")
  if [[ $code == 0 && $got == "$2" ]]; then echo "ok   $1"
  else echo "FAIL $1 (exit $code): got '${out}' want '$2'"; fail=1; fi
}
state() { (cd "$case_dir/tmp" && for f in *; do [ -f "$f" ] && printf '%s\n' "$f" && cat "$f"; done); }
lock_file() { echo "$case_dir/tmp/bee-context-nudge-$sid-$1.lock"; }
hold_lock() { # hold_lock <agent> [exit]: helper takes the lock, signals ready, then exits at once or on release
  local release="$case_dir/release"
  mkfifo "$case_dir/ready"; if [ "${2:-}" = exit ]; then release=/dev/null; else mkfifo "$release"; fi
  python3 -c 'import fcntl, sys
f = open(sys.argv[1], "a"); fcntl.flock(f, fcntl.LOCK_EX)
open(sys.argv[2], "w").write("ready\n"); open(sys.argv[3]).read()' "$(lock_file "$1")" "$case_dir/ready" "$release" &
  holder=$!
  read -r _ < "$case_dir/ready"
}

new_case orchestrator; respond A 230000
call ""; expect orchestrator ""

new_case no-transcript
call A; expect no-transcript ""
if [ -z "$(ls -A "$case_dir/tmp")" ]; then echo "ok   no-transcript no state file"; else echo "FAIL no-transcript left $(ls "$case_dir/tmp")"; fail=1; fi

new_case boundaries
respond A 184000; call A; expect "dry-run 184k" ""
respond A 184999; call A; expect "boundaries 184,999" ""
respond A 185000; call A; expect "boundaries 185,000" "$(warn 185 220)"
respond A 219999; call A; expect "boundaries 219,999" ""
respond A 220000; call A; expect "boundaries 220,000" "$(pause 220)"

new_case one-response
respond A 200000 3; call A; expect one-response "$(warn 200 220)"

new_case warn-once
respond A 200000; call A; expect "warn-once first" "$(warn 200 220)"
respond A 200000; call A; expect "warn-once second" ""

new_case pause-once
respond A 200000; call A; expect "pause-once 200k" "$(warn 200 220)"
respond A 230000; call A; expect "pause-once 230k" "$(pause 230)"
respond A 230000; call A; expect "pause-once 230k again" ""

new_case jump
respond A 230000; call A; expect "jump first" "$(pause 230)"
respond A 230000; call A; expect "jump second" ""

new_case lagging
respond A 140000; call A; expect "lagging 140k" ""
respond A 200000; call A; expect "lagging 200k" "$(warn 200 220)"

new_case per-agent
respond A 230000; respond B 200000
call A; expect "per-agent A" "$(pause 230)"
call B; expect "per-agent B" "$(warn 200 220)"

new_case thresholds
respond A 40000; call A BEE_NUDGE_WARN=30000 BEE_NUDGE_PAUSE=45000; expect thresholds "$(warn 40 45)"

new_case owner-exited
respond A 230000; hold_lock A exit; wait "$holder"
call A; expect "owner-exited next call" "$(pause 230)"
call A; expect "owner-exited later call" ""

new_case owner-running
respond A 230000; hold_lock A
before=$(state); call A; expect owner-running ""
if [ "$(state)" == "$before" ]; then echo "ok   owner-running state unchanged"; else echo "FAIL owner-running changed state"; fail=1; fi
echo > "$case_dir/release"; wait "$holder"

new_case contended
respond A 230000; hold_lock A
call A; expect "contended first" ""
call A; expect "contended second" ""
echo > "$case_dir/release"; wait "$holder"
call A; expect "contended after release" "$(pause 230)"
call A; expect "contended later" ""

new_case no-warn-after-pause
respond A 230000; call A; expect "no-warn-after-pause pause" "$(pause 230)"
respond A 200000; call A; expect "no-warn-after-pause 200k" ""

# SA-02 contract: the hook's pause text defers to the standing rules and names no role's outcome, so
# every implementor brief must define a hook-triggered pause with Outcome: Handoff and a handoff BEES
# entry, and no context figure.
printf '# P\n\n### X-01 · unit\n\nBody.\n' > "$TMP/plan.md"
pause_text=$(pause 200 | jq -r .hookSpecificOutput.additionalContext)
for kind in impl fix; do
  if [ $kind == impl ]; then where=(--plan "$TMP/plan.md"); in="Objective: contract."
  else where=(--work "$TMP/plan.work"); in=$'Fixes: x\nFilter: f\nReview: r'; fi
  printf '%s\n' "$in" | "$here/../scripts/bees-brief" "${where[@]}" --units X-01 --kind $kind >/dev/null
  brief="$TMP/plan.work/brief-X-01-$kind-r1.txt"
  missing=""
  [[ $pause_text == *"your standing rules"* && $pause_text != *"Outcome"* ]] || missing+=" hook-text"
  grep -q "^Standing rules:" "$brief" || missing+=" standing-rules"
  tr '\n' ' ' < "$brief" | grep -q 'When the context hook tells you to pause, .*report `Outcome: Handoff`, end with `BEES: results=<unit>:handoff:<handoff file>' || missing+=" hook-pause"
  if grep -Eo '[0-9]+k\b' "$brief"; then missing+=" context-figure"; fi
  if [ -z "$missing" ]; then echo "ok   brief-contract $kind"; else echo "FAIL brief-contract $kind:$missing"; fail=1; fi
done
echo "Objective: run." | "$here/../scripts/bees-brief" --work "$TMP/plan.work" --units X-01 --kind run >/dev/null
brief="$TMP/plan.work/brief-X-01-run-r1.txt"
if [ "$(tail -n +2 "$brief" | sed '1,/^$/d')" == "$(cat "$here/../../codex-implementor/templates/run-contract.md")" ] && ! grep -q "When the context hook tells you to pause" "$brief"; then
  echo "ok   brief-contract run is the shared run contract"; else echo "FAIL brief-contract run"; fail=1; fi

exit $fail
