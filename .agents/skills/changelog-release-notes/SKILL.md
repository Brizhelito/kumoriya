---
name: changelog-release-notes
description: "Use when the user asks to create, generate, update, or maintain CHANGELOG and Release Notes files for this app. Trigger keywords: changelog, release notes, notas de version, actualizar version, update release docs, crear release notes."
---

# Changelog + Release Notes System

Use this skill when the user asks for a release documentation update.

## Goal

Keep a predictable filesystem for release documentation and update it safely on each app update.

Language mode is internationalized with locale-separated release notes files.

## Default Scope

1. Maintain a root `CHANGELOG.md` as the canonical historical log.
2. Maintain versioned release notes under `docs/releases/`.
3. Keep a release index at `docs/releases/README.md`.
4. Prefer append-only history and avoid rewriting older release entries unless explicitly requested.
5. Keep exactly one file per locale and version:
   - `docs/releases/es/vX.Y.Z.md`
   - `docs/releases/en/vX.Y.Z.md`
6. Do not mix ES and EN in the same release note file.

## Required Inputs

Collect these inputs before writing:

1. Target version (for example: `v0.8.3` or `0.8.3`).
2. Release date (default to current date if user does not specify).
3. Change summary grouped by categories.
4. Locale coverage: ensure ES and EN files exist with equivalent content.

If the user does not provide enough detail, ask for missing inputs.

## Decision Flow

1. Identify release type:
   - patch: bugfix and low-risk changes
   - minor: additive features
   - major: breaking changes
2. Identify source of truth for version:
   - use explicit user-provided version first
   - otherwise read app/package version from project metadata
   - normalize to strict format `vX.Y.Z`
3. Check filesystem status:
   - if missing: create `CHANGELOG.md`, `docs/releases/`, `docs/releases/README.md`
   - if present: update existing files in place
4. Build release content sections:
   - Added
   - Changed
   - Fixed
   - Deprecated
   - Removed
   - Security
   - Breaking Changes (required for major releases)
5. Update index links and ensure the new release note file is listed first.

## Filesystem Contract

Use this layout:

```text
CHANGELOG.md
docs/
  releases/
    README.md
      es/
         vX.Y.Z.md
      en/
         vX.Y.Z.md
```

Normalize version file names to `vX.Y.Z.md` under locale subfolders.

## Update Rules

1. `CHANGELOG.md`
   - Keep entries newest-first.
   - Add heading format: `## [vX.Y.Z] - YYYY-MM-DD`.
   - Use a single language consistently in the changelog (default: English).
   - Keep category subsections only when they have content.
   - Never duplicate an existing version heading.
2. `docs/releases/es/vX.Y.Z.md` and `docs/releases/en/vX.Y.Z.md`
   - Create if missing, update if existing.
   - Keep each file single-language only.
   - Include in each locale file:
     - title + date
     - summary
     - categorized changes
     - migration notes (if needed)
     - known issues (optional)
3. `docs/releases/README.md`
   - Ensure a bullet list of available releases.
   - Keep newest-first.
   - Add or update links for both locales of the target version.

## Content Templates

Use these templates when creating missing files.

### CHANGELOG Entry

```md
## [vX.Y.Z] - YYYY-MM-DD

### Added
- ...

### Changed
- ...

### Fixed
- ...
```

### Release Notes File (ES)

```md
# Lanzamiento vX.Y.Z

Fecha: YYYY-MM-DD

## Resumen
- ...

## Agregado
- ...

## Cambios
- ...

## Corregido
- ...

## Notas de Migracion
- Ninguna.
```

### Release Notes File (EN)

```md
# Release vX.Y.Z

Date: YYYY-MM-DD

## Summary
- ...

## Added
- ...

## Changed
- ...

## Fixed
- ...

## Migration Notes
- None.
```

### Release Index

```md
# Release Notes

- vX.Y.Z (YYYY-MM-DD)
   - Espanol: [es/vX.Y.Z.md](./es/vX.Y.Z.md)
   - English: [en/vX.Y.Z.md](./en/vX.Y.Z.md)
```

## Quality Checks

Before finalizing:

1. Version appears exactly once as a heading in `CHANGELOG.md`.
2. Release file name and heading version match exactly.
3. Date format is `YYYY-MM-DD`.
4. Index includes a valid relative link.
5. No duplicated bullets caused by repeated updates.
6. If release is major, ensure a "Breaking Changes" section exists.
7. Verify ES and EN files are both present and not mixed-language.

## Response Contract

Return a concise report:

```md
Release Docs Update Report
- Version:
- Release type:
- Files created:
- Files updated:
- Notes:
- Risks or missing inputs:
```

## Safety Boundaries

1. Do not invent breaking changes.
2. Do not silently bump versions.
3. Do not delete historical release notes unless explicitly requested.
4. If change details are ambiguous, ask a short clarification instead of guessing.
5. Do not accept version strings outside strict `vX.Y.Z` format.