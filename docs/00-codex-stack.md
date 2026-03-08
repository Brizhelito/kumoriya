# Kumoriya Codex Stack

This repo is intentionally designed around Codex-native primitives.

## Core control plane

- `AGENTS.md` = project instructions and architectural guardrails
- `.codex/config.toml` = project-scoped configuration
- `.codex/rules/` = command execution policy outside the sandbox
- `.agents/skills/` = reusable task workflows and expertise
- `.codex/agents/*.toml` = multi-agent role configs
- `.codex/prompts/` = versioned prompt templates
- Codex app settings = personalization, Git prompts, local environments, MCP activation

## Why this stack

It gives Kumoriya:
- explicit instructions in Git
- reusable skills across app/CLI/IDE
- controllable MCP setup
- worktree-friendly parallelism
- repeatable bootstrap and validation flows
