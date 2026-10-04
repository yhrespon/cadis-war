# Export Android — C.A.D.I.S WARS v0.17.0 (Godot 4.3)

## Résultat de l’export local

L’environnement Android a été installé et configuré :

- Godot `4.3.stable.official.77dcf97d8`
- JDK 17 (`17.0.20.1`)
- Android SDK Platform 34
- Android SDK Build-Tools 34.0.0
- Android Platform-Tools 37.0.1
- Templates d’export Godot 4.3

Commande utilisée :

```bash
source ~/godot-workspace/android-env.sh
cd godot_project
godot --headless --path . --export-debug Android build/cadis_wars.apk
```

APK généré : `godot_project/build/cadis_wars.apk`

- Taille : environ 73 Mo
- SHA-256 : `0c49ba02b1e26587227c12f85e07566189179a778d0b62c5beb07ccd2599a103`
- Package : `com.cadis.wars`
- Version code : `17`
- Version name : `0.17.0`
- Compile SDK : 34
- Target SDK : 34
- Minimum SDK : 21
- Architecture : `arm64-v8a`
- Signature : debug Godot, vérifiée avec `apksigner`
- Permissions : Internet et vibration

Vérification effectuée :

```text
Verifies
Verified using v1 scheme (JAR signing): true
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme (APK Signature Scheme v3): true
```

L’APK debug n’est pas ajouté au dépôt Git car `build/` et `*.apk` sont ignorés par `.gitignore`. Il reste disponible comme artefact local ; le dépôt contient les sources et la configuration permettant de le reconstruire.

## Installation sur un appareil Android

Après connexion d’un appareil autorisant le débogage USB :

```bash
adb devices
adb install -r godot_project/build/cadis_wars.apk
```

Aucun appareil Android n’était connecté dans cette session : l’installation et le test tactile sur matériel réel restent donc à effectuer.

## GitHub Actions

Le workflow `.github/workflows/export-apk.yml` peut également produire un artefact `cadis_wars-debug-apk`. Les exports release nécessitent une configuration de signature séparée ; aucun keystore privé ni mot de passe n’est commité.

## Publication

Cet APK est un build **debug**, pas une version destinée au Play Store. Pour une publication, il faudra générer un AAB ou un APK release avec un keystore privé conservé hors du dépôt et configurer Play App Signing.
