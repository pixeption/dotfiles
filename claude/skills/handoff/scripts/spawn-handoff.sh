#!/usr/bin/env bash
# spawn-handoff.sh — one-shot handoff to a fresh Claude session.
#
# Spawns a new interactive Claude session in a kitty tab and delivers the handoff
# in a SINGLE step: the handoff text becomes the new session's first prompt, so it
# starts working immediately. No process-wait, no ListAgents, no SendMessage round
# trip. Only the message text crosses — this is not context/file transfer.
#
# Usage:
#   spawn-handoff.sh [--task PHRASE|--name NAME] [--cwd DIR] [--os-window] [--dry-run] [MSG_FILE]
#     MSG_FILE   handoff text; omit to read it from stdin
#     --task     short phrase describing the work; slugified into a mentionable name plus a time
#                suffix for uniqueness, e.g. --task "fix pipeline-ui frictions" -> fix-pipeline-ui-frictions-165852
#     --name     exact session name to use verbatim (still sanitized to letters/digits/hyphens);
#                overrides --task and adds no suffix
#     --cwd      working dir for the new session (default: $PWD)
#     --model    model for the new session (alias or full id); defaults to $CLAUDE_MODEL, i.e. the
#                spawning session's own model when the caller exports it
#     --effort   reasoning effort: low|medium|high|xhigh|max; defaults to $CLAUDE_EFFORT, the
#                spawning session's own effort
#     --os-window  open a separate OS window instead of a tab
#     --dry-run  print what would run, spawn nothing
#   Name precedence: --name (verbatim) > --task (slug + -HHMMSS) > handoff-HHMMSS.
#
# Prints NAME=<name> and WINDOW=<id> on success so the caller can address the tab.
set -euo pipefail

# Lowercase, collapse every run of non-[a-z0-9] to a single hyphen, trim, cap length -
# the mentionable, quote-free form a session name must take.
slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
    | cut -c1-40 | sed -E 's/-+$//'
}

cwd="$PWD"; name=""; task=""; wtype="tab"; dry=0
# Inherit the spawning session's model/effort by default: CLAUDE_EFFORT is exported by Claude Code
# itself; CLAUDE_MODEL is exported by the caller (the skill tells Claude to pass its own model id).
model="${CLAUDE_MODEL:-}"; effort="${CLAUDE_EFFORT:-medium}"
while [ $# -gt 0 ]; do
  case "$1" in
    --cwd)       cwd="$2"; shift 2;;
    --name)      name="$2"; shift 2;;
    --task)      task="$2"; shift 2;;
    --model)     model="$2"; shift 2;;
    --effort)    effort="$2"; shift 2;;
    --os-window) wtype="os-window"; shift;;
    --dry-run)   dry=1; shift;;
    --)          shift; break;;
    -*)          echo "unknown option: $1" >&2; exit 2;;
    *)           break;;
  esac
done

model_args=()
[ -n "$model" ] && model_args=(--model "$model")

case "$effort" in
  low|medium|high|xhigh|max) ;;
  *) echo "invalid --effort '$effort' (want low|medium|high|xhigh|max)" >&2; exit 2;;
esac

# Handoff text: from the file arg, else stdin.
msgfile="$(mktemp -t handoff-msg.XXXXXX)"
trap 'rm -f "$msgfile"' EXIT
if [ "$#" -ge 1 ] && [ -n "${1:-}" ]; then cat -- "$1" > "$msgfile"; else cat > "$msgfile"; fi
[ -s "$msgfile" ] || { echo "handoff message is empty" >&2; exit 2; }

# Name: an explicit --name wins verbatim (sanitized); else a --task slug with a time suffix for
# uniqueness; else the plain timestamped default. A sanitized name that comes out empty falls back.
if [ -n "$name" ]; then
  name="$(slugify "$name")"; [ -n "$name" ] || name="handoff"
elif [ -n "$task" ]; then
  slug="$(slugify "$task")"; name="${slug:-handoff}-$(date +%H%M%S)"
else
  name="handoff-$(date +%H%M%S)"
fi

# claude is often not on a non-login PATH; fall back to a login shell's resolution.
claude_bin="$(command -v claude 2>/dev/null || zsh -lic 'command -v claude' 2>/dev/null || true)"
[ -n "$claude_bin" ] || { echo "claude binary not found on PATH or in a login shell" >&2; exit 3; }

if [ "$dry" -eq 1 ]; then
  echo "claude:  $claude_bin"
  echo "name:    $name"
  echo "model:   ${model:-<session default>}"
  echo "effort:  $effort"
  echo "cwd:     $cwd"
  echo "wtype:   $wtype"
  echo "message: $(wc -c < "$msgfile") bytes, $(wc -l < "$msgfile") lines"
  echo "would run: kitty @ launch --type=$wtype --cwd=$cwd --title=$name -- $claude_bin --name $name ${model:+--model $model} --effort $effort --settings {\"crossSessionInbound\":\"accept\"} <message>"
  exit 0
fi

# kitty remote control must be live (allow_remote_control + a listen socket).
kitty @ ls >/dev/null 2>&1 || { echo "kitty remote control is off; enable allow_remote_control + a listen socket in kitty.conf" >&2; exit 3; }

# The message is expanded here by THIS shell into a single argv element, so kitty
# never tokenizes it — newlines/quotes/$/backticks in the handoff are all safe. The
# new session accepts inbound messages unattended so a follow-up needs no approval.
wid="$(kitty @ launch --type="$wtype" --cwd="$cwd" --title="$name" -- \
  "$claude_bin" --name "$name" ${model_args[@]+"${model_args[@]}"} --effort "$effort" \
  --settings '{"crossSessionInbound":"accept"}' "$(cat "$msgfile")")"

echo "NAME=$name"
echo "WINDOW=$wid"
