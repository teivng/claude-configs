# INSTRUCTIONS FOR AGENT

If you are a Claude (or any LLM-driven coding agent) reading this file to set up a fresh machine with these configs, this is your install brief.

## What you're installing

A personal Claude Code configuration: skills, plugins, hooks, CLAUDE.md templates, and documentation. Inventory:

- **Skill**: `brain-dump` (Level 3 compaction preservation).
- **Plugins**: `pr-review-toolkit@claude-plugins-official`, `superpowers@superpowers-dev`, `pyright-lsp@claude-plugins-official`.
- **Project-agnostic hooks**: `block-loose-files`, `block-hardcoded-paths`, `warn-untracked-artifacts`, `brain-dump-on-resume`.
- **CLAUDE.md templates**: `do-not-block`, `compaction-preservation`.
- **Documentation**: orchestration writeup, compaction strategy (Levels 1/2/3), hooks philosophy.

## Profiles

Four profiles in `profiles/`:

- `science` — scientific research skills (mostly references; the actual skill files ship with the user's claude.ai account, not this repo).
- `coding` — PR review + pyright + hygiene hooks; for day-to-day engineering.
- `orchestration` — brain-dump infrastructure + worktree skills; for long multi-agent sessions.
- `all` — union of the above.

## Decision tree before installing

1. **Is the user running Claude Code on this machine?** If not, the plugin install commands won't work. Stop and ask.
2. **Which profile?** Default to `orchestration` if the user mentioned multi-agent work or long sessions. Default to `coding` otherwise. Don't install `all` unless asked — it's wasteful for short-term projects.
3. **What's the target project?** Hooks install into `<project>/.claude/hooks/`. If the user is in a research codebase, install there. If they're setting up a fresh dev environment with no specific project, ask.

## How to install

```bash
git clone https://github.com/teivng/claude-configs ~/.claude-configs
cd ~/.claude-configs
./install.sh --profile <profile-name> --project <target-project-dir>
```

The installer handles:

- Skill copies into `~/.claude/skills/`.
- Marketplace registration (`claude plugin marketplace add`).
- Plugin installation (`claude plugin install`).
- Hook script copying into `<project>/.claude/hooks/`.
- Hook wiring into `<project>/.claude/settings.local.json` (idempotent — won't duplicate existing entries).
- Per-project `hook-config.json` copy (only if it doesn't already exist).

What the installer does NOT handle automatically:

- **CLAUDE.md templates.** They contain `{{placeholders}}` that need human edits. The installer prints paths and exits; the user pastes manually.
- **MCPs.** These are claude.ai-hosted. The user re-authorizes via the claude.ai web UI. See `mcps/README.md`.
- **Restart prompt.** Some plugins need a Claude Code session restart to pick up. The installer prints a reminder at the end.

## What to do AFTER install

1. **Edit `<project>/.claude/hook-config.json`** to match the project's conventions. The bundled defaults (`/home/`, `/Users/`, `/root/` as forbidden prefixes; `src/**/paths.py` as the allowlist file; etc.) are sensible but project-specific. Customize.
2. **Paste the CLAUDE.md templates** into the project's CLAUDE.md, edit the placeholders, strip the leading HTML comment.
3. **Smoke-test the brain-dump skill**: type `/brain-dump` in a Claude Code session. The skill should write to `<project>/.claude/brain-dumps/latest.md`. Inspect the file. If it looks reasonable, run `/compact` and verify the SessionStart hook injects the dump into the new context.

## What to AVOID

- **Do not** modify hook scripts to skip the smoke test in `install.sh`. The smoke test is the safety check; if a hook fails it, the installer should refuse to wire it.
- **Do not** copy hooks into `~/.claude/settings.json` (user-level). Hooks belong in project-level `.claude/settings.local.json` so they don't accidentally fire on unrelated projects.
- **Do not** install all four profiles "just to be safe." The brain-dump skill in particular adds context overhead; only install it if the user has multi-hour sessions.
- **Do not** redistribute the K-Dense or Anthropic scientific-* skills from `~/.claude/skills/` — they have their own license terms. The `science` profile only documents them; it doesn't copy.

## If something fails

- **Hook smoke test fails**: read the stderr message. The hook scripts are small; usually a path bug or a missing dep (jq isn't used anymore; we use python3). Don't bypass — fix or skip the hook.
- **Plugin install fails**: check `claude plugin marketplace list`. If a marketplace isn't registered, add it manually with `claude plugin marketplace add <repo>`.
- **Profile not found**: run `./install.sh --list-profiles` to see available names.

## What to tell the user when done

A short summary like:

> Installed claude-configs profile `<name>`:
>  - <N> skills, <M> plugins, <K> hooks wired.
>  - CLAUDE.md templates available at `~/.claude-configs/claude-md-templates/`; paste manually.
>  - Edit `<project>/.claude/hook-config.json` to customize per-project hook policy.
>  - Restart your Claude Code session to pick up the plugin changes.
>  - Try `/brain-dump` before your next `/compact` to verify the Level 3 pattern works.

Avoid celebrating; users want to know what to do next, not what you did.
