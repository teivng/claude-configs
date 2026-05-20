#!/bin/bash
# Stop hook: warn (don't block) on untracked artifact files.
#
# Project-agnostic. Reads policy from `<project-root>/.claude/hook-config.json`
# (key `warn_untracked_artifacts`), or falls back to bundled defaults.
#
# Patterns are file extensions matched against `git status --porcelain` output;
# excluded_dirs are directory prefixes ignored (typical: caches).
#
# Always exit 0 — this hook is advisory, never blocking.
set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_ROOT" 2>/dev/null || exit 0

CONFIG_FILE="${PROJECT_ROOT}/.claude/hook-config.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG="${SCRIPT_DIR}/../default-hook-config.json"

if [ -f "$CONFIG_FILE" ]; then
  CFG="$CONFIG_FILE"
else
  CFG="$DEFAULT_CONFIG"
fi

python3 - "$CFG" <<'PY' || true
import json, os, subprocess, sys
from pathlib import Path

cfg_path = Path(sys.argv[1])
try:
    with cfg_path.open() as f:
        policy = json.load(f).get("warn_untracked_artifacts", {})
except Exception:
    policy = {}

if not policy.get("enabled", True):
    sys.exit(0)

patterns = policy.get("patterns", ["npy", "pt", "h5", "h5ad", "pkl", "ckpt", "log", "tar.gz"])
excluded = policy.get("excluded_dirs", [".cache/", "node_modules/"])

try:
    out = subprocess.check_output(["git", "status", "--porcelain"], text=True)
except Exception:
    sys.exit(0)

ext_re = "|".join(p.replace(".", r"\.") for p in patterns)
import re
needle = re.compile(rf"\.({ext_re})$")

flagged = []
for line in out.splitlines():
    if not line.startswith("?? "):
        continue
    path = line[3:].strip()
    if any(path.startswith(d) for d in excluded):
        continue
    if needle.search(path):
        flagged.append(path)

if flagged:
    print(f"[hook warning] untracked artifact files in the repo:")
    for p in flagged:
        print(f"  - {p}")
    print(f"\nIf intentional inputs, add to .gitignore or move to a cache dir.")
    print(f"If accidental outputs, clean before committing.")
PY
