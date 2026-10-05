# Prompt de reprise — CADIS WAR ZONE

Tu reprends le projet **CADIS WAR ZONE** depuis le dépôt Git `cadis-war-zone`, commit `v18-premiere-tranche-pc-xbox-like`.

Le projet est un jeu Godot 3D TPS sci-fi. La priorité technique est **PC/Xbox-like avec renderer Forward+**, avec un profil mobile séparé. Le mode solo a été corrigé pour créer le joueur hors réseau et activer automatiquement sa caméra. Un contrôleur jour/nuit/météo est installé dans `systems/day_night_weather.gd`. Le système de sous-titres et voix françaises est dans `systems/dialogue_manager.gd`.

Commence par lire `SESSION_STATE.md` et `RAPPORT_V18_PREMIERE_TRANCHE.md`, puis vérifie `project.godot`, `level/level.gd`, `player/player_input.gd`, `menu/settings.gd`, `enemies/red_robot/red_robot.gd` et `enemies/red_robot/parts/part.gd`.

Assets vocaux déjà intégrés : `audio/dialogue/mission_intro_fr.wav` et `audio/dialogue/boss_warning_fr.wav`. Ambiance météo : `audio/ambience/rain_wind_loop.mp3`.

Ne réuploade pas l’archive source et ne réinstalle pas les outils si Godot 4.3, Godot Mono, .NET 8 et Android SDK sont déjà présents. Les versions et chemins de l’environnement sont décrits dans `SESSION_STATE.md`.

Tâche de reprise immédiate :

1. Ouvrir le projet et vérifier visuellement que Joe est visible et que la caméra troisième personne est active.
2. Reproduire l’erreur éventuelle `mesh_get_surface_count` et identifier l’asset GLB exact dans Godot 4.7.
3. Réimporter uniquement l’asset défectueux et conserver les sources originales.
4. Ajouter une vraie mission aventure avec objectifs, déclencheurs, checkpoints et sous-titres français.
5. Ajouter des animations et armes plus détaillées avant d’augmenter les effets graphiques.
6. Ajouter végétation, arbres, props et variantes de météo sans sacrifier le framerate.
7. Ajouter des boss avec phases d’attaque et dialogues français contextuels.
8. Tester Forward+ sur PC réel puis produire un profil qualité moyen et un profil Android.

Contraintes : ne pas prétendre atteindre le niveau AAA de GTA V/Xbox One avec de simples réglages ; produire une amélioration mesurable, tester chaque étape et conserver un commit propre par tranche.
