# `unity command` tools

Parameter binding, the console, `eval`/`run_script` and the structured tools to check before an
`eval`. Every call names its project with `--project-path <dir>` (see SKILL.md, "One driver per
project").

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

To browse the live command catalog, `unity command --project-path <dir>` with no command name
lists the editor's tags with a command count each; `--tag <tag>` lists that area's commands and
their parameters, `--query <term>` filters by substring of name, description or tag, and
`--detail full` returns the whole catalog. Under `--format json` the rows are `data.tags`
(`tag`, `count`) for the tag index and `data.commands` otherwise.

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

**Prove Play Mode is advancing before trusting what you observe in it.** `editor_status:
playing` and a captured frame both look healthy on a game frozen at frame 1. Once the editor
answers again after `editor_play`:

```bash
unity command wait_for --project-path <dir> --result-only -- \
  --condition '{"member":"UnityEngine.Time.frameCount","op":"changed"}' --timeout_s 10
```

`met: true` with `framesObserved` above 0 is the proof; `timedOut: true` means a frozen player
loop, so check `set_autotick` first.
