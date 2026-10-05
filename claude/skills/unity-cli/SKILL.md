---
name: unity-cli
description: >-
  Drives Unity through the `unity` CLI, the Unity Pipeline package (`com.unity.pipeline`) and a live editor's HTTP API (`unity command`, `recompile`, `test`, `status`, `job`) and the helpers `unity-editor`, `unity-test`, `unity-suite`, `unity-wait` for an edit → recompile → test loop. Use when scripting or iterating on a live Unity editor, running batch tests or builds, managing or upgrading editors and the CLI, or debugging its exit codes.
---

# Unity CLI + Unity Pipeline

> Written for **Unity CLI `1.0.0-beta.12`**, **Pipeline `0.8.0-exp.1`**, **Unity `6000.6.2f1`**.
> Both tools are pre-release and flags move on every upgrade: after any `unity self-update` or
> `unity pipeline upgrade`, trust `unity <cmd> --help`, `unity commands --format json` and
> `unity list --project-path <dir> --format json` over this file, and fix the file.

Two different things that compose:

| | Unity CLI (`unity`) | Unity Pipeline (`com.unity.pipeline`) |
|---|---|---|
| Form | standalone native binary | Unity package installed into a project |
| Talks to | Unity's release/licensing services, local install root | a **running** Editor over local HTTP |
| Needs an editor running? | no | yes |
| Purpose | install/manage editors, spawn batch-mode editors | drive a live editor: test, author, inspect, iterate |

The CLI is the client, the package is the server: `unity command`/`unity list` only work once the
package is in the target project. Updating the CLI does not update the package, and vice versa.

Everyday verbs: `status`, `list`, `open`, `close`, `recompile`, `test`, `run`, `command` (alias
`cmd`), `job`. `unity --help` has the rest (`assets`, `docs`, `pipeline`, `mcp`, `editors`,
`config`, `watch`, `shell`, …), and `unity commands --grep <pattern>` finds a CLI command by
keyword across names, descriptions and options. This repo builds through `game-build`, not `unity build`.
Version-matched API docs: `unity docs GameObject --url` from the project (`--manual`, `--search`,
`--editor-version <v>`).

Run the helpers in `~/.claude/skills/unity-cli/scripts/` by absolute path: `unity-editor`,
`unity-test`, `unity-suite`, `unity-wait` (`_common.sh` is the helper library they source). Prefer
them over a hand-rolled poll loop; the pitfalls below are exactly what they exist to absorb. Invoke
them in normal use; read their source only to maintain or debug them. Offline tests for them are in
`tests/`.

## The loop

```bash
S=~/.claude/skills/unity-cli/scripts P=<project>
$S/unity-editor up "$P"                            # once: open or reuse the live editor
# edit sources
$S/unity-wait --project-path "$P" recompile        # exit 1 prints the compile errors: fix, repeat
$S/unity-test <filter> --project-path "$P"         # exit 1 lists the failing tests: fix, repeat
```

Accept a run only when `unity-test` reported no `FILTER MISMATCH` and `passed/total` is the count you
expect: a filter that matches fewer tests than you meant still goes green. The full suite runs once
at the end, through `unity-suite`.

**Project flag**: live-editor commands (`unity command`, `recompile`, `job`, `list`) take
`--project-path <dir>`; `unity assets` takes `--project <dir>`; `unity test`, `open`, `close` and
`run` take the project as a positional argument.

## One driver per project (read this first)

A Unity project is **one exclusive resource**: its GUI editor, a batch `unity test`, `unity
command`, the `Temp/UnityLockfile`, **and every source file it compiles**, its own `Assets/` plus
every package it pulls by `file:` path (here, `nono4u/Game` loads `game-core`'s packages and
`game-build`). A second driver on the same project fails ("another instance is running", a refused
`run_tests`, a mid-reload socket); editing *any* file in that compile domain while another driver
holds the editor puts it into a broken compile, a domain reload or Safe Mode. Two drivers that both
retry starve each other forever.

There is no locking mechanism; the rule is organisational and the `bees` orchestrator enforces it:

- Exactly one agent drives a project at a time, named in its brief, and no other agent edits
  sources that project compiles while it does. `game-core` and `nono4u/Game` share a compile
  domain, so one agent holds both or the other agent does non-Unity work.
- A failure because another editor/instance holds the project is **not transient**: end your turn
  and report it. Never wrap it in a loop, a `sleep`, or a "wait for the lock".
- **"Held" means a lock error on *your* project.** `unity status` listing a GUI editor on a
  *different* project is not a held project: batch `unity test` spins its own headless editor.
- **Always name the project.** A bare `unity command <tool>` connects to *whatever* editor is
  running, so with no editor on the project you meant it lands on another project's GUI editor.
  Pass `--project-path <dir>` on every `unity command`, or `unity run <project> --command …` for
  batch. The helper scripts already do.
- **No background retry loops, ever.** A `run_in_background` shell that re-launches `unity test`
  on failure keeps firing after the project has moved to someone else and disturbs their editor.
  One attempt in the foreground with a deadline; on failure read the error and decide.

## Bring up an editor: `unity-editor up`

```bash
unity-editor up [project] [--scene <path.unity>]
unity-editor down [project] [--force]
unity-editor restart [project] [--scene <path.unity>]     force-close, then up
unity-editor ensure [project] [--deadline 30]             restart only if it stays silent
```

`up` does, in order: skip `unity open` if `unity status` already shows a live editor for the
project; otherwise `unity open <project> --args "-automated"` and wait for it; `set_autotick
--enable true`; `clear_console`; `open_scene` the `--scene` you named if a different one is
active; report the active scene and its `rootCount`. Why each step exists:

- **`-automated`**: without it a modal dialog (import prompt, safe-mode prompt, API updater) can
  block the main thread with nothing to dismiss it, silently hanging every later `unity command`.
  Batch runs (`unity test`/`run`/`build`) can't show modals, so this only matters for a GUI editor
  kept open for a live session. Cheap check for a hung command: `editor_status.status ==
  "blocked_by_dialog"` names `dialog.title`/`buttons`; `GET /api/dialog` is the deeper check.
- **A Safe Mode editor looks exactly like no editor at all.** A compile error opens the project
  into Safe Mode: the Pipeline server never starts, no descriptor is written, `unity status` shows
  nothing, and every call answers "No Pipeline instance found" while the process is plainly
  running (`pgrep`). Nothing you wait for will arrive, so `up` doesn't wait: `unity-wait ready`
  checks the editor log between status polls for `Safe Mode: Only loading a subset of
  assemblies`, prints the `error CS` lines and exits 1; `unity-editor up` then force-closes that
  editor. Fix the errors and re-run `up`; leaving Safe Mode by hand never starts the server. The log is
  `<project>/Logs/Editor.log` (Unity writes the launch header to `~/Library/Logs/Unity/Editor.log`
  and then moves there); `editor_log` in `_common.sh` picks the right one, tested offline by
  `tests/editor-log.sh`. `unity pipeline list` has a `safeMode` field too, but it reads `null`
  again ~60 s after launch, so don't poll it.
- **`unity status` is `ready` only once the main thread answers.** A listener that bound its port
  while the editor is still importing/compiling reports `starting` and the command exits non-zero.
  `unity-wait ready` polls `editor_status` itself. An empty `unity status` still needs diagnosis:
  `unity pipeline list` can show a running Editor whose Pipeline server is unreachable.
- **`unity status --until-ready` is not a substitute for `unity-wait ready`.** It blocks until a
  matching editor reports `ready` (`--timeout`, default 300 s, exit 6 at the deadline), but it
  cannot see Safe Mode, and right after `editor_play` it returns `ready` at once while the next
  `unity command` still fails with a bare network error.
- **Never `unity open` a project that may already be open.** It does not check: it starts a second
  editor process on the same project, without `-automated`, and reports success with a
  `launchedPid`. `unity-editor up` checks `unity status` first.
- **`set_autotick --enable true`**: an unfocused GUI editor throttles its update loop, so
  `recompile`/`run_tests` make no progress, a full-deadline symptom with no editor activity. Batch
  editors always tick.
- **Check the active scene before `editor_play`.** `unity open` restores whatever scene was last
  open, not necessarily the boot scene. Playing the wrong one boots nothing: `editor_status` says
  `playing`, the hierarchy is bare, and view-dependent commands fail with a misleading "not
  booted". `list_open_scenes` → the boot scene must be `isActive` **and** `isLoaded`; a low
  `rootCount` on the active scene is the tell.

**Check active work before diagnosing a silent editor.** `editor_status`/`test_status` queue behind
command execution, even for detached work. Read the job/progress endpoint or the `ui_*` disk job
record first; `/api/status` and `/api/progress` stay off the main thread. With no active work or
reload, 30 s of silence means a blocked dialog or hung main thread. `unity-editor ensure` restarts
on that silence, so use it only after ruling out active work. Run `unity-editor restart` once; if
it hangs again, stop and report rather than looping.

## Tests on a live editor: `unity-test`

```bash
unity-test <filter> [--type name|assembly|category] [--mode editmode|playmode] [--project-path <dir>]
           [--deadline <s>] [--start-deadline <s>]
```

EditMode detaches (`run_tests --detach` + `unity job wait <jobId>`), so the run survives the CLI's
own HTTP timeout and the result is a real object keyed by job id, not a shared file another driver
can stomp. Jobs are in-memory: a domain reload or editor restart discards them, so finish compiling
(`unity-wait recompile`) before starting a run. PlayMode cannot detach (entering Play drops the
request), so it uses `--async_tests true` and polls `test_status`. The script refuses an **empty** filter (no filter =
the whole suite, perf benchmarks included), exits 1 on a filter that matches **zero** tests
(`FilterApplied` still echoes it), and refuses an EditMode run while `playMode != stopped` (it would
make no progress).

The `testName` filter is a case-insensitive **substring of the full test name**
(`Namespace.Class.Method(args)`), so a bare class name and a namespace-qualified one both work, and
the bare one also matches any class whose name contains it. To cover several unrelated classes, pick
a shared substring, pass `--type assembly <Name>`, or run them in batch (`unity-suite --filter`).

| | `unity-test <filter>` (live editor) | `unity test --filter` / `unity-suite --filter` (batch) |
|---|---|---|
| match | one case-insensitive substring of the full name | a pattern over the full name |
| several classes | `A\|B` is literal and matches nothing | `A\|B\|C` runs all three |
| 0 tests matched | exits 1 | `unity test` exits 0 (`total` 0); `unity-suite` exits 2 |

`run_tests` params must be **named flags**, never a JSON blob: `--json` is the *output-format*
flag, so a `--json '{...}'` positional is silently dropped and the run falls back to the whole
suite. Check `FilterApplied` in the returned result before accepting the run. **Never call `run_tests` with no filter**, not even
to "see its params".

**The one silent hang.** Pipeline logs `[PipelineTestRunner] Running N tests` but the TestRunnerApi
run never begins (no `[TestResultCollector] Run started` in the editor log). The job stays
`running`, holds the exec gate (`editor_status` times out), and `unity job cancel` does not
release it. When `unity-test` sees neither a start marker nor a terminal job state within
`--start-deadline` (default 120 s), it requests cancellation, runs `unity-editor restart` once and
retries the run; a second trip exits 2. Offline test:
`tests/unity-test-start-watchdog.sh`.

**Job completion is not operation completion.** `unity job wait <id> --project-path <dir>
--timeout 120 --format json` may report that work was *dispatched* and name a status command such
as `build_status`; follow it to the terminal result. For tests, require the actual summary: a run
with a failing test returns a successful job envelope with `Summary.Failed: 1`.

## Compiles: `unity recompile` / `unity-wait recompile`

```bash
unity recompile --project-path <dir> --timeout 120 --format json
```

The native check works on a running, stopped Editor and reports errors with file/line. Exits: 0
success, 6 compile errors (warnings too with `--strict`), 7 unreachable. `--focus` brings the
Editor forward. `compilationFailed` can be null in the CLI's `up_to_date` result;
`console_status.groundTruth.compilationFailed` is the native flag.

```bash
unity-wait [--project-path <dir>] ready      [deadline]   # editor answers; exit 1 fast on Safe Mode
unity-wait [--project-path <dir>] recompile  [deadline]   # editor_stop if playing, trigger, wait, settle
unity-wait [--project-path <dir>] job <id>   [deadline]   # ui_* job record on disk, readable through Play Mode
```

Exit 0 success, 1 failure, 2 deadline. Use `unity-wait recompile` when you need its Play Mode stop
and post-reload settling; the details it handles:

- `recompile_status` has **two completion terminals**, `completed` and `up_to_date` (a trivial
  edit, or one Unity already auto-compiled). A poll that waits only for `completed` spins to its
  deadline. Judge the compile by `failed`, not `compilationFailed`: the native flag stays true
  for a moment after a fixing compile until the domain reload clears it. An `idle`/`up_to_date`
  status with the native flag set is reported as `completed` with `failed: true`.
- `recompile_status: completed` is not a reconnect signal: the domain reload lands after it, so
  the very next command can hit a mid-reload editor and fail with a bare network error.
  `unity-wait` requires two consecutive answers before calling it clean.
- `unity command` failing with unreachable/timeout while the editor is mid-reload is "still
  working", not a failure. Always set a deadline.
- A recompile is **deferred while the Editor is in Play Mode**: the request hangs until Play
  exits, and the editor silently keeps running old code. `unity-wait recompile` does `editor_stop`
  first (`UNITY_WAIT_NO_STOP=1` to fail fast instead) and does not resume Play; call `editor_play`
  yourself if you still need it.

## Full clean suite: `unity-suite`

```bash
unity-suite [project] [--failed-only <report.xml>] [--mode EditMode|PlayMode] [--timeout <s>]
            [--filter <A|B>] [--assemblies <A;B>]
```

`--filter` joins class names with `|` and `--assemblies` joins assembly names with `;`, e.g.
`--assemblies "Pipeline.UI.Tests;Pipeline.UI.CoreTests;Pipeline.UI.Live.Tests"`. The script refuses a
comma in either and exits 2 when the report holds 0 tests, since `unity test` itself exits 0 then.

A Play Mode session poisons a live editor for full-suite runs, so the suite runs in a fresh batch
editor holding no lock. The script closes any live editor, runs `unity test` with an explicit
`--output` and `--timeout` (default 1800 s; the CLI's own default is *no* timeout), reopens the editor afterward if one was open, and parses the NUnit XML for pass/fail
rather than guessing from the exit code. Under the count line it prints
`report: <path> · finished <HH:MM>`, so a quoted result shows which run it came from. With a compile error it exits 2 in ~10 s listing the
`error CS` lines and does **not** reopen the editor (that would only enter Safe Mode): fix, then
`unity-editor up`.

### Running `unity test` by hand

```bash
unity test --mode EditMode <project> --filter <filter> --output /abs/path/report.xml --timeout 900
```

- **Use an absolute `--output`.** The default `test-results.xml` resolves against the shell's cwd,
  not the project, so a run from elsewhere looks exactly like a run that never happened.
- **Read the XML, not just the exit code.** Failing tests and usage errors both surface as 2; a
  run with no fresh report (filter matched nothing, compile error, editor died) exits non-zero
  with a message naming which.
- **Raw NUnit args go after `--`, CLI flags before it.** `… -- -testCategory '!Integration'` is
  honoured but nothing echoes it; `… -- --output x.xml` is swallowed by NUnit. Category-only
  filtering (no `--filter`) hits an exit-2 CLI bug that still writes a real report; always
  combine it with `--filter`.
- **`--filter`** (see the filter table above): `UIParity` matches `UIParityDiffTests` and
  `UIParityTrackingTests`. `--type class <BareName>` matches 0 tests. Take names from
  `grep -rl 'class .*Tests'`.
- **Pick assemblies with `-- -assemblyNames "A;B"`**; `unity test` has no assembly flag of its own.
  The list is semicolon-separated.
- **0 tests is a silent green.** A comma-joined `--filter` or `-assemblyNames`, or a class the
  filter doesn't cover, still exits 0 with a well-formed XML whose `total` is 0. Always check
  `total`; `unity-suite` does it for you.
- Per-project defaults (mode, report format, timeout, target) can be committed in
  `ProjectSettings/UnityCliConfig.json`; `unity config resolve <key>` shows which layer won.
- A Pipeline.UI run is ~2 min. If a foreground call hits the shell timeout, `pgrep -fl 'unity
  test'` before re-attempting: a leftover batch editor is a held project, not a transient error.
- A batch run that prints `attempt to write a readonly database` then `Licensing initialization
  failed` may **hang instead of exiting** (no XML, no `Temp/UnityLockfile`). That is a stuck
  licensing client: report it as environmental and do not commit, the unit has no evidence. One
  second invocation is allowed to get a clean error; never poll the first for minutes.

## Exit codes and result envelopes

| Code | Meaning |
|---|---|
| 0 | success |
| 1 | general error |
| 2 | usage error (`INVALID_COMMAND_ARGS`, honoured in JSON/NDJSON); failing tests also surface here |
| 3 | authentication failure |
| 4 | precondition not met (no license, floating server not configured) |
| 6 | editor process failure; `recompile`: compile failure |
| 7 | service unreachable |
| 9 | `install`, `install-modules`, `projects require` with `--no-wait`/`--wait-timeout`: another install holds the lock (`INSTALL_LOCK_BUSY`); retry later |
| 130 | user cancelled |
| 143 | SIGTERM |

Batch commands collapse most failures into 6, so use the NUnit XML or the JSON envelope to learn
*why*. `unity command` returns a structured envelope (`{ "success", "command", "data", "errors",
"warnings" }`): branch on `.success`/`.errors`, and inspect nested `data.result.success` when
present (a failed `eval` can still report top-level success). `--result-only` prints just the
tool's result as parsed JSON, which is all a script usually wants (not combinable with
`--detach`). Nine `*_status` commands (`recompile_status`, `test_status`, …) return a parsed object
in `data.result`; other commands may still return a JSON-encoded **string** there, so decode
defensively (`_common.sh`'s `result_json` handles both shapes).

For headless diagnostics: `unity run <project> --command <name> --log-file /abs/path/editor.log
--timeout 120 -- <tool flags>` writes and streams a per-run log (`--no-tail` to write only).

## Reference

Read the one you need when the task reaches it:

- [`reference/command-tools.md`](reference/command-tools.md) — before passing `unity command`
  parameters, reading the console, writing an `eval`/`run_script`, or polling from the client
  (`wait_for`).
- [`reference/assets-batch.md`](reference/assets-batch.md) — importing/exporting
  `.unitypackage`s, `find_assets`, import settings, or a transactional `batch`.
- [`reference/editor-api.md`](reference/editor-api.md) — before a destructive or non-undoable
  tool (`confirm`/`dry_run`, `save_all`, Play Mode as a scoped borrow), the direct HTTP API, code
  reload without a domain reload, or capturing the game view.
- [`reference/upgrades.md`](reference/upgrades.md) — before an upgrade (the `unity-cli-upgrade` skill
  runs it), or when an asmdef declares Pipeline commands.
