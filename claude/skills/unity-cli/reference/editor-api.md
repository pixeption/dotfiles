# Editor conventions and APIs

Conventions for writing tools, the direct HTTP escape hatch, code reload and capturing the view.

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
in SKILL.md ("Compiles"); it is deferred during Play.

## Capturing what you built

`capture_game_view` defaults to `--source screen`: the composited backbuffer including Screen
Space Overlay canvases, in Edit Mode and Play Mode alike. `--source camera` captures a camera
target only and misses overlays; passing `--camera` without `--source` also selects camera capture. `--save_path <path>` for a path-only result;
`--include_inline_image true` also returns image data. A plain `screenshot` is not a substitute for
composited screen capture.

For `Core.View` UI, use `unity-ui` (`ui_render`/`ui_validate`) or `unity-ui-live` in Play Mode,
including their rule to export again before applying after direct prefab edits.
