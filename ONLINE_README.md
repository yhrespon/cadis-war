# C.A.D.I.S WARS — Online v1

## Fonctionnalités

- Salon par code, de 2 à 6 joueurs.
- Campagne coopérative, duel solo et duel par équipes.
- Recherche de joueur avec remplissage IA si le salon reste vide.
- Historique de résultats, victoires, récompenses et classement en mémoire serveur.
- Création de clan avec nom et tag.
- WebSocket par défaut : `wss://cadis-war.up.railway.app`.

## Serveur

Le serveur est `server.js` et son manifeste `package.json` sont à la racine du projet. Railway doit lancer `npm start`; le port est lu depuis `process.env.PORT`. Le endpoint `/health` permet une vérification.

```bash
npm install
npm start
curl http://localhost:8080/health
```

## Important

Le mode sans serveur n’est réellement possible qu’en local sur le même appareil/réseau et ne permet pas à deux APK éloignés de se découvrir. Le client utilise donc le serveur WebSocket Railway par défaut et bascule vers une simulation IA locale quand la connexion ou la recherche échoue. Les adversaires IA doivent rester identifiables dans les statistiques et les paramètres afin de ne pas présenter un faux joueur humain comme une personne réelle.

## Protocole

Les messages JSON sont : `hello`, `create_room`, `join_room`, `ready`, `start_room`, `search`, `result`, `clan_create`, `ping`.
