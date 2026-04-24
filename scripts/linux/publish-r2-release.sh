#!/usr/bin/env bash
# Publish an Android-only release to R2 + kumoriya-api from Linux.
#
# Mirrors the behaviour of scripts/windows/publish-r2-release.ps1 but restricted
# to Android (universal + per-ABI splits). Windows installer is out of scope
# because Inno Setup only runs on Windows.
#
# Requires: bash 4+, flutter, aws CLI v2, jq, sha256sum, curl.
#
# Env loading (overridable via --r2-env / --update-env):
#   secrets/kumoriya_r2.credentials.env      → R2_BUCKET_NAME, R2_ENDPOINT_URL,
#                                                R2_PUBLIC_BASE_URL,
#                                                AWS_ACCESS_KEY_ID,
#                                                AWS_SECRET_ACCESS_KEY
#   secrets/update_publish.credentials.env   → UPDATE_API_BASE_URL,
#                                                RELEASE_PUBLISH_TOKEN,
#                                                RELEASE_CHANNEL (optional)
#
# ABI keys in the JSON payload use underscores (`arm64_v8a`, `armeabi_v7a`,
# `x86_64`) to match the Go backend enum. File names keep hyphens for humans.
#
# Usage:
#   scripts/linux/publish-r2-release.sh \
#     --release-notes "Fix crash on resume" \
#     --summary-es "Arreglado crash al reanudar" \
#     --summary-en "Fixed crash on resume"
#
# Flags:
#   --skip-build              Reuse existing APKs under build/app/outputs/flutter-apk.
#   --channel <name>          Override RELEASE_CHANNEL (default: alpha).
#   --release-notes <text>    Short release notes for the manifest.
#   --summary-es <text>       ES summary (defaults to release-notes).
#   --summary-en <text>       EN summary (defaults to release-notes).
#   --r2-env <path>           Override R2 env file.
#   --update-env <path>       Override update-publish env file.

set -euo pipefail

RELEASE_NOTES="Actualizacion de version."
SUMMARY_ES=""
SUMMARY_EN=""
CHANNEL=""
SKIP_BUILD=0
R2_ENV_FILE="secrets/kumoriya_r2.credentials.env"
UPDATE_ENV_FILE="secrets/update_publish.credentials.env"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release-notes) RELEASE_NOTES="$2"; shift 2 ;;
    --summary-es)    SUMMARY_ES="$2";    shift 2 ;;
    --summary-en)    SUMMARY_EN="$2";    shift 2 ;;
    --channel)       CHANNEL="$2";       shift 2 ;;
    --r2-env)        R2_ENV_FILE="$2";   shift 2 ;;
    --update-env)    UPDATE_ENV_FILE="$2"; shift 2 ;;
    --skip-build)    SKIP_BUILD=1; shift ;;
    -h|--help)
      sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_DIR="$REPO_ROOT/apps/kumoriya_app"
PUBSPEC="$APP_DIR/pubspec.yaml"

load_env_file() {
  local path="$1"
  [[ -z "$path" || ! -f "$path" ]] && return 0
  # shellcheck disable=SC1090
  set -a; source "$path"; set +a
}

load_env_file "$R2_ENV_FILE"
load_env_file "$UPDATE_ENV_FILE"

: "${R2_BUCKET_NAME:?R2_BUCKET_NAME missing (check $R2_ENV_FILE)}"
: "${R2_ENDPOINT_URL:?R2_ENDPOINT_URL missing}"
: "${R2_PUBLIC_BASE_URL:?R2_PUBLIC_BASE_URL missing}"
: "${UPDATE_API_BASE_URL:?UPDATE_API_BASE_URL missing (check $UPDATE_ENV_FILE)}"
: "${RELEASE_PUBLISH_TOKEN:?RELEASE_PUBLISH_TOKEN missing}"

CHANNEL="${CHANNEL:-${RELEASE_CHANNEL:-alpha}}"
SUMMARY_ES="${SUMMARY_ES:-$RELEASE_NOTES}"
SUMMARY_EN="${SUMMARY_EN:-$RELEASE_NOTES}"

for cmd in flutter aws jq sha256sum curl; do
  command -v "$cmd" >/dev/null || { echo "Missing command: $cmd" >&2; exit 1; }
done

# Parse "version: X.Y.Z+N" from pubspec.
VERSION="$(grep -E '^version:\s*[0-9]+\.[0-9]+\.[0-9]+\+' "$PUBSPEC" \
  | sed -E 's/^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+.*/\1/')"
[[ -z "$VERSION" ]] && { echo "Could not parse version from $PUBSPEC" >&2; exit 1; }
TAG="v$VERSION"

APK_DIR="$APP_DIR/build/app/outputs/flutter-apk"
UNIVERSAL_APK="app-release.apk"
SPLIT_APKS=(app-armeabi-v7a-release.apk app-arm64-v8a-release.apk app-x86_64-release.apk)

if [[ $SKIP_BUILD -eq 0 ]]; then
  pushd "$APP_DIR" >/dev/null
  echo "==> Building Android universal APK..."
  flutter build apk --release
  echo "==> Building Android per-ABI APKs..."
  flutter build apk --release --split-per-abi \
    --target-platform android-arm,android-arm64,android-x64
  popd >/dev/null
fi

[[ -f "$APK_DIR/$UNIVERSAL_APK" ]] || { echo "Universal APK missing: $APK_DIR/$UNIVERSAL_APK" >&2; exit 1; }
for apk in "${SPLIT_APKS[@]}"; do
  [[ -f "$APK_DIR/$apk" ]] || { echo "Split APK missing: $APK_DIR/$apk" >&2; exit 1; }
done

RELEASE_DIR="$REPO_ROOT/releases/versions/$TAG"
mkdir -p "$RELEASE_DIR" "$REPO_ROOT/releases/manifests"
RELEASE_JSON="$RELEASE_DIR/release.json"
UPDATE_JSON="$REPO_ROOT/releases/manifests/update.json"
NOTES_ES="$REPO_ROOT/docs/releases/es/$TAG.md"
NOTES_EN="$REPO_ROOT/docs/releases/en/$TAG.md"

[[ -f "$NOTES_ES" ]] || { echo "Missing release notes: $NOTES_ES" >&2; exit 1; }
[[ -f "$NOTES_EN" ]] || { echo "Missing release notes: $NOTES_EN" >&2; exit 1; }

NOTES_ES_MD="$(cat "$NOTES_ES")"
NOTES_EN_MD="$(cat "$NOTES_EN")"

# Map: source apk filename -> "<abi_key>|<destination filename>".
# abi_key uses underscores (matches Go AndroidABI* enum and updater lookup).
declare -A ABI_MAP=(
  ["app-release.apk"]="universal|kumoriya-$VERSION-universal.apk"
  ["app-armeabi-v7a-release.apk"]="armeabi_v7a|kumoriya-$VERSION-armeabi-v7a.apk"
  ["app-arm64-v8a-release.apk"]="arm64_v8a|kumoriya-$VERSION-arm64-v8a.apk"
  ["app-x86_64-release.apk"]="x86_64|kumoriya-$VERSION-x86_64.apk"
)

# Build a JSON array of objects: {abi,file_name,r2_key,public_url,size_bytes,sha256,source_path}.
ARTIFACTS_JSON="$(jq -n '[]')"
for src in "${!ABI_MAP[@]}"; do
  IFS='|' read -r abi file_name <<<"${ABI_MAP[$src]}"
  src_path="$APK_DIR/$src"
  sha="$(sha256sum "$src_path" | awk '{print $1}')"
  size="$(stat -c%s "$src_path")"
  r2_key="artifacts/android/$TAG/$file_name"
  public_url="$R2_PUBLIC_BASE_URL/$r2_key"
  ARTIFACTS_JSON="$(jq --arg abi "$abi" --arg fn "$file_name" --arg k "$r2_key" \
    --arg u "$public_url" --arg sha "$sha" --argjson sz "$size" --arg sp "$src_path" \
    '. + [{abi:$abi,file_name:$fn,r2_key:$k,public_url:$u,size_bytes:$sz,sha256:$sha,source_path:$sp}]' \
    <<<"$ARTIFACTS_JSON")"
done

get_universal() { jq '.[] | select(.abi=="universal")' <<<"$ARTIFACTS_JSON"; }
UNIVERSAL="$(get_universal)"
[[ -z "$UNIVERSAL" ]] && { echo "Universal artifact missing from computed set" >&2; exit 1; }

# --- release.json (human reference, uploaded to R2 + committed) ---
jq -n \
  --arg v "$VERSION" --arg tag "$TAG" --arg date "$(date -u +%F)" \
  --arg ch "$CHANNEL" --arg notes "$RELEASE_NOTES" \
  --arg es "$SUMMARY_ES" --arg en "$SUMMARY_EN" \
  --arg notesEs "$NOTES_ES_MD" --arg notesEn "$NOTES_EN_MD" \
  --argjson universal "$UNIVERSAL" \
  --argjson artifacts "$ARTIFACTS_JSON" \
  '{
    version: $v, tag: $tag, date: $date, channels: [$ch],
    manifest_release_notes: $notes,
    summary: {es:$es, en:$en},
    artifacts: {
      android: {
        file_name: $universal.file_name,
        r2_key: $universal.r2_key,
        public_url: $universal.public_url,
        abis: [$artifacts[] | {abi, file_name, r2_key, public_url, size_bytes, sha256}]
      }
    },
    changelog_paths: {es:("docs/releases/es/"+$tag+".md"), en:("docs/releases/en/"+$tag+".md")},
    notes_markdown: {es:$notesEs, en:$notesEn}
  }' > "$RELEASE_JSON"

# --- update.json (runtime manifest consumed by the app updater) ---
jq -n \
  --arg v "$VERSION" --arg notes "$RELEASE_NOTES" \
  --argjson universal "$UNIVERSAL" \
  --argjson artifacts "$ARTIFACTS_JSON" \
  '{
    android: (
      {
        latest_version: $v,
        url: $universal.public_url,
        release_notes: $notes,
        universal: ($universal | {url:.public_url, file_name, r2_key, size_bytes, sha256}),
        abis: (
          [$artifacts[] | select(.abi!="universal")]
          | map({key:.abi, value:{url:.public_url, file_name, r2_key, size_bytes, sha256}})
          | from_entries
        )
      }
    )
  }' > "$UPDATE_JSON"

# --- Upload APKs ---
aws_upload() {
  local src="$1" key="$2" ctype="${3:-}" cdisp="${4:-}"
  echo "Uploading: $src -> s3://$R2_BUCKET_NAME/$key"
  local args=(s3 cp "$src" "s3://$R2_BUCKET_NAME/$key"
              --endpoint-url "$R2_ENDPOINT_URL" --region auto)
  [[ -n "$ctype" ]] && args+=(--content-type "$ctype")
  [[ -n "$cdisp" ]] && args+=(--content-disposition "$cdisp")
  aws "${args[@]}"
}

while IFS= read -r row; do
  src="$(jq -r '.source_path' <<<"$row")"
  key="$(jq -r '.r2_key'       <<<"$row")"
  fn="$(jq -r '.file_name'     <<<"$row")"
  aws_upload "$src" "$key" "application/vnd.android.package-archive" \
    "attachment; filename=\"$fn\""
done < <(jq -c '.[]' <<<"$ARTIFACTS_JSON")

aws_upload "$RELEASE_JSON" "releases/$TAG/release.json" "application/json" ""
aws_upload "$NOTES_ES"     "releases/changelogs/es/$TAG.md" "" ""
aws_upload "$NOTES_EN"     "releases/changelogs/en/$TAG.md" "" ""

# --- Publish to API ---
PUBLISH_BODY="$(jq -n \
  --arg v "$VERSION" --arg tag "$TAG" --arg date "$(date -u +%F)" \
  --arg ch "$CHANNEL" --arg notes "$RELEASE_NOTES" \
  --arg es "$SUMMARY_ES" --arg en "$SUMMARY_EN" \
  --arg notesEs "$NOTES_ES_MD" --arg notesEn "$NOTES_EN_MD" \
  --argjson universal "$UNIVERSAL" \
  --argjson artifacts "$ARTIFACTS_JSON" \
  '{
    version:$v, tag:$tag, date:$date, channel:$ch,
    manifest_release_notes:$notes,
    summary:{es:$es, en:$en},
    notes_markdown:{es:$notesEs, en:$notesEn},
    is_latest: true,
    downloads: {
      android: {
        url: $universal.public_url,
        file_name: $universal.file_name,
        r2_key: $universal.r2_key,
        size_bytes: $universal.size_bytes,
        sha256: $universal.sha256,
        universal: ($universal | {url:.public_url, file_name, r2_key, size_bytes, sha256}),
        abis: (
          [$artifacts[] | select(.abi!="universal")]
          | map({key:.abi, value:{url:.public_url, file_name, r2_key, size_bytes, sha256}})
          | from_entries
        )
      }
    }
  }')"

PUBLISH_URL="${UPDATE_API_BASE_URL%/}/internal/releases/publish"
echo "==> POST $PUBLISH_URL"
curl -fsSL -X POST "$PUBLISH_URL" \
  -H "Authorization: Bearer $RELEASE_PUBLISH_TOKEN" \
  -H "Content-Type: application/json" \
  --data "$PUBLISH_BODY" >/dev/null

aws_upload "$UPDATE_JSON" "update.json" "application/json" ""

echo
echo "Release published successfully."
echo "Version: $VERSION"
jq -r '.[] | "Android " + .abi + " URL: " + .public_url' <<<"$ARTIFACTS_JSON"
echo "Manifest: $R2_PUBLIC_BASE_URL/update.json"
