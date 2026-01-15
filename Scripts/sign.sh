#!/usr/bin/env bash

# Sign a macOS app bundle with Developer ID.
#
# Usage: sign.sh (env vars: APP_NAME, APPLE_SIGNING_IDENTITY)
#
# Required environment variables:
#   APP_NAME                Application name (used to derive .app bundle path)
#   APPLE_SIGNING_IDENTITY  Code signing identity (e.g., 'Developer ID Application: Name (TEAMID)')
#
# Optional environment variables:
#   ENTITLEMENTS            Path to entitlements.plist (default: Sources/App/entitlements.plist)
#
# Find your identity with: security find-identity -v -p codesigning

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

log() { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

: "${APP_NAME:?APP_NAME is required}"
: "${APPLE_SIGNING_IDENTITY:?APPLE_SIGNING_IDENTITY is required}"

APP_BUNDLE="$ROOT/${APP_NAME}.app"
ENTITLEMENTS="${ENTITLEMENTS:-Sources/App/entitlements.plist}"

[[ -d "$APP_BUNDLE" ]] || fail "App bundle not found: $APP_BUNDLE"
[[ -f "$ENTITLEMENTS" ]] || fail "Entitlements file not found: $ENTITLEMENTS"

FRAMEWORKS_DIR="$APP_BUNDLE/Contents/Frameworks"

log "==> Signing $APP_NAME"
log "    App Bundle:   $APP_BUNDLE"
log "    Identity:     $APPLE_SIGNING_IDENTITY"
log "    Entitlements: $ENTITLEMENTS"

# Sign all frameworks
if [[ -d "$FRAMEWORKS_DIR" ]]; then
    for framework in "$FRAMEWORKS_DIR"/*.framework; do
        [[ -d "$framework" ]] || continue
        log "--- Signing $(basename "$framework") ---"
        codesign --force --deep --sign "$APPLE_SIGNING_IDENTITY" --timestamp --options runtime "$framework"
    done
fi

# Sign main executable with entitlements
log "--- Signing main executable ---"
codesign --force --sign "$APPLE_SIGNING_IDENTITY" \
    --entitlements "$ENTITLEMENTS" \
    --timestamp \
    --options runtime \
    "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Sign app bundle
log "--- Signing app bundle ---"
codesign --force --sign "$APPLE_SIGNING_IDENTITY" \
    --entitlements "$ENTITLEMENTS" \
    --timestamp \
    --options runtime \
    "$APP_BUNDLE"

# Verify signature
log "--- Verifying signature ---"
if codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"; then
    log "OK: App bundle is properly signed."
else
    fail "Signature verification failed"
fi
