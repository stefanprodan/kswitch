#!/usr/bin/env bash

# Generate appcast.xml for Sparkle updates.
#
# Usage: appcast.sh (env vars: ARCHIVE, VERSION, DOWNLOAD_URL, SPARKLE_PRIVATE_KEY)
#
# Required environment variables:
#   ARCHIVE             Path to the signed .zip archive
#   VERSION             Version string (e.g., 1.0.0)
#   DOWNLOAD_URL        URL where the archive will be hosted
#   SPARKLE_PRIVATE_KEY EdDSA private key for signing

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

log() { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

: "${ARCHIVE:?ARCHIVE is required}"
: "${VERSION:?VERSION is required}"
: "${DOWNLOAD_URL:?DOWNLOAD_URL is required}"
: "${SPARKLE_PRIVATE_KEY:?SPARKLE_PRIVATE_KEY is required}"

[[ -f "$ARCHIVE" ]] || fail "Archive not found: $ARCHIVE"

# Find sign_update tool
SIGN_UPDATE=""
for path in \
    "$ROOT/.build/artifacts/sparkle/Sparkle/bin/sign_update" \
    "$ROOT/.build/checkouts/Sparkle/bin/sign_update"
do
    [[ -x "$path" ]] && SIGN_UPDATE="$path" && break
done
[[ -n "$SIGN_UPDATE" ]] || fail "sign_update not found. Run 'swift build' first."

log "==> Signing archive"
FILE_SIZE=$(stat -f%z "$ARCHIVE" 2>/dev/null || stat -c%s "$ARCHIVE")
SIGNATURE=$("$SIGN_UPDATE" "$ARCHIVE" --ed-key-file <(echo "$SPARKLE_PRIVATE_KEY"))
ED_SIGNATURE=$(echo "$SIGNATURE" | grep -o 'edSignature="[^"]*"' | sed 's/edSignature="//;s/"//')

[[ -n "$ED_SIGNATURE" ]] || ED_SIGNATURE="$SIGNATURE"

PUB_DATE=$(date -R)

log "==> Generating appcast.xml"
cat > "$ROOT/appcast.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>KSwitch Updates</title>
    <item>
      <title>Version ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
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
cat "$ROOT/appcast.xml"
