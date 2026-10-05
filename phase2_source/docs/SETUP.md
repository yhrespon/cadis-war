# Recréer l’environnement CADIS sur un autre compte ou ordinateur

GitHub stocke le code et les assets suivis, **pas les logiciels installés, les SDK, les keystores privés ni les identifiants**. Après clonage :

```bash
git clone https://github.com/yhrespon/cadis-war-zone.git
cd cadis-war-zone
./scripts/setup_cadis_environment.sh
source "$HOME/.cadis-android.env"
./scripts/build_android.sh
```

## Ce que le script installe

- OpenJDK 17
- Android SDK Command Line Tools `11076708`
- Android `platform-tools`
- Android `build-tools 34.0.0`
- Android platform `android-34`
- Templates d’export Godot `4.7.2`
- Réglages Godot Android pour Java et Android SDK

Le script est idempotent : il réutilise les composants déjà présents et ne les télécharge pas à nouveau.

## Ce qui doit être reconnecté manuellement

- `gh auth login` pour le nouveau compte GitHub.
- Les éventuels tokens/API keys ou comptes externes.
- Un keystore de release si une signature de production est nécessaire. Le debug keystore n’est pas un secret à partager.
