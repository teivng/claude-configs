#!/bin/bash
# SessionStart hook (matcher: compact|clear) — injects the latest brain dump
# into the new post-compact context as `additionalContext`.
#
# Companion to two writers:
#   1. ~/.claude/skills/brain-dump — model-driven, writes the rich latest.md
#      when the user manually runs /brain-dump (optional).
#   2. precompact/brain-dump-snapshot.sh — the PreCompact hook, writes the
#      deterministic auto-snapshot.md before EVERY compaction (automatic).
#
# Flow:
#   1. (optional) User runs /brain-dump          → latest.md written.
#   2. User runs /compact → PreCompact hook fires → auto-snapshot.md written.
#   3. Conversation compresses, new session starts.
#   4. This hook fires on the matching SessionStart event → reads whichever of
#      the two dumps exist → emits the SDK-standard JSON envelope so Claude Code
#      injects them into the new context.
#
# If neither dump exists, exit 0 silently (do not error — first-ever compact is
# the most common case).
set -uo pipefail

# Resolve the project root from the hook's invocation cwd. Claude Code runs
# hook commands from the project root, so $PWD is the right anchor.
PROJECT_ROOT="$(pwd)"
DUMP_FILE="$PROJECT_ROOT/.claude/brain-dumps/latest.md"
AUTO_FILE="$PROJECT_ROOT/.claude/brain-dumps/auto-snapshot.md"

# Inject whichever of the two dumps exist:
#   latest.md        — rich, model-written by the /brain-dump skill (optional)
#   auto-snapshot.md — deterministic, written by the PreCompact hook every compact
# If neither exists, exit clean (first-ever compact is the common case).
if [ ! -f "$DUMP_FILE" ] && [ ! -f "$AUTO_FILE" ]; then
  exit 0
fi

# Emit the SDK-standard envelope. The `additionalContext` field is parsed
# by Claude Code and injected as a system-reminder-like block at the start
# of the post-compact context. The `hookSpecificOutput.additionalContext`
# nesting is the canonical shape Anthropic's docs spec; the flat
# `additional_context` field is included for compatibility with editors
# that follow Cursor's format.
python3 - "$DUMP_FILE" "$AUTO_FILE" <<'PY'
import json, os, sys

dump_path, auto_path = sys.argv[1], sys.argv[2]
parts = []
if os.path.isfile(dump_path):
    with open(dump_path) as f:
        parts.append("## Manual brain-dump (/brain-dump skill)\n\n" + f.read())
if os.path.isfile(auto_path):
    with open(auto_path) as f:
        parts.append("## Deterministic snapshot (PreCompact hook)\n\n" + f.read())

# Wrap the dump(s) in a clear preamble so the new Claude knows where they
# came from and what to do with them.
preamble = (
    "BRAIN DUMP from prior session (pre-compaction state). "
    "Use this as ground truth for in-flight work; don't re-investigate "
    "what's already documented here. "
    "If anything below conflicts with what you read on disk now, trust the disk.\n\n"
    "---\n\n"
)
ctx = preamble + "\n\n".join(parts)

print(json.dumps({
    "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ctx},
    "additionalContext": ctx,
    "additional_context": ctx,
}))
PY
