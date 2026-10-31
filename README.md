# Ufit

Application iOS SwiftUI et prototype web pour une plateforme sélective de tenues,
de créateurs et de marques indépendantes.

- App : `code/UFit.xcodeproj`, schéma `UFit`.
- Backend indépendant : `joumichy/ufit_backend`, sous `code/UFit_backend`.
- Design Lab natif indépendant : `joumichy/ufit_design-lab`, sous `design-lab`.

## Atelier maison SwiftUI

```bash
git clone git@github.com:joumichy/ufit_design-lab.git design-lab
npm run lab
```

L'atelier s'ouvre sur `http://127.0.0.1:6010` : exploration des composants,
création de variantes et de maquettes, édition SwiftUI, comparaison et revue de
promotion. Les rendus sont compilés avec Xcode et affichés dans le simulateur,
qui montre uniquement la maquette. Un simulateur iOS doit être démarré.

L'interface est maison. `eure/swift-storybook` découvre les #Preview du module
Ufit, sans utiliser son interface de catalogue. Les captures viennent du
simulateur ; les interactions se font dans le vrai rendu iOS. Aucun package
npm n'est nécessaire pour lancer cet atelier.

`npm run lab:open` ouvre le projet Lab généré dans Xcode pour travailler avec
le Canvas et les `#Preview`. `ufit.code-workspace` réunit les deux dépôts.
Le Lab lit les composants Ufit ; le produit n'a aucune dépendance runtime
vers le Lab ou StorybookKit.

```bash
npm run lab:design -- start boutons --file ios:Core/DesignSystem/ButtonStyles.swift
npm run lab:native -- --candidate boutons
npm run lab:design -- diff boutons
# Après revue humaine :
npm run lab:design -- approve boutons --reviewer "Nom du valideur"
npm run lab:design -- promote boutons
npm run lab:design -- promote boutons --apply
```

Pour une maquette proposée, utiliser `start selection --proposal outfit-selection`.
Le même fichier SwiftUI est conçu, prévisualisé et promu. Les promotions
refusent les conflits et conservent une sauvegarde locale. Après application,
le catalogue sans candidat relit la source iOS canonique. Compiler et qualifier
l'intégration dans Ufit reste nécessaire avant livraison.

Le Storybook React historique est secondaire : `npm run lab:web`, port 6007.
Son code reste destiné au prototype web. Guide complet et versions :
`design-lab/README.md`. Plan et design system produit : documents locaux `docs/`.
