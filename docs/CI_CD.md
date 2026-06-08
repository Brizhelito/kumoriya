# CI/CD Pipeline

> **Continuous integration, testing, and release automation for the Kumoriya platform.**

---

## Table of Contents

1. [GitHub Actions Workflows](#github-actions-workflows)
2. [Quality Gates](#quality-gates)
3. [Release Pipeline](#release-pipeline)
4. [Build Scripts](#build-scripts)
5. [Distribution](#distribution)
6. [AI-Assisted Development](#ai-assisted-development)

---

## GitHub Actions Workflows

### CI Pipeline (per push/PR)

```
Push to any branch
      │
      ▼
┌─────────────────────────────────┐
│  GitHub Actions: CI             │
│                                 │
│  1. Checkout repository         │
│  2. Setup Flutter SDK           │
│  3. flutter pub get             │
│  4. dart format --set-exit-if-changed .  │
│  5. dart analyze                │
│  6. dart run build_runner build │
│  7. flutter test                │
│                                 │
│  All must pass → ✅             │
│  Any failure → ❌ (block merge) │
└─────────────────────────────────┘
```

### Quality Gates

| Gate | Command | Purpose |
|:---|:---|:---|
| **Format** | `dart format --set-exit-if-changed .` | Enforce consistent code style |
| **Analyze** | `dart analyze` | Static analysis, type checking |
| **Build Runner** | `dart run build_runner build --delete-conflicting-outputs` | Verify code generation |
| **Tests** | `flutter test` | Run all unit/widget tests |

---

## Release Pipeline

### Version Management

Releases follow **Semantic Versioning** (MAJOR.MINOR.PATCH):

- **Current versions:** `v0.1.0` through `v0.4.2` (10 releases)
- **Version tracking:** `releases/versions/` directory with per-version metadata

### Release Artifacts

| Platform | Format | Distribution |
|:---|:---|:---|
| Android | APK (arm64-v8a, armeabi-v7a, x86_64) | Cloudflare R2 |
| Windows | MSIX (x64) | Cloudflare R2 |

### Release Process

```
1. Update version in pubspec.yaml
2. Update CHANGELOG.md
3. Create release notes in docs/releases/{en,es}/v{VERSION}.md
4. Build artifacts:
   ├── flutter build apk --split-per-abi
   └── flutter build windows → package as MSIX
5. Upload artifacts to Cloudflare R2
6. Update update.json manifest on R2
7. Create git tag: v{VERSION}
8. Push tag → triggers release workflow
```

### R2 Update Manifest

```json
{
  "android": {
    "version": "0.4.2",
    "version_code": 42,
    "download_url": "https://pub-xxx.r2.dev/releases/v0.4.2/app-arm64-v8a-release.apk",
    "changelog": "https://pub-xxx.r2.dev/releases/v0.4.2/changelog.md"
  },
  "windows": {
    "version": "0.4.2",
    "download_url": "https://pub-xxx.r2.dev/releases/v0.4.2/kumoriya_windows_x64.msix",
    "changelog": "https://pub-xxx.r2.dev/releases/v0.4.2/changelog.md"
  },
  "is_latest": true
}
```

---

## Build Scripts

### Linux Scripts (`scripts/linux/`)

| Script | Purpose |
|:---|:---|
| `publish-r2-release.sh` | Upload artifacts to R2, update manifest |
| `republish-release-history.sh` | Republish historical releases to R2 |

### Windows Scripts (`scripts/windows/`)

| Script | Purpose |
|:---|:---|
| `00-init-clean-repo.ps1` | Initialize clean repository |
| `20-bootstrap-codex-home.ps1` | Bootstrap development environment |
| `publish-r2-release.ps1` | Windows release publish |
| `capture_android_download_logs.ps1` | Collect Android download diagnostics |
| `load-r2-credentials.ps1` | Load R2 credentials from secrets |

### Utility Scripts

| Script | Purpose |
|:---|:---|
| `force_party_leave.sh` | Admin: force user out of Watch Party room |
| `read_downloads.py` | Parse download diagnostics |
| `extract_nexus_netlog.py` | Extract network logs for debugging |
| `ws_auth_test.dart` | WebSocket authentication test utility |

---

## Distribution

### Cloudflare R2

- **Bucket:** Release artifacts and update manifest
- **Public access:** Via `pub-*.r2.dev` URLs
- **Caching:** CDN-cached with cache-busting on version changes

### OTA Updates

The Flutter app checks for updates on startup:

1. Fetch `update.json` from R2
2. Compare `version_code` (Android) or `version` (Windows) with installed version
3. If newer available → show update dialog
4. User downloads APK/MSIX from R2 URL
5. Android: Open APK for installation
6. Windows: Launch MSIX installer

### Release Notes

Bilingual release notes maintained in:
- `docs/releases/en/v{VERSION}.md` (English)
- `docs/releases/es/v{VERSION}.md` (Spanish)

Post-update, the app shows release notes dialog comparing previous → current version.

---

## AI-Assisted Development

### Agent System (`.agents/`)

Kumoriya uses AI-assisted development agents for quality assurance:

| Agent | Purpose |
|:---|:---|
| `matching-orchestrator` | Coordinates AniList matching calibration |
| `matcher-calibration-auditor` | Audits matching confidence thresholds |
| `matching-regression-guardian` | Guards against matching regressions |
| `source-catalog-existence-verifier` | Verifies source plugin catalog coverage |
| `source-search-surface-auditor` | Audits search result quality |
| `design-system-enforcer` | Enforces UI design system consistency |
| `interaction-states-implementer` | Implements loading/error/empty states |
| `player-controls-interaction-designer` | Designs player control interactions |
| `qa-subagent` | General quality assurance |

### Skills (`.agents/skills/`)

Reusable skill definitions for common tasks:
- `anilist-matching` — Matching heuristics and confidence rules
- `source-plugin-jkanime` — JKAnime plugin maintenance
- `resolver-plugin` — Resolver plugin creation/hardening
- `player-slice` — Player feature implementation
- `storage-drift` — Database schema and migrations
- `flutter-vertical-slice` — Feature slice scaffolding
- `uiux-review` — UI/UX audit and recommendations
- `validate-task` — Task completion validation
- `changelog-release-notes` — Release documentation
- `dev-diary` — Development log maintenance

### Workflows (`.devin/workflows/`)

Automated workflow definitions:
- `/architect-plan` — Feature decomposition into tasks
- `/worker-run` — Single task implementation
- `/reviewer-check` — Task validation against contracts
- `/run-next-task` — End-to-end task loop
- `/escalate-task` — Failing task escalation
- `/index-refresh` — System index rebuild
