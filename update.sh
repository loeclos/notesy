#!/usr/bin/env bash
# Regenerate versions.json from the upstream release feed and point the
# `version` default in notesy.nix at the feed's latest.
#
# Usage: ./update.sh [channel] [version]
#   channel defaults to "beta", version defaults to the feed's latest.
#   The feed only carries hashes for its latest release, so requesting an
#   older/different version fails with instructions for a manual entry.
#
# Deps: curl, jq. Pure eval is preserved — this runs at maintenance time,
# not during `nix build`/`nix eval`.
set -euo pipefail

BASE_URL="${NOTESY_BASE_URL:-https://cdn.notesy.ink}"
CHANNEL="${1:-beta}"
WANT_VERSION="${2:-}"

FEED="$BASE_URL/$CHANNEL/latest.json"
echo "fetching $FEED ..." >&2
META="$(curl -fsSL "$FEED")"
LATEST="$(jq -r '.version' <<<"$META")"

if [[ -z "$WANT_VERSION" ]]; then
  VER="$LATEST"
elif [[ "$WANT_VERSION" != "$LATEST" ]]; then
  echo "error: feed $FEED only provides hashes for latest ($LATEST), not $WANT_VERSION." >&2
  echo "Add it manually to versions.json (tar/zip/programSha256 for x86_64-linux) or wait for release." >&2
  exit 1
else
  VER="$WANT_VERSION"
fi

# linux-x86_64 is published under both "linux-x86_64" and "x86_64-linux" keys.
ASSET="$(jq -c '.assets."linux-x86_64" // .assets."x86_64-linux" // null' <<<"$META")"
if [[ "$ASSET" == "null" ]]; then
  echo "error: no linux-x86_64 asset in $FEED. Keys: $(jq -c '.assets | keys' <<<"$META")" >&2
  exit 1
fi

# Sanity: the derived URL pattern in notesy.nix must match the feed's tar URL.
EXPECTED_TAR_URL="$BASE_URL/$CHANNEL/$VER/notesy-$VER-linux-x86_64.tar.gz"
FEED_TAR_URL="$(jq -r '.tar.url' <<<"$ASSET")"
if [[ "$FEED_TAR_URL" != "$EXPECTED_TAR_URL" ]]; then
  echo "warning: feed tar URL drift:" >&2
  echo "  feed:    $FEED_TAR_URL" >&2
  echo "  derived: $EXPECTED_TAR_URL" >&2
  echo "Pass srcUrl explicitly or fix the assetFile pattern in notesy.nix." >&2
fi

ENTRY="$(jq -n --argjson a "$ASSET" '{tar: $a.tar.sha256, zip: $a.sha256, programPath: $a.program.path, programSha256: $a.program.sha256}')"

jq --arg v "$VER" --argjson e "$ENTRY" \
  '.[$v] |= (. // {}) | .[$v]["x86_64-linux"] = $e' \
  versions.json > versions.json.tmp && mv versions.json.tmp versions.json

# Point the `version ? "..."` default at the new release (single-line, safe).
sed -i -E 's/(version \? ")[^"]+(")/\1'"$VER"'\2/' notesy.nix

if ! jq -e --arg v "$VER" '.[$v]["x86_64-linux"].tar' versions.json >/dev/null; then
  echo "error: failed to write versions.json entry for $VER" >&2
  exit 1
fi

echo "pinned $VER (channel $CHANNEL):"
jq --arg v "$VER" '.[$v]' versions.json
echo "Next: nix build .#packages.x86_64-linux.notesy"
