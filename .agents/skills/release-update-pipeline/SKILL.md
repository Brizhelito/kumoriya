---
name: release-update-pipeline
description: Ship a Kumoriya release end-to-end. Use for version bump, changelog, builds, checksums, R2 upload, update.json, git tag, release gate.
---

# Release Update Pipeline

Full 10-phase pipeline for cutting a Kumoriya release.

## Trigger

- release / publish version / cut release
- actualizar version / subir binarios
- R2 / changelog + build + deploy

## How to use

1. Read `references/pipeline.md` for required inputs, conventions, all 10 phases, and the release gate.
2. Execute phases in order. Do not skip.
3. Delegate Phase 2 to the `changelog-release-notes` skill.
4. On any failure, stop and return the failure-policy block.
5. End with the Output Contract report from the reference.

## Hard rules

- R2: binaries + `update.json` only. Website feed served from static JSON.
- Never publish manifest pointing to missing artifacts.
- Release not "done" until the release gate (Phase 9) is fully true.
