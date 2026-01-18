#!/usr/bin/env bash

# Create a DMG installer for a macOS app.
#
# Usage: dmg.sh (env vars: APP_NAME, APP_VERSION, APPLE_SIGNING_IDENTITY, APP_STORE_CONNECT_*)
#
# Required environment variables:
#   APP_NAME                        Application name (used to derive .app bundle path)
#   APP_VERSION                     Application version (e.g., 1.0.0)
#   APPLE_SIGNING_IDENTITY          Code signing identity (e.g., 'Developer ID Application: Name (TEAMID)')
#   APP_STORE_CONNECT_API_KEY_PATH  Path to App Store Connect API key (.p8 file)
#   APP_STORE_CONNECT_KEY_ID        App Store Connect Key ID
#   APP_STORE_CONNECT_ISSUER_ID     App Store Connect Issuer ID
#
# Creates:
#   dist/${APP_NAME}.dmg         Signed and notarized DMG installer
#   dist/${APP_NAME}.dmg.sha256  SHA256 checksum

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

log() { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

: "${APP_NAME:?APP_NAME is required}"
: "${APP_VERSION:?APP_VERSION is required}"
: "${APPLE_SIGNING_IDENTITY:?APPLE_SIGNING_IDENTITY is required}"
: "${APP_STORE_CONNECT_API_KEY_PATH:?APP_STORE_CONNECT_API_KEY_PATH is required}"
: "${APP_STORE_CONNECT_KEY_ID:?APP_STORE_CONNECT_KEY_ID is required}"
: "${APP_STORE_CONNECT_ISSUER_ID:?APP_STORE_CONNECT_ISSUER_ID is required}"

APP_BUNDLE="$ROOT/${APP_NAME}.app"
DIST_DIR="$ROOT/dist"
DMG_FILE="$DIST_DIR/${APP_NAME}.dmg"
DMG_SHA="$DIST_DIR/${APP_NAME}.dmg.sha256"

[[ -d "$APP_BUNDLE" ]] || fail "App bundle not found: $APP_BUNDLE"
[[ -f "$APP_STORE_CONNECT_API_KEY_PATH" ]] || fail "API key file not found: $APP_STORE_CONNECT_API_KEY_PATH"

# Verify app is notarized
log "==> Verifying app is notarized"
if ! xcrun stapler validate "$APP_BUNDLE" &>/dev/null; then
    fail "App bundle is not notarized. Run notarize.sh first."
fi
log "OK: App is notarized"

mkdir -p "$DIST_DIR"

# Remove existing DMG if present
rm -f "$DMG_FILE"

log "==> Creating DMG"
log "    App Bundle: $APP_BUNDLE"
log "    Output:     $DMG_FILE"

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Get the app's icon for the volume
ICON_FILE="$APP_BUNDLE/Contents/Resources/Icon.icns"

if command -v create-dmg &>/dev/null; then
    log "--- Using create-dmg for styled DMG ---"

    CREATE_DMG_ARGS=(
        --volname "$APP_NAME"
        --window-pos 200 120
        --window-size 600 400
        --icon-size 100
        --icon "$APP_NAME.app" 150 190
        --app-drop-link 450 190
        --no-internet-enable
        --skip-jenkins
    )

    # Add volume icon if app has one
    if [[ -f "$ICON_FILE" ]]; then
        CREATE_DMG_ARGS+=(--volicon "$ICON_FILE")
    fi

    create-dmg "${CREATE_DMG_ARGS[@]}" "$DMG_FILE" "$APP_BUNDLE"
else
    log "--- Using hdiutil (create-dmg not installed) ---"
    log "    For a styled DMG, install create-dmg: brew install create-dmg"

    # Create a temporary folder with app and Applications symlink
    STAGING_DIR="$TEMP_DIR/staging"
    mkdir -p "$STAGING_DIR"
    cp -R "$APP_BUNDLE" "$STAGING_DIR/"
    ln -s /Applications "$STAGING_DIR/Applications"

    # Create DMG
    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$STAGING_DIR" \
        -ov -format UDZO \
        "$DMG_FILE"
fi

[[ -f "$DMG_FILE" ]] || fail "DMG creation failed"
log "Created: $DMG_FILE"

#------------------------------------------------------------------------------
# Sign DMG
#------------------------------------------------------------------------------
log "==> Signing DMG"
codesign --force --sign "$APPLE_SIGNING_IDENTITY" --timestamp "$DMG_FILE"

# Verify signature
if codesign --verify --verbose=2 "$DMG_FILE"; then
    log "OK: DMG is properly signed"
else
    fail "DMG signature verification failed"
fi

#------------------------------------------------------------------------------
# Notarize DMG
#------------------------------------------------------------------------------
log "==> Notarizing DMG"
log "This may take several minutes..."

RESULT_FILE="$TEMP_DIR/result.json"

set +e
xcrun notarytool submit "$DMG_FILE" \
    --key "$APP_STORE_CONNECT_API_KEY_PATH" \
    --key-id "$APP_STORE_CONNECT_KEY_ID" \
    --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
    --output-format json \
    --wait \
    --timeout 30m > "$RESULT_FILE" 2>&1
NOTARIZE_STATUS=$?
set -e

# Parse result
SUBMISSION_ID=$(grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' "$RESULT_FILE" | head -1 | cut -d'"' -f4)
STATUS=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$RESULT_FILE" | head -1 | cut -d'"' -f4)

log "Submission ID: $SUBMISSION_ID"
log "Status: $STATUS"

# Handle failure
if [[ "$STATUS" != "Accepted" ]]; then
    log ""
    log "=== Notarization Result ==="
    cat "$RESULT_FILE"

    if [[ -n "$SUBMISSION_ID" ]]; then
        log ""
        log "=== Fetching detailed log ==="
        LOG_FILE="$TEMP_DIR/log.json"
        xcrun notarytool log "$SUBMISSION_ID" \
            --key "$APP_STORE_CONNECT_API_KEY_PATH" \
            --key-id "$APP_STORE_CONNECT_KEY_ID" \
            --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
            "$LOG_FILE" 2>&1 || true

        if [[ -f "$LOG_FILE" ]]; then
            cat "$LOG_FILE"
        fi
    fi
    fail "DMG notarization failed"
fi

log "DMG notarization accepted!"

#------------------------------------------------------------------------------
# Staple notarization ticket
#------------------------------------------------------------------------------
log "==> Stapling notarization ticket to DMG"
xcrun stapler staple "$DMG_FILE"

# Verify
if xcrun stapler validate "$DMG_FILE"; then
    log "OK: DMG is notarized and stapled"
else
    fail "DMG stapler validation failed"
fi

#------------------------------------------------------------------------------
# Create checksum
#------------------------------------------------------------------------------
log "==> Creating SHA256 checksum"
shasum -a 256 "$DMG_FILE" | awk '{print $1}' > "$DMG_SHA"

log ""
log "==> DMG creation complete!"
log "    $DMG_FILE"
log "    $DMG_SHA"
