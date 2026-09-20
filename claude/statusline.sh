#!/bin/bash

input=$(cat)

# Claude Code supplies live subscription-window data to this status-line
# command. Keep the most recent populated snapshot for other local consumers.
usage_file="${CLAUDE_USAGE_FILE:-/tmp/claude-usage.json}"
if echo "$input" | jq -e '.rate_limits.five_hour? // .rate_limits.seven_day?' >/dev/null; then
  echo "$input" |
    jq '{
      timestamp: (now | todate),
      five_hour: .rate_limits.five_hour,
      seven_day: .rate_limits.seven_day
    }' > "${usage_file}.tmp" &&
    mv "${usage_file}.tmp" "$usage_file"
fi

model=$(echo "$input" | jq -r '.model.display_name // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
dir=""
[ -n "$cwd" ] && dir=$(basename "$cwd")
branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
five_hour=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_hour_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_day=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_day_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
ctx_used=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

# ANSI styles
RESET=$'\033[0m'; DIM=$'\033[2m'; BOLD=$'\033[1m'
CYAN=$'\033[36m'; BLUE=$'\033[34m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'

human() {
  awk -v n="$1" 'BEGIN { if (n >= 1000) printf "%.0fk", n / 1000; else printf "%d", n }'
}

# green < 50, yellow < 80, else red
pct_color() {
  awk -v n="$1" -v g="$GREEN" -v y="$YELLOW" -v r="$RED" \
    'BEGIN { if (n < 50) printf "%s", g; else if (n < 80) printf "%s", y; else printf "%s", r }'
}

# resets_at (unix epoch seconds) -> compact remaining like 2d3h / 4h32m / 45m
remaining() {
  awk -v t="$1" -v now="$(date +%s)" 'BEGIN {
    s = t - now; if (s < 0) s = 0
    d = int(s / 86400); s -= d * 86400
    h = int(s / 3600);  s -= h * 3600
    m = int(s / 60)
    if (d > 0) printf "%dd%dh", d, h
    else if (h > 0) printf "%dh%dm", h, m
    else printf "%dm", m
  }'
}

output=""
add() { # $1 = already-styled segment; $2 = raw value (skip when empty)
  [ -z "$2" ] && return
  if [ -n "$output" ]; then output="$output ${DIM}|${RESET} $1"; else output="$1"; fi
}

limit_seg() { # $1 label, $2 used%, $3 resets_at
  local c seg
  c=$(pct_color "$2")
  seg="${DIM}$1:${RESET} ${c}$(printf '%.0f%%' "$2")${RESET}"
  [ -n "$3" ] && seg="$seg ${DIM}($(remaining "$3"))${RESET}"
  add "$seg" "$2"
}

# model + effort as one segment
model_seg="${BOLD}${CYAN}${model}${RESET}"
[ -n "$effort" ] && model_seg="$model_seg ${DIM}${effort}${RESET}"
add "$model_seg" "$model"

add "${BOLD}${BLUE}${dir}${RESET}" "$dir"
add "${GREEN}${branch}${RESET}" "$branch"

[ -n "$five_hour" ] && limit_seg "5h" "$five_hour" "$five_hour_reset"
[ -n "$seven_day" ] && limit_seg "7d" "$seven_day" "$seven_day_reset"

if [ -n "$ctx_used" ] && [ -n "$ctx_size" ]; then
  ratio=$(awk -v u="$ctx_used" -v s="$ctx_size" 'BEGIN { if (s > 0) printf "%.0f", (u / s) * 100; else print 0 }')
  c=$(pct_color "$ratio")
  add "${DIM}ctx:${RESET} ${c}$(human "$ctx_used")/$(human "$ctx_size")${RESET}" "$ctx_used"
fi

printf '%s\n' "$output"
