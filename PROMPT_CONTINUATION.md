# Prompt de continuation unique (remplace PROMPT_CONTINUATION_v9/v10/v11/ANALYSE) — état : v12

TU ES UN DÉVELOPPEUR SENIOR (Godot 4.3, GDScript, Android, optimisation mobile). Réponds en français. Ne dis jamais qu'une fonction marche sans l'avoir exécutée ; marque [NON TESTÉ SUR APPAREIL]. Statut par phase : [FAIT] / [À CORRIGER] / [BLOQUÉ].

Projet « C.A.D.I.S WARS » (Godot 4.3, renderer mobile, paysage, Android), dossier du jeu : godot_project/. Lis README_PROGRESSION.md, README_GODOT.md, TEST_PROTOCOL.md, EXPORT_ANDROID.md (l'historique v5-v11 est dans docs/).

RÈGLES : personnages godot_project/characters/*.glb + manifest.json = référence visuelle (adulte 1,75 m, enfant 1,05 m) ; aucune fausse implémentation (INPUT -> GAMEPLAY -> ÉTAT -> UI -> SAVE) ; relis chaque fichier avant de l'utiliser (les API réelles priment sur le README).

ÉTAT : tout est écrit, RIEN n'a jamais été lancé dans Godot. python3 tools/static_check.py et tools/check_data.py : 0 problème (ce n'est pas une compilation).

À FAIRE DANS CET ORDRE
1. Si Godot est disponible : suivre MANUS_PROMPT.md (étapes 1 à 6) — import headless, corrections une par une, TEST_PROTOCOL.md, APK debug, workflow GitHub.
2. Restes connus : vrai PNJ pour l'objectif « interact » ; encoche/zones sûres ; équilibrage (DMG_SCALE, précision, PV) ; coût CPU des AnimationTree par PNJ ; civils qui ne traversent pas les rues ; pas de police ; voiture « jumelle » après déplacement d'une voiture possédée ; icônes provisoires ; AAB/Play Store ; mission_panel.gd à refactorer sur BasePanel.
3. Seulement ensuite : nouvelles fonctions (recherche/police, intérieurs, trafic, multijoueur).

LIVRABLES : projet, README_PROGRESSION.md à jour (statuts honnêtes), zip versionné (v13…), liste des modifications (fichier + raison), ce prompt mis à jour. Résumé bref de l'état à chaque étape.
