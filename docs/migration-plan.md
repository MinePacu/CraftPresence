# Migration Plan

## Goal

Prepare a safe, reviewable migration from three private repositories into `MinePacu/CraftPresence-Test` with this final folder layout:

```text
Android/
iOS/
macOS/
```

## Phase 1: dry-run preparation

Current scope:

- Add scripts.
- Add documentation.
- Add examples.
- Add dry-run previews.
- Add validation checklist.
- Open a pull request in the test target repository.

No real issue import, comment import, history merge push, or force-push is performed in this phase.

## Phase 2: source clone preview and clone

`scripts/clone_sources.sh --dry-run` shows clone targets.

Later, after explicit approval:

```bash
./scripts/clone_sources.sh --execute
```

This clones source repositories into the external workspace only.

## Phase 3: issue and comment export

`scripts/export_issues.py --dry-run` reads private source issue counts and skips PRs returned by the Issues API.

Later, after explicit approval:

```bash
./scripts/export_issues.py --execute
```

This writes issue export JSON files under `../CraftPresence-migration-workspace/exports`.

## Phase 4: issue and comment import

`scripts/import_issues.py --dry-run` previews imported issue titles, states, labels, and comment counts.

Later, after explicit approval:

```bash
./scripts/import_issues.py --execute
```

The importer:

- Creates missing platform labels.
- Creates target issues.
- Adds source metadata to issue bodies.
- Imports comments in ascending original `created_at` order.
- Adds source metadata to comment bodies.
- Closes imported issues whose source issue was closed.
- Writes `state/issue-map.json`.
- Writes `state/comment-import-state.json` so comment import can resume without duplicating already imported comments.

GitHub issue `created_at` and real author identity are not rewritten because GitHub does not allow normal API clients to set them.

## Phase 5: history rewrite

`scripts/rewrite_history.sh --dry-run` previews source clone status and root contents.

Later, after explicit approval:

```bash
./scripts/rewrite_history.sh --execute
```

This uses `git-filter-repo --to-subdirectory-filter` in external workspace clones:

- `CraftPresence-Android` becomes `Android/`.
- `CraftPresence-iOS` becomes `iOS/`.
- `CraftPresence` becomes `macOS/`.

Commit titles are not prefixed.

## Phase 6: issue reference rewrite

After `state/issue-map.json` exists:

```bash
./scripts/rewrite_issue_refs.py --dry-run
```

The script interprets short references by source repository:

- `#3` in Android history means `MinePacu/CraftPresence-Android#3`.
- `#3` in iOS history means `MinePacu/CraftPresence-iOS#3`.
- `#3` in macOS history means `MinePacu/CraftPresence#3`.

Supported forms include:

- `#3`
- `GH-3`
- `fixes #3`
- `closes #3`
- `resolves #3`

The dry-run report is written to `reports/issue-ref-rewrite-report.md`.

## Phase 7: `.gitignore` merge

```bash
./scripts/merge_gitignore.py --dry-run
```

The merge keeps common global rules such as `.DS_Store` and `*.log` global, and adjusts platform-specific path rules under `Android/`, `iOS/`, or `macOS/`.

Reports are written to:

- `reports/gitignore-preview.txt`
- `reports/gitignore-merge-report.md`

## Phase 8: final merge into test monorepo

This phase is intentionally not automated in the first scope. It should happen only after explicit approval to import and push.

