#!/usr/bin/env bash

# Build and package the app into a .app bundle.
#
# Usage: package.sh (env vars: APP_NAME, BUNDLE_ID, MACOS_MIN_VERSION, APP_VERSION, BUILD_NUMBER)
#
# Required environment variables:
#   APP_NAME           Application name
#   BUNDLE_ID          Bundle identifier
#   MACOS_MIN_VERSION  Minimum macOS version
#   APP_VERSION        Version string (e.g., 1.0.0)
#   BUILD_NUMBER       Build number
#
# Optional environment variables:
#   SPARKLE_FEED_URL   Sparkle appcast URL
#   SPARKLE_PUBLIC_KEY Sparkle EdDSA public key

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

: "${APP_NAME:?APP_NAME is required}"
: "${BUNDLE_ID:?BUNDLE_ID is required}"
: "${MACOS_MIN_VERSION:?MACOS_MIN_VERSION is required}"
: "${APP_VERSION:?APP_VERSION is required}"
: "${BUILD_NUMBER:?BUILD_NUMBER is required}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-}"
SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-}"

APP="$ROOT/${APP_NAME}.app"

log() { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Build
HOST_ARCH=$(uname -m)
log "==> Building (${HOST_ARCH})"
swift build -c release --arch "$HOST_ARCH"

# Create app bundle
log "==> Packaging"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

# Info.plist
BUILD_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${APP_VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>${MACOS_MIN_VERSION}</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleIconFile</key><string>Icon</string>
    <key>BuildTimestamp</key><string>${BUILD_TIMESTAMP}</string>
    <key>GitCommit</key><string>${GIT_COMMIT}</string>
    <key>SUFeedURL</key><string>${SPARKLE_FEED_URL}</string>
    <key>SUPublicEDKey</key><string>${SPARKLE_PUBLIC_KEY}</string>
</dict>
</plist>
PLIST

# Install binary
BUILD_DIR=".build/${HOST_ARCH}-apple-macosx/release"
BINARY_SRC="${BUILD_DIR}/${APP_NAME}"
if [[ ! -f "$BINARY_SRC" ]]; then
  fail "Missing binary at ${BINARY_SRC}"
fi
cp "$BINARY_SRC" "$APP/Contents/MacOS/$APP_NAME"
chmod +x "$APP/Contents/MacOS/$APP_NAME"

# Bundle resources
APP_RESOURCES_DIR="$ROOT/Sources/App/Resources"
if [[ -d "$APP_RESOURCES_DIR" ]]; then
  cp -R "$APP_RESOURCES_DIR/." "$APP/Contents/Resources/"
fi

# SwiftPM resource bundles
shopt -s nullglob
SWIFTPM_BUNDLES=("${BUILD_DIR}/"*.bundle)
shopt -u nullglob
for bundle in "${SWIFTPM_BUNDLES[@]}"; do
  cp -R "$bundle" "$APP/Contents/Resources/"
done

# Embed frameworks if any
if compgen -G "${BUILD_DIR}/*.framework" >/dev/null; then
  cp -R "${BUILD_DIR}/"*.framework "$APP/Contents/Frameworks/"
  chmod -R a+rX "$APP/Contents/Frameworks"
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/$APP_NAME"
fi

# Clean extended attributes
chmod -R u+w "$APP"
xattr -cr "$APP"
find "$APP" -name '._*' -delete

log "OK: ${APP_NAME}.app is ready for signing."
