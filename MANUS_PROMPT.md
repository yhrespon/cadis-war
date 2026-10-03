Tu es développeur senior Godot 4.3 / GDScript / Android. Réponds en français. Sois factuel : ne déclare « OK » que ce que tu as réellement exécuté ; sinon [NON TESTÉ]. Statut par ligne : [FAIT] / [À CORRIGER] / [BLOQUÉ].

CONTEXTE
Projet « C.A.D.I.S WARS » : jeu d'action 3D Android (Godot 4.3, renderer Mobile, paysage, GDScript). Archive : cadis_wars_v12.zip -> dossier cadis_wars_v12/, jeu dans godot_project/. Le code a été écrit et relu SANS JAMAIS ÊTRE LANCÉ dans Godot (aucun import, aucun test, aucun APK). Les seuls contrôles faits sont statiques (python3 tools/static_check.py, tools/check_data.py : ce n'est pas une compilation GDScript).
Lis d'abord : README_PROGRESSION.md, README_GODOT.md, TEST_PROTOCOL.md, EXPORT_ANDROID.md.
Règles : les personnages godot_project/characters/*.glb + manifest.json sont la référence visuelle (adulte 1,75 m, enfant 1,05 m). Pas de fausse implémentation : chaque élément visible a INPUT -> GAMEPLAY -> ÉTAT -> UI -> SAVE. Corrige à la source (pas de contournement qui masque l'erreur). Ne modifie ni les .glb ni manifest.json (générés par tools/export_glb.py).

ÉTAPE 1 — Installer et importer
  1. Télécharger Godot 4.3-stable (Linux x86_64, build standard) + modèles d'export 4.3-stable (.tpz). Installer JDK 17 et Android SDK (platform-tools, platforms;android-34, build-tools;34.0.0, cmdline-tools) ; renseigner export/android/android_sdk_path et java_sdk_path dans ~/.config/godot/editor_settings-4.tres.
  2. cd cadis_wars_v12 && python3 tools/static_check.py && python3 tools/check_data.py   (attendu : 0 problème)
  3. godot --headless --path godot_project --import 2>&1 | tee import.log ; puis godot --headless --path godot_project --quit 2>&1 | tee load.log
  4. Corriger UNE par UNE toutes les occurrences de « SCRIPT ERROR », « Parse Error », « Failed to load », « Could not parse global class », « Identifier not declared », « Cannot infer the type ». Après chaque lot : relancer 3. et les deux scripts Python.
  Critère : import.log et load.log sans aucune de ces chaînes ; les 10 .glb importés (godot_project/.godot/imported/*.scn présents).

ÉTAPE 2 — Vérifications d'API et de convention à trancher PAR L'EXÉCUTION (rapporter la valeur observée)
  a. Noms d'os après import : afficher get_bone_name() de Skeleton3D pour homme_barbu (attendu : « mixamorig_RightHand » ou « mixamorig:RightHand »). Vérifier que GameCharacter.attach_to_bone(…, "RightHand") renvoie un BoneAttachment3D non nul et que _upper_track_paths() renvoie > 20 chemins (sinon le tir/rechargement haut du corps ne marchera pas).
  b. Matériau importé : mi.get_active_material(0) du mesh doit être un StandardMaterial3D avec albedo_texture ET normal_texture non nuls. Sinon corriger GameCharacter.apply_outfit.
  c. Arme : convention du repère de l'arme = canon +Y, dessus +Z (weapon.gd, tools/export_glb.py gameplay_anchors, manifest weapon_grip.basis_cols). Lancer la visionneuse (main.tscn) ou une scène de test, équiper pistolet/SMG/fusil, jouer « shoot » : le canon doit pointer vers l'avant du personnage, la crosse dans la paume. Si faux, corriger Weapon.apply_grip (UNE seule convention, mettre à jour weapon.gd + README_GODOT.md), jamais les .glb.
  d. Root motion : en jeu (Player, AnimationTree actif), marcher 10 s en ligne droite : le modèle ne doit PAS dériver ni « sauter en arrière » par rapport à la capsule. (GameCharacter.build_tree fixe tree.root_motion_track = player.root_motion_track ; vérifier que c'est suffisant.)
  e. Réticule : avec cam.h_offset ≠ 0, le tir part du centre exact de l'écran (PlayerCombat.shoot utilise project_ray_origin/normal). Placer un mannequin (TargetDummy) pile sous le réticule à 10 m : toucher à chaque tir sans dispersion (spread_deg = 0 en test).
  f. AnimationTree : transitions loco/jump/roll/crouch/climb/drive ; OneShot « upper » (parameters/upper/request = 1) : tirer en marchant -> jambes continuent ; upper_active() repasse à false.
  g. NPCSpawner._is_free (intersect_shape) : vérifier qu'il ne place pas de PNJ dans les bâtiments juste après le chargement d'un secteur (les corps statiques peuvent ne pas être encore dans le serveur physique ; si oui, attendre une frame physique avant la requête).

ÉTAPE 3 — Dérouler TEST_PROTOCOL.md ligne par ligne (phase 0 puis les 25 lignes du parcours + Mission secrète). Pour chaque ligne : [FAIT]/[À CORRIGER]/[BLOQUÉ] + sortie console + correctif (fichier, raison). Capturer des captures d'écran (xvfb + --rendering-driver opengl3 si pas de GPU ; sinon indiquer [BLOQUÉ] pour le rendu).

ÉTAPE 4 — Performance (au minimum en mesure de scène sur desktop, idéalement sur appareil)
  Mesurer FPS/temps de frame avec 30 PNJ actifs (chacun a un AnimationTree) ; si > 4 ms CPU pour les arbres, proposer et implémenter un LOD (désactiver l'arbre au-delà de N m : NPCActor a déjà un mode « sleep »). Rapporter les chiffres.

ÉTAPE 5 — APK
  1. Générer un keystore de debug (commande dans EXPORT_ANDROID.md), renseigner GODOT_ANDROID_KEYSTORE_DEBUG_PATH/USER/PASSWORD.
  2. cd godot_project && mkdir -p ../build/android && godot --headless --export-debug "Android" ../build/android/cadis_wars-debug.apk
  3. Vérifier : aapt dump badging cadis_wars-debug.apk -> package « com.cadis.wars », versionCode 12, versionName 0.12.0, orientation paysage, uses-permission VIBRATE uniquement (pas INTERNET), arm64-v8a. Si un adb/émulateur ou un appareil est disponible : adb install -r, lancer, logcat (adb logcat -s godot), vérifier que le menu s'affiche.
  4. Si l'export échoue : lire l'erreur exacte, corriger export_presets.cfg (ne jamais committer de keystore), noter la cause.

ÉTAPE 6 — Workflow GitHub (.github/workflows/export-apk.yml)
  Créer un dépôt de test, pousser le projet, lancer le workflow (push + workflow_dispatch). Vérifier : job « checks » vert ; job « export-debug » : (i) l'image barichello/godot-ci:4.3 contient bien les modèles d'export à /root/.local/share/godot/export_templates/4.3.stable (le workflow ne fait le mv que si HOME ≠ /root) ; (ii) chemins ANDROID_HOME / JAVA_HOME effectivement utilisés ; (iii) l'étape « Vérification de chargement des scripts » échoue bien si on introduit volontairement une erreur de syntaxe (test négatif, puis annuler) ; (iv) l'artefact cadis_wars-debug-apk est téléchargeable. Pour la release : créer les 3 secrets (RELEASE_KEYSTORE_BASE64, RELEASE_KEYSTORE_USER, RELEASE_KEYSTORE_PASSWORD) avec un keystore jetable et lancer workflow_dispatch release=true. Noter : un mot de passe contenant « @ » casserait les sed du workflow (à durcir si c'est le cas).

LIVRABLES (compte rendu attendu)
  1. Tableau : étape / statut [FAIT]/[À CORRIGER]/[BLOQUÉ] / preuve (extrait de log, chiffre, capture).
  2. Liste précise des modifications : fichier, lignes, raison, avant/après.
  3. cadis_wars_v13.zip (dossier racine cadis_wars_v13) + README_PROGRESSION.md mis à jour avec statuts honnêtes (ne passer en [FAIT] que ce qui a été exécuté) + APK debug si produit.
  4. Liste des points restant [NON TESTÉ SUR APPAREIL] et de ce qui nécessite un téléphone réel (encoche/zones sûres, FPS/chauffe, retour Android, vibration, mise en veille).
  5. Aucune affirmation « ça marche » sans commande exécutée et sortie citée.
