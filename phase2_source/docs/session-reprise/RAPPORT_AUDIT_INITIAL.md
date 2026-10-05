# C.A.D.I.S WARS — rapport d’audit et de correction

Date : 4 octobre 2026
Moteur : Godot 4.3 stable (`4.3.stable.official.77dcf97d8`)
Projet : `cadis_wars_v16/godot_project`

## Inventaire

Le projet contient 60 scripts GDScript, 4 scènes `.tscn`, 66 ressources `.tres`, 14 modèles `.glb`, 13 autoloads, 25 définitions de missions, 7 véhicules, 5 armes et un test d’intégration trafic.

## Validation initiale

| Domaine | État | Résultat |
|---|---|---|
| Import Godot 4.3 | PASS | Import headless terminé sans erreur de parsing ni erreur de script |
| Compilation GDScript | PASS | Aucun `SCRIPT ERROR` ou `Parse Error` pendant l’import |
| Scène `main_menu.tscn` | PARTIEL | Démarrage sans erreur de script ; fuite de ressource signalée à la sortie |
| Scène `main.tscn` | TESTÉ MAIS ÉCHOUÉ | Erreurs renderer `Parameter "m" is null` |
| Scène `game.tscn` | TESTÉ MAIS ÉCHOUÉ | Environ 1 182 erreurs renderer sur 120 frames |
| Test trafic | PARTIEL | 8 assertions PASS, 0 FAIL ; erreurs renderer à la sortie |
| Lint GDScript | TESTÉ MAIS ÉCHOUÉ | 458 problèmes, surtout des lignes dépassant 100 caractères |
| Export Android debug | PASS | APK généré avec succès |
| Test sur appareil Android | NON TESTÉ | Aucun appareil Android connecté |
| Performance GPU mobile | NON TESTÉ | Nécessite un appareil cible |
| Multijoueur Online | NON TESTÉ / NON IMPLÉMENTÉ | Aucun test réseau réel disponible |

## Corrections appliquées

Deux corrections ciblées ont été intégrées dans la version finale :

1. `scripts/world/city_builder.gd` valide les `SurfaceTool` et refuse d’instancier un `ArrayMesh` sans surface.
2. `scripts/main_menu.gd` arrête et libère explicitement le `VideoStreamPlayer` dans `_exit_tree()`.

Les fichiers source ont été conservés dans leur structure originale. Les caches `.godot` générés par les tests ne sont pas inclus dans l’archive finale afin de forcer une réimportation propre sur la machine cible.

## Résultats après correction

- Import/parse Godot : **PASS**, 0 erreur de script.
- Scène menu : lancement **PASS** au niveau du processus ; une ressource Godot reste signalée à la fermeture headless.
- Scène game : lancement **PASS** au niveau du processus et 0 erreur de script ; les erreurs renderer `m is null` persistent en headless, avec 1 181 occurrences sur le test de 30 frames.
- Export Android debug : **PASS**.
- APK final produit : environ 87 Mo.

## Erreurs renderer restantes

Les scènes 3D produisent encore :

```text
ERROR: Parameter "m" is null.
at: mesh_get_surface_count (servers/rendering/dummy/storage/mesh_storage.h:120)
```

Le problème persiste avec les renderers headless `mobile` et `gl_compatibility`. Les 14 modèles GLB se chargent correctement et aucun `MeshInstance3D` sans mesh n’a été trouvé lors des diagnostics. L’origine exacte semble liée à des ressources 3D dynamiques ou à leur libération dans le renderer headless ; elle doit être reproduite sur un renderer graphique réel avant une correction plus invasive.

## Test d’intégration trafic

Les huit assertions suivantes passent : chargement du site secret, densité de trafic, transitions jaune/rouge/vert, chargement de la ville de la mission secrète, création du réseau de feux et présence des quatre têtes de feu par carrefour. Aucune assertion fonctionnelle n’échoue. Le test reste classé **PARTIEL** à cause des erreurs renderer et des ressources encore utilisées à la sortie.

## Lint GDScript

`gdlint` trouve 458 problèmes : 435 dépassements de longueur de ligne, 15 définitions dans un ordre non conforme, 3 fonctions avec trop de retours, 2 arguments inutilisés et 1 problème d’expression. Ces problèmes sont principalement de qualité et de style ; ils ne correspondent pas automatiquement à des erreurs de compilation Godot.

## Fichiers de sortie

- Archive corrigée : `CADIS_WARS_v17_corrige_final.zip`
- APK debug final : `CADIS_WARS_corrige_final.apk`
- Journaux détaillés : `/home/ubuntu/cadis_audit/logs/`

Le projet original n’a pas été écrasé. La configuration `run/main_scene` est restaurée sur `res://main_menu.tscn`.
