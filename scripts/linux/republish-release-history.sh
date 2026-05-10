#!/usr/bin/env bash
# Republish historical Kumoriya releases (metadata + notes) without touching latest.
#
# This script republishes existing releases from `releases/versions/vX.Y.Z/release.json`
# using the user-friendly release notes in `docs/releases/{es,en}/vX.Y.Z.md`.
# It uploads the refreshed release.json + changelog markdown to R2 and posts the
# release metadata to the API with `is_latest=false` so the current latest release
# remains unchanged.
#
# Requires: bash 4+, aws CLI v2, jq, curl.
#
# Usage:
#   scripts/linux/republish-release-history.sh --all
#   scripts/linux/republish-release-history.sh --tag v0.2.0 --tag v0.3.0
#
# Flags:
#   --all             Republish every historical release except the current pubspec version.
#   --tag <vX.Y.Z>    Republish a specific tag (repeatable).
#   --dry-run         Print actions without uploading/publishing.
#   --r2-env <path>   Override R2 env file.
#   --update-env <path> Override update-publish env file.

set -euo pipefail

DRY_RUN=0
ALL=0
R2_ENV_FILE="secrets/kumoriya_r2.credentials.env"
UPDATE_ENV_FILE="secrets/update_publish.credentials.env"
TAGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) ALL=1; shift ;;
    --tag)
      [[ $# -ge 2 ]] || { echo "Missing value for --tag" >&2; exit 2; }
      TAGS+=("$2")
      shift 2
      ;;
    --dry-run) DRY_RUN=1; shift ;;
    --r2-env)
      [[ $# -ge 2 ]] || { echo "Missing value for --r2-env" >&2; exit 2; }
      R2_ENV_FILE="$2"
      shift 2
      ;;
    --update-env)
      [[ $# -ge 2 ]] || { echo "Missing value for --update-env" >&2; exit 2; }
      UPDATE_ENV_FILE="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '2,40p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown flag: $1" >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_DIR="$REPO_ROOT/apps/kumoriya_app"
PUBSPEC="$APP_DIR/pubspec.yaml"
VERSIONS_DIR="$REPO_ROOT/releases/versions"
DOCS_ES_DIR="$REPO_ROOT/docs/releases/es"
DOCS_EN_DIR="$REPO_ROOT/docs/releases/en"
TMP_DIR="${TMPDIR:-/tmp}/kumoriya-republish"
mkdir -p "$TMP_DIR"

load_env_file() {
  local path="$1"
  [[ -z "$path" || ! -f "$path" ]] && return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    local key="${line%%=*}"
    local value="${line#*=}"
    [[ "$key" == "$line" ]] && continue
    export "$key=$value"
  done < "$path"
}

load_env_file "$R2_ENV_FILE"
load_env_file "$UPDATE_ENV_FILE"

if [[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  unset AWS_PROFILE
fi

: "${R2_BUCKET_NAME:?R2_BUCKET_NAME missing (check $R2_ENV_FILE)}"
: "${R2_ENDPOINT_URL:?R2_ENDPOINT_URL missing}"
: "${R2_PUBLIC_BASE_URL:?R2_PUBLIC_BASE_URL missing}"
: "${UPDATE_API_BASE_URL:?UPDATE_API_BASE_URL missing (check $UPDATE_ENV_FILE)}"
: "${RELEASE_PUBLISH_TOKEN:?RELEASE_PUBLISH_TOKEN missing}"

for cmd in aws jq curl; do
  command -v "$cmd" >/dev/null || { echo "Missing command: $cmd" >&2; exit 1; }
done

CURRENT_VERSION="$(grep -E '^version:\s*[0-9]+\.[0-9]+\.[0-9]+\+' "$PUBSPEC" | sed -E 's/^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+.*/\1/')"
CURRENT_TAG="v$CURRENT_VERSION"

summary_for_tag() {
  case "$1" in
    v0.1.0) printf '%s|%s|%s\n' "Primer alpha público para Android y Windows." "First public alpha for Android and Windows." "First public alpha for Android and Windows." ;;
    v0.1.1) printf '%s|%s|%s\n' "Actualizaciones más rápidas y permisos más claros." "Faster updates and clearer permissions." "Faster updates and clearer permissions." ;;
    v0.1.2) printf '%s|%s|%s\n' "Versión visible y detección automática de actualizaciones." "Visible version info and automatic update checks." "Visible version info and automatic update checks." ;;
    v0.1.3) printf '%s|%s|%s\n' "Más formas de explorar anime y mejores herramientas de reproducción." "More ways to browse anime and better playback tools." "More ways to browse anime and better playback tools." ;;
    v0.1.4) printf '%s|%s|%s\n' "Cola de descargas más ágil y limpieza más confiable." "Smoother download queue and more reliable cleanup." "Smoother download queue and more reliable cleanup." ;;
    v0.2.0) printf '%s|%s|%s\n' "Watch Party más clara y releases más confiables." "Clearer Watch Party and more reliable releases." "Clearer Watch Party and more reliable releases." ;;
    v0.3.0) printf '%s|%s|%s\n' "Descargas más inteligentes y sincronización mejorada." "Smarter downloads and improved sync." "Smarter downloads and improved sync." ;;
    *) return 1 ;;
  esac
}

manifest_for_tag() {
  case "$1" in
    v0.1.0) printf '%s\n' "First public alpha release for Android and Windows." ;;
    v0.1.1) printf '%s\n' "Better Android updates, clearer permissions, and smaller internal fixes." ;;
    v0.1.2) printf '%s\n' "Installed version visible in Settings and update checks at startup." ;;
    v0.1.3) printf '%s\n' "Better anime browsing, support tools, and playback polish." ;;
    v0.1.4) printf '%s\n' "Smoother download queue, safer cleanup, and better resolver handling." ;;
    v0.2.0) printf '%s\n' "Clearer Watch Party screens, backend-powered discovery, and API-driven releases." ;;
    v0.3.0) printf '%s\n' "Smarter downloads, better sync, and lighter app updates for each device." ;;
    v0.4.0) printf '%s\n' "Full manga experience with reader, library, downloads, and improved release flow." ;;
    *) return 1 ;;
  esac
}

primary_android_expr='
  if .artifacts.android.abis? and (.artifacts.android.abis | length > 0) then
    (.artifacts.android.abis | map(select(.abi == "universal")) | .[0]) // .[0]
    | {url:.public_url, public_url, file_name, r2_key, size_bytes, sha256}
  else
    {
      url: .artifacts.android.public_url,
      file_name: .artifacts.android.file_name,
      r2_key: .artifacts.android.r2_key,
      public_url: .artifacts.android.public_url,
      size_bytes: (.artifacts.android.size_bytes // 0),
      sha256: (.artifacts.android.sha256 // "")
    }
  end'

android_abis_list_expr='
  if .artifacts.android.abis? and (.artifacts.android.abis | length > 0) then
    (.artifacts.android.abis
      | map(select(.abi != "universal"))
      | map({abi,file_name,r2_key,public_url,size_bytes,sha256}))
  else
    []
  end'

android_abis_map_expr='
  if .artifacts.android.abis? and (.artifacts.android.abis | length > 0) then
    (.artifacts.android.abis
      | map(select(.abi != "universal"))
      | map({key:.abi, value:{url:.public_url, file_name, r2_key, size_bytes, sha256}})
      | from_entries)
  else
    {}
  end'

render_release_json() {
  local src_json="$1"
  local out_json="$2"
  local docs_es="$3"
  local docs_en="$4"

  local version tag date channel manifest summary_es summary_en notes_es notes_en
  version="$(jq -r '.version' "$src_json")"
  tag="$(jq -r '.tag' "$src_json")"
  date="$(jq -r '.date' "$src_json")"
  channel="$(jq -r '.channels[0] // "alpha"' "$src_json")"
  manifest="$(jq -r '.manifest_release_notes // empty' "$src_json")"
  if [[ -z "$manifest" || "$manifest" == "null" ]]; then
    manifest="$(manifest_for_tag "$tag")"
  fi
  IFS='|' read -r summary_es summary_en _ <<<"$(summary_for_tag "$tag")"
  notes_es="$(cat "$docs_es")"
  notes_en="$(cat "$docs_en")"

  local android_artifacts windows_artifact primary_android
  android_artifacts="$(jq -c "$android_abis_list_expr" "$src_json")"
  windows_artifact="$(jq -c '
    if .artifacts.windows? and .artifacts.windows.public_url then
      {file_name:.artifacts.windows.file_name, r2_key:.artifacts.windows.r2_key, public_url:.artifacts.windows.public_url, size_bytes:(.artifacts.windows.size_bytes // 0), sha256:(.artifacts.windows.sha256 // "")}
    else empty end
  ' "$src_json")"
  primary_android="$(jq -c "$primary_android_expr" "$src_json")"

  jq -n \
    --arg v "$version" \
    --arg tag "$tag" \
    --arg date "$date" \
    --arg ch "$channel" \
    --arg notes "$manifest" \
    --arg es "$summary_es" \
    --arg en "$summary_en" \
    --arg notesEs "$notes_es" \
    --arg notesEn "$notes_en" \
    --argjson primaryAndroid "$primary_android" \
    --argjson androidArtifacts "$android_artifacts" \
    --argjson windowsArtifact "${windows_artifact:-null}" \
    '{
      version: $v,
      tag: $tag,
      date: $date,
      channels: [$ch],
      manifest_release_notes: $notes,
      summary: {es:$es, en:$en},
      artifacts: {
        android: {
          file_name: $primaryAndroid.file_name,
          r2_key: $primaryAndroid.r2_key,
          public_url: $primaryAndroid.public_url,
          abis: $androidArtifacts
        }
      },
      changelog_paths: {es:("docs/releases/es/"+$tag+".md"), en:("docs/releases/en/"+$tag+".md")},
      notes_markdown: {es:$notesEs, en:$notesEn}
    }
    | if $windowsArtifact != null then .artifacts.windows = $windowsArtifact else . end' \
    > "$out_json"
}

build_publish_body() {
  local release_json="$1"
  local out_json="$2"
  local docs_es="$3"
  local docs_en="$4"

  local version tag date channel manifest summary_es summary_en notes_es notes_en
  version="$(jq -r '.version' "$release_json")"
  tag="$(jq -r '.tag' "$release_json")"
  date="$(jq -r '.date' "$release_json")"
  channel="$(jq -r '.channels[0] // "alpha"' "$release_json")"
  manifest="$(jq -r '.manifest_release_notes // empty' "$release_json")"
  if [[ -z "$manifest" || "$manifest" == "null" ]]; then
    manifest="$(manifest_for_tag "$tag")"
  fi
  IFS='|' read -r summary_es summary_en _ <<<"$(summary_for_tag "$tag")"
  notes_es="$(cat "$docs_es")"
  notes_en="$(cat "$docs_en")"

  local primary_android windows_download android_abis
  primary_android="$(jq -c "$primary_android_expr" "$release_json")"
  windows_download="$(jq -c '
    if .artifacts.windows? and .artifacts.windows.public_url then
      {url:.artifacts.windows.public_url, file_name:.artifacts.windows.file_name, r2_key:.artifacts.windows.r2_key, size_bytes:(.artifacts.windows.size_bytes // 0), sha256:(.artifacts.windows.sha256 // "")}
    else empty end
  ' "$release_json")"
  android_abis="$(jq -c "$android_abis_map_expr" "$release_json")"

  jq -n \
    --arg v "$version" \
    --arg tag "$tag" \
    --arg date "$date" \
    --arg ch "$channel" \
    --arg notes "$manifest" \
    --arg es "$summary_es" \
    --arg en "$summary_en" \
    --arg notesEs "$notes_es" \
    --arg notesEn "$notes_en" \
    --argjson primaryAndroid "$primary_android" \
    --argjson androidAbis "$android_abis" \
    --argjson windowsDownload "${windows_download:-null}" \
    '{
      version:$v,
      tag:$tag,
      date:$date,
      channel:$ch,
      manifest_release_notes:$notes,
      summary:{es:$es, en:$en},
      notes_markdown:{es:$notesEs, en:$notesEn},
      is_latest:false,
      downloads:{
        android: {
          url: $primaryAndroid.url,
          file_name: $primaryAndroid.file_name,
          r2_key: $primaryAndroid.r2_key,
          size_bytes: $primaryAndroid.size_bytes,
          sha256: $primaryAndroid.sha256,
          abis: $androidAbis
        }
      }
    }
    | if $windowsDownload != null then .downloads.windows = $windowsDownload else . end' \
    > "$out_json"
}

upload_file() {
  local src="$1"
  local key="$2"
  local ctype="${3:-}"
  local cdisp="${4:-}"

  echo "Uploading: $src -> s3://$R2_BUCKET_NAME/$key"
  if [[ $DRY_RUN -eq 1 ]]; then
    return 0
  fi

  local args=(s3 cp "$src" "s3://$R2_BUCKET_NAME/$key" --endpoint-url "$R2_ENDPOINT_URL" --region auto)
  [[ -n "$ctype" ]] && args+=(--content-type "$ctype")
  [[ -n "$cdisp" ]] && args+=(--content-disposition "$cdisp")
  aws "${args[@]}"
}

publish_release() {
  local payload="$1"
  local publish_url="${UPDATE_API_BASE_URL%/}/internal/releases/publish"
  echo "==> POST $publish_url"
  if [[ $DRY_RUN -eq 1 ]]; then
    return 0
  fi
  curl -fsSL -X POST "$publish_url" \
    -H "Authorization: Bearer $RELEASE_PUBLISH_TOKEN" \
    -H "Content-Type: application/json" \
    --data @"$payload" >/dev/null
}

mapfile -t RELEASE_FILES < <(find "$VERSIONS_DIR" -mindepth 2 -maxdepth 2 -name release.json | sort)
if [[ ${#TAGS[@]} -eq 0 && $ALL -eq 0 ]]; then
  ALL=1
fi

if [[ $ALL -eq 1 ]]; then
  TAGS=()
  for f in "${RELEASE_FILES[@]}"; do
    tag="$(basename "$(dirname "$f")")"
    [[ "$tag" == "$CURRENT_TAG" ]] && continue
    TAGS+=("$tag")
  done
fi

if [[ ${#TAGS[@]} -eq 0 ]]; then
  echo "No historical tags selected." >&2
  exit 1
fi

for tag in "${TAGS[@]}"; do
  if [[ "$tag" == "$CURRENT_TAG" ]]; then
    echo "Skipping current latest tag: $tag"
    continue
  fi

  src_json="$VERSIONS_DIR/$tag/release.json"
  docs_es="$DOCS_ES_DIR/$tag.md"
  docs_en="$DOCS_EN_DIR/$tag.md"

  [[ -f "$src_json" ]] || { echo "Missing release.json: $src_json" >&2; exit 1; }
  [[ -f "$docs_es" ]] || { echo "Missing ES notes: $docs_es" >&2; exit 1; }
  [[ -f "$docs_en" ]] || { echo "Missing EN notes: $docs_en" >&2; exit 1; }

  tmp_release_json="$TMP_DIR/$tag.release.json"
  tmp_publish_json="$TMP_DIR/$tag.publish.json"

  render_release_json "$src_json" "$tmp_release_json" "$docs_es" "$docs_en"
  build_publish_body "$src_json" "$tmp_publish_json" "$docs_es" "$docs_en"

  echo "==> Republishing $tag (is_latest=false)"
  upload_file "$tmp_release_json" "releases/$tag/release.json" "application/json" ""
  upload_file "$docs_es" "releases/changelogs/es/$tag.md" "" ""
  upload_file "$docs_en" "releases/changelogs/en/$tag.md" "" ""
  publish_release "$tmp_publish_json"

done

echo
if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry run complete."
else
  echo "Historical releases republished successfully."
fi
