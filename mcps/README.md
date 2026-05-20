# MCPs

This directory exists to document the MCP (Model Context Protocol) servers used in this personal Claude Code setup. **There are no installable files here** — the MCPs in question are hosted by claude.ai and configured via the claude.ai web interface, not via local config files.

## Why MCPs aren't in this repo

The MCP servers used (Notion, Slack, Linear, Gmail, Google Calendar, IDE) appear in this environment under tool names like `mcp__claude_ai_Notion__notion-search`. The `mcp__claude_ai_*` prefix is the convention claude.ai uses for **hosted** MCP integrations — ones configured through claude.ai/account or the Claude Code GUI, with auth handled by claude.ai's backend.

That means:

- There's no JSON file on disk we can commit.
- There's no `mcp install <name>` command we can put in `install.sh`.
- On a new machine, you re-authorize each MCP via claude.ai's UI after logging in.

## Which MCPs the orchestrator-Claude uses

| MCP | What it provides | Used for |
|---|---|---|
| **Notion** (`mcp__claude_ai_Notion__*`) | Search + fetch pages, create/update pages and comments, query databases | Devlog reading + writing, finding prior research (e.g. Phil's compression sweep documented at `33d87c413fa581959be0f98b528f6dd5`) |
| **Slack** (`mcp__claude_ai_Slack__*`) | Send/read messages, search channels, manage threads | Escalating questions to teammates when Notion / repo docs are insufficient |
| **Linear** (`mcp__claude_ai_Linear__*`) | Issues, projects, comments, attachments | Tracking work items, cross-linking PRs to tickets |
| **Gmail** (`mcp__claude_ai_Gmail__*`) | Read/send mail | Rare — most communication goes through Slack |
| **Google Calendar** (`mcp__claude_ai_Google_Calendar__*`) | Events, scheduling, suggest-time | Calendar integration for the `schedule` skill |
| **IDE** (`mcp__ide__*`) | Editor diagnostics, code execution in Jupyter | Live pyright/pylance diagnostic stream surfaced in chat |

## Local MCPs (not currently in use)

If you ever want a non-hosted MCP — e.g., a local Postgres MCP for querying a project database — those DO live in `~/.claude.json` under `mcpServers` or in `<project>/.claude/.mcp.json` (project-local). Format:

```json
{
  "mcpServers": {
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres", "postgresql://localhost/mydb"]
    }
  }
}
```

If you add any local MCPs to your setup, drop the JSON snippet here and update `install.sh` to copy it into place.

## Re-authorizing on a new machine

1. Log in to claude.ai.
2. Go to Settings → Integrations (or whatever the current UI calls it).
3. For each MCP listed above, click "Connect" and follow the OAuth flow.
4. Open Claude Code; the integrations should be available within a session.

If the new machine is offline or the user can't log in to claude.ai, the MCPs are unavailable — there's no way around the hosted dependency.
