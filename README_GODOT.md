# Intégration Godot 4.3+ — v6d (NON exécuté : aucun Godot dans mon environnement)

## Ouvrir / lancer
Godot 4.3+ -> Importer `godot_project/project.godot` (premier import des 10 `.glb` : quelques secondes chacun).
- **F5 = niveau de jouable `game.tscn`** (scène principale) : sol, bâtiment + échelle, rampe, voiture, pistolet et batte au sol, 3 mannequins.
- `main.tscn` = ancienne visionneuse (choix du perso, un bouton par animation) : clic droit > « Lancer cette scène ».

## Ce qui est écrit (scripts/)
- `player.gd` : **CharacterBody3D** (capsule, gravité, `move_and_slide`) + `GameCharacter` + caméra `SpringArm3D` (collision caméra).
  Actions : marche/course/sprint (vitesses = celles des animations : 1,6 / 3,7 / 5,3 m/s adulte, pas de patinage), saut, accroupi, roulade,
  poing, pied, tir (raycast depuis la caméra), recharge, interaction, escalade, conduite, dégâts, mort + réapparition.
  `use_root_motion = true` : la vitesse vient du root motion de l'animation à la place des valeurs codées.
- `game_input.gd` : actions clavier créées par code. ZQSD/WASD, Espace saut, Maj sprint, C accroupi, V roulade, J poing, K pied, F tir, R recharge, E interagir. Clic = capture souris, Échap = libère.
- `touch_controls.gd` : joystick virtuel (gauche), glisser à droite = caméra, 9 boutons. Visible seulement sur appareil tactile/mobile.
- `weapon.gd` (pistolet, batte : primitives, `BoneAttachment3D` sur la main droite), `pickup.gd`, `target_dummy.gd`,
  `ladder.gd` (animation climb), `vehicle.gd` (voiture arcade, anim drive), `game_world.gd` (niveau + HUD).

## À vérifier au premier lancement (je n'ai pas pu tester)
1. Console : erreurs de parse GDScript éventuelles (écrit à la main, jamais compilé).
2. Le personnage joue-t-il ses animations ? Sinon vérifier dans l'Import dock qu'un AnimationPlayer est créé.
3. Os de la main : Godot peut renommer `mixamorig:RightHand` en `mixamorig_RightHand` ; `attach_to_bone` compare la fin du nom. Orientation de l'arme : régler `grip_offset` / `grip_rotation_deg` dans `weapon.gd` (axe long = +Y de l'os).
4. Position assise en voiture : `anchor.position` dans `vehicle.gd`. Échelle : le joueur se tient à +0,45 m côté +Z.
5. Avertissements glTF `byteStride` : corrigés à l'export (stride explicite 8/12/16 sur toutes les vues d'attributs). À reconfirmer dans Godot.

## Android
`export_presets.cfg` (preset « Android », arm64, immersif, `com.example.crimegame` -> changer l'identifiant) et `project.godot`
(`import_etc2_astc=true`, obligatoire pour exporter en mobile/compatibilité, paysage) sont prêts. Il reste à faire sur ta machine :
Éditeur > Gérer les modèles d'export (installer 4.3+), JDK 17 + Android SDK (Paramètres de l'éditeur > Export > Android), keystore de debug,
puis Projet > Exporter. Pour la publication : keystore de release (non fourni). Aucun APK n'a été produit ici.

## Pipeline des modèles
`tools/export_glb.py` écrit directement dans `godot_project/characters/` (source unique : plus de dossier `export/`).
`python3 tools/export_glb.py [perso1,perso2]` puis `python3 tools/verify_glb.py perso anim image.png`.

## Crédit
CC-BY-4.0 « Fuse personnage » (Sketchfab, auteur 1831251) : à afficher dans l'écran « Crédits » (déjà dans la visionneuse).
