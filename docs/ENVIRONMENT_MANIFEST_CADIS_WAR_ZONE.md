# Manifeste d’environnement — CADIS WAR ZONE

## Variables recommandées

```bash
export PATH="$HOME/.local/bin:$HOME/.dotnet:$HOME/android-sdk/platform-tools:$HOME/android-sdk/build-tools/35.0.0:$PATH"
export ANDROID_HOME="$HOME/android-sdk"
export ANDROID_SDK_ROOT="$HOME/android-sdk"
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export GODOT_SILENCE_ROOT_WARNING=1
```

## Installation reproductible

Le script principal est :

```bash
phase2_source/scripts/setup_cadis_environment.sh
```

Il installe ou vérifie Java, les outils Android, les platform-tools, la plateforme Android et les modèles d’export Godot. Les chemins sont configurables via `ANDROID_HOME`, `JAVA_HOME` et `GODOT_VERSION`.

## Vérification sans compilation

```bash
./scripts/verify_cadis_resume.sh
```

Cette vérification contrôle la présence du dépôt, de Godot, de Node/npm, du SDK Android, des templates Godot, des autoloads phase 2, des fichiers de reprise et du preset Android. Elle ne télécharge rien et ne modifie pas l’environnement.

## Fichiers qui ne doivent jamais être commités

- `.godot/` : cache d’import régénérable.
- `node_modules/` : dépendances régénérables par `npm ci`.
- APK/APKS générés et journaux de compilation.
- Keystores et mots de passe Android.
- Clés API ou secrets Railway/GitHub.

## Dépendances serveur

À la racine du dépôt, `package.json` et `package-lock.json` décrivent le serveur WebSocket/Fastify. Reconstituer les dépendances avec :

```bash
npm ci
node --check server.js
```

## Intégrations externes

Le serveur online configuré est `cadis-war.up.railway.app`. Les secrets de déploiement ne sont pas dans Git. Vérifier les variables Railway dans le compte cible avant toute publication.
