# Application iOS Ufit

Application SwiftUI sur iOS17 minimum, avec espaces Client, Créateur, Marque et
Administration selon les droits du compte. Le code produit est dans `UFit` ;
`UFit_backend` est un dépôt Git indépendant. Travailler par défaut sur `charlie`
dans ces deux dépôts, en préservant les changements locaux.

## Lancer le backend

Depuis la racine du workspace, suivre le [guide backend](UFit_backend/README.md).
Le profil privé sélectionné doit être déjà provisionné ; ne pas utiliser un autre
profil ou créer une base vide pour contourner une connexion indisponible.
Le runtime local qualifié écoute sur `http://127.0.0.1:4014` et son `/health`
confirme la connexion au schéma existant.

## Configurer le client

`Config/UFit.xcconfig` inclut facultativement `Config/UFit.local.xcconfig`, ignoré
par Git. Ce dernier contient uniquement les valeurs publiques client :

- `UFIT_API_BASE_URL` : origine de l’API, locale pour le simulateur ou HTTPS pour
  une distribution ;
- `SUPABASE_URL` et `SUPABASE_PUBLIC_KEY` : Auth du même projet que le backend ;
- `STRIPE_PUBLIC_KEY` : clé publiable du même mode que le backend.

Provisionner ces valeurs depuis l’autorité du profil sélectionné, sans copier de
clé secrète dans l’app. La syntaxe xcconfig impose d’échapper les doubles slashs,
comme dans le fichier de configuration versionné. Le profil local qualifié vise
le port4014 ; les valeurs versionnées seules ne constituent pas un environnement
connecté. Aucune clé privée Supabase, Stripe, Apple ou SMTP ne doit être embarquée.

## Lancer dans Xcode

Ouvrir `UFit.xcodeproj`, choisir le schéma `UFit` et un simulateur iPhone disponible,
puis lancer. Vérifier le feed réel et ses images, la connexion et l’espace du
compte concerné. Les comptes de qualification appartiennent au registre privé du
poste ; aucune adresse ou mot de passe n’est documenté ici.

Depuis la racine du workspace, un build en ligne de commande utilise le même
projet et le même schéma :

```bash
xcodebuild -project code/UFit.xcodeproj -scheme UFit -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Adapter uniquement le simulateur à ceux installés. Le succès d’un build ne prouve
pas les parcours. Les vérifications fonctionnelles se font dans l’app réelle,
y compris chargement, vide, erreur et reprise lorsqu’ils s’appliquent. Aucun test
comportemental frontend automatisé sans demande explicite.

## Organisation

- `UFit/UFitApp.swift` : point d’entrée de l’application.
- `UFit/App` : composition, navigation et sélection des espaces détenus.
- `UFit/Features` : écrans et workflows produit.
- `UFit/Core/Components` : composants Ufit réutilisables.
- `UFit/Core/DesignSystem` : tokens et styles Onyx Neige.
- `UFit/Core/Auth` : configuration publique et session.

Le Design Lab est l’espace de conception facultatif de l’utilisateur. Il n’est
pas nécessaire au lancement ou à la qualification produit et ne doit pas être
importé dans l’app.

## Portée de la qualification locale

Debug et Release ont été installés sur simulateur avec l’API locale et StripeTEST.
L’application complète reste en cours : cette procédure ne qualifie ni backend
HTTPS de distribution, connexion Apple, réception APNs/e-mail ni onboarding
Connect terminé et versements effectifs. Les critères et preuves courants sont
possédés par `docs/ufit_ios_complete_checklist.md` à la racine du workspace.
