# NASA Supabase deployment

Project: `hnvpqbvrxfxocbpzhkey` (Singapore, `ap-southeast-1`).
Dashboard: https://supabase.com/dashboard/project/hnvpqbvrxfxocbpzhkey/functions

## Completed on 3 November 2026

- Deployed `create-students`, `class-report`, `clerk-webhook`, and `space-weather`; all four are ACTIVE.
- Verified unsigned requests: student management and class reports return 401; the webhook returns 400 for an invalid signature.
- Verified space-weather CORS preflight returns 200. Replaced the failing `api.nasa.gov/DONKI` gateway with NASA's direct `https://ccmc.gsfc.nasa.gov/DONKI-API/get` API, documented in its September 2026 migration notice. Both direct endpoints returned 200.
- Deployed and verified live weather on 3 November 2026: 0 flare records and 4 CME analysis records in the requested window, with a maximum CME speed of 894 km/s and game status `watch`. Repeated requests returned `cached: true` with the same stored observation timestamp. On future upstream failures, `unavailable: true` remains a fallback, not an observation of calm conditions.
- Confirmed Realtime and public channels are enabled. The existing co-op client uses Broadcast and Presence.
- Saved the project URL and publishable key in the ignored local `env/dev.json`.
- Fixed function deployment to explicitly include the dependency import map and use API bundling without Docker.
- Applied all three Prisma migrations after the user authorized database setup: `0001_init`, `0002_security`, and `0003_catalogue`.
- Hosted guest API checks passed: 70 activities including 18 co-op missions; denied reads of profiles, attempts, and rooms; rejected solo missions for co-op; created, joined, started, and closed a guest room; confirmed finished rooms cannot be joined.

## Database maintenance

The public schema was empty before setup. Prisma now tracks all three applied migrations. Continue to manage schema changes through Prisma; do not rerun the initial SQL manually.

From `backend/`, after configuring `DIRECT_URL` in the ignored `.env` file:

```powershell
npm ci
npm run validate
npm run migrate:deploy
```

The applied migrations include `0002_security` (RLS, RPCs and Realtime policies) and `0003_catalogue` (70 activities). Creating only the tables is insufficient: co-op needs `create_coop_room`, `join_coop_room`, and `set_coop_status`; teacher features and progress sync also depend on the RPCs and policies.

Run `npm run test:cloud` from `backend/` to repeat the hosted guest API checks using `env/dev.json`. The test creates one room, closes it afterward, and leaves its closed row in the database. Two-device gameplay still needs manual verification: create a room, join using its four-digit code, start a mission, exchange actions, and finish. The API checks do not verify Realtime message exchange or the Flutter UI.

The `space_weather` table caches successful NASA responses for one hour. The direct public DONKI API does not require `NASA_API_KEY`.

## Authentication deferred

Clerk setup was explicitly skipped. No Clerk provider or secrets were added. Student/teacher sign-in, managed accounts, signed-in reports and webhook synchronization are not ready for end-to-end use until authentication is configured.

The functions retain their existing authentication design: Clerk token verification inside protected handlers and Svix signature verification for the webhook. Supabase's legacy gateway JWT verification is off as specified in the repository configuration.

## Redeploy functions

```powershell
npx supabase login
npm run functions:deploy -- --project-ref hnvpqbvrxfxocbpzhkey
```

When real secrets are available, place them in the ignored `supabase/functions/.env`, then run:

```powershell
npm run functions:secrets -- --project-ref hnvpqbvrxfxocbpzhkey
```

Do not upload placeholder secrets. Keep private keys and database passwords out of the Flutter configuration and version control.
