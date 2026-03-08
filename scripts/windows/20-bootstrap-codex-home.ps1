<#
Creates a minimal global Codex home guidance file.
#>

$codexHome = Join-Path $HOME ".codex"
New-Item -ItemType Directory -Force -Path $codexHome | Out-Null

@"
# Global Codex defaults

- Be pragmatic.
- Keep diffs reviewable.
- Validate before claiming success.
- Ask before adding heavy dependencies.
"@ | Set-Content -Encoding UTF8 (Join-Path $codexHome "AGENTS.md")
