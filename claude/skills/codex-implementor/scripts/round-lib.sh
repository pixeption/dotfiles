# Sourced, not run: the finish checks opencode-round and codex-round share, so the two channels
# cannot drift on what a verdict is, what a usage limit is, or what a failed out-file looks like.

# An error event matching this means the account is out of codex, not that the round failed.
usage_limit_re='429|usage limit|rate limit|quota'
is_usage_limit() { grep -qiE "$usage_limit_re" <<<"$1"; }

# The last non-blank line of <file>, stripped of markdown (`## Verdict: X`, `**X**`); REQUEST_CHANGES
# means CHANGES_REQUIRED.
final_verdict() {
  grep -v '^[[:space:]]*$' "$1" | tail -n 1 |
    sed -E 's/[#*`]//g; s/^[[:space:]]*(Verdict:)?[[:space:]]*//I; s/[[:space:]]*$//; s/^REQUEST_CHANGES$/CHANGES_REQUIRED/' |
    grep -xE 'APPROVE|CHANGES_REQUIRED'
}
# True when <file> ends in a verdict; a decorated one is appended bare as the new last line.
ends_in_verdict() {
  local v; v=$(final_verdict "$1") || return 1
  [ "$(grep -v '^[[:space:]]*$' "$1" | tail -n 1)" = "$v" ] || printf '\n%s\n' "$v" >> "$1"
}

# write_blocked <out-file> <Blocked: reason> [unit]... — the reason, the partial answer without BEES
# lines, and `BEES: results=<unit>:blocked:-` per unit, so a failed round never reads as done.
write_blocked() {
  local out=$1 reason=$2 results="" partial; shift 2
  [ $# = 0 ] || results="$(printf '%s:blocked:-;' "$@")"
  partial="$(grep -v '^BEES:' "$out" 2>/dev/null)"
  printf '%s\n\n%s%s\n' "$reason" "$partial" "${results:+${partial:+$'\n\n'}BEES: results=${results%;}}" > "$out"
}
