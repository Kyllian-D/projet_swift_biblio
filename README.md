# Bibliothèque d'Endoscopes

Ce projet est une application web de gestion de la compatibilité des endoscopes, écrite entièrement en **Swift** avec le framework **Hummingbird 2** et une base de données **SQLite**. Elle tourne dans **GitHub Codespaces**, sans avoir besoin de macOS ni de Xcode.

L'idée de départ est simple : permettre aux techniciens de retrouver rapidement quelle carte de connexion, quel set de connexion et quel code cycle utiliser pour un endoscope donné, selon sa marque, son modèle et sa catégorie de stérilisation (AquaTYPHOON, PlasmaTYPHOON, etc.). Les données viennent de fichiers CSV qui sont importés automatiquement au démarrage, et les cartes de connexion en PDF peuvent être ouvertes directement dans le navigateur.

---

## Fonctionnement général

Au premier lancement, le serveur lit les fichiers CSV présents dans `Sources/App/` et les charge dans la base SQLite. Si la base est déjà remplie, cet import est ignoré pour ne pas dupliquer les données. Les PDFs placés dans le dossier `PDFs/` sont indexés automatiquement et associés à leur code de carte de connexion.

Toutes les pages HTML sont générées côté serveur en Swift — il n'y a pas de framework front-end. L'interface est disponible en français et en anglais, la langue étant mémorisée dans un cookie entre les visites.

---

## Lancer le projet

Dans le terminal intégré, commencer par compiler :

```bash
./build.sh
```

Ce script résout les dépendances Swift et compile le tout. Ensuite, démarrer le serveur :

```bash
./run.sh
```

Codespaces détecte automatiquement que le port **8080** est ouvert et propose de l'ouvrir dans le navigateur — il suffit de cliquer sur la notification ou d'aller dans l'onglet **Ports**. Pour arrêter le serveur, faire `Ctrl + C` dans le terminal.

---

## Routes exposées

L'application expose une douzaine de routes. En GET, la racine `/` affiche la liste complète des endoscopes avec la recherche et le filtre par catégorie. La route `/endoscope/:id` ouvre la fiche détaillée d'un endoscope avec son formulaire de modification, `/categories` liste toutes les catégories, `/pdfs/:filename` sert un fichier PDF, et `/lang/:code` permet de changer la langue (`fr` ou `en`).

En POST, les routes `/endoscopes/add`, `/endoscope/:id/update` et `/endoscope/:id/delete` gèrent la création, la modification et la suppression d'un endoscope. Les routes `/categories/add`, `/category/:id/update` et `/category/:id/delete` font de même pour les catégories — la suppression d'une catégorie entraîne aussi la suppression de tous ses endoscopes. Enfin, `/import/csv` permet de relancer l'import CSV et de repartir d'une base vierge.

---

## Structure du projet

Le code source est organisé dans `Sources/App/`. Le point d'entrée est `main.swift`, qui configure le serveur et déclare toutes les routes. `Models.swift` contient les trois structures de données — `Endoscope`, `Category` et `PdfDocument`. `Database.swift` gère le schéma SQLite, les opérations CRUD et la logique de recherche. `Views.swift` s'occupe de générer tout le HTML en Swift, dans les deux langues. `CSVImporter.swift` prend en charge la lecture des CSV et l'indexation des PDFs.

Les données de compatibilité AquaTYPHOON sont dans `aqua_connection_cards.csv`, et celles pour PlasmaTYPHOON et PlasmaTYPHOON+ dans `plasma_connection_cards.csv`. Les PDFs sont dans le dossier `PDFs/` à la racine. La base de données `db.sqlite3` est créée automatiquement au premier démarrage.

---

## Modèles de données

Un `Endoscope` regroupe neuf informations : son identifiant, la marque, le modèle, la catégorie associée, la référence du set de connexion, le numéro article PENTAX, le code cycle, le code de carte de connexion et des notes libres. Il est conforme à `Codable` et `Sendable`.

Une `Category` est plus simple : elle a un identifiant, un nom et une description. Elle représente une ligne de produits de stérilisation comme AquaTYPHOON.

Un `PdfDocument` permet de faire le lien entre un fichier PDF physique et les endoscopes concernés. Il stocke le nom du fichier, une clé de correspondance, une clé de document et le numéro de version.

---

## Recherche

La barre de recherche sur la page principale est conçue pour être souple. La saisie est découpée en tokens sur tout caractère non-alphanumérique (espaces, tirets, `+`, `_`…), et chaque token est recherché indépendamment dans tous les champs : marque, modèle, numéro PENTAX, code cycle, carte de connexion, set de connexion, notes et nom de catégorie. Les résultats sont ensuite triés par pertinence selon le nombre de tokens qui correspondent. Le filtre par catégorie peut être combiné avec une recherche textuelle en même temps.

---

## Architecture

Le flux d'une requête est assez direct. Le navigateur envoie une requête HTTP, que Hummingbird reçoit et route dans `main.swift`. Selon la route, `Database.swift` interroge ou met à jour `db.sqlite3` via SQLite.swift. `Views.swift` construit ensuite la page HTML à partir des données récupérées, et le résultat est renvoyé au navigateur. Le CSS vient de Pico CSS, chargé depuis un CDN — pas de build front-end.

---

## Problèmes fréquents

Si le port 8080 est déjà utilisé au démarrage, il y a probablement un ancien processus qui tourne encore. La commande `lsof -i :8080` permet de trouver son PID, et `kill <PID>` suffit à le stopper. Relancer ensuite `./run.sh`.

Si la compilation échoue avec une erreur du type `'App' product not found`, c'est généralement que les dépendances n'ont pas encore été résolues. Lancer `swift package resolve` puis `./build.sh` règle le problème.

Le premier build dans un nouveau Codespace peut être lent — Swift télécharge une image Docker d'environ 1 Go. Les démarrages suivants sont bien plus rapides car l'image est mise en cache.

Enfin, si les modifications apportées au code ne s'affichent pas dans le navigateur, c'est normal : le serveur doit être redémarré pour les prendre en compte. Faire `Ctrl + C`, relancer `./build.sh`, puis `./run.sh`.
