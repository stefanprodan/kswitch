#!/usr/bin/env bash

# Generate appcast.xml for Sparkle updates using a local ZIP file.
#
# Usage: appcast.sh
#
# Required environment variables:
#   APP_NAME             Application name (e.g., KSwitch)
#   APP_VERSION          Version with v prefix (e.g., v0.1.0)
#   SPARKLE_PRIVATE_KEY  EdDSA private key (base64 string from Sparkle's generate_keys)
#   DIST_ZIP             Path to local ZIP file
#   DOWNLOAD_URL         URL where ZIP will be downloadable
#   RELEASE_URL          URL to the GitHub release page
#   APPCAST_OUTPUT       Output path for appcast.xml

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

log() { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

: "${APP_NAME:?APP_NAME is required}"
: "${APP_VERSION:?APP_VERSION is required}"
: "${SPARKLE_PRIVATE_KEY:?SPARKLE_PRIVATE_KEY is required}"
: "${DIST_ZIP:?DIST_ZIP is required}"
: "${DOWNLOAD_URL:?DOWNLOAD_URL is required}"
: "${RELEASE_URL:?RELEASE_URL is required}"
: "${APPCAST_OUTPUT:?APPCAST_OUTPUT is required}"

# Validate ZIP file exists
[[ -f "$DIST_ZIP" ]] || fail "ZIP file not found: $DIST_ZIP"

# Find sign_update tool
SIGN_UPDATE=""
for path in \
    "$ROOT/.build/artifacts/sparkle/Sparkle/bin/sign_update" \
    "$ROOT/.build/checkouts/Sparkle/bin/sign_update"
do
    [[ -x "$path" ]] && SIGN_UPDATE="$path" && break
done
[[ -n "$SIGN_UPDATE" ]] || fail "sign_update not found. Run 'swift build' first."

# Strip v prefix for version string
VERSION="${APP_VERSION#v}"
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")

log "==> Generating appcast.xml"
log "    Version:  $VERSION"
log "    ZIP:      $DIST_ZIP"
log "    URL:      $DOWNLOAD_URL"

# Sign the archive
log "--- Signing archive ---"
FILE_SIZE=$(stat -f%z "$DIST_ZIP" 2>/dev/null || stat -c%s "$DIST_ZIP")
SIGNATURE=$("$SIGN_UPDATE" "$DIST_ZIP" --ed-key-file <(echo "$SPARKLE_PRIVATE_KEY"))
ED_SIGNATURE=$(echo "$SIGNATURE" | grep -o 'edSignature="[^"]*"' | sed 's/edSignature="//;s/"//')
[[ -n "$ED_SIGNATURE" ]] || ED_SIGNATURE="$SIGNATURE"

# Generate appcast.xml
cat > "$APPCAST_OUTPUT" << EOF
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
        url="${DOWNLOAD_URL}"
        sparkle:edSignature="${ED_SIGNATURE}"
        length="${FILE_SIZE}"
        type="application/octet-stream"
      />
    </item>
  </channel>
</rss>
EOF

log "OK: appcast.xml generated"
log "    Output: $APPCAST_OUTPUT"
