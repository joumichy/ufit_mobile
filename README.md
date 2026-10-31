# Ufit

Application iOS SwiftUI et prototype React pour une plateforme sélective de
tenues, de créateurs et de marques indépendantes.

- App : `code/UFit.xcodeproj` (schéma `UFit`).
- Prototype : `cd code/design && npm ci && npm run build`.
- Backend indépendant : `joumichy/ufit_backend`, sous `code/UFit_backend`.
- Design Lab indépendant : `joumichy/ufit_design-lab`, sous `design-lab`.

## Atelier de conception

```bash
git clone git@github.com:joumichy/ufit_design-lab.git design-lab
npm --prefix code/design ci
npm --prefix design-lab ci
npm run lab
```

Storybook : `http://127.0.0.1:6007`. Ouvrir `ufit.code-workspace` pour réunir
les deux dépôts dans l'éditeur. Le Lab montre les sources du prototype en
lecture seule et propose des composants, états et maquettes dans son propre
dépôt. Le code Ufit n'a aucune dépendance runtime envers le Lab.

```bash
npm run lab:design -- start navigation --file web:app/components/BottomNav.tsx
npm run lab:design -- diff navigation
# Après revue humaine :
npm run lab:design -- approve navigation --reviewer "Nom du valideur"
npm run lab:design -- promote navigation
npm run lab:design -- promote navigation --apply
```

Les promotions sont ciblées et refusent d'écraser un fichier changé depuis
la copie initiale. Le Lab conserve une sauvegarde locale des originaux.
Vérifier le build et les interactions dans le produit après intégration.

Pour iOS, utiliser `--file ios:Core/Components/Nom.swift`, puis
`npm run lab:native -- --candidate <id> --device <UUID>`. Le Lab compile le
SwiftUI dans une app de prévisualisation séparée (`com.ufit.designlab`).
La promotion copie le code natif ; elle ne convertit pas React en SwiftUI.

Guide complet : `design-lab/README.md`. Direction produit et plan d'exécution :
documents locaux sous `docs/`.
