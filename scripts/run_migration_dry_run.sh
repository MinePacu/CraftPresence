#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="${CRAFTPRESENCE_MIGRATION_WORKSPACE:-"$(cd "$ROOT_DIR/.." && pwd)/CraftPresence-migration-workspace"}"

echo "CraftPresence migration dry run"
echo "Repository root: $ROOT_DIR"
echo "Migration workspace: $WORKSPACE"
echo

mkdir -p "$WORKSPACE"/{sources,rewritten,exports,reports,merged,state}

echo "== GitHub authentication =="
if command -v gh >/dev/null 2>&1; then
  gh auth status || true
else
  echo "gh is not installed or not on PATH."
fi
echo

echo "== Repository access preview =="
for repo in MinePacu/CraftPresence-Android MinePacu/CraftPresence-iOS MinePacu/CraftPresence MinePacu/CraftPresence-Test; do
  if command -v gh >/dev/null 2>&1; then
    gh repo view "$repo" --json nameWithOwner,isPrivate,defaultBranchRef 2>/dev/null || echo "Cannot access $repo"
  else
    echo "Would verify access to $repo"
  fi
done
echo

"$ROOT_DIR/scripts/clone_sources.sh" --dry-run
echo

"$ROOT_DIR/scripts/export_issues.py" --dry-run
echo

"$ROOT_DIR/scripts/import_issues.py" --dry-run
echo

"$ROOT_DIR/scripts/rewrite_history.sh" --dry-run
echo

"$ROOT_DIR/scripts/rewrite_issue_refs.py" --dry-run
echo

"$ROOT_DIR/scripts/merge_gitignore.py" --dry-run

echo
echo "Dry run complete. No issues, comments, labels, pushes, or force-pushes were created."

