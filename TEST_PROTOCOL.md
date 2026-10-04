# Protocole de test — C.A.D.I.S WARS v17 (Godot 4.3 + appareil Android)
Les contrôles statiques, l’import/chargement, les trois smoke-tests desktop et les assertions de personnages indiqués dans `docs/COMPTE_RENDU_ANALYSE_v13.md` ont été exécutés ; le parcours interactif reste à dérouler.
Légende : noter pour chaque ligne [FAIT] / [À CORRIGER] / [BLOQUÉ] + la sortie console.

## Phase 0 — le projet charge-t-il ?
1. `python3 tools/static_check.py && python3 tools/check_data.py` (contrôles statiques : 0 problème attendu — ce n'est PAS une compilation).
2. `godot --headless --path godot_project --import` puis `godot --headless --path godot_project --quit` : corriger TOUTE erreur de parse/chargement, une par une.
3. À vérifier en priorité : noms d'os après import (`mixamorig:` vs `mixamorig_`), filtre de l'OneShot, API AnimationTree 4.3, arme dans la main, siège voiture,
   `static var` (BasePanel._active / CityBuilder), `PhysicsShapeQueryParameters3D`, `Callable` en lambdas multi-lignes.
4. Test ciblé v17 : `godot --path godot_project res://tests/traffic_integration.tscn` (adapter le nom du binaire à Godot 4.3). Il vérifie les phases des feux, l’apparition et le déplacement du trafic secret, l’arrêt au rouge, puis le mode fantôme après 7 s et la restauration des collisions après 3 s ; résultat attendu : **17 assertions PASS**.

## Parcours complet (étape 10 du plan)
| # | Action | Attendu |
|---|---|---|
| 1 | Lancer | Menu : 7 entrées lisibles, personnage 3D à droite, crédit CC-BY |
| 2 | Histoire > Nouvelle partie | Ville Port-Alpha, joueur 1,75 m, HUD (vie/armure/$/arme), minimap |
| 3 | Contrôles : stick, caméra, saut, accroupi, roulade, interaction | réponse correcte, pas de zone morte tactile |
| 4 | Panneau jaune (E) | MissionPanel : Histoire / Contrats / Secondaires ; accepter pa_01 |
| 5 | Objectif | flèche + distance + minimap ; interact (colonne bleue) -> dialogue -> mission suivante |
| 6 | pa_02 (kill) | ennemis visibles en rouge sur la minimap, tirent, meurent, `report_kill` fait avancer (n/N) |
| 7 | Arme + tir + rechargement | chargeur/réserve HUD, chiffres de dégâts, marqueur de touche |
| 8 | Récompense | argent +, toast, autosave |
| 9 | Magasin (comptoir doré) | achat réel, équiper arme / porter vêtement, solde décrémenté |
| 10 | Voiture garée (E) | monter, conduire, descendre ; mission pa_07 (vehicle_goto) |
| 11 | Mort | respawn à l'hôpital après 3 s ; mission en cours = échec |
| 12 | Pause (P / bouton II / retour Android) | PauseMenu ; Paramètres puis retour à la pause ; Sauvegarder |
| 13 | Quitter > Continuer | position, argent, inventaire, mission en cours + PROGRESSION PARTIELLE (kills, minuteur), voitures possédées, voiture conduite restaurés |
| 14 | Contrat pa_c1 | terminé puis REPROPOSÉ (répétable) et payé à chaque fois |
| 15 | pa_08 terminée | « Nouvelle ville débloquée » ; point de voyage bleu (place `travel`) > Nova District |
| 16 | Voyage pendant une mission | refusé (bouton grisé + message) |
| 17 | Nova District > Ironworks > Sunset Bay | chaque chaîne x_01..x_04 jouable ; sauvegarde puis Continuer dans la ville courante (pas de position d'une autre ville) |
| 18 | Mission secrète | voir ci-dessous |
| 19 | Online | « Multijoueur – Bientôt disponible », jamais « Connecté » |
| 20 | Paramètres (qualité Auto/Low/…/Ultra), Crédits (CC-BY), Personnage (10 persos) | appliqués ; décor du menu mis à jour |
| 21 | (v12) Marcher 10 s en ligne droite, pistolet équipé | le modèle ne dérive pas / ne « saute » pas par rapport à la capsule (root motion de l'AnimationTree) |
| 22 | (v12) Viser un mannequin à 10 m pile sous le réticule (caméra décalée à l'épaule) | le tir touche le point du réticule ; traceur sort du canon |
| 23 | (v12) Pistolet / SMG / fusil dans la main | canon vers l'avant (repère arme : canon +Y, dessus +Z), crosse dans la paume, 10 personnages |
| 24 | (v12) Boutique : vêtement/cheveux acheté puis porté | la couleur change sur le personnage (pas d'avertissement « apply_outfit » en console) |
| 25 | (v12) Pause tactile (bouton II en haut à droite) et FREIN/SORTIR en voiture | boutons visibles et fonctionnels |

## Mission secrète
Menu > Mission secrète > Commencer : site 3x3, 6 gardes (3 postes de 2) autour du dossier central ; chrono 180 s ; vision 16 m / 70° ; ALERTE si repéré.
Cas : (a) réussite discrète (+1500) ; (b) réussite avec alerte ; (c) temps écoulé ; (d) mort (pas de respawn) ; (e) abandon via pause ; (f) Rejouer ; (g) meilleur score conservé après relance ;
(h) la progression d'histoire (missions terminées, ville courante, argent) n'est PAS modifiée.

## Sur appareil Android
Encoche / zones sûres (NON gérées), taille des textes et boutons, FPS (NPC + AnimationTree), chauffe, retour Android par contexte, vibration, reprise après mise en veille.
