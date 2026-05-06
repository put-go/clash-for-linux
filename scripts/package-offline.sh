#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE_NAME="${1:-clash-for-linux-amd64-offline.zip}"
OUT_FILE="$PROJECT_DIR/$PACKAGE_NAME"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/clash-for-linux-package.XXXXXX")"
STAGE_DIR="$TMP_DIR/clash-for-linux"
MIHOMO_VERSION="v1.19.23"
YQ_VERSION="v4.52.4"
SUBCONVERTER_VERSION="v0.9.9"

REQUIRED_BIN_ASSETS=(
  "resources/bin/mihomo/mihomo-linux-amd64-compatible-v1.19.23.gz"
  "resources/bin/mihomo/mihomo-linux-arm64-v1.19.23.gz"
  "resources/bin/mihomo/mihomo-linux-armv7-v1.19.23.gz"
  "resources/bin/yq/yq_linux_amd64.tar.gz"
  "resources/bin/yq/yq_linux_arm64.tar.gz"
  "resources/bin/yq/yq_linux_arm.tar.gz"
  "resources/bin/subconverter/subconverter_linux64.tar.gz"
  "resources/bin/subconverter/subconverter_aarch64.tar.gz"
  "resources/bin/subconverter/subconverter_armv7.tar.gz"
)

REQUIRED_GEO_ASSETS=(
  "resources/geo/Country.mmdb"
  "resources/geo/GeoSite.dat"
  "resources/geo/GeoIP.dat"
)

BIN_ASSET_DOWNLOADS=(
  "resources/bin/mihomo/mihomo-linux-amd64-compatible-v1.19.23.gz https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/mihomo-linux-amd64-compatible-${MIHOMO_VERSION}.gz"
  "resources/bin/mihomo/mihomo-linux-arm64-v1.19.23.gz https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/mihomo-linux-arm64-${MIHOMO_VERSION}.gz"
  "resources/bin/mihomo/mihomo-linux-armv7-v1.19.23.gz https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/mihomo-linux-armv7-${MIHOMO_VERSION}.gz"
  "resources/bin/yq/yq_linux_amd64.tar.gz https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64.tar.gz"
  "resources/bin/yq/yq_linux_arm64.tar.gz https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_arm64.tar.gz"
  "resources/bin/yq/yq_linux_arm.tar.gz https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_arm.tar.gz"
  "resources/bin/subconverter/subconverter_linux64.tar.gz https://github.com/asdlokj1qpi233/subconverter/releases/download/${SUBCONVERTER_VERSION}/subconverter_linux64.tar.gz"
  "resources/bin/subconverter/subconverter_aarch64.tar.gz https://github.com/asdlokj1qpi233/subconverter/releases/download/${SUBCONVERTER_VERSION}/subconverter_aarch64.tar.gz"
  "resources/bin/subconverter/subconverter_armv7.tar.gz https://github.com/asdlokj1qpi233/subconverter/releases/download/${SUBCONVERTER_VERSION}/subconverter_armv7.tar.gz"
)

GEO_ASSET_DOWNLOADS=(
  "resources/geo/Country.mmdb https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/country.mmdb"
  "resources/geo/GeoSite.dat https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat"
  "resources/geo/GeoIP.dat https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat"
)

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

copy_path() {
  local path="$1"

  [ -e "$PROJECT_DIR/$path" ] || return 0
  mkdir -p "$STAGE_DIR/$(dirname "$path")"
  cp -pR "$PROJECT_DIR/$path" "$STAGE_DIR/$path"
}

download_asset() {
  local path="$1"
  local url="$2"
  local target="$PROJECT_DIR/$path"
  local tmp_file="$target.tmp"

  [ -s "$target" ] && return 0

  mkdir -p "$(dirname "$target")"
  echo "downloading offline asset: $path"

  env \
    http_proxy="${CLASH_PACKAGE_HTTP_PROXY:-${http_proxy:-}}" \
    https_proxy="${CLASH_PACKAGE_HTTPS_PROXY:-${https_proxy:-}}" \
    all_proxy="${CLASH_PACKAGE_ALL_PROXY:-${all_proxy:-}}" \
    curl -fL --retry 3 --connect-timeout 20 "$url" -o "$tmp_file"

  mv -f "$tmp_file" "$target"
}

download_missing_bin_assets() {
  local item path url

  for item in "${BIN_ASSET_DOWNLOADS[@]}"; do
    path="${item%% *}"
    url="${item#* }"
    download_asset "$path" "$url"
  done
}

download_missing_geo_assets() {
  local item path url

  for item in "${GEO_ASSET_DOWNLOADS[@]}"; do
    path="${item%% *}"
    url="${item#* }"
    download_asset "$path" "$url"
  done
}

require_assets() {
  local asset missing=0

  for asset in "${REQUIRED_BIN_ASSETS[@]}"; do
    if [ ! -f "$PROJECT_DIR/$asset" ]; then
      echo "missing required offline asset: $asset" >&2
      missing=1
    fi
  done

  for asset in "${REQUIRED_GEO_ASSETS[@]}"; do
    if [ ! -f "$PROJECT_DIR/$asset" ]; then
      echo "missing required offline asset: $asset" >&2
      missing=1
    fi
  done

  [ "$missing" -eq 0 ] || {
    echo "offline package aborted: required assets are incomplete" >&2
    return 1
  }
}

mkdir -p "$STAGE_DIR"

download_missing_bin_assets
download_missing_geo_assets
require_assets

copy_path "LICENSE"
copy_path "README.md"
copy_path "install.sh"
copy_path "uninstall.sh"
copy_path "config"
copy_path "scripts/core"
copy_path "scripts/init"
copy_path "resources/bin"
copy_path "resources/dashboard/dist.zip"
copy_path "resources/geo"
copy_path "resources/shell.png"
copy_path "resources/ui.png"

find "$STAGE_DIR" -name ".DS_Store" -delete

rm -f "$OUT_FILE"
(
  cd "$STAGE_DIR"
  zip -r "$OUT_FILE" . \
    -x ".git/*" \
    -x ".github/*" \
    -x ".gitignore" \
    -x ".gitattributes" \
    -x ".editorconfig" \
    -x ".env" \
    -x "runtime/*"
)

echo "$OUT_FILE"
