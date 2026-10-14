#!/usr/bin/env bash
# Offline test for context-nudge, the orchestrator's PostToolUse context hook. Each case writes a fake
# main-chain transcript with one assistant usage, pipes a hook input to the script with its own TMPDIR
# and asserts the exact hookSpecificOutput.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/../scripts/context-nudge"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail=0

new_case() { # new_case <name> <context>: fresh TMPDIR and a transcript whose last reading is <context>
  case_dir="$TMP/$1"; sid="sid-$1"
  mkdir -p "$case_dir/tmp"
  jq -nc --argjson c "$2" '{type: "assistant", message: {usage: {input_tokens: 3,
    cache_creation_input_tokens: 1000, cache_read_input_tokens: ($c - 1003), output_tokens: 40}}}' > "$case_dir/t.jsonl"
}
call() { # sets $out and $code
  out=$(jq -nc --arg s "$sid" --arg t "$case_dir/t.jsonl" '{session_id: $s, transcript_path: $t,
      hook_event_name: "PostToolUse", tool_name: "Read"}' | env TMPDIR="$case_dir/tmp" "$SCRIPT" 2>&1); code=$?
}
nudge() { jq -nc --arg t "Context at $1k: start nothing new, finish the running unit, then hand off per bees reference/handoff.md." \
  '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $t}}'; }
expect() { # expect <label> <want-json|"">
  local got; got=$(jq -c . <<<"$out" 2>/dev/null || echo "$out")
  if [[ $code == 0 && $got == "$2" ]]; then echo "ok   $1"
  else echo "FAIL $1 (exit $code): got '${out}' want '$2'"; fail=1; fi
}

new_case below 169999; call; expect "silent below the threshold" ""
new_case at 170000; call; expect "fires at the threshold" "$(nudge 170)"
call; expect "silent on a second call" ""

exit $fail
