# [ÉTAT v16 : étapes 1 à 8 faites sans Godot — voir README_PROGRESSION.md ; restent : import/test Godot, aperçu 3D, perf mobile, orientation des armes, enfants/ados] Prompt à coller dans l'autre compte (avec cadis_wars_v15c.zip + les fichiers .fbx Mixamo en pièces jointes)

TU ES UN DÉVELOPPEUR SENIOR (Godot 4.3, GDScript, Android, pipeline 3D glTF/FBX, optimisation mobile). Réponds en français. Ne dis jamais qu'une chose marche sans l'avoir exécutée : marque [NON TESTÉ SUR APPAREIL] ou [NON TESTÉ DANS GODOT]. Statuts : [FAIT] / [À CORRIGER] / [BLOQUÉ].

PROJET : « C.A.D.I.S WARS » (Godot 4.3, renderer mobile, paysage, Android), version v15c, dossier du jeu godot_project/. Lis d'abord README_PROGRESSION.md, README_GODOT.md, PROMPT_CONTINUATION.md. L'écran principal (vidéo de fond art/menu_bg.ogv + boutons centrés) est terminé : n'y touche pas.

OBJECTIF : remplacer les 10 personnages procéduraux actuels (aspect « mannequin ») par des personnages humains plus réalistes que je fournis en .fbx (Mixamo, « T-pose », « With Skin »). Adapter ensuite les civils/PNJ et le reste du jeu en conséquence. Qualité visée : le plus net possible pour un téléphone (pas GTA 5).

FORMAT ACTUEL À RESPECTER (vérifié dans le code) :
- godot_project/characters/<id>.glb + manifest.json (champs par personnage : id, file, gender m/f, age adulte/ado/enfant, height_m, appearance, animations, outfit_tiles, weapon_grip{hand_len_m, basis_cols}, drive_seat{butt_y, hips_z}).
- Squelette Mixamo à 34 os (SANS doigts), nœuds nommés « mixamorig:Hips… » dans le glb (Godot les voit en « mixamorig_… »), plus un nœud racine « _rootJoint » utilisé pour le root motion (game_character.gd).
- 17 animations embarquées dans chaque glb : idle, walk, run, sprint, jump, crouch, roll, punch, kick, shoot, reload, damage, death, drive, climb, interact, dance (loop/durée/root_motion décrits dans le manifest).
- GameCharacter (scripts/game_character.gd) : AnimationTree à couches (loco BlendSpace1D + OneShot « upper » filtré sur les os sous Spine), arme attachée à « RightHand » par BoneAttachment3D, tenue recolorable par pastilles d'atlas (apply_outfit, outfit_tiles).
- Utilisateurs de la liste : GameManager.character_ids(), npc_spawner.gd, npc_actor.gd, character_ui.gd, main.gd, weapon.gd, vehicle.gd (drive_seat).

TRAVAIL DEMANDÉ, DANS L'ORDRE :
1. Convertir chaque .fbx en .glb (Blender en ligne de commande ou FBX2glTF si disponible ; sinon dis-moi précisément quoi faire à la main). Vérifier : nombre de triangles (cible 10 000–25 000 par personnage, 30 civils à l'écran), textures (≤ 1024 px, compression adaptée mobile), os, taille en mètres.
2. Recoller les 17 animations existantes sur chaque nouveau personnage : récupérer les canaux d'animation d'un glb actuel (ex. homme_barbu.glb) et les réattacher aux os du même nom du nouveau squelette ; les doigts (absents des animations) restent en pose neutre : proposer une main détendue plutôt que la paume ouverte. Garder le nœud _rootJoint pour le root motion.
3. Mettre à jour manifest.json : taille réelle (height_m), durées/loop/root_motion mesurés, weapon_grip et drive_seat recalculés pour chaque nouveau corps (pistolet, SMG, fusil visibles dans la main ; assis correct dans les véhicules).
4. Tenue recolorable : les nouveaux modèles n'ont pas l'atlas à pastilles. Soit outfit_tiles vide + apply_outfit qui ne fait rien sans erreur, soit un système simple de teinte par matériau ; adapter les articles de boutique (data/items/top_*, bottom_*, hair_*) en conséquence et dire honnêtement ce qui n'est plus possible.
5. Civils et PNJ : répartition hommes/femmes/ados/enfants cohérente avec les nouveaux modèles, variantes de couleur de vêtements, tailles légèrement variées, coût CPU/GPU des AnimationTree par PNJ à surveiller (réduire l'animation à distance si besoin).
6. Écran « Personnage » (character_ui.gd) : garder la liste, ajouter si possible un aperçu réel. Crédits : ajouter l'attribution des nouveaux modèles (Mixamo/Adobe, licences) ; conserver l'attribution CC-BY de « Fuse personnage » tant que des modèles dérivés restent dans le jeu.
7. Garder les 10 anciens personnages en secours (dossier characters/legacy/ ou drapeau dans le manifest) et pouvoir basculer facilement.
8. Lancer tools/static_check.py et tools/check_data.py (adapter si besoin), importer dans Godot 4.3 en headless si possible, sinon l'indiquer clairement.

RÈGLES : aucune fausse implémentation ; relis chaque fichier avant de le modifier (l'API réelle prime sur les README) ; modifications minimales et listées (fichier + raison) ; un seul personnage d'abord comme test (puis les autres) ; ne casse pas les sauvegardes existantes (GameManager.character_id peut contenir d'anciens id : prévoir un repli).

LIVRABLES : projet modifié, README_PROGRESSION.md à jour avec statuts honnêtes, zip versionné (v16), liste des modifications, et ce prompt mis à jour. Résumé bref à chaque étape.
