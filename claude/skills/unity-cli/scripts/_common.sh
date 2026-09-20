# Sourced by the unity-* helpers beside it. Needs: bash, python3, unity on PATH.
export PATH="$HOME/.unity/bin:$PATH"

die() { echo "$*" >&2; exit "${DIE_CODE:-1}"; }

# Walk up for ProjectSettings/ProjectVersion.txt: run from any subdirectory, never trust the cwd.
resolve_project() {
  local dir
  dir=$(cd "${1:-.}" 2>/dev/null && pwd) || die "no such directory: ${1:-.}"
  while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/ProjectSettings/ProjectVersion.txt" ]] && { printf '%s' "$dir"; return 0; }
    dir=$(dirname "$dir")
  done
  die "not inside a Unity project: ${1:-.} (no ProjectSettings/ProjectVersion.txt at or above it)"
}

# 0 when `unity status` lists a live editor for the project.
editor_open() {
  unity status --format json 2>/dev/null | python3 -c '
import sys, json
try: d = json.load(sys.stdin)
except Exception: sys.exit(1)
sys.exit(0 if any(i.get("project") == sys.argv[1] for i in (d.get("data") or {}).get("instances") or []) else 1)
' "$1"
}

not_running() { ! pgrep -f "Unity -projectpath ${PROJECT:?}" >/dev/null; }

# Unity rotates Editor.log on every launch, so it holds the most recently launched editor's whole
# session; the header names its project on a line of its own, which is how we know it is ours.
EDITOR_LOG="${UNITY_EDITOR_LOG:-$HOME/Library/Logs/Unity/Editor.log}"
log_is_ours() { grep -qxF "${PROJECT:?}" "$EDITOR_LOG" 2>/dev/null; }

# Prints the distinct `error CS...` lines of the project's current Editor.log (nothing if none).
compile_errors() { log_is_ours && grep -E "error CS[0-9]+" "$EDITOR_LOG" | grep -v "^##utp" | sort -u | head -20; }

# 0 when the project's editor opened into Safe Mode - a compile error at launch. Such an editor
# never starts the pipeline server, writes no descriptor, and answers nothing, forever.
in_safe_mode() { log_is_ours && grep -q "^Safe Mode: Only loading a subset of assemblies" "$EDITOR_LOG"; }

# Prints a tool's decoded data.result as one JSON line, or the single token `unreachable` — which is
# what a mid-domain-reload or Play-mode editor looks like, and is "still working", not an error.
# data.result is sometimes a JSON-encoded string rather than an object; this decodes both.
result_json() {                      # result_json <project> <tool> [args...]
  local project=$1; shift
  local out
  out=$(unity command "$1" --project-path "$project" --format json "${@:2}" 2>/dev/null | python3 -c '
import sys, json
try:
    r = (json.load(sys.stdin).get("data") or {}).get("result")
    if isinstance(r, str): r = json.loads(r)
    print("unreachable" if r is None else json.dumps(r))
except Exception:
    print("unreachable")
' 2>/dev/null)
  printf '%s' "${out:-unreachable}"
}

field() { python3 -c 'import sys,json;print(json.loads(sys.stdin.read()).get(sys.argv[1],""))' "$1" 2>/dev/null; }

wait_for() {                         # wait_for <deadline_seconds> <fn-returning-0-when-done>
  local deadline=$1 check=$2 start=$SECONDS
  while (( SECONDS - start < deadline )); do
    "$check" && return 0
    sleep 3
  done
  echo "timed out after ${deadline}s" >&2
  return 2
}
