---
name: unity-cli-upgrade
description: >-
  Checks for and applies upgrades of the `unity` CLI and the Unity Pipeline package (`com.unity.pipeline`) in the Unity projects nono4u/GameCore and nono4u/Game unless others are named, then reads the changelogs and revises the unity-cli skill to match. Use when the user asks to check, update or upgrade the Unity CLI, the pipeline package or "unity tooling", or says "unity-cli-upgrade".
---

# Upgrade the Unity CLI and the Pipeline package

Three jobs in order: upgrade the CLI, upgrade the Pipeline package per project, then bring the
`unity-cli` skill in line with what changed. The CLI and the package version independently, so
either can be current while the other is behind. The skill revision is part of the upgrade: both
tools are pre-release, and a skill describing yesterday's flags misleads every later session.

Load the `unity-cli` skill first; its "One driver per project" rule governs every step that touches
a project here.

## Check

```bash
S=~/.claude/skills/unity-cli-upgrade/scripts
$S/unity-cli-upgrade-check                        # nono4u/GameCore and nono4u/Game
$S/unity-cli-upgrade-check <project-dir>...       # exactly the projects the user named
```

Read-only. One row for the CLI and one per project, each ending `ok` or `UPGRADE`. Exit 0 means
everything is latest: report that and stop. Exit 10 means at least one row needs an upgrade; do
only those rows. If the user asked only to check, report the rows and stop.

Projects the user names replace the defaults unless they say "also".

## Upgrade the CLI

```bash
W=<scratch-dir>/unity-cli-upgrade && mkdir -p "$W"
unity skill show > "$W/skill-before.md"                  # the binary's own skill, for the diff below
unity skill show --list > "$W/skill-files-before.txt"
unity self-update --changelog > "$W/cli-changelog.txt"   # release notes of the target version
unity self-update --yes
unity --version                                          # must print the version the check called latest
unity skill show > "$W/skill-after.md"
diff "$W/skill-before.md" "$W/skill-after.md" > "$W/skill.diff"
unity skill show --list | diff "$W/skill-files-before.txt" -   # new embedded reference files
```

`--changelog` covers the target version only. When the update crosses more than one version, read
each one in between with `unity changelog --target <version>`. Read a new embedded reference file
with `unity skill show --path <file>`.

Take the snapshot before updating, because the binary carries only its own version's skill and
notes. If the new binary misbehaves, `unity self-update --rollback` restores the previous one;
report that instead of working around a broken CLI.

## Upgrade the Pipeline package

One project at a time, game-core before any project that consumes its packages, since a consumer
compiles game-core's Pipeline commands and breaks with them.

1. Note the project's current pin (the check printed it) so the changelog range is known.
2. `unity pipeline upgrade --project-path <dir> --format json`. Require `"upgraded": true`; it
   rewrites the pin in `Packages/manifest.json`.
3. In a repo that owns packages, bump their declared dependency to the same version, so a consumer
   resolving them from git gets a consistent set:
   `grep -ln '"com.unity.pipeline"' <repo>/Packages/*/package.json`.
4. Restart the editor so it resolves the package, then compile:

   ```bash
   U=~/.claude/skills/unity-cli/scripts
   $U/unity-editor restart <dir>
   $U/unity-wait --project-path <dir> recompile
   ```

   A Safe Mode exit here means the new package broke a source file. Fix the root cause in the
   owning package; never pin back silently. If it cannot be fixed cleanly, restore the old pin with
   `unity pipeline install --project-path <dir> --package-version <old>` and report why.
5. Run the suites the repo's CLAUDE.md names for a tooling change, through `unity-suite`.
6. Read the range of the resolved changelog between the old pin and the new one:
   `<dir>/Library/PackageCache/com.unity.pipeline@*/CHANGELOG.md`, plus `Documentation~/` beside it
   for anything the changelog only names.

Leave the manifest, lock file and `package.json` edits uncommitted unless the user asked for a
commit; list them in the report.

## Revise the unity-cli skill

Skip this section only when nothing was upgraded. Sources: `cli-changelog.txt`, `skill.diff` and
the package changelog range.

1. **Triage each changelog entry.** Keep an entry only if it changes what an agent does with this
   setup: a command, flag, default, exit code, output shape, error code or documented pitfall that
   `~/.claude/skills/unity-cli/` covers or should cover. Drop the rest (other platforms, features
   nobody here uses) without recording them.
2. **Find every statement it touches**: `grep -rn '<command or flag>' ~/.claude/skills/unity-cli/`
   covers SKILL.md, `reference/`, `scripts/` and `tests/`.
3. **Verify before writing.** Confirm each kept entry against `unity <cmd> --help`, and anything
   about live-editor behaviour with a real run on an editor brought up through `unity-editor up`.
   A changelog and the embedded skill say what was intended; the skill records what happens. An
   entry that does not reproduce changes nothing in the skill and goes in the report.
4. **Rewrite in place, as present-tense fact.** The skill describes the installed versions only,
   because a reader acts on what is true now and history lives in git:
   - Replace the old statement; never append a note beside it.
   - No version comparisons or change words: no "since", "as of", "now", "no longer",
     "previously", "new in", no older version numbers.
   - Delete a pitfall or workaround once the fix is verified, including the script code that
     absorbed it. Keep it if the run still reproduces it.
   - The version line at the top of SKILL.md names the installed CLI, Pipeline and Unity versions
     and nothing older.
5. **Follow the skill rules in `~/.claude/CLAUDE.md`**: body at most 500 lines, detail in
   `reference/<topic>.md` linked directly from SKILL.md, each rule with a one-clause why, the
   description untouched unless a capability was added or removed.
6. **Fix the helpers** when a flag or output shape they rely on changed, then run every script in
   `~/.claude/skills/unity-cli/tests/`.
7. **Other owners.** If a changed command appears in another skill or a repo doc
   (`grep -rn` over `~/.claude/skills` and the repos' `CLAUDE.md`, `docs/`, `.claude/skills/`), fix
   it in its owning source. Synced skills under a project's `.claude/skills/` are generated from
   `nono4u/GameCore`'s packages; edit the source there.

Never run `unity skill install` or `unity skill refresh`: see unity-cli's `reference/upgrades.md`.

## Done when

- `unity-cli-upgrade-check` on the same projects exits 0, or every remaining `UPGRADE` row is reported
  with the reason it was left.
- Each upgraded project compiles and its suites pass, with the counts in the report.
- `grep -rnE 'since|as of|no longer|previously|new in' ~/.claude/skills/unity-cli/` shows no line
  describing a version change, and the version line matches `unity --version` and the manifests.
- unity-cli's `tests/` scripts pass.
- The report lists old and new versions, the skill statements changed and why, entries triaged as
  relevant but left unverified, and every uncommitted file by repo.
