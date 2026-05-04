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
MERGED_DIR="$WORKSPACE/merged"
REPORT_DIR="$WORKSPACE/reports"
ISSUE_MAP="$WORKSPACE/state/issue-map.json"
PREVIEW_REPO="$MERGED_DIR/history-preview"

entries=(
  "CraftPresence-Android|MinePacu/CraftPresence-Android|Android|android"
  "CraftPresence-iOS|MinePacu/CraftPresence-iOS|iOS|ios"
  "CraftPresence|MinePacu/CraftPresence|macOS|macos"
)

mkdir -p "$REWRITTEN_DIR" "$MERGED_DIR" "$REPORT_DIR"

safe_remove_dir() {
  local path="$1"
  case "$path" in
    "$WORKSPACE"/*) rm -rf "$path" ;;
    *) echo "Refusing to remove path outside workspace: $path" >&2; exit 1 ;;
  esac
}

require_execute_tools() {
  if ! command -v git-filter-repo >/dev/null 2>&1; then
    echo "git-filter-repo is required for --execute." >&2
    exit 1
  fi
  if [[ ! -f "$ISSUE_MAP" ]]; then
    echo "Missing issue map: $ISSUE_MAP" >&2
    echo "Run issue import first so state/issue-map.json exists." >&2
    exit 1
  fi
  for entry in "${entries[@]}"; do
    IFS='|' read -r local_name _source_repo _prefix _remote_name <<<"$entry"
    if [[ ! -d "$SOURCES_DIR/$local_name/.git" ]]; then
      echo "Missing source clone: $SOURCES_DIR/$local_name" >&2
      echo "Run ./scripts/clone_sources.sh --execute first." >&2
      exit 1
    fi
  done
}

write_message_callback() {
  local source_repo="$1"
  local callback_file="$2"
  python3 - "$ISSUE_MAP" "$source_repo" "$callback_file" <<'PY'
import json
import sys
from pathlib import Path

issue_map_path, source_repo, callback_file = sys.argv[1:]
issue_map = json.loads(Path(issue_map_path).read_text(encoding="utf-8"))
Path(callback_file).write_text(
    "import re\n"
    f"issue_map = {json.dumps(issue_map)}\n"
    f"source_repo = {source_repo!r}\n"
    "ref_re = re.compile(rb'(?<![\\w/.-])(?:(fixes|fixed|closes|closed|resolves|resolved)\\s+)?(#|GH-)([1-9]\\d*)\\b', re.I)\n"
    "def repl(match):\n"
    "    number = match.group(3).decode()\n"
    "    key = f'{source_repo}#{number}'\n"
    "    if key not in issue_map:\n"
    "        return match.group(0)\n"
    "    keyword = match.group(1) or b''\n"
    "    prefix = keyword + b' ' if keyword else b''\n"
    "    return prefix + b'#' + str(issue_map[key]).encode()\n"
    "return ref_re.sub(repl, message)\n",
    encoding="utf-8",
)
PY
}

current_branch() {
  local repo="$1"
  git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || git -C "$repo" rev-parse --short HEAD
}

echo "History merge preview"
echo "Workspace: $WORKSPACE"
echo "Source clones: $SOURCES_DIR"
echo "Rewritten preview clones: $REWRITTEN_DIR"
echo "Merged preview repo: $PREVIEW_REPO"
echo "Issue map: $ISSUE_MAP"
echo "Dry run: $DRY_RUN"
echo

"$ROOT_DIR/scripts/rewrite_issue_refs.py" --dry-run

cat > "$REPORT_DIR/history-merge-preview-plan.md" <<EOF
# History Merge Preview Plan

- Workspace: $WORKSPACE
- Source clones: $SOURCES_DIR
- Rewritten local preview clones: $REWRITTEN_DIR
- Final local merged preview repo: $PREVIEW_REPO
- Issue map: $ISSUE_MAP
- Commit message rewrite report: $REPORT_DIR/issue-ref-rewrite-report.md
- No source repository is modified.
- No target repository push is performed.
- No force-push is performed.

## Platform mapping

- MinePacu/CraftPresence-Android -> Android/
- MinePacu/CraftPresence-iOS -> iOS/
- MinePacu/CraftPresence -> macOS/
EOF

if [[ "$DRY_RUN" -eq 1 ]]; then
  if [[ ! -f "$ISSUE_MAP" ]]; then
    echo "Missing issue-map.json. The command will not execute rewrite/merge until $ISSUE_MAP exists."
  fi
  for entry in "${entries[@]}"; do
    IFS='|' read -r local_name source_repo prefix _remote_name <<<"$entry"
    source="$SOURCES_DIR/$local_name"
    target="$REWRITTEN_DIR/$local_name-history-preview"
    if [[ -d "$source/.git" ]]; then
      echo "- Would clone local source copy $source to $target"
    elif [[ -d "$source" ]]; then
      echo "- Local source path exists but is not a git clone: $source"
      echo "  Dry-run commit-message scan falls back to gh for $source_repo."
      echo "  Execute mode requires a real source clone. Run ./scripts/clone_sources.sh --execute after moving or deleting this non-git directory."
    else
      echo "- Local source clone is missing: $source"
      echo "  Dry-run commit-message scan falls back to gh for $source_repo."
      echo "  Execute mode requires ./scripts/clone_sources.sh --execute first."
    fi
    echo "  Would rewrite commit message issue refs using $source_repo and issue-map.json"
    echo "  Would move repository root under $prefix/"
  done
  echo "- Would create merged preview repo at $PREVIEW_REPO"
  echo "Report: $REPORT_DIR/history-merge-preview-plan.md"
  exit 0
fi

require_execute_tools

rewritten_repos=()
for entry in "${entries[@]}"; do
  IFS='|' read -r local_name source_repo prefix _remote_name <<<"$entry"
  source="$SOURCES_DIR/$local_name"
  target="$REWRITTEN_DIR/$local_name-history-preview"
  callback_file="$REPORT_DIR/$local_name-message-callback.py"

  safe_remove_dir "$target"
  git clone --no-local "$source" "$target"
  write_message_callback "$source_repo" "$callback_file"
  git -C "$target" filter-repo --message-callback "$(cat "$callback_file")" --force
  git -C "$target" filter-repo --to-subdirectory-filter "$prefix" --force
  git -C "$target" log --oneline --decorate -30 > "$REPORT_DIR/$local_name-history-preview-log.txt"
  rewritten_repos+=("$target")
done

safe_remove_dir "$PREVIEW_REPO"
git clone --no-local "${rewritten_repos[0]}" "$PREVIEW_REPO"

for index in 1 2; do
  entry="${entries[$index]}"
  IFS='|' read -r _local_name _source_repo _prefix remote_name <<<"$entry"
  repo="${rewritten_repos[$index]}"
  branch="$(current_branch "$repo")"
  git -C "$PREVIEW_REPO" remote add "$remote_name" "$repo"
  git -C "$PREVIEW_REPO" fetch "$remote_name"
  git -C "$PREVIEW_REPO" merge --allow-unrelated-histories --no-edit "$remote_name/$branch"
done

git -C "$PREVIEW_REPO" log --oneline --decorate --graph --all -60 > "$REPORT_DIR/merged-history-preview-log.txt"
find "$PREVIEW_REPO" -maxdepth 2 -type f \
  ! -path "$PREVIEW_REPO/.git/*" \
  | sed "s#^$PREVIEW_REPO/##" \
  | sort > "$REPORT_DIR/merged-history-preview-tree.txt"

echo "Merged history preview repo created: $PREVIEW_REPO"
echo "Rewrite report: $REPORT_DIR/issue-ref-rewrite-report.md"
echo "Merged log: $REPORT_DIR/merged-history-preview-log.txt"
echo "Merged tree: $REPORT_DIR/merged-history-preview-tree.txt"
echo "No push was performed."
