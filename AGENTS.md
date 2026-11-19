# Ufit

Le dépôt `ufit_mobile` possède l'application SwiftUI (`code/UFit`) et le
prototype React (`code/design`). Le backend `code/UFit_backend` et l'atelier
`design-lab` sont des dépôts Git indépendants, ignorés par ce dépôt.

Au début et à la reprise, lire `docs/ufit_product_soul.md` : la charte de l’âme
Ufit, « premium, minimaliste, ludique, immersif », guide toute décision d’interface.
La relire avant une conception ou un refactoring UX/UI.

Avant une modification substantielle, lire les documents locaux sous `docs/`,
en commençant par `docs/operations/codex_execution_rules_ufit.md`,
`docs/ufit_execution_action_plan.md` et `docs/ufit_design_system.md`.

La checklist iOS est organisée par sujet : commencer par l’index court
`docs/ufit_ios_complete_checklist.md`, puis lire et actualiser les seules pages
pertinentes de `docs/ios-checklist/`. Le dossier `legacy/` conserve uniquement
un instantané historique ; ne pas y consigner le travail courant.

## Branche de travail

Travailler par défaut sur `charlie` pour le code de l’application et le backend.
Vérifier la branche avant toute modification de ces dépôts. Les commits et
vérifications locales restent sur `charlie`. Fusionner vers `main` uniquement
lorsqu’un build cloud ou un déploiement concret est prêt à être lancé depuis
cette branche ; une recherche d’hébergement ou un build local ne justifie pas
une fusion préventive. Aucune CI depuis une branche de développement. Les branches
techniques existantes ne sont pas la cible de travail par défaut ; une autre
branche nécessite une demande explicite de l’utilisateur. Préserver les
modifications locales et l’index pendant toute bascule ou intégration.
Le Design Lab est un atelier de conception, pas une cible de version ou de
livraison produit. Son organisation ne doit pas retarder le développement de
l’application sur `charlie`.

## Cycle de conception

Le Lab est un espace de conception à la disposition de l'utilisateur. Par défaut,
l'agent conçoit, modifie et qualifie directement les sources produit sur
`charlie` : concevoir depuis la tâche utilisateur et la direction Ufit, puis
implémenter dans l'application. Le passage par le Lab n'est pas une condition
du travail et son catalogue n'est pas à maintenir systématiquement. Utiliser
une preview ciblée si elle aide concrètement à examiner un état difficile à
reproduire dans l'app, ou travailler dans le Lab à la demande de l'utilisateur.
Les décisions et délégations déjà accordées s'appliquent : le cycle produit
n'ajoute pas de validation humaine systématique avant de coder. Les règles de
revue et de promotion du Lab s'appliquent seulement lorsqu'on y travaille.
Cette consigne remplace les anciennes demandes de publication systématique des
résultats dans le Lab ; conserver leurs traces historiques sans les réactiver.

Pour chaque écran affecté, concevoir la composition à partir de la tâche, de
l'identité Ufit, des contenus et des actions, ainsi que des états pertinents.
Ne pas reprendre une action ou une disposition inadaptée sous prétexte de
conserver les composants ou les contrats existants : adapter les raccordements
autorisés tout en préservant les fonctions et les règles métier. Pendant le
codage, regarder le rendu complet, corriger hiérarchie, alignement, densité et
actions, puis vérifier les parcours et états affectés dans le simulateur réel.
Vérifier notamment vide, chargement, erreur et reprise lorsqu'ils s'appliquent.
Un état vide ne doit pas masquer un échec de chargement. Une compilation, le
nombre de previews ou l'utilisation de composants Ufit ne prouvent pas la
qualité du résultat.
Signaler les états non vérifiés et leurs limites avant de déclarer le travail
terminé ; un défaut significatif constaté doit être corrigé dans le périmètre.

Le Lab maison se pilote dans le navigateur : exploration, édition des variantes,
comparaison et promotion. Dans ce mode, son renderer affiche la maquette native ;
la qualification produit se fait dans l'application Ufit sur simulateur réel.
Swift Storybook assure la découverte des #Preview, sans son interface générique. Le Lab lit les composants iOS du produit ; le produit
n'importe jamais le Lab, ses fixtures ou `StorybookKit`. Lorsqu'une conception
passe par le Lab, promouvoir les fichiers SwiftUI examinés de manière ciblée. Le prototype React
reste une surface secondaire et ne sert pas de source de conception iOS.
Les écrans appartiennent à `Features`, les composants à `Core/Components`, les
tokens et styles à `Core/DesignSystem`.

`npm run lab` lance l’atelier navigateur sur `127.0.0.1:6011`. `npm run lab:open` ouvre le projet
Lab et les `#Preview` dans Xcode. `npm run lab:design -- ...` gère les reworks
et promotions ; `npm run lab:native -- --candidate <id>` prévisualise une copie ciblée.
`npm run lab:web` conserve le prototype Storybook React sur le port 6007.
Le guide détaillé est possédé par
`design-lab/README.md` et `design-lab/docs/architecture.md`.

Préserver les deltas locaux préexistants. Ne pas forcer les hashes de promotion.
Un état `promoted` n'est pas une preuve de qualification ou de livraison.
Vérifier les comportements dans le navigateur ou le simulateur réel ; ne pas
créer de tests comportementaux frontend automatisés sans demande explicite.
