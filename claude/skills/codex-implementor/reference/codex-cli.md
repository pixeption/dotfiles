# The codex CLI fallback

Use only when the OpenCode server won't start, or an implementation unit must run under an OS
sandbox. Same models; `codex exec` as a background process.

## The wrappers

Both hardcode `< /dev/null`, read the prompt from a file, write only the final message, record the
session id, and write `<out-file>.usage` via `extract-codex-cli-usage` from the session's rollout
under `~/.codex/sessions` — the last `token_count` event's `last_token_usage`, never
`total_token_usage` (a cumulative sum across the session, not the current context).

```sh
# implement — in place with the editor: -s danger-full-access
~/.claude/skills/codex-implementor/scripts/codex-implement \
  -C <dir> -p "$T/brief.md" -o "$W/impl-<unit>-r1.txt" [-e high] [-t fast|standard]
# follow-up within 30 min
~/.claude/skills/codex-implementor/scripts/codex-implement ... -r "$(cat "$W/impl-<unit>-r1.txt.session")"

# review — always --sandbox read-only
~/.claude/skills/codex-review/scripts/codex-review -p "$T/r1-prompt.txt" -o "$W/review-<unit>-r1.txt" -e medium
~/.claude/skills/codex-review/scripts/codex-review -p "$T/r2-prompt.txt" -o "$W/review-<unit>-r2.txt" -r "$(cat "$W/review-<unit>-r1.txt.session")"
```

| | CLI |
|---|---|
| isolation | OS seatbelt: `read-only` (review), `workspace-write` / `danger-full-access` (implement) |
| session | prompt cache **30 min**; `codex-implement` refuses a resume older than that — after it, start fresh with the findings or the delta in the prompt |
| live view | read-only tail of the JSONL `.log` (the owner's, never yours) |

## The stdin trap

`codex exec` (and `resume`) appends stdin as a `<stdin>` block even with a prompt argument and,
backgrounded, inherits an fd that never EOFs — it **hangs forever** at `Reading additional input
from stdin...`. Never remove the wrappers' `< /dev/null`.

Hung or working? After ~60–90 s, `<out-file>.log` growing = working; stuck on that line = hung →
`pkill -f "codex exec"` and resume by **explicit id**, never `--last`.
