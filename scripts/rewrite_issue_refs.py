#!/usr/bin/env python3
"""Rewrite issue references in commit messages using issue-map.json."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = Path(os.environ.get("CRAFTPRESENCE_MIGRATION_WORKSPACE", ROOT.parent / "CraftPresence-migration-workspace"))
STATE_DIR = WORKSPACE / "state"
REPORT_DIR = WORKSPACE / "reports"
REWRITTEN_DIR = WORKSPACE / "rewritten"

REPOS = {
    "CraftPresence-Android": "MinePacu/CraftPresence-Android",
    "CraftPresence-iOS": "MinePacu/CraftPresence-iOS",
    "CraftPresence": "MinePacu/CraftPresence",
}

REF_RE = re.compile(r"(?<![\w/.-])(?:(?P<keyword>fixes|fixed|closes|closed|resolves|resolved)\s+)?(?P<form>#|GH-)(?P<number>[1-9]\d*)\b", re.IGNORECASE)


def run_git(repo: Path, args: list[str], input_text: str | None = None) -> str:
    return subprocess.run(["git", "-C", str(repo), *args], input=input_text, text=True, capture_output=True, check=True).stdout


def rewrite_message(message: str, source_repo: str, issue_map: dict[str, int]) -> tuple[str, list[str]]:
    changes: list[str] = []

    def replace(match: re.Match[str]) -> str:
        old_number = match.group("number")
        key = f"{source_repo}#{old_number}"
        if key not in issue_map:
            return match.group(0)
        new_number = issue_map[key]
        prefix = f"{match.group('keyword')} " if match.group("keyword") else ""
        replacement = f"{prefix}#{new_number}"
        changes.append(f"{match.group(0)} -> {replacement} ({key})")
        return replacement

    return REF_RE.sub(replace, message), changes


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", help="Write a review report only.")
    parser.add_argument("--execute", action="store_true", help="Rewrite commit messages in rewritten workspace clones.")
    args = parser.parse_args()
    dry_run = not args.execute or args.dry_run

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    issue_map_path = STATE_DIR / "issue-map.json"
    if issue_map_path.exists():
        issue_map = json.loads(issue_map_path.read_text(encoding="utf-8"))
    else:
        issue_map = json.loads((ROOT / "examples" / "issue-map.example.json").read_text(encoding="utf-8"))

    report_lines = ["# Issue Reference Rewrite Report", "", f"Dry run: {dry_run}", ""]
    for local_name, source_repo in REPOS.items():
        repo_dir = REWRITTEN_DIR / local_name
        report_lines.append(f"## {source_repo}")
        if not repo_dir.exists():
            report_lines.append(f"- Rewritten repo not found yet: `{repo_dir}`")
            report_lines.append("")
            continue

        log = run_git(repo_dir, ["log", "--format=%H%x00%B%x00END%x00"])
        chunks = log.split("\0END\0")
        callback_cases: list[tuple[str, str, str, list[str]]] = []
        for chunk in chunks:
            parts = chunk.strip("\0\n").split("\0", 1)
            if len(parts) != 2:
                continue
            commit, message = parts
            rewritten, changes = rewrite_message(message, source_repo, issue_map)
            if changes:
                callback_cases.append((commit, message, rewritten, changes))
                report_lines.append(f"- `{commit[:12]}`")
                for change in changes:
                    report_lines.append(f"  - {change}")

        if not callback_cases:
            report_lines.append("- No rewrite candidates found.")
        report_lines.append("")

        if dry_run or not callback_cases:
            continue

        callback = repo_dir / ".git" / "craftpresence-message-callback.py"
        callback.write_text(
            "import json, re\n"
            f"issue_map = {json.dumps(issue_map)}\n"
            f"source_repo = {source_repo!r}\n"
            "ref_re = re.compile(rb'(?<![\\w/.-])(?:(fixes|fixed|closes|closed|resolves|resolved)\\s+)?(#|GH-)([1-9]\\d*)\\b', re.I)\n"
            "def repl(match):\n"
            "    number = match.group(3).decode()\n"
            "    key = f'{source_repo}#{number}'\n"
            "    if key not in issue_map:\n"
            "        return match.group(0)\n"
            "    keyword = (match.group(1) or b'')\n"
            "    prefix = keyword + b' ' if keyword else b''\n"
            "    return prefix + b'#' + str(issue_map[key]).encode()\n"
            "message = ref_re.sub(repl, message)\n",
            encoding="utf-8",
        )
        run_git(repo_dir, ["filter-repo", "--message-callback", callback.read_text(encoding="utf-8"), "--force"])

    report = REPORT_DIR / "issue-ref-rewrite-report.md"
    report.write_text("\n".join(report_lines) + "\n", encoding="utf-8")
    print(f"Issue reference rewrite report: {report}")
    if dry_run:
        print("No commit messages were changed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as exc:
        print(exc.stderr or str(exc), file=sys.stderr)
        raise SystemExit(exc.returncode)

