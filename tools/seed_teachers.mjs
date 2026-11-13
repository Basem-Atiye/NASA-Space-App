// Seeds two teacher demo accounts (Supabase Auth + profiles).
// Reads secrets from ../.env — never prints them.
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const envText = readFileSync(resolve(root, '.env'), 'utf8');
const env = Object.fromEntries(
  envText
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#') && l.includes('='))
    .map((l) => {
      const i = l.indexOf('=');
      return [l.slice(0, i).trim(), l.slice(i + 1).trim()];
    }),
);

const url = env.SUPABASE_URL;
const service = env.SUPABASE_SERVICE_ROLE_KEY || env.SUPABASE_SECRET_KEY;
const anon = env.SUPABASE_PUBLISHABLE_KEY || env.SUPABASE_ANON_KEY;
const dbUrl = env.DIRECT_URL || env.DATABASE_URL;

if (!url || !anon) {
  console.error('Missing SUPABASE_URL / publishable key in .env');
  process.exit(1);
}

const teachers = [
  { email: 'teacher1@shackleton.app', password: 'TeacherDemo1!', name: 'Ms Nova', role: 'teacher' },
  { email: 'teacher2@shackleton.app', password: 'TeacherDemo2!', name: 'Mr Orion', role: 'teacher' },
  { email: 'player1@shackleton.app', password: 'PlayerDemo1!', name: 'Cadet One', role: 'student' },
];

async function adminCreate(t) {
  if (!service) return null;
  const res = await fetch(`${url}/auth/v1/admin/users`, {
    method: 'POST',
    headers: {
      apikey: service,
      Authorization: `Bearer ${service}`,
      'Content-Type': 'application/json',
      'User-Agent': 'shackleton-seed/1.0 (node)',
      Accept: 'application/json',
    },
    body: JSON.stringify({
      email: t.email,
      password: t.password,
      email_confirm: true,
      user_metadata: { display_name: t.name, role_intent: t.role || 'teacher' },
    }),
  });
  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    /* ignore */
  }
  return { ok: res.ok, status: res.status, data, text };
}

async function listUsers() {
  if (!service) return [];
  const res = await fetch(`${url}/auth/v1/admin/users?page=1&per_page=200`, {
    headers: {
      apikey: service,
      Authorization: `Bearer ${service}`,
      'User-Agent': 'shackleton-seed/1.0 (node)',
      Accept: 'application/json',
    },
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    console.log('admin list failed', res.status, data?.message || data);
    return [];
  }
  return data.users || [];
}

async function adminUpdate(id, t) {
  const res = await fetch(`${url}/auth/v1/admin/users/${id}`, {
    method: 'PUT',
    headers: {
      apikey: service,
      Authorization: `Bearer ${service}`,
      'Content-Type': 'application/json',
      'User-Agent': 'shackleton-seed/1.0 (node)',
      Accept: 'application/json',
    },
    body: JSON.stringify({
      password: t.password,
      email_confirm: true,
      user_metadata: { display_name: t.name, role_intent: t.role || 'teacher' },
    }),
  });
  return res.ok;
}

async function confirmViaSql() {
  if (!dbUrl) {
    console.log('No DIRECT_URL — skip SQL confirm');
    return false;
  }
  try {
    const { default: pg } = await import('pg');
    const client = new pg.Client({ connectionString: dbUrl, ssl: { rejectUnauthorized: false } });
    await client.connect();
    const emails = teachers.map((t) => t.email);
    const r = await client.query(
      `update auth.users
         set email_confirmed_at = coalesce(email_confirmed_at, now()),
             confirmed_at = coalesce(confirmed_at, now())
       where email = any($1::text[])
       returning id, email`,
      [emails],
    );
    console.log(`SQL confirmed ${r.rowCount} user(s)`);
    for (const row of r.rows) {
      await client.query(
        `insert into public.profiles (id, role, display_name, avatar, age_mode)
         values ($1, 'teacher', $2, 'nova', 'explorer')
         on conflict (id) do update
           set role = 'teacher',
               display_name = excluded.display_name`,
        [row.id, teachers.find((t) => t.email === row.email)?.name || 'Teacher'],
      );
    }
    await client.end();
    return true;
  } catch (e) {
    console.log('SQL path unavailable:', e.message);
    return false;
  }
}

async function signIn(t) {
  const res = await fetch(`${url}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: anon, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: t.email, password: t.password }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    console.log(`SIGNIN_FAIL ${t.email}: ${data.msg || data.error_code || res.status}`);
    return null;
  }
  console.log(`SIGNIN_OK ${t.email}`);
  return data;
}

async function signupPublic(t) {
  const res = await fetch(`${url}/auth/v1/signup`, {
    method: 'POST',
    headers: { apikey: anon, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: t.email,
      password: t.password,
      data: { display_name: t.name, role_intent: t.role || 'student' },
    }),
  });
  const data = await res.json().catch(() => ({}));
  console.log(`SIGNUP ${t.email} status=${res.status}`);
  return res.ok ? data : null;
}

const users = await listUsers();
for (const t of teachers) {
  const existing = users.find((u) => u.email === t.email);
  if (existing) {
    const ok = await adminUpdate(existing.id, t);
    console.log(ok ? `UPDATED ${t.email}` : `UPDATE_FAIL ${t.email}`);
  } else {
    const created = await adminCreate(t);
    if (created?.ok) {
      console.log(`CREATED ${t.email}`);
    } else {
      console.log(`ADMIN_CREATE_FAIL ${t.email}: ${created?.status} ${created?.data?.message || created?.text || ''}`);
      await signupPublic(t);
    }
  }
}

await confirmViaSql();

for (const t of teachers) {
  const session = await signIn(t);
  if (session?.access_token) {
    // ensureProfile role is set by RPC arg; teachers/students both call it
    const res = await fetch(`${url}/rest/v1/rpc/ensure_profile`, {
      method: 'POST',
      headers: {
        apikey: anon,
        Authorization: `Bearer ${session.access_token}`,
        'Content-Type': 'application/json',
        Prefer: 'return=representation',
      },
      body: JSON.stringify({
        p_role: t.role || 'teacher',
        p_display_name: t.name,
        p_avatar: 'nova',
        p_age_mode: 'explorer',
      }),
    });
    console.log(res.ok ? `PROFILE_OK ${t.name}` : `PROFILE_FAIL ${t.name}`);
  }
}

console.log('\nDemo accounts:');
for (const t of teachers) {
  console.log(`  ${t.role}: ${t.email} / ${t.password}  (${t.name})`);
}
