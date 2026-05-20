#!/bin/bash
# PreToolUse hook for Write|Edit: block hardcoded absolute paths in module code.
#
# Project-agnostic: reads policy from `<project-root>/.claude/hook-config.json`
# (key `block_hardcoded_paths`), falling back to bundled defaults.
#
# Policy fields:
#   - forbidden_prefixes: list of path prefixes that may not appear inside
#     quoted strings within enforce_in files (e.g. "/home/", "/Users/").
#   - enforce_in: glob list of files to enforce on (e.g. "src/**/*.py").
#   - allowlist_files: glob list of files exempted (typically the project's
#     paths registry module — the one place where hardcoded defaults are
#     legitimate).
#
# Exit 0 = allow, exit 2 = block.
set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONFIG_FILE="${PROJECT_ROOT}/.claude/hook-config.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG="${SCRIPT_DIR}/../default-hook-config.json"

if [ -f "$CONFIG_FILE" ]; then
  CFG="$CONFIG_FILE"
else
  CFG="$DEFAULT_CONFIG"
fi

exec python3 "${SCRIPT_DIR}/block-hardcoded-paths.py" --project-root "$PROJECT_ROOT" --config "$CFG"
