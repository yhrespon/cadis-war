# C.A.D.I.S WARS v13 — rapport d’analyse, corrections et validation

**Date des tests : 3 octobre 2026**
**Moteur cible : Godot 4.3.stable.official.77dcf97d8**
**Environnement : Linux x86_64, Sandbox Manus ; tests graphiques avec Xvfb, Mesa llvmpipe/OpenGL logiciel.**
**Périmètre :** archive reçue `cadis_wars_v12.zip`, code Godot, données, ressources importées, scènes de démarrage, modifications v13, mesure d’AnimationTrees. Aucun téléphone ou tablette Android n’a été connecté.

## 1. Conclusion exécutive

Le projet **se charge et démarre sous Godot 4.3**, version déclarée par le dépôt. Les vérifications statiques, données, import du contenu GLB, compilation/analyse des scripts par l’éditeur et les smoke-tests des scènes menu, visionneuse et jeu passent. Les dix personnages du manifeste ont également passé les assertions runtime de setup, squelette, main droite, filtre d’animation et textures.

Trois défauts de source ont été corrigés pendant l’audit :

1. Le dessin initial de la mini-carte pouvait construire un `Rect2` de taille négative.
2. Le mannequin de prévisualisation du menu montrait son dos à la caméra.
3. Le filtre du OneShot était limité aux chemins animés dans `idle` (9 articulations seulement) ; surtout, la sous-machine `shoot/reload` n’avait pas de sortie vers `End`, et le OneShot restait actif même après la fin du clip. Le masque couvre désormais tout le sous-arbre `Spine` (22 os) et les clips d’action quittent automatiquement leur sous-machine.

**Limites importantes :** les séquences interactives, le tir/calibrage du réticule, les armes en main, les missions, l’IA/collisions des PNJ, root motion prolongé et les parcours Android n’ont pas été validés intégralement. L’export local de l’APK est bloqué par l’absence d’Android SDK et de chemin Java SDK valide. Le premier run GitHub a passé contrôles statiques/import mais a échoué sur le message du renderer dummy ; le filtre a été corrigé et un second run est à obtenir.

## 2. Contrôles automatisés exécutés

| Contrôle | Résultat constaté |
|---|---|
| `python3 tools/static_check.py` | Code 0 ; 0 problème sur 52 fichiers. |
| `python3 tools/check_data.py` | Code 0 ; 0 erreur, 25 missions atteignables. |
| `python3 -m py_compile tools/*.py` | Code 0. |
| Import Godot 4.3 (`--headless --path godot_project --import`) | Code 0 ; ressources GLB importées. Dix scènes modèles accessibles dans le cache importé. |
| Godot 4.3 éditeur (`--headless --editor --path godot_project --quit`) | Code 0 ; aucune erreur de parse/script/chargement dans le journal final. |
| Smoke-test `res://main_menu.tscn` | Code 0 ; aucune erreur de script ou chargement détectée. |
| Smoke-test `res://main.tscn` (visionneuse) | Code 0 ; aucune erreur de script ou chargement détectée. |
| Smoke-test `res://game.tscn` | Code 0 ; aucune erreur de script ou chargement détectée ; capture graphique produite. |
| Assertions personnage/animation | 10/10 personnages passés ; assertions détaillées ci-dessous. |

### Notes sur les messages d’import et de headless

- L’import GLB a signalé `Ignoring face with non-finite normal in LOD generation.` L’import s’est terminé avec le code 0. Aucun `.glb` ni `manifest.json` n’a été retouché.
- Une première exécution de scène avec le renderer `--headless`/dummy a émis des erreurs de rendu du type `mesh_get_surface_count` (paramètre de mesh nul). Ce renderer ne fournit pas le même contexte que le rendu OpenGL. Les trois scènes ont donc été relancées avec Xvfb et `--rendering-driver opengl3 --rendering-method gl_compatibility` ; aucune erreur de script/chargement n’a été détectée sur ces exécutions. L’avertissement Xvfb concernant V-Sync non pris en charge n’est pas une erreur de jeu.
- La capture du jeu prouve le démarrage graphique (ville, personnage, HUD/minimap) ; elle n’atteste pas que les actions tactiles/manette ou les missions ont été parcourues.

## 3. Corrections faites dans le code source

### 3.1 Mini-carte — `godot_project/scripts/ui/minimap.gd`

**Défaut :** au premier `_draw()`, la taille disponible pouvait être nulle ou inférieure à l’épaisseur des bordures ; la construction de rectangles intérieurs pouvait alors recevoir une largeur/hauteur négative. Cela se manifestait comme `Rect2 size is negative`.

**Correction :** le dessin attend désormais une taille exploitable (garde à 16 px), calcule le rectangle intérieur une fois, et réutilise cette valeur pour le contrôle du point. Cela évite la géométrie négative avant la mise en page initiale.

**Validation :** les smoke-tests OpenGL finals ne montrent plus de `Rect2 size is negative`. Pas d’analyse manuelle de toutes les résolutions/ratios Android.

### 3.2 Orientation de l’aperçu — `godot_project/scripts/main_menu.gd`

**Défaut :** l’aperçu était tourné de 160° alors que les modèles regardent +Z et que la caméra du menu se trouve côté +Z ; la capture montrait le dos du personnage.

**Correction :** yaw d’aperçu à 0°.

**Validation visuelle :**

- Avant : [capture du menu avant correction](evidence/menu_avant_correction.png).
- Après : [capture du menu après correction](evidence/menu_apres_correction.png).

Le résultat montre le visage. Le test porte sur l’aperçu du menu, pas sur l’orientation de toutes les armes en jeu.

### 3.3 Filtre du haut du corps et fin des actions — `godot_project/scripts/game_character.gd`

**Constat initial du runtime Godot 4.3 :** pour `homme_barbu`, le squelette importé possède 34 os. Les clips importés comportent 18 pistes chacun ; neuf chemins de pistes uniques sont effectivement animés dans le sous-arbre haut du corps (Spine, Neck/Head, bras/avant-bras). Le calcul initial à partir du seul clip `idle` renvoyait donc 9 chemins, inférieur au critère attendu `>20`. Les fichiers GLB n’ont pas été artificiellement modifiés pour gonfler leur nombre de pistes.

**Correction du masque :** `_upper_track_paths()` parcourt maintenant le squelette et ajoute les chemins de **tous les os descendants de `Spine`**, y compris mains/doigts. Pour chacun des dix modèles présents, cela donne 22 chemins de masque. Il s’agit de chemins filtrables du squelette, pas de clés d’animation ajoutées : les os absents des clips n’ont pas de mouvement inventé.

**Défaut d’exécution découvert :** une assertion du test a montré `upper_active=true` longtemps après `shoot`. La StateMachine d’action n’avait aucune transition automatique vers son nœud de fin. Une `AnimationNodeOneShot` dont l’entrée reste sur une StateMachine non terminée ne libérait donc pas le blend comme prévu.

**Correction de durée :** transitions `ADVANCE_MODE_AUTO` + `SWITCH_MODE_AT_END` vers le nœud terminal réservé `"End"` pour `shoot` et `reload`. `"End"` est utilisé comme nom de nœud compatible avec le binaire 4.3 exécuté ; la constante `AnimationNodeStateMachine.END_NODE` n’existe pas dans cette version de l’API et a été rejetée par le parseur lors du premier essai.

**Assertions runtime après correction :**

- dix identifiants du manifeste : `setup=true` ; chacun a 34 os, `RightHand=true`, `upper_paths=22`, `textures=true` ;
- personnage de référence : attachement `RightHand` non nul ; `build_tree=true` ; OneShot actif après 12 pas physiques puis inactif après 162 pas physiques ; sortie `AUDIT FINAL=PASS`.

Le clip `shoot` a été testé au niveau de son état et de sa terminaison. La pose de tir, le rechargement déclenché par l’interface et toutes les transitions d’animation n’ont pas été évalués image par image. La documentation de l’API utilisée pour les transitions est celle de [Godot 4.3 — AnimationNodeOneShot](https://docs.godotengine.org/en/4.3/classes/class_animationnodeoneshot.html), [AnimationNodeStateMachine](https://docs.godotengine.org/en/4.3/classes/class_animationnodestatemachine.html) et [AnimationNodeStateMachineTransition](https://docs.godotengine.org/en/4.3/classes/class_animationnodestatemachinetransition.html).

### 3.4 Export et workflow v13

- Version du preset Android mise à **version code 13 / version name 0.13.0**.
- Le workflow n’ignore plus les codes de retour de l’import (`|| true` supprimé), et la vérification regroupe import et démarrage en cherchant les erreurs de parse, chargement et déclaration/type.
- Injection des champs de keystore release via Python plutôt que `sed` avec délimiteur `@` ; un `@` dans le mot de passe ne casse donc plus le remplacement. Les secrets n’ont pas été fournis ou imprimés par cette modification.
- Run GitHub Actions `37125564277` sur le commit de remplacement : statique et import des ressources réussis ; l’étape de démarrage a échoué uniquement sur `ERROR: Parameter "m" is null.` émis par le renderer dummy sans affichage, pas sur une erreur GDScript. L’export APK a donc été sauté.
- Le filtre CI a été corrigé pour distinguer ces erreurs renderer des erreurs de parse/chargement. Le rerun après ce correctif reste à valider avant de déclarer un APK compilé.

## 4. Assertion des dix modèles

Les dix entrées de `godot_project/characters/manifest.json` ont été chargées successivement sous Godot 4.3. Pour chacune, le test a contrôlé :

1. `GameCharacter.setup(entry)` retourne vrai.
2. Le squelette se retrouve dans l’instance et contient 34 os.
3. Un os `*RightHand` est présent.
4. `_upper_track_paths()` renvoie 22 chemins.
5. Au moins un `BaseMaterial3D` du personnage expose textures `albedo` et `normal`.

Les dix identifiants réussis : `homme_barbu`, `femme_jupe`, `punk`, `garcon_enfant`, `ado_casquette`, `fille_queue`, `femme_chignon`, `homme_afro`, `ado_fille_longs`, `chauve_costume`.

L’attachement BoneAttachment a été créé sur le personnage de référence. **Cela vérifie le nom et l’existence de l’os, pas le grip visuel d’un pistolet/SMG/fusil.**

## 5. Mesure de performance — 30 AnimationTrees

Mesure effectuée sous Godot 4.3, sandbox Linux, Xvfb, Mesa llvmpipe : 30 instances `GameCharacter`, setup réussi pour chacune, chacune avec un AnimationTree actif. Moniteurs Godot pendant la fenêtre d’échantillonnage actif :

| Moniteur | Moyenne | Pic |
|---|---:|---:|
| `TIME_PROCESS` | 6,462 ms | 7,543 ms |
| `TIME_PHYSICS_PROCESS` | 2,853 ms | 3,550 ms |

Le moniteur du processus physique total reste sous le seuil mentionné de 4 ms pendant cette fenêtre ; aucune nouvelle règle LOD n’a donc été ajoutée sur la base d’un résultat inférieur au seuil. La mesure est une mesure desktop logicielle et inclut le moteur ; elle n’isole pas le coût des arbres et **ne prédit pas** les performances d’un téléphone. L’instance a une LOD sommeil existante : `NPCActor` désactive visibilité, collision et AnimationTree à LOD 3 (>95 m), la gestion étant assurée par `NPCManager`. La validation sur appareil reste nécessaire.

## 6. Tests fonctionnels restant à exécuter

**État : non validé par cet audit.** Les tests ci-dessous nécessitent une interaction gameplay prolongée ou un appareil cible ; les afficher ici ne signifie pas qu’ils ont passé.

| Domaine | Statut | Ce qu’il reste à faire |
|---|---|---|
| Contrôles de menu (nouvelle partie, paramètres, etc.) | [À CORRIGER — NON TESTÉ] | Parcourir chaque entrée depuis la vraie scène du menu. |
| Missions et objectifs | [À CORRIGER — NON TESTÉ] | Démarrer/terminer une mission et vérifier les objectifs et sauvegardes. |
| Mission secrète | [À CORRIGER — NON TESTÉ] | Activer le déclencheur et vérifier récompense/cooldown/absence de doublon. |
| Armes et alignement tir/réticule avec caméra décalée | [À CORRIGER — NON TESTÉ] | Tirer sur un repère à 10 m et comparer impact/centre du réticule pour chaque arme. |
| Root motion | [À CORRIGER — NON TESTÉ] | Maintenir locomotion pendant 10 s ; vérifier capsule, position, pente et arrêt. |
| PNJ civils/ennemis/alliés | [À CORRIGER — NON TESTÉ] | Vérifier apparition, collision, distances, fuite/dégâts, morts et absence d’empilement. |
| Placement sur secteur nouvellement chargé | [À CORRIGER — NON TESTÉ] | Reproduire les spawns après chargement et tester l’absence de chevauchement bâtiments. |
| Véhicules et voyage entre villes | [À CORRIGER — NON TESTÉ] | Conduire, entrer/sortir, changer de ville et vérifier le chargement de secteur. |
| Pause, reprise et retour menu | [À CORRIGER — NON TESTÉ] | Ouvrir pause depuis jeu et voiture ; vérifier contrôles et absence d’inputs bloqués. |
| Paramètres, équipement et recoloration visibles | [À CORRIGER — NON TESTÉ] | Vérifier le résultat visuel du changement de palette/équipement. |
| Touches mobiles, zones sûres, encoche et ratio d’écran | [BLOQUÉ — APPAREIL REQUIS] | Tester sur Android réel, dimensions et orientation cible. |
| Export/installation APK Android | [BLOQUÉ — SDK LOCAL ABSENT / CI EN RELANCE] | L’export local a échoué : voir section 7 ; un premier run CI s’est arrêté avant export sur le faux positif renderer, rerun en attente. |
| Profilage mobile et LOD réel | [BLOQUÉ — APPAREIL REQUIS] | Rejouer la scène et profiler le CPU/GPU sur l’appareil cible. |

## 7. Export APK local — blocage

L’export Android debug a été tenté après installation des templates Godot 4.3 et création d’une clé de debug jetable. Godot n’a pas exporté d’APK, faute de chemins d’outils configurés :

```text
A valid Java SDK path is required in Editor Settings (Android > Java SDK Path).
A valid Android SDK path is required in Editor Settings (Android > Android SDK Path).
```

Résultat : **pas d’APK local**. L’environnement n’a ni Android SDK configuré ni JDK 17 configuré. Le mot de passe/keystore jetable n’est pas inclus dans les livrables. La version Android dans le preset est 13/0.13.0. Ne pas installer l’APK sur appareil avant d’avoir obtenu un export vérifié et testé.

## 8. Fichiers livrables

- Projet source complet : `cadis_wars_v13.zip` (à la racine du livrable).
- Résumé de progression : `README_PROGRESSION.md`.
- Présent document.
- Captures de validation :
  - `docs/evidence/menu_avant_correction.png`
  - `docs/evidence/menu_apres_correction.png`
  - `docs/evidence/game_start.png`

Les captures sont prises dans l’environnement desktop avec OpenGL logiciel ; elles ne constituent pas des captures d’un téléphone.
