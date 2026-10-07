#!/usr/bin/env bash
# Offline test for opencode-round's "did the final step finish" check: a stub `opencode run` prints a
# log built from fixtures/final-step-finish-missing.log (the real tail of a finished round whose
# `opencode run` exited before printing the final step_finish), and a stub server answers
# GET /session/<sid>/message/<msg> from files.
#   finished-on-server  - log lacks the final step_finish, server has it with reason stop: exit 0, BEES kept,
#                         and .usage reads the server's tokens, not the previous step's.
#   finished-in-log     - log has the final step_finish with reason stop, server knows nothing: exit 0.
#   cut-mid-step        - log lacks it, server's message has no step-finish: exit 1, BEES blocked.
#   tool-calls-last     - after the text the step ended in tool-calls and another step began: exit 1.
#   newer-step-open     - a newer message's step began and never finished, server says stop for the
#                         text message: exit 1.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/../scripts/opencode-round"
FIXTURE="$here/fixtures/final-step-finish-missing.log"
TMP=$(mktemp -d); trap 'kill $srv 2>/dev/null; rm -rf "$TMP"' EXIT
sid=$(jq -r .sessionID "$FIXTURE" | head -1)
msg=$(jq -r 'select(.type == "text") | .part.messageID' "$FIXTURE")

python3 -c '
import functools, http.server, sys
h = functools.partial(http.server.SimpleHTTPRequestHandler, directory=sys.argv[1])
h.func.log_message = lambda *a: None
s = http.server.HTTPServer(("127.0.0.1", 0), h)
open(sys.argv[2], "w").write(str(s.server_address[1]))
s.serve_forever()' "$TMP/www" "$TMP/port" &
srv=$!
for _ in $(seq 50); do [ -s "$TMP/port" ] && break; sleep 0.1; done
url="http://127.0.0.1:$(cat "$TMP/port")"

step_finish() { jq -c --arg m "$1" --arg r "$2" '{type: "step_finish", sessionID, part: {type: "step-finish", messageID: $m, sessionID, reason: $r}}' <<<"$(head -1 "$FIXTURE")"; }
server_parts() { # server_parts <reason-of-step-finish|none>
  mkdir -p "$TMP/www/session/$sid/message"
  jq -n --arg r "$1" '{info: {}, parts: ([{type: "step-start"}, {type: "text"}] + if $r == "none" then [] else [{type: "step-finish", reason: $r, tokens: {total: 140000}}] end)}' \
    > "$TMP/www/session/$sid/message/$msg"
}

fail=0
check() { # check <name> <want-exit> <want-last-line-regex> [role]; the log to replay is $TMP/<name>.log
  local name=$1 want=$2 re=$3 role=${4:-impl} out code last
  out="$TMP/$name.txt"
  "$SCRIPT" --url "$url" -C "$TMP" --role "$role" -o "$out" -u STEP-05 -- cat "$TMP/$name.log" 2>/dev/null; code=$?
  last=$(tail -n 1 "$out")
  if [[ $code == "$want" && $last =~ $re ]]; then echo "ok   $name"
  else echo "FAIL $name (exit $code): $(head -1 "$out") … $last"; fail=1; fi
}

cp "$FIXTURE" "$TMP/finished-on-server.log"; server_parts stop
check finished-on-server 0 '^BEES: results=STEP-05:done:'
usage=$(jq .context_tokens "$TMP/finished-on-server.txt.usage")
if [ "$usage" = 140000 ]; then echo "ok   finished-on-server usage"; else echo "FAIL finished-on-server usage: context_tokens $usage"; fail=1; fi

{ cat "$FIXTURE"; step_finish "$msg" stop; } > "$TMP/finished-in-log.log"; rm -rf "$TMP/www/session"
check finished-in-log 0 '^BEES: results=STEP-05:done:'

cp "$FIXTURE" "$TMP/cut-mid-step.log"; server_parts none
check cut-mid-step 1 '^BEES: results=STEP-05:blocked:-$'

{ cat "$FIXTURE"; step_finish "$msg" tool-calls; step_finish msg_next tool-calls; } > "$TMP/tool-calls-last.log"; server_parts tool-calls
check tool-calls-last 1 '^BEES: results=STEP-05:blocked:-$'
{ cat "$FIXTURE"; step_finish "$msg" tool-calls; jq -c '{type: "step_start", sessionID, part: {type: "step-start", messageID: "msg_next", sessionID}}' <<<"$(head -1 "$FIXTURE")"; } > "$TMP/newer-step-open.log"; server_parts stop
check newer-step-open 1 '^BEES: results=STEP-05:blocked:-$'
# review: the answer's last line, bare or markdown-decorated, must be a verdict.
review() { # review <name> <want-exit> <last-line> <want-out-last-line-regex>
  { jq -c --arg t "Findings.

$3" 'if .type == "text" then .part.text = $t else . end' "$FIXTURE"; step_finish "$msg" stop; } > "$TMP/$1.log"
  check "$1" "$2" "$4" review
}
review verdict-heading 0 '## Verdict: APPROVE' '^APPROVE$'
review verdict-bold 0 '**Verdict: REQUEST_CHANGES**' '^CHANGES_REQUIRED$'
review verdict-prose 1 'I would approve this.' 'blocked'
exit $fail
