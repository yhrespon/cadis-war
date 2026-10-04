# Validation trafic v17 — C.A.D.I.S WARS

**Date d’exécution :** 4 octobre 2026  
**Répertoire testé :** `cadis_wars_v17/cadis_wars_v16`  
**Résultat principal :** 17/17 assertions d’intégration réussies sous Godot 4.3 Mono et OpenGL logiciel (Xvfb/llvmpipe).

## Correctifs livrés

- Réseau de feux procéduraux créé à chaque chargement de ville, avec cycles vert/jaune/rouge et tout-rouge, décalage temporel par carrefour et têtes visibles aux intersections.
- Approche du feu par limitation progressive de vitesse selon la distance d’arrêt, arrêt réel au rouge, choix au jaune fondé sur la distance de freinage et exclusion de l’attente normale au feu du compteur de blocage.
- Dégagement fantôme après plus de 7 secondes d’immobilisation réelle ; le masque de collision initial est mémorisé, désactivé vis-à-vis des véhicules pendant 3 secondes, puis restauré.
- Trafic routier activé sur le site secret, avec une densité réduite, sans population civile ambiante dans le scénario d’infiltration.
- Défauts de contrôle découverts lors de la compilation corrigés : indentation du spawner, incrément de la boucle civile (qui ne progressait pas correctement), emplacement de l’appel de trafic et activation `ai_driven` des conducteurs.

## Assertions réellement exécutées

Le test `godot_project/tests/traffic_integration.tscn` instancie le jeu et exécute de la physique 3D réelle. Les 17 vérifications suivantes sont passées :

1. La ressource de définition du site secret se charge.
2. Le site secret déclare la densité de trafic attendue.
3. L’axe X passe par le jaune.
4. L’axe conflictuel demeure rouge.
5. L’axe transversal reçoit ensuite le vert.
6. La mission secrète charge `secret_site`.
7. Le réseau de feux est présent dans l’arbre de scène.
8. Les quatre intersections exposent quatre têtes chacune (32 enfants directs).
9. Des véhicules de trafic apparaissent après 8 secondes.
10. Aucun civil ambiant n’est créé dans le scénario secret.
11. Au moins un véhicule se déplace effectivement entre deux mesures séparées de 2 secondes.
12. Le feu du scénario physique est rouge à l’approche.
13. Il demeure rouge pendant la mesure.
14. Une voiture arrivant à 9 m/s freine et s’arrête avant la ligne.
15. Le feu passe au vert pour le scénario de blocage.
16. Une voiture immobilisée derrière un véhicule passe au masque fantôme après le seuil de blocage de 7 secondes.
17. Son masque de collision d’origine revient après 3 secondes.

Commande exécutée dans cet environnement :

```bash
GODOT_SILENCE_ROOT_WARNING=1 xvfb-run -a godot43 \
  --display-driver x11 --audio-driver Dummy \
  --rendering-driver opengl3 --rendering-method gl_compatibility \
  --path godot_project res://tests/traffic_integration.tscn
```

**Sortie :** code retour 0, `RÉSULTAT: TOUS LES TESTS DE TRAFIC SONT PASSÉS`, aucune erreur de script ni de parse. Une seule alerte V-Sync est émise par le pilote d’affichage Xvfb/Mesa et n’affecte pas les assertions.

## Autres contrôles

| Contrôle | Résultat |
|---|---|
| `python3 tools/static_check.py` | 0 problème, 59 fichiers |
| `python3 tools/check_data.py` | 0 problème ; 25 missions atteignables |
| Import/analyse Godot 4.3 du projet | Processus terminé avec code 0 ; le démarrage de l’éditeur en batch émet un diagnostic interne `EditorSettings`, mais aucun parse error GDScript n’a été trouvé et le test runtime complet passe |
| `dotnet build smoke.csproj` | Build C# Godot réussi, 0 avertissement, 0 erreur |
| Projet témoin C# démarré par Godot 4.3 Mono | `C# smoke test OK` |

Le lanceur interne `godot43` configure `DOTNET_ROOT=/opt/dotnet` et `DOTNET_ROOT_X64=/opt/dotnet`. Le SDK installé est .NET 6.0.428, conforme à la documentation Godot 4.3 utilisée pour cette validation.

## Limites explicites

- Aucun export APK/Android n’a été produit ou installé ; aucun téléphone n’était disponible pour ce test.
- Ce rapport valide le système de circulation et le démarrage de la mission secrète, pas un parcours interactif exhaustif de toutes les missions ou fonctionnalités du jeu.
- Les avertissements de l’éditeur batch `EditorSettings` et de V-Sync sont rapportés ci-dessus, non masqués ; ils n’ont pas empêché le démarrage en runtime ni les assertions physiques.
