import { readFileSync, writeFileSync, chmodSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

// Only public client fields from Ufit's selected existing profile cross into iOS.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = path.join(root, 'code', '.env');
const destination = path.join(root, 'code', 'Config', 'UFit.local.xcconfig');
const allowed = new Set(['SUPABASE_URL', 'SUPABASE_PUBLIC_KEY', 'STRIPE_PUBLIC_KEY']);
const fields = new Map();
for (const line of readFileSync(source, 'utf8').split(/\r?\n/)) {
  const match = line.match(/^\s*([A-Z_]+)\s*=\s*(.*?)\s*$/);
  if (!match || !allowed.has(match[1])) continue;
  const value = match[2].replace(/^(['"])(.*)\1$/, '$2');
  if (/[\r\n]/.test(value)) throw new Error('Invalid public runtime field');
  fields.set(match[1], value.replaceAll('//', '/$()/'));
}
if ([...allowed].some(key => !fields.get(key))) throw new Error('Ufit public authentication configuration is incomplete');
if (process.env.UFIT_API_BASE_URL) {
  const api = new URL(process.env.UFIT_API_BASE_URL);
  fields.set('UFIT_API_BASE_URL', api.href.replaceAll('//', '/$()/'));
}
writeFileSync(destination, [...fields].map(([key, value]) => `${key} = ${value}`).join('\n') + '\n', { mode: 0o600 });
chmodSync(destination, 0o600);
console.log('Configuration publique iOS provisionnée depuis le profil Ufit sélectionné.');
