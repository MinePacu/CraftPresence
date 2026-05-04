#!/usr/bin/env python3
"""Export non-PR GitHub issues and comments from private source repositories."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = Path(os.environ.get("CRAFTPRESENCE_MIGRATION_WORKSPACE", ROOT.parent / "CraftPresence-migration-workspace"))
EXPORT_DIR = WORKSPACE / "exports"
REPORT_DIR = WORKSPACE / "reports"

SOURCES = [
    {"repo": "MinePacu/CraftPresence-Android", "platform": "Android"},
    {"repo": "MinePacu/CraftPresence-iOS", "platform": "iOS"},
    {"repo": "MinePacu/CraftPresence", "platform": "macOS"},
]


def gh_api(path: str, paginate: bool = True) -> list[dict[str, Any]]:
    cmd = ["gh", "api", path]
    if paginate:
        cmd.append("--paginate")
    result = subprocess.run(cmd, check=True, text=True, capture_output=True)
    text = result.stdout.strip()
    if not text:
        return []
    decoder = json.JSONDecoder()
    pos = 0
    values: list[dict[str, Any]] = []
    while pos < len(text):
        obj, pos = decoder.raw_decode(text, pos)
        if isinstance(obj, list):
            values.extend(obj)
        else:
            values.append(obj)
        while pos < len(text) and text[pos].isspace():
            pos += 1
    return values


def issue_payload(issue: dict[str, Any], comments: list[dict[str, Any]], repo: str, platform: str) -> dict[str, Any]:
    return {
        "source_repo": repo,
        "platform": platform,
        "number": issue["number"],
        "title": issue["title"],
        "body": issue.get("body") or "",
        "state": issue["state"],
        "author": issue.get("user", {}).get("login"),
        "created_at": issue.get("created_at"),
        "updated_at": issue.get("updated_at"),
        "closed_at": issue.get("closed_at"),
        "html_url": issue.get("html_url"),
        "labels": [label["name"] for label in issue.get("labels", [])],
        "comments": [
            {
                "id": comment["id"],
                "author": comment.get("user", {}).get("login"),
                "created_at": comment.get("created_at"),
                "updated_at": comment.get("updated_at"),
                "html_url": comment.get("html_url"),
                "body": comment.get("body") or "",
            }
            for comment in sorted(comments, key=lambda c: c.get("created_at") or "")
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", help="Preview export counts without writing issue JSON.")
    parser.add_argument("--execute", action="store_true", help="Write issue export JSON files.")
    args = parser.parse_args()

    dry_run = not args.execute or args.dry_run
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Issue export workspace: {WORKSPACE}")
    print(f"Dry run: {dry_run}")

    if shutil.which("gh") is None:
        print("gh is not installed or not on PATH.")
        for source in SOURCES:
            print(f"- Would read {source['repo']} issues and comments")
        print("Issue and comment counts are unavailable until gh is installed and authenticated.")
        return 0 if dry_run else 1

    totals: dict[str, dict[str, int]] = {}
    for source in SOURCES:
        repo = source["repo"]
        platform = source["platform"]
        path = f"repos/{repo}/issues?state=all&per_page=100"
        print(f"- Reading {repo}")
        issues = gh_api(path)
        normal_issues = [issue for issue in issues if "pull_request" not in issue]
        pr_count = len(issues) - len(normal_issues)
        comment_count = sum(int(issue.get("comments") or 0) for issue in normal_issues)
        totals[repo] = {"issues": len(normal_issues), "comments": comment_count, "prs_skipped": pr_count}
        print(f"  issues: {len(normal_issues)}, comments: {comment_count}, PRs skipped: {pr_count}")

        if dry_run:
            continue

        exported = []
        for issue in normal_issues:
            comments = gh_api(f"repos/{repo}/issues/{issue['number']}/comments?per_page=100")
            exported.append(issue_payload(issue, comments, repo, platform))

        out = EXPORT_DIR / f"{repo.replace('/', '__')}.issues.json"
        out.write_text(json.dumps(exported, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"  wrote {out}")

    report = REPORT_DIR / "issue-export-summary.json"
    report.write_text(json.dumps(totals, indent=2) + "\n", encoding="utf-8")
    print(f"Summary report: {report}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as exc:
        print(exc.stderr or str(exc), file=sys.stderr)
        raise SystemExit(exc.returncode)
