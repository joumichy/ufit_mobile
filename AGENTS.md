# Ufit

Le dépôt `ufit_mobile` possède l'application SwiftUI (`code/UFit`) et le
prototype React (`code/design`). Le backend `code/UFit_backend` et l'atelier
`design-lab` sont des dépôts Git indépendants, ignorés par ce dépôt.

Avant une modification substantielle, lire les documents locaux sous `docs/`,
en commençant par `docs/operations/codex_execution_rules_ufit.md`,
`docs/ufit_execution_action_plan.md` et `docs/ufit_design_system.md`.

## Cycle de conception

Pour une nouvelle interface ou une modification visuelle :

1. Inventorier les composants Ufit et leurs stories dans le Lab.
2. Concevoir les briques et leurs états dans le Lab, puis composer la maquette.
3. Faire valider humainement la direction et le périmètre.
4. Promouvoir uniquement les fichiers validés vers leur propriétaire Ufit.
5. Raccorder les données et contrats réels dans les features produit.
6. Basculer les stories sur la source produit et qualifier le parcours réel.

Le Lab lit le produit ; le produit n'importe jamais le Lab, ses fixtures,
stories ou dépendances Storybook. React reste la cible du prototype web.
L'application iOS reçoit des fichiers SwiftUI conçus et prévisualisés en natif.
Les écrans appartiennent à `Features`, les composants à `Core/Components`, les
tokens et styles à `Core/DesignSystem`.

`npm run lab` ouvre Storybook sur le port 6007 ; `npm run lab:design -- ...`
gère les copies et promotions ; `npm run lab:native -- ...` prévisualise le
code natif dans un snapshot isolé. Le guide détaillé est possédé par
`design-lab/README.md` et `design-lab/docs/architecture.md`.

Préserver les deltas locaux préexistants. Ne pas forcer les hashes de promotion.
Un état `promoted` n'est pas une preuve de qualification ou de livraison.
Vérifier les comportements dans le navigateur ou le simulateur réel ; ne pas
créer de tests comportementaux frontend automatisés sans demande explicite.
