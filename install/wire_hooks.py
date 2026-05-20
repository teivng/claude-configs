#!/usr/bin/env python3
"""Wire installed hook scripts into <project>/.claude/settings.local.json.

Idempotent: if a hook is already wired (same command path), leaves it alone.
Otherwise appends to the relevant event's hook list. Creates the file if
it doesn't exist.

Invoked by install.sh after copying hook scripts into place.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HOOK_BINDINGS = [
    {
        "event": "PreToolUse",
        "matcher": "Write",
        "command_rel": ".claude/hooks/pretooluse/block-loose-files.sh",
    },
    {
        "event": "PreToolUse",
        "matcher": "Write|Edit",
        "command_rel": ".claude/hooks/pretooluse/block-hardcoded-paths.sh",
    },
    {
        "event": "Stop",
        "matcher": None,
        "command_rel": ".claude/hooks/stop/warn-untracked-artifacts.sh",
    },
    {
        "event": "SessionStart",
        "matcher": "compact|clear",
        "command_rel": ".claude/hooks/sessionstart/brain-dump-on-resume.sh",
    },
]


def add_binding(hooks_root: dict, event: str, matcher: str | None, command: str) -> bool:
    """Append a binding under `event`. Returns True if added, False if already present."""
    bucket = hooks_root.setdefault(event, [])
    for entry in bucket:
        if entry.get("matcher") == matcher:
            for h in entry.get("hooks", []):
                if h.get("command") == command:
                    return False
            entry.setdefault("hooks", []).append(
                {"type": "command", "command": command, "async": False}
            )
            return True
    new: dict = {"hooks": [{"type": "command", "command": command, "async": False}]}
    if matcher is not None:
        new["matcher"] = matcher
    bucket.append(new)
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--project-root", required=True, type=Path)
    ap.add_argument("--dry-run", default="0")
    args = ap.parse_args()

    root = args.project_root.resolve()
    settings_path = root / ".claude" / "settings.local.json"

    if settings_path.exists():
        with settings_path.open() as f:
            settings = json.load(f)
    else:
        settings = {}

    hooks_root = settings.setdefault("hooks", {})

    added = 0
    for b in HOOK_BINDINGS:
        cmd = str(root / b["command_rel"])
        if (root / b["command_rel"]).exists():
            if add_binding(hooks_root, b["event"], b["matcher"], cmd):
                added += 1
                print(f"  +wired {b['event']} {b['matcher'] or ''}: {b['command_rel']}")
        else:
            print(f"  skipped {b['command_rel']} (not present)")

    if args.dry_run == "1":
        print(f"\n  [dry-run] would write {settings_path} with {added} new bindings")
        return 0

    settings_path.parent.mkdir(parents=True, exist_ok=True)
    with settings_path.open("w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
    print(f"\n  wrote {settings_path} ({added} new bindings; total preserved)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
