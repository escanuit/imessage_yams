# Brief : publier l'app iMessage « Yams » sur TestFlight

Tu as accès au compte développeur Apple et aux identifiants App Store Connect utilisés pour
DreamBrawl. Je te demande de t'en servir pour publier une **autre** app, sans rien modifier
dans DreamBrawl.

## Objectif

Envoyer un build de l'app iMessage **Yams** sur App Store Connect, pour qu'il soit disponible
dans TestFlight. C'est terminé quand le build apparaît dans TestFlight à l'état « Prêt à tester ».

Ne soumets **pas** l'app à la validation de l'App Store public : TestFlight interne uniquement.

## Le projet

- Dépôt : `https://github.com/escanuit/imessage_yams`
- Branche : `claude/gifted-archimedes-fafseb` (la seule ; il n'y a pas de `main`)
- App iMessage seule (pas d'icône sur l'écran d'accueil), Swift / SwiftUI, iOS 16+, aucun serveur,
  aucune dépendance.
- Deux cibles, à garder avec ces identifiants de lot :
  - `Yams` → `com.escanuit.yams` (coquille de type *messages application*)
  - `YamsMessages` → `com.escanuit.yams.MessagesExtension` (extension Messages)
- Pas de `.xcodeproj` dans le dépôt : il se génère avec `xcodegen` à partir de `project.yml`.
- `PUBLIER.md` détaille les étapes ; `.github/workflows/release.yml` les automatise.

État actuel : la compilation simulateur et l'archive Release **non signée** passent en CI.
La signature et l'envoi à Apple n'ont **jamais été exécutés**, attends-toi à devoir ajuster.

## Étapes

### 1. Côté Apple

1. Enregistrer les deux identifiants de lot ci-dessus (developer.apple.com → *Identifiers*),
   s'ils n'existent pas. Aucune capacité particulière à activer.
2. Créer la fiche de l'app sur App Store Connect : iOS, langue principale français,
   identifiant `com.escanuit.yams`, SKU `yams`. Nom : « Yams » ; s'il est déjà pris,
   « Yams à deux ». Si tu ne peux pas créer la fiche toi-même (l'API ne le permet pas),
   arrête-toi et demande-moi de le faire.

### 2. Envoi du build — choisis une des deux voies

**Voie A — workflow GitHub (à préférer si tu peux écrire des secrets sur ce dépôt)**

Ajouter ces quatre secrets dans `escanuit/imessage_yams` (*Settings → Secrets and variables → Actions*),
puis lancer le workflow **Publier sur TestFlight** (`release.yml`, déclenchement manuel) :

| Secret | Valeur |
| --- | --- |
| `APPLE_TEAM_ID` | identifiant d'équipe Apple (10 caractères) |
| `ASC_KEY_ID` | identifiant de la clé API App Store Connect |
| `ASC_ISSUER_ID` | *Issuer ID* de la clé |
| `ASC_KEY_P8` | contenu complet du fichier `.p8` |

La clé doit avoir le rôle **Admin** : le workflow archive sans signature puis laisse
`xcodebuild -exportArchive -allowProvisioningUpdates` signer avec la signature gérée par Apple.

**Voie B — depuis un Mac avec Xcode**

```bash
git clone -b claude/gifted-archimedes-fafseb https://github.com/escanuit/imessage_yams.git
cd imessage_yams
brew install xcodegen
xcodegen
```

Puis reproduire les étapes « Archive » et « Signature et envoi à App Store Connect » de
`.github/workflows/release.yml`, avec l'identifiant d'équipe et la clé API. Si tu utilises déjà
fastlane ou un autre outil pour DreamBrawl, tu peux t'en servir à la place : seul le résultat compte.

### 3. Si la signature échoue

L'archive non signée suivie d'un export signé est la partie la plus fragile. Solution de repli :
archiver **avec** signature automatique (retirer `CODE_SIGNING_ALLOWED=NO`, ajouter
`-allowProvisioningUpdates` et les trois options `-authenticationKey…` à `xcodebuild archive`).
Si tu corriges le workflow, pousse la correction sur la même branche.

### 4. Après l'envoi

1. Attendre la fin du traitement du build par Apple (10 à 30 minutes).
2. Vérifier qu'il n'y a pas d'e-mail ou d'avertissement de rejet (icônes, manifeste de
   confidentialité, version).
3. Me donner le numéro de build et me dire quoi faire pour inviter une testeuse interne.

## Règles

- Ne jamais écrire une clé, un mot de passe ou le contenu du `.p8` dans le dépôt, un commit,
  un log ou le chat : uniquement dans les secrets GitHub ou le trousseau.
- Ne pas changer les identifiants de lot ni le nom des cibles sans me le dire.
- Ne pas toucher au projet DreamBrawl, à ses certificats ni à ses profils existants ;
  ne révoquer aucun certificat.
- Le numéro de build doit augmenter à chaque envoi (`CURRENT_PROJECT_VERSION` ; le workflow
  utilise le numéro d'exécution GitHub). La version est `1.0`.
- Si une étape demande une décision (nom de l'app pris, rôle de la clé insuffisant, accès refusé
  au dépôt), arrête-toi et dis-moi précisément ce qui bloque.

## Compte rendu attendu

- la voie utilisée (A ou B) et ce que tu as dû modifier ;
- le numéro de build envoyé et son état dans TestFlight ;
- tout ce qui n'a pas marché ou n'a pas pu être vérifié.
