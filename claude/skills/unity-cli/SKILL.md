---
name: unity-cli
description: Reference for the Unity CLI (the `unity` binary) and Unity Pipeline package (`com.unity.pipeline`) — installing/managing Unity editors, batch-mode test/build, and driving a live Editor over its local HTTP API via `unity command` through an iterative code → author → test → fix loop. Load this when scripting `unity command`/`unity recompile`/`unity test`/`unity status`/`unity job`, upgrading the CLI, iterating on a live Unity editor session, or debugging Unity CLI exit codes.
---

# Unity CLI + Unity Pipeline

> Written for **Unity CLI `1.0.0-beta.11`**, **Pipeline `0.8.0-exp.1`**, **Unity `6000.6.2f1`**.
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
`config`, `watch`, `shell`, …). This repo builds through `game-build`, not `unity build`.
Version-matched API docs: `unity docs GameObject --url` from the project (`--manual`, `--search`,
`--editor-version <v>`).

Helper scripts live beside this file in `scripts/`: `unity-editor`, `unity-test`, `unity-suite`,
`unity-wait`, `_common.sh`. Prefer them over a hand-rolled poll loop; the pitfalls below are
exactly what they exist to absorb. Offline tests for them are in `tests/`.

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
the bare one also matches any class whose name contains it. It is **one** substring: `A|B` and
`A,B` are literal and match nothing (the script exits 1). To cover several unrelated classes, pick a
shared substring, pass `--type assembly <Name>`, or run them in batch (`unity-suite --filter`).
Check the printed `passed/total` is the count you expect.

`run_tests` params must be **named flags**, never a JSON blob: `--json` is the *output-format*
flag, so a `--json '{...}'` positional is silently dropped and the run falls back to the whole
suite. Check `FilterApplied` in the returned result before accepting the run. **Never call `run_tests` with no filter**, not even
to "see its params".

**The one silent hang.** Pipeline logs `[PipelineTestRunner] Running N tests` but the TestRunnerApi
run never begins (no `[TestResultCollector] Run started` in the editor log). The job stays
`running`, holds the exec gate (`editor_status` times out), and `unity job cancel` does not
release it. `unity-test` exits 2 after `--start-deadline` (default 120 s) when it sees neither a
start marker nor a terminal job state, and requests cancellation. A `queued` job or an unreadable
status does not prove the gate is stuck, so check `unity job status` and `/api/progress` first;
if every command times out, `unity-editor restart` once, then re-run. Offline test:
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
rather than guessing from the exit code. With a compile error it exits 2 in ~10 s listing the
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
- **`--filter` is a pattern over the full test name**, unlike the live `unity-test` substring:
  `UIParity` matches `UIParityDiffTests` and `UIParityTrackingTests`, and `A|B|C` runs all three
  classes in one run. `--type class <BareName>` matches 0 tests. Take names from
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

## `unity command` parameter binding

Prefer **named parameters**: `unity command ui_new --name SettingsPopup --project-path <dir>`.
Inspect the schema (`unity list`) before relying on positionals. Two collisions:

- A tool parameter named `format` collides with the CLI's global `--format`. Pass the tool's own
  flag after a bare `--`: `unity command get_serialized_fields --target X --format json -- --format value`.
- `--timeout <seconds>` before the `--` bounds the CLI request (default 30 s). `run_tests` has its
  own `timeout` (default 300 s), and it matters even under `--detach`: a run that outlives it is
  cancelled but the command **never completes**, which holds the editor's one-command exec gate
  forever (every later command times out, `job wait` never returns, `/api/progress` reads
  `active: true`; only `unity-editor restart` clears it). Pass it after the bare `--`
  (`… --detach -- --timeout 1500`); `unity-test` does, from its `--deadline`.

## Reading the console

`unity command console --project-path <dir> --level error --tail 50` (`--level log|warn|error`;
`--since <cursor> --since_session <session>` to follow, and a cursor it can't honour returns the
tail with `reset`/`dropped` true). `counts` describes the buffer, `groundTruth` the Editor's own
counts and compile state; compile errors from before capture started are backfilled.
`console_status` gives counts without entries; `clear_console` clears both buffers. There is no
`read_console` or `get_console_logs`; guessing returns `400 Command Not Found`.

To browse the live command catalog by area, `GET /api/commands?detail=tags` (see Direct HTTP)
returns one row per tag with a count, then `?tag=<tag>` lists that area. No `unity list` flag
surfaces it.

## `eval` / `eval_file` / `run_script`

- `eval --code` takes **statements, not a bare expression** (wrapped in a method body):
  `return Foo.Bar;`, not `Foo.Bar`.
- **No `using` directives**: they parse as `using (...)` statements and fail with a wall of
  `CS1001`. Fully qualify every type (`UnityEditor.PrefabUtility...`) and call extension methods
  statically (`Core.UISystemExt.PushScreen(ui, type, null)`).
- **Quoting is the hazard from a shell.** A format string like `String.Format("{0}", x)` gets
  mangled by shell/JSON escaping. Prefer a quote-free expression or `eval_file --file`.
- For a real file with `using`s and structured diagnostics, `run_script --file X --entry
  Type.Method`: compiles in memory, no domain reload; `entry` may be `async Task`; `--dry_run
  true` compiles without running.
- For a registered `[ConsoleCommand]`, `unity command devconsole --input 'g.level.mockupParity'`
  (`com.pixeption.devconsole`), not an `eval` that calls `Core.ConsoleCommands.Execute`.

**Check the structured tools before writing an `eval`**: `find_gameobjects` (filters `--name`,
`--tag`, `--type`, `--hierarchy_path`, `--include_inactive`; returns identities), `get_component_properties --target <hierarchyPath> --type T`,
`get_serialized_fields` (`-- --format value`, per the collision above), `set_serialized_field`
(writes immediately, no `dry_run`), `menu` for any `ExecuteMenuItem`. Project commands:
`assetdb_update` rebuilds the AssetMap so a freshly created prefab resolves; `ui_stacks` (Play Mode) returns `mainView`/`views`/
`popups`.

**Check `wait_for` before polling from the client**: a server-side wait on a member condition
(`--condition '{"member":"UnityEditor.EditorApplication.isPlaying","value":true}'`, ops
`equals|notEquals|greaterThan|lessThan|contains|changed`, `findType`/`target` for instance
members, `on_met.capture` to screenshot the frame it fires). Synchronous `wait_for` holds the exec
queue for its whole duration, so use it only for a short wait that nothing you still have to send
can satisfy; otherwise `--async true` and poll `wait_status`. Async waits don't survive a domain
reload.

## Assets

- `.unitypackage`: `unity assets inspect <file>` before import; `unity assets import <file>
  --project <dir>`; `unity assets export Assets/Art --output /abs/art.unitypackage --project <dir>`
  (dependencies included unless `--no-dependencies`). These spawn batch Editors: honour project
  ownership.
- `find_assets --type` matches the **main** asset type: a sprite-mode texture is `Texture2D`, not
  `Sprite`. Use `--type Texture2D`, or `search --query "t:Sprite ..."`, which resolves sub-assets.
- `find_assets --label` is an `AssetDatabase` label (`.meta`), **not** an Addressables label, so
  it cannot answer "is this registered in AssetDB".
- `get_import_settings --asset <path> [--platform]` reads the importer; `set_import_settings
  --settings '{...}' --dry_run true` previews the write.

## `batch`

Up to 200 ordered operations, transactional, one Undo step; `dry_run: true` preflights the whole
sequence. Project `ui_*` ops run inline (`ui_export` → `ui_check` verified synchronous;
`ui_apply`/`ui_render` untested inside a batch). Op shape:

```json
[{"id":"a","command":"ui_export","params":{"target":"<prefab>"}}]
```

`ui_export`'s default document path is `<documentRoot>/<PrefabName>-<guid6>/ui.yaml`, not
`<PrefabName>/ui.yaml`; a wrong guess fails `UI104 MALFORMED_DOCUMENT` naming the real path.

## Conventions

- Destructive/overwriting tools take `confirm`/`dry_run`; `dry_run` previews and **wins even if
  `confirm` is also set**; without `confirm: true` the call is refused, not defaulted.
- Asset/settings/package writes are **not** undoable (only scene/object mutations are, in one Undo
  step): validate before writing.
- Object-reference parameters (`target`, `parent`, `material`, …) accept a plain `hierarchyPath`,
  an asset path, or a bare `instanceId`.
- `save_all` after any scene-authoring sequence: `unity close` never saves, so a dirty scene is
  silently discarded.
- `set_selection --paths <asset>` / `editor_focus` after a change so a human co-working the editor
  sees it in the Inspector; `get_selection` to check what they're looking at first.
- **Play Mode is a scoped borrow.** `editor_stop` as soon as the observation that needed it is
  done; don't carry a playing editor across an edit round or leave one running at the end of a
  turn. A human looking at the editor is inspecting, not working in it, so stopping Play to get
  work done is correct.

## Direct HTTP escape hatch

The editor writes a `0600` descriptor at `<project>/Library/Pipeline/.unity-pipeline-port`:
`port`, `evalToken`, `pid`, `projectPath`, `unityVersion`, `mode`, `startedAt`, `lastHeartbeat`,
and an `info` field carrying the not-automated warning when opened without `-automated`. Every
request needs `Authorization: Bearer <evalToken>`. **Dial `127.0.0.1`, never `localhost`**: the
listener binds only the IPv4 loopback and checks the `Host` header itself, so anything but
`127.0.0.1:<port>` gets a `400` naming the expected host. The token survives a domain reload but
regenerates on editor restart, so never cache a descriptor indefinitely. A descriptor whose PID was
recycled by another process is recognised as stale.

## Code reload

`[CodeReload]`/`[OnCodeReload]` live in namespace `Unity.Pipeline.CodeReload`, assembly
`Unity.Pipeline.Attributes`; `CodeReloadRegistry`, `codereload_status`, `cleanup_codereload`.
`reload_file --filename <file>` applies edited method bodies without a domain reload. Tag target
methods with `[CodeReload]` before compiling; public or non-public, instance or static, block-bodied,
returning **void or `IEnumerator`**. The compiled backend may access only public host members;
`reload_file_editor_interpreter` reaches private members via its supported C# subset. No methods
applied is a failure; unchanged bodies report explicit up-to-date success. Inspect per-method
results for partial applies, not just top-level success.

A structural change (new entry point, new `[CliArg]`, new field) needs the full recompile flow
under Compiles above; it is deferred during Play.

## Capturing what you built

`capture_game_view` defaults to `--source screen`: the composited backbuffer including Screen
Space Overlay canvases, in Edit Mode and Play Mode alike. `--source camera` captures a camera
target only and misses overlays; passing `--camera` without `--source` also selects camera capture. `--save_path <path>` for a path-only result;
`--include_inline_image true` also returns image data. A plain `screenshot` is not a substitute for
composited screen capture.

For `Core.View` UI, use `unity-ui` (`ui_render`/`ui_validate`) or `unity-ui-live` in Play Mode,
including their rule to export again before applying after direct prefab edits.

## Package assemblies and upgrades

- **`[CliCommand]`/`[CliArg]`, `[CodeReload]`/`[OnCodeReload]` live in `Unity.Pipeline.Attributes`**
  (namespaces unchanged: `Unity.Pipeline.Commands`, `Unity.Pipeline.CodeReload`). Any asmdef that
  declares Pipeline commands must reference that assembly explicitly; referencing
  `Unity.Pipeline`/`Unity.Pipeline.Editor` does not pull it in, and the miss is a `CS0246` that
  opens the editor into Safe Mode on resolve. Loose `Assets/` scripts with no asmdef are
  unaffected (it is `autoReferenced`).
- `InstanceDescriptor`/`RuntimeInstanceDescriptor` and several internals are `internal`. Read the
  descriptor JSON directly (`port`/`evalToken` are stable) rather than referencing those types.
- Runtime Pipeline/Roslyn are excluded from non-development builds unless
  `ENABLE_RUNTIME_PIPELINE` is defined; the attributes remain usable with no reload effect.
- Upgrade the CLI with plain `unity self-update`, then `unity --version` / `unity self-update
  --changelog` (`--check`, `--rollback`). `unity pipeline upgrade --project-path <dir>` updates the
  package separately and needs an Editor restart to resolve. After either, recheck the affected
  sections here against `--help` and the package
  [changelog](https://docs.unity3d.com/Packages/com.unity.pipeline@0.8/changelog/CHANGELOG.html),
  and update the version line at the top.
- **Never run `unity skill install claude-code`**: it writes the CLI's embedded skill to
  `~/.claude/skills/unity-cli/` and overwrites this file. `unity skill show` prints that embedded
  skill to stdout; it describes the CLI binary, not the project's Pipeline package, so read it
  after a CLI upgrade and read the resolved package's `Documentation~`/CHANGELOG after a package
  upgrade.
- `unity open --wait` (macOS/Linux) blocks until the editor exits and reports a crash or licensing
  failure as exit 6: for CI, not a live session.
- `unity mcp` survives recompiles (the auth token persists across domain reloads); editor restarts
  need fresh discovery.
