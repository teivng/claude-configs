<!--
TEMPLATE — paste this into your project's CLAUDE.md, then edit the
placeholders in {{}} to match the project. Strip this HTML comment when done.

Replaces a generic compaction summarizer's instinct to drop "old" information
with an explicit list of what to keep. Combined with the brain-dump skill +
SessionStart hook (see hooks/sessionstart/), this is Level 3 compaction
preservation.
-->

## Compaction preservation

When this conversation gets compacted, **always preserve**:

- The list of files modified in the current session and which branch
  they're on
- Active git worktree paths (under `.claude/worktrees/`) and their PR status
- The "Do NOT" block above, verbatim
- {{PROJECT-SPECIFIC CONVENTION 1 — e.g. "the convention that compression is
  a sweep axis, never inside the embedder"}}
- {{PROJECT-SPECIFIC CONVENTION 2 — e.g. "the `paths.py` registry pattern;
  no hardcoded absolute paths in module code"}}
- Rejected-alternative decisions documented in `~/.claude/projects/.../memory/`
  (or your project's equivalent decision log)
- The git remote rule: do not push without asking
- Any in-flight background subprocesses (PIDs + what they're doing)

If you must drop something, drop architecture prose and re-reference
the file; never drop the Do NOT block or the worktree/PR list.

### Brain-dump workflow (active)

This project wires the automatic dump→restore loop (both hooks live in
`.claude/settings.local.json`):

- **Before every `/compact`**, a PreCompact hook (matcher `manual|auto`)
  writes a deterministic snapshot — timestamp, git branch/HEAD/status/log,
  and SLURM jobs — to `.claude/brain-dumps/auto-snapshot.md`. This is
  automatic; you don't have to remember anything.
- **After `/compact`**, a SessionStart hook (matcher `compact|clear`)
  re-injects that snapshot (plus the richer `latest.md` if present) as
  `additionalContext`, so the post-compact session inherits modified
  files, branch state, and in-flight jobs verbatim — not just what the
  compaction summarizer chose to keep.

Optionally, for a richer reasoning-heavy dump (open PRs, rejected
alternatives, next concrete actions, quoted invariants), invoke the
`brain-dump` skill (`/brain-dump`) before `/compact`; it writes
`.claude/brain-dumps/latest.md`, which the restore hook injects alongside
the deterministic snapshot.

Manual fallback if for any reason a hook doesn't fire: read
`.claude/brain-dumps/auto-snapshot.md` (and `latest.md`) directly at
session start.
