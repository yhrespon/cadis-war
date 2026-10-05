# CADIS WAR ZONE — gel de session du 5 octobre 2026

Ce document est la **source de vérité pour reprendre le projet dans un autre compte**. Il accompagne la source phase 2 conservée dans `phase2_source/`.

## Dépôt et état Git

- Dépôt : `yhrespon/cadis-war`
- Branche : `main`
- Projet : C.A.D.I.S WARS / CADIS WAR ZONE
- Moteur validé : Godot `4.3.stable.official.77dcf97d8`
- Le présent commit contient les fichiers de source, les scripts, les rapports, les instructions et les métadonnées de session. Les caches `.godot/`, `node_modules/`, APK générés et journaux volumineux restent exclus ou régénérables.

## Source phase 2

La source issue de la session référencée `7XCDHThHENnU2YxmwgJQUF` est archivée sous `phase2_source/`. Elle contient notamment le projet Godot, les assets, les scripts de mission, météo, dialogue, les scènes, le preset Android et les scripts d’installation/export.

Fonctionnalités de la tranche 2 : mission `north_gate_revolt`, trois objectifs, HUD, checkpoints, dialogues français, météo jour/nuit, pluie/orage, spawn solo, corrections Godot 4.3, protections bullet/mesh et export APK Android.

## Logiciels et versions

| Outil | Version / chemin de référence |
|---|---|
| Ubuntu | 24.04 x86_64 |
| Godot standard | `4.3.stable.official.77dcf97d8` ; alias `/home/ubuntu/.local/bin/godot4.3` |
| Java | OpenJDK 17 requis pour l’export Android ; OpenJDK 21 présent dans la sandbox de gel |
| Android SDK | `$HOME/android-sdk` |
| Android build-tools | `35.0.0` observé ; le script historique cible aussi `34.0.0` |
| Node.js | `v22.13.0` |
| npm | `10.9.2` |
| Export templates | `$HOME/.local/share/godot/export_templates/4.3.stable` |
| Android apksigner | `$HOME/android-sdk/build-tools/35.0.0/apksigner` |

Les binaires ne sont pas committés : ils sont volumineux et régénérables. Le script `phase2_source/scripts/setup_cadis_environment.sh` documente l’installation SDK et templates.

## Commandes de reprise

```bash
gh repo clone yhrespon/cadis-war
cd cadis-war
chmod +x phase2_source/scripts/setup_cadis_environment.sh phase2_source/scripts/build_android.sh scripts/verify_cadis_resume.sh
./scripts/verify_cadis_resume.sh
```

Validation Godot 4.3 :

```bash
cd phase2_source
GODOT_SILENCE_ROOT_WARNING=1 godot4.3 --headless --path . --editor --quit --rendering-method forward_plus
godot4.3 --headless --path . --scene res://level/level.tscn --rendering-method forward_plus --quit-after 6
```

Export Android :

```bash
cd phase2_source
export ANDROID_HOME="$HOME/android-sdk"
export ANDROID_SDK_ROOT="$HOME/android-sdk"
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
godot4.3 --headless --path . --rendering-method gl_compatibility --export-debug Android CadisWarZone_PHASE2_debug.apk
$ANDROID_HOME/build-tools/35.0.0/apksigner verify --verbose CadisWarZone_PHASE2_debug.apk
```

## Résultats réellement observés

- Import et compilation Godot 4.3 : aucune erreur `SCRIPT ERROR`, `Parse Error` ou `Failed to load script`.
- Runtime headless Forward+ de `res://level/level.tscn` : aucune erreur GDScript ni animation `explode`.
- Export APK debug : réussi, APK d’environ 490 Mo.
- Signature APK : v1, v2 et v3 vérifiées.
- Limite connue : un message `mesh_get_surface_count` issu d’un asset 3D importé peut encore apparaître avec le renderer dummy headless. Il ne bloque pas le parsing ni l’export ; réimporter l’asset avec Godot 4.7 pour l’isoler.
- [NON TESTÉ SUR APPAREIL] tactile, vibrations réelles, performances Android, audio matériel et installation sur téléphone.

## Fichiers de reprise

- `PROMPT_REPRISE_CADIS_WAR_ZONE_PHASE2.md` : prompt autonome à copier dans un nouveau compte.
- `docs/ENVIRONMENT_MANIFEST_CADIS_WAR_ZONE.md` : inventaire des outils et variables.
- `docs/session-reprise/` : état et rapports de la session historique.
- `phase2_source/RAPPORT_V19_PHASE2.md` : rapport détaillé de la tranche 2.
