#!/usr/bin/env python3
"""PreToolUse policy: block scratch/debug/adhoc files at repo root.

Reads tool-input JSON from stdin. Reads policy from the config path
supplied as `--config <file>`. Project root supplied as `--project-root <dir>`.

Exit 0 to allow, exit 2 to block.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def load_policy(path: Path) -> dict:
    try:
        with path.open() as f:
            cfg = json.load(f)
        return cfg.get("block_loose_files", {})
    except Exception:
        return {}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--project-root", required=True, type=Path)
    ap.add_argument("--config", required=True, type=Path)
    args = ap.parse_args()

    policy = load_policy(args.config)
    if not policy.get("enabled", True):
        return 0

    patterns = tuple(policy.get("patterns", ["test_", "debug_", "scratch_", "adhoc_", "tmp_", "wip_"]))
    allowed_dirs = tuple(policy.get("allowed_dirs", ["tests/", "scripts/", "src/"]))

    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    file_path = (payload.get("tool_input") or {}).get("file_path", "")
    if not file_path:
        return 0

    project_root = str(args.project_root).rstrip("/") + "/"
    if not file_path.startswith(project_root):
        # Outside the project — not our concern.
        return 0

    rel = file_path[len(project_root):]

    # Files inside an allowed directory pass.
    if any(rel.startswith(d) for d in allowed_dirs):
        return 0

    # Root-level files (no slash in rel) check pattern prefix.
    if "/" in rel:
        return 0

    if rel.startswith(patterns):
        sys.stderr.write(
            f"Blocked: loose file at repo root: {rel}\n"
            f"Patterns blocked at root: {list(patterns)}\n"
            f"Allowed directories: {list(allowed_dirs)}\n"
            f"Re-issue with a path inside one of the allowed directories, "
            f"or use a non-prefixed filename for a genuine top-level file.\n"
        )
        return 2

    return 0


if __name__ == "__main__":
    sys.exit(main())
