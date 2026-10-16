#!/usr/bin/env bash
# Offline test for bee-scout-nudge, the implementor and advisor PostToolUse scout reminder: each case
# pipes a sequence of tool calls for one agent with its own TMPDIR and asserts which call nudges, and
# whether as a search or a failure-read reminder.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/../scripts/bee-scout-nudge"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail=0
n=0

call() { # call <agent|""> <tool> <input-json>: prints quiet, search or failures
  local out
  out=$(jq -nc --arg a "$1" --arg t "$2" --argjson i "$3" '{session_id: "s", hook_event_name: "PostToolUse",
      tool_name: $t, tool_input: $i} + if $a == "" then {} else {agent_id: $a} end' \
    | TMPDIR="$TMP" "$SCRIPT" 2>&1) || { echo "exit $?: $out"; return; }
  case "$out" in
    "") echo quiet ;;
    *"a run's failures"*) echo failures ;;
    *"searches or long reads"*) echo search ;;
    *) echo "garbage: $out" ;;
  esac
}
bash_() { jq -nc --arg c "$1" '{command: $c}'; }
expect() { # expect <label> <want…>: runs the queued calls of a fresh agent and compares their verdicts
  local label=$1; shift
  n=$((n + 1)); local got=() i
  for ((i = 0; i < ${#calls[@]}; i += 2)); do got+=("$(call "a$n" "${calls[i]}" "${calls[i + 1]}")"); done
  if [[ "${got[*]}" == "$*" ]]; then echo "ok   $label"; else echo "FAIL $label: got [${got[*]}] want [$*]"; fail=1; fi
}

GREP=$(bash_ 'cd lane && grep -rn "class Foo" --include=*.cs .')
SHORT=$(bash_ "sed -n 10,40p Editor/Foo.cs")
LONG=$(bash_ "sed -n 1,330p Tests/FooTests.cs")
DOC=$(bash_ "cat docs/plans/plan.work/brief-U-01-impl-r1.txt")
CAT=$(bash_ "cat -n Tests/Facade/UIPipeline.cs")
XML=$(bash_ "grep '^FAIL' /tmp/run.log | head")
RUN=$(bash_ "unity-suite GameCore --filter FooTests > /tmp/run.log; grep -c Logs/U-01.xml")
AGENT='{"description": "scout"}'

[[ $(call "" Grep '{}') == quiet ]] && echo "ok   no agent_id is quiet" || { echo "FAIL no agent_id"; fail=1; }
calls=(Bash "$GREP" Grep '{}' Glob '{}' Bash "$GREP"); expect "every third search nudges" quiet quiet search quiet
calls=(Bash "$GREP" Bash "$GREP" Agent "$AGENT" Bash "$GREP" Bash "$GREP"); expect "a scout restarts the count" quiet quiet quiet quiet quiet
calls=(Bash "$SHORT" Bash "$DOC" Read '{"file_path": "a/Foo.cs", "limit": 40}' Bash "$LONG" Bash "$CAT"); expect "short reads and docs do not count" quiet quiet quiet quiet quiet
calls=(Bash "$LONG" Read '{"file_path": "a/Foo.cs"}' Bash "$CAT"); expect "long and whole reads of code count" quiet quiet search
calls=(Bash "$RUN" Bash "$XML" Bash "$XML" Agent "$AGENT" Bash "$XML"); expect "reading failures nudges once per scout, a run does not" quiet failures quiet quiet failures

exit $fail
