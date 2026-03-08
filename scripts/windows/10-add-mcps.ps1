<#
Adds recommended MCP servers to Codex using the CLI.
Adjust paths before running.
#>

codex mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem C:\Users\YOUR_USER\Documents\Kumoriya
codex mcp add dart -- C:\flutter\bin\dart.bat mcp-server
codex mcp add fetch --env PYTHONIOENCODING=utf-8 -- uvx mcp-server-fetch --user-agent=KumoriyaCodex/0.1
codex mcp add playwright -- npx -y @playwright/mcp@latest

# Add GitHub separately with your token or OAuth if preferred.
