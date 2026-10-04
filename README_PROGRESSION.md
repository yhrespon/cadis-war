# v17 — feux, trafic secret et corrections (testé sous Godot 4.3 le 2026-10-04)

**Validation exécutée ici :** Godot `4.3.stable.mono.official.77dcf97d8`, SDK .NET `6.0.428`, import/runtime sous OpenGL logiciel (Xvfb/llvmpipe),
`tools/static_check.py` (0 problème, 59 fichiers), `tools/check_data.py` (0 problème, 25 missions atteignables), build C# témoin (0 avertissement, 0 erreur).
Le test `godot_project/tests/traffic_integration.tscn` passe **17/17 assertions** : phases des feux, carrefours visibles, trafic secret qui apparaît et roule,
arrêt réel au rouge, puis masque fantôme déclenché après 7 s de blocage et restauré après 3 s. Le test C# témoin est également exécuté dans Godot (`C# smoke test OK`).
Limites : pas d’export Android, pas de test sur téléphone, et pas de parcours exhaustif de toutes les missions. Le lancement de l’éditeur en batch émet aussi un
diagnostic interne `EditorSettings` ; le runtime du jeu testé n’a signalé aucune erreur de script. Voir `docs/VALIDATION_TRAFIC_V17.md`.

## 1. Poignard (Double_Dagger_Stab)
- Le FBX n'est PAS dans l'archive (et il était exporté sur le mannequin gris « Beta », squelette différent) : l'animation `stab` est donc **construite par code**
  (`tools/add_stab_anim.py`, visée os par os, 2 coups) et ajoutée aux 4 GLB `mx_*.glb` + manifest. Ce n'est pas l'animation Mixamo d'origine.
- Pour la vraie : ré-exportez Double_Dagger_Stab depuis Mixamo sur Remy « With Skin » (squelette `mixamorig`), donnez-moi le FBX, je le retargete.
- Arme `dagger` (data/weapons/dagger.tres, item `w_dagger` 220 $, modèle 3D dans weapon.gd). Joueur : 2 touches par animation ; PNJ : même animation.
  Les anciens modèles « legacy » n'ont pas `stab` -> repli sur `punch` (GameCharacter.melee_anim_for).

## 2. Ambiance (EnvironmentController)
- Cycle jour/nuit (24 h de jeu = 12 min) + météo : ensoleillé, nuageux, pluie, orage (éclairs + tonnerre), brouillard. Ciel, soleil/lune, brouillard, pluie (particules
  qui suivent la caméra), chaussée mouillée, fenêtres/vitrines/lampadaires allumés la nuit, phares (seulement les voitures à < 45 m). Heure + météo sauvegardées.
- HUD : heure + météo sous la minimap. Le site secret reste de nuit, sans météo. Pluie aussi sur l'écran d'accueil (1 fois sur 3). **Aucun personnage sur l'accueil.**

## 3. Ville (CityBuilder réécrit)
- Échelle des personnages : étage 3,4 m, porte 1,1 x 2,3 m (cadre, marche, lampe), trottoirs 2,1 m, chaussée 6,8 m. Styles : immeuble, tour (antenne), maison à toit
  à deux pentes, entrepôt (porte roulante). Balcons, vitrines + auvents, parapets, climatiseurs, abribus supprimés (gênaient les piétons).
- Marquages (ligne jaune, bords blancs, passages piétons). Mobilier : arbres, bornes, boîtes aux lettres, panneaux, lampadaires.
- Décor visuel d'un bloc fusionné en 2 maillages (Main / Detail masqué à > 90 m) : moins d'appels de dessin sur mobile.
- Voitures garées contre la bordure (le trafic roule sur la voie). Camions plus garés ; hélico/avion rares.

## 4. Monde « GTA » (CrimeManager + factions)
- Factions : civil, police, gang (bandits), dealer (trafiquants), boss (méchants de mission, comportement inchangé). Tous passent par la MÊME chaîne que le joueur
  (GameCharacter, armes, AnimationTree, take_damage, véhicules).
- Recherche 0-5 étoiles : un crime (tir, agression, meurtre, vol de voiture, policier touché) compte s'il est VU d'un policier ou d'un civil (qui « appelle » après 2,5-5 s).
  Étoiles clignotantes = police sans contact visuel. La police fonce vers la dernière position connue, renforts à pied (armes selon niveau) + voitures de patrouille
  (sirène, gyrophares) qui se garent près du joueur et débarquent 2 agents. Mort = fin de recherche + amende.
- Gangs (groupes de 2-4, couleurs) et trafiquants (2 + camionnette) : neutres tant qu'on ne les provoque pas (coup, tir à ~22 m, ou rester > 3 s dans leur zone) ; ennemis de la police.
- Piétons : traversent les rues aux coins ; trafic automatique (TrafficDriver : voies de droite, intersections, freinage, sous la pluie plus lent). Vol de voiture : le conducteur s'enfuit.
- Minimap : police bleue, gangs/trafiquants orange.

## À SAVOIR / PAS FAIT
- Les feux tricolores, l’arrêt au rouge, le dégagement fantôme (blocage > 7 s, collision désactivée 3 s) et le trafic modéré du site secret sont maintenant implémentés et testés. Les intérieurs ne sont pas faits.
- Valeurs à régler : tools -> constantes en tête de crime_manager.gd, npc_spawner.gd (DENSITY_*), traffic_driver.gd (LANE, vitesses).
- Si un symptôme sort : copiez l'erreur exacte de la console Godot, je corrige.

# C.A.D.I.S WARS — v16 (personnages humains Mixamo)

**[NON TESTÉ DANS GODOT] [NON TESTÉ SUR APPAREIL]** : aucun Godot, Blender ni réseau dans l'environnement de travail. Exécutés : `tools/fbx2glb.py` (convertisseur écrit pour l'occasion), `tools/verify_new_glb.py` (structure + rendu logiciel de poses), `static_check.py` (0 problème, 53 fichiers), `check_data.py` (0 problème, 25 missions). Aucun import Godot, aucune compilation GDScript, aucun APK : la CI GitHub Actions devra confirmer.

| Étape | Statut | Détail |
|---|---|---|
| 1. FBX -> GLB | [FAIT, NON TESTÉ DANS GODOT] | 4 humains : `mx_remy` (H 1,80 m), `mx_brute` (H 1,92 m, hache ignorée), `mx_eve` (F 1,68 m), `mx_ch21` (F 1,80 m ; ce n'est pas un homme). 22 000–24 400 triangles chacun (avant : 24 600–59 200 ; réduction par effondrement d'arêtes, sommets de couture/bord conservés), textures ≤ 1024 px (albedo JPEG, normales JPEG q86, alpha PNG), 2,2–6,0 Mo/GLB. Tailles réelles imposées (les FBX Mixamo sont en unités maison ≈ 2x). |
| 2. 17 animations | [FAIT, NON TESTÉ DANS GODOT] | Reprises de `homme_barbu.glb`, retargetées en local (delta par rapport à la pose de liaison), translations Hips/_rootJoint mises à l'échelle du bassin. Rendu logiciel vérifié (course, tir, assis en voiture). Doigts : main détendue constante ajoutée à chaque animation (flexion calculée dans le repère de l'os). `_rootJoint` est joint du skin, comme dans les GLB d'origine. |
| 3. Manifest | [FAIT] | `height_m`, durées/loop copiés, `root_motion` mis à l'échelle ; `weapon_grip` : `hand_len_m` = distance main->index1 mesurée, plancher 0,115 m (Eve/Ch21 mesurent ~0,09 m : armes à 80 % au lieu de 65 %), `basis_cols` repris de la référence (mêmes axes d'os Mixamo) ; `drive_seat` = valeurs de référence x rapport de bassin. **Orientation des armes et assise en véhicule jamais vues dans Godot : à valider.** |
| 4. Tenue | [FAIT, LIMITÉ] | Pas d'atlas à pastilles : `outfit_tiles` vide, `apply_outfit` bascule sur une teinte par matériau (`tint_materials`). Recolorable : Remy (haut, bas, cheveux), Brute (pantalon, cheveux), Ch21 (chemise, pantalon, cheveux). **Eve : un seul matériau, aucune teinte possible** ; Brute n'a pas de haut. Les articles de boutique `top_*`/`bottom_*`/`hair_*` restent achetables mais sans effet visible sur ces cas. |
| 5. Civils / PNJ | [FAIT, NON TESTÉ] | 2 hommes + 2 femmes, **tous adultes : plus d'ados ni d'enfants** (aucun modèle fourni). Taille aléatoire 0,94–1,06 par PNJ (légère glisse de pieds possible, ≤ 6 %). Voix : genre lu dans le manifest. Coût AnimationTree par PNJ non mesuré ; 22 k triangles x 20–34 civils est lourd pour un téléphone modeste (voir risques). |
| 6. Écran Personnage / crédits | [FAIT PARTIELLEMENT] | Liste avec libellés (`label`) ; **pas d'aperçu 3D** (non fait). Crédits : mention Mixamo/Adobe ajoutée ; mention CC-BY « Fuse personnage » conservée (les animations en dérivent et les anciens modèles restent). |
| 7. Anciens personnages | [FAIT] | Les 10 restent dans le manifest (`legacy: true`, GLB intacts). Bascule : `"use_legacy": true` dans `characters/manifest.json`. |
| 8. Sauvegardes | [FAIT, NON TESTÉ] | Un ancien `character_id` est remplacé par un modèle actif du même genre (`GameManager.resolve_character_id`). |

**Risques connus** : (1) 22 k triangles x ~30 civils ≈ 650 k triangles skinnés : prévoir de baisser le budget (`build_mixamo_characters.py`, paramètre 22000) ou un LOD si l'appareil rame ; (2) la réduction de maillage a pu déformer légèrement des vêtements fins (non inspectée de près) ; (3) l'import Godot peut régler différemment alpha/normales (cheveux en `MASK`) ; (4) les écrans de ville n'ont pas été modifiés : « adapter les environnements » n'a pas été fait, faute de précision sur ce qui était attendu.

Régénérer : `python3 tools/build_mixamo_characters.py <dossier des .fbx>` (Remy.fbx, Brute.fbx, Eve_By_J_Gonzales.fbx, Ch21_nonPBR.fbx). `Double_Dagger_Stab.fbx` (animation sur mannequin Beta) n'a pas été intégré.

# C.A.D.I.S WARS — v15c (écran principal)

Changements **[NON TESTÉ DANS GODOT : aucun Godot dans l'environnement ; static_check.py = 0 problème ; la vidéo a été décodée avec ffmpeg, pas avec Godot]** :
- Fond animé `godot_project/art/menu_bg.ogv` (Theora, 1280x720, 24 i/s, boucle parfaite de 10 s, ~1 Mo) + affiche `art/menu_bg.png`, générés par `tools/gen_menu_video.py` (relancer le script pour les régénérer).
- Le titre « C.A.D.I.S WARS » est incrusté dans l'image (or + reflet qui passe) ; l'ancien titre en texte est supprimé du menu.
- `main_menu.gd` : `VideoStreamPlayer` (loop, recadrage « cover » aligné en haut), affiche dessous, halo sombre derrière les boutons ; boutons **centrés** sous le titre (44 px, texte centré), version/argent en petit au bas de l'écran ; plus de personnage ni de décor 3D.
- Constante `TITLE_BOTTOM` (245) = bas du titre dans l'image : à ajuster si le titre est modifié.
- Non fait : évolution visuelle des personnages (plus humains) et adaptation des civils.

# C.A.D.I.S WARS — suivi de progression v15

**v15 = code modifié SANS compilation ni test** (aucun Godot/SDK/réseau dans l'environnement de travail). Seuls `static_check.py` et `check_data.py` (0 problème) ont tourné. Tout ce qui suit est **[NON TESTÉ SUR APPAREIL]** ; la première compilation (GitHub Actions) peut révéler des erreurs de script à corriger.

Ajouts v15 : contrôles tactiles réduits (TIR+COUP fusionnés en « attack » selon l'arme en main ; VISER en bascule, visible avec arme à feu seulement ; RECH. idem ; boutons PIED/BAISSE/SOIN retirés du tactile) ; relâche différé des taps (jump/roll rates possibles sinon) ; symbole flottant touchable sur les véhicules (plus de texte) ; 4 véhicules (moto, camion, hélicoptère, avion ; vol arcade : MONTER/DESC.) ; voix des PNJ (bulle 3D + synthèse vocale du téléphone, `voice_manager.gd`) ; soin : bouton « Activer » dans la boutique (en jeu) ; menu : skyline nocturne, mentions du bas retirées (attribution CC-BY conservée dans Crédits) ; v14 : sons synthétisés, vibrations ≥45 ms, mêlée élargie, 20–34 civils/ville.

Non fait / limites : animations d'« activités » des PNJ (téléphone, assis…) inexistantes ; voix = synthèse du téléphone, pas des voix enregistrées ; coup de pied accessible seulement clavier/manette ; cause exacte des bugs saut/viser/roule non reproduite.


**v14 = corrections de code SANS compilation ni test : aucun Godot, aucun SDK Android ni accès réseau dans l'environnement de travail.** Seuls `static_check.py` (0 problème) et `check_data.py` (0 problème, 25 missions) ont été exécutés ; les fichiers WAV ont été vérifiés (lecture/durées). Tout le reste est **[NON TESTÉ SUR APPAREIL]**. Pas d'APK produit ici : utiliser le workflow GitHub Actions `export-apk`.

| Sujet | Cause constatée | Correction v14 |
|---|---|---|
| Son absent | Aucun fichier dans `audio/` ; en plus `play_music`/`play_ui` n'étaient appelés nulle part | 21 sons/musiques synthétisés (`tools/gen_audio.py`), musique menu/ville lancée, son sur tous les boutons `UIKit`, bouclage musique |
| Vibrations | Durées de 12–35 ms, souvent ignorées par les moteurs Android (cause probable, non confirmée) | Durée minimale 45 ms ; la permission VIBRATE était déjà présente |
| Coups sans effet | Cause exacte non reproduite (pas de Godot). Sans son/vibration, aucun retour ; cône de touche étroit (~66°) | Cône élargi (~84°), portée +0,4 m, chiffre de dégâts + secousse de caméra à chaque coup |
| Peu de monde | 6–14 civils par ville, apparition à ≥22 m seulement | 20–34 civils, apparition dès 10 m, 4 par cycle de 0,5 s (coût CPU mobile non mesuré) |
| Version | — | code 14 / 0.14.0 |

Non corrigé : écran d'accueil (design), qualité des personnages, orientation des armes, root motion, précision de tir, missions, performances sur téléphone.


**Référence exécutée : Godot 4.3.stable.official.77dcf97d8, Linux x86_64.** Tests graphiques sous Xvfb avec OpenGL logiciel Mesa/llvmpipe ; aucun téléphone Android n’était connecté. Les résultats distinguent les commandes réellement exécutées des interactions qui restent à faire.

## Résumé des contrôles réellement exécutés

- `python3 tools/static_check.py` : **0 problème, 52 fichiers**.
- `python3 tools/check_data.py` : **0 problème ; 25 missions atteignables**.
- Import Godot 4.3 : **code retour 0 ; 10/10 scènes GLB importées** sous `godot_project/.godot/imported/`.
- `godot --headless --editor --path godot_project --quit` : **code retour 0**, aucune erreur de parse/chargement dans le journal.
- Menu, visionneuse et jeu démarrés chacun sous Godot 4.3/OpenGL logiciel : **code retour 0, zéro erreur de script/chargement**.
- Assertions runtime sur les **10 personnages** : setup réussi, 34 os chacun, `RightHand` trouvé, 22 chemins de filtre du haut du corps, matériau StandardMaterial3D avec textures d’albedo et de normale.
- Pour `homme_barbu`, `attach_to_bone(..., "RightHand")` retourne un `BoneAttachment3D` non nul ; le OneShot `shoot` est actif après 12 pas physiques et inactif après 162 pas physiques (sortie automatique vers `End`).
- Mesure desktop de 30 AnimationTrees actifs : moniteur Godot `TIME_PHYSICS_PROCESS` **2,853 ms moyen / 3,550 ms maximum** lors de la fenêtre mesurée. Ce chiffre est une mesure sandbox logicielle, pas une mesure de téléphone ; le seuil de 4 ms n’a pas été dépassé dans cette mesure.
- Export Android local tenté mais **bloqué** : aucun chemin Java SDK valide ni Android SDK. Aucun APK produit localement.

Voir le rapport exhaustif [docs/COMPTE_RENDU_ANALYSE_v13.md](docs/COMPTE_RENDU_ANALYSE_v13.md) et les captures dans `docs/evidence/`.

## Corrections v13

| Fichier | Modification | Preuve/résultat |
|---|---|---|
| `godot_project/scripts/ui/minimap.gd` | Ignore le premier dessin tant que le contrôle mesure au plus 16 px ; crée une seule zone intérieure valide et la réutilise pour `has_point`. | Le lancement initial headless produisait des `Rect2 size is negative`; aucun de ces messages dans les smoke-tests OpenGL après correction. |
| `godot_project/scripts/main_menu.gd` | Orientation du personnage de prévisualisation ramenée de 160° à 0° (modèles orientés +Z, caméra située côté +Z). | Captures avant/après : le dos était visible avant, le visage après. |
| `godot_project/scripts/game_character.gd` | Le masque du OneShot est construit sur les os du sous-arbre `Spine` au lieu de dépendre des seules pistes du clip `idle` ; 22 chemins pour le squelette de référence. Ajout de transitions automatiques vers le nœud réservé `End` après `shoot`/`reload`. | Assertions runtime sur les 10 modèles ; le OneShot se désactive après le clip fini. |
| `godot_project/export_presets.cfg` | Version Android passée à code 13 / nom 0.13.0. | Le preset est cohérent avec l’archive v13 ; l’APK reste à exporter. |
| `.github/workflows/export-apk.yml` | Ne masque plus les échecs d’import ; le contrôle de logs repère les erreurs de chargement, parse et types ; remplacement des valeurs du keystore release par Python (n’échoue pas sur `@` comme le `sed` antérieur). | Modification incluse ; l’exécution GitHub Actions reste à vérifier. |

> Les clips des GLB de référence n’animent que neuf articulations du haut du corps. Le filtre contient 22 chemins d’os du sous-arbre (mains/doigts inclus) ; cela n’ajoute pas de clés aux animations et ne modifie aucun `.glb` ni `manifest.json`.

## Statut par phase

| Phase | Statut | Note |
|---|---|---|
| 0 — contrôles statiques, import, chargement GDScript | [FAIT] | Exécuté avec Godot 4.3 exact ; détails et avertissement d’import dans le rapport. |
| 1 — installation/éditeur | [FAIT] | Binaire 4.3 et modèles d’export installés dans l’environnement de test ; SDK Android et JDK 17 absents. |
| 2a — squelette, main droite, chemins du filtre | [FAIT] | 34 os ; nom observé `mixamorig_RightHand` ; attachement non nul ; masque de 22 chemins. |
| 2b — matériaux | [FAIT] | Pour les 10 modèles : StandardMaterial3D, textures albedo et normal présentes. |
| 2c — orientation visuelle des armes | [À CORRIGER — NON TESTÉ] | Aucun test visuel pistolet/SMG/fusil en main ; le repère des GLB n’a pas été modifié. |
| 2d — root motion pendant 10 s | [À CORRIGER — NON TESTÉ] | Le test continu en jeu n’a pas été fait. |
| 2e — précision du tir/réticule avec décalage caméra | [À CORRIGER — NON TESTÉ] | Pas de mannequin à 10 m ni de série de tirs mesurée. |
| 2f — OneShot shoot/reload | [FAIT, TEST LIMITÉ] | `shoot` testé, actif puis inactif après fin ; toutes les autres transitions de gameplay ne sont pas parcourues. |
| 2g — placement PNJ dans des secteurs fraîchement chargés | [À CORRIGER — NON TESTÉ] | Le code se charge ; collision/placement physique non validés. |
| 3 — parcours du protocole et mission secrète | [À CORRIGER — PARTIEL] | Menu et démarrage direct du jeu vérifiés ; interactions et scénarios de mission non déroulés. |
| 4 — performance desktop | [FAIT, LIMITÉ] | 30 arbres actifs mesurés en sandbox ; pas d’appareil Android. Le LOD sommeil existant de `NPCActor` (>95 m) reste en place. |
| 5 — APK Android | [FAIT — DEBUG CI] | APK version 13 / 0.13.0 exporté par GitHub Actions et vérifié comme archive ; l’export local reste bloqué par les SDK absents, et l’APK n’a pas été installé sur appareil. |
| 6 — GitHub Actions | [FAIT] | Run 37125744583 réussi : contrôles statiques, import, démarrage, export debug et upload d’artefact. Le premier run a révélé un faux positif du renderer dummy, corrigé avant le rerun. |

## À ne pas confondre

- `--headless` utilise le renderer **dummy** ; dans la première exécution Godot 4.3 il a émis des erreurs renderer `mesh_get_surface_count` (pas des erreurs GDScript). Les scènes ont ensuite été relancées sous OpenGL logiciel/Xvfb ; les trois smoke-tests ciblés sont sortis sans erreur de script/chargement.
- L’import GLB 4.3 a émis un avertissement `Ignoring face with non-finite normal in LOD generation.` L’import a terminé avec code 0. Les `.glb` et `manifest.json` n’ont pas été modifiés, conformément à la consigne.
- Les captures de menu et de jeu prouvent un rendu desktop de démarrage, pas la validation de toutes les mécaniques ni du comportement Android.
