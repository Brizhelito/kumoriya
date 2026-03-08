# Codex-Native System Design

## Equivalent to Windsurf concepts

| Windsurf-like concept | Codex-native equivalent |
| --- | --- |
| Project rules / guardrails | `AGENTS.md` + `.codex/rules/*.rules` |
| Skills | `.agents/skills/*` |
| MCP servers | `[mcp_servers.*]` in `.codex/config.toml` |
| Workflows | explicit skills + versioned prompts |
| Memory | `AGENTS.md`, nested docs, repo state |
| Parallel tasks | worktrees + multi-agent roles |
| Recurrent jobs | automations + skills |

## Important design rule

Do not try to copy a Windsurf mental model literally.
Use Codex-native building blocks and version them in Git.
