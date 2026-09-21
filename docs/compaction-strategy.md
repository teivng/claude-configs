# Compaction strategy — three levels

Context compaction is unavoidable in long Claude Code sessions. Auto-compaction at ~95% context, manual `/compact` whenever the user triggers it. What gets dropped is up to the compaction summarizer, and by default it drops "old" information — which often includes the decisions that justify the current state.

Three levels of investment to fight this, in increasing effort. Most projects don't need Level 3 — Level 2 is the sweet spot.

## Level 1 — Pass preservation directives at `/compact` time

**Effort**: 30 seconds per compact.
**Install**: none.

When you type `/compact`, pass an argument:

```
/compact preserve current branch, modified files, key invariants, recent decisions
```

The compaction summarizer reads the argument as part of its instruction. Specific items get kept verbatim. Vague items get summarized.

**When to use**: short-lived projects, occasional users, anyone who doesn't want to maintain config.

**Trade-off**: relies on you remembering to pass the args every time. Easy to forget on a hectic Friday.

## Level 2 — CLAUDE.md `## Compaction preservation` stanza

**Effort**: 5 minutes to write, one-time.
**Install**: paste a template into CLAUDE.md.

The compaction summarizer reads CLAUDE.md before writing the summary. A stanza like:

```markdown
## Compaction preservation

When compacting, always preserve:
- The list of files modified in the current session
- Project-specific invariants (X, Y, Z)
- Rejected-alternative decisions documented in <decision log>
- The git remote rule: do not push without asking
- In-flight subprocesses
```

…gets picked up automatically. Even a bare `/compact` becomes preservation-aware.

Template available at [`../claude-md-templates/compaction-preservation.template.md`](../claude-md-templates/compaction-preservation.template.md).

**When to use**: any project where you expect to compact more than 2-3 times.

**Trade-off**: stanza is static. If your in-flight state changes during the session (e.g. you spawn a subagent), the stanza doesn't know about it. The compaction summarizer might still drop it.

## Level 3 — Brain Dump skill + SessionStart hook

**Effort**: 30 minutes to install, ~30 seconds per compaction to invoke.
**Install**: see [`../install.sh --profile orchestration`](../install.sh).

Active state preservation. The user invokes a `/brain-dump` skill that writes structured session state to disk; a SessionStart hook fires after compaction and injects that state back into the new context.

Components:

1. **`brain-dump` skill** ([`../skills/brain-dump/SKILL.md`](../skills/brain-dump/SKILL.md)) — user invokes `/brain-dump` before `/compact`. The skill writes structured state (modified files, branch, open PRs, in-flight subprocesses, decisions made, alternatives rejected, next concrete actions, quoted invariants) to `<project-root>/.claude/brain-dumps/latest.md`. Model-driven, **optional** — it captures rich reasoning a deterministic script can't. It **synthesizes rather than overwrites**: the prior dump is archived first, then every claim in it is kept, rewritten or dropped on purpose (see "Synthesis" below).
2. **PreCompact hook** ([`../hooks/precompact/brain-dump-snapshot.sh`](../hooks/precompact/brain-dump-snapshot.sh)) — fires on the `manual|auto` matcher *before* every compaction. Writes a deterministic factual snapshot (timestamp, git branch/HEAD/status/log, SLURM jobs if present) to `<project-root>/.claude/brain-dumps/auto-snapshot.md`. This is the **automatic floor**: it runs on every `/compact`, manual or auto, with no model turn and no reliance on you remembering to dump. Writes a separate file so it never clobbers `latest.md`. Always exits 0 — never blocks compaction.
3. **SessionStart hook** ([`../hooks/sessionstart/brain-dump-on-resume.sh`](../hooks/sessionstart/brain-dump-on-resume.sh)) — fires on the `compact|clear` matcher. Reads whichever of `latest.md` / `auto-snapshot.md` exist and emits them as `additionalContext` in the SDK-standard JSON envelope. Claude Code injects this into the new context, where it appears at the top as a system-reminder-like block.
4. **CLAUDE.md `## Compaction preservation` stanza** — same template as Level 2, but with a section explaining the brain-dump workflow.

The flow (the PreCompact + SessionStart hooks are automatic; the `/brain-dump` skill is the optional rich layer on top):

```
[user]    → /compact
[hook]    → PreCompact fires, writes .claude/brain-dumps/auto-snapshot.md (deterministic state)
[compact] → conversation compresses
[hook]    → SessionStart fires, reads auto-snapshot.md (+ latest.md if present), emits additionalContext
[claude]  → new session starts with the snapshot pre-loaded

  (optional richer dump, layered on top:)
[user]    → /brain-dump   (before /compact)
[skill]   → archives the old latest.md to dump-<TS>.md, re-derives the mechanical
            facts, synthesizes old + new into .claude/brain-dumps/latest.md
```

**Documented results in the community**: 12+ compaction cycles with full decision-history retention (sigalovskinick gist) vs. coherence loss after 2-3 cycles without the pattern.

**When to use**: research codebases with multi-week timelines, projects where you spawn many subagents, anything where re-deriving state from disk every compact would lose load-bearing context (e.g. the rationale behind a non-obvious design choice).

**Trade-offs**:

- **The dump step is now automatic** via the PreCompact hook (matcher `manual|auto`), which earlier versions of this repo said wasn't possible. Every `/compact` writes a fresh deterministic `auto-snapshot.md` before compacting, so you can never forget to dump the factual state. The `/brain-dump` skill is still manual — but it's now an *optional richer layer*, not the only line of defense. If you skip it, you still get the snapshot; if you run it, you get both.
- **A dump that overwrites loses everything the last one knew.** This is the failure mode we actually hit: a session that ends on topic B replaces a dump that was all about topic A, and topic A is gone from every future context. Hence synthesis — but synthesis has its own failure mode, an unbounded file that grows every cycle and is injected into every post-compact context. The skill resolves that by giving each carried claim an explicit disposition (keep / rewrite / drop) and holding the file near 150 lines, cutting prose before facts.
- **Carried-forward facts go stale silently.** A branch SHA or job id copied from the last dump is worse than an absent one, because the next session trusts it. The skill therefore re-derives every mechanical fact from a fresh capture and treats disk as authoritative over the previous dump on any conflict.
- **`brain-dump` skill writes ~60-150 lines per invocation**. That's context the orchestrator's next turn has to read. Cost-benefit favors the dump for multi-hour sessions; not worth it for short ones. (The PreCompact snapshot is much smaller — ~20-40 lines — and always worth it.)
- **The hook's `additionalContext` mechanism is documented in Anthropic's SDK reference but the field-naming has been inconsistent across editor integrations** (`additionalContext` vs `additional_context` vs `hookSpecificOutput.additionalContext`). The bundled hook emits all three variants for compatibility.

## Empirical observation from building this

The first version of the brain-dump skill in this repo was tested on the actual session that built it. Result: the seeded `latest.md` is 152 lines and successfully captured (a) the two PR numbers in flight, (b) the four post-merge follow-ups identified by pr-review-toolkit's silent-failure-hunter and pr-test-analyzer, (c) the rejected design alternatives, and (d) the quoted MUST-NOT block.

A fresh post-compact Claude reading that dump should be able to continue the work without re-investigating any of those facts. Which was the whole point.

## What we'd recommend

- **Solo projects, single-week scope**: Level 1.
- **Team projects, multi-week scope**: Level 2.
- **Research codebases, multi-month scope, agent orchestration**: Level 3.

Don't install Level 3 if you don't need it — the dump output is real context burn, and short sessions don't benefit. But once you've felt the pain of losing a multi-hour orchestration thread to compaction, Level 3 is cheap insurance.
