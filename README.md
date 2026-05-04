# CraftPresence Monorepo Migration Tools

This repository contains dry-run-first tooling for preparing a migration from three private source repositories into the private test monorepo `MinePacu/CraftPresence-Test`.

Source repositories:

| Source | Destination folder |
| --- | --- |
| `MinePacu/CraftPresence-Android` | `Android/` |
| `MinePacu/CraftPresence-iOS` | `iOS/` |
| `MinePacu/CraftPresence` | `macOS/` |

Temporary clones, issue exports, rewritten histories, reports, and generated `issue-map.json` files are written outside this repository by default:

```text
../CraftPresence-migration-workspace/
```

Set `CRAFTPRESENCE_MIGRATION_WORKSPACE=/absolute/path` to override that location.

## Safety model

The scripts are designed so the default path is inspection only. They do not import issues, create comments, close issues, push branches, force-push, create releases, or create GitHub Actions workflows unless a later explicit command enables a real execution mode.

Use the combined dry run:

```bash
./scripts/run_migration_dry_run.sh
```

This prints the planned workspace, source repositories, clone targets, issue export plan, import preview inputs, history rewrite plan, `.gitignore` merge preview, folder layout preview, and issue reference rewrite expectations.

## Script overview

| Script | Purpose | Real changes by default |
| --- | --- | --- |
| `scripts/clone_sources.sh` | Shows or performs source clone/update into the external workspace | No |
| `scripts/export_issues.py` | Exports non-PR GitHub issues and issue comments; dry-run writes preview issue JSON for downstream reports | No |
| `scripts/import_issues.py` | Imports exported issues/comments into the test repo with platform labels and resume support | No |
| `scripts/rewrite_history.sh` | Rewrites each source history under `Android/`, `iOS/`, or `macOS/` in external working clones | No |
| `scripts/rewrite_issue_refs.py` | Rewrites issue references in commit messages using `issue-map.json`, with a review report | No |
| `scripts/merge_gitignore.py` | Merges source `.gitignore` files into a monorepo root `.gitignore` preview or output | No |
| `scripts/run_migration_dry_run.sh` | Runs the safe preview flow | No |

## Generated files

The migration workspace may contain:

```text
CraftPresence-migration-workspace/
├─ sources/
├─ rewritten/
├─ exports/
├─ reports/
├─ merged/
└─ state/
```

These files are intentionally not stored in this repository.

## Validation commands

Check GitHub authentication:

```bash
gh auth status
```

Check private source repository access:

```bash
gh repo view MinePacu/CraftPresence-Android --json nameWithOwner,isPrivate
gh repo view MinePacu/CraftPresence-iOS --json nameWithOwner,isPrivate
gh repo view MinePacu/CraftPresence --json nameWithOwner,isPrivate
```

Check rewritten commit history after an explicit rewrite run:

```bash
git -C ../CraftPresence-migration-workspace/rewritten/CraftPresence-Android log --oneline -- Android/
git -C ../CraftPresence-migration-workspace/rewritten/CraftPresence-iOS log --oneline -- iOS/
git -C ../CraftPresence-migration-workspace/rewritten/CraftPresence log --oneline -- macOS/
```

Check target folder structure after an explicit merge:

```bash
find Android iOS macOS -maxdepth 2 -type f | sort | head -50
```

Check issue reference rewrite report:

```bash
sed -n '1,160p' ../CraftPresence-migration-workspace/reports/issue-ref-rewrite-report.md
```

Check `.gitignore` merge report:

```bash
sed -n '1,160p' ../CraftPresence-migration-workspace/reports/gitignore-merge-report.md
```

Check issue map:

```bash
jq . ../CraftPresence-migration-workspace/state/issue-map.json
```

See also:

- `docs/migration-plan.md`
- `docs/safety-rules.md`
- `docs/verification-checklist.md`
