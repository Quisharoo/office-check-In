#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source local signing config if present
if [[ -f "${SCRIPT_DIR}/signing.local" ]]; then
  source "${SCRIPT_DIR}/signing.local"
fi
PKG_DIR="${ROOT_DIR}/mac/OfficeCheckInApp"
APP_NAME="OfficeCheckIn"
DIST_DIR="${ROOT_DIR}/dist"
VERSION_FILE="${ROOT_DIR}/VERSION"
VERSION="$(cat "${VERSION_FILE}")"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
MACOS_DIR="${APP_DIR}/Contents/MacOS"
RESOURCES_DIR="${APP_DIR}/Contents/Resources"
INFO_PLIST="${PKG_DIR}/AppInfo.plist"
ENTITLEMENTS="${PKG_DIR}/OfficeCheckIn.entitlements"
# Set your signing identity (run `security find-identity -v -p codesigning` to list)
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"

echo "Building ${APP_NAME} (release)..."
swift build -c release --package-path "${PKG_DIR}"

BIN_PATH="${PKG_DIR}/.build/release/${APP_NAME}"
if [[ ! -f "${BIN_PATH}" ]]; then
  echo "Build failed: ${BIN_PATH} not found"
  exit 1
fi

echo "Packaging .app..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"
cp "${INFO_PLIST}" "${APP_DIR}/Contents/Info.plist"

if [[ -n "${SIGNING_IDENTITY}" ]]; then
  echo "Codesigning with entitlements..."
  codesign --force --options runtime --entitlements "${ENTITLEMENTS}" --sign "${SIGNING_IDENTITY}" "${APP_DIR}"
else
  echo "Skipping codesign (set SIGNING_IDENTITY to enable)"
fi

echo "Zipping..."
mkdir -p "${DIST_DIR}"
ZIP_NAME="${APP_NAME}-${VERSION}.zip"
rm -f "${DIST_DIR}/${ZIP_NAME}"
(cd "${DIST_DIR}" && ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}.app" "${ZIP_NAME}")

echo "Done: ${DIST_DIR}/${ZIP_NAME}"
