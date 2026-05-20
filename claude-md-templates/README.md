# CLAUDE.md templates

Two templates designed to be pasted into your project's CLAUDE.md:

- [`do-not-block.template.md`](do-not-block.template.md) — MUST-NOT rules at the top of CLAUDE.md, in the highest-survival position. Edit the `{{placeholders}}` to match your project's invariants.
- [`compaction-preservation.template.md`](compaction-preservation.template.md) — the stanza that instructs the compaction summarizer what to keep, plus the brain-dump workflow notes.

## Why two separate templates

`Do NOT` is read on every agent action. Compaction preservation is read only at compact boundaries. Different audiences, different positions in the file. Don't merge them.

## Placement

```
CLAUDE.md
├── Do NOT block          ← top (this template)
├── Compaction preservation  ← high (this template)
├── What this project is
├── ... (project-specific architecture, conventions, etc.)
```

## Workflow

1. Copy template content into your CLAUDE.md.
2. Edit every `{{placeholder}}`.
3. Strip the leading HTML comment block.
4. Commit.

The templates intentionally leave the "what to put in placeholders" decision to you — they're not opinionated about your project's specific invariants. The structure is the load-bearing part.
