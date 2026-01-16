#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="OfficeCheckIn"
VERSION_FILE="${ROOT_DIR}/VERSION"
VERSION="$(cat "${VERSION_FILE}")"
DIST_DIR="${ROOT_DIR}/dist"
ZIP_NAME="${APP_NAME}-${VERSION}.zip"
ZIP_PATH="${DIST_DIR}/${ZIP_NAME}"

echo "Packaging app..."
"${ROOT_DIR}/Scripts/package_app.sh"

if [[ ! -f "${ZIP_PATH}" ]]; then
  echo "Missing artifact: ${ZIP_PATH}"
  exit 1
fi

SHA256="$(shasum -a 256 "${ZIP_PATH}" | awk '{print $1}')"
echo "SHA256: ${SHA256}"

echo "Writing Homebrew cask (local template updated)..."
cat > "${ROOT_DIR}/Casks/office-check-in.rb" <<EOF
cask "office-check-in" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "https://github.com/Quisharoo/office-check-In/releases/download/v${VERSION}/${ZIP_NAME}"
  name "Office Check-In"
  desc "Mac menubar app for office attendance tracking"
  homepage "https://github.com/Quisharoo/office-check-In"

  app "${APP_NAME}.app"
end
EOF

echo "Creating GitHub release..."
git tag -f "v${VERSION}"
git push -f origin "v${VERSION}"

gh release create "v${VERSION}" "${ZIP_PATH}" \
  --title "Office Check-In ${VERSION}" \
  --notes "macOS menubar app release"

echo "Release complete: v${VERSION}"
