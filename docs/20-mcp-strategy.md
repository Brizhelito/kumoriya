# MCP Strategy for Kumoriya

## Recommended MCPs

### Always useful
- filesystem
- dart / flutter
- github

### Useful in specific situations
- fetch
- playwright
- local kumoriya MCP if you keep one

## Recommended behavior

### filesystem
Use for:
- file reads/writes
- scaffolding
- controlled refactors

### dart
Use for:
- format
- analyze
- test
- Flutter project inspection

### github
Use for:
- repo inspection
- issue/PR review
- remote context
Do not commit tokens in project config.

### fetch
Use mainly for:
- reading official docs
- checking public pages
Not a blocker for core app work.

### playwright
Use only when:
- scraping is JS-heavy
- you need browser evidence
- you need DOM/network proof

## Example CLI commands

```bash
codex mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem C:\Users\YOUR_USER\Documents\Kumoriya
codex mcp add dart -- C:\flutter\bin\dart.bat mcp-server
codex mcp add fetch --env PYTHONIOENCODING=utf-8 -- uvx mcp-server-fetch --user-agent=KumoriyaCodex/0.1
codex mcp add playwright -- npx -y @playwright/mcp@latest
```

Add GitHub at the user level if you use a PAT.
