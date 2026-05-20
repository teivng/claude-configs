# Hooks

Three levels of compaction-and-hygiene investment, in increasing effort. Pick the level appropriate to your project's lifetime and complexity.

## Level 1 — Manual `/compact` with preservation directives (free, zero install)

Just pass arguments to `/compact` every time:

```
/compact preserve <project-specific invariants here>
```

Examples:

- `/compact preserve current branch, modified files, the survival ABC contract, any rejected-alternative decisions`
- `/compact preserve in-flight PRs, the convention that compression is a sweep axis (never inside the embedder)`

Adds 30 seconds at each compact boundary. No CLAUDE.md edit, no hooks. The cheapest move and often enough for short-lived projects.

## Level 2 — CLAUDE.md `## Compaction preservation` stanza (free, one-time)

Add a stanza to your CLAUDE.md that the compaction summarizer reads. Even a bare `/compact` becomes preservation-aware because the summarizer is instructed what to keep.

Template in this repo: [`claude-md-templates/compaction-preservation.template.md`](../claude-md-templates/compaction-preservation.template.md). Edit the placeholders and append to your CLAUDE.md.

Combined with Level 1 (passing explicit args at compact time), this covers ~80% of long-session use cases.

## Level 3 — Brain Dump skill + SessionStart hook (≈30 min install)

Active state preservation across compaction. Three components, all installable from this repo:

1. **`brain-dump` skill** (`skills/brain-dump/`) — user invokes `/brain-dump` before `/compact`. The skill writes structured session state (modified files, branch, open PRs, in-flight subprocesses, decisions made, next actions, quoted invariants) to `<project-root>/.claude/brain-dumps/latest.md`.
2. **SessionStart hook** (`hooks/sessionstart/brain-dump-on-resume.sh`) — fires on the `compact|clear` matcher after compaction. Reads `latest.md` and emits it as `additionalContext` in the SDK-standard JSON envelope, so Claude Code injects it into the new context.
3. **CLAUDE.md `## Compaction preservation` stanza** — instructs the in-flight compaction summarizer what to keep; tells the post-compact Claude to read `.claude/brain-dumps/latest.md` if for any reason the hook didn't fire.

Documented results in the broader community (sigalovskinick gist): 12+ compaction cycles with full decision-history retention vs. coherence loss after 2-3 cycles without the pattern.

**Caveat**: there's no documented `PreCompact` hook in Claude Code (only `SessionStart` with `compact` matcher fires *after* compaction). That means the dump step is manual — the user types `/brain-dump` before typing `/compact`. The restore step is automatic. If you find your version of Claude Code supports `PreCompact`, you can wire the dump there too; the skill is invocable as a slash command.

## Independent hooks (not tied to compaction)

These can be installed individually; they help long-running projects stay clean and don't depend on the brain-dump pattern:

| Hook | Event | What it does |
|---|---|---|
| [`pretooluse/block-loose-files.sh`](pretooluse/block-loose-files.sh) | `PreToolUse Write` | Blocks scratch/debug/adhoc files written to repo root. Re-routes to `scripts/`, `tests/`, or `src/`. |
| [`pretooluse/block-hardcoded-paths.sh`](pretooluse/block-hardcoded-paths.sh) | `PreToolUse Write\|Edit` | Blocks hardcoded absolute paths (`/home/...`, `/Users/...`, `/root/...`) inside module code; allowlists a project's `paths.py` registry. |
| [`stop/warn-untracked-artifacts.sh`](stop/warn-untracked-artifacts.sh) | `Stop` | Warns (does not block) on untracked artifact files (`*.npy`, `*.pt`, `*.h5`, `*.log`, ...) in the repo. Prevents accidentally committing 12 GB embedding caches. |
| [`sessionstart/brain-dump-on-resume.sh`](sessionstart/brain-dump-on-resume.sh) | `SessionStart compact\|clear` | Injects the latest brain dump (`<root>/.claude/brain-dumps/latest.md`) into the new post-compact context. |

All hooks are **project-agnostic**: they read policy from `<project-root>/.claude/hook-config.json` (or fall back to `hooks/default-hook-config.json` if no project config exists). Edit the patterns and paths to match your project's conventions.

## Installing

See the top-level [`install.sh`](../install.sh) for the one-click installer. The hooks-only install:

```bash
./install.sh --hooks-only --project /path/to/your/project
```

This:

1. Copies the hook scripts into `<project>/.claude/hooks/`.
2. Copies `default-hook-config.json` into `<project>/.claude/hook-config.json` (you edit this to customize per-project policy).
3. Patches `<project>/.claude/settings.local.json` to wire the hooks (creates the file if it doesn't exist).
4. Smoke-tests each hook on a fixture and refuses to wire any that fail.

## Why hooks beat prompts for behavioral invariants

CLAUDE.md rules get dropped under context compaction. Hooks are external processes — they survive forever, fire deterministically, and don't compete with the agent's attention. The trade-off is that they're shell scripts with all the brittleness that implies; keep them small, smoke-test them every time you change them, and prefer Python policy files over inline bash for anything non-trivial.

See [`docs/hooks-philosophy.md`](../docs/hooks-philosophy.md) for the longer argument.
