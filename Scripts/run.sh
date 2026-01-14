#!/usr/bin/env bash
# Build, package, and launch the app.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

: "${APP_NAME:?APP_NAME is required}"
: "${BUNDLE_ID:?BUNDLE_ID is required}"
: "${MACOS_MIN_VERSION:?MACOS_MIN_VERSION is required}"
: "${MARKETING_VERSION:?MARKETING_VERSION is required}"
: "${BUILD_NUMBER:?BUILD_NUMBER is required}"

APP="$ROOT/${APP_NAME}.app"
APP_PROCESS_PATTERN="${APP_NAME}.app/Contents/MacOS/${APP_NAME}"

log() { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Kill existing instances
log "==> Killing existing ${APP_NAME} instances"
pkill -f "${APP_PROCESS_PATTERN}" 2>/dev/null || true
pkill -f "${ROOT}/.build/debug/${APP_NAME}" 2>/dev/null || true
pkill -f "${ROOT}/.build/release/${APP_NAME}" 2>/dev/null || true
pkill -x "${APP_NAME}" 2>/dev/null || true

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
    <key>CFBundleShortVersionString</key><string>${MARKETING_VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>${MACOS_MIN_VERSION}</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleIconFile</key><string>Icon</string>
    <key>BuildTimestamp</key><string>${BUILD_TIMESTAMP}</string>
    <key>GitCommit</key><string>${GIT_COMMIT}</string>
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
APP_RESOURCES_DIR="$ROOT/Sources/$APP_NAME/Resources"
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

# Icon
if [[ -f "$ROOT/Icon.icns" ]]; then
  cp "$ROOT/Icon.icns" "$APP/Contents/Resources/Icon.icns"
fi

# Clean extended attributes
chmod -R u+w "$APP"
xattr -cr "$APP"
find "$APP" -name '._*' -delete

# Ad-hoc signing
log "==> Signing"
ENTITLEMENTS="$ROOT/Sources/kswitch/entitlements.plist"
for fw in "$APP/Contents/Frameworks/"*.framework; do
  [[ -d "$fw" ]] || continue
  while IFS= read -r -d '' bin; do
    codesign --force --sign "-" "$bin"
  done < <(find "$fw" -type f -perm -111 -print0)
  codesign --force --sign "-" "$fw"
done
codesign --force --sign "-" --entitlements "$ENTITLEMENTS" "$APP"

log "==> Launching"
if ! open "$APP"; then
  log "WARN: open failed; launching binary directly."
  "$APP/Contents/MacOS/$APP_NAME" >/dev/null 2>&1 &
  disown
fi

# Verify running
for _ in {1..10}; do
  if pgrep -f "${APP_PROCESS_PATTERN}" >/dev/null 2>&1; then
    log "OK: ${APP_NAME} is running."
    exit 0
  fi
  sleep 0.4
done
fail "App exited immediately. Check crash logs in Console.app (User Reports)."
