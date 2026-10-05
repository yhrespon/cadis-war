#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
WARN=0
FAIL=0

check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '[OK] %s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '[MANQUANT] %s\n' "$label"
    FAIL=$((FAIL + 1))
  fi
}

optional() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '[OK] %s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '[À INSTALLER] %s\n' "$label"
    WARN=$((WARN + 1))
  fi
}

printf '%s\n' 'CADIS WAR ZONE — vérification de reprise (aucun téléchargement)'
printf 'Dépôt: %s\n' "$ROOT"

check 'project Git présent' test -d "$ROOT/.git"
check 'source phase2 présente' test -f "$ROOT/phase2_source/project.godot"
check 'prompt de reprise présent' test -f "$ROOT/PROMPT_REPRISE_CADIS_WAR_ZONE_PHASE2.md"
check 'manifeste environnement présent' test -f "$ROOT/docs/ENVIRONMENT_MANIFEST_CADIS_WAR_ZONE.md"
check 'autoload MissionManager présent' grep -q 'MissionManager=' "$ROOT/phase2_source/project.godot"
check 'gestionnaire de mission présent' test -f "$ROOT/phase2_source/systems/mission_manager.gd"
check 'preset Android présent' grep -q 'platform="Android"' "$ROOT/phase2_source/export_presets.cfg"
check 'server.js présent' test -f "$ROOT/server.js"
check 'package-lock présent' test -f "$ROOT/package-lock.json"

optional 'Godot 4.3 disponible' command -v godot4.3
optional 'Node disponible' command -v node
optional 'npm disponible' command -v npm
optional 'Java disponible' command -v java
optional 'Android SDK présent' test -d "${ANDROID_HOME:-$HOME/android-sdk}"
optional 'templates Godot 4.3 présents' test -f "$HOME/.local/share/godot/export_templates/4.3.stable/android_debug.apk"

printf '\nRésumé: OK=%d À_INSTALLER=%d BLOQUANT=%d\n' "$PASS" "$WARN" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
