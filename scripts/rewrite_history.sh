#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=1

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
SOURCES_DIR="$WORKSPACE/sources"
REWRITTEN_DIR="$WORKSPACE/rewritten"
REPORT_DIR="$WORKSPACE/reports"

entries=(
  "CraftPresence-Android:Android"
  "CraftPresence-iOS:iOS"
  "CraftPresence:macOS"
)

mkdir -p "$REWRITTEN_DIR" "$REPORT_DIR"

echo "History rewrite plan"
echo "Workspace: $WORKSPACE"
echo "Dry run: $DRY_RUN"

if ! command -v git-filter-repo >/dev/null 2>&1; then
  echo "git-filter-repo is required for --execute. Install it before running real history rewrites."
fi

for entry in "${entries[@]}"; do
  IFS=: read -r local_name prefix <<<"$entry"
  source="$SOURCES_DIR/$local_name"
  target="$REWRITTEN_DIR/$local_name"
  echo "- $source -> $target, moved under $prefix/"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ -d "$source/.git" ]]; then
      git -C "$source" rev-list --count HEAD | sed "s/^/  commits: /"
      git -C "$source" ls-tree --name-only HEAD | sed -n '1,20p' | sed "s/^/  root item: /"
    else
      echo "  source clone not found yet"
    fi
    continue
  fi

  if [[ ! -d "$source/.git" ]]; then
    echo "Missing source clone: $source" >&2
    exit 1
  fi

  rm -rf "$target"
  git clone --no-local "$source" "$target"
  git -C "$target" filter-repo --to-subdirectory-filter "$prefix" --force
  git -C "$target" log --oneline --decorate -20 > "$REPORT_DIR/$local_name.rewritten-log.txt"
done

cat > "$REPORT_DIR/history-rewrite-plan.md" <<EOF
# History rewrite plan

- Source clones: $SOURCES_DIR
- Rewritten clones: $REWRITTEN_DIR
- Android history target: Android/
- iOS history target: iOS/
- macOS history target: macOS/
- Commit titles are not prefixed.
- Source repositories are cloned and rewritten only in local external workspace copies.
- No push is performed by this script.
EOF

echo "Report: $REPORT_DIR/history-rewrite-plan.md"

