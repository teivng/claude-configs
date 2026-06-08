#!/bin/bash
# PreCompact hook — writes a deterministic state snapshot to
# .claude/brain-dumps/auto-snapshot.md before EVERY compaction (manual or auto).
#
# Why this exists: the brain-dump *skill* is model-driven and only runs when the
# user manually invokes /brain-dump. This hook is the deterministic floor — it
# guarantees a factual snapshot on every /compact even if the skill wasn't run.
# The companion SessionStart hook (sessionstart/brain-dump-on-resume.sh)
# re-injects this file (plus any richer latest.md) into the post-compact context.
#
# This closes the gap called out in docs/compaction-strategy.md: historically the
# DUMP step was manual (user had to type /brain-dump) because no PreCompact hook
# was documented. PreCompact IS supported (matcher `manual|auto`), so the dump
# step is now automatic too. Wire it with matcher "manual|auto".
#
# Design notes:
#   - Writes a SEPARATE file (auto-snapshot.md), never latest.md, so a richer
#     skill-written brain-dump is never clobbered. The restore hook injects both.
#   - NEVER blocks compaction: every path exits 0. A snapshot bug must never
#     prevent the user from compacting. (PreCompact CAN block via exit 2 — we
#     deliberately never do.)
#   - Only read-only, fast commands (git, and squeue if present). Safe to run
#     even on a shared login node.
#   - Project-agnostic: captures git state always; SLURM jobs only if `squeue`
#     exists. Add project-specific captures (tmux, docker ps, PID files) below.
set -uo pipefail

# Claude Code sets CLAUDE_PROJECT_DIR; fall back to cwd (it runs hooks from the
# project root). Resolve once so every capture below shares the same anchor.
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
DUMP_DIR="$PROJECT_ROOT/.claude/brain-dumps"
OUT="$DUMP_DIR/auto-snapshot.md"

mkdir -p "$DUMP_DIR" 2>/dev/null || exit 0

# Best-effort: read the compaction trigger (manual|auto) from stdin JSON.
# PreCompact delivers {"trigger": "manual"|"auto", ...} on stdin. We don't
# require it — a parse failure just omits the line.
INPUT="$(cat 2>/dev/null || true)"
TRIGGER="$(printf '%s' "$INPUT" | python3 -c $'import sys,json\ntry:\n  print(json.load(sys.stdin).get("trigger",""))\nexcept Exception:\n  print("")' 2>/dev/null || true)"

{
  echo "# Auto-snapshot (PreCompact)"
  echo
  echo "- Written: $(date '+%Y-%m-%d %H:%M:%S %Z') on $(hostname 2>/dev/null)"
  [ -n "$TRIGGER" ] && echo "- Compaction trigger: $TRIGGER"
  echo "- Project: $PROJECT_ROOT"
  echo

  if git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    echo "## Git"
    echo '```'
    echo "branch: $(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    echo "HEAD:   $(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null)"
    echo '```'
    echo
    echo "### Modified / untracked (git status --porcelain, first 60)"
    echo '```'
    git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | head -60
    echo '```'
    echo
    echo "### Recent commits"
    echo '```'
    git -C "$PROJECT_ROOT" log --oneline -8 2>/dev/null
    echo '```'
    echo
  fi

  # SLURM jobs — only on clusters with `squeue` (skipped silently elsewhere).
  if command -v squeue >/dev/null 2>&1; then
    echo "## SLURM jobs (${USER:-unknown})"
    echo '```'
    squeue -u "${USER:-$(whoami 2>/dev/null)}" -o "%.12i %.22j %.8T %.10M %.5D %R" 2>/dev/null | head -40
    echo '```'
    echo
  fi

  # --- Project-specific captures (uncomment / add as needed) ---------------
  # Background subprocesses you started this session won't survive compaction
  # context; record anything whose PID/state you'd want the next session to know.
  #
  # echo "## tmux sessions"; echo '```'; tmux ls 2>/dev/null; echo '```'; echo
  # echo "## docker"; echo '```'; docker ps --format '{{.ID}} {{.Names}} {{.Status}}' 2>/dev/null; echo '```'; echo
} > "$OUT" 2>/dev/null || exit 0

exit 0
