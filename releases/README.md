# Release Filesystem

This folder stores release metadata used by automation.

## Layout

```text
releases/
  manifests/
    update.json
  versions/
    v0.1.0/
      release.json

docs/
  releases/
    README.md
    es/
      vX.Y.Z.md
    en/
      vX.Y.Z.md
```

## Purpose

- `manifests/update.json`: runtime manifest consumed by app update checks.
- `versions/vX.Y.Z/release.json`: immutable metadata per released version.
- `docs/releases/<locale>/vX.Y.Z.md`: human release notes by locale.

## Artifact naming

- Android universal: `kumoriya-<version>-universal.apk`
- Android arm64-v8a: `kumoriya-<version>-arm64-v8a.apk`
- Android armeabi-v7a: `kumoriya-<version>-armeabi-v7a.apk`
- Android x86_64: `kumoriya-<version>-x86_64.apk`
- Windows (Inno): `Kumoriya-<version>-windows-x64-setup.exe`

## R2 object keys used by publish script

- `artifacts/android/vX.Y.Z/kumoriya-X.Y.Z-universal.apk`
- `artifacts/android/vX.Y.Z/kumoriya-X.Y.Z-arm64-v8a.apk`
- `artifacts/android/vX.Y.Z/kumoriya-X.Y.Z-armeabi-v7a.apk`
- `artifacts/android/vX.Y.Z/kumoriya-X.Y.Z-x86_64.apk`
- `artifacts/windows/vX.Y.Z/Kumoriya-X.Y.Z-windows-x64-setup.exe`
- `releases/vX.Y.Z/release.json`
- `releases/changelogs/es/vX.Y.Z.md`
- `releases/changelogs/en/vX.Y.Z.md`
- `update.json`
