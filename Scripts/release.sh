#!/usr/bin/env bash

# Automate the full release process for KSwitch.
#
# Usage: release.sh (called via `make release`)
#
# This script performs:
#   1. Validates version format and git state
#   2. Creates and pushes a signed git tag (if needed)
#   3. Builds, signs, and notarizes the app
#   4. Creates distribution files (ZIP + checksum)
#   5. Generates appcast.xml
#   6. Creates GitHub release with all assets
#
# Required environment variables (passed from Makefile):
#   APP_NAME, BUNDLE_ID, MACOS_MIN_VERSION, APP_VERSION, BUILD_NUMBER
#   SPARKLE_PUBLIC_KEY, SPARKLE_FEED_URL
#
# Required environment variables (user must set):
#   APPLE_SIGNING_IDENTITY          Code signing identity
#   APP_STORE_CONNECT_API_KEY_PATH  Path to App Store Connect API key (.p8 file)
#   APP_STORE_CONNECT_KEY_ID        App Store Connect Key ID
#   APP_STORE_CONNECT_ISSUER_ID     App Store Connect Issuer ID
#   SPARKLE_PRIVATE_KEY             EdDSA private key for appcast signing

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

log() { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

#------------------------------------------------------------------------------
# Validate required configuration (passed from Makefile)
#------------------------------------------------------------------------------
: "${APP_NAME:?APP_NAME is required}"
: "${APP_VERSION:?APP_VERSION is required}"
: "${BUNDLE_ID:?BUNDLE_ID is required}"
: "${MACOS_MIN_VERSION:?MACOS_MIN_VERSION is required}"
: "${BUILD_NUMBER:?BUILD_NUMBER is required}"
: "${SPARKLE_PUBLIC_KEY:?SPARKLE_PUBLIC_KEY is required}"
: "${SPARKLE_FEED_URL:?SPARKLE_FEED_URL is required}"

GIT_TAG="v${APP_VERSION}"

log "==> Release Configuration"
log "    App Name:    $APP_NAME"
log "    Version:     $APP_VERSION"
log "    Git Tag:     $GIT_TAG"

#------------------------------------------------------------------------------
# Validate required tools
#------------------------------------------------------------------------------
command -v gh &>/dev/null || fail "gh CLI not found. Install from https://cli.github.com"
command -v git &>/dev/null || fail "git not found"

#------------------------------------------------------------------------------
# Validate required environment variables
#------------------------------------------------------------------------------
: "${APPLE_SIGNING_IDENTITY:?APPLE_SIGNING_IDENTITY is required}"
: "${APP_STORE_CONNECT_API_KEY_PATH:?APP_STORE_CONNECT_API_KEY_PATH is required}"
: "${APP_STORE_CONNECT_KEY_ID:?APP_STORE_CONNECT_KEY_ID is required}"
: "${APP_STORE_CONNECT_ISSUER_ID:?APP_STORE_CONNECT_ISSUER_ID is required}"
: "${SPARKLE_PRIVATE_KEY:?SPARKLE_PRIVATE_KEY is required}"

#------------------------------------------------------------------------------
# Validate version format (vX.Y.Z or vX.Y.Z-suffix)
#------------------------------------------------------------------------------
if [[ ! "$GIT_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
    fail "Invalid version format: $APP_VERSION. Must be semver (X.Y.Z or X.Y.Z-suffix)"
fi

#------------------------------------------------------------------------------
# Validate git state
#------------------------------------------------------------------------------
log "==> Checking git state"

CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
    fail "Must be on main branch. Currently on: $CURRENT_BRANCH"
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    fail "Working directory has uncommitted changes. Commit or stash them first."
fi

log "--- Pulling latest from origin ---"
git pull origin main

#------------------------------------------------------------------------------
# Check tag and release existence
#------------------------------------------------------------------------------
log "==> Checking tag and release status"

TAG_EXISTS=false
RELEASE_EXISTS=false

if git rev-parse "$GIT_TAG" &>/dev/null; then
    TAG_EXISTS=true
    log "    Tag $GIT_TAG exists"
fi

if gh release view "$GIT_TAG" &>/dev/null 2>&1; then
    RELEASE_EXISTS=true
    log "    GitHub release $GIT_TAG exists"
fi

if [[ "$TAG_EXISTS" == "true" && "$RELEASE_EXISTS" == "true" ]]; then
    fail "Tag $GIT_TAG and GitHub release already exist. Update APP_VERSION in Makefile for a new release."
fi

if [[ "$TAG_EXISTS" == "true" ]]; then
    log "    Tag exists but no release - will create release only"
fi

#------------------------------------------------------------------------------
# Create and push tag if needed
#------------------------------------------------------------------------------
if [[ "$TAG_EXISTS" == "false" ]]; then
    log "==> Creating signed tag $GIT_TAG"
    git tag -s "$GIT_TAG" -m "Release $GIT_TAG"

    log "--- Pushing tag to origin ---"
    git push origin "$GIT_TAG"
fi

#------------------------------------------------------------------------------
# Clean build artifacts
#------------------------------------------------------------------------------
log "==> Cleaning build artifacts"
rm -rf "$ROOT/dist"
rm -rf "$ROOT/${APP_NAME}.app"

#------------------------------------------------------------------------------
# Run build pipeline
#------------------------------------------------------------------------------
log "==> Running build pipeline"

log "--- package.sh ---"
APP_NAME="$APP_NAME" \
BUNDLE_ID="$BUNDLE_ID" \
MACOS_MIN_VERSION="$MACOS_MIN_VERSION" \
APP_VERSION="$APP_VERSION" \
BUILD_NUMBER="$BUILD_NUMBER" \
SPARKLE_PUBLIC_KEY="$SPARKLE_PUBLIC_KEY" \
SPARKLE_FEED_URL="$SPARKLE_FEED_URL" \
    "$ROOT/Scripts/package.sh"

log "--- sign.sh ---"
APP_NAME="$APP_NAME" \
APPLE_SIGNING_IDENTITY="$APPLE_SIGNING_IDENTITY" \
    "$ROOT/Scripts/sign.sh"

log "--- notarize.sh ---"
APP_NAME="$APP_NAME" \
APP_VERSION="$APP_VERSION" \
APP_STORE_CONNECT_API_KEY_PATH="$APP_STORE_CONNECT_API_KEY_PATH" \
APP_STORE_CONNECT_KEY_ID="$APP_STORE_CONNECT_KEY_ID" \
APP_STORE_CONNECT_ISSUER_ID="$APP_STORE_CONNECT_ISSUER_ID" \
    "$ROOT/Scripts/notarize.sh"

log "--- dmg.sh ---"
APP_NAME="$APP_NAME" \
APP_VERSION="$APP_VERSION" \
APPLE_SIGNING_IDENTITY="$APPLE_SIGNING_IDENTITY" \
APP_STORE_CONNECT_API_KEY_PATH="$APP_STORE_CONNECT_API_KEY_PATH" \
APP_STORE_CONNECT_KEY_ID="$APP_STORE_CONNECT_KEY_ID" \
APP_STORE_CONNECT_ISSUER_ID="$APP_STORE_CONNECT_ISSUER_ID" \
    "$ROOT/Scripts/dmg.sh"

#------------------------------------------------------------------------------
# Create distribution files
#------------------------------------------------------------------------------
log "==> Creating distribution files"
DIST_DIR="$ROOT/dist"
mkdir -p "$DIST_DIR"

DIST_ZIP="$DIST_DIR/${APP_NAME}.zip"
DIST_SHA="$DIST_DIR/${APP_NAME}.zip.sha256"
DIST_DMG="$DIST_DIR/${APP_NAME}.dmg"
DIST_DMG_SHA="$DIST_DIR/${APP_NAME}.dmg.sha256"

log "--- Creating ZIP archive ---"
ditto -c -k --keepParent "$ROOT/${APP_NAME}.app" "$DIST_ZIP"

log "--- Creating SHA256 checksum ---"
shasum -a 256 "$DIST_ZIP" | awk '{print $1}' > "$DIST_SHA"

log "    $DIST_ZIP"
log "    $DIST_SHA"

#------------------------------------------------------------------------------
# Generate appcast.xml
#------------------------------------------------------------------------------
log "==> Generating appcast.xml"

REPO_URL=$(gh repo view --json url -q '.url')
DOWNLOAD_URL="${REPO_URL}/releases/download/${GIT_TAG}/${APP_NAME}.zip"
RELEASE_URL="${REPO_URL}/releases/tag/${GIT_TAG}"

APP_NAME="$APP_NAME" \
APP_VERSION="$GIT_TAG" \
SPARKLE_PRIVATE_KEY="$SPARKLE_PRIVATE_KEY" \
DIST_ZIP="$DIST_ZIP" \
DOWNLOAD_URL="$DOWNLOAD_URL" \
RELEASE_URL="$RELEASE_URL" \
APPCAST_OUTPUT="$DIST_DIR/appcast.xml" \
    "$ROOT/Scripts/appcast.sh"

#------------------------------------------------------------------------------
# Create GitHub release
#------------------------------------------------------------------------------
log "==> Creating GitHub release"

gh release create "$GIT_TAG" \
    --title "${APP_NAME} ${GIT_TAG}" \
    --generate-notes \
    "$DIST_ZIP" \
    "$DIST_SHA" \
    "$DIST_DMG" \
    "$DIST_DMG_SHA" \
    "$DIST_DIR/appcast.xml"

log ""
log "==> Release complete!"
log "    Tag:     $GIT_TAG"
log "    Release: $RELEASE_URL"
log ""
log "Distribution files:"
log "    $DIST_ZIP"
log "    $DIST_SHA"
log "    $DIST_DMG"
log "    $DIST_DMG_SHA"
log "    $DIST_DIR/appcast.xml"
