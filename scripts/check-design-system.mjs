import { readFileSync, readdirSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// Static architecture gate. It deliberately makes no claim about rendered UX or behavior.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sourceRoot = path.join(root, 'code/UFit');
const catalogPath = path.join(root, 'design-lab/ufit-lab.json');
const sourceExtension = '.swift';
const encoding = 'utf8';
const failureCode = 1;
const control = /\b(?:Button|TextField|SecureField|TextEditor|Picker|Toggle|Stepper|Slider|List|Form|Menu|ProgressView|DisclosureGroup|SignInWithAppleButton|ContentUnavailableView|Link|LabeledContent|NavigationStack|TabView|DatePicker|ColorPicker|Gauge|ShareLink)\s*[({]|\.(?:confirmationDialog|sheet|photosPicker|searchable|refreshable|alert|popover|fullScreenCover|contextMenu|swipeActions|toolbar|navigationTitle)\s*[({]/g;
const unscaledFont = /\.font\(\.system\(|\.font\(\.(?:largeTitle|title[23]?|headline|subheadline|body|callout|footnote|caption2?)\b/g;
const rawPalette = /Color\s*\(\s*(?:red:|hue:|white:)|Color\s*\(\s*"#[0-9a-fA-F]/g;
const rawIcon = /\bImage\s*\(\s*systemName:/g;
const labImport = /import\s+(?:StorybookKit|UfitDesignLab)\b/;
const maximumLines = 900;
function swiftFiles(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const file = path.join(directory, entry.name);
    return entry.isDirectory() ? swiftFiles(file) : file.endsWith(sourceExtension) ? [file] : [];
  });
}
const failures = [];
const features = [...swiftFiles(path.join(sourceRoot, 'Features')), ...swiftFiles(path.join(sourceRoot, 'App'))];
for (const file of features) {
  const code = readFileSync(file, encoding);
  const relative = path.relative(root, file);
  for (const [name, pattern] of [['Contrôle hors propriétaire Ufit', control], ['Typographie hors propriétaire Ufit', unscaledFont], ['Palette locale', rawPalette], ['Icône hors propriétaire Ufit', rawIcon]]) {
    pattern.lastIndex = 0;
    for (const match of code.matchAll(pattern)) {
      const line = code.slice(0, match.index).split('\n').length;
      failures.push(`${relative}:${line} ${name}: ${match[0]}`);
    }
  }
}
for (const file of [...features, ...swiftFiles(path.join(sourceRoot, 'Core/Components')), ...swiftFiles(path.join(sourceRoot, 'Core/DesignSystem'))]) {
  const code = readFileSync(file, encoding);
  if (code.split('\n').length > maximumLines) failures.push(`${path.relative(root, file)} dépasse ${maximumLines} lignes.`);
  if (labImport.test(code)) failures.push(`${path.relative(root, file)} importe le Lab.`);
}
const catalogAvailable = existsSync(catalogPath);
if (catalogAvailable) {
  const config = JSON.parse(readFileSync(catalogPath, encoding));
  const registered = new Set(config.native.catalog.map(entry => entry.source));
  for (const file of [...swiftFiles(path.join(sourceRoot, 'Core/Components')), ...swiftFiles(path.join(sourceRoot, 'Core/DesignSystem'))]) {
    const relative = path.relative(sourceRoot, file);
    if (!registered.has(relative)) failures.push(`${relative} sans propriétaire de catalogue.`);
  }
  const previewRoot = path.join(root, 'design-lab/native/Previews');
  const previewCode = swiftFiles(previewRoot).map(file => readFileSync(file, encoding)).join('\n');
  for (const entry of config.native.catalog.filter(entry => entry.source.startsWith('Core/Components/') || entry.source.startsWith('Core/DesignSystem/'))) {
    const source = readFileSync(path.join(sourceRoot, entry.source), encoding);
    for (const component of entry.components) {
      const privateType = new RegExp(`private\\s+struct\\s+${component}\\b`).test(source);
      const scenario = new RegExp(`\\b${component}\\s*[({]`).test(previewCode);
      if (!privateType && !scenario) failures.push(`${entry.source} : ${component} sans scénario canonique.`);
    }
  }
}
if (failures.length) {
  process.stderr.write(failures.join('\n') + '\n');
  process.exitCode = failureCode;
} else {
  process.stdout.write(`Design system : ${features.length} sources App/Features contrôlées ; contrôles/typo/palette possédés, plafond ${maximumLines} lignes et frontière produit/Lab vérifiés. Qualification réelle distincte.\n`);
  if (!catalogAvailable) process.stdout.write('Catalogue Lab absent : synchronisation des previews non vérifiée ; contrôle produit effectué.\n');
}
