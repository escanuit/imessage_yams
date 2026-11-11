# 🎲 Yams pour iMessage

Un Yams à deux qui se joue directement dans une conversation iMessage : chacun joue son tour
dans l'app Messages, le coup part sous forme de bulle, l'autre touche la bulle pour jouer le sien.

Pas de serveur ni de compte : toute la partie voyage dans le message.

## Installer avec Xcode

Il faut un Mac avec Xcode 15 ou plus récent.

```bash
brew install xcodegen
```

```bash
xcodegen
```

```bash
open Yams.xcodeproj
```

Dans Xcode, pour **chacune des deux cibles** (`Yams` et `YamsMessages`), onglet
*Signing & Capabilities* : choisir ton équipe (*Team*). Si l'identifiant `com.escanuit.yams`
est refusé, change le préfixe dans `project.yml` et relance `xcodegen`.

Puis branche l'iPhone, sélectionne-le comme destination et lance (⌘R). L'app apparaît dans le
tiroir d'apps de Messages. À refaire sur le deuxième iPhone : **les deux téléphones doivent avoir l'app**.

> Avec un compte Apple gratuit, l'app installée expire au bout de 7 jours (il faut la relancer
> depuis Xcode). Avec un compte développeur payant, elle tient un an, ou se distribue par TestFlight.

Sans XcodeGen : créer dans Xcode un projet *iMessage App*, y glisser les fichiers de
`YamsMessages/`, supprimer `MainInterface.storyboard`, et dans l'`Info.plist` de l'extension
remplacer `NSExtensionMainStoryboard` par
`NSExtensionPrincipalClass` = `$(PRODUCT_MODULE_NAME).MessagesViewController`.

## Comment jouer

1. Dans la conversation, ouvre Yams depuis le tiroir d'apps → **Nouvelle partie**.
2. Lance les dés (3 lancers max), touche ceux que tu gardes, puis choisis une case et valide.
3. Le coup se place dans le champ de saisie : appuie sur la flèche d'envoi.
4. L'autre touche la bulle, joue, envoie. 12 manches chacun.

## Règles

| Case | Points |
| --- | --- |
| As → Six | total des dés de la valeur |
| Bonus | +35 si le haut atteint 63 |
| Brelan | somme des 5 dés |
| Carré | 40 |
| Full | 30 |
| Petite suite (1-2-3-4-5) | 25 |
| Grande suite (2-3-4-5-6) | 25 |
| Yams | 50 |

Règles maison : pas de case Chance, donc 12 manches chacun.

Le barème est dans `YamsMessages/Game.swift` (`Category.score`) pour l'ajuster.

## Anti-triche (léger)

Les dés sont tirés à partir d'une graine contenue dans la partie : rouvrir la bulle redonne
exactement le même tirage, et les lancers déjà utilisés sont mémorisés sur l'appareil.

## Organisation

| Dossier | Contenu |
| --- | --- |
| `YamsMessages/Game.swift` | règles, score, tirage, encodage de la partie dans l'URL du message |
| `YamsMessages/GameModel.swift` | état de l'écran |
| `YamsMessages/Views.swift` | interface SwiftUI |
| `YamsMessages/MessagesViewController.swift` | lien avec Messages (lecture et envoi des bulles) |
| `Shared/` | icône |
| `Tests/main.swift` | tests de la logique, sans Xcode |
| `web/` | variante web en un seul fichier (même jeu, par lien), utile sans Mac |

Tests de la logique :

```bash
swiftc YamsMessages/Game.swift Tests/main.swift -o /tmp/yams-tests && /tmp/yams-tests
```
