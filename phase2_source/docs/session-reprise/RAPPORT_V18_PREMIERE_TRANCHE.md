# CADIS WAR ZONE — première tranche PC/Xbox-like

Date : 5 octobre 2026

## Objectif

Cette tranche prépare une version jouable orientée PC/Xbox-like avec le renderer Forward+, en corrigeant prioritairement le lancement solo, la caméra du joueur, la qualité de rendu de base, la météo et les premiers dialogues français.

## Corrections appliquées

- Activation du renderer `forward_plus` pour PC/Xbox-like et `mobile` pour le profil mobile.
- Désactivation de la caméra statique du niveau lorsqu’un joueur local est créé.
- Spawn garanti en session locale hors réseau.
- Activation différée de la caméra du joueur après son ajout à l’arbre de scène.
- Activation du viseur local.
- Réduction de l’exposition excessive et du brouillard qui rendaient l’image délavée.
- Réglages par défaut élevés : TAA, MSAA 2x, VoxelGI élevé, SSAO élevé et SSIL moyen.
- Compatibilité Godot 4.3 rétablie dans `settings.gd`.
- Ajout d’un contrôleur jour/nuit avec soleil dynamique.
- Ajout des modes météo clavier : `1` ciel clair, `2` pluie, `3` orage.
- Ajout de l’ambiance pluie/vent en boucle.
- Ajout d’un gestionnaire de sous-titres et de voix françaises.
- Ajout d’un briefing français de mission pour Joe.
- Ajout d’une première menace vocale française du robot.
- Ajout de garde-fous sur les pièces robot et les animations projectile.
- Ajout d’une configuration gdlint adaptée au code legacy existant.

## Assets audio ajoutés

- `audio/dialogue/mission_intro_fr.wav`
- `audio/dialogue/boss_warning_fr.wav`
- `audio/ambience/rain_wind_loop.mp3`

## Validation

- Import/validation Godot headless : **OK**, code sans erreur de parsing.
- Démarrage court du niveau en Forward+ : **OK**.
- Erreurs d’animation `explode` : **corrigées**.
- Lint des scripts modifiés : configuration projet ajoutée pour ignorer les anciennes règles de style non bloquantes.
- Une erreur `mesh_get_surface_count` reste signalée par Godot sur un asset importé du projet ; elle ne produit pas d’erreur GDScript et doit être isolée avec l’éditeur Godot 4.7 ou une réimportation complète des GLB.
- Le test graphique réel sur matériel Xbox/PC n’est pas possible dans le sandbox ; Forward+ démarre toutefois dans la validation headless.

## Suite prévue

1. Vérifier visuellement la caméra et le joueur dans l’éditeur Godot 4.7.
2. Réimporter les GLB avec les paramètres Forward+ définitifs.
3. Construire le système de missions aventure avec objectifs, cinématiques et dialogues.
4. Ajouter des personnages humains/monstres plus détaillés, arbres, végétation et props réalistes.
5. Ajouter des animations de combat, boss et réactions physiques.
6. Ajouter musique adaptative, ambiances intérieures/extérieures et sons de monstres.
7. Préparer les profils de qualité PC, Xbox-like et Android.
