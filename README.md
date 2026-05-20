# claude-configs

Personal Claude Code configuration: skills, plugins, hooks, and CLAUDE.md templates, packaged for one-click install on a fresh machine.

The goal is to capture the patterns that survive long multi-agent sessions — particularly the **Level 3 brain-dump pattern** that keeps state across `/compact` — so a new clone reproduces the working setup without re-deriving everything from scratch.

## Quick start

```bash
git clone https://github.com/teivng/claude-configs ~/.claude-configs
cd ~/.claude-configs
./install.sh --profile orchestration --project ~/path/to/your/project
```

Other profiles:

```bash
./install.sh --list-profiles
./install.sh --profile coding --project ~/work/repo
./install.sh --profile science          # no project-level pieces
./install.sh --hooks-only --project ~/path/to/repo
```

## What's in this repo

| Path | Purpose |
|---|---|
| [`install.sh`](install.sh) | Interactive one-click installer. Reads profiles, installs skills + plugins, copies hooks, prints CLAUDE.md template hints. |
| [`INSTRUCTIONS_FOR_AGENT.md`](INSTRUCTIONS_FOR_AGENT.md) | Self-contained brief for an LLM agent that needs to install this setup on a new machine. |
| [`profiles/`](profiles/) | YAML manifests of what to install per use case (`science`, `coding`, `orchestration`, `all`). |
| [`skills/`](skills/) | Custom skills bundled in this repo. Currently: `brain-dump` (Level 3 compaction preservation). |
| [`plugins.yaml`](plugins.yaml) | Plugin marketplaces + plugin IDs to register/install via `claude plugin`. |
| [`hooks/`](hooks/) | Project-agnostic hook scripts (`PreToolUse`, `Stop`, `SessionStart`) + default config + level-by-level documentation. |
| [`claude-md-templates/`](claude-md-templates/) | Paste-into-CLAUDE.md templates: `## Do NOT` block and `## Compaction preservation` stanza. Edit `{{placeholders}}` per project. |
| [`mcps/`](mcps/) | Documentation of claude.ai-hosted MCPs (Notion, Slack, Linear, etc.). No installable files — these are configured via claude.ai's web UI. |
| [`docs/`](docs/) | Long-form: orchestration writeup, compaction strategy (Levels 1/2/3 explained), hooks philosophy. |

## What this is NOT

- **A skill marketplace.** The `science` profile references external skills (K-Dense, Anthropic-hosted) by name, but doesn't redistribute them. Install those from their original sources.
- **A claude.ai account snapshot.** MCPs and hosted integrations live in your claude.ai account; this repo can't move them. The `mcps/README.md` documents which are in use; you re-authorize on a new machine via the web UI.
- **Opinionated about your project's invariants.** The hooks and CLAUDE.md templates leave all the project-specific details as placeholders. Edit before using.

## The compaction story (read this if nothing else)

If you only have time for one thing in this repo, read [`docs/compaction-strategy.md`](docs/compaction-strategy.md). It explains the three levels of investment for preserving state across `/compact`:

- **Level 1**: pass preservation directives to `/compact` (free, 30 sec).
- **Level 2**: `## Compaction preservation` stanza in CLAUDE.md (free, one-time).
- **Level 3**: brain-dump skill + SessionStart hook (≈30 min install, paid context for ~60-150 lines per dump).

This repo ships Level 2 templates and a working Level 3 installation. Pick the level your project needs.

## Philosophy

The patterns in this repo come from running a long multi-agent Claude Code session (eval_suite — variance-reduction ML pipeline at Blank Bio) and noticing what bit us. The findings are documented honestly in [`docs/orchestration-writeup.md`](docs/orchestration-writeup.md), including what didn't work and what was over-engineered.

Two principles that load-bear:

1. **Hooks beat prompts for invariants.** CLAUDE.md gets dropped under compaction; shell hooks survive forever and fire deterministically. Use hooks for mechanical rules; use CLAUDE.md for judgment calls. [Longer argument in `docs/hooks-philosophy.md`.](docs/hooks-philosophy.md)
2. **Project-agnostic by construction.** Every hook reads policy from `<project>/.claude/hook-config.json`; every CLAUDE.md piece is a template with `{{placeholders}}`. The repo doesn't know your project; it lets you tell it.

## Installing on a new machine — for humans

```bash
# Prereqs: Claude Code installed, git, python3 (3.8+). No extra Python
# packages required — the installer's YAML parser is stdlib-only.

git clone https://github.com/teivng/claude-configs ~/.claude-configs
cd ~/.claude-configs

# Inspect available profiles
./install.sh --list-profiles

# Install the one that fits
./install.sh --profile orchestration --project ~/work/some-repo

# Edit the per-project hook config to match the project
$EDITOR ~/work/some-repo/.claude/hook-config.json

# Paste the CLAUDE.md templates manually (the installer printed the paths)
$EDITOR ~/work/some-repo/CLAUDE.md
```

## Installing — for an agent

Read [`INSTRUCTIONS_FOR_AGENT.md`](INSTRUCTIONS_FOR_AGENT.md). It's self-contained and assumes no prior context about this repo.

## Contributing

The repo is intentionally personal — it's not meant to be a general-purpose skill collection. But if you find a bug in a hook or a typo in a template, PRs welcome.

The hooks are the only piece that's actively used in anger; the templates and docs are aspirational starting points. If you adapt this for a different project shape (e.g. a JS monorepo with a different "paths registry" convention), generalize the hook config schema rather than forking the scripts.
