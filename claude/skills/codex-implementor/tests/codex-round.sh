#!/usr/bin/env bash
# Offline test for codex-round's channel choice and completion contract. HOME, PATH and the ports
# are private: a stub `opencode` (its `serve` exits, `run` replays $OC_LOG), a stub `codex` at
# ~/.local/bin (resolve-codex's first choice; it answers per $CODEX_MODE) and a stub server
# answering the preflight's and codex-round's GETs and POSTs from $TMP/www (POSTs logged to
# $TMP/www.posts); `stop` runs against fake rounds. Never touches the real server.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/../scripts/codex-round"
TMP=$(mktemp -d); srv=""; stale=""; other=""; fakes=""; trap 'kill $srv $stale $other $fakes 2>/dev/null; rm -rf "$TMP"' EXIT
export HOME="$TMP/home" PATH="$TMP/bin:$PATH" OPENCODE_ROUND_POLL=1
mkdir -p "$TMP/bin" "$HOME/.local/bin" "$HOME/.codex/sessions" "$TMP/www" "$TMP/www-stale" "$TMP/srv" "$TMP/work" "$TMP/out" "$TMP/err"

cat > "$TMP/bin/opencode" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$STUB_CALLS/opencode"
[ "$1" = run ] && cat "$OC_LOG"
[ "$1" = run ]
STUB
cat > "$HOME/.local/bin/codex" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$STUB_CALLS/codex"
while [ $# -gt 0 ]; do [ "$1" = --output-last-message ] && out="$2"; shift; done
case "$CODEX_MODE" in
  limit) echo '{"type":"error","message":"You have hit your usage limit reached"}'; exit 1 ;;
  limit-late) echo '{"type":"error","message":"stream disconnected: connection reset"}'
              echo '{"type":"turn.failed","error":{"message":"usage limit reached"}}'; exit 1 ;;
  limit-ok) echo '{"type":"error","message":"429 rate limit, retrying"}' ;;
esac
echo '{"type":"thread.started","thread_id":"thr-1"}'
echo '{"info":{"total_token_usage":{},"last_token_usage":{"input_tokens":10,"output_tokens":5}}}' > "$HOME/.codex/sessions/rollout-thr-1.jsonl"
printf '%s\n' "$ANSWER" > "$out"
STUB
chmod +x "$TMP/bin/opencode" "$HOME/.local/bin/codex"

# The stub server is named `opencode serve --port <p>` so the preflight's pkill can stop it on a restart.
cat > "$TMP/srv/opencode" <<'STUB'
import http.server, os, sys, time
www = os.environ["WWW"]
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        f = os.path.join(www, self.path.split("?")[0].strip("/").replace("/", "_"))
        if os.path.isfile(f + ".delay"): time.sleep(float(open(f + ".delay").read()))
        body = open(f, "rb").read() if os.path.isfile(f) else None
        self.send_response(200 if body else 404); self.end_headers(); self.wfile.write(body or b"")
    def do_POST(self):
        open(www + ".posts", "a").write(self.path + "\n")
        self.do_GET()
    def log_message(self, *a): pass
s = http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[3])), H)
open(os.environ["PORTFILE"], "w").write(str(s.server_address[1]))
s.serve_forever()
STUB
serve() { # serve <www> <portfile> <port>: starts a stub server in the background
  WWW="$1" PORTFILE="$2" python3 "$TMP/srv/opencode" serve --port "$3" &
  for _ in $(seq 50); do [ -s "$2" ] && break; sleep 0.1; done
}
free_port() { python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'; }
serve "$TMP/www" "$TMP/port" 0; srv=$!
live="http://127.0.0.1:$(cat "$TMP/port")"
dead="http://127.0.0.1:$(free_port)"
fence='{"permission": {"external_directory": {"*": "allow"}},
  "agent": {"review-discovery": {"permission": {"edit": "deny"}}, "review-followup": {"permission": {"edit": "deny", "task": "deny"}}}}'
echo "$fence" > "$TMP/www/config"
echo '{"providers": [{"id": "openai", "models": {"gpt-6.1-sol-fast": {}}}]}' > "$TMP/www/config_providers"
echo '[]' > "$TMP/www/permission"
echo 'Brief.' > "$TMP/prompt"

oc_log() { # oc_log <answer> [error-message]: a finished round, or one ending in an error event
  jq -nc --arg t "$1" '{type: "text", sessionID: "ses_1", part: {messageID: "msg_1", type: "text", text: $t}},
    {type: "step_finish", sessionID: "ses_1", part: {messageID: "msg_1", type: "step-finish", reason: "stop", tokens: {total: 42}}}'
  [ -z "${2:-}" ] || jq -nc --arg m "$2" '{type: "error", sessionID: "ses_1", error: {name: "APIError", data: {message: $m}}}'
}

fail=0; n=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1: $2"; fail=1; }
# round <want-exit> <job> <args>…: runs one round into a fresh $out, with fresh call logs.
round() {
  local want=$1 code; shift; n=$((n + 1)); out="$TMP/out/r$n.txt"
  export STUB_CALLS="$TMP/calls/$n"; mkdir -p "$STUB_CALLS"
  "$SCRIPT" "$@" -C "$TMP/work" -p "$TMP/prompt" -o "$out" -u U-1 2>"$TMP/err/$n"; code=$?
  [ "$code" = "$want" ] || { echo "     exit $code, want $want; stderr: $(tail -3 "$TMP/err/$n")"; return 1; }
}
called() { [ -s "$STUB_CALLS/$1" ]; }
artifacts() { # artifacts <files…>: present, and .usage the newest
  for f in "" "$@" .session .pid .cwd .usage; do [ -e "$out$f" ] || { echo "     missing $out$f"; return 1; }; done
  for f in "" .log .session .pid .cwd "$@"; do [ ! "$out$f" -nt "$out.usage" ] || { echo "     $f newer than .usage"; return 1; }; done
}

for job in implement run review advise; do
  answer="Did it."; [ "$job" = review ] && answer=$'Findings.\n\nAPPROVE'
  export ANSWER="$answer" CODEX_MODE=ok OC_LOG="$TMP/oc-$job.log"; oc_log "$answer" > "$OC_LOG"
  agent=""; case $job in review) agent="--agent review-discovery " ;; advise) agent="--agent review-followup " ;; esac
  if round 0 "$job" --url "$live" && [ "$(cat "$out")" = "$answer" ] && artifacts .url && [ "$(cat "$out.url")" = "$live" ] &&
     ! called codex && grep -q -- "run --attach $live --dir $(cd "$TMP/work" && pwd -P) ${agent}--auto" "$STUB_CALLS/opencode"
  then ok "$job on OpenCode"; else bad "$job on OpenCode" "$(head -1 "$out" 2>/dev/null)"; fi
  sandbox=danger-full-access; case $job in review|advise) sandbox=read-only ;; esac
  if round 0 "$job" --url "$dead" && [ "$(cat "$out")" = "$answer" ] && artifacts && [ ! -e "$out.url" ] &&
     [ "$(jq .context_tokens "$out.usage")" = 15 ] &&
     grep -q -- "--sandbox $sandbox .*-m gpt-6.1-sol -c model_reasoning_effort=medium -c service_tier=priority " "$STUB_CALLS/codex" &&
     grep -q '^serve' "$STUB_CALLS/opencode"
  then ok "$job on the CLI when the server cannot start"; else bad "$job on the CLI" "$(head -1 "$out" 2>/dev/null)"; fi
done

export CODEX_MODE=limit
if round 3 implement --url "$dead" && [[ $(head -1 "$out") == "Blocked: codex unavailable"* ]] &&
   [ "$(tail -n 1 "$out")" = "BEES: results=U-1:blocked:-" ] && [ -e "$out.usage" ]
then ok "both channels unavailable"; else bad "both channels unavailable" "$(head -1 "$out")"; fi
export ANSWER="Did it."
for mode in limit-late limit-ok; do
  export CODEX_MODE=$mode
  if round 3 implement --url "$dead" && [[ $(head -1 "$out") == "Blocked: codex unavailable: codex "*"limit"* ]]
  then ok "CLI usage limit in any error event ($mode)"; else bad "CLI usage limit ($mode)" "$(head -1 "$out" 2>/dev/null)"; fi
done

export OC_LOG="$TMP/oc-limit.log"; oc_log "partial" "429 Too Many Requests" > "$OC_LOG"
if round 3 review --url "$live" && [[ $(head -1 "$out") == "Blocked: codex unavailable: opencode APIError"* ]] && ! called codex
then ok "OpenCode usage limit, CLI not tried"; else bad "OpenCode usage limit" "$(head -1 "$out")"; fi

echo '{}' > "$TMP/www/config"
if round 1 implement --url "$live" && ! called codex && [ ! -e "$out" ] && [ ! -e "$out.pid" ]
then ok "fence refusal does not switch channel"; else bad "fence refusal" "exit or files"; fi
echo "$fence" > "$TMP/www/config"
echo '{}' > "$TMP/www-stale/config"; cp "$TMP/www/config_providers" "$TMP/www-stale/"; echo '[]' > "$TMP/www-stale/experimental_session"
serve "$TMP/www-stale" "$TMP/port-stale" "$(free_port)"; stale=$!
if round 1 implement --url "http://127.0.0.1:$(cat "$TMP/port-stale")" && ! called codex && [ ! -e "$out" ] &&
   grep -q '^serve' "$STUB_CALLS/opencode"
then ok "fence refusal whose restart cannot start does not switch channel"; else bad "fence refusal and failed restart" "exit or files"; fi

if round 3 implement --url "$dead" -s ses_x && ! called codex && ! called opencode && [ ! -e "$out" ]
then ok "OpenCode resume with the server down"; else bad "OpenCode resume with the server down" "codex or preflight ran"; fi
export CODEX_MODE=ok ANSWER=$'Resumed.\n\nAPPROVE'
pinned_to() { jq -nc --arg d "$1" '{type: "session_meta", payload: {cwd: $d}}'; }
pinned_to "$TMP/work" > "$HOME/.codex/sessions/rollout-x-0199-uuid.jsonl"
pinned_to "$TMP" > "$HOME/.codex/sessions/rollout-x-0299-uuid.jsonl"
for job in implement review; do
  sandbox=danger-full-access; [ "$job" = review ] && sandbox=read-only
  if round 0 "$job" --url "$dead" -s 0199-uuid && grep -q "^exec --sandbox $sandbox resume 0199-uuid " "$STUB_CALLS/codex" && ! called opencode
  then ok "CLI $job resume skips preflight, keeps its sandbox"; else bad "CLI $job resume" "$(cat "$STUB_CALLS/codex" 2>/dev/null)"; fi
done
if round 1 implement --url "$dead" -s 0299-uuid && ! called codex && grep -q 'not pinned to' "$TMP/err/$n"
then ok "CLI resume pinned to another directory refused"; else bad "CLI resume pinned elsewhere" "$(cat "$STUB_CALLS/codex" 2>/dev/null)"; fi

export ANSWER="I would approve this."
if round 1 review --url "$dead" && [[ $(head -1 "$out") == "Blocked: the answer does not end"* ]] &&
   [ "$(tail -n 1 "$out")" = "BEES: results=U-1:blocked:-" ]
then ok "CLI review without a verdict"; else bad "CLI review without a verdict" "$(head -1 "$out")"; fi
export ANSWER=$'Findings.\n\n**Verdict: REQUEST_CHANGES**'
if round 0 review --url "$dead" && [ "$(tail -n 1 "$out")" = CHANGES_REQUIRED ]
then ok "CLI review with a markdown verdict"; else bad "CLI review with a markdown verdict" "$(tail -n 1 "$out")"; fi

n=$((n + 1)); out="$TMP/out/r$n.txt"; echo keep > "$out"; export STUB_CALLS="$TMP/calls/$n"; mkdir -p "$STUB_CALLS"
"$SCRIPT" implement -C "$TMP/work" -p "$TMP/prompt" -o "$out" --url "$dead" 2>/dev/null; code=$?
if [ "$code" = 2 ] && [ "$(cat "$out")" = keep ] && ! called codex && ! called opencode
then ok "existing out-file refused"; else bad "existing out-file refused" "exit $code"; fi
# stop: fake rounds on a second stub server, so the recorded .url (not the default port) is used.
gone() { local stat; ! stat="$(ps -o stat= -p "$1" 2>/dev/null)" || [[ $stat == Z* ]]; }
fake_round() { # fake_round <out> <session> [--log]: a round process with a child and a grandchild
  bash -c 'bash -c "sleep 300; :" & wait' 2>/dev/null & echo $! > "$1.pid"
  printf '%s\n' "$TMP/work" > "$1.cwd"; printf '%s\n' "$stopurl" > "$1.url"
  if [ "${3:-}" = --log ]; then jq -nc --arg s "$2" '{type: "step_start", sessionID: $s}' > "$1.log"; else echo "$2" > "$1.session"; fi
  sleep 0.5; tree=("$(cat "$1.pid")"); tree+=($(pgrep -P "${tree[0]}")); tree+=($(pgrep -P "${tree[1]}"))
  fakes="$fakes ${tree[*]}"
}
stop() { STUB_CALLS="$TMP/calls/stop" CODEX_ROUND_STOP_WAIT=1 "$SCRIPT" stop "$1" 2>"$TMP/err/stop"; }
tree_gone() { local p; [ ${#tree[@]} = 3 ] || return 1; for p in "${tree[@]}"; do gone "$p" || return 1; done; }
mkdir -p "$TMP/www-stop"; echo true > "$TMP/www-stop/session_ses_s_abort"; echo true > "$TMP/www-stop/session_ses_b_abort"
echo '{"ses_b": {"type": "busy"}}' > "$TMP/www-stop/session_status"
serve "$TMP/www-stop" "$TMP/port-stop" 0; stale="$stale $!"
stopurl="http://127.0.0.1:$(cat "$TMP/port-stop")"
sleep 300 & other=$!

fake_round "$TMP/out/s1.txt" ses_s
if stop "$TMP/out/s1.txt" && tree_gone && ! gone "$other" &&
   grep -qix "/session/ses_s/abort?directory=$(jq -rn --arg d "$TMP/work" '$d | @uri')" "$TMP/www-stop.posts"
then ok "stop aborts the session on its recorded server and ends the round's tree"; else bad "stop" "$(cat "$TMP/err/stop")"; fi
fake_round "$TMP/out/s2.txt" ses_unknown --log
if ! stop "$TMP/out/s2.txt" && grep -q "ses_unknown: the abort" "$TMP/err/stop" && tree_gone && ! gone "$other"
then ok "stop of an unknown session fails"; else bad "stop of an unknown session" "$(cat "$TMP/err/stop")"; fi
fake_round "$TMP/out/s3.txt" ses_b
if ! stop "$TMP/out/s3.txt" && grep -q "ses_b still busy" "$TMP/err/stop"
then ok "stop fails while the session stays busy"; else bad "stop with a busy session" "$(cat "$TMP/err/stop")"; fi
fake_round "$TMP/out/s4.txt" ses_b; echo 2 > "$TMP/www-stop/session_status.delay"; start=$SECONDS
if ! stop "$TMP/out/s4.txt" && (( SECONDS - start < 4 )) && grep -q "ses_b still busy or unreadable" "$TMP/err/stop" && tree_gone
then ok "stop keeps to its wait when the status answers slowly"; else bad "stop with a slow status" "$((SECONDS - start)) s: $(cat "$TMP/err/stop")"; fi
echo true > "$TMP/www-stop/session_ses_e_abort"; fake_round "$TMP/out/s5.txt" ses_e; echo 0.5 > "$TMP/www-stop/session_status.delay"
(until grep -qs "ses_e/abort" "$TMP/www-stop.posts"; do sleep 0.1; done; kill "${tree[0]}") & fakes="$fakes $!"
if stop "$TMP/out/s5.txt" && tree_gone
then ok "stop ends the descendants of a root that exits on the abort"; else bad "stop with a root that exits on the abort" "$(cat "$TMP/err/stop")"; fi
exit $fail
