---
name: changelog-release-notes
description: Create or update Kumoriya CHANGELOG and release notes. Use for changelog, release notes, notas de version, actualizar version.
---

# Changelog + Release Notes

Maintain a predictable filesystem for release documentation (EN + ES).

## How to use

1. Read `references/guide.md` for filesystem contract, rules, templates, quality checks.
2. Collect required inputs (version, date, summary, locales). Ask if missing.
3. Update these targets:
   - root `CHANGELOG.md` (append new top entry)
   - `docs/releases/en/vX.Y.Z.md`
   - `docs/releases/es/vX.Y.Z.md`
   - `docs/releases/README.md` (newest-first)
4. Run quality checks from the reference before returning the Response Contract report.

## Hard rules

- Append-only history. Never rewrite old versions unless explicitly asked.
- One file per locale per version. Never mix ES + EN.
- Strict `vX.Y.Z` format.
- Ask on ambiguity instead of guessing.
