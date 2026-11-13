import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const requireFrom = createRequire(resolve(root, 'backend/package.json'));
const pg = requireFrom('pg');
const env = Object.fromEntries(
  readFileSync(resolve(root, '.env'), 'utf8')
    .split(/\r?\n/)
    .filter((l) => l && !l.startsWith('#') && l.includes('='))
    .map((l) => {
      const i = l.indexOf('=');
      return [l.slice(0, i).trim(), l.slice(i + 1).trim()];
    }),
);

const client = new pg.Client({ connectionString: env.DIRECT_URL, ssl: { rejectUnauthorized: false } });
await client.connect();
const r = await client.query(`
  update auth.users
     set email_confirmed_at = coalesce(email_confirmed_at, now())
   where email like '%@shackleton.app'
      or email like '%@students.shackleton.app'
  returning email
`);
console.log(`confirmed ${r.rowCount}: ${r.rows.map((x) => x.email).join(', ')}`);
await client.end();
