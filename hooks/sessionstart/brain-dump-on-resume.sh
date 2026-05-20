#!/bin/bash
# SessionStart hook (matcher: compact|clear) — injects the latest brain dump
# into the new post-compact context as `additionalContext`.
#
# Companion to ~/.claude/skills/brain-dump (the skill that writes the dump).
# Flow:
#   1. User runs /brain-dump just before compacting → latest.md written.
#   2. User runs /compact → conversation compresses, new session starts.
#   3. This hook fires on the matching SessionStart event with `compact`
#      matcher → reads latest.md → emits the SDK-standard JSON envelope
#      so Claude Code injects it into the new context.
#
# If no dump exists, exit 0 silently (do not error — first-ever compact is
# the most common case).
set -uo pipefail

# Resolve the project root from the hook's invocation cwd. Claude Code runs
# hook commands from the project root, so $PWD is the right anchor.
PROJECT_ROOT="$(pwd)"
DUMP_FILE="$PROJECT_ROOT/.claude/brain-dumps/latest.md"

if [ ! -f "$DUMP_FILE" ]; then
  # No dump available — nothing to inject. Exit clean.
  exit 0
fi

# Emit the SDK-standard envelope. The `additionalContext` field is parsed
# by Claude Code and injected as a system-reminder-like block at the start
# of the post-compact context. The `hookSpecificOutput.additionalContext`
# nesting is the canonical shape Anthropic's docs spec; the flat
# `additional_context` field is included for compatibility with editors
# that follow Cursor's format.
python3 - "$DUMP_FILE" <<'PY'
import json, sys

with open(sys.argv[1], "r") as f:
    dump = f.read()

# Wrap the dump in a clear preamble so the new Claude knows where it
# came from and what to do with it.
preamble = (
    "BRAIN DUMP from prior session (pre-compaction state). "
    "Use this as ground truth for in-flight work; don't re-investigate "
    "what's already documented here. "
    "If anything below conflicts with what you read on disk now, trust the disk.\n\n"
    "---\n\n"
)
ctx = preamble + dump

print(json.dumps({
    "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ctx},
    "additionalContext": ctx,
    "additional_context": ctx,
}))
PY
