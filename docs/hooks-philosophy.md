# Hooks philosophy — why hooks beat prompts for invariants

A short note explaining why this repo invests in hooks rather than longer CLAUDE.md files.

## The failure mode

A typical Claude Code session has three rules that matter for hygiene:

1. "Don't write scratch files at repo root."
2. "Don't hardcode absolute paths in module code."
3. "Don't push to `origin` without explicit user authorization."

You can write these in CLAUDE.md. They'll work, mostly. Until they don't:

- **CLAUDE.md gets compacted.** The rule list is on lines 200-300 of a 500-line file. Half-way through a long session, the summarizer drops it. Claude doesn't know the rule anymore.
- **CLAUDE.md has a hierarchy problem.** "Don't hardcode paths" is on the same level as "the survival ABC's `predict_risk` returns higher = worse." Both are stated as conventions. The agent ranks them by recency / contextual relevance. The hygiene rule loses.
- **CLAUDE.md is advisory.** The agent reads it as guidance, weighs it against the immediate task, and makes a judgment call. Sometimes "I'll just write `scratch_run.py` here, I'll move it later" wins. There's no enforcement.

## What hooks do differently

Hooks are external processes that fire on tool calls. They run BEFORE the tool effect lands. Their exit code determines whether the tool call succeeds (0) or fails (2). Critically:

- **The agent can't ignore a hook.** Exit 2 blocks the tool call. The agent sees the stderr message and re-issues differently.
- **Hooks survive compaction.** They live in `settings.json` and shell scripts on disk. The agent's context doesn't store them.
- **Hooks are deterministic.** Same input → same output. No judgment, no creativity, no "but in this case..."
- **Hooks are auditable.** You can read the script. You can `chmod -x` it to disable. You can `bash -x` to debug.

## What hooks DON'T do well

- **Anything requiring judgment.** "Don't introduce parallel abstractions" — a hook can't tell whether `_run_prognostic_cv_v2` is a parallel abstraction or a legitimate variant. That's CLAUDE.md territory.
- **Anything requiring whole-file or whole-codebase context.** Hooks see one tool call at a time. They can't reason about "is this refactor net-positive for the project."
- **Anything that should warn rather than block.** PostStop / Stop hooks can warn (emit to stderr without exit 2), but UX-wise warnings get glossed over. PreToolUse with exit 2 is the assertive form; reserve it for things that are unambiguously bad.

## The split

Use hooks for: **mechanical rules with no judgment, where every violation is bad.**

Use CLAUDE.md for: **conventions that require judgment, where context determines whether something is fine.**

Use both for: **rules that are mechanical but worth explaining.** (The hook enforces; the CLAUDE.md entry explains why so the agent doesn't fight the hook.)

## The hooks in this repo

| Hook | Why it's a hook, not a CLAUDE.md rule |
|---|---|
| `block-loose-files.sh` | Mechanical pattern matching. "Files starting with `test_` at repo root" has no judgment component. |
| `block-hardcoded-paths.sh` | Mechanical regex. Either the file matches the pattern or it doesn't. The allowlist exception (`paths.py`) is itself mechanical. |
| `warn-untracked-artifacts.sh` | Mechanical. Untracked `*.npy` files are essentially always wrong. Warning rather than blocking because there are legitimate transient cases (a quick smoke-test cache) that shouldn't be hard-blocked. |
| `brain-dump-on-resume.sh` | Mechanical context injection. Read a file → emit JSON. No judgment. |

The hooks I considered and rejected:

- ❌ **"Don't introduce parallel abstractions to existing modules"** — too judgment-heavy. A hook can't tell what "parallel" means.
- ❌ **"Don't add new fields to PipelineConfig without checking conventions"** — too project-specific to be a portable hook; better as a CLAUDE.md rule.
- ❌ **"Run `pytest -q` before committing"** — already covered by pre-commit hooks at the git level. Adding a Claude-Code-level wrapper is over-engineering.

## Cost

Hooks are shell scripts. They're fragile. The first version of `block-hardcoded-paths.sh` in this session had a heredoc bug that consumed stdin; the auto-mode classifier caught it, and the fix moved the policy logic into a separate `.py` file with the shell wrapping it via `exec python3`. That's the typical maturity path: inline bash → Python policy file + bash entry point.

Smoke-test every hook. The repo includes test invocations as inline comments / examples. Don't trust a hook you haven't seen fail on a fixture and pass on a known-good input.

## Bottom line

Hooks are not a substitute for CLAUDE.md. They're a complement. Hooks handle the bottom of the maintainability stack — mechanical, deterministic, unambiguous rules. CLAUDE.md handles the top — judgment calls, project shape, design philosophy.

Both fail in their own ways. Hooks fail loudly (exit 2 in your face). CLAUDE.md rules fail silently (the agent just stopped following them). Loud failure is recoverable; silent failure is not. That's why the cheap, mechanical rules should live in hooks first.
