#!/usr/bin/env bash
set -euo pipefail

# Fetch Synheart Flux native binaries into vendor/flux/** based on vendor/flux/VERSION.
#
# Expected:
# - vendor/flux/VERSION contains a git tag like "v0.1.0"
# - Release artifacts exist at:
#   https://github.com/synheart-ai/synheart-flux/releases/download/<tag>/<artifact>
#
# Optional env:
# - FLUX_VERSION: override version tag
# - FLUX_REPO: override repo (default synheart-ai/synheart-flux)
# - FLUX_GITHUB_TOKEN: GitHub token for private releases / higher rate limits

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

FLUX_REPO="${FLUX_REPO:-synheart-ai/synheart-flux}"
FLUX_VERSION="${FLUX_VERSION:-$(cat vendor/flux/VERSION)}"

if [[ -z "${FLUX_VERSION}" ]]; then
  echo "ERROR: Flux version is empty (vendor/flux/VERSION)." >&2
  exit 1
fi

BASE_URL="https://github.com/${FLUX_REPO}/releases/download/${FLUX_VERSION}"

AUTH_HEADER=()
if [[ -n "${FLUX_GITHUB_TOKEN:-}" ]]; then
  AUTH_HEADER=(-H "Authorization: token ${FLUX_GITHUB_TOKEN}")
fi

echo "Fetching Flux binaries"
echo "  repo: ${FLUX_REPO}"
echo "  tag:  ${FLUX_VERSION}"

mkdir -p vendor/flux/android vendor/flux/ios vendor/flux/desktop/{mac,linux,win}

tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "${tmp_dir}"; }
trap cleanup EXIT

download() {
  local url="$1"
  local out="$2"
  echo "  - download: ${url}"
  curl -fL "${AUTH_HEADER[@]}" "${url}" -o "${out}"
}

# Android JNI libs
download "${BASE_URL}/synheart-flux-android-jniLibs.tar.gz" "${tmp_dir}/flux-android.tar.gz"
tar -xzf "${tmp_dir}/flux-android.tar.gz" -C vendor/flux/android/

# iOS XCFramework
download "${BASE_URL}/synheart-flux-ios-xcframework.zip" "${tmp_dir}/flux-ios.zip"
unzip -o "${tmp_dir}/flux-ios.zip" -d vendor/flux/ios/ >/dev/null

# Desktop (optional but bundled if available)
download "${BASE_URL}/synheart-flux-desktop-macos-arm64.tar.gz" "${tmp_dir}/flux-mac.tar.gz"
tar -xzf "${tmp_dir}/flux-mac.tar.gz" -C vendor/flux/desktop/mac/

download "${BASE_URL}/synheart-flux-desktop-linux-x86_64.tar.gz" "${tmp_dir}/flux-linux.tar.gz"
tar -xzf "${tmp_dir}/flux-linux.tar.gz" -C vendor/flux/desktop/linux/

download "${BASE_URL}/synheart-flux-desktop-windows-x86_64.zip" "${tmp_dir}/flux-win.zip"
unzip -o "${tmp_dir}/flux-win.zip" -d vendor/flux/desktop/win/ >/dev/null

echo "Done. Vendor Flux contents:"
find vendor/flux -maxdepth 4 -type f \( -name "*.so" -o -name "*.dylib" -o -name "*.dll" -o -name "*.xcframework" \) -print || true

