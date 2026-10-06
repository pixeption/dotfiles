#!/usr/bin/env bash
# Offline test for bees-context-tally on fixtures in the real sub-agent transcript shape, built by
# fixtures/context-tally-build.py into a fresh project dir (<sid>/subagents/agent-<id>.jsonl):
#   adone   bee-opus-medium, done: three lines of one message.id, each read class and an unknown
#           read, a partial read, a heredoc write, an image result
#   aval    bee-opus-high: validation intervals with positive, explicit-zero and missing
#           thinking_tokens, and one with injected content of unknown size
#   alow    bee-opus-low: only an explicit-zero interval
#   aedge   bee-opus-low: an unresolved plan path, a read with no result, a two-file command, and
#           negative, NaN and Infinity thinking_tokens
#   apause  bee-opus-high, paused: the context hook's warn and pause texts
#   acomp   no .meta.json, a compaction, no BEES line
#   alate   a later unrelated run, first timestamp exactly 2026-10-03T00:00:00.000Z
#   aempty  (separate project) a run with no API response
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/../scripts/bees-context-tally"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
P="$TMP/proj"; P2="$TMP/proj2"
python3 "$here/fixtures/context-tally-build.py" "$P" "$P2" || { echo "FAIL fixture build"; exit 1; }

fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
eq() { # eq <name> <want> <got>
  if [ "$2" == "$3" ]; then ok "$1"; else bad "$1: want [$2] got [$3]"; fi
}
run() { "$SCRIPT" "$@" >"$TMP/out" 2>"$TMP/err"; }
rec() { grep '^{' "$TMP/out" | jq -c --arg a "$1" "select(.agent_id == \$a) | $2"; }
table_has() { if grep -qF -- "$2" "$TMP/out"; then ok "$1"; else bad "$1: no line [$2]"; fi; }

run "$P"; eq "scan exit" 0 $?
eq "scan runs" "acomp adone aedge alate alow apause aval" "$(grep '^{' "$TMP/out" | jq -r .agent_id | sort | tr '\n' ' ' | sed 's/ $//')"

eq "responses by message.id" 9 "$(rec adone .responses)"
eq "peak" 21000 "$(rec adone .peak_context)"
eq "cumulative" 149000 "$(rec adone .cumulative_context)"
eq "timestamps" '["2026-10-01T10:00:00.000Z","2026-10-01T10:01:40.000Z"]' "$(rec adone '[.first_ts, .last_ts]')"
eq "type model effort" '["bee-opus-medium","claude-opus-5-5","medium"]' "$(rec adone '[.agent_type, .model, .effort]')"
eq "outcome done" '"done"' "$(rec adone .outcome)"
eq "read skill entry" '{"count":2,"tokens":2000,"untokened":1}' "$(rec adone .reads.skill_entry)"
eq "read plan file" '{"count":2,"tokens":1000,"untokened":1}' "$(rec adone .reads.plan_file)"
eq "read saved output" '{"count":1,"tokens":500,"untokened":0}' "$(rec adone .reads.saved_output)"
eq "read unknown" '{"count":1,"tokens":200,"untokened":0}' "$(rec adone .reads.unknown)"
eq "image at token cost" 100 "$(rec adone .image_tokens)"
eq "no hook trace" '"unknown"' "$(rec adone .pause)"
eq "score not inferred" null "$(rec adone .score)"

eq "outcome paused" '"paused"' "$(rec apause .outcome)"
eq "pause overshoot" '{"reading":40000,"peak_after":48000,"overshoot":8000}' "$(rec apause .pause)"

eq "missing meta" '["unknown",null]' "$(rec acomp '[.agent_type, .effort]')"
eq "compaction" '[1,60000,127000]' "$(rec acomp '[.compactions, .peak_context, .cumulative_context]')"
eq "outcome unknown" '"unknown"' "$(rec acomp .outcome)"
eq "compaction interval excluded" 11000 "$(rec acomp .unattributed.growth)"

eq "residual (unattributed)" '{"growth":8100,"visible":5000,"residual":3100,"share":0.383,"per_thinking_response":1033}' \
  "$(rec aval '.unattributed | {growth, visible, residual, share, per_thinking_response}')"
eq "visible split" '{"own_inputs":21,"results":4979}' "$(rec aval '.unattributed | {own_inputs, results}')"
eq "validation intervals" '{"eligible":[[1000,1000],[600,400]],"controls":[0]}' "$(rec aval .validation)"
eq "unresolved path is unknown" '{"count":1,"tokens":100,"untokened":0}' "$(rec aedge .reads.unknown)"
eq "missing result and multi-file command untokened" '[{"count":2,"tokens":null,"untokened":2},{"count":1,"tokens":null,"untokened":1}]' \
  "$(rec aedge '[.reads.plan_file, .reads.skill_entry]')"
eq "negative, NaN, Infinity thinking are unknown" '{"eligible":[],"controls":[]}' "$(rec aedge .validation)"
eq "validation zero only" '{"eligible":[],"controls":[0]}' "$(rec alow .validation)"
table_has "validation table high" "| high | 2 | 1.12 | 1.25 | 1.38 | 1 | inconclusive |"
table_has "validation table low" "| low | 0 | - | - | - | 1 | inconclusive |"
table_has "peak table" "| bee-opus-high | 2 | 0 | 48k |"
if grep -qiE '\b(nan|inf|infinity)\b' "$TMP/out"; then bad "no NaN or infinity"; else ok "no NaN or infinity"; fi

run "$P" --since 2026-10-03T00:00:00Z
eq "since at boundary" alate "$(grep '^{' "$TMP/out" | jq -r .agent_id | tr '\n' ' ' | sed 's/ $//')"
run "$P" --since 2026-10-03T00:00:00.001Z
eq "since past boundary" 0 "$(grep -c '^{' "$TMP/out")"

H=$'session_id\tagent_id\tplan\tunit\tscore\tbase_commit\treview_rounds'
S1=11111111-1111-1111-1111-111111111111
printf '%s\n%s\t%s\t%s\n%s\t%s\t%s\n' "$H" "$S1" adone $'plan-a\tSA-05\t3\tabc1234\t1' "$S1" apause $'plan-a\tSA-01\t5\tdef5678\t2' > "$TMP/m.tsv"
run "$P" --manifest "$TMP/m.tsv"; eq "manifest exit" 0 $?
run "$P" --manifest "$TMP/m.tsv" --since 2026-10-01T00:00:00Z
eq "manifest with since rejected" "2 1" "$? $(grep -c -- '--manifest and --since are mutually exclusive' "$TMP/err")"
run "$P" --manifest "$TMP/m.tsv"
eq "manifest selects exactly" "adone apause" "$(grep '^{' "$TMP/out" | jq -r .agent_id | sort | tr '\n' ' ' | sed 's/ $//')"
eq "manifest join" '["plan-a","SA-01",5,"def5678",2]' "$(rec apause '[.plan, .unit, .score, .base_commit, .review_rounds]')"
{ cat "$TMP/m.tsv"; tail -1 "$TMP/m.tsv"; } > "$TMP/dup.tsv"
run "$P" --manifest "$TMP/dup.tsv"; eq "manifest duplicate fails" "1 1" "$? $(grep -ci duplicate "$TMP/err")"
{ cat "$TMP/m.tsv"; printf '%s\tanone\tplan-a\tSA-09\t2\tabc1234\t0\n' "$S1"; } > "$TMP/miss.tsv"
run "$P" --manifest "$TMP/miss.tsv"; eq "manifest missing transcript fails" "1 1" "$? $(grep -c anone "$TMP/err")"
printf '%s\n%s\taempty\tplan-a\tSA-09\t2\tabc1234\t0\n' "$H" "$S1" > "$TMP/empty.tsv"
run "$P2" --manifest "$TMP/empty.tsv"; eq "no usable peak fails" "1 1" "$? $(grep -c aempty "$TMP/err")"
exit $fail
