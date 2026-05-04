#!/usr/bin/env python3
"""Import exported issues and comments into MinePacu/CraftPresence-Test."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = Path(os.environ.get("CRAFTPRESENCE_MIGRATION_WORKSPACE", ROOT.parent / "CraftPresence-migration-workspace"))
EXPORT_DIR = WORKSPACE / "exports"
STATE_DIR = WORKSPACE / "state"
REPORT_DIR = WORKSPACE / "reports"
TARGET_REPO = os.environ.get("CRAFTPRESENCE_TARGET_REPO", "MinePacu/CraftPresence-Test")

PLATFORM_LABELS = {
    "Android": {"name": "platform: Android", "color": "3DDC84", "description": "Imported from CraftPresence Android"},
    "iOS": {"name": "platform: iOS", "color": "A2AAAD", "description": "Imported from CraftPresence iOS"},
    "macOS": {"name": "platform: macOS", "color": "0A84FF", "description": "Imported from CraftPresence macOS"},
}


def run_gh(args: list[str], input_text: str | None = None) -> str:
    result = subprocess.run(["gh", *args], input=input_text, text=True, capture_output=True, check=True)
    return result.stdout


def load_exports() -> list[dict[str, Any]]:
    issues: list[dict[str, Any]] = []
    for path in sorted(EXPORT_DIR.glob("*.issues.json")):
        issues.extend(json.loads(path.read_text(encoding="utf-8")))
    return sorted(issues, key=lambda i: (i["source_repo"], i["number"]))


def load_json(path: Path, default: Any) -> Any:
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return default


def save_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def issue_body(issue: dict[str, Any]) -> str:
    return "\n".join(
        [
            f"> Imported issue from {issue['source_repo']}#{issue['number']}",
            f"> Original author: @{issue.get('author') or 'unknown'}",
            f"> Original created_at: {issue.get('created_at') or 'unknown'}",
            f"> Original URL: {issue.get('html_url') or 'unknown'}",
            "",
            issue.get("body") or "",
        ]
    ).rstrip() + "\n"


def comment_body(issue: dict[str, Any], comment: dict[str, Any]) -> str:
    return "\n".join(
        [
            f"> Imported comment from {issue['source_repo']}#{issue['number']}",
            f"> Original author: @{comment.get('author') or 'unknown'}",
            f"> Original created_at: {comment.get('created_at') or 'unknown'}",
            f"> Original URL: {comment.get('html_url') or 'unknown'}",
            "",
            comment.get("body") or "",
        ]
    ).rstrip() + "\n"


def ensure_labels(dry_run: bool) -> None:
    print("Platform labels:")
    for label in PLATFORM_LABELS.values():
        print(f"- {label['name']}")
        if dry_run:
            continue
        try:
            run_gh(["label", "create", label["name"], "--repo", TARGET_REPO, "--color", label["color"], "--description", label["description"]])
        except subprocess.CalledProcessError as exc:
            if "already exists" not in (exc.stderr or ""):
                raise


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", help="Preview imports only.")
    parser.add_argument("--execute", action="store_true", help="Create issues/comments and close imported closed issues.")
    args = parser.parse_args()
    dry_run = not args.execute or args.dry_run

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    issue_map_path = STATE_DIR / "issue-map.json"
    comment_state_path = STATE_DIR / "comment-import-state.json"
    issue_map: dict[str, int] = load_json(issue_map_path, {})
    comment_state: dict[str, list[int]] = load_json(comment_state_path, {})

    issues = load_exports()
    print(f"Target repo: {TARGET_REPO}")
    print(f"Import workspace: {WORKSPACE}")
    print(f"Dry run: {dry_run}")
    print(f"Exported issues found: {len(issues)}")
    print(f"Exported comments found: {sum(len(i.get('comments', [])) for i in issues)}")
    ensure_labels(dry_run)

    preview: list[dict[str, Any]] = []
    for issue in issues:
        source_key = f"{issue['source_repo']}#{issue['number']}"
        label = PLATFORM_LABELS[issue["platform"]]["name"]
        preview.append({"source": source_key, "title": issue["title"], "state": issue["state"], "label": label, "comments": len(issue.get("comments", []))})
        print(f"- {source_key}: {issue['title']} [{issue['state']}] comments={len(issue.get('comments', []))}")

        if dry_run:
            continue

        if source_key in issue_map:
            target_number = issue_map[source_key]
        else:
            created = run_gh(
                ["issue", "create", "--repo", TARGET_REPO, "--title", issue["title"], "--body-file", "-", "--label", label],
                issue_body(issue),
            ).strip()
            target_number = int(created.rstrip("/").split("/")[-1])
            issue_map[source_key] = target_number
            save_json(issue_map_path, issue_map)

        imported_comment_ids = set(comment_state.get(source_key, []))
        for comment in sorted(issue.get("comments", []), key=lambda c: c.get("created_at") or ""):
            comment_id = int(comment["id"])
            if comment_id in imported_comment_ids:
                continue
            run_gh(["issue", "comment", str(target_number), "--repo", TARGET_REPO, "--body-file", "-"], comment_body(issue, comment))
            imported_comment_ids.add(comment_id)
            comment_state[source_key] = sorted(imported_comment_ids)
            save_json(comment_state_path, comment_state)

        if issue["state"] == "closed":
            run_gh(["issue", "close", str(target_number), "--repo", TARGET_REPO, "--comment", f"Closing to match imported state from {source_key}."])

    (REPORT_DIR / "issue-import-preview.json").write_text(json.dumps(preview, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Preview report: {REPORT_DIR / 'issue-import-preview.json'}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as exc:
        print(exc.stderr or str(exc), file=sys.stderr)
        raise SystemExit(exc.returncode)

