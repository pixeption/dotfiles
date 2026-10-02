# Package assemblies and upgrades

Read before an upgrade of the CLI or the Pipeline package, or when an asmdef declares Pipeline
commands.


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
  sections of this skill against `--help` and the package
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
