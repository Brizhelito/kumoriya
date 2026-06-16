# Release Update Pipeline — Full Reference

Loaded on demand by the `release-update-pipeline` skill.

## Required Inputs

Collect before execution:
1. target version (`X.Y.Z`)
2. release date (`YYYY-MM-DD`, default: today)
3. release scope (patch/minor/major)
4. release notes summary (EN + ES, short one-liner for the manifest)
5. git branch (default: `main`)

If an input is missing, ask only for the missing minimum.

## Canonical Conventions

Defaults unless the user overrides:
- release tag: `vX.Y.Z`
- Flutter app version: `X.Y.Z+N` (increment N from previous release)
- changelog heading: `## [vX.Y.Z] - YYYY-MM-DD`
- android artifact: `artifacts/android/vX.Y.Z/kumoriya-X.Y.Z-arm64-v8a.apk`
- windows artifact: `artifacts/windows/vX.Y.Z/Kumoriya-X.Y.Z-windows-x64-setup.exe`
- update manifest: `releases/manifests/update.json`
- release metadata: `releases/versions/vX.Y.Z/release.json`
- R2 bucket: `kumoriya-releases`
- R2 public base: `https://pub-8159019abe1741a097538b976c19722c.r2.dev`
- API publish endpoint: `https://api.kumoriya.online/internal/releases/publish`

## Remotes

- **origin** → `https://github.com/Brizhelito/kumoriya.git` (source of truth)
- **deploy** → `https://github.com/BrizhelDev/kumoriya.git` (CI mirror, Actions run here)

`gh` CLI must be authenticated with both accounts. Switch with `gh auth switch -u <user>`.

---

## Local Phases

### Phase 0 — Preflight
1. Confirm version, scope, and summaries (EN + ES).
2. Inspect `git status` — clean working tree required.
3. Verify `gh auth status` shows both Brizhelito and BrizhelDev accounts.
4. Check `flutter --version` matches CI (stable channel).
5. Run `dart format` and `dart analyze` on `apps/kumoriya_app/lib`.

Do not proceed if dirty tree or toolchain broken.

### Phase 1 — Version Bump
1. `apps/kumoriya_app/pubspec.yaml` — update `version: X.Y.Z+N`
2. Verify no stale version references.

### Phase 2 — Changelog + Release Notes
Use the `changelog-release-notes` skill.

Required outputs:
1. Root `CHANGELOG.md` — new top entry (non-technical, user-facing language)
2. `docs/releases/en/vX.Y.Z.md`
3. `docs/releases/es/vX.Y.Z.md`
4. `docs/releases/README.md` — newest-first

Rules:
- Append-only history.
- User-facing language. No technical jargon (commit hashes, class names, etc.).
- Fixes that complete a new feature are NOT listed separately as "Fixed" — they are part of the feature.

### Phase 3 — Git Commits + Push + Trigger CI

Commits (in order):
```bash
git add apps/kumoriya_app/pubspec.yaml CHANGELOG.md docs/releases/
git commit -m "chore(release): bump version to vX.Y.Z"

git add .github/workflows/  # only if workflow changed
git commit -m "ci: ..."     # only if workflow changed
```

Push to both remotes:
```bash
gh auth switch -u Brizhelito
git push origin main

gh auth switch -u BrizhelDev
git push deploy main
```

Tag:
```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```

Trigger CI:
```bash
gh workflow run release.yml -R BrizhelDev/kumoriya \
  -f version=X.Y.Z \
  -f channel=alpha \
  -f summary_en="<EN summary>" \
  -f summary_es="<ES summary>"
```

Monitor:
```bash
gh run view <run-id> -R BrizhelDev/kumoriya
gh run view --job=<job-id> -R BrizhelDev/kumoriya  # step details
gh run view --job=<job-id> -R BrizhelDev/kumoriya --log-failed  # failure logs
```

Switch back:
```bash
gh auth switch -u Brizhelito
```

---

## CI Phases (GitHub Actions)

The workflow `.github/workflows/release.yml` handles:

### CI Job 1: build-android (ubuntu-latest)
1. Checkout + Flutter setup + Java 17
2. Decode keystore from secrets → write `key.properties` + `google-services.json`
3. `flutter build apk --release --split-per-abi --target-platform android-arm64`
4. Compute SHA-256 + size
5. Upload APK to R2 (`aws s3 cp`)
6. Upload to GitHub Release (`softprops/action-gh-release`, continue-on-error)

### CI Job 2: build-windows (windows-latest)
1. Checkout + Flutter setup
2. `flutter build windows --release` (with `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`)
3. Install Inno Setup (`choco install innosetup`)
4. Patch `kumoriya_installer.iss` version + output filename
5. `iscc kumoriya_installer.iss /Qp`
6. Upload EXE to R2
7. Upload to GitHub Release (continue-on-error)

### CI Job 3: publish (ubuntu-latest, needs both builds)
1. Read version from pubspec + release notes from `docs/releases/`
2. Combine Android + Windows artifact metadata
3. POST to API (`/internal/releases/publish`) with `is_latest: true`
4. Generate `update.json` with both platforms
5. Upload `update.json` to R2 (last, so manifest never points to missing artifacts)

---

## Post-CI Phase

### Phase 4 — Update Local Manifests
After CI succeeds, update local files to match what's on R2:

1. `releases/manifests/update.json` — copy from R2 or reconstruct from CI outputs
2. `releases/versions/vX.Y.Z/release.json` — create with artifact metadata
3. Commit and push:
```bash
git add releases/
git commit -m "chore(release): publish artifact metadata for vX.Y.Z"
git push origin main
```

---

## GitHub Actions Secrets

Set on `BrizhelDev/kumoriya` via `gh secret set -R BrizhelDev/kumoriya`:

| Secret | Source |
|--------|--------|
| `ANDROID_KEYSTORE_JKS` | Base64 of `kumoriya-release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | From `key.properties` |
| `ANDROID_KEY_ALIAS` | From `key.properties` |
| `ANDROID_GOOGLE_SERVICES_JSON` | From `google-services.json` |
| `R2_BUCKET_NAME` | `secrets/kumoriya_r2.credentials.env` |
| `R2_ENDPOINT_URL` | `secrets/kumoriya_r2.credentials.env` |
| `R2_PUBLIC_BASE_URL` | `secrets/kumoriya_r2.credentials.env` |
| `AWS_ACCESS_KEY_ID` | `secrets/kumoriya_r2.credentials.env` |
| `AWS_SECRET_ACCESS_KEY` | `secrets/kumoriya_r2.credentials.env` |
| `UPDATE_API_BASE_URL` | `secrets/update_publish.credentials.env` |
| `RELEASE_PUBLISH_TOKEN` | `secrets/update_publish.credentials.env` |

---

## Release Gate (all must be true)

- [ ] version bumped in pubspec.yaml
- [ ] changelog entry in CHANGELOG.md
- [ ] EN + ES release notes created
- [ ] dart analyze clean (no errors)
- [ ] git commits clean (one concern per commit)
- [ ] release tag created and pushed
- [ ] CI workflow triggered and all 3 jobs passed
- [ ] Android APK on R2
- [ ] Windows installer on R2
- [ ] API publish succeeded (both platforms in `/releases/latest`)
- [ ] `update.json` on R2 with both platforms
- [ ] Local manifests updated and committed
- [ ] residual risks stated

## Failure Policy

On block, return:
1. failing phase (local or CI job)
2. exact command/error (include CI log URL)
3. impact
4. fastest safe recovery

For CI failures, common issues:
- **Windows coroutine error**: `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` env var (already in workflow)
- **Keystore password**: single-quote echo pattern in workflow (already fixed)
- **Secret masking**: never pass R2 public URL as job output (reconstruct in publish job)

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
- R2 upload status:
- API publish status:
- Manifest status:
- Git commits:
- Git tag:
- CI run URL:
- CI result:
- Residual risks:
- Next action:
```
