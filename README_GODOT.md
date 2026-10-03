# Intégration Godot 4.3 — C.A.D.I.S WARS v13

## Ouvrir / lancer

Ouvrir `godot_project/project.godot` avec **Godot 4.3**. Le premier import des 10 `.glb` se fait par Godot.

- **F5** démarre `main_menu.tscn` (scène principale) : Histoire / Mission secrète / Personnage / Magasins / Paramètres / Crédits.
- `game.tscn` est la scène de jeu (`GameManager.mode` : `story`, `secret` ou `test`).
- `main.tscn` est la visionneuse de personnages (un bouton par animation) : utiliser « Lancer cette scène ».

## Architecture (`godot_project/scripts/`)

- `autoload/` : Settings, Audio, Game, Inventory, Weapon, Vehicle, NPC, World, Mission, Save, UI.
- `player/` : `Player` (CharacterBody3D, capsule adaptée à la taille, SpringArm3D) et `PlayerCombat` (hitscan).
- `game_character.gd` : enveloppe de `.glb`, AnimationPlayer, AnimationTree locomotion, OneShot haut du corps, tenue recolorable et attachement aux os.
- `ai/`, `world/`, `ui/`, `defs/` (WeaponDef/ItemDef/MissionDef/VehicleDef/CityDef), `vehicles/`.
- Données : `data/**/*.tres` et `data/registry.json`. `secret_site` est volontairement chargé directement par le mode Mission secrète.

## Mouvement et repères

Valeurs du manifest pour l’adulte de 1,75 m : marche 1,14 m/s, course 3,70 m/s, sprint 5,26 m/s ; enfant de 1,05 m : 0,66 / 2,16 / 3,07 m/s. Ces valeurs sont lues avec `GameCharacter.anim_speed` ; vitesse/animation n’ont pas été comparées sur une longue session en jeu.

- Personnage : +Y haut, +Z avant.
- Arme (repère local) : canon +Y, dessus +Z, crosse vers -Z. `manifest.weapon_grip.basis_cols` décrit les axes locaux de l’arme sur l’os `RightHand`.
- Tir joueur : rayon par le centre de l’écran via `Camera3D.project_ray_origin/normal`, aligné avec le centre du HUD.

## Validation v13 exécutée

- Godot 4.3 exact : import, analyse éditeur, et smoke-test du menu, de la visionneuse et du jeu sous OpenGL logiciel/Xvfb.
- 10/10 modèles : setup, squelette 34 os, main droite, 22 chemins de masque, matériau avec albedo et normal.
- OneShot `shoot` : lancement actif puis fin automatique vérifiée ; transitions gameplay complètes non parcourues.
- Correction visuelle du mannequin du menu vérifiée par captures avant/après : `docs/evidence/`.

Le détail des tests et les limites sont dans [README_PROGRESSION.md](README_PROGRESSION.md) et [docs/COMPTE_RENDU_ANALYSE_v13.md](docs/COMPTE_RENDU_ANALYSE_v13.md). Le parcours détaillé reste dans [TEST_PROTOCOL.md](TEST_PROTOCOL.md).

## Android

Preset Android v13 : package `com.cadis.wars`, version 13 / 0.13.0, arm64-v8a, mode immersif. L’export **n’a pas encore produit d’APK** : le test local est bloqué par l’absence de chemins Java SDK et Android SDK ; consulter `EXPORT_ANDROID.md`.

## Pipeline des modèles et crédit

`tools/export_glb.py` écrit dans `godot_project/characters/` ; vérifier avec `python3 tools/verify_glb.py perso anim image.png`. Les modèles et le registre n’ont pas été modifiés pendant les corrections v13.

Crédit CC-BY-4.0 « Fuse personnage » (Sketchfab, auteur 1831251) : affiché dans « Crédits » et la visionneuse.
