# Changelog + Release Notes — Full Reference

Loaded on demand by the `changelog-release-notes` skill.

## Default Scope

1. Root `CHANGELOG.md` = canonical historical log.
2. Versioned notes under `docs/releases/`.
3. Release index at `docs/releases/README.md`.
4. Append-only history. Do not rewrite old entries unless asked.
5. One file per locale and version:
   - `docs/releases/es/vX.Y.Z.md`
   - `docs/releases/en/vX.Y.Z.md`
6. Never mix ES + EN in the same file.

## Required Inputs

1. Target version (e.g. `v0.8.3`).
2. Release date (default: today).
3. Change summary by categories.
4. Locale coverage (ES + EN both present).

Ask for missing inputs, do not guess.

## Decision Flow

1. Release type: patch (bugfix) / minor (additive) / major (breaking).
2. Version source: user-provided first, else read from project metadata, normalize to `vX.Y.Z`.
3. Filesystem: create missing `CHANGELOG.md` / `docs/releases/` / `README.md`, else update in place.
4. Sections: Added / Changed / Fixed / Deprecated / Removed / Security / Breaking Changes (required for major).
5. Update index, newest-first.

## Filesystem Contract

```
CHANGELOG.md
docs/
  releases/
    README.md
    es/vX.Y.Z.md
    en/vX.Y.Z.md
```

## Update Rules

### CHANGELOG.md
- Newest-first.
- Heading: `## [vX.Y.Z] - YYYY-MM-DD`.
- Single language (default English).
- Omit empty subsections.
- Never duplicate a version heading.

### docs/releases/{es,en}/vX.Y.Z.md
- Single language per file.
- Include: title + date, summary, categorized changes, migration notes, optional known issues.

### docs/releases/README.md
- Bullet list newest-first.
- Link both locales for each version.

## Templates

### CHANGELOG entry
```md
## [vX.Y.Z] - YYYY-MM-DD

### Added
- ...

### Changed
- ...

### Fixed
- ...
```

### Release notes (ES)
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

### Release notes (EN)
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

### Release index
```md
# Release Notes

- vX.Y.Z (YYYY-MM-DD)
  - Espanol: [es/vX.Y.Z.md](./es/vX.Y.Z.md)
  - English: [en/vX.Y.Z.md](./en/vX.Y.Z.md)
```

## Quality Checks

1. Version appears exactly once as heading in `CHANGELOG.md`.
2. Release file name + heading version match exactly.
3. Date format `YYYY-MM-DD`.
4. Index includes valid relative link.
5. No duplicated bullets from repeated updates.
6. Major release: "Breaking Changes" section present.
7. ES + EN files both present, not mixed-language.

## Response Contract

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
3. Do not delete historical notes unless asked.
4. Ask on ambiguity, do not guess.
5. Reject version strings outside `vX.Y.Z`.
