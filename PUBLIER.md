# Publier Yams

Tout se fait depuis ton Mac, avec ton compte développeur. Les étapes 1 à 4 suffisent pour
jouer à deux via TestFlight ; l'étape 5 est seulement pour l'App Store public.

## 1. Signature

Dans `project.yml`, mets ton identifiant d'équipe dans `DEVELOPMENT_TEAM`, puis relance `xcodegen`.
Si l'identifiant `com.escanuit.yams` est déjà pris, change-le aussi (les deux lignes
`PRODUCT_BUNDLE_IDENTIFIER`, celle de l'extension devant garder le même préfixe).

## 2. Fiche de l'app

Sur [App Store Connect](https://appstoreconnect.apple.com) → *Apps* → **+** → *Nouvelle app* :
plateforme iOS, langue principale français, identifiant de lot `com.escanuit.yams`, SKU `yams`.
Le nom doit être unique sur l'App Store : si « Yams » est pris, essaie « Yams à deux » par exemple.

## 3. Archive et envoi

Dans Xcode : destination **Any iOS Device (arm64)** → menu *Product* → **Archive** →
*Distribute App* → **App Store Connect** → *Upload*.

Pour chaque nouvel envoi, augmente `CURRENT_PROJECT_VERSION` dans `project.yml`.

## 4. TestFlight (jouer tout de suite)

Après 10 à 30 minutes de traitement, le build apparaît dans l'onglet *TestFlight*.
Ajoute ta femme comme testeuse interne (elle doit d'abord être invitée dans
*Utilisateurs et accès*), elle installe l'app TestFlight et accepte l'invitation.
Pas de validation Apple pour les testeurs internes. Un build TestFlight expire au bout de 90 jours.

## 5. App Store public

Dans l'onglet *Distribution* de la fiche, il faut renseigner :

- **Captures d'écran** iPhone 6,9" (simulateur iPhone Pro Max, ⌘S), au moins une.
- **Description**, par exemple :
  > Le Yams à deux, directement dans vos conversations iMessage. Lancez les dés, gardez ceux
  > que vous voulez, inscrivez votre score et envoyez votre coup : votre partenaire touche la
  > bulle pour jouer le sien. 12 manches, sans compte, sans publicité, sans serveur.
- **Mots-clés** : `yams,dés,jeu,imessage,deux joueurs,couple,yam`
- **Catégorie** : Jeux → Dés (ou Jeux de société).
- **URL de la politique de confidentialité** : l'adresse de `PRIVACY.md` (le dépôt doit être public,
  ou copie le texte sur une page à toi).
- **Confidentialité de l'app** : « Aucune donnée collectée ».
- **Classification d'âge** : répondre « non » partout → 4+.
- **Prix** : gratuit.

Puis sélectionne le build et **Soumettre pour validation** (un à deux jours en général).
Dans les notes pour la validation, précise que c'est une app iMessage qui s'utilise à deux, et que
le validateur peut jouer les deux côtés avec les deux conversations du simulateur.
