---
name: release-update-pipeline
description: Use when preparing and publishing a Kumoriya app release end-to-end: version bump, changelog/release notes, build artifacts, checksums, R2 upload, update.json publish, git commits/tags, and final release checklist.
---

# Kumoriya Release Update Pipeline (End-to-End)

Use this skill for a full release cycle.

## Goal

Ship a new Kumoriya version with reproducible artifacts and auditable release metadata.

Coverage includes:
- versions
- changelog + release notes
- compile/build
- artifact naming and checksums
- R2 upload + update manifest update
- git commits + tag
- final release TODO checklist

## Trigger Keywords

- release
- publish version
- actualizar version
- subir binarios
- R2
- changelog + build + deploy
- cut release

## Required Inputs

Collect before execution:
1. target version (`X.Y.Z`)
2. release date (`YYYY-MM-DD`, default: today)
3. release scope (patch/minor/major)
4. platforms to publish (android/windows)
5. R2 bucket and path conventions
6. distribution files expected for this version
7. git branch and tag policy

If an input is missing, ask only for the missing minimum.

## Canonical Conventions

Use these defaults unless the user says otherwise:
- release tag: `vX.Y.Z`
- app version in Flutter: `X.Y.Z+N` (increment build number)
- changelog heading: `## [vX.Y.Z] - YYYY-MM-DD`
- android artifact path: `artifacts/android/vX.Y.Z/kumoriya-X.Y.Z.apk`
- windows artifact path: `artifacts/windows/vX.Y.Z/Kumoriya-X.Y.Z-windows-x64-setup.exe`
- update manifest URL path: `/update.json`

## Workflow

### Phase 0: Preflight

1. Confirm clean intent and scope.
2. Inspect current git status and existing version references.
3. Verify required tooling availability:
- Flutter
- Dart
- Git
- Upload tool (`aws` or `rclone`)

Do not proceed to publish if toolchain is broken.

### Phase 1: Version Bump

Update version sources consistently:
1. app version in `apps/kumoriya_app/pubspec.yaml`
2. any release metadata files that pin version
3. ensure naming strings reference the new version

Validation:
- no stale previous version references in release-critical files

### Phase 2: Changelog + Release Notes

Use `changelog-release-notes` skill for docs consistency.

Required outputs:
1. root `CHANGELOG.md` with new top entry
2. `docs/releases/en/vX.Y.Z.md`
3. `docs/releases/es/vX.Y.Z.md`
4. `docs/releases/README.md` updated newest-first

Rule:
- append-only history, no rewrite of old versions unless asked

### Phase 3: Build + Validation

Run minimum validation honestly:
1. `dart format` (targeted or package-wide)
2. `dart analyze`
3. relevant tests
4. build artifacts for requested platforms

Typical commands:
```powershell
cd apps/kumoriya_app
flutter pub get
flutter test
flutter build apk --release
flutter build windows --release
```

If any step fails, stop publish and report exact blocker.

### Phase 4: Artifact Hygiene

1. Locate built binaries.
2. Rename/copy to canonical release filenames.
3. Generate checksums (SHA-256 preferred).

Example checksum command:
```powershell
Get-FileHash <path> -Algorithm SHA256
```

Record final local paths and hashes in the release report.

### Phase 5: Update Manifest (update.json)

Update manifest for each published platform:
- `latest_version`
- `url`
- `release_notes`

Validation:
1. URLs point to exact uploaded filenames
2. version strings are consistent
3. JSON is valid

Never publish manifest pointing to missing artifacts.

### Phase 6: Upload to Cloudflare R2

Upload artifacts first, manifest last.

Preferred order:
1. upload platform binaries
2. verify remote object existence
3. upload updated `update.json`

CLI examples (adapt to environment):

Using AWS CLI with R2 S3 endpoint:
```powershell
aws s3 cp <local_file> s3://<bucket>/artifacts/android/vX.Y.Z/kumoriya-X.Y.Z.apk --endpoint-url <r2_endpoint>
aws s3 cp <local_file> s3://<bucket>/artifacts/windows/vX.Y.Z/Kumoriya-X.Y.Z-windows-x64-setup.exe --endpoint-url <r2_endpoint>
aws s3 cp <update_json> s3://<bucket>/update.json --endpoint-url <r2_endpoint>
```

Using rclone:
```powershell
rclone copy <local_file> <remote>:<bucket>/artifacts/android/vX.Y.Z/
rclone copy <local_file> <remote>:<bucket>/artifacts/windows/vX.Y.Z/
rclone copy <update_json> <remote>:<bucket>/
```

If credentials are unavailable, prepare all files and provide exact upload commands.

### Phase 7: Git Commits + Tag

Commit in reviewable slices:
1. `chore(release): bump version to vX.Y.Z`
2. `docs(release): add notes for vX.Y.Z`
3. `chore(release): publish artifact metadata for vX.Y.Z` (if tracked)

Then tag:
```powershell
git tag -a vX.Y.Z -m "Release vX.Y.Z"
```

Optional push sequence:
```powershell
git push origin <branch>
git push origin vX.Y.Z
```

Do not include unrelated changes.

### Phase 8: Release TODO Checklist (Gate)

All must be true before declaring done:
- version updated everywhere required
- changelog entry present once
- EN + ES notes created
- analyze clean
- relevant tests passed
- release builds succeeded
- artifact names/paths normalized
- SHA-256 hashes generated
- binaries uploaded to R2
- update.json uploaded last
- git commits clean and scoped
- release tag created
- residual risks explicitly stated

## Failure Policy

If blocked, return:
1. failing phase
2. exact command/error
3. impact
4. fastest safe recovery path

Never claim release complete if upload, manifest, build, or tag is missing.

## Output Contract

Return this final structure:

```md
Release Execution Report
- Version: vX.Y.Z
- Date: YYYY-MM-DD
- Release type: patch|minor|major
- Platforms: android/windows
- Files changed:
- Artifacts generated:
- Checksums:
- R2 upload status:
- Manifest status:
- Git commits:
- Git tag:
- Validation run:
- Residual risks:
- Next action:
```
