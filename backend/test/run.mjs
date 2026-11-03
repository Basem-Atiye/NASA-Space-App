// Cross-platform runner. Only creates and removes its own uniquely named database.
import { spawnSync } from 'node:child_process';
import { readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { randomBytes } from 'node:crypto';

const cwd = fileURLToPath(new URL('../', import.meta.url));
const database = `shackleton_test_${randomBytes(8).toString('hex')}`;
function psql(args) {
  const result = spawnSync('psql', ['-X', '-v', 'ON_ERROR_STOP=1', ...args], {
    cwd, stdio: 'inherit', env: process.env,
  });
  if (result.error) throw new Error(`Cannot run psql: ${result.error.message}`);
  if (result.status !== 0) throw new Error(`psql failed (${result.status ?? result.signal})`);
}

let created = false;
try {
  psql(['-d', 'postgres', '-c', `CREATE DATABASE ${database}`]);
  created = true;
  psql(['-d', database, '-f', 'test/supabase_shim.sql']);
  const migrations = readdirSync(new URL('../prisma/migrations/', import.meta.url), { withFileTypes: true })
    .filter(entry => entry.isDirectory()).map(entry => entry.name).sort();
  for (const migration of migrations) {
    console.log(`Apply ${migration}`);
    psql(['-d', database, '-1', '-f', `prisma/migrations/${migration}/migration.sql`]);
  }
  psql(['-d', database, '-f', 'test/rls_test.sql']);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
} finally {
  if (created) {
    try {
      psql(['-d', 'postgres', '-c', `DROP DATABASE ${database}`]);
    } catch (error) {
      console.error(`Cleanup failed for ${database}: ${error.message}`);
      process.exitCode = 1;
    }
  }
}
