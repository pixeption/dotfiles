# Assets and `batch`

## Assets

- `.unitypackage`: `unity assets inspect <file>` before import; `unity assets import <file>
  --project <dir>`; `unity assets export Assets/Art --output /abs/art.unitypackage --project <dir>`
  (dependencies included unless `--no-dependencies`). These spawn batch Editors: honour project
  ownership. Note the flag: `unity assets` takes `--project`, not the `--project-path` every
  live-editor command takes.
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
