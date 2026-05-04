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
| `scripts/merge_histories_preview.sh` | Uses `issue-map.json` to preview or create a local merged history repo under the external workspace | No |
| `scripts/push_merged_history_branch.sh` | Pushes the local merged history preview to a new test-repo branch named `migration/repo` | No |
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

## Import issues into the monorepo test repository

Only run this section after explicitly deciding to create issues in the test target repository. These commands must target `MinePacu/CraftPresence-Test`, not the source repositories.

The source repositories are read only. The importer creates issues and comments only in the repository named by `CRAFTPRESENCE_TARGET_REPO`.

First, confirm authentication and repository access:

```bash
gh auth status
gh repo view MinePacu/CraftPresence-Android --json nameWithOwner,isPrivate
gh repo view MinePacu/CraftPresence-iOS --json nameWithOwner,isPrivate
gh repo view MinePacu/CraftPresence --json nameWithOwner,isPrivate
gh repo view MinePacu/CraftPresence-Test --json nameWithOwner,isPrivate
```

Export the source issues and comments into the external migration workspace:

```bash
./scripts/export_issues.py --execute
```

This reads normal issues and issue comments from the three source repositories, skips PRs returned by the Issues API, and writes export JSON under `../CraftPresence-migration-workspace/exports/`. It does not modify source repositories.

Before importing, print the exact import summary for the monorepo test repository:

```bash
CRAFTPRESENCE_TARGET_REPO=MinePacu/CraftPresence-Test \
  ./scripts/import_issues.py --dry-run
```

Review:

```bash
jq . ../CraftPresence-migration-workspace/reports/issue-import-preview.json
```

The dry run shows the target repository, issue count, comment count, platform labels, each planned imported issue, and any `skipped_reasons` from resume state.

When the dry-run summary is correct, run the actual issue and comment import:

```bash
CRAFTPRESENCE_TARGET_REPO=MinePacu/CraftPresence-Test \
  ./scripts/import_issues.py --execute
```

The importer uses resume state in `../CraftPresence-migration-workspace/state/`:

- `issue-map.json` records source issue keys to target issue numbers.
- `comment-import-state.json` records imported source comment IDs so re-running the command does not duplicate comments already recorded there.

After import, inspect the generated state:

```bash
jq . ../CraftPresence-migration-workspace/state/issue-map.json
jq . ../CraftPresence-migration-workspace/state/comment-import-state.json
```

## Preview rewritten and merged history after issue import

After `../CraftPresence-migration-workspace/state/issue-map.json` exists, preview commit-message issue reference rewrites and the local history merge plan:

```bash
./scripts/merge_histories_preview.sh --dry-run
```

This writes:

```text
../CraftPresence-migration-workspace/reports/issue-ref-rewrite-report.md
../CraftPresence-migration-workspace/reports/history-merge-preview-plan.md
```

To create the local merged history preview repository only under the migration workspace, run:

```bash
./scripts/clone_sources.sh --execute
./scripts/merge_histories_preview.sh --execute
```

This command:

- Reads source clones from `../CraftPresence-migration-workspace/sources/`.
- Rewrites local cloned copies only, not the source repositories.
- Rewrites commit message issue references using `state/issue-map.json`.
- Moves repository roots under `Android/`, `iOS/`, and `macOS/`.
- Creates the final local preview repo at `../CraftPresence-migration-workspace/merged/history-preview`.
- Writes before/after commit message rewrite details to `reports/issue-ref-rewrite-report.md`.
- Writes merged history and tree reports under `../CraftPresence-migration-workspace/reports/`.
- Does not push to `MinePacu/CraftPresence-Test`.

## Push the merged history preview to a test branch

After the local merged history preview exists, preview the push to the test repository branch `migration/repo`:

```bash
./scripts/push_merged_history_branch.sh --dry-run
```

To push the merged preview to a new branch in `MinePacu/CraftPresence-Test`:

```bash
./scripts/push_merged_history_branch.sh --execute
```

This command:

- Reads only `../CraftPresence-migration-workspace/merged/history-preview`.
- Pushes to `MinePacu/CraftPresence-Test:migration/repo`.
- Refuses to push to `main` or `master`.
- Refuses to update `migration/repo` if it already exists on the remote.
- Uses regular `git push` without `--force`.
- Does not modify any source repository.

After a successful push, create a draft PR:

```bash
gh pr create \
  --repo MinePacu/CraftPresence-Test \
  --base main \
  --head migration/repo \
  --draft \
  --title "Merge CraftPresence histories" \
  --body "Merges Android, iOS, and macOS histories into the monorepo layout."
```

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
