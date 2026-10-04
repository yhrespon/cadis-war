# C.A.D.I.S WARS — Optimisation ville et véhicules v18

Date : 2026-10-04
Moteur testé : Godot 4.3 stable `4.3.stable.official.77dcf97d8`

## Objectif

Réduire le coût de rendu des maisons/ville, des ombres, des phares et des effets procéduraux sans remplacer les générateurs existants ni casser les véhicules, le trafic ou les sauvegardes.

## Recherche utilisée

- [Godot 4.3 — Optimizing 3D performance](https://docs.godotengine.org/en/4.3/tutorials/performance/optimizing_3d_performance.html) : LOD, visibilité, instancing, lumières et ombres sur mobile.
- [Godot 4.3 — Visibility Ranges / HLOD](https://docs.godotengine.org/en/4.3/tutorials/3d/visibility_ranges.html) : fusion de groupes de géométrie et distance de visibilité.
- [Godot 4.3 — Procedural geometry](https://docs.godotengine.org/en/4.3/tutorials/3d/procedural_geometry/index.html) : réutilisation de meshes et coût CPU de la génération procédurale.
- [Godot 4.3 — Lights and shadows](https://docs.godotengine.org/en/4.3/tutorials/3d/lights_and_shadows.html) : distance des ombres, coût des ombres directionnelles et des spots.
- [Payback 2 — fiche Google Play](https://play.google.com/store/apps/details?id=net.apex_designs.payback2&hl=en_US) : variété de villes, événements, modes et véhicules. Seules les idées générales de structure ont été retenues ; aucun contenu propriétaire n’a été copié.
- [Kenney Car Kit](https://kenney.nl/assets/car-kit) et [City Kit Suburban](https://kenney-assets.itch.io/city-kit-suburban) : ressources identifiées comme CC0, mais non importées dans cette passe pour préserver les modèles procéduraux actuels.

## Modifications

### `godot_project/scripts/world/city_builder.gd`

- Les blocs restent fusionnés en deux meshes : `Main` et `Detail`.
- Le mesh `Detail` conserve sa limite de visibilité à 90 m et reçoit une marge de transition de 8 m.
- Les détails lointains (portes, balcons, vitrines, arbres, mobilier et lampes) ne projettent plus d’ombres dynamiques.
- Les marquages routiers fusionnés ne projettent plus d’ombres.
- Le mesh principal des bâtiments conserve les ombres directionnelles pour préserver la lisibilité de la ville.

### `godot_project/scripts/world/environment_controller.gd`

- Le nombre de phares dynamiques visibles simultanément est limité à **4**, choisis par distance à la caméra.
- Les phares restent sans ombres.
- Les ombres des meshes de véhicules sont activées seulement à moins de **34 m** de la caméra lorsque le réglage graphique des ombres est actif.
- Les véhicules éloignés gardent leur rendu mais ne contribuent plus à la shadow map.
- La mise à jour de ces règles est regroupée avec la mise à jour périodique de l’éclairage météo.

### `godot_project/scripts/vehicles/vehicle.gd`

- Les surfaces translucides des véhicules, notamment les pare-brise procéduraux, ne projettent pas d’ombres.
- Le gameplay, les collisions et les véhicules procéduraux restent inchangés.

## Validation exécutée

| Vérification | Statut | Preuve |
|---|---:|---|
| Godot 4.3 exact | [FAIT] | `4.3.stable.official.77dcf97d8` |
| Import/analyse éditeur headless | [FAIT] | code retour `0`, `cadis-import-after3.log` |
| `tools/static_check.py` | [FAIT avec anomalie existante] | code retour `0`, signale 1 déséquilibre préexistant dans `scripts/player/player_combat.gd` lignes 218–220 |
| `tools/check_data.py` | [FAIT] | 5 villes, 25 missions, 0 problème |
| Test trafic/intégration | [FAIT] | code retour `0`, 17 assertions prévues validées |
| Test sur téléphone Android réel | [NON TESTÉ] | aucun appareil connecté |
| Mesure FPS GPU mobile | [NON TESTÉ] | le headless ne représente pas les performances d’un téléphone |

## Limites observées

Le renderer `dummy` headless de Godot émet encore des messages bas niveau `mesh_get_surface_count` avec `Parameter "m" is null` pendant le test. Le processus retourne toutefois `0`, les scripts se chargent et les assertions de trafic passent. Ces messages relèvent du renderer de test sans GPU et ne sont pas des erreurs de parse GDScript.

Le projet contient aussi une anomalie statique préexistante signalée par `tools/static_check.py` :

```text
ÉQUILIBRE godot_project/scripts/player/player_combat.gd ( 218 220
problèmes : 1
```

Elle n’est pas liée aux trois fichiers optimisés et n’a pas été modifiée dans cette passe.

## Décision sur les assets externes

Aucun modèle CC0 n’a été injecté automatiquement. Les maisons et voitures procédurales actuelles sont fonctionnelles et les ressources externes doivent encore être vérifiées visuellement : échelle, pivot avant `+Z`, sièges, collisions, matériaux mobiles, LOD et coût mémoire. Elles pourront être ajoutées comme variantes optionnelles dans une passe séparée.
