# 🐾 Vole la Ménagerie

> **État du dépôt : documentation initiale uniquement.** Les scripts Luau et le fichier `default.project.json` décrits ci-dessous ne sont pas encore importés. Les fonctionnalités annoncées dans le document fourni restent à vérifier après ajout du code et tests dans Roblox Studio ; ce dépôt ne contient pas encore de jeu exécutable.

Un jeu Roblox où tu collectionnes des créatures rigolotes, où elles te font gagner de l'argent... et où les autres joueurs peuvent venir te les voler !

> Jeu original, inspiré des genres populaires du moment sur Roblox (collection, tycoon, vol entre joueurs). Aucun nom, personnage ou asset d'un autre jeu n'est utilisé : toutes les créatures sont construites avec des formes simples directement par le code.

---

## Sommaire

1. [Comment on joue](#-comment-on-joue)
2. [Ce qui est déjà dans le jeu](#-ce-qui-est-déjà-dans-le-jeu)
3. [Les fichiers du projet](#-les-fichiers-du-projet)
4. [Installer Roblox Studio](#-installer-roblox-studio)
5. [Mettre le jeu dans Studio (méthode simple : copier-coller)](#-mettre-le-jeu-dans-studio-méthode-simple--copier-coller)
6. [Mettre le jeu dans Studio (méthode avancée : Rojo)](#-mettre-le-jeu-dans-studio-méthode-avancée--rojo)
7. [Tester le jeu](#-tester-le-jeu)
8. [Activer la sauvegarde](#-activer-la-sauvegarde)
9. [Publier le jeu](#-publier-le-jeu)
10. [Gagner des Robux (monétisation)](#-gagner-des-robux-monétisation)
11. [Personnaliser le jeu](#-personnaliser-le-jeu)
12. [Problèmes fréquents](#-problèmes-fréquents)
13. [Idées pour la suite](#-idées-pour-la-suite)
14. [Comment on travaille sur ce dépôt](#-comment-on-travaille-sur-ce-dépôt)

---

## 🎮 Comment on joue

1. **Tu arrives dans ta base.** Chaque joueur reçoit une des 6 bases autour du tapis roulant (son nom est affiché sur le panneau au fond).
2. **Des créatures défilent sur le tapis roulant** au milieu de la carte. Approche-toi et appuie sur **E** (ou touche le bouton sur mobile) pour en acheter une.
3. **La créature va dans ta base** et te rapporte des pièces chaque seconde.
4. **Récupère ton argent** en marchant sur la **plaque verte** à l'entrée de ta base.
5. **Achète des créatures de plus en plus rares** : elles coûtent plus cher mais rapportent beaucoup plus.
6. **Vole les créatures des autres !** Va dans une autre base, reste appuyé sur **E** devant une créature, puis ramène-la en courant dans ta base avant la fin du chrono (45 s). Attention : tu es plus lent quand tu portes une créature.
7. **Défends ta base !** Si quelqu'un te vole, cours-lui après : si tu le touches, la créature revient chez toi. Tu peux aussi appuyer sur le **bouton bleu** pour verrouiller ta base pendant 30 secondes.
8. **Base pleine ?** Approche-toi d'une de tes créatures et appuie sur **E** pour la revendre (50 % de son prix).

### Les créatures

| Créature | Rareté | Prix | Gains |
| --- | --- | --- | --- |
| Grenouille Pantoufle | Commun | 25 | 1 / s |
| Hérisson Cupcake | Peu commun | 120 | 4 / s |
| Pingouin Disco | Rare | 500 | 14 / s |
| Poulpe Astronaute | Épique | 2 000 | 45 / s |
| Lama Tornade | Épique | 8 000 | 150 / s |
| Dragon Chaussette | Légendaire | 35 000 | 550 / s |
| Baleine Galactique | Mythique | 150 000 | 2 000 / s |
| Chat Quantique | Secret | 800 000 | 9 000 / s |

**Mutations :** parfois une créature apparaît en version **Dorée** (×2 prix et gains, 5 % de chance) ou **Diamant** (×5, 1 % de chance). Elles brillent !

---

## ✅ Ce qui est déjà dans le jeu

- Carte construite automatiquement par le code : tapis roulant, 6 bases avec murs, panneaux, emplacements.
- Tapis roulant avec des créatures aléatoires (raretés et mutations).
- Achat, placement dans la base, revente.
- Revenus passifs à récupérer sur une plaque.
- Vol entre joueurs : chrono, vitesse réduite, le propriétaire peut rattraper le voleur.
- Verrou de base gratuit (30 s, puis 2 min de recharge) avec un dôme visible.
- Classement (leaderboard) avec les pièces de chaque joueur.
- Sauvegarde des pièces et des créatures (avec protection contre la duplication).
- Boutique Robux : 3 game passes et 4 produits.
- Interface : argent, gains par seconde, nombre de créatures, état du verrou, messages, bandeau de vol.
- Fonctionne sur PC, mobile et tablette.
- Sécurisé : c'est le serveur qui décide de tout (argent, achats, vols). Un tricheur ne peut pas se donner de l'argent depuis son PC.

---

## 📁 Les fichiers du projet

```
vole-la-menagerie/
├── README.md                     ← ce fichier
├── default.project.json          ← plan du projet pour Rojo (méthode avancée)
└── src/
    ├── shared/
    │   └── Config.luau           ← TOUS les réglages (prix, créatures, vitesses, IDs Robux)
    ├── server/
    │   ├── GameServer.server.luau ← le cerveau du jeu (carte, tapis, bases, vol)
    │   ├── PlayerData.luau       ← sauvegarde des joueurs
    │   └── Monetization.luau     ← achats Robux
    └── client/
        └── Client.client.luau    ← ce que le joueur voit à l'écran
```

| Fichier | Type dans Studio | Où le mettre dans Studio | Son nom dans Studio |
| --- | --- | --- | --- |
| `src/shared/Config.luau` | **ModuleScript** | ReplicatedStorage | `Config` |
| `src/server/GameServer.server.luau` | **Script** | ServerScriptService | `GameServer` |
| `src/server/PlayerData.luau` | **ModuleScript** | ServerScriptService | `PlayerData` |
| `src/server/Monetization.luau` | **ModuleScript** | ServerScriptService | `Monetization` |
| `src/client/Client.client.luau` | **LocalScript** | StarterPlayer → StarterPlayerScripts | `Client` |

> ⚠️ Les noms doivent être **exactement** ceux du tableau (majuscules comprises), sinon les scripts ne se trouvent pas entre eux.

---

## 💻 Installer Roblox Studio

1. Va sur [create.roblox.com](https://create.roblox.com) et connecte-toi avec ton compte Roblox.
2. Clique sur **Commencer à créer** (ou "Start Creating") : ça télécharge Roblox Studio.
3. Installe-le, puis ouvre-le et connecte-toi.

---

## 📋 Mettre le jeu dans Studio (méthode simple : copier-coller)

C'est la méthode conseillée pour débuter. Compte environ 15 minutes.

### Étape 1 : créer un nouveau jeu

1. Dans Studio, clique sur **Nouveau** puis choisis le modèle **Baseplate** (un grand sol gris).
2. Le jeu s'ouvre. Repère deux fenêtres importantes :
   - **Explorer** (à droite) : la liste de tout ce qu'il y a dans ton jeu.
   - **Propriétés** (à droite, en dessous) : les réglages de l'objet sélectionné.
   - Si tu ne les vois pas : onglet **Affichage** (View) en haut → clique sur **Explorer** et **Propriétés**.

### Étape 2 : créer le ModuleScript `Config`

1. Dans l'Explorer, passe la souris sur **ReplicatedStorage** et clique sur le petit **+**.
2. Choisis **ModuleScript**.
3. Clic droit sur le nouveau `ModuleScript` → **Renommer** → tape `Config` puis Entrée.
4. Double-clique dessus pour l'ouvrir. **Supprime tout** le texte qui s'y trouve.
5. Ouvre le fichier [`src/shared/Config.luau`](src/shared/Config.luau) sur GitHub, clique sur l'icône **Copier** (en haut à droite du fichier), puis colle dans Studio (Ctrl+V).

### Étape 3 : les scripts du serveur

Fais la même chose dans **ServerScriptService** :

| Clique sur + et choisis | Renomme-le | Colle le contenu de |
| --- | --- | --- |
| **ModuleScript** | `PlayerData` | `src/server/PlayerData.luau` |
| **ModuleScript** | `Monetization` | `src/server/Monetization.luau` |
| **Script** | `GameServer` | `src/server/GameServer.server.luau` |

> Attention à bien choisir **Script** (et pas ModuleScript) pour `GameServer`.

### Étape 4 : le script du joueur

1. Dans l'Explorer, ouvre **StarterPlayer** (clique sur la petite flèche).
2. Sur **StarterPlayerScripts**, clique sur **+** et choisis **LocalScript**.
3. Renomme-le `Client` et colle le contenu de `src/client/Client.client.luau`.

### Étape 5 : vérifier

Ton Explorer doit ressembler à ça :

```
ReplicatedStorage
  └── Config              (ModuleScript)
ServerScriptService
  ├── GameServer          (Script)
  ├── Monetization        (ModuleScript)
  └── PlayerData          (ModuleScript)
StarterPlayer
  └── StarterPlayerScripts
        └── Client        (LocalScript)
```

Sauvegarde ton jeu : **Fichier → Enregistrer sur Roblox** (ou Ctrl+S).

---

## 🛠️ Mettre le jeu dans Studio (méthode avancée : Rojo)

[Rojo](https://rojo.space) synchronise automatiquement les fichiers de ce dépôt avec Studio. Pratique quand le code change souvent, mais demande d'installer des outils. À essayer quand tu seras à l'aise.

1. Installe [Rokit](https://github.com/rojo-rbx/rokit) puis Rojo : `rokit add rojo-rbx/rojo`.
2. Installe le **plugin Rojo** dans Studio (onglet Plugins → Gérer les plugins, ou depuis le site de Rojo).
3. Dans le dossier du projet : `rojo serve`.
4. Dans Studio, ouvre le plugin Rojo et clique sur **Connect**. Les scripts apparaissent tout seuls.

---

## ▶️ Tester le jeu

- **Seul :** clique sur **Jouer** (Play, ou F5). Tu apparais dans ta base. Va au tapis roulant et achète une Grenouille Pantoufle avec tes 50 pièces de départ.
- **À plusieurs (pour tester le vol) :** onglet **Test** → dans "Clients et serveurs", choisis **2 joueurs** → **Démarrer**. Deux fenêtres s'ouvrent : tu peux voler avec l'un et défendre avec l'autre.
- **Voir les erreurs :** onglet **Affichage → Sortie** (Output). Les messages en rouge sont des erreurs : copie-les et envoie-les à Claude.

---

## 💾 Activer la sauvegarde

Par défaut, Studio n'a pas le droit de sauvegarder (tu verras un message jaune "Pas de sauvegarde dans ce test Studio"). Le jeu marche quand même, mais la progression repart à zéro à chaque test.

Pour activer la sauvegarde :

1. Publie d'abord le jeu (voir ci-dessous).
2. Dans Studio : **Accueil → Paramètres du jeu → Sécurité**.
3. Active **Permettre l'accès Studio aux services API** (Enable Studio Access to API Services).
4. Clique sur **Enregistrer**.

Dans le vrai jeu publié, la sauvegarde marche toujours, sans rien faire.

**Ce qui est sauvegardé :** les pièces et les créatures de la base. L'argent pas encore récupéré sur la plaque verte est ajouté automatiquement quand le joueur quitte.

---

## 🌍 Publier le jeu

1. **Fichier → Publier sur Roblox**. Donne un nom ("Vole la Ménagerie"), une description, puis valide.
2. Va sur le [Creator Hub](https://create.roblox.com/dashboard/creations), clique sur ton jeu.
3. **Nombre de joueurs par serveur :** dans les réglages du lieu (Places → ton lieu → Configurer), mets **6 joueurs maximum** (il y a 6 bases). Si un 7e joueur arrive, il n'a pas de base.
4. **Rendre le jeu public :** dans les paramètres de l'expérience, passe-le en **Public** quand tu es prêt. Avant ça, tu dois remplir le questionnaire de maturité (Maturity & Compliance).
5. Ajoute une **icône** et des **miniatures** : c'est ce qui donne envie de cliquer !

---

## 💰 Gagner des Robux (monétisation)

Le jeu a déjà une boutique (bouton **⭐ Boutique** à droite de l'écran). Tant que les numéros ne sont pas configurés, les boutons affichent "Bientôt".

### Ce qu'on vend

| Nom | Type | Ce que ça fait | Prix conseillé |
| --- | --- | --- | --- |
| 💰 Argent x2 | Game pass | Toutes les créatures rapportent 2 fois plus | 199 R$ |
| 👟 Course rapide | Game pass | Vitesse 24 au lieu de 16 | 99 R$ |
| 🏠 +5 emplacements | Game pass | 15 créatures au lieu de 10 | 149 R$ |
| 🛡️ Bouclier 10 min | Produit | Personne ne peut te voler pendant 10 min | 25 R$ |
| 🥚 Œuf mystère | Produit | Une créature Épique ou mieux | 49 R$ |
| 🪙 Sac de 5 000 pièces | Produit | +5 000 pièces | 19 R$ |
| 💎 Coffre de 60 000 pièces | Produit | +60 000 pièces | 99 R$ |

**Game pass** = acheté une seule fois, gardé pour toujours. **Produit de développeur** = achetable autant de fois qu'on veut.

### Créer un game pass

1. [Creator Hub](https://create.roblox.com/dashboard/creations) → ton jeu → **Monétisation → Passes**.
2. **Créer un pass** : nom, description, image (une image carrée simple suffit au début).
3. Ouvre le pass → **Ventes** → active "En vente" et mets le prix.
4. Copie son **ID** (le numéro dans l'adresse de la page, ou via le bouton "Copier l'ID").
5. Dans Studio, ouvre `Config` et remplace le `0` correspondant :

```lua
Config.GamePasses = {
	DoubleCash = 123456789, -- ← colle l'ID ici
	FastRun = 0,
	ExtraSlots = 0,
}
```

### Créer un produit de développeur

1. Creator Hub → ton jeu → **Monétisation → Produits de développeur → Créer**.
2. Nom, prix, puis copie l'**ID**.
3. Colle-le dans `Config.Products` (`Shield`, `MysteryEgg`, `CashSmall`, `CashBig`).

N'oublie pas de **republier** le jeu après avoir changé `Config` (Fichier → Publier sur Roblox).

### Tester les achats

Dans Studio, les achats sont des **tests gratuits** : une fenêtre te dit que tu ne seras pas débité. Tu peux donc vérifier que tout marche sans dépenser de Robux.

### Combien je touche ?

- Roblox garde 30 % : sur un pass à 100 R$, tu reçois 70 R$.
- Les Robux arrivent dans un délai de quelques jours ("en attente") avant d'être disponibles.
- Pour changer des Robux en vrai argent, il faut le programme **DevEx** : avoir au moins 13 ans, un compte vérifié et un minimum de Robux gagnés (30 000 au moment de l'écriture). Vérifie les conditions à jour sur le [site de DevEx](https://create.roblox.com/docs/production/earning-on-roblox#developer-exchange).

---

## 🎨 Personnaliser le jeu

Presque tout se règle dans **`Config.luau`**, sans toucher au reste :

- **Ajouter une créature :** copie une ligne de `Config.Creatures`, change l'`id` (sans espace ni accent), le `name`, la `rarity`, le `price`, l'`income`, la `weight` (chance d'apparition), la `size` et les couleurs.
- **Rendre le jeu plus facile :** augmente `STARTING_COINS` ou baisse les prix.
- **Tapis plus rapide :** change `CONVEYOR_SPEED` et `SPAWN_INTERVAL`.
- **Vol plus dur :** baisse `STEAL_TIME_LIMIT` ou `CARRY_WALK_SPEED`, augmente `CATCH_DISTANCE`.
- **Verrou :** `LOCK_DURATION` et `LOCK_COOLDOWN`.

> ⚠️ Ne change jamais l'`id` d'une créature quand le jeu est déjà publié : les joueurs qui la possèdent la perdraient.

---

## 🧯 Problèmes fréquents

| Problème | Solution |
| --- | --- |
| Rien n'apparaît (pas de tapis, pas de bases) | Vérifie que `GameServer` est un **Script** (pas un LocalScript) dans **ServerScriptService**. Regarde la fenêtre Sortie. |
| "Infinite yield possible on ... Config" | Le ModuleScript `Config` n'est pas dans ReplicatedStorage ou n'a pas le bon nom. |
| "Infinite yield possible on ... PlayerData" ou "Monetization" | Ces ModuleScripts doivent être dans ServerScriptService, à côté de `GameServer`. |
| Pas d'interface à l'écran | Le LocalScript `Client` doit être dans StarterPlayer → StarterPlayerScripts. |
| Je ne peux pas voler en test solo | Normal : il faut un autre joueur. Utilise le test à 2 joueurs (onglet Test). |
| Message jaune "Pas de sauvegarde" | Normal dans Studio. Voir [Activer la sauvegarde](#-activer-la-sauvegarde). |
| Le bouton de la boutique dit "Bientôt" | L'ID de cet achat vaut encore `0` dans `Config`. |

---

## 🚀 Idées pour la suite

- Une vraie musique et des sons (achat, vol, alerte).
- Des modèles 3D plus jolis pour les créatures (faits dans Studio ou Blender).
- La "Renaissance" (rebirth) : on recommence à zéro contre un bonus permanent.
- Des événements (pluie de créatures dorées pendant 5 minutes).
- Un classement global des plus riches.
- Des gains hors-ligne.
- Une quête du jour pour faire revenir les joueurs chaque jour.

---

## 🌿 Comment on travaille sur ce dépôt

- La branche `main` contient toujours une version qui marche.
- **Une branche par fonctionnalité** (`feature/nom-de-la-fonctionnalite`).
- Chaque branche arrive dans `main` par une **pull request avec une description détaillée** : ce qui change, pourquoi, et comment le tester dans Studio.
- On fusionne une pull request seulement après l'avoir testée dans Studio.

