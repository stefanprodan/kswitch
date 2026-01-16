#!/usr/bin/env bash

# Notarize a macOS app with Apple.
#
# Usage: notarize.sh (env vars: APP_NAME, APP_STORE_CONNECT_API_KEY_PATH, APP_STORE_CONNECT_KEY_ID, APP_STORE_CONNECT_ISSUER_ID)
#
# Required environment variables:
#   APP_NAME                        Application name (used to derive .app bundle path)
#   APP_VERSION                     Application version (e.g., 1.0.0)
#   APP_STORE_CONNECT_API_KEY_PATH  Path to App Store Connect API key (.p8 file)
#   APP_STORE_CONNECT_KEY_ID        App Store Connect Key ID
#   APP_STORE_CONNECT_ISSUER_ID     App Store Connect Issuer ID

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

log() { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

: "${APP_NAME:?APP_NAME is required}"
: "${APP_VERSION:?APP_VERSION is required}"
: "${APP_STORE_CONNECT_API_KEY_PATH:?APP_STORE_CONNECT_API_KEY_PATH is required}"
: "${APP_STORE_CONNECT_KEY_ID:?APP_STORE_CONNECT_KEY_ID is required}"
: "${APP_STORE_CONNECT_ISSUER_ID:?APP_STORE_CONNECT_ISSUER_ID is required}"

APP_BUNDLE="$ROOT/${APP_NAME}.app"

[[ -d "$APP_BUNDLE" ]] || fail "App bundle not found: $APP_BUNDLE"
[[ -f "$APP_STORE_CONNECT_API_KEY_PATH" ]] || fail "API key file not found: $APP_STORE_CONNECT_API_KEY_PATH"
TEMP_DIR=$(mktemp -d)
ZIP_FILE="$TEMP_DIR/${APP_NAME}.zip"

trap "rm -rf $TEMP_DIR" EXIT

log "==> Notarizing $APP_NAME"
log "    App Bundle: $APP_BUNDLE"
log "    Key ID:     $APP_STORE_CONNECT_KEY_ID"

# Create ZIP for notarization
log "--- Creating ZIP archive ---"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_FILE"
log "Created: $ZIP_FILE"

# Submit for notarization
log "--- Submitting for notarization ---"
log "This may take several minutes..."

RESULT_FILE="$TEMP_DIR/result.json"

set +e
xcrun notarytool submit "$ZIP_FILE" \
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
    fail "Notarization failed"
fi

log "Notarization accepted!"

# Staple the notarization ticket
log "--- Stapling notarization ticket ---"
xcrun stapler staple "$APP_BUNDLE"

# Verify
log "--- Verifying notarization ---"
if xcrun stapler validate "$APP_BUNDLE"; then
    log "OK: App is notarized and stapled."
else
    fail "Stapler validation failed"
fi

# Create distribution ZIP
log "--- Creating distribution archive ---"
DIST_DIR="$ROOT/dist"
mkdir -p "$DIST_DIR"
DIST_ZIP="$DIST_DIR/${APP_NAME}-${APP_VERSION}.zip"
ditto -c -k --keepParent "$APP_BUNDLE" "$DIST_ZIP"

# Create SHA256 checksum
DIST_SHA="$DIST_DIR/${APP_NAME}-${APP_VERSION}.zip.sha256"
shasum -a 256 "$DIST_ZIP" | awk '{print $1}' > "$DIST_SHA"

log ""
log "App is ready for distribution:"
log "  $DIST_ZIP"
log "  $DIST_SHA"
