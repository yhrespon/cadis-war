# PROMPT DE REPRISE — CADIS WAR ZONE, phase 2

Tu es un développeur senior Godot 4.3, GDScript, Android, réseau WebSocket et game design. Réponds en français. Travaille uniquement à partir du dépôt Git courant et ne demande pas de réupload si les fichiers sont présents.

## Contexte verrouillé

Le dépôt est `yhrespon/cadis-war`, branche `main`. Lis d’abord :

1. `docs/CADIS_WAR_ZONE_SESSION_FREEZE_2026-10-05.md`
2. `docs/ENVIRONMENT_MANIFEST_CADIS_WAR_ZONE.md`
3. `phase2_source/RAPPORT_V19_PHASE2.md`
4. `docs/session-reprise/SESSION_STATE.md`
5. `docs/session-reprise/RAPPORT_V18_PREMIERE_TRANCHE.md`

La base phase 2 se trouve dans `phase2_source/`. Les caches `.godot/`, les dépendances Node et les APK ne sont pas des sources nécessaires et doivent rester régénérables.

## Règles de travail

- Ne déclare `[FAIT]` que ce qui a été exécuté dans le compte courant.
- Marque `[NON TESTÉ SUR APPAREIL]` toute validation Android non réalisée sur téléphone.
- Ne committe jamais de keystore, mot de passe ou secret Railway.
- Avant modification, lire le fichier ciblé ; après modification, lancer un test reproductible.
- Corriger les causes à la source, sans masquer les erreurs par des filtres de logs.
- Respecter les limites de propriété intellectuelle : s’inspirer de mécaniques de jeux connus sans copier leurs personnages, marques, cartes, dialogues ou assets.

## État déjà réalisé

La tranche 2 comprend la mission `north_gate_revolt`, trois objectifs, HUD, checkpoints persistants, voix/sous-titres français, météo jour/nuit, pluie/orage, spawn solo, compatibilité Godot 4.3, protections bullet/mesh et export APK Android debug vérifié par apksigner v1/v2/v3.

## Première reprise obligatoire

Exécuter :

```bash
./scripts/verify_cadis_resume.sh
cd phase2_source
GODOT_SILENCE_ROOT_WARNING=1 godot4.3 --headless --path . --editor --quit --rendering-method forward_plus
godot4.3 --headless --path . --scene res://level/level.tscn --rendering-method forward_plus --quit-after 6
```

Relever les erreurs réelles. Le seul point historique connu est `mesh_get_surface_count` sur un asset importé avec le renderer dummy ; l’isoler dans Godot 4.7 sans supprimer l’asset à l’aveugle.

## Objectifs de la phase suivante

1. Remplacer les positions fixes de mission par des `Area3D`/triggers visibles et testables.
2. Répliquer objectifs, checkpoints, dégâts, tirs et score en réseau.
3. Brancher le lobby par code au serveur WebSocket existant sans casser le mode solo/IA.
4. Ajouter le tableau de score en partie, récompenses et classement.
5. Ajouter véhicules et interactions terminal/porte.
6. Tester contrôles tactiles, vibrations, audio et performances sur Android réel.
7. Exporter l’APK debug après chaque lot et vérifier sa signature.

## Livrables attendus

- Rapport Markdown avec tableau `[FAIT] / [À CORRIGER] / [BLOQUÉ] / [NON TESTÉ SUR APPAREIL]`.
- Modifications source testées.
- Commit Git explicite et propre.
- APK debug seulement si export réellement exécuté.
- Mise à jour de ce prompt et du manifeste si l’installation ou l’architecture change.
