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

The dump lives at `<project-root>/.claude/brain-dumps/latest.md`, with a
timestamped sibling kept for history. The matching SessionStart hook re-injects
`latest.md` into the new context after compaction, so a fresh Claude can pick up
where the prior session left off.

**A dump is a synthesis of the existing `latest.md` and this session, never a
blank-page rewrite.** See "Synthesis rules" below — that step is the point of
the skill, not an optimization.

Each dump must contain these sections, in this order:

1. **Session header** — UTC timestamp, the user's last instruction (one-line
   summary), the active git branch, the active worktrees under
   `.claude/worktrees/` and their associated PR numbers.
2. **What changed** — a `git status --short` snapshot, plus a one-paragraph
   narrative of what has happened since the previous dump.
3. **In-flight subprocesses** — any background Bash, Monitor, or Agent tasks
   the orchestrator is responsible for. Include PIDs / task IDs and what they
   are doing.
4. **Open PRs and their state** — output of `gh pr list` filtered to relevant
   branches. Include the title, base branch, and a one-line status.
5. **Recent decisions / rejected alternatives** — a concise list of design
   decisions and any approaches considered and rejected. Cite the file or
   memory entry where the decision is recorded. Carries across dumps: a
   decision stays until it is superseded, not until it is old.
6. **Next concrete actions** — what the user (or a resumed agent) should do
   next. Phrased as imperatives: "review PR #9", "land the brain-dump skill",
   etc.
7. **Quoted invariants** — verbatim, the contents of the project's CLAUDE.md
   `## Do NOT` / `## Hard rules` block, if one exists. These must survive every
   compaction. Re-read the file; never copy them forward unverified.

## Synthesis rules

The previous dump is the starting draft. Read it in full before writing
anything, then give **every claim in it an explicit disposition**:

- **Keep** — still true and still load-bearing. Invariants, live decisions with
  a rejected alternative behind them, pointers to where results actually live,
  naming/ID schemes, anything a fresh session cannot re-derive from disk.
- **Rewrite** — true in substance but the specifics moved: a branch SHA, a file
  count, a job id, a node, a "next action" that is now half done. Update it to
  what is true now.
- **Drop** — the work finished and is recorded somewhere durable (a results
  file, a write-up, a memory entry); the claim was refuted by what is on disk;
  a decision was superseded; a job completed; a next-action was done. Say where
  it went if it went somewhere, in a few words, then stop carrying it.

Four rules that make the synthesis trustworthy:

- **Re-derive mechanical facts, never copy them.** Branch, SHA, changed-file
  counts, running jobs, sentinel/progress counts, PR states all come from a
  fresh `capture.sh` run or a fresh command. Copying a stale number forward is
  worse than omitting it, because the next session will trust it.
- **Disk beats the old dump** on any conflict, always. If they disagree,
  investigate briefly, then write what the disk says.
- **Stay bounded.** This file is injected into every post-compact context, so it
  has a running cost. Aim for roughly 150 lines. When it grows past that, cut
  prose and architecture explanation (re-readable from the repo), never facts,
  invariants or in-flight state.
- **Uncertain means say so.** Mark a carried-over claim you could not verify as
  unverified rather than silently promoting it to ground truth.

Report the synthesis to the user in the confirmation line: what was dropped and
why, and what was rewritten. That is how they catch a bad drop while the context
to notice it still exists.

## How to invoke

A bash helper at the same path as this SKILL.md (`./capture.sh`) does the
mechanical state-gathering. It is a starting point, not the whole dump — the
narrative, decision and next-action sections come from conversation context and
must be written by the orchestrator.

Concrete steps:

```bash
PROJECT_ROOT="$(pwd)"  # or the relevant repo root
DUMP_DIR="${PROJECT_ROOT}/.claude/brain-dumps"
mkdir -p "$DUMP_DIR"

# 1. Archive the current dump BEFORE touching it, so a bad synthesis is
#    always recoverable.
TS=$(date -u +%Y%m%dT%H%M%SZ)
[ -f "$DUMP_DIR/latest.md" ] && cp "$DUMP_DIR/latest.md" "$DUMP_DIR/dump-${TS}.md"

# 2. Fresh mechanical capture, to a scratch file — NOT over latest.md.
~/.claude/skills/brain-dump/capture.sh > /tmp/capture-${TS}.md
```

3. Read the archived `latest.md` and the fresh capture together, apply the
   synthesis rules above, and write the merged result to `latest.md`. The
   capture supplies sections 1-4; the prior dump plus this session's context
   supply 5-7.

4. Confirm to the user with a one-line summary plus what changed in the dump:
   "Dumped to `.claude/brain-dumps/latest.md` (carried N decisions, dropped the
   finished X, rewrote the Y state); safe to `/compact` now."

## What the user types

The trigger phrases this skill responds to include:

- `/brain-dump`
- "dump state"
- "save current progress before I compact you"
- "snapshot the session"

## Companion components

- `~/.claude/skills/brain-dump/capture.sh` — bash helper that gathers
  mechanical state (git, gh, ps).
- `.claude/hooks/sessionstart/brain-dump-on-resume.sh` (project-local) —
  SessionStart hook on the `compact|clear` matcher that reads `latest.md` and
  emits it as `additionalContext` so the new post-compact Claude sees it.
- `.claude/hooks/precompact/brain-dump-snapshot.sh` (project-local) — PreCompact
  hook writing the deterministic `auto-snapshot.md`. It is the floor under this
  skill: it fires on every compaction whether or not anyone ran `/brain-dump`.
  It writes a separate file and never touches `latest.md`.
- CLAUDE.md `## Compaction preservation` stanza — instructs the
  compaction summarizer what to preserve verbatim.

All pieces should be present for the pattern to work end-to-end.
