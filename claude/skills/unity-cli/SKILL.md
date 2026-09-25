---
name: unity-cli
description: Reference for the Unity CLI (the `unity` binary) and Unity Pipeline package (`com.unity.pipeline`) — installing/managing Unity editors, batch-mode test/build, and driving a live Editor over its local HTTP API via `unity command` through an iterative code → author → test → fix loop. Load this when scripting `unity command`/`unity recompile`/`unity test`/`unity status`/`unity job`, upgrading the CLI, iterating on a live Unity editor session, or debugging Unity CLI exit codes.
---

# Unity CLI + Unity Pipeline

Two different things that compose:

| | Unity CLI (`unity`) | Unity Pipeline (`com.unity.pipeline`) |
|---|---|---|
| Form | standalone native binary | Unity package installed into a project |
| Talks to | Unity's release/licensing services, local install root | a **running** Editor over local HTTP |
| Needs an editor running? | no | yes |
| Purpose | install/manage editors, spawn batch-mode editors | drive a live editor: test, author, inspect, iterate |

The CLI is the client, the package is the server — `unity command`/`unity list` only work once the
package is in the target project.

CLI `1.0.0-beta.11`, Pipeline `0.7.0-exp.1`, Unity 6000.4.8f1 checked 2026-09-23 in game-core and
nono4u/Game: native compile checks, detached EditMode tests (20/20 and 4/4), and `console_status`.
Also checked CLI JSON/NDJSON usage errors and docs lookup; other 0.7 guidance follows the
[changelog](https://docs.unity3d.com/Packages/com.unity.pipeline@0.7/changelog/CHANGELOG.html)
and versioned docs. Older observations are dated below; PlayMode/player behavior was not reverified.
**Trust `unity <cmd> --help` and `unity list --project-path <dir> --format json` over this file.**
`unity commands --format json` describes the CLI tree; the project's resolved package and live
command schema determine Pipeline capabilities. Updating the CLI does not update that package.

Common verbs: `status`, `list`, `open`, `close`, `recompile`, `test`, `command` (alias `cmd`),
`job`. Discover the rest through `unity --help`, including read-only `pipeline cloud-build` /
`pipeline automation`, `cloud org create`, `mcp configure --server issue-tracker`, and
`editors prune --remove-missing`. This repo builds through `game-build`, not `unity build` directly.
For version-matched API docs, run `unity docs GameObject --url` from the project; use `--manual`,
`--search`, or `--editor-version <version>` as needed.

Reading the Editor console: `unity command console --project-path <dir> --level error --tail 50`
(`--level log|warn|error`, `--since <cursor> --since_session <session>` to follow; a cursor it
can't honor returns the tail with `reset`/`dropped` true). `counts` describes the buffer and
`groundTruth` the Editor's counts and compile state; compile errors from before capture started are
backfilled. `console_status` gives those counts without pulling entries; `clear_console` clears both
buffers. There is no `read_console` or `get_console_logs`, and guessing either one returns
`400 Command Not Found`.

Helper scripts live beside this file in `scripts/`: `unity-editor`, `unity-test`, `unity-suite`,
`unity-wait`, `_common.sh`. Prefer them over hand-rolling a poll loop — the pitfalls
below are exactly what they exist to paper over.

## One driver per project (read this first)

A Unity project is **one exclusive resource**: its GUI editor, a batch `unity test`, `unity
command`, the `Temp/UnityLockfile`, **and every source file it compiles** — its own `Assets/` plus
every package it pulls by `file:` path (for this repo, `nono4u/Game` loads `game-core`'s packages
and `game-build`). A second driver on the same project fails ("another instance is running", a
refused `run_tests`, a mid-reload socket); an editor of *any* file in that compile domain while
another driver holds the editor puts it into a broken compile, a domain reload or Safe Mode. Two
drivers that both retry starve each other forever.

There is no locking mechanism; the rule is organisational and the `bees` orchestrator enforces it:

- Exactly one agent drives a project at a time, named in its brief, and no other agent edits
  sources that project compiles while it does. In this repo `game-core` and `nono4u/Game` share a
  compile domain, so one agent holds both or the other agent does non-Unity work.
- If a command fails because another editor/instance holds the project, that is **not** a transient
  condition: end your turn and report it. Never wrap it in a loop, a `sleep`, or a "wait for the
  lock".
- **"Held" means a lock error on *your* project.** `unity status` listing a GUI editor on a
  *different* project (e.g. nono4u/Game while you drive game-core) is not a held project: batch
  `unity test` spins its own headless editor. Two agents stopped on that misread (2026-09-19).
- **Always name the project.** A bare `unity command <tool>` connects to *whatever* editor is
  running — with no editor on the project you meant, it lands on another project's GUI editor
  (observed: `ui_seed` probes executed on nono4u's editor while working game-core). Pass
  `--project-path <dir>` on every `unity command`, or use `unity run <project> --command …` for
  batch; the helper scripts already do.
- **No background retry loops, ever.** A `run_in_background` shell that re-launches `unity test`
  on failure keeps firing after the project has moved to someone else and disturbs their editor
  (observed: 8 blind batch runs against a project another agent was using). One attempt in the
  foreground with a deadline; on failure read the error and decide.

## Bring up an editor: `unity-editor up`

```bash
unity-editor up [project] [--scene <path.unity>]
unity-editor down [project] [--force]
unity-editor restart [project] [--scene <path.unity>]     force-close, then up
unity-editor ensure [project] [--deadline 30]             restart only if it stays silent
```

**Check active work before diagnosing a silent editor.** `editor_status`/`test_status` can queue
behind command execution, even for detached work. Read the job/progress endpoint or the `ui_*`
disk job record first; Pipeline's `/api/status` and `/api/progress` stay off the main thread.
With no active work or reload, 30 s of silence suggests a blocked dialog or hung main thread.
`unity-editor ensure` restarts on that silence, so use it only after ruling out active work.
Run `unity-editor restart` once; if it hangs again, stop and report rather than looping.

`up` does, in order: skip `unity open` if `unity status` already shows a live editor for the
project; otherwise `unity open <project> --args "-automated"` then wait for it; `set_autotick
--enable true`; `clear_console`; `open_scene` the `--scene` you named if a different one is active;
report the active scene and its `rootCount`. Reasons each step exists:

- **`-automated`**: without it, a modal dialog (import prompt, safe-mode prompt, API-update) can
  block the main thread with nothing to dismiss it, silently hanging every subsequent `unity
  command` against that instance. Batch-mode runs (`unity test`/`run`/`build`) can't show modal
  popups, so this only matters for a GUI editor kept open for a live session. Cheap check for a
  hung command: `editor_status.status == "blocked_by_dialog"` names `dialog.title`/`buttons`;
  `GET /api/dialog` is the deeper check.
- **A safe-mode editor looks exactly like no editor at all.** A compile error opens the project
  into Safe Mode: the pipeline server never starts, no descriptor file is written, `unity status`
  shows nothing, and every call answers "No Pipeline instance found" while the process is plainly
  running (`pgrep`). Nothing you wait for will ever arrive, so `up` doesn't: `unity-wait ready`
  watches `~/Library/Logs/Unity/Editor.log` for the `Safe Mode: Only loading a subset of
  assemblies` line (the log rotates per launch and names its project, so it is the right log),
  prints the `error CS` lines, and `up` force-closes that editor and exits 1 within ~15 s. Fix
  the errors, re-run `up` — leaving safe mode by hand never starts the server. (`unity pipeline
  list` has a `safeMode` field too, but it reads `null` again ~60 s after launch — don't poll it.)
  A batch `unity test` with the same error aborts in ~15 s with "Scripts have compiler errors"
  and no report; `unity-suite` prints the errors and leaves the editor closed instead of
  reopening it into Safe Mode.
- **`unity status` is `ready` only once the main thread answers** (beta.10): a listener that
  binds its port while the editor is still importing/compiling reports `starting`, and the
  command exits non-zero. `unity-wait ready` polls `editor_status` itself, so this is only
  relevant when you read `unity status` by hand. The beta.8 bug where a healthy editor showed no
  instance at all (a stale-token `401` after a recompile, a descriptor the CLI refused to read
  before parsing the manifest) is fixed in beta.10. An empty `unity status` still needs diagnosis:
  `unity pipeline list` can show a running Editor whose Pipeline server is unreachable.
- **`set_autotick --enable true`**: an unfocused GUI editor throttles its update loop, so
  `recompile`/`run_tests` make no progress — a full-deadline symptom with no editor activity.
  Batch-mode editors always tick, so they don't need this.
- **Check the active scene before `editor_play`.** `unity open` restores whatever scene was last
  open, not necessarily the project's boot scene. Playing the wrong one boots nothing —
  `editor_status` still reports `playing`, but the hierarchy is bare and any view-dependent command
  fails with a misleading "not booted" error. `list_open_scenes` → confirm the boot scene is
  `isActive: true` **and** `isLoaded: true` (a low `rootCount` on the active scene is the tell).

## Waiting on a live editor

### Tests: `unity-test`

```bash
unity-test <filter> [--type name|assembly|category] [--mode editmode|playmode] [--project-path <dir>]
```

EditMode detaches (`run_tests --detach` + `unity job wait <jobId>`), so it survives the domain
reload a compile causes, and the result is a real object keyed by job id (not a shared file another
driver can stomp). PlayMode cannot detach — entering Play mode drops the request — so it uses
`--async_tests true` and polls `test_status` instead. An **empty** filter is refused (no filter =
the whole suite, perf benchmarks included); a filter that matches **zero** tests runs zero and is
exit 1 (`FilterApplied` still echoes it); and it refuses an EditMode run while
`playMode != stopped` (an EditMode run launched during Play makes no progress).

`run_tests` params must be **named flags**, never a JSON blob — `--json` is the *output-format*
flag, so a `--json '{...}'` positional is silently dropped and the run falls back to the whole
suite. Confirm the response's `FilterApplied` echoes what you asked for before waiting. **Never
call `run_tests` with no filter**, even just to "see its params" — that starts a full run.

**Job completion versus operation completion (beta.11):** `unity job wait <id> --project-path
<dir> --timeout 120 --format json` may report that work was *dispatched* and name a status command
such as `build_status`. Follow that command to the operation's terminal result; dispatch is not
success. For tests, require the actual test summary/filter, not just a successful job envelope:
the verified failed-test run returned top-level success but `Summary.Failed: 1`.
The older `--async_tests true` + `Temp/pipeline_test_status.json` route uses a shared status file.

### Compiles: `unity recompile` / `unity-wait recompile`

For a running, stopped Editor, beta.11 adds a native compile check:

```bash
unity recompile --project-path <dir> --timeout 120 --format json
```

It reports errors with file/line; documented exits are 0 success, 6 compile errors, 7 unreachable.
Verified clean `completed`/`up_to_date` and unreachable results; compile-error/strict-warning exits
remain documentation-based. `compilationFailed` can be null in the CLI's `up_to_date` result;
Pipeline 0.7 `console_status.groundTruth.compilationFailed` provides the native flag.
`--strict` also fails on warnings; `--focus` brings the Editor forward. Keep `unity-wait recompile`
when you need its existing PlayMode stop and post-reload settling behavior; native equivalence for
those steps has not been verified. Both require a reachable Pipeline server.

`recompile_status` has **two completion terminals**: `completed` and `up_to_date` (a trivial edit, or
one Unity already auto-compiled, finishes as `up_to_date` — a poll that waits only for `completed`
spins to its deadline on a compile that's already done). 0.7 adds `compilationFailed`, read from
Unity's native flag: a repeat `recompile` with errors still standing no longer erases them into
a false `up_to_date`; check failure fields before declaring success. `console_status` returns
the native flag and counts without entries. `data.result` can be a JSON-encoded string — decode
it if needed, or use `--result-only`. `unity command` can fail (unreachable/timeout) while
the editor is mid-domain-reload — that's "still working", not a failure; always set a deadline.

```bash
unity-wait ready      [deadline]   # editor answers at all
unity-wait recompile  [deadline]   # trigger + wait + print compile errors, exit 1 if any
unity-wait job <id>   [deadline]   # ui_* job, readable straight through PlayMode
```

Exit 0 success, 1 failure, 2 deadline.

### Full clean suite: `unity-suite`

```bash
unity-suite [project] [--failed-only <report.xml>] [--mode EditMode|PlayMode]
```

The Game/CLAUDE.md rule: a Play-mode session poisons the live editor for full-suite runs, so the
suite must run in a fresh batch editor holding no lock. This script closes any live editor
(`unity close`), runs `unity test`, reopens the editor afterward if one was open, and parses the
NUnit XML report for pass/fail rather than guessing from a generic nonzero exit.
With a compile error it exits 2 in ~10 s listing the `error CS` lines and does **not** reopen the
editor (that would only put it into Safe Mode) — fix, then `unity-editor up`.

### Batch tests: use an explicit report path

Earlier runs produced no stdout, and a 1719/0 run exited `1` (2026-09-12; not rechecked on beta.11).
Read a fresh NUnit XML report as well as the CLI envelope/exit code. The default `--output
test-results.xml` is resolved against **the shell's cwd, not the project** — `unity test
../other-project …` run from `myproject/` writes `myproject/test-results.xml`, and a
`ls ../other-project/test-results.xml` afterwards says "no such file", which reads exactly like a run that
never happened (observed 2026-09-12: three back-to-back re-runs of a suite that had passed the first
time). Use an absolute `--output` and an explicit process timeout:

```bash
unity test --mode EditMode <project> --filter <filter> --output /abs/path/report.xml --timeout 900
```

beta.10 makes one case honest: a run that produced no fresh report (filter matched nothing,
compile error, editor died) now exits non-zero with a message naming which, instead of "results
could not be converted to JUnit". Per-project defaults for `unity test`/`unity build` (mode,
report format, timeout, target) can be committed in `ProjectSettings/UnityCliConfig.json`;
`unity config resolve <key>` shows which layer supplied a value.

Earlier test-run traps (2026-09-18; not reverified on beta.11):

- **Failing tests were observed to make `unity test` exit 2** — also the documented usage-error code. Do
  not chase the CLI syntax; open the XML, the failure is in there.
- **Raw NUnit args go after `--`, CLI flags before it.** `unity test … -- -testCategory '!Integration'`
  is honoured but nothing echoes that it was; `… -- --output x.xml` is swallowed by NUnit and the
  report lands in the cwd under the default name. Category-only filtering (no `--filter`) hits an
  exit-2 CLI bug that still writes a real report — always combine it with `--filter`.
- **`--filter` is a class-name substring match**, so `--filter UIParity` matches `UIParityDiffTests`
  and `UIParityTrackingTests` alike, and a class the filter does not cover runs 0 tests silently.
  Take the names from `grep -rl 'class .*Tests'` and check the XML's `total` per filter.
- **`--type class <BareName>` matches 0 tests**; the default substring filter is the one that works.

A Pipeline.UI run is ~2 min; if a foreground call does hit the shell timeout, `pgrep -fl 'unity
test'` / `pgrep -fl "projectpath <project>"` before re-attempting — a leftover batch editor is a
held project, not a transient error. `unity-suite` passes an explicit `--output` for this reason.
A batch run that prints `attempt to write a readonly database` and then `Licensing initialization
failed` may **hang instead of exiting** (no XML, no `Temp/UnityLockfile`). That is a stuck licensing
client, not a live held project: report it as environmental, and do not commit — the unit has no
evidence. One second invocation is allowed to get a clean error; never poll the first for minutes.

## Exit codes and result envelopes

An Editor process failure can surface as **6** through batch commands; test-report failures and
CLI usage errors have also surfaced as 2. Use the command's contract plus NUnit XML or the JSON
envelope to determine *why* it failed. Beta.11 CLI usage errors honor JSON/NDJSON with
`INVALID_COMMAND_ARGS`, exit 2 (JSON and NDJSON unknown-option cases checked locally).

`unity command` is different — it returns a structured envelope
(`{ "success", "command", "data", "errors", "warnings" }`), so branch on `.success`/`.errors`
directly; `--result-only` (beta.10) prints just the tool's result as parsed JSON, which is all a
script usually wants (not combinable with `--detach`). Earlier `unity run --command` runs reported
exit 0/top-level success on a failed `eval`; inspect nested `data.result.success` when present too
(not reverified on beta.11). For headless diagnostics, `unity run <project> --command <name>
--log-file /abs/path/editor.log --timeout 120 -- <tool flags>` writes and streams a per-run log;
add `--no-tail` to write it without streaming.

| Code | Meaning |
|---|---|
| 0 | success |
| 1 | general error |
| 2 | usage error |
| 3 | authentication failure |
| 4 | precondition not met (no license, floating server not configured) |
| 6 | editor process failure; `recompile`: compile failure (warnings too with `--strict`) |
| 7 | service unreachable |
| 130 | user cancelled |
| 143 | SIGTERM |

## `unity command` parameter binding

Prefer **named parameters**: `unity command ui_new --name SettingsPopup --project-path <dir>`.
Older routes silently dropped positionals; newer Pipeline schemas can bind them, so inspect the
schema before relying on them. CLI usage errors exit 2; editor-side argument rejection may have
a different exit contract — always inspect `.success`/`.errors` for `INVALID_COMMAND_ARGS`.

Two collisions to know:

- A tool parameter named `format` collides with the CLI's own global `--format`. Pass the tool's
  own flag after a bare `--`: `unity command get_serialized_fields --target X --format json --
  --format value`.
- `--timeout <seconds>` bounds the CLI request (default 30s) but collides with a tool's own
  `timeout` parameter (`run_tests` has one) — for anything long, prefer `--detach` + `unity job
  wait` over fighting it.

## `eval` / `eval_file` / `run_script`

- `eval`'s code parameter is `--code`; takes **statements, not a bare expression** (the code is
  wrapped in a method body) — `return Foo.Bar;`, not `Foo.Bar`.
- **No `using` directives** — they parse as `using (...)` resource statements and fail with a wall
  of `CS1001` pointing at your `using` lines. Fully-qualify every type
  (`UnityEditor.PrefabUtility...`), and call extension methods statically
  (`Core.UISystemExt.PushScreen(ui, type, null)`, not `ui.PushScreen(type)`).
- **Quoting is the real hazard from a shell** — a format string like `String.Format("{0}", x)` gets
  mangled by shell/JSON escaping. Prefer a quote-free expression, or use `eval_file --file` with the
  code in a file.
- For a real file with `using`s and structured diagnostics, use `run_script --file X --entry
  Type.Method` instead — compiles in memory, no domain reload; `entry` may be `async Task`;
  `--dry_run true` compiles without running.

- For a registered `[ConsoleCommand]`, use `unity command devconsole --input 'g.level.mockupParity'`
  (`com.pixeption.devconsole`), not an `eval` that calls `Core.ConsoleCommands.Execute` by hand.

**Before polling from the client, check `wait_for`** (0.7): a server-side wait on a member
condition (`--condition '{"member":"UnityEditor.EditorApplication.isPlaying","value":true}'`,
ops `equals|notEquals|greaterThan|lessThan|contains|changed`, `findType`/`target` for instance
members, `on_met.capture` to screenshot in the very frame it fires). Synchronous `wait_for`
holds the one-command exec queue for its whole duration, so use it only for a short wait that
nothing you still have to send can satisfy; otherwise `--async true` and poll `wait_status`.
Async waits don't survive a domain reload.

**Before writing an `eval`, check the structured tools first**: `find_gameobjects` (locate by
`hierarchyPath`/`instanceId`), `get_component_properties --target <hierarchyPath> --type T` (whole
component as a map), `get_serialized_fields` (`--format value` after a bare `--`, per the collision
above), `set_serialized_field` (writes immediately — no `dry_run`). Two project commands beyond
those: `assetdb_update` rebuilds the AssetMap so a freshly-created prefab resolves (replaces the old
eval/menu workaround — the eval assembly can't reference Addressables editor APIs); `ui_stacks`
(Play mode) returns the screen/popup/toast stacks — `mainView`/`views`/`popups`. `menu` covers any
other `ExecuteMenuItem`.

## Assets

- For `.unitypackage` files, use `unity assets inspect <file>` before import. Import with
  `unity assets import <file> --project <dir>`; export with `unity assets export Assets/Art
  --output /abs/path/art.unitypackage --project <dir>`. Dependencies are included unless
  `--no-dependencies` is set. These import/export operations use batch Editors: honor project ownership.
- `find_assets --type` matches the asset's **main** type — a sprite-mode texture is `Texture2D`,
  not `Sprite` (the Sprite is a sub-asset). Use `--type Texture2D`, or `search --query "t:Sprite
  ..."`, which resolves sub-assets.
- `find_assets --label` is an `AssetDatabase` label (`.meta`), **not** an Addressables label — it
  cannot answer "is this registered in AssetDB", since `RegisterUIViewsCmd`'s `view` label lives in
  the Addressables settings asset.
- `get_import_settings --asset <path> [--platform]` reads the importer; `set_import_settings
  --settings '{...}' --dry_run true` previews the write.

## `batch`

Up to 200 ordered operations, transactional, one Undo step, `dry_run: true` preflights the whole
sequence before committing to it. Project `ui_*` ops run inline (verified: `ui_export`→`ui_check`
ran synchronously, no job — `ui_apply`/`ui_render` untested inside a batch). Op shape:

```json
[{"id":"a","command":"ui_export","params":{"target":"<prefab>"}}]
```

`ui_export`'s default document path is `<documentRoot>/<PrefabName>-<guid6>/ui.yaml`, not
`<PrefabName>/ui.yaml` — a wrong guess fails `UI104 MALFORMED_DOCUMENT` naming the real path.

## Conventions

- Destructive/overwriting tools take `confirm`/`dry_run`; `dry_run` previews and **wins even if
  `confirm` is also set**; without `confirm: true` the call is refused, not defaulted.
- Asset/settings/package writes are **not** Ctrl+Z-undoable (only scene/object mutations are, in
  one Undo step) — validate before writing.
- Object-reference parameters (`target`, `parent`, `material`, ...) accept a plain `hierarchyPath`
  string, an asset path, or a bare `instanceId` — no JSON handle needed.
- `save_all` after any scene-authoring sequence — `unity close` never saves, so a dirty scene is
  silently discarded.
- `set_selection --paths <asset>` / `editor_focus` after a change, so a human co-working the same
  editor sees the result in the Inspector; `get_selection` to check what they're looking at first.

## Direct HTTP escape hatch

The editor writes a `0600` descriptor at `<project>/Library/Pipeline/.unity-pipeline-port`:
`port`, `evalToken`, plus `pid`/`projectPath`/`unityVersion`/`mode`/`startedAt`/`lastHeartbeat`, and
an `info` field carrying the not-automated warning when the editor was opened without
`-automated`. Every request needs `Authorization: Bearer <evalToken>`. **Dial `127.0.0.1`, never
`localhost`** — Unity's Mono `HttpListener` answers the IPv6 loopback (`::1`) with `400`, and
`localhost` resolves non-deterministically between the two. The token survives a domain reload but
regenerates on editor restart.

## Code reload

Current [Pipeline 0.7 docs](https://docs.unity3d.com/Packages/com.unity.pipeline@0.7/manual/code-reload.html)
use `[CodeReload]`/`[OnCodeReload]`, namespace `Unity.Pipeline.CodeReload`, `CodeReloadRegistry`,
and `codereload_status`/`cleanup_codereload`. The previously installed 0.6 package had `HotReload` APIs despite
the published changelog dating the rename to 0.6: inspect the resolved package before choosing names.

`reload_file --filename <file>` applies edited method bodies without a domain reload. Tag entry
methods before compiling/entering Play; they must be **public**, returning **void or `IEnumerator`**.
The compiled backend may access only public host members; `reload_file_editor_interpreter` reaches
private members via its supported C# subset. Current docs fix Editor registration on entering Play
even when the runtime server is disabled; manual registration is an older-package workaround, not
the default. No methods applied is a failure; unchanged bodies can report explicit up-to-date success.
Inspect per-method results/diagnostics for partial applies, not just top-level success.

A full recompile is **deferred while the Editor is in Play Mode** — `unity command recompile`
hangs until Play Mode exits, so a playing editor silently keeps running old code. To load a
structural change (new entry point, new `[CliArg]`, new field) into a playing editor: `editor_stop` →
recompile (now completes) → `editor_play`. `unity-wait recompile` does the `editor_stop` for you
(set `UNITY_WAIT_NO_STOP=1` to fail fast instead) — it does not resume Play, so call `editor_play`
yourself if you still need it.

**Play Mode is a scoped borrow.** `editor_stop` as soon as the observation that needed it is done —
don't carry a playing editor across an edit round or leave one running at the end of a turn. The
editor is the agent's working surface during a run; a human looking at it is inspecting, not
working in it, so stopping Play to get work done is correct, not disruptive.

## Caveats

- Pre-release — flags move on every upgrade.
- **0.6 narrowed the package's public API**: `InstanceDescriptor`/`RuntimeInstanceDescriptor` and
  several internals used by `com.pixeption.pipeline-ui` became `internal`, which put the editor
  into Safe Mode with six `CS0122` errors on that upgrade. If you need the descriptor's fields,
  read the JSON file directly (`port`/`evalToken` are stable, documented) rather than referencing
  those model types.
- **0.7 runtime builds:** `[CodeReload]`/`[OnCodeReload]` live in `Unity.Pipeline.Attributes`;
  asmdefs using them must reference it. Runtime Pipeline/Roslyn are excluded from non-development
  builds unless `ENABLE_RUNTIME_PIPELINE` is defined; attributes remain usable with no reload effect.
- Upgrade with **plain `unity self-update`**, then `unity --version` / `unity self-update --changelog`.
  Use `--check` to inspect availability or `--rollback` to undo; override channels only when requested.
  `unity pipeline upgrade --project-path <dir>` separately updates the package and needs an Editor
  restart to resolve. `unity skill refresh` updates the package's mirrored skill, not this file:
  recheck affected sections against command help and both changelogs after an upgrade.
- `unity open --wait` (macOS/Linux) blocks until the editor exits and reports a crash or
  licensing failure as exit 6 — for CI, not for a live session. A descriptor whose PID was
  recycled by another process is now recognised as stale rather than dialled.
- **Do not install the package's own `unity-pipeline` skill alongside this one** — `unity skill
  install claude-code --local` mirrors it into the project and it shares this skill's trigger.
  It's useful to read once after each `unity pipeline upgrade` (it's guaranteed version-matched)
  but two skills answering the same trigger is a conflict, not a redundancy.
- `unity mcp` can survive recompiles: Pipeline has persisted the auth token across domain reloads
  since 0.4. Editor restarts require fresh discovery/token; do not cache a descriptor indefinitely.

## Capturing what you built

`capture_game_view` defaults to `--source camera`, which misses **Screen Space Overlay** canvases.
Since Pipeline 0.4, `--source screen` captures the composited backbuffer, including overlays, in
**Play Mode only**. Use `--save_path <path>` for a path-only result; `--include_inline_image true`
also returns image data. A plain `screenshot` is not a substitute for composited screen capture.

For `Core.View` UI, use `unity-ui` (`ui_render`/`ui_validate`) or `unity-ui-live` in Play Mode.
Follow those skills' prefab/document workflow, including exporting again before applying after
direct prefab edits.
