#!/usr/bin/env python3
"""Merge source .gitignore files for the monorepo layout."""

from __future__ import annotations

import argparse
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = Path(os.environ.get("CRAFTPRESENCE_MIGRATION_WORKSPACE", ROOT.parent / "CraftPresence-migration-workspace"))
SOURCES_DIR = WORKSPACE / "sources"
MERGED_DIR = WORKSPACE / "merged"
REPORT_DIR = WORKSPACE / "reports"

SOURCES = [
    ("CraftPresence-Android", "Android"),
    ("CraftPresence-iOS", "iOS"),
    ("CraftPresence", "macOS"),
]

GLOBAL_PATTERNS = {
    ".DS_Store",
    "Thumbs.db",
    "*.log",
    "*.tmp",
    "*.swp",
    "*~",
}


def normalize_rule(rule: str, prefix: str) -> tuple[str, str]:
    stripped = rule.strip()
    if not stripped or stripped.startswith("#"):
        return stripped, "comment/blank"
    negated = stripped.startswith("!")
    body = stripped[1:] if negated else stripped
    if body in GLOBAL_PATTERNS or body.startswith("*."):
        return stripped, "global"
    if body.startswith("/"):
        body = body[1:]
    if body.startswith(f"{prefix}/"):
        adjusted = body
    else:
        adjusted = f"{prefix}/{body}"
    if negated:
        adjusted = f"!{adjusted}"
    return adjusted, "platform"


def read_rules(path: Path) -> list[str]:
    if not path.exists():
        return []
    return path.read_text(encoding="utf-8", errors="replace").splitlines()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", help="Preview merged .gitignore only.")
    parser.add_argument("--execute", action="store_true", help="Write merged .gitignore to workspace/merged/.gitignore.")
    args = parser.parse_args()
    dry_run = not args.execute or args.dry_run

    MERGED_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    global_rules: list[str] = []
    sections: dict[str, list[str]] = {}
    report: list[str] = ["# .gitignore Merge Report", "", f"Dry run: {dry_run}", ""]
    seen_global: set[str] = set()

    for local_name, prefix in SOURCES:
        path = SOURCES_DIR / local_name / ".gitignore"
        report.append(f"## {prefix}")
        rules = read_rules(path)
        if not rules:
            report.append(f"- No .gitignore found at `{path}`.")
            sections[prefix] = []
            report.append("")
            continue
        platform_rules: list[str] = []
        seen_platform: set[str] = set()
        for rule in rules:
            adjusted, kind = normalize_rule(rule, prefix)
            if not adjusted:
                continue
            if kind == "comment/blank":
                continue
            if kind == "global":
                if adjusted not in seen_global:
                    global_rules.append(adjusted)
                    seen_global.add(adjusted)
                report.append(f"- global: `{rule}`")
            else:
                if adjusted not in seen_platform:
                    platform_rules.append(adjusted)
                    seen_platform.add(adjusted)
                if adjusted != rule:
                    report.append(f"- adjusted: `{rule}` -> `{adjusted}`")
                else:
                    report.append(f"- kept: `{rule}`")
        sections[prefix] = platform_rules
        report.append("")

    lines: list[str] = ["# Global"]
    lines.extend(sorted(global_rules))
    for _, prefix in SOURCES:
        lines.extend(["", f"# {prefix}"])
        lines.extend(sorted(sections.get(prefix, [])))

    preview = "\n".join(lines).rstrip() + "\n"
    (REPORT_DIR / "gitignore-merge-report.md").write_text("\n".join(report) + "\n", encoding="utf-8")
    (REPORT_DIR / "gitignore-preview.txt").write_text(preview, encoding="utf-8")

    print(".gitignore merge preview")
    print(preview)
    print(f"Report: {REPORT_DIR / 'gitignore-merge-report.md'}")

    if not dry_run:
        (MERGED_DIR / ".gitignore").write_text(preview, encoding="utf-8")
        print(f"Wrote {MERGED_DIR / '.gitignore'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

