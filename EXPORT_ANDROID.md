# Export Android — C.A.D.I.S WARS v13 (Godot 4.3)

## Résultat de la tentative locale

Les modèles d’export Android Godot 4.3 et une clé de debug temporaire ont été installés, puis l’export debug tenté. Godot a refusé l’export faute de chemins SDK valides :

```text
A valid Java SDK path is required in Editor Settings (Android > Java SDK Path).
A valid Android SDK path is required in Editor Settings (Android > Android SDK Path).
```

**Aucun APK local n’a été produit.** L’environnement de test n’a pas de JDK 17 / Android SDK configuré. La clé temporaire créée pour le test est exclue des livrables.

## Export local avec un environnement configuré

1. Installer les modèles d’export Godot 4.3, le **JDK 17** et le **SDK Android** (API 34 + outils de ligne de commande).
2. Dans Godot : `Editor > Editor Settings > Export > Android`, définir *Android SDK Path* et *Java SDK Path*.
3. Importer `godot_project/project.godot` et corriger toute erreur du journal ; consulter [TEST_PROTOCOL.md](TEST_PROTOCOL.md), phase 0.
4. Utiliser le preset **Android** : `arm64-v8a`, version code 13, version name 0.13.0, paysage/immersif, permission vibration.
5. Pour l’installation : `adb install build/cadis_wars.apk` (uniquement après export réussi et vérification sur appareil).

Variables reconnues par Godot 4.3 : `GODOT_ANDROID_KEYSTORE_DEBUG_PATH|USER|PASSWORD` et `GODOT_ANDROID_KEYSTORE_RELEASE_PATH|USER|PASSWORD`. Les variables debug ne sont définies que dans l’étape debug, car Godot peut refuser l’export release si elles restent définies.

## GitHub Actions (`.github/workflows/export-apk.yml`)

- Push/PR : contrôles statiques et données, import des ressources, chargement des scripts, export Android debug et artefact `cadis_wars-debug-apk`.
- Tag `v*` ou lancement manuel `release=true` : export release, secrets requis : `RELEASE_KEYSTORE_BASE64`, `RELEASE_KEYSTORE_USER` (alias) et `RELEASE_KEYSTORE_PASSWORD`.
- Le workflow v13 échoue maintenant si l’import échoue (l’erreur n’est plus masquée par `|| true`) et contrôle aussi les messages d’import et de chargement. L’injection des champs de keystore utilise Python afin que les valeurs contenant `@` ne cassent pas la modification du preset.
- L’exécution de ce workflow n’est pas encore confirmée ; l’image `barichello/godot-ci:4.3`, ses chemins JDK/SDK/templates et l’artefact restent à valider par une exécution GitHub réelle.

## Limites et publication

Pas d’AAB/Gradle personnalisé ni de signature Play App Signing. Le package `com.cadis.wars` est cohérent dans le preset. Les icônes sont encore provisoires. Ne jamais committer un keystore ou ses mots de passe ; ne pas utiliser les secrets release pour une clé de debug.
