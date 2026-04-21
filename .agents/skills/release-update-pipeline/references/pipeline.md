# Release Update Pipeline — Full Reference

Loaded on demand by the `release-update-pipeline` skill.

## Required Inputs

Collect before execution:
1. target version (`X.Y.Z`)
2. release date (`YYYY-MM-DD`, default: today)
3. release scope (patch/minor/major)
4. platforms to publish (android/windows)
5. R2 bucket and path conventions
6. distribution files expected for this version
7. website static metadata destination path (default: `visual_reference/public/data/release-feed.json`)
8. git branch and tag policy

If an input is missing, ask only for the missing minimum.

## Canonical Conventions

Defaults unless the user overrides:
- release tag: `vX.Y.Z`
- Flutter app version: `X.Y.Z+N`
- changelog heading: `## [vX.Y.Z] - YYYY-MM-DD`
- android artifact: `artifacts/android/vX.Y.Z/kumoriya-X.Y.Z.apk`
- windows artifact: `artifacts/windows/vX.Y.Z/Kumoriya-X.Y.Z-windows-x64-setup.exe`
- update manifest URL path: `/update.json`
- website release feed: `visual_reference/public/data/release-feed.json`
- website feed format: one JSON with `latest` + `changelog[]`

Separation rule:
- R2: binaries + app update manifest only.
- Website: static metadata in website repo/CDN, no R2 runtime fetch for release cards.

## Phases

### Phase 0 — Preflight
1. Confirm intent and scope.
2. Inspect git status + existing version references.
3. Verify toolchain: Flutter, Dart, Git, upload tool (`aws` or `rclone`).

Do not proceed if toolchain broken.

### Phase 1 — Version Bump
1. `apps/kumoriya_app/pubspec.yaml`
2. Any metadata files pinning version.
3. Version strings in naming.

Validate: no stale version references in release-critical files.

### Phase 2 — Changelog + Release Notes
Use the `changelog-release-notes` skill.

Required outputs:
1. root `CHANGELOG.md` new top entry
2. `docs/releases/en/vX.Y.Z.md`
3. `docs/releases/es/vX.Y.Z.md`
4. `docs/releases/README.md` newest-first

Rule: append-only history.

### Phase 3 — Build + Validation
1. `dart format`
2. `dart analyze`
3. relevant tests
4. platform builds

```powershell
cd apps/kumoriya_app
flutter pub get
flutter test
flutter build apk --release
flutter build windows --release
```

If any step fails, stop publish and report blocker.

### Phase 4 — Artifact Hygiene
1. Locate binaries.
2. Rename to canonical filenames.
3. Generate SHA-256.

```powershell
Get-FileHash <path> -Algorithm SHA256
```

Record local paths and hashes in the report.

### Phase 5 — Update Manifest (update.json)
Per platform:
- `latest_version`
- `url`
- `release_notes`

Validate:
1. URLs match uploaded filenames
2. version strings consistent
3. JSON valid

Never publish manifest pointing to missing artifacts.

### Phase 6 — Website Static Metadata (Astro/Vercel)

Output: `visual_reference/public/data/release-feed.json`

Structure:
- `generated_at` (ISO)
- `latest` (version/tag/date/channel/downloads)
- `changelog[]` newest-first with EN/ES notes

Website rules (strict):
- Inline changelog content in JSON (`notes.en` / `notes.es`).
- No `notes_urls` to remote markdown.
- R2 links used only on user download click.

Schema:
```json
{
  "generated_at": "2026-03-31T00:00:00Z",
  "latest": {
    "version": "0.1.2",
    "tag": "v0.1.2",
    "date": "2026-03-31",
    "channel": "alpha",
    "downloads": {
      "android": { "url": "...", "file_name": "..." },
      "windows": { "url": "...", "file_name": "..." }
    }
  },
  "changelog": [
    {
      "version": "0.1.2",
      "tag": "v0.1.2",
      "date": "2026-03-31",
      "notes": { "en": "...", "es": "..." }
    }
  ]
}
```

Sources of truth:
1. `releases/versions/vX.Y.Z/release.json`
2. `docs/releases/en/vX.Y.Z.md`
3. `docs/releases/es/vX.Y.Z.md`
4. `docs/releases/README.md`

Validate:
1. JSON parses
2. latest tag/version = release tag
3. `latest.downloads.*.url` matches uploaded artifacts
4. `changelog[0].tag` = current tag
5. `changelog[*].notes` non-empty for EN and ES
6. no `notes_urls`
7. committed in same release PR

### Phase 7 — Upload to Cloudflare R2
Upload artifacts first, manifest last.

```powershell
aws s3 cp <local> s3://<bucket>/artifacts/android/vX.Y.Z/kumoriya-X.Y.Z.apk --endpoint-url <r2>
aws s3 cp <local> s3://<bucket>/artifacts/windows/vX.Y.Z/Kumoriya-X.Y.Z-windows-x64-setup.exe --endpoint-url <r2>
aws s3 cp <update_json> s3://<bucket>/update.json --endpoint-url <r2>
```

Or rclone:
```powershell
rclone copy <local> <remote>:<bucket>/artifacts/android/vX.Y.Z/
rclone copy <local> <remote>:<bucket>/artifacts/windows/vX.Y.Z/
rclone copy <update_json> <remote>:<bucket>/
```

Without creds: prepare files, provide exact commands.

### Phase 8 — Git Commits + Tag
Reviewable slices:
1. `chore(release): bump version to vX.Y.Z`
2. `docs(release): add notes for vX.Y.Z`
3. `chore(release): publish artifact metadata for vX.Y.Z` (if tracked)

Tag:
```powershell
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin <branch>
git push origin vX.Y.Z
```

No unrelated changes.

### Phase 9 — Release Gate (all must be true)
- version updated everywhere
- changelog entry once
- EN + ES notes
- analyze clean
- tests pass
- builds succeed
- artifact names normalized
- SHA-256 generated
- website metadata generated + validated
- binaries uploaded
- update.json uploaded last
- git commits clean
- release tag created
- residual risks stated

## Failure Policy

On block, return:
1. failing phase
2. exact command/error
3. impact
4. fastest safe recovery

Never claim complete if upload, manifest, build, or tag missing.

## Output Contract

```md
Release Execution Report
- Version: vX.Y.Z
- Date: YYYY-MM-DD
- Release type: patch|minor|major
- Platforms: android/windows
- Files changed:
- Artifacts generated:
- Checksums:
- Website metadata status:
- R2 upload status:
- Manifest status:
- Git commits:
- Git tag:
- Validation run:
- Residual risks:
- Next action:
```
