#!/usr/bin/env python3
"""PreToolUse policy: block hardcoded absolute paths in module code.

Reads tool-input JSON from stdin. Policy is read from the config file
supplied as `--config <file>`, key `block_hardcoded_paths`.

Exit 0 to allow, exit 2 to block.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
import sys
from pathlib import Path


def load_policy(path: Path) -> dict:
    try:
        with path.open() as f:
            cfg = json.load(f)
        return cfg.get("block_hardcoded_paths", {})
    except Exception:
        return {}


def matches_any(file_path: str, patterns: list[str], project_root: Path) -> bool:
    """Glob-match file_path against the patterns, relative to project_root."""
    rel = str(Path(file_path).relative_to(project_root))
    for pat in patterns:
        if fnmatch.fnmatch(rel, pat):
            return True
        # Support `**` semantics manually: fnmatch doesn't traverse directories.
        if "**" in pat:
            # Strip everything before the first `**` to allow it to match nested dirs.
            tail = pat.split("**", 1)[1].lstrip("/")
            if tail and rel.endswith(tail.lstrip("*")):
                return True
            if fnmatch.fnmatch(rel, pat.replace("**", "*")):
                return True
    return False


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--project-root", required=True, type=Path)
    ap.add_argument("--config", required=True, type=Path)
    args = ap.parse_args()

    policy = load_policy(args.config)
    if not policy.get("enabled", True):
        return 0

    forbidden_prefixes = policy.get(
        "forbidden_prefixes", ["/home/", "/Users/", "/root/"]
    )
    enforce_in = policy.get("enforce_in", ["src/**/*.py"])
    allowlist = policy.get("allowlist_files", ["src/**/paths.py", "src/**/config.py"])

    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    tool = payload.get("tool_name", "")
    ti = payload.get("tool_input") or {}
    fp = ti.get("file_path", "")

    if tool == "Write":
        content = ti.get("content", "")
    elif tool == "Edit":
        content = ti.get("new_string", "")
    else:
        return 0

    if not fp:
        return 0

    project_root = args.project_root
    try:
        _ = Path(fp).relative_to(project_root)
    except ValueError:
        # Outside project — skip.
        return 0

    # Only enforce on files matching enforce_in.
    if not matches_any(fp, enforce_in, project_root):
        return 0

    # Allowlist files are exempt.
    if matches_any(fp, allowlist, project_root):
        return 0

    # Build a regex matching any forbidden prefix inside quotes.
    quoted_re = re.compile(
        r"""["']("""
        + "|".join(re.escape(p) for p in forbidden_prefixes)
        + r""")[^"']+["']"""
    )
    if quoted_re.search(content):
        sys.stderr.write(
            f"Blocked: hardcoded absolute path in module code: {fp}\n"
            f"Forbidden prefixes: {forbidden_prefixes}\n"
            f"This convention exists to keep paths configurable per-host. "
            f"Move the path to the project's paths registry (typically "
            f"src/<pkg>/paths.py), or — if this is a one-shot script — "
            f"place it in scripts/ instead of in module code.\n"
            f"Configured allowlist: {allowlist}\n"
        )
        return 2

    return 0


if __name__ == "__main__":
    sys.exit(main())
