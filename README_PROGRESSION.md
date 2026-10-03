# C.A.D.I.S WARS — suivi de progression v13

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
