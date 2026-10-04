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
- Upgrades run through the `unity-cli-upgrade` skill ("Upgrade the CLI", "Upgrade the Pipeline
  package", "Revise the unity-cli skill"): the CLI and the package version separately, a package
  upgrade needs an Editor restart to resolve, and this skill is revised in the same pass.
  `unity self-update` also takes `--check`, `--changelog` and `--rollback`.
- **Never run `unity skill install claude-code` or `unity skill refresh`**: they write the CLI's
  embedded skill to `~/.claude/skills/unity-cli/` and overwrite this skill. **Nor `unity setup
  claude`**: it installs Unity's Claude Code plugin, whose own Unity skills would load beside this
  one. Read the embedded skill without installing it: `unity skill show` prints its SKILL.md,
  `--list` names its files and `--path references/<file>.md` prints one. It describes the CLI
  binary, not the project's Pipeline package, and its claims need the same verification as a
  changelog.
- `unity open --wait` (macOS/Linux) blocks until the editor exits and reports a crash or licensing
  failure as exit 6: for CI, not a live session.
- `unity mcp` survives recompiles (the auth token persists across domain reloads); editor restarts
  need fresh discovery.
