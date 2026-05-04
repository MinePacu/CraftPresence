#!/usr/bin/env python3
"""Rewrite issue references in commit messages using issue-map.json."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = Path(os.environ.get("CRAFTPRESENCE_MIGRATION_WORKSPACE", ROOT.parent / "CraftPresence-migration-workspace"))
STATE_DIR = WORKSPACE / "state"
REPORT_DIR = WORKSPACE / "reports"
REWRITTEN_DIR = WORKSPACE / "rewritten"
SOURCES_DIR = WORKSPACE / "sources"

REPOS = [
    {"local": "CraftPresence-Android", "repo": "MinePacu/CraftPresence-Android"},
    {"local": "CraftPresence-iOS", "repo": "MinePacu/CraftPresence-iOS"},
    {"local": "CraftPresence", "repo": "MinePacu/CraftPresence"},
]

REF_RE = re.compile(r"(?<![\w/.-])(?:(?P<keyword>fixes|fixed|closes|closed|resolves|resolved)\s+)?(?P<form>#|GH-)(?P<number>[1-9]\d*)\b", re.IGNORECASE)


def run_git(repo: Path, args: list[str], input_text: str | None = None) -> str:
    return subprocess.run(["git", "-C", str(repo), *args], input=input_text, text=True, capture_output=True, check=True).stdout


def run_gh(args: list[str]) -> str:
    return subprocess.run(["gh", *args], text=True, capture_output=True, check=True).stdout


def parse_json_stream(text: str) -> list[dict]:
    decoder = json.JSONDecoder()
    pos = 0
    values: list[dict] = []
    text = text.strip()
    while pos < len(text):
        obj, pos = decoder.raw_decode(text, pos)
        if isinstance(obj, list):
            values.extend(obj)
        else:
            values.append(obj)
        while pos < len(text) and text[pos].isspace():
            pos += 1
    return values


def find_refs(message: str, source_repo: str) -> list[dict[str, str]]:
    refs: list[dict[str, str]] = []
    for match in REF_RE.finditer(message):
        number = match.group("number")
        refs.append(
            {
                "reference": match.group(0),
                "source_issue": f"{source_repo}#{number}",
            }
        )
    return refs


def subject(message: str) -> str:
    for line in message.splitlines():
        if line.strip():
            return line.strip()
    return ""


def local_log(repo_dir: Path) -> list[tuple[str, str, str]]:
    log = run_git(repo_dir, ["log", "--all", "--format=%H%x00%B%x00END%x00"])
    commits: list[tuple[str, str, str]] = []
    for chunk in log.split("\0END\0"):
        parts = chunk.strip("\0\n").split("\0", 1)
        if len(parts) != 2:
            continue
        commit, message = parts
        commits.append((commit, subject(message), message))
    return commits


def gh_default_branch(repo: str) -> str | None:
    if shutil.which("gh") is None:
        return None
    result = subprocess.run(
        ["gh", "repo", "view", repo, "--json", "defaultBranchRef"],
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        return None
    data = json.loads(result.stdout)
    return data.get("defaultBranchRef", {}).get("name")


def gh_commit_log(repo: str) -> tuple[list[tuple[str, str, str]], str]:
    if shutil.which("gh") is None:
        return [], "gh is not installed or not on PATH"
    branch = gh_default_branch(repo)
    if not branch:
        return [], "could not determine default branch with gh"
    commits = parse_json_stream(run_gh(["api", f"repos/{repo}/commits?sha={branch}&per_page=100", "--paginate"]))
    rows: list[tuple[str, str, str]] = []
    for item in commits:
        message = item.get("commit", {}).get("message") or ""
        rows.append((item.get("sha") or "", subject(message), message))
    return rows, f"GitHub commits API default branch `{branch}`"


def load_commit_log(local_name: str, source_repo: str, prefer_rewritten: bool) -> tuple[list[tuple[str, str, str]], str]:
    rewritten_dir = REWRITTEN_DIR / local_name
    source_dir = SOURCES_DIR / local_name
    if prefer_rewritten and (rewritten_dir / ".git").exists():
        return local_log(rewritten_dir), f"rewritten repo `{rewritten_dir}`"
    if (source_dir / ".git").exists():
        return local_log(source_dir), f"source repo clone `{source_dir}`"
    if (rewritten_dir / ".git").exists():
        return local_log(rewritten_dir), f"rewritten repo `{rewritten_dir}`"
    commits, source = gh_commit_log(source_repo)
    notes = []
    if source_dir.exists():
        notes.append(f"`{source_dir}` exists but is not a git clone")
    if rewritten_dir.exists():
        notes.append(f"`{rewritten_dir}` exists but is not a git clone")
    if notes:
        source = f"{source}; fallback used because {', '.join(notes)}"
    return commits, source


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
        has_issue_map = True
    else:
        issue_map = {}
        has_issue_map = False

    report_lines = ["# Issue Reference Rewrite Report", "", f"Dry run: {dry_run}", ""]
    if has_issue_map:
        report_lines.extend([f"Issue map: `{issue_map_path}`", ""])
    else:
        report_lines.extend(
            [
                f"Issue map missing: `{issue_map_path}`",
                "Commit message rewrite was not run because target issue numbers are unknown until issue import creates `state/issue-map.json`.",
                "The sections below scan source commit messages and report potential issue references only.",
                "",
            ]
        )

    if args.execute and not has_issue_map:
        report_lines.append("Execute mode stopped before rewriting because `state/issue-map.json` does not exist.")
        report = REPORT_DIR / "issue-ref-rewrite-report.md"
        report.write_text("\n".join(report_lines) + "\n", encoding="utf-8")
        print(f"Issue reference rewrite report: {report}")
        print("No commit messages were changed.")
        return 1

    for repo_info in REPOS:
        local_name = repo_info["local"]
        source_repo = repo_info["repo"]
        report_lines.append(f"## {source_repo}")
        commits, source_description = load_commit_log(local_name, source_repo, prefer_rewritten=has_issue_map)
        report_lines.append(f"- Scan source: {source_description}")
        if not commits:
            report_lines.append("- No commits available to scan.")
            report_lines.append("")
            continue

        callback_cases: list[tuple[str, str, str, list[str]]] = []
        potential_refs = 0
        for commit, commit_subject, message in commits:
            refs = find_refs(message, source_repo)
            if not refs:
                continue
            potential_refs += len(refs)
            if not has_issue_map:
                report_lines.append(f"- commit: `{commit[:12]}`")
                report_lines.append(f"  - subject: {commit_subject}")
                for ref in refs:
                    report_lines.append(f"  - reference: `{ref['reference']}` -> interpreted source issue `{ref['source_issue']}`")
                continue

            rewritten, changes = rewrite_message(message, source_repo, issue_map)
            if not changes:
                report_lines.append(f"- commit: `{commit[:12]}`")
                report_lines.append(f"  - subject: {commit_subject}")
                for ref in refs:
                    report_lines.append(f"  - reference: `{ref['reference']}` -> interpreted source issue `{ref['source_issue']}`")
                    report_lines.append("  - mapped issue: not found in issue-map.json")
                continue

            callback_cases.append((commit, message, rewritten, changes))
            report_lines.append(f"- commit: `{commit[:12]}`")
            report_lines.append(f"  - subject: {commit_subject}")
            report_lines.append("  - before:")
            report_lines.append("    ```text")
            report_lines.extend(f"    {line}" for line in message.strip().splitlines())
            report_lines.append("    ```")
            report_lines.append("  - after:")
            report_lines.append("    ```text")
            report_lines.extend(f"    {line}" for line in rewritten.strip().splitlines())
            report_lines.append("    ```")
            for change in changes:
                report_lines.append(f"  - mapped issue: {change}")

        if potential_refs == 0:
            report_lines.append("- No potential issue references found.")
        report_lines.append("")

        if dry_run or not callback_cases or not has_issue_map:
            continue

        repo_dir = REWRITTEN_DIR / local_name
        if not repo_dir.exists():
            raise RuntimeError(f"Cannot execute rewrite because rewritten repo does not exist: {repo_dir}")
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
            "return ref_re.sub(repl, message)\n",
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
