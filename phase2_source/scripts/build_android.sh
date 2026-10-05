#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$HOME/.cadis-android.env" ] && source "$HOME/.cadis-android.env"
cd "$ROOT"
godot --headless --rendering-method gl_compatibility --export-debug "Android" CadisWarZone_PRO.apk
"${ANDROID_HOME:-$HOME/android-sdk}/build-tools/34.0.0/apksigner" verify --verbose CadisWarZone_PRO.apk
echo "APK créé et vérifié : $ROOT/CadisWarZone_PRO.apk"
