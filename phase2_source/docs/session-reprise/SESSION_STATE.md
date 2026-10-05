# CADIS WAR ZONE — état de session et reprise

## Identité du dépôt

Nom de travail : `cadis-war-zone`
Version de travail : `v18 première tranche PC/Xbox-like`
Date de gel : 5 octobre 2026
Profil graphique : **Forward+ PC/Xbox-like**

## Ce qui est inclus

Le dépôt contient le projet Godot complet, les scènes, scripts, modèles GLB, textures, shaders, ressources d’éclairage, audio original présent dans la source, ainsi que les nouveaux assets générés pour la première tranche :

- `audio/dialogue/mission_intro_fr.wav`
- `audio/dialogue/boss_warning_fr.wav`
- `audio/ambience/rain_wind_loop.mp3`
- `systems/dialogue_manager.gd`
- `systems/day_night_weather.gd`
- `RAPPORT_V18_PREMIERE_TRANCHE.md`

Le dossier `.godot/` n’est pas versionné car il contient 806 Mo de caches générés automatiquement. Il sera régénéré par Godot à la première ouverture et ne contient pas de source nécessaire.

## Installation validée dans la session d’origine

- OS : Ubuntu 24.04 x86_64
- Godot standard : `/home/ubuntu/tools/godot-4.3/Godot_v4.3-stable_linux.x86_64`
- Alias utilisé : `/home/ubuntu/.local/bin/godot4.3`
- Version : `4.3.stable.official.77dcf97d8`
- Godot Mono installé : `/home/ubuntu/tools/godot-4.3-dotnet/Godot_v4.3-stable_mono_linux_x86_64/Godot_v4.3-stable_mono_linux.x86_64`
- .NET SDK : `/home/ubuntu/.dotnet`, version `8.0.425`
- Java : OpenJDK 21
- Android SDK : `/home/ubuntu/android-sdk`
- Android build-tools : `34.0.0`
- Android platform-tools : `adb`
- Templates d’export Godot 4.3 installés dans le profil utilisateur d’origine

## Variables utiles

```bash
export PATH=/home/ubuntu/.local/bin:/home/ubuntu/.dotnet:/home/ubuntu/android-sdk/platform-tools:/home/ubuntu/android-sdk/build-tools/34.0.0:$PATH
export DOTNET_ROOT=/home/ubuntu/.dotnet
export ANDROID_HOME=/home/ubuntu/android-sdk
export ANDROID_SDK_ROOT=/home/ubuntu/android-sdk
export GODOT_SILENCE_ROOT_WARNING=1
```

Les binaires d’installation ne sont pas copiés dans le dépôt Git : GitHub impose des limites sur les gros fichiers et les caches importés sont régénérables. Les chemins et versions ci-dessus permettent de retrouver exactement l’environnement validé. Les scripts historiques `scripts/setup_cadis_environment.sh` et `scripts/build_android.sh` restent dans le dépôt.

## Corrections de cette version

Le mode solo crée maintenant le joueur même sans pair réseau. La caméra statique du niveau est désactivée et la caméra du joueur est activée après son ajout dans l’arbre de scène. Le renderer du projet est configuré en Forward+ et le profil mobile utilise Mobile. L’exposition et le brouillard ont été réduits, les réglages TAA/MSAA/VoxelGI/SSAO/SSIL ont été renforcés.

Un contrôleur jour/nuit avec soleil dynamique et météo claire/pluie/orage est branché au niveau. Les touches `1`, `2` et `3` changent la météo pendant le test. Le gestionnaire `DialogueManager` affiche les sous-titres et lit les voix françaises si elles existent. Le niveau joue le briefing de Joe et le robot possède une première menace vocale.

Les accès fragiles aux animations de projectile et aux surfaces des pièces robot sont protégés. `gdlintrc` sépare les anciennes règles de style du lint fonctionnel.

## Tests effectués

```bash
godot4.3 --headless --path . --editor --rendering-method gl_compatibility --quit
godot4.3 --headless --path . --scene res://level/level.tscn --rendering-method forward_plus --quit-after 6
gdlint systems/day_night_weather.gd systems/dialogue_manager.gd level/level.gd player/player_input.gd enemies/red_robot/red_robot.gd enemies/red_robot/parts/part.gd player/bullet/bullet.gd menu/settings.gd
```

Résultats : import/parse Godot OK, démarrage Forward+ OK, erreurs GDScript 0, erreurs d’animation `explode` 0, lint des fichiers modifiés OK.

Une erreur Godot `mesh_get_surface_count` provenant d’un asset importé reste à isoler dans l’éditeur Godot 4.7 ou après réimportation propre des GLB. Elle ne provient pas d’un parse GDScript et ne bloque pas le démarrage Forward+ headless.

## Reprise

1. Cloner ou ouvrir le dépôt.
2. Ouvrir `project.godot` avec Godot 4.3 pour validation ou Godot 4.7 pour l’éditeur/les assets.
3. Lancer `res://menu/menu.tscn`.
4. Cliquer sur `JOUER > Histoire/Solo`.
5. Vérifier la présence de Joe, la caméra troisième personne et les sous-titres.
6. Tester `1`, `2`, `3` dans le niveau.
7. Réimporter les GLB dans Godot 4.7 si l’erreur `mesh_get_surface_count` apparaît encore.
8. Continuer par la vertical slice : caméra/animation, armes, mission aventure, boss, végétation, dialogues et audio adaptatif.
