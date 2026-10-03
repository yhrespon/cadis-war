# Projet : personnages pour jeu d'action type Crime City (APK) — état v5

## Objectif de l'utilisateur
Plusieurs personnages similaires (hommes, femmes, jeunes, enfants), vêtements/têtes/cheveux/coiffures différents, maximum d'animations, pour un jeu d'action à missions (APK pro : lobby, interface, scènes, options). Résultats réels, sans simulation, suivant le design du modèle fourni. Réponses en français, dire franchement ce qui n'est pas faisable.

## Modèle de départ (source_model/)
« Fuse personnage », Sketchfab, auteur 1831251, CC-BY-4.0 : crédit obligatoire (texte dans source_model/license.txt, à reprendre dans le jeu). glTF 2.0, 8 maillages skinnés, 1 matériau, atlas 4096x4096, squelette Mixamo 34 joints (cm, pose T, base féminine).

## Prérequis
Python 3 + numpy, opencv-python, Pillow ; gcc (le z-buffer C se compile tout seul au premier rendu : tools/zraster.c -> libzraster.so). Pas de Blender, pas de Mixamo, pas de réseau.
Lancer : `cd tools && python3 cast.py` régénère previews/sheet_front.png et sheet_back.png (8 personnages).

## Outils (tools/)
- rig.py : lecture glTF, hiérarchie, pose de bind, rx/ry/rz, qmat/mat_to_q.
- render.py : skinning logiciel ; render_tris (ancien painter, artefacts) ; **render_z (NOUVEAU, vrai z-buffer en C, texture + ombrage par pixel, antialiasing ss=2)**.
- zraster.c : rasteriseur C orthographique, double face.
- geo.py : loft, dome, sector_brim (visière incurvée épaisse, fermée), merge, calc_normals.
- body_parts.py : mesures sur le modèle, torse en loft (profil homme/femme), manches (emmanchure élargie), poignets, jambes calées sur les bottes (+ y=52..32 mesurés sur Body), bassin (part de y=92), jupe (part de y=92), haut des jambes rétréci (a_top) pour épouser la taille.
- headshell.py (NOUVEAU) : coques de crâne bâties sur le profil MESURÉ de la tête (HEAD_TAB), bord variable (devant/côtés/derrière + « dips » pattes/oreille/nuque), rideau de cheveux longs.
- faceart.py (NOUVEAU) : barbe PEINTE dans l'atlas (masque analytique lissé évalué en 3D dans l'espace UV), plus de volume 3D.
- chargen.py : atlas 1536x512 + pastilles, recoloration, make_hair (rase, court, coupe, afro, longs, queue, chignon, crete), cap_parts (casquette 2 couleurs), build()/finalize(). build() retire désormais : torse de Body, moignons de jambes (si bas procédural), bras de Body recouverts par une manche.
- char.py : classe Char ; render() utilise render_z par défaut (painter=True pour l'ancien).
- cast.py : 8 personnages de test (CAST) + planches.
- zoom.py, headcheck.py, diag_zbuffer.py (NOUVEAUX) : rendus de contrôle zoomés (zones, têtes face/3-4/profil/dos, painter vs z-buffer).

## Ce qui est fait en (A bis) — vérifié par rendu
1. Z-buffer écrit. Verdict : les stries de peau à travers t-shirt/manches étaient un **artefact du painter** (disparues) ; les bandes à la ceinture et la peau au bas des jeans étaient de **vrais défauts** (recouvrement bassin/haut y 92-100 ; moignons de jambes de Body sous le jean) -> corrigés.
2. Recouvrement bassin/haut supprimé (haut et bassin/jupe se raccordent à y=92).
3. Barbe : peinte sur la texture (menton arrondi, pattes, moustache avec fente sous le nez), bords nets.
4. Casquette : couronne basse sur crâne mesuré, visière incurvée plus étroite, bouton, 2e couleur. Coiffure « court » : plus de bol (naissance relevée, pattes, nuque dégagée).
5. sheet_back.png inspecté : défauts d'épaules trouvés et corrigés (peau parasite au dos).
6. 8 personnages rendus face et dos : previews/sheet_front.png, sheet_back.png (copies *_v4.png).
7. Alpha mesuré : 255 sur tous les pixels utilisés -> exporter en alphaMode OPAQUE (à appliquer en (C)).

## Ce qui est fait en (A ter) — v5, vérifié par rendu (previews/*_v5.png)
1. Jonction manche/torse : cause = torse (demi-largeur jusqu'à 17 cm) presque à fleur de la manche -> dents de scie. Corrigé : `bp.shoulder_clip` (torse resserré à hauteur d'épaule pour les hauts à manches, appliqué dans chargen.build via `prof_c`) + manche à départ effilé/abaissé (`bp.sleeve`, x_start=6). Vérifié face, 3/4, dos, profil sur homme_barbu, ado_casquette, punk (zoom_epaules_v5.png). Plus de bloc ni de dents de scie.
2. Entrejambe : cause = fond du bassin dépassant des jambes de 2-4 cm (bloc à bords durs). Corrigé : `bp.pelvis` s'effile en U (6 sections, jusqu'à y=77). Vérifié face/3-4/dos/profil (zoom_hanches_v5.png). Petite encoche résiduelle au dos du jean en vue de profil (mineure).
3. Cheveux longs : rideau ondulé (`hs.back_curtain` renvoie maintenant une LISTE de bandes/mèches, 15 bandes, 5 d'une nuance plus claire = A.swatch(hc*1.2+5)), plus long (y_bot=122). Encore plutôt « mi-long/carré » que très longs ; mèches discrètes.
4. Afro : n'était qu'un béret plat -> remplacé par un dôme (geo.dome) centré (XC,154,2.6), bord rentré en 6 anneaux (chargen.make_hair, branche 'afro'). Lisible comme afro, sans texture de boucles.
5. 'coupe' (garcon_enfant) et 'rase' (test, non inclus dans CAST) revérifiées en gros plan : correctes. (tetes_v5.png)
6. CAST = 10 personnages : homme_barbu, femme_jupe, punk, garcon_enfant (coiffure 'coupe'), ado_casquette, fille_queue, femme_chignon, homme_afro (NOUVEAU), ado_fille_longs (NOUVEAU), chauve_costume. Planches face/dos : previews/sheet_front_v5.png, sheet_back_v5.png (sheet_front/back.png = identiques). Sheet_front/back générées avec ncol=5.
7. Nouveaux scripts de contrôle : tools/ctrl_haut.py (épaules), ctrl_entrejambe.py, ctrl_tetes.py (usage : `python3 ctrl_xxx.py nom1,nom2 sortie.png` ; ctrl_tetes accepte aussi 'test_rase'), zoom_a.py.

## Défauts restants (mineurs)
- Planche dos des 2 nouveaux personnages + des planches v5 complètes : générées mais PAS inspectées image par image dans cette session (seuls les gros plans ci-dessus l'ont été). À regarder en premier.
- Cheveux : couleur unie ou 2 nuances, pas de texture de mèches/boucles ; afro lisse.
- Vêtements : couleurs unies, pas de plis ni de textures.
- Encoche mineure à l'arrière du jean en profil.
- AUCUNE animation, AUCUN .glb : (B), (C), (D) NON COMMENCÉS.

## Reste à faire
B. anim.py (non commencé) : animations procédurales. Principe : rotation relative D_j dans les axes MONDE ; rotation locale glTF = Wr[parent]^T @ D_j @ Wr[j] ; translation de Hips pour le rebond. +x = côté gauche du perso, +y haut, +z devant. En pose T, bras baissés : rz(-80) à gauche, rz(+80) à droite. Liste : idle, marche, course, sprint, saut, accroupi, roulade, coup de poing, coup de pied, tir, recharge, dégâts, mort, conduite, escalade, interaction, danse. Vérifier par planches de rendus (Char.render(R, P, ...) avec pose_world de rig.py ; attention aux ponts de poids de skinning aux épaules/hanches en pose dynamique).
C. Export .glb à la main (JSON + binaire) : maillage skinné unique, joints nommés mixamorig:Hips etc. SANS suffixes (le modèle source a des suffixes : rig.Base.short), IBM colonne-major, atlas PNG 1536x512 + normal embarqués (A.color / A.normal), alphaMode OPAQUE, animations nommées, échelle en mètres (mesh déjà *0.01) ; relire le .glb et le rendre pour contrôle. Manifest JSON (id, genre, âge, apparence, animations).
D. Demander le moteur (three.js WebView Android, Unity ou Godot), puis intégrer.

## Limites honnêtes
Pas de Blender ni de Mixamo : vêtements et cheveux générés par code, qualité low-poly, pas de niveau artiste, pas de plis ni de textures de vêtements (couleurs unies). Le rendu de contrôle est logiciel (pas un moteur 3D) ; il ne remplace pas un test dans le moteur final.

## Session v5b (nouveau compte) — constat seulement, aucun code modifié
- sheet_back_v5.png inspectée : 10 personnages cohérents. Défauts visibles (mineurs) : bord dentelé à la jonction veste/jupe de femme_chignon (dos, taille) ; petites taches sombres aux hanches/bas du jean de homme_afro (dos) ; fille_queue : short blanc un peu plat. Rien de bloquant.
- Connu pour (B)/(C) : Char expose lt (translations locales), lr, Wr, ibm (J,4,4), mesh (pos, nrm, uv, joints, weights, idx), A.color/A.normal ; joints 34 dont _rootJoint(0) ; rig.Base.short = noms sans suffixes ; pose_world dans rig.py.
- (B) anim.py et (C) export .glb : TOUJOURS NON COMMENCÉS.

## Session v5c (A quater FAIT, B préparé) — vérifié par rendu
- A quater : cause des deux défauts du dos = l'ourlet de la VESTE descendait à y=88 alors que le bas (bassin/jupe/jambes) démarre à y=92 -> encoches/dents au raccord (femme_chignon : veste/jupe ; homme_afro : veste/jean). Corrigé dans chargen.build : `torso_loft(prof_c, 139.5, 92, 1.4, uvc)` (au lieu de 88). Revérifié en zoom dos + 3/4 : bord de taille propre sur les deux personnages. Reste une très légère marche entre hanche et haut de jambe droite en 3/4 sur homme_afro (mineur, non traité). Les autres personnages à veste (punk, chauve_costume) bénéficient de la même correction mais n'ont pas été re-rendus : à revérifier d'un coup d'œil sur la planche dos.
- Faits utiles pour (B) (mesurés, pas supposés) :
  * Char.mesh en MÈTRES (pos *0.01) ; Char.Wp et Char.lt en mètres ; Char.Wr = base.Wr (rotations de bind monde, inchangées par build()) ; Char.ibm (J,4,4) calculé comme inverse du bind monde ; Char.skin_mats(R,P) attend R (J,3,3) et P (J,3) en MONDE ; Char.render(R, P, view, size, center, scale, yaw, cy, pitch) ; zoom.zoom(c, zones, R=, P=, yaw=).
  * Taille homme ~1.73 m (y de -0.017 à 1.733), enfant ~1.05 m. Hips en bind : (0, 0.916, -0.013) pour homme_barbu.
  * 34 joints : 0 _rootJoint, 1 Hips, 2 Spine, 3 Spine1, 4 Spine2, 5 Neck, 6 Head, 7 HeadTop_End, 8-15 épaule/bras/avant-bras/main/index gauche (8 LeftShoulder, 9 LeftArm, 10 LeftForeArm, 11 LeftHand, 12-15 LeftHandIndex1-4), 16-23 idem droite (16 RightShoulder, 17 RightArm, 18 RightForeArm, 19 RightHand, 20-23 RightHandIndex1-4), 24-28 jambe gauche (24 LeftUpLeg, 25 LeftLeg, 26 LeftFoot, 27 LeftToeBase, 28 LeftToe_End), 29-33 jambe droite (29 RightUpLeg, 30 RightLeg, 31 RightFoot, 32 RightToeBase, 33 RightToe_End). Seul l'index est présent côté doigts (pas de pouce/majeur).
  * Axes de bind (monde) : colonne/torse/tête/Hips : x=+x, y=+y (identité). Bras gauche : x local = -z monde, y local = +x monde (pointe vers +x, côté gauche). Bras droit : y local = -x monde. Jambes : x local = -x, y local = -y (axe retourné, pointe vers le bas) ; pieds : y local ≈ +z (pointe vers l'avant).
  * Donc avec la règle du prompt (D_j monde, rotation locale = Wr[parent]^T @ D_j @ Wr[j]) : à D_j = I on retrouve la pose de bind (pose T). Bras baissés : D = rz(-80) gauche, rz(+80) droite.
  * rig.pose_world(Wr, Wp, parent, lt, lrot) fait la FK : lrot (J,3,3) rotations locales, lt translations locales (mettre Hips lt + offset pour le rebond). Le paramètre root_off de cette fonction est inopérant : ajouter l'offset directement à lt[1].
- tools/anim.py : TOUJOURS NON ÉCRIT. (C) export .glb : NON COMMENCÉ. (D) NON COMMENCÉ.

## Session v5d (3e compte) — contrôle seulement, aucun code modifié
- Coup d'œil punk et chauve_costume (dos + 3/4, taille) : previews/ctrl_punk_chauve_v5d.png. L'ourlet de veste (y=92) se raccorde proprement au cargo/pantalon : pas d'encoche ni de dents de scie. A quater validé aussi pour ces deux personnages. Entrejambe en U visible mais propre.
- Toujours NON COMMENCÉS : (B) tools/anim.py, (C) export .glb + manifest, (D) choix du moteur. Prochaine étape = écrire anim.py (voir « Reste à faire » et « Session v5c » pour les faits mesurés sur le rig).

## Session v6 (4e compte) — (B) et (C) FAITS, vérifiés par rendu
- tools/anim.py : 17 animations procédurales (idle, walk, run, sprint, jump, crouch, roll, punch, kick, shoot, reload, damage, death, drive, climb, interact, dance). Principe : rotation MONDE absolue A_j par os (non spécifié = hérite du parent) ; lrot_j = (A_p Wr[p])^T (A_j Wr[j]) ; paramètres plats (NAMES) interpolés par keys() ; grounding automatique (point le plus bas du maillage posé au sol, 'mesh') sauf climb ; `anim.sample(c, nom)` -> (temps, lrot, lt) à 30 fps. Boucles : idle, walk, run, sprint, drive, climb, dance.
- tools/sheet_anim.py : planches d'images clés (`python3 sheet_anim.py perso a1,a2 out.png side|front 6`). Planches : previews/anim_walk_run_punch_kick_v6.png, anim_a2.png (jump..damage), anim_a3.png (death..idle).
- tools/export_glb.py : un .glb par personnage dans export/ (3 Mo chacun, 14,8k sommets, 34 joints `mixamorig:*` sans suffixes, _rootJoint conservé, IBM colonne-major, atlas couleur + normal PNG embarqués, alphaMode OPAQUE, doubleSided, 17 animations nommées, rotations de tous les joints + translation Hips, interpolation LINEAR, mètres, +Y haut, +Z devant) + export/manifest.json (id, genre, âge, apparence, hauteur, animations, crédit CC-BY).
- tools/verify_glb.py : relit le .glb avec un parseur INDÉPENDANT (sémantique glTF : TRS -> monde -> IBM), compare au pipeline interne : écart max < 1e-6 m (walk, roll, dance, 4 personnages). Rendu : previews/glb_check_v6.png.
## Défauts connus après v6 (honnêtes)
- Animations sur place (pas de root motion), pieds non verrouillés au sol (léger glissement en marche/course). Style simple, pas de mocap.
- Aucune arme/objet : tir, recharge, conduite, interaction, escalade se jouent à vide (pas de pistolet, volant, échelle).
- Épaules : les manches (conçues pour la pose T) font une bosse arrondie quand les bras sont baissés, visible en vue de face (glb_check_v6.png). À améliorer (manche dédiée en pose bras baissés / poids).
- Pas de doigts autres que l'index, pas d'expressions, pas de LOD. Hanches/mains en pose dynamique extrême (roll, death) non inspectées en gros plan.
- Non testé dans un vrai moteur (seulement parseur maison). (D) moteur : toujours à choisir.

## Session v6b — (D) Godot : projet écrit, NON exécuté
- godot_project/ : project.godot (Godot 4.3, renderer mobile, paysage), main.tscn + scripts/main.gd (visionneuse), scripts/game_character.gd (classe GameCharacter), characters/ (10 .glb + manifest.json), README_GODOT.md. Aucun Godot dans l'environnement : le code GDScript n'a jamais été lancé, seulement relu.

## Session v6c — déplacements (root motion) AJOUTÉS
- anim.py : `sample()` renvoie maintenant n+1 images (boucles : image finale = pose initiale + déplacement total) ; lt[:,0] (_rootJoint) = déplacement. walk/run/sprint : vitesse DÉDUITE du pied d'appui (le pied qui recule le plus vite par rapport au bassin) -> avance 1,6 / 3,7 / 5,3 m/s (adulte). Autres : MOTION (saut +1 m, roulade +2,4 m, punch/kick avance puis retour, dégâts -0,3 m, mort -0,55 m, escalade +0,6 m par cycle). Marche : genou plié plus longtemps + attaque talon pour réduire le patinage à l'atterrissage.
- export_glb.py : canal translation sur _rootJoint (+ Hips) ; manifest : root_motion par animation. verify_glb.py : écart < 1e-6 m toujours.
- slide_check.py : mesure de glissement. Cheville en appui : ~0 m/s (planté) ; course adulte 0 % d'images en contact avec glissement, sprint max 0,64 m/s ; marche : 18-25 % d'images « contact » > 0,5 m/s = surtout décollage sur la pointe (pivot normal) mais un peu de patinage à la pose du talon possible. Rendu : previews/root_motion_walk_run_v6c.png (caméra fixe).
- Godot : game_character.gd (root_motion_track sur Skeleton3D:_rootJoint, consume_root_motion()), main.gd (sol damier, caméra qui suit, bouton recentrer). NON exécuté.

## Session v6d — corrections de la liste de défauts v6c
1. **byteStride** : `export_glb.py` écrit désormais un `byteStride` explicite (8/12/16) sur toutes les vues d'attributs de sommets ; relu par `verify_glb.py` (écart < 1e-6 m). À reconfirmer dans Godot (non testé).
2. **Patinage au talon** : marche réécrite (`cyc_walk2`, appui à angle de hanche quasi linéaire, genou redressé avant la pose). Mesure `slide_check.py` : contacts > 0,5 m/s 25 % -> 6 % ; vitesse max en contact 4,1 -> 0,66 m/s (homme_barbu ; 0,62 femme_jupe ; 0 enfant). Course/sprint inchangés. Résiduel : < 0,7 m/s à la pose du talon (pas de vrai IK).
3. **CharacterBody3D** : `player.gd`, collisions, gravité, contrôles clavier + tactile (NON exécuté).
4. **Armes/objets/véhicule/interaction** : pistolet, batte, mannequins, échelle, voiture, ramasser, interagir (primitives, NON exécuté).
5. **Android** : `export_presets.cfg` + réglages projet ; SDK/JDK/keystore et APK restent à faire sur ta machine.
6. **Dossier racine** : renommé `projet_personnages_crime_game_v6d` (cohérent avec l'archive).
7. **Doublons** : `export/` supprimé ; GLB uniquement dans `godot_project/characters/`.
8. **Temporaires** : `__pycache__/` et previews en double (sheet_front/back.png) supprimés ; `.gitignore` ajouté.
9. **Qualité procédurale** : poids des manches (transition épaule->bras plus précoce, `SLEEVE_C1/W1` dans body_parts.py) : épaulette horizontale réduite, bosse encore visible bras baissés. Poses extrêmes (roulade, mort) NON retravaillées. Style toujours procédural, sans plis ni mocap.

## Session v6e — points « à régler manuellement » : ce qui est fait / reste
Fait (valeurs MESURÉES sur le rig, écrites dans manifest.json par export_glb.py `gameplay_anchors`) :
1. **Arme** : `weapon_grip` (base de rotation + longueur de main) calculé sur la pose « shoot » (visée) -> canon vers +Z, dessus vers +Y, paume à mi-main. `Weapon.apply_grip(entry)` l'applique (pistolet ; la batte garde grip_offset). Vérifié NUMÉRIQUEMENT (canon (0,0,1), dessus (0,1,0)) ; pas vérifié visuellement dans Godot.
2. **Assise voiture** : pose « drive » corrigée (mains resserrées sur le volant, bras plus bas). `drive_seat` = {butt_y, hips_z} mesuré par personnage ; `Player.enter_vehicle` décale le modèle pour poser les fesses sur l'ancre. Voiture : habitacle ouvert (pare-brise), siège et volant ajoutés. Rendu de contrôle depuis le .glb relu : pose assise cohérente. Les coordonnées SEAT_X/Y/Z de vehicle.gd restent à valider dans Godot.
3. **Échelle** : StaticBody3D + une CollisionShape3D par montant et par barreau (le joueur grimpe en déplacement direct, donc sans blocage).
4. .glb et manifest ré-exportés (10 personnages), verify_glb : écart < 1e-6 m.
Reste : patinage du talon (< 0,7 m/s sur ~2 images de marche, pas d'IK), réglage visuel fin dans Godot (arme, siège), test visuel de `use_root_motion = true`. Rien de ceci n'a été exécuté dans Godot.

## Session v6f — C.A.D.I.S WARS : écran principal
- Jeu renommé « C.A.D.I.S WARS » (project.godot, preset Android, package com.example.cadiswars).
- `main_menu.tscn` + `scripts/main_menu.gd` = scène de départ : Histoire, Mission secrète, Online, Personnage, Magasins, Paramètres -> popup « Encore en développement ». Décor 3D : les personnages fournis (idle, 1,75 m), un nouveau toutes les 6 s. Bouton discret « Niveau de test (dev) » -> game.tscn (à retirer en version finale).
- Règle de design : les personnages fournis sont la référence visuelle (échelle, style, proportions) pour tout monde 3D, véhicules, armes, caméra, interactions. Pas de personnages génériques de remplacement.
- Non exécuté dans Godot.

## Session v8 — retour à Godot comme base du jeu
- Godot 4.3 est de nouveau la base (godot_project/). Le viewer Android natif (Java/OpenGL, CodeAssist) reste dans l'archive séparée cadis_wars_android_v7.zip : outil de test uniquement, pas la base du jeu.
- Ajout de .github/workflows/export-apk.yml : export APK debug via GitHub Actions (image barichello/godot-ci:4.3). NON TESTÉ.
- Contenu identique à v6f côté Godot (menu C.A.D.I.S WARS, niveau de test, 10 persos, manifest avec drive_seat / weapon_grip). Rien exécuté dans Godot.
