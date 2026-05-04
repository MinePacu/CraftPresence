# Verification Checklist

## Before running anything

- [ ] Confirm current repository is `MinePacu/CraftPresence-Test`.
- [ ] Confirm no source clone or export output exists inside this repository.
- [ ] Confirm `../CraftPresence-migration-workspace` is outside the test repository.
- [ ] Confirm `gh auth status` succeeds with an account that can read the three private source repositories and write to the test target repository.

## Dry run

```bash
./scripts/run_migration_dry_run.sh
```

- [ ] Dry run prints the external workspace path.
- [ ] Dry run lists all three source repositories.
- [ ] Dry run lists clone targets outside this repository.
- [ ] Dry run prints issue and comment counts when GitHub access is available.
- [ ] Dry run lists platform labels that would be created.
- [ ] Dry run previews import issue summaries when exports exist.
- [ ] Dry run previews history rewrite targets.
- [ ] Dry run writes issue reference rewrite report.
- [ ] Dry run previews merged `.gitignore`.

## GitHub access

```bash
gh repo view MinePacu/CraftPresence-Android --json nameWithOwner,isPrivate
gh repo view MinePacu/CraftPresence-iOS --json nameWithOwner,isPrivate
gh repo view MinePacu/CraftPresence --json nameWithOwner,isPrivate
gh repo view MinePacu/CraftPresence-Test --json nameWithOwner,isPrivate
```

- [ ] All four repositories are accessible.
- [ ] All repositories are private.

## History rewrite

After an explicitly approved rewrite:

```bash
git -C ../CraftPresence-migration-workspace/rewritten/CraftPresence-Android log --oneline -- Android/
git -C ../CraftPresence-migration-workspace/rewritten/CraftPresence-iOS log --oneline -- iOS/
git -C ../CraftPresence-migration-workspace/rewritten/CraftPresence log --oneline -- macOS/
```

- [ ] Android commits affect `Android/`.
- [ ] iOS commits affect `iOS/`.
- [ ] macOS commits affect `macOS/`.
- [ ] Commit titles do not have artificial platform prefixes.

## Issue imports

After explicitly approved import:

```bash
jq . ../CraftPresence-migration-workspace/state/issue-map.json
jq . ../CraftPresence-migration-workspace/state/comment-import-state.json
```

- [ ] Pull requests were skipped.
- [ ] Imported issues have the correct platform label.
- [ ] Imported issue bodies include source repository, issue number, original author, original created time, and original URL.
- [ ] Imported comments include source repository, issue number, original comment author, original comment created time, and original comment URL.
- [ ] Closed source issues were closed after import.
- [ ] Re-running import does not duplicate comments already tracked in `comment-import-state.json`.

## Issue reference rewrite

```bash
sed -n '1,160p' ../CraftPresence-migration-workspace/reports/issue-ref-rewrite-report.md
```

- [ ] Short references are interpreted using the source repository context.
- [ ] `#N`, `GH-N`, `fixes #N`, `closes #N`, and `resolves #N` candidates are reported.
- [ ] Non-issue numbers are not rewritten.
- [ ] Report is reviewed before any execute mode.

## `.gitignore`

```bash
sed -n '1,160p' ../CraftPresence-migration-workspace/reports/gitignore-preview.txt
sed -n '1,160p' ../CraftPresence-migration-workspace/reports/gitignore-merge-report.md
```

- [ ] Global rules are still global.
- [ ] Platform-specific rules are scoped under `Android/`, `iOS/`, or `macOS/`.
- [ ] Duplicate rules are removed.
- [ ] Sections exist for Android, iOS, and macOS.

## Final safety check

- [ ] No GitHub Releases were created or edited.
- [ ] No GitHub Actions workflows were created or edited.
- [ ] No source repository was pushed to or modified.
- [ ] No force-push was performed.
- [ ] No generated workspace artifacts were committed.

