# HISTORIQUE v5 → v11 (archivé en v12 : ancien README_PROGRESSION.md, texte inchangé hors 3 corrections signalées « v12 »)
> État courant et statuts : voir ../README_PROGRESSION.md. Les sections « canon +Z » (v6e) décrivent le repère MONDE, pas celui de l'arme.

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
1. **Arme** : `weapon_grip` (base de rotation + longueur de main) calculé sur la pose « shoot » (visée) -> dans le MONDE (pose de visée) le canon pointe vers +Z et le dessus vers +Y ; dans le repère de L'ARME : canon = +Y, dessus = +Z (convention unique, voir weapon.gd). Paume à mi-main. `Weapon.apply_grip(entry)` l'applique (pistolet ; la batte garde grip_offset). Vérifié NUMÉRIQUEMENT (canon (0,0,1), dessus (0,1,0)) ; pas vérifié visuellement dans Godot.
2. **Assise voiture** : pose « drive » corrigée (mains resserrées sur le volant, bras plus bas). `drive_seat` = {butt_y, hips_z} mesuré par personnage ; `Player.enter_vehicle` décale le modèle pour poser les fesses sur l'ancre. Voiture : habitacle ouvert (pare-brise), siège et volant ajoutés. Rendu de contrôle depuis le .glb relu : pose assise cohérente. Les coordonnées SEAT_X/Y/Z de vehicle.gd restent à valider dans Godot.
3. **Échelle** : StaticBody3D + une CollisionShape3D par montant et par barreau (le joueur grimpe en déplacement direct, donc sans blocage).
4. .glb et manifest ré-exportés (10 personnages), verify_glb : écart < 1e-6 m.
Reste : patinage du talon (< 0,7 m/s sur ~2 images de marche, pas d'IK), réglage visuel fin dans Godot (arme, siège), test visuel de `use_root_motion = true`. Rien de ceci n'a été exécuté dans Godot.

## Session v6f — C.A.D.I.S WARS : écran principal
- Jeu renommé « C.A.D.I.S WARS » (project.godot, preset Android, package com.cadis.wars (corrigé en v12 ; l'ancien « com.example.cadiswars » n'a jamais été dans le preset)).
- `main_menu.tscn` + `scripts/main_menu.gd` = scène de départ : Histoire, Mission secrète, Online, Personnage, Magasins, Paramètres -> popup « Encore en développement ». Décor 3D : les personnages fournis (idle, 1,75 m), un nouveau toutes les 6 s. Bouton discret « Niveau de test (dev) » -> game.tscn (à retirer en version finale).
- Règle de design : les personnages fournis sont la référence visuelle (échelle, style, proportions) pour tout monde 3D, véhicules, armes, caméra, interactions. Pas de personnages génériques de remplacement.
- Non exécuté dans Godot.

---
# v9 — Session de reprise (ÉTAT EXACT, honnête)  [aucun GDScript exécuté : pas de Godot dans l'environnement]

## Audit (phases 0 / 0 bis) [FAIT]
- Archive reçue = v6f (pas de .github, pas de viewer Android). Rig [VÉRIFIÉ] : 10 persos, 34 joints mixamorig, poids normalisés (somme 1,0000, 4 influences), 17 animations, boucles fermées (idle/walk/run/sprint/drive/climb/dance), écart glb vs pipeline < 1e-6 m.
- Vitesses root motion adulte : marche 1,14 / course 3,70 / sprint 5,26 m/s (README_GODOT annonçait 1,6 : texte faux, le code lit le manifest).
- Roulade : à la clé 13/33 le perso est tête en bas en l'air (plus une galipette qu'une roulade au sol) -> à retoucher dans tools/anim.py si gênant. Mort : lisible.
- Décision : rig exploitable tel quel (pas de régénération). Haut/bas du corps = OneShot filtré sur Spine dans un AnimationTree. IK de pieds repoussée.

## Écrit dans cette session (30 .gd, analyse statique seulement : tabulations + parenthèses équilibrées) [NON TESTÉ]
- project.godot : 11 autoloads, couches physiques nommées, retour Android géré (quit_on_go_back=false).
- scripts/defs : WeaponDef, ItemDef, VehicleDef, MissionDef, CityDef. tools/gen_data.py génère data/**/*.tres + registry.json
  (4 armes, 22 objets, 3 véhicules, 4 villes, 20 missions : chaîne Port-Alpha 8 missions + contrat + 4 secondaires, puis 4 missions par autre ville).
- Autoloads FAITS : SettingsManager (persistant, FPS 30/45/60/90 selon l'écran, qualité dynamique), AudioManager (bus séparés, fichier absent = silence),
  GameManager, InventoryManager (achat->inventaire->équipement), WeaponManager, VehicleManager, NPCManager (LOD d'IA par distance + bruit),
  WorldManager (une ville à la fois, secteurs = blocs streamés), SaveManager (tmp + validation + .bak, 4 emplacements), UIManager (fondu, toasts, retour Android).
- tools/add_outfit_tiles.py : manifest.outfit_tiles (haut/bas/cheveux = pastilles d'atlas, vérifiées sur des sommets réels). Vêtements = recoloration (shader), PAS de nouvelle géométrie.
- scripts/world : CityBuilder (étage 3,2 m, porte 1,0x2,1 m, trottoir 2,1 m, couvertures), ShopPoint.
- GameCharacter (AnimationTree : loco BlendSpace1D, états base, saut/échelle TimeScale, tir/recharge en couche haute, tenue recolorable, repli AnimationPlayer),
  Weapon (modèles pistolet/SMG/fusil/batte, axes manifest : canon +Y, dessus +Z), PlayerCombat (hitscan, dispersion, recul, ADS, aide à la visée, mêlée, headshot x2),
  Player (déplacement, caméra, roulade, accroupi, échelle, véhicule, santé/armure, mort/respawn), Vehicle (VehicleDef, dégâts, piétons), GameInput (clavier+manette), TouchControls (réglages, contexte véhicule).

## CASSÉ / MANQUANT (le projet NE démarre PAS en l'état)
1. scripts/autoload/mission_manager.gd ABSENT mais déclaré en autoload -> erreur au lancement.
2. Anciens fichiers incompatibles avec le nouveau Player : scripts/game_world.gd, scripts/main_menu.gd, scenes game/main_menu/main (ancienne API : Player.equip, Weapon.make(String)...).
3. Pas encore écrits : EnemyController, CivilianController, MissionManager + exécution des objectifs (kill, collect, goto, interact, survive, protect, escort, chase, stealth_goto, vehicle_goto),
   HUD + minimap réelle + réticule + chiffres de dégâts, menu principal stylé (titre, boutons parallélogrammes, logo doré, personnage décor, pages Histoire/Mission secrète/Online verrouillé/Personnage/Magasins/Paramètres/Crédits),
   ShopUI, SettingsUI, PauseMenu, game.tscn (scène jeu : ville, joueur, HUD, respawn, autosave), test_level.tscn (niveau dev), secret_mission.tscn (infiltration chronométrée),
   spawn des voitures garées/civils par secteur (WorldManager._load_sector), .github/workflows/export-apk.yml, export_presets.cfg fiabilisé (keystore, icônes, VIBRATE), écran Crédits CC-BY.
4. Limites assumées : pas d'intérieurs, pas de navmesh (IA par steering + raycasts), pas de trafic roulant (voitures garées pilotables), pas de pose de visée continue,
   pas d'animations montée/descente véhicule, accroupi-marche = anim walk.
5. Protocole de test à exécuter dans Godot 4.3 : ouvrir godot_project/, laisser l'import des .glb, lire la console (erreurs de parse GDScript attendues : premier passage de correction),
   vérifier : noms d'os après import (mixamorig: vs mixamorig_), chemins de filtre de l'OneShot, API AnimationTree 4.3 (request/active du OneShot, sync BlendSpace1D), arme dans la main, siège voiture.

---
# v10 — Reprise, étapes 1 et 2 (aucun Godot dans l'environnement : TOUT est [NON TESTÉ SUR APPAREIL])

## Étape 1 — projet démarrable  [À CORRIGER : à valider dans Godot]
- ÉCRIT : scripts/autoload/mission_manager.gd (autoload manquant), scripts/world/mission_item.gd.
  Objectifs jouables seuls : goto, collect, interact (marqueur provisoire, pas de vrai PNJ), vehicle_goto, survive (minuteur).
  kill / chase / escort / protect / stealth_goto / vagues de survive : passent par MissionManager.spawner (spawn_enemies, spawn_friendly) et
  report_kill(tag) / report_alert(). Sans spawner -> objectif marqué [BLOQUÉ] (toast + erreur console), jamais un faux succès.
- MIGRÉ : scripts/main_menu.gd (Histoire -> Continuer / Nouvelle partie via GameManager.start_story, niveau de test -> game.tscn en mode "test"; retour Android).
  Les autres rubriques restent « Encore en développement ».
- SUPPRIMÉ : scripts/game_world.gd (ancienne API). main.tscn + main.gd = visionneuse de personnages, indépendante de Player/Weapon, CONSERVÉE.
- Contrôle statique (script Python) : tabulations, parenthèses, appels Manager.méthode -> 0 problème. Ce n'est PAS une compilation GDScript.

## Étape 2 — monde / scène de jeu  [À CORRIGER : à valider dans Godot]
- ÉCRIT : scripts/game.gd + game.tscn (ville, joueur à Port-Alpha:spawn, TouchControls, HUD PROVISOIRE, respawn à l'hôpital après 3 s, autosave 60 s,
  restauration position/yaw/santé depuis pending_load, retour Android -> sauvegarde + menu), scripts/world/mission_board.gd (panneau temporaire : accepte la
  prochaine mission disponible), WorldManager._spawn_parked_cars (1-2 voitures pilotables par secteur, déterministes, protégées au déchargement si conduites).
- MANQUE : civils par secteur (CivilianController), restauration de la voiture conduite / voitures possédées, ShopUI (le comptoir affiche un toast),
  position exacte du spawn dans le bloc « plaza » (peut tomber sur un prop : à vérifier).

## Étape 3 — HUD réel + minimap  [À CORRIGER : à valider dans Godot]
- ÉCRIT : scripts/ui/hud.gd (CanvasLayer calque 5, sous les boutons tactiles), scripts/ui/minimap.gd ; game.gd les utilise (HUD provisoire retiré).
- HUD : vie, armure, argent, arme + chargeur/réserve, « RECHARGEMENT », soins, objectif + distance + chrono, titre de mission, zone (3 s), réticule (armes à feu, à pied),
  marqueur de touche (rouge = tête), chiffres de dégâts (signal Player.hud_damage_number), flash de dégâts + pulsation sous 30 % de vie, vitesse en véhicule, écran de mort.
- Minimap : blocs réels (WorldManager.block_rects_near), véhicules (groupe vehicle), ennemis (groupe enemy, vide tant qu'EnemyController n'existe pas), objets de mission, objectif (flèche au bord si hors portée), nord, orientée caméra, 15 Hz.
- À VÉRIFIER sur appareil : lisibilité des tailles de texte, encoche/zones sûres (non gérées), réticule vs h_offset de la caméra (tir depuis le centre exact ?), coût du redessin sur mobile bas de gamme.
- tools/static_check.py : contrôle statique réutilisable (0 problème sur 35 fichiers ; ce n'est pas une compilation).

## Reste (ordre inchangé) : 4 EnemyController/CivilianController (débloque les objectifs kill...), 5 panneau de missions,
6 menu premium + SettingsUI + ShopUI + Crédits, 7 pause, 8 export Android/CI, 9 villes 2-4, 10 protocole de test complet.

## Protocole de test minimal (à exécuter dans Godot 4.3)
1. Ouvrir godot_project/, laisser l'import des .glb, ouvrir la console de sortie : noter TOUTE erreur de parse (attendues au 1er passage).
2. F5 : menu -> Histoire -> Nouvelle partie. Attendu : ville chargée, joueur visible 1,75 m, caméra OK, HUD « PV / Armure / arme / $ ».
3. Marcher jusqu'au panneau jaune (3 m du spawn), E : toast + objectif « Parlez à ... » ; aller à la colonne bleue (poi contact_a), E : dialogue, mission suivante possible.
4. Monter dans une voiture garée (E), conduire, descendre. 5. Mourir (tomber / dégâts) : respawn à l'hôpital après 3 s.
6. Retour Android / Échap : menu ; Histoire -> Continuer : position et argent restaurés.

---
# v10 — Étape 4 : EnemyController / CivilianController / allié  [ÉCRIT, NON TESTÉ : aucun Godot dans cet environnement]

## Écrit (scripts/ai/, 5 fichiers) + 1 modification (game.gd)
- npc_actor.gd (NPCActor) : base commune (capsule, GameCharacter + AnimationTree comme le joueur, steering + 3 raycasts d'évitement,
  détection de blocage, dégâts/mort, LOD d'IA : ai_lod / on_lod_changed / hear_noise attendus par NPCManager).
- enemy_controller.gd : IDLE / PATROL / ALERT / COMBAT / SEARCH / FLEE ; vue (portée, cône, ligne de vue), ouïe, tir hitscan à précision dégressive,
  rechargement, mêlée (batte), infiltration (stealth -> MissionManager.report_alert), poursuite (chase), fuite (objectif chase : flee_to), report_kill(tag) à la mort,
  butin 8-40 $ si tué par le joueur. Groupe « enemy » (minimap, aide à la visée, mêlée du joueur).
- civilian_controller.gd : marche sur l'anneau de trottoir de son bloc, pauses, fuite (tirs à < 30 m, coups, véhicule qui le touche).
- ally_controller.gd : suit le joueur (escort / protect), groupe « friendly » (les ennemis le visent), disparaît 1,2 s après sa mort (MissionManager le détecte via is_instance_valid).
- npc_spawner.gd : MissionManager.spawner (spawn_enemies / spawn_friendly) + civils ambiants (max = CityDef.civilians x densité, apparition 22-90 m, retrait > 120 m).
- game.gd : crée le NPCSpawner après load_city, NPCManager.clear() au début et à la sortie.
- static_check.py : 0 problème / 40 fichiers (ce n'est PAS une compilation GDScript).

## Débloqué côté missions
kill, chase, stealth_goto, survive (vagues), protect, escort : plus de [BLOQUÉ] tant que le spawner existe.

## Limites assumées / risques à vérifier en jeu
- Pas de navmesh : évitement local seulement ; cul-de-sac / intérieurs = blocages possibles (le PNJ change de côté au bout de 0,6 s).
- Placement : test de capsule libre puis repli sur le trottoir ; un secteur tout juste chargé peut ne pas répondre aux requêtes physiques.
- Hauteur du sol supposée à y = 0 (spawn à y = 0,1 comme le joueur et les voitures).
- Équilibrage non testé : DMG_SCALE = 0,45, précision 15-70 %, PV ennemi 60 x difficulté, portées par arme (enemy_controller.gd).
- Civils : ne traversent pas les rues, aucune réaction police (pas de système de recherche), tuer un civil n'a pas de conséquence.
- Allié : suit toujours le joueur (pas de mode « tenir la position »), ne monte pas en voiture.
- Ennemis de mission non plafonnés (un objectif « tuer N » doit rester atteignable) ; coût CPU des AnimationTree par PNJ à mesurer sur mobile.
- Appels API Godot 4.3 à confirmer : AnimationTree (tree.active), PhysicsShapeQueryParameters3D, get_viewport().world_3d.direct_space_state.

## Reste (ordre inchangé) : 5 panneau de missions, 6 menu premium + SettingsUI + ShopUI + Crédits, 7 pause, 8 export Android/CI, 9 villes 2-4, 10 protocole de test complet.
## Test à ajouter au protocole : mission pa_02_nettoyage (kill), pa_05_poursuite (chase), pa_06_defense (protect), pa_04_escorte ; vérifier minimap (points rouges), mort -> disparition, civils sur trottoir.

---
# v10 — Étape 5 : panneau de missions  [ÉCRIT, NON TESTÉ : aucun Godot dans cet environnement]

## Écrit
- scripts/ui/mission_panel.gd (MissionPanel, CanvasLayer calque 20, PROCESS_MODE_ALWAYS) : liste à gauche (Histoire / Contrats / Secondaires, missions
  verrouillées grisées + prérequis manquants), détail à droite (donneur, type, briefing, objectifs, récompense × reward_mult, objet offert, ville débloquée,
  limite de temps, échec si mort), actions Accepter / Abandonner (confirmation en 2 temps) / Fermer. Pause du jeu pendant l'affichage (restaurée à la fermeture),
  relâche des commandes tactiles à l'ouverture, bouton retour Android = fermeture (UIManager.push_back). Une seule instance à la fois.
- scripts/world/mission_board.gd : interact() ouvre MissionPanel (ne choisit plus la mission à la place du joueur).
- static_check.py : 0 problème / 41 fichiers (ce n'est PAS une compilation GDScript).

## À vérifier dans Godot
- Lisibilité / taille des boutons (64-78 px en base 1280x720), défilement tactile des deux ScrollContainer, focus manette.
- `grab_focus.call_deferred()`, `static var` (Godot 4.1+), `scene.get("touch")` dans game.tscn.
- La pause n'empêche pas l'ouverture : le Player est en pause, mais l'action "interact" restée enfoncée ne doit pas rouvrir le panneau à la fermeture.

## Incohérence connue (non corrigée)
- Le contrat pa_c1_contrat dit « répétable » dans son briefing, mais MissionManager.is_available() exclut toute mission terminée : il ne l'est pas.
  À trancher : soit retirer le mot, soit gérer une catégorie « contract » répétable dans MissionManager.

## Reste : 6 menu premium + SettingsUI + ShopUI + Crédits, 7 pause, 8 export Android/CI, 9 villes 2-4, 10 protocole de test complet.
## Test à ajouter : ouvrir le panneau (E près du panneau jaune), accepter pa_01, vérifier HUD ; rouvrir -> « En cours » + Abandonner ; retour Android ferme.

---
# v10 — Étape 6 (partie 1) : boutique, réglages, crédits  [ÉCRIT, NON TESTÉ : aucun Godot dans cet environnement]

## Écrit (scripts/ui/)
- ui_kit.gd (UIKit : styles, labels, boutons, colonne défilante) et base_panel.gd (BasePanel : fond, cadre, en-tête, Fermer, pause SEULEMENT en partie,
  retour Android, un seul écran à la fois). mission_panel.gd (étape 5) n'a pas été refactoré sur cette base.
- shop_ui.gd (ShopUI) : onglets Armes / Munitions / Soins / Hauts / Bas / Cheveux ; achat réel InventoryManager.buy() (message d'erreur réel sinon),
  Équiper (arme) / Porter-Retirer (vêtement, porté automatiquement à l'achat) ; sauvegarde après chaque action (autosave en partie, save_profile au menu).
- settings_ui.gd (SettingsUI) : Audio, Contrôles, Graphismes, Jeu, générés depuis une table ; écriture au relâchement des curseurs ; qualité -> page reconstruite.
- credits_ui.gd (CreditsUI) : mention CC-BY-4.0 du modèle de personnage reprise mot pour mot de source_model/license.txt.

## Branché / corrigé
- game.gd open_shop() -> ShopUI. main_menu.gd : Magasins, Paramètres, Crédits ouvrent les vrais écrans (7 entrées, boutons 54 px). Mission secrète / Online / Personnage : toujours « en développement ».
- BUG corrigé : aucun noeud n'était dans le groupe "sun" -> SettingsManager.apply_to_scene() n'agissait jamais sur le soleil (ombres, distance). game.gd l'ajoute.
- BUG corrigé : SettingsManager.set_value("graphics","quality") réécrivait fps/résolution/ombres sans les appliquer. Il appelle maintenant apply_all().
- static_check.py : 0 problème / 46 fichiers (ce n'est PAS une compilation GDScript).

## Risques / à vérifier dans Godot
- Achat depuis le menu sans sauvegarde préexistante : save_profile() crée un « autosave » sans position ; vérifier que « Continuer » puis game.gd (pending_load sans clé "player") se comportent bien.
- OptionButton / CheckButton / HSlider avec le thème par défaut : taille tactile à juger sur appareil ; popup d'OptionButton au-dessus d'un CanvasLayer (layer 20).
- 7 boutons du menu dans 720 px de haut : à vérifier visuellement.
- Boutique : pas d'aperçu 3D du vêtement (pastille de couleur seulement) ; pas de vente ; achat de munitions sans arme correspondante autorisé.

## Reste : 6 (suite) restyle « premium » du menu (logo, boutons parallélogrammes, pages Histoire / Mission secrète / Personnage), 7 pause, 8 export Android/CI, 9 villes 2-4, 10 protocole de test complet.

---
# v10 — Étape 6 (suite) + étape 7 : menu premium, choix du personnage, pause  [ÉCRIT, NON TESTÉ : aucun Godot dans cet environnement]

## Écrit / modifié
- scripts/ui/pause_menu.gd (PauseMenu, base BasePanel) : Reprendre, mission en cours + Abandonner (2 temps), Paramètres (revient à la pause à la fermeture),
  Sauvegarder (emplacement 1, mode histoire), Quitter vers le menu (game.quit_to_menu() : autosave puis menu).
- game.gd : la touche/bouton « pause » n'était gérée PAR PERSONNE (action définie dans game_input.gd et dessinée sur l'écran tactile, jamais lue) -> _process()
  ouvre PauseMenu. Le bouton retour Android (on_back) ouvre la pause au lieu de quitter directement au menu.
- base_panel.gd : `on_closed` (Callable) et libération immédiate de l'instance active à la fermeture (permet d'enchaîner deux écrans).
- scripts/ui/character_ui.gd (CharacterUI) : choix parmi les 10 personnages du manifest (genre, âge, taille) -> GameManager.character_id (lu par Player),
  sauvegardé seulement s'il existe déjà une sauvegarde. Pas d'aperçu 3D dans l'écran : le décor du menu se met à jour à la fermeture.
- main_menu.gd : restyle (titre en deux lignes avec contour, voile dégradé, boutons à coins diagonaux + liseré doré, argent affiché, popup Histoire stylé),
  « Personnage » = écran réel, bouton « Niveau de test (dev) » visible seulement si OS.is_debug_build().
- static_check.py : 0 problème / 48 fichiers (ce n'est PAS une compilation GDScript).

## Limites honnêtes
- « Boutons parallélogrammes » = coins diagonaux (StyleBoxFlat ne sait pas pencher) ; pas de logo image ni de police personnalisée (police par défaut Godot).
- Le menu n'a jamais été vu à l'écran : rendu, tailles et chevauchement avec le personnage 3D à valider sur appareil.
- Menu pause : le temps de jeu est figé (tree.paused) ; les timers de mission le sont aussi (à confirmer).
- Mission secrète et Online : toujours « en développement » (secret_mission.tscn n'existe pas).
- Le changement de personnage ne se fait qu'au menu, pas en partie.

## Reste : 8 export Android/CI (.github/workflows/export-apk.yml, export_presets.cfg, keystore, icônes), 9 villes 2-4, 10 protocole de test complet (+ mission secrète si voulue).
## Test à ajouter : touche P / bouton II / retour Android -> pause ; Paramètres depuis la pause -> retour à la pause ; Quitter -> menu puis Continuer ; Personnage -> choix -> décor mis à jour.

---
# v11 — Étapes 8, 9, 10 + Mission secrète  [ÉCRIT, NON TESTÉ : aucun Godot dans cet environnement]

## Constat de départ (analyse de la v10)
- **Aucun mécanisme de voyage entre villes n'existait** : les villes 2-4 étaient définies et leurs missions cohérentes, mais injouables (missions exigent `city == current_city`).
- Le contrat `pa_c1_contrat` se disait « répétable » mais ne l'était pas (déjà noté en v10).
- `GameManager.start_secret_mission()` visait une scène inexistante ; « Online » affichait « Encore en développement ».
- La sauvegarde hors partie (achat au menu) recopiait la position d'une ancienne sauvegarde même si la ville avait changé.

## Étape 9 — villes 2-4  [À CORRIGER : à valider dans Godot]
- TravelPoint (scripts/world/travel_point.gd, poteau bleu « VOYAGE » sur la place `travel`) -> TravelUI (scripts/ui/travel_ui.gd) -> GameManager.travel_to(id) :
  refusé si mission active ou ville verrouillée ; sauvegarde du profil puis rechargement de game.tscn dans la ville choisie.
- save_manager.gd : la position/les véhicules d'une ancienne sauvegarde ne sont réutilisés que si la ville est la même.
- **tools/check_data.py (EXÉCUTÉ, 0 problème)** : POI dans les limites et sur des blocs distincts, POI des missions présents dans leur ville, prérequis existants,
  simulation de progression : les 25 missions sont atteignables et les 4 villes déblocables (pa_08 -> Nova, nd_04 -> Ironworks, iw_04 -> Sunset Bay).
  C'est une vérification de DONNÉES ; la génération 3D des villes 2-4 (CityBuilder) n'a jamais été vue.

## Étape 5 (reste) — missions
- Contrats répétables : MissionManager.is_available() accepte un contrat déjà terminé ; MissionPanel le garde dans la liste (récompense à chaque fois).
- Progression partielle d'étape sauvegardée (`progress` + `timers` dans to_dict) : kill/chase (ne respawn que les restants), collect `items` (marqueurs restants),
  collect `pois` (on retire les premiers de la liste : l'ordre de ramassage n'est pas sauvegardé -> approximation), survive/protect (minuteur ; vagues déjà écoulées non rejouées en rafale).
  Non restauré : position des ennemis vivants (ils réapparaissent à leur poste), escort (le PNJ repart de son point de départ).
- Vrai PNJ pour « interact » : **NON FAIT** (colonne lumineuse conservée) -> [À CORRIGER].

## Mission secrète  [À CORRIGER : à valider dans Godot]
- Menu > Mission secrète > Commencer -> game.tscn en mode « secret » sur data/cities/secret_site.tres (3x3 blocs, aucun civil).
- SecretMission (scripts/world/secret_mission.gd) utilise MissionManager.start_custom : objectif, chrono 180 s, flèche et minimap RÉELS ; 6 gardes EnemyController en mode stealth
  (vue 16 m, cône 70°, ligne de vue, ouïe), alerte = MissionManager.alert_raised ; objet à voler (dossier) puis sortie ; mort/abandon/temps = échec (pas de respawn).
- Score = 1000 + 10 x secondes restantes + 1500 si 0 alerte - 250 x alertes ; meilleur score dans GameManager.secret_best_score (sauvegardé via save_profile).
  Écran de résultat ResultUI (Rejouer / Menu). Rien n'est ajouté à la progression d'histoire (mission `category = "secret"`, non sauvegardée, ville d'histoire restaurée après load_city).
- Limite : un garde qui repère le joueur déclenche un vrai combat (pas de « retour au calme »).

## Online
- Entrée de menu verrouillée : « Multijoueur – Bientôt disponible » (aucune connexion simulée).

## Restaurations (v10 : manquantes)
- game.gd `_restore_vehicles` : voitures possédées (`parked_vehicles`) et voiture conduite (le joueur y remonte) ; les épaves ne sont pas restaurées ; la voiture générée par le secteur au même endroit est retirée (anti-doublon).
  Limite : une voiture déplacée laisse sa « jumelle » déterministe à l'emplacement d'origine du secteur.
- Civils par secteur : couverts autrement (NPCSpawner gère les civils ambiants sur les trottoirs des secteurs chargés) -> `WorldManager._load_sector` n'a pas besoin d'en créer.

## Étape 8 — export Android / CI  [NON TESTÉ]
- export_presets.cfg : permission VIBRATE activée, icônes (godot_project/icons/, générées par script, provisoires), `com.cadis.wars`, version 0.11.0 (0.12.0 en v12), sortie `build/cadis_wars.apk`.
- .github/workflows/export-apk.yml (YAML validé syntaxiquement, jamais exécuté) ; instructions exactes : EXPORT_ANDROID.md.

## Étape 10 — tests
- TEST_PROTOCOL.md : phase 0 (chargement) + parcours complet en 20 lignes + cas de la Mission secrète + points propres à l'appareil.
- **Aucun test de jeu n'a pu être exécuté.** Contrôles statiques : static_check.py 0 problème / 52 fichiers ; check_data.py 0 problème.

## Statut par phase
| Phase | Statut |
|---|---|
| 0 Chargement dans Godot | [BLOQUÉ] pas de Godot ici : à faire en premier |
| 4 IA ennemis/civils/allié | [À CORRIGER] écrit, non testé |
| 5 Missions (panneau, contrats, reprise partielle) | [À CORRIGER] écrit, non testé ; PNJ « interact » non fait |
| 6 Menu premium, Mission secrète, Online verrouillé, Personnage, Magasins, Paramètres, Crédits | [À CORRIGER] écrit, non vu à l'écran |
| 7 Pause | [À CORRIGER] écrit, non testé |
| 8 Export / CI | [À CORRIGER] écrit, non exécuté |
| 9 Villes 2-4 + voyage | [À CORRIGER] données vérifiées par script ; 3D et voyage non testés |
| 10 Tests | [BLOQUÉ] protocole écrit, non exécuté |

## Limites inchangées
Pas d'intérieurs, pas de navmesh, pas de trafic roulant, pas de système de recherche (police), encoche/zones sûres non gérées, police par défaut Godot, pas de logo image.
