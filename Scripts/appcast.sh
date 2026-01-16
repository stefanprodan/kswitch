#!/usr/bin/env bash

# Generate appcast.xml for Sparkle updates using the latest GitHub release.
#
# Usage: appcast.sh
#
# Required environment variables:
#   APP_NAME             Application name (e.g., KSwitch)
#   SPARKLE_PRIVATE_KEY  EdDSA private key (base64 string from Sparkle's generate_keys)

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

log() { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

command -v gh &>/dev/null || fail "gh CLI not found. Install from https://cli.github.com"
: "${APP_NAME:?APP_NAME is required}"
: "${SPARKLE_PRIVATE_KEY:?SPARKLE_PRIVATE_KEY is required}"

# Find sign_update tool
SIGN_UPDATE=""
for path in \
    "$ROOT/.build/artifacts/sparkle/Sparkle/bin/sign_update" \
    "$ROOT/.build/checkouts/Sparkle/bin/sign_update"
do
    [[ -x "$path" ]] && SIGN_UPDATE="$path" && break
done
[[ -n "$SIGN_UPDATE" ]] || fail "sign_update not found. Run 'swift build' first."

log "==> Fetching latest release from GitHub"
RELEASE_JSON=$(gh release view --json tagName,publishedAt,assets)

TAG=$(echo "$RELEASE_JSON" | jq -r '.tagName')
PUB_DATE=$(echo "$RELEASE_JSON" | jq -r '.publishedAt')
VERSION="${TAG#v}"

# Find the .zip asset
ASSET_NAME=$(echo "$RELEASE_JSON" | jq -r --arg app "$APP_NAME" 'first(.assets[] | select(.name | startswith($app) and endswith(".zip"))) | .name')
ASSET_URL=$(echo "$RELEASE_JSON" | jq -r --arg app "$APP_NAME" 'first(.assets[] | select(.name | startswith($app) and endswith(".zip"))) | .browserDownloadUrl')
[[ -n "$ASSET_NAME" && "$ASSET_NAME" != "null" ]] || fail "No ${APP_NAME}*.zip asset found in release $TAG"

REPO_URL=$(gh repo view --json url -q '.url')
RELEASE_URL="${REPO_URL}/releases/tag/${TAG}"

log "==> Downloading $ASSET_NAME for signing"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
ARCHIVE="$TMPDIR/$ASSET_NAME"
curl -sL "$ASSET_URL" -o "$ARCHIVE"
[[ -f "$ARCHIVE" ]] || fail "Failed to download $ASSET_NAME"

log "==> Signing archive"
FILE_SIZE=$(stat -f%z "$ARCHIVE" 2>/dev/null || stat -c%s "$ARCHIVE")
SIGNATURE=$("$SIGN_UPDATE" "$ARCHIVE" --ed-key-file <(echo "$SPARKLE_PRIVATE_KEY"))
ED_SIGNATURE=$(echo "$SIGNATURE" | grep -o 'edSignature="[^"]*"' | sed 's/edSignature="//;s/"//')
[[ -n "$ED_SIGNATURE" ]] || ED_SIGNATURE="$SIGNATURE"

log "==> Generating appcast.xml"
cat > "$ROOT/appcast.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>${APP_NAME} Updates</title>
    <item>
      <title>Version ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <description><![CDATA[<h2>${APP_NAME} v${VERSION}</h2><p><a href="${RELEASE_URL}">View release notes on GitHub</a></p>]]></description>
      <enclosure
        url="${ASSET_URL}"
        sparkle:edSignature="${ED_SIGNATURE}"
        length="${FILE_SIZE}"
        type="application/octet-stream"
      />
    </item>
  </channel>
</rss>
EOF

log "OK: appcast.xml generated for ${TAG}"
cat "$ROOT/appcast.xml"
