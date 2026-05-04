#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=1
TARGET_REPO="${CRAFTPRESENCE_TARGET_REPO:-MinePacu/CraftPresence-Test}"
BRANCH_NAME="${CRAFTPRESENCE_MERGED_HISTORY_BRANCH:-migration/repo}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --execute) DRY_RUN=0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="${CRAFTPRESENCE_MIGRATION_WORKSPACE:-"$(cd "$ROOT_DIR/.." && pwd)/CraftPresence-migration-workspace"}"
MERGED_REPO="$WORKSPACE/merged/history-preview"
REPORT_DIR="$WORKSPACE/reports"
REPORT="$REPORT_DIR/push-merged-history-branch-plan.md"
TARGET_REMOTE_URL="https://github.com/$TARGET_REPO.git"

mkdir -p "$REPORT_DIR"

if [[ "$BRANCH_NAME" == "main" || "$BRANCH_NAME" == "master" ]]; then
  echo "Refusing to push protected branch name: $BRANCH_NAME" >&2
  exit 1
fi

echo "Push merged history branch"
echo "Merged repo: $MERGED_REPO"
echo "Target repo: $TARGET_REPO"
echo "Target branch: $BRANCH_NAME"
echo "Dry run: $DRY_RUN"
echo

cat > "$REPORT" <<EOF
# Push Merged History Branch Plan

- Merged preview repo: $MERGED_REPO
- Target repository: $TARGET_REPO
- Target branch: $BRANCH_NAME
- Main branch push: no
- Force-push: no
- Source repository modification: no

## Pull request command after push

\`\`\`bash
gh pr create --repo $TARGET_REPO --base main --head $BRANCH_NAME --draft --title "Merge CraftPresence histories" --body "Merges Android, iOS, and macOS histories into the monorepo layout."
\`\`\`
EOF

if [[ ! -d "$MERGED_REPO/.git" ]]; then
  echo "Missing merged preview git repo: $MERGED_REPO" >&2
  echo "Run ./scripts/merge_histories_preview.sh --execute first." >&2
  exit 1
fi

if git ls-remote --exit-code --heads "$TARGET_REMOTE_URL" "$BRANCH_NAME" >/dev/null 2>&1; then
  echo "Remote branch already exists: $TARGET_REPO:$BRANCH_NAME" >&2
  echo "Refusing to update it without force-push. Choose a new branch name with CRAFTPRESENCE_MERGED_HISTORY_BRANCH." >&2
  exit 1
fi

current_commit="$(git -C "$MERGED_REPO" rev-parse HEAD)"
current_branch="$(git -C "$MERGED_REPO" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"

{
  echo
  echo "## Resolved source"
  echo
  echo "- Current merged repo HEAD: \`$current_commit\`"
  if [[ -n "$current_branch" ]]; then
    echo "- Current merged repo branch: \`$current_branch\`"
  else
    echo "- Current merged repo branch: detached HEAD"
  fi
} >> "$REPORT"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Would push $current_commit to $TARGET_REPO:$BRANCH_NAME"
  echo "Would use regular git push without --force."
  echo "Report: $REPORT"
  exit 0
fi

git -C "$MERGED_REPO" push "$TARGET_REMOTE_URL" "HEAD:refs/heads/$BRANCH_NAME"

echo "Pushed $current_commit to $TARGET_REPO:$BRANCH_NAME"
echo "Open a draft PR with:"
echo "gh pr create --repo $TARGET_REPO --base main --head $BRANCH_NAME --draft --title \"Merge CraftPresence histories\" --body \"Merges Android, iOS, and macOS histories into the monorepo layout.\""
echo "Report: $REPORT"
