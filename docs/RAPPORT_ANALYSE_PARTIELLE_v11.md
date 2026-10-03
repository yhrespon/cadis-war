# Analyse partielle v11 (session interrompue) — honnête

Godot absent (pas de réseau) : analyse = relecture manuelle. RIEN n'a été exécuté. Contrôles statiques : 0 problème (static_check, check_data).

## Relu en détail (≈ 5 000 lignes sur 6 800)
autoloads (game, save, world, ui, inventory, vehicle, weapon, npc, mission, settings, audio), game.gd, player, player_combat, weapon, game_character, vehicle, npc_actor, enemy/ally/civilian, npc_spawner, city_builder, objets du monde, game_input, touch_controls, ui_kit, base_panel, hud, minimap, main_menu, pause, travel, result, character, credits, shop, settings_ui, mission_panel, defs.

## NON relu
scripts/main.gd (visionneuse), .tres de data/, main.tscn / game.tscn / main_menu.tscn, project.godot détaillé vs autoloads, EXPORT_ANDROID.md, TEST_PROTOCOL.md, workflow (fin), tools/*.py, cohérence des .glb / manifest (animations, outfit_tiles).

## Corrigé (2, dans touch_controls.gd)
1. Bouton Pause tactile hors écran : y = -60 (formule `-p.y`) -> y = +60.
2. Contexte véhicule : aucun bouton pour le frein (Player lit l'action « jump » pour freiner) -> bouton « FREIN » ajouté ; « ACTION » étiqueté « SORTIR ».

## Incohérences / risques trouvés, NON corrigés
- Dossier racine nommé `..._v6f` alors que l'archive s'appelle v11 (zip livré : renommé cadis_wars_v11).
- 4 prompts de continuation (PROMPT_CONTINUATION, v9, v10, v11) + README de 43 Ko : redondants, README_GODOT annonce encore 1,6 m/s (faux, 1,14).
- Package Android : com.cadis.wars (preset) vs com.example.cadiswars (README v6f).
- Convention d'axes de l'arme contradictoire : README v6e « canon +Z » / v9 et weapon.gd « canon +Y, dessus +Z » -> à vérifier visuellement dans Godot (basis_cols du manifest).
- player.gd : `_update_driving` ne gère pas la mort/pause du conducteur autrement que par exit_vehicle(true) ; `rig.rotation.y = PI + 0.0` (résidu).
- Hud : réticule au centre exact alors que cam.h_offset ≠ 0 (le tir part de la caméra décalée) -> réticule faux d'environ 0,45 m à l'écran.
- NPCManager.clear() ne désenregistre pas les PNJ morts via tree_exited si connecté sur lambda capturant `n` (OK) ; mais count_of() parcourt des instances libérées sans nettoyage périodique.
- WorldManager : les voitures garées sont déterministes mais non persistées -> « jumelle » après déplacement (déjà connu).
- Missions « interact » : colonne lumineuse, pas de PNJ (connu).
- GameCharacter.apply_outfit : suppose `StandardMaterial3D` à l'import du .glb ; non vérifié (peut être null selon l'import -> tenue non recolorée).
- mission_panel.gd non refactoré sur BasePanel (duplication de style).
- Divisions entières `s / 60` (avertissement GDScript INTEGER_DIVISION, pas une erreur).

## À faire en premier (nouveau compte)
Voir PROMPT_CONTINUATION_ANALYSE.md.
