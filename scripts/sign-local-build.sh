#!/bin/bash
set -euo pipefail

# Run from a desktop Terminal session so macOS can request private-key access.
# A signing failure must not fall back to an ad hoc signature.
identity=${1:?Usage: bash scripts/sign-local-build.sh SIGNING_IDENTITY}
repo=$(cd "$(dirname "$0")/.." && pwd)
source_app="$repo/output/PlayCover.app"
signed_app="$repo/output/PlayCover-developer-signed.app"

if [ ! -d "$signed_app" ]; then
    cp -R "$source_app" "$signed_app"
fi

/usr/bin/codesign --force --deep --sign "$identity" --options runtime \
    --preserve-metadata=entitlements "$signed_app"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$signed_app"

team=$(/usr/bin/codesign -dv "$signed_app" 2>&1 | /usr/bin/awk -F= '/^TeamIdentifier=/{print $2}')
if [ -z "$team" ] || [ "$team" = "not set" ]; then
    echo "Developer signing failed: no Team ID" >&2
    exit 1
fi
for component in \
    "$signed_app/Contents/Frameworks/Sparkle.framework" \
    "$signed_app/Contents/Frameworks/PlayTools.framework" \
    "$signed_app/Contents/Frameworks/PlayTools.framework/PlugIns/AKInterface.bundle"; do
    component_team=$(/usr/bin/codesign -dv "$component" 2>&1 | /usr/bin/awk -F= '/^TeamIdentifier=/{print $2}')
    if [ "$component_team" != "$team" ]; then
        echo "Team ID mismatch: $component" >&2
        exit 1
    fi
done

echo "Developer signature verified; Team ID: $team"
echo "App ready for launch testing: $signed_app"
