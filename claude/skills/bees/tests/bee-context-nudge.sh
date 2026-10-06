#!/usr/bin/env bash
# Offline test for bee-context-nudge, the implementor bees' PostToolUse context hook. Each case builds
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
warn() { jq -nc --arg t "Context at $1k: finish the current step; if more than a few steps of this unit remain, plan to pause at $2k." \
  '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $t}}'; }
pause() { jq -nc --arg t "Context at $1k: stop at the next safe point and pause per your standing rules (Outcome: Paused)." \
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

new_case orchestrator; respond A 210000
call ""; expect orchestrator ""

new_case no-transcript
call A; expect no-transcript ""
if [ -z "$(ls -A "$case_dir/tmp")" ]; then echo "ok   no-transcript no state file"; else echo "FAIL no-transcript left $(ls "$case_dir/tmp")"; fail=1; fi

new_case boundaries
respond A 149999; call A; expect "boundaries 149,999" ""
respond A 150000; call A; expect "boundaries 150,000" "$(warn 150 200)"
respond A 199999; call A; expect "boundaries 199,999" ""
respond A 200000; call A; expect "boundaries 200,000" "$(pause 200)"

new_case one-response
respond A 160000 3; call A; expect one-response "$(warn 160 200)"

new_case warn-once
respond A 160000; call A; expect "warn-once first" "$(warn 160 200)"
respond A 160000; call A; expect "warn-once second" ""

new_case pause-once
respond A 160000; call A; expect "pause-once 160k" "$(warn 160 200)"
respond A 210000; call A; expect "pause-once 210k" "$(pause 210)"
respond A 210000; call A; expect "pause-once 210k again" ""

new_case jump
respond A 210000; call A; expect "jump first" "$(pause 210)"
respond A 210000; call A; expect "jump second" ""

new_case lagging
respond A 140000; call A; expect "lagging 140k" ""
respond A 160000; call A; expect "lagging 160k" "$(warn 160 200)"

new_case per-agent
respond A 210000; respond B 160000
call A; expect "per-agent A" "$(pause 210)"
call B; expect "per-agent B" "$(warn 160 200)"

new_case thresholds
respond A 40000; call A BEE_NUDGE_WARN=30000 BEE_NUDGE_PAUSE=45000; expect thresholds "$(warn 40 45)"

new_case owner-exited
respond A 210000; hold_lock A exit; wait "$holder"
call A; expect "owner-exited next call" "$(pause 210)"
call A; expect "owner-exited later call" ""

new_case owner-running
respond A 210000; hold_lock A
before=$(state); call A; expect owner-running ""
if [ "$(state)" == "$before" ]; then echo "ok   owner-running state unchanged"; else echo "FAIL owner-running changed state"; fail=1; fi
echo > "$case_dir/release"; wait "$holder"

new_case contended
respond A 210000; hold_lock A
call A; expect "contended first" ""
call A; expect "contended second" ""
echo > "$case_dir/release"; wait "$holder"
call A; expect "contended after release" "$(pause 210)"
call A; expect "contended later" ""

new_case no-warn-after-pause
respond A 210000; call A; expect "no-warn-after-pause pause" "$(pause 210)"
respond A 160000; call A; expect "no-warn-after-pause 160k" ""

exit $fail
