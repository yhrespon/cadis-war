# C.A.D.I.S WARS — corrections appliquées

## Corrections 1–4

1. **Maisons / ville** : la ville reste procédurale, car le ZIP ne contient aucun modèle 3D de maison. Les meshes procéduraux ont été conservés et leur coût d’éclairage a été réduit pour Android.
2. **Véhicules** : le ZIP ne contient aucun modèle 3D de voiture. Les véhicules procéduraux restent fonctionnels ; les phares et effets coûteux sont limités par la qualité graphique.
3. **Lenteur** : profil automatique Android passé en Low, résolution 3D réduite, 30 FPS, ombres désactivées, effets désactivés, distance de vue réduite et streaming limité à 9 secteurs en qualité basse/moyenne. La pluie est réduite de 900 à 180 particules sans effets.
4. **Joueur / marche** : accélération augmentée, freinage séparé et plus rapide, zone morte du joystick tactile ajoutée, entrées normalisées et vitesse résiduelle supprimée sous le seuil.

## Fichiers modifiés

- `project.godot`
- `scripts/autoload/settings_manager.gd`
- `scripts/player/player.gd`
- `scripts/touch_controls.gd`
- `scripts/world/environment_controller.gd`

## Validation

- Godot : 4.3 stable
- Test intégration trafic : 8 PASS, 0 FAIL, 0 erreur GDScript/parse
- Export Android debug : réussi, APK signé et vérifié
- Architecture APK : `arm64-v8a`

Les messages `mesh_get_surface_count` observés uniquement avec le renderer Dummy headless viennent du backend de rendu sans GPU ; aucun `SCRIPT ERROR` ni `Parse Error` n’est présent dans les tests.
