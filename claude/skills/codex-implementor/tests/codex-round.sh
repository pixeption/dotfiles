#!/usr/bin/env bash
# Offline test for codex-round's channel choice and completion contract. HOME, PATH and the ports
# are private: a stub `opencode` (its `serve` exits, `run` replays $OC_LOG), a stub `codex` at
# ~/.local/bin (resolve-codex's first choice; it answers per $CODEX_MODE) and a stub server
# answering the preflight's and codex-round's GETs from $TMP/www. Never touches the real server.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/../scripts/codex-round"
TMP=$(mktemp -d); trap 'kill $srv 2>/dev/null; rm -rf "$TMP"' EXIT
export HOME="$TMP/home" PATH="$TMP/bin:$PATH" OPENCODE_ROUND_POLL=1
mkdir -p "$TMP/bin" "$HOME/.local/bin" "$HOME/.codex/sessions" "$TMP/www" "$TMP/work" "$TMP/out" "$TMP/err"

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
if [ "$CODEX_MODE" = limit ]; then echo '{"type":"error","message":"You have hit your usage limit reached"}'; exit 1; fi
echo '{"type":"thread.started","thread_id":"thr-1"}'
echo '{"info":{"total_token_usage":{},"last_token_usage":{"input_tokens":10,"output_tokens":5}}}' > "$HOME/.codex/sessions/rollout-thr-1.jsonl"
printf '%s\n' "$ANSWER" > "$out"
STUB
chmod +x "$TMP/bin/opencode" "$HOME/.local/bin/codex"

python3 -c '
import http.server, json, os, sys
www, portfile = sys.argv[1], sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        f = os.path.join(www, self.path.split("?")[0].strip("/").replace("/", "_"))
        body = open(f, "rb").read() if os.path.isfile(f) else None
        self.send_response(200 if body else 404); self.end_headers(); self.wfile.write(body or b"")
    def log_message(self, *a): pass
s = http.server.HTTPServer(("127.0.0.1", 0), H)
open(portfile, "w").write(str(s.server_address[1]))
s.serve_forever()' "$TMP/www" "$TMP/port" &
srv=$!
for _ in $(seq 50); do [ -s "$TMP/port" ] && break; sleep 0.1; done
live="http://127.0.0.1:$(cat "$TMP/port")"
dead="http://127.0.0.1:$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
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

export OC_LOG="$TMP/oc-limit.log"; oc_log "partial" "429 Too Many Requests" > "$OC_LOG"
if round 3 review --url "$live" && [[ $(head -1 "$out") == "Blocked: codex unavailable: opencode APIError"* ]] && ! called codex
then ok "OpenCode usage limit, CLI not tried"; else bad "OpenCode usage limit" "$(head -1 "$out")"; fi

echo '{}' > "$TMP/www/config"
if round 1 implement --url "$live" && ! called codex && [ ! -e "$out" ] && [ ! -e "$out.pid" ]
then ok "fence refusal does not switch channel"; else bad "fence refusal" "exit or files"; fi
echo "$fence" > "$TMP/www/config"

if round 3 implement --url "$dead" -s ses_x && ! called codex && ! called opencode && [ ! -e "$out" ]
then ok "OpenCode resume with the server down"; else bad "OpenCode resume with the server down" "codex or preflight ran"; fi
export CODEX_MODE=ok ANSWER="Resumed."; touch "$HOME/.codex/sessions/rollout-x-0199-uuid.jsonl"
if round 0 implement --url "$dead" -s 0199-uuid && grep -q '^exec resume 0199-uuid ' "$STUB_CALLS/codex" && ! called opencode
then ok "CLI resume skips preflight"; else bad "CLI resume" "$(cat "$STUB_CALLS/codex" 2>/dev/null)"; fi

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
exit $fail
