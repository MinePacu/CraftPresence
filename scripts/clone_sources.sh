#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=1
UPDATE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --execute) DRY_RUN=0 ;;
    --update) UPDATE=1 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="${CRAFTPRESENCE_MIGRATION_WORKSPACE:-"$(cd "$ROOT_DIR/.." && pwd)/CraftPresence-migration-workspace"}"
SOURCES_DIR="$WORKSPACE/sources"

repos=(
  "MinePacu/CraftPresence-Android:CraftPresence-Android:Android"
  "MinePacu/CraftPresence-iOS:CraftPresence-iOS:iOS"
  "MinePacu/CraftPresence:CraftPresence:macOS"
)

mkdir -p "$SOURCES_DIR"

echo "Clone source repositories"
echo "Workspace: $WORKSPACE"
echo "Dry run: $DRY_RUN"

for entry in "${repos[@]}"; do
  IFS=: read -r repo local_name platform <<<"$entry"
  target="$SOURCES_DIR/$local_name"
  echo "- $repo -> $target -> $platform/"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    continue
  fi

  if [[ -d "$target/.git" ]]; then
    if [[ "$UPDATE" -eq 1 ]]; then
      git -C "$target" fetch --all --prune
    else
      echo "  Already cloned. Use --update to fetch."
    fi
  else
    gh repo clone "$repo" "$target"
  fi
done

