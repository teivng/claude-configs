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

Before any `/compact`, invoke the `brain-dump` skill (or type
`/brain-dump`) to capture structured state to
`.claude/brain-dumps/latest.md`. After `/compact`, a SessionStart hook
(matcher `compact|clear`, wired in `.claude/settings.local.json`)
auto-injects that dump as `additionalContext` into the new context, so
the post-compact session inherits modified files, branch state, open
PRs, in-flight subprocesses, and recent decisions verbatim — not just
what the compaction summarizer chose to keep.

Manual flow if for any reason the hook doesn't fire: read
`.claude/brain-dumps/latest.md` directly at session start.
