#!/usr/bin/env bash
# Offline test for opencode-preflight's memory cap and --stop. A stub server answering /config,
# /config/providers, /experimental/session and /session/status from $WWW runs as
# `opencode serve --port <p>` on a private port, so server_rss_mb, the restart's pkill and the
# cap see it; a stub `opencode` on PATH starts the same stub on a restart. Never touches the real server.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/../scripts/opencode-preflight"
TMP=$(mktemp -d); trap '/usr/bin/pkill -f "$TMP/srv/opencode" 2>/dev/null; rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/srv" "$TMP/www" "$TMP/work"
export PATH="$TMP/bin:$PATH" WWW="$TMP/www" PIDFILE="$TMP/pidfile"

cat > "$TMP/srv/opencode" <<'STUB'
import http.server, os, sys
www = os.environ["WWW"]
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        f = os.path.join(www, self.path.split("?")[0].strip("/").replace("/", "_"))
        body = open(f, "rb").read() if os.path.isfile(f) else None
        self.send_response(200 if body else 404); self.end_headers(); self.wfile.write(body or b"")
    def log_message(self, *a): pass
s = http.server.HTTPServer(("127.0.0.1", int(sys.argv[3])), H)
open(os.environ["PIDFILE"], "w").write(str(os.getpid()))
s.serve_forever()
STUB
printf '#!/usr/bin/env bash\nexec python3 "%s" "$@"\n' "$TMP/srv/opencode" > "$TMP/bin/opencode"; chmod +x "$TMP/bin/opencode"
port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
# A guard pkill on PATH: only a pattern naming the stub's port reaches the real pkill, so no case can stop another server.
printf '#!/usr/bin/env bash\ncase "$*" in *"--port %s("*) exec /usr/bin/pkill "$@" ;; esac\necho "guard: refused pkill $*" >&2; exit 1\n' "$port" > "$TMP/bin/pkill"; chmod +x "$TMP/bin/pkill"
url="http://127.0.0.1:$port"
serve() { rm -f "$PIDFILE"; opencode serve --port "$port" & for _ in $(seq 50); do curl -sf "$url/config" >/dev/null && break; sleep 0.1; done; }
server_pid() { cat "$PIDFILE"; }
up() { curl -sf -m 2 "$url/config" >/dev/null; }

fence='{"permission": {"external_directory": {"*": "allow"}}}'
echo '{"providers": [{"id": "openai", "models": {"gpt-6.1-sol": {}}}]}' > "$WWW/config_providers"
busy() { echo '[{"directory": "/x"}]' > "$WWW/experimental_session"; echo '{"ses_1": {"type": "busy"}}' > "$WWW/session_status"; }
idle() { echo '[]' > "$WWW/experimental_session"; }
preflight() { "$SCRIPT" -m openai/gpt-6.1-sol -C "$TMP/work" --port "$port" --max-rss-mb 1 "$@" 2>"$TMP/err"; }

fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1: $(tr '\n' ' ' < "$TMP/err")"; fail=1; }

echo "$fence" > "$WWW/config"; busy; serve; pid=$(server_pid)
if preflight && grep -q "warning: the server holds .* MB resident" "$TMP/err" && [ "$(server_pid)" = "$pid" ]
then ok "busy and over the cap: warning, exit 0, not restarted"; else bad "busy and over the cap"; fi
echo '{}' > "$WWW/config"
if ! preflight && grep -q "no permission fence" "$TMP/err" && [ "$(server_pid)" = "$pid" ]
then ok "busy with the fence missing: exit 1"; else bad "busy with the fence missing"; fi
echo "$fence" > "$WWW/config"; idle
if preflight && grep -q "restarting the idle server" "$TMP/err" && up && [ "$(server_pid)" != "$pid" ]
then ok "idle and over the cap: restarted"; else bad "idle and over the cap"; fi
busy
if ! "$SCRIPT" --stop --port "$port" 2>"$TMP/err" && grep -q "not stopping .*: a session is busy" "$TMP/err" && up
then ok "--stop while busy: exit 1, server lives"; else bad "--stop while busy"; fi
idle; (exec -a "opencode attach $url" sleep 30) & client=$!; sleep 0.2
if ! "$SCRIPT" --stop --url "$url" 2>"$TMP/err" && grep -q "not stopping .*: a client is attached" "$TMP/err" && up
then ok "--stop --url with a client attached: exit 1, server lives"; else bad "--stop --url with a client attached"; fi
kill $client; wait $client 2>/dev/null
if "$SCRIPT" --stop --url "$url" 2>"$TMP/err" && ! up
then ok "--stop --url while idle: stopped"; else bad "--stop --url while idle"; fi
exit $fail
