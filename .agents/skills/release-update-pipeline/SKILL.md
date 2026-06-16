---
name: release-update-pipeline
description: Ship a Kumoriya release end-to-end. Use for version bump, changelog, builds, checksums, R2 upload, update.json, git tag, release gate. Builds run on GitHub Actions (Android + Windows in parallel), publish to R2 + API.
---

# Release Update Pipeline

Hybrid pipeline: local prep (version bump + changelog + git) then GitHub Actions handles builds, R2 upload, API publish, and GitHub Release.

## Trigger

- release / publish version / cut release
- actualizar version / subir binarios
- R2 / changelog + build + deploy

## How to use

1. Read `references/pipeline.md` for required inputs, conventions, all phases, and the release gate.
2. Execute **Local Phases** (0-3) in order on the developer machine.
3. Push to both remotes (`origin` + `deploy`), then trigger the CI workflow.
4. Monitor the CI run; on failure, diagnose from logs and re-trigger.
5. After CI succeeds, execute **Post-CI Phase** (4) to update local manifests.
6. End with the Output Contract report from the reference.

## Hard rules

- R2: binaries + `update.json` only.
- Never publish manifest pointing to missing artifacts.
- Release not "done" until the release gate is fully true.
- Builds run on CI — never build locally for release (except emergency fallback).
- CI mirror repo: `BrizhelDev/kumoriya` (source of truth: `Brizhelito/kumoriya`).

## CI Architecture

```
build-android (ubuntu-latest)  ─┐
                                 ├──► publish (ubuntu-latest)
build-windows (windows-latest) ─┘
```

- **build-android**: signed APK → R2 upload → GH Release
- **build-windows**: Flutter build → Inno Setup installer → R2 upload → GH Release
- **publish**: combines both artifact metadata → API publish → update.json to R2

Workflow: `.github/workflows/release.yml` (triggered via `workflow_dispatch`).
