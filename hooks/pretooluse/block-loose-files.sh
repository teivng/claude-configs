#!/bin/bash
# PreToolUse hook for Write: block "scratch/debug/adhoc" files at repo root.
#
# Project-agnostic: reads policy from `<project-root>/.claude/hook-config.json`
# (key `block_loose_files`), falling back to bundled defaults if no project
# config exists.
#
# Behavior:
#   - For Write tool calls only.
#   - If `tool_input.file_path` resolves inside the current project root
#     AND lands at the repo root (no slash in the relative path)
#     AND starts with one of the configured patterns,
#     exit 2 with a directive stderr message.
#   - Allowed directories (e.g. `tests/`, `scripts/`) are exempt.
#
# Exit 0 = allow, exit 2 = block.
set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONFIG_FILE="${PROJECT_ROOT}/.claude/hook-config.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG="${SCRIPT_DIR}/../default-hook-config.json"

# Use project config if it exists; else fall back to the bundled default.
if [ -f "$CONFIG_FILE" ]; then
  CFG="$CONFIG_FILE"
else
  CFG="$DEFAULT_CONFIG"
fi

# Delegate to the Python policy script for parsing + matching. Pipe
# stdin (the tool-input JSON) through.
exec python3 "${SCRIPT_DIR}/block-loose-files.py" --project-root "$PROJECT_ROOT" --config "$CFG"
