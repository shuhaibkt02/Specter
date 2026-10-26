#!/bin/bash
set -euo pipefail

APP_NAME="Specter"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
INSTALL_DEST="/Applications/${APP_BUNDLE}"

echo "=========================================="
echo "🔨 Building ${APP_NAME} (Release)..."
echo "=========================================="
swift build -c release

echo "📦 Assembling ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy compiled executable and Info.plist
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
cp "Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
cp "Resources/${APP_NAME}.icns" "${RESOURCES_DIR}/${APP_NAME}.icns"

# Ad-hoc code signing (Never expires on your Mac, no paid Apple Developer account needed)
echo "🔏 Code signing (Ad-Hoc / Lifelong)..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "🚀 Installing to /Applications..."
# Terminate existing instances by exact process name.
while IFS= read -r pid; do
    kill "${pid}" 2>/dev/null || true
done < <(pgrep -x "${APP_NAME}" || true)

# Replace old version in /Applications
rm -rf "${INSTALL_DEST}"
cp -R "${APP_BUNDLE}" "${INSTALL_DEST}"

echo "=========================================="
echo "✅ ${APP_NAME} installed successfully!"
echo "📍 Location: ${INSTALL_DEST}"
echo "=========================================="
echo "To launch now:"
echo "  open ${INSTALL_DEST}"
echo ""
echo "To keep it running lifelong on boot:"
echo "  System Settings > General > Login Items > Add '${APP_NAME}'"
