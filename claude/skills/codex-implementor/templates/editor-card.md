You alone drive <project>. The helpers are not on PATH; run them by absolute path:

```sh
S=~/.claude/skills/unity-cli/scripts P=<project>
$S/unity-editor up "$P"                       # open or reuse the live editor, headless
$S/unity-wait --project-path "$P" recompile   # after every edit; exit 1 prints the compile errors
$S/unity-test <filter> --project-path "$P"    # while iterating; exit 1 lists the failing tests
$S/unity-suite "$P" --filter 'A|B'            # the acceptance run, once, at the end
```

- `unity-test`'s filter is one case-insensitive substring of the full test name, so `A|B` matches
  nothing there. Accept a run only with no `FILTER MISMATCH` and the passed/total you expect. Never
  run it without a filter.
- `unity-suite` runs a filtered Edit-Mode run in the open editor (same PID) unless that editor
  entered Play; anything else closes it, runs in batch and reopens it. Pass `--output
  <project>/Logs/<unit>.xml`. Quote its count line and its `report:` line verbatim under Verification.
- A hand-run batch `unity test` takes an absolute `--output` before any `--`; parse the XML and
  ignore stdout and the exit code.
- Pass `--project-path "$P"` on every `unity command`: a bare one lands on whatever editor is
  running.
- A compile error at launch makes `unity-editor up` exit 1 with the `error CS` lines printed and no
  editor left running. Fix them, then `unity-editor up` again.
- A failure because another instance holds the project is not transient: stop and report. No
  retry, sleep or polling loop.
- `unity close` before reporting; never kill the editor.
- Open `~/.claude/skills/unity-cli/SKILL.md` only for a command this card does not cover, and read
  only that section.
