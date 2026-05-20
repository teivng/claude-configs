#!/bin/bash
# brain-dump/capture.sh
#
# Gathers mechanical session state for the brain-dump skill. Writes a
# Markdown block to stdout. The orchestrator pipes this into
# `.claude/brain-dumps/latest.md` and then APPENDS narrative sections
# (decisions, next actions) by writing them directly.
#
# Designed to be safe to run anywhere — degrades gracefully if a tool
# (gh, git) is missing.
set -uo pipefail

UTC_NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
CWD="$(pwd)"

# Try to find the repo root (defaults to CWD if not a git repo).
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$CWD")"
BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "(not a git repo)")"

# Worktrees under .claude/worktrees/ (the convention this skill assumes).
WORKTREES="$(find "$REPO_ROOT/.claude/worktrees" -maxdepth 1 -mindepth 1 -type d 2>/dev/null \
  | sed "s|$REPO_ROOT/||" | sort)"

cat <<EOF
# Brain dump — $UTC_NOW

## Session header

- Captured at: \`$UTC_NOW\` (UTC)
- Repo root: \`$REPO_ROOT\`
- Active branch: \`$BRANCH\`
- Active worktrees:
EOF
if [ -n "$WORKTREES" ]; then
  while IFS= read -r wt; do
    [ -n "$wt" ] && echo "  - \`$wt\`"
  done <<<"$WORKTREES"
else
  echo "  (none)"
fi
cat <<EOF

## What changed (git status)

\`\`\`
$(git -C "$REPO_ROOT" status --short 2>/dev/null | head -50)
\`\`\`

## Recent commits

\`\`\`
$(git -C "$REPO_ROOT" log --oneline -10 2>/dev/null)
\`\`\`

## Open pull requests

\`\`\`
$(gh pr list --json number,title,baseRefName,headRefName,state --limit 10 2>/dev/null \
  | python3 -c "
import json, sys
try:
    for p in json.load(sys.stdin):
        print(f\"  #{p['number']} [{p['state']}] {p['headRefName']} -> {p['baseRefName']}: {p['title']}\")
except Exception:
    print('  (no PRs or gh unavailable)')
" 2>/dev/null)
\`\`\`

## In-flight subprocesses (heuristic)

Background Python jobs touching the repo, if any:

\`\`\`
$(ps -eo pid,etime,pcpu,cmd 2>/dev/null \
  | grep -E "python.*$(basename "$REPO_ROOT")" \
  | grep -v grep \
  | head -10)
\`\`\`

## Recent decisions and next actions

> _The orchestrator must fill this section by writing it directly._
> _Capture: decisions made during this session, alternatives considered
> and rejected, and the concrete next actions for a fresh Claude or for
> the user._

EOF
