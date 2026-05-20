<!--
TEMPLATE — paste at the TOP of your project's CLAUDE.md (above "What this
project is"). Edit the rules to match your project. Strip this HTML comment
when done.

Why at the top: rules buried inside architecture prose get dropped first
under compaction. The summarizer reads CLAUDE.md from the top; the Do NOT
block survives if it lives there.

Why MUST-NOT language: research on Claude Code workflows finds that
permissive ("prefer X") rules are routinely ignored when the agent thinks
there's a good reason. MUST-NOT rules force the agent to escalate
("the rule says X, but here's why I think we should...") rather than
silently violate.
-->

## Do NOT (hard rules — must-not, even under compaction)

These are the rules that have bitten us repeatedly. Surfaced at the top
so they survive context refresh. Detailed rationale lives later in the
file; the rules themselves are non-negotiable.

- **MUST NOT** {{rule 1 — e.g. "mean-pool inside the embedder. Compression is
  a sweep axis owned by `src/<pkg>/compression/`."}}
- **MUST NOT** push to `origin` without explicit user authorization.
  This is per-action — "go ahead, fire away" on an earlier prompt does
  not pre-authorize subsequent pushes from spawned agents. When in
  doubt, ask.
- **MUST NOT** modify test files to make a failing test pass. Fix the
  code or surface the failure; do not edit tests without explicit
  instruction.
- **MUST NOT** {{rule 4 — e.g. "hardcode absolute paths (`/home/...`,
  `/Users/...`) in module code. Every external path resolves through
  `src/<pkg>/paths.py`."}}
- **MUST NOT** {{rule 5 — e.g. "add new fields to `paths.py`,
  `PipelineConfig`, or other registries without checking existing
  conventions first."}}
- **MUST NOT** {{rule 6 — project-specific invariant}}
