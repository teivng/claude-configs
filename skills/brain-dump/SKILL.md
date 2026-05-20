---
name: brain-dump
description: |
  Capture the current session's working state to a structured engineering log
  on disk. Run before `/compact` so that critical state (modified files,
  active branch, in-flight subprocesses, recent decisions, open PRs) survives
  the context compression — the matching SessionStart hook injects the dump
  back into the new post-compact context.

  USE THIS SKILL when: (1) the user is about to run `/compact`, (2) the
  user explicitly asks to "dump state" or "save progress", or (3) a complex
  multi-agent task is approaching a natural pause and we'd want a fresh
  session to be able to pick it up.

  Do NOT use this for short single-turn tasks — the dump itself costs
  context, and brief sessions don't need it.
---

# Brain Dump

This skill captures structured session state to disk so it survives `/compact`.

## What gets dumped

The dump is written to `<project-root>/.claude/brain-dumps/latest.md` (overwriting any prior dump) and to a timestamped sibling for history. The
matching SessionStart hook re-injects `latest.md` into the new context after
compaction, so a fresh Claude can pick up where the prior session left off.

Each dump must contain these sections, in this order:

1. **Session header** — UTC timestamp, the user's last instruction (one-line
   summary), the active git branch, the active worktrees under
   `.claude/worktrees/` and their associated PR numbers.
2. **What changed** — a `git status --short` snapshot, plus a one-paragraph
   narrative of what the session has been working on.
3. **In-flight subprocesses** — any background Bash, Monitor, or Agent tasks
   the orchestrator is responsible for. Include PIDs / task IDs and what they
   are doing.
4. **Open PRs and their state** — output of `gh pr list` filtered to relevant
   branches. Include the title, base branch, and a one-line status.
5. **Recent decisions / rejected alternatives** — a concise list of design
   decisions made during the session and any approaches considered and
   rejected. Cite the file or memory entry where the decision is recorded.
6. **Next concrete actions** — what the user (or a resumed agent) should do
   next. Phrased as imperatives: "review PR #9", "land the brain-dump skill",
   etc.
7. **Quoted invariants** — verbatim, the contents of the project's CLAUDE.md
   `## Do NOT` block, if one exists. These must survive every compaction.

## How to invoke

A bash helper at the same path as this SKILL.md (`./capture.sh`) does the
mechanical state-gathering. Pipe its output into `latest.md`, then add the
narrative sections by reading recent conversation context and writing them
yourself. The helper is a starting point, not the whole dump.

Concrete steps:

```bash
PROJECT_ROOT="$(pwd)"  # or the relevant repo root
DUMP_DIR="${PROJECT_ROOT}/.claude/brain-dumps"
mkdir -p "$DUMP_DIR"

# 1. Mechanical capture
~/.claude/skills/brain-dump/capture.sh > "$DUMP_DIR/latest.md"

# 2. Open the dump and APPEND the narrative + decisions + next-actions
#    sections, drawing from conversation context. The orchestrator must
#    write these — they aren't recoverable from disk alone.
```

After step 2, also write a timestamped copy:

```bash
TS=$(date -u +%Y%m%dT%H%M%SZ)
cp "$DUMP_DIR/latest.md" "$DUMP_DIR/dump-${TS}.md"
```

## What the user types

The trigger phrases this skill responds to include:

- `/brain-dump`
- "dump state"
- "save current progress before I compact you"
- "snapshot the session"

When invoked, confirm completion with a one-line summary: "Dumped to
`.claude/brain-dumps/latest.md`; safe to `/compact` now."

## Companion components

- `~/.claude/skills/brain-dump/capture.sh` — bash helper that gathers
  mechanical state (git, gh, ps).
- `.claude/hooks/brain-dump-on-resume.sh` (project-local) — SessionStart
  hook on the `compact|clear` matcher that reads `latest.md` and emits it
  as `additionalContext` so the new post-compact Claude sees it.
- CLAUDE.md `## Compaction preservation` stanza — instructs the
  compaction summarizer what to preserve verbatim.

All three pieces should be present for the pattern to work end-to-end.
