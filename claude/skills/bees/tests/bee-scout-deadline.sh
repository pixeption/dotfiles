#!/usr/bin/env bash
# Offline test for bee-scout-deadline, the scout's PreToolUse time-limit hook: each case pipes a hook
# input with its own TMPDIR and asserts allow (no output) or the deny decision. A deadline of 0 stands
# in for an expired clock, so no case sleeps.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/../scripts/bee-scout-deadline"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail=0

call() { # call <agent|""> [VAR=value …]: sets $out and $code
  local agent=$1; shift
  out=$(jq -nc --arg a "$agent" '{session_id: "s", hook_event_name: "PreToolUse", tool_name: "Grep", tool_input: {}}
      + if $a == "" then {} else {agent_id: $a, agent_type: "bee-scout"} end' \
    | env TMPDIR="$TMP" "$@" "$SCRIPT" 2>&1); code=$?
}
expect() { # expect <label> allow|deny
  local got=allow
  [[ $(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$out" 2>/dev/null) == deny ]] && got=deny
  [[ -n $out && $got == allow ]] && got="garbage: $out"
  if [[ $code == 0 && $got == "$2" ]]; then echo "ok   $1"; else echo "FAIL $1 (exit $code): got $got want $2"; fail=1; fi
}

call ""; expect "no agent_id" allow
call A; expect "within the limit" allow
call A BEE_SCOUT_DEADLINE=0; expect "past the limit" deny

exit $fail
