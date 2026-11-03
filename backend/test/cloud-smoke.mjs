// Checks the hosted guest API using only the Flutter app's public configuration.
// Creates one short-lived co-op room and closes it in finally; does not add users.
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const config = JSON.parse(readFileSync(new URL('../../env/dev.json', import.meta.url), 'utf8').replace(/^\uFEFF/, ''));
const base = config.SUPABASE_URL;
assert(base?.startsWith('https://'), 'Configure SUPABASE_URL in env/dev.json');
assert(config.SUPABASE_PUBLISHABLE_KEY, 'Configure the publishable key');

async function request(path, body) {
  const response = await fetch(`${base}/rest/v1/${path}`, {
    method: body === undefined ? 'GET' : 'POST',
    headers: { apikey: config.SUPABASE_PUBLISHABLE_KEY, 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(15000),
  });
  const text = await response.text();
  return { ok: response.ok, status: response.status, data: text ? JSON.parse(text) : null };
}

const catalogue = await request('levels?select=id,is_coop');
assert(catalogue.ok, `Catalogue returned ${catalogue.status}`);
assert.equal(catalogue.data.length, 70);
assert.equal(catalogue.data.filter(level => level.is_coop).length, 18);
console.log('PASS: guests can read all 70 activities, including 18 co-op missions');

for (const table of ['profiles', 'attempts', 'coop_rooms']) {
  const result = await request(`${table}?select=*&limit=1`);
  assert([401, 403].includes(result.status), `Guest access to ${table} should be forbidden, got ${result.status}`);
  console.log(`PASS: guests cannot read ${table}`);
}

const invalid = await request('rpc/create_coop_room', { mission: 'cadet-01' });
assert(!invalid.ok, 'Solo missions must not create co-op rooms');
console.log('PASS: solo missions cannot create co-op rooms');

let room;
try {
  const created = await request('rpc/create_coop_room', { mission: 'coop-01' });
  assert(created.ok, `Room creation returned ${created.status}`);
  room = created.data[0];
  assert.match(room.code, /^\d{4}$/);
  const joined = await request('rpc/join_coop_room', { room_code: room.code });
  assert(joined.ok, `Join returned ${joined.status}`);
  assert.equal(joined.data[0].room_id, room.room_id);
  assert.equal(joined.data[0].mission_id, 'coop-01');
  const started = await request('rpc/set_coop_status', { room: room.room_id, new_status: 'playing' });
  assert(started.ok, `Start returned ${started.status}`);
  const playing = await request('rpc/join_coop_room', { room_code: room.code });
  assert(playing.ok);
  assert.equal(playing.data[0].status, 'playing');
  console.log('PASS: guest room creation, join, and start');
} finally {
  if (room) {
    const closed = await request('rpc/set_coop_status', { room: room.room_id, new_status: 'done' });
    assert(closed.ok, `Room cleanup returned ${closed.status}`);
  }
}
const closed = await request('rpc/join_coop_room', { room_code: room.code });
assert(!closed.ok, 'Finished rooms must not be joinable');
console.log('PASS: finished room cannot be joined');
