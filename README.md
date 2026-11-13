# Shackleton Station 2.0: Junior Astronaut Mission Trainer

A portrait mobile game for Android and iPhone, made for the NASA Space Apps Challenge 2026
challenge **Build a Junior Astronaut Mission Trainer** (Beirut team).

Players walk Commander Nova Haddad across the Moon's south pole in a hand-drawn 2D world, solve
real engineering problems with real NASA numbers, and every decision becomes evidence for six
skills. Teachers get a phone dashboard that shows who needs help, what the class learned
(Readiness Check before → after) and where the class gets stuck.

## What is in 2.0

| | Cadet (6–10) | Explorer (11–14) | Engineer (15–18) |
|---|---|---|---|
| Campaign | **Moon Cadets**, 12 levels | **Stranded at Shackleton**, 15 levels (Season 1: 10, Season 2: 5) | **Artemis Base Camp**, 15 levels |
| Style | read aloud, pictures, no timers, mistakes retried | real numbers, 30 s decisions, hints cost a star | NASA formulas in every SIM, 15 s decisions |
| New games | sort, jump, drive (tilt), fitness (motion), draw | probe, SIM planner, drive | SIM models for power, life support, radiation, ISRU, comms, thermal, landing pad, quakes, base design, Mars delay |

- **42 campaign levels + 10 Survival missions + 18 co-op missions = 70 activities** (`lib/data/catalogue.dart`).
- **Six skills**: Prioritise, Systems thinking, Root cause, Resource maths, Procedure, Teamwork.
  Mastery = share of good decisions in the last 20 pieces of evidence. Player view: *My skills*.
- **Readiness Check**: the same 8 questions before and after each campaign; the gain is the
  number we show judges and teachers.
- **Co-op** (`lib/coop/`): 2–4 players, roles Astronaut, CAPCOM, Flight Engineer, Flight
  Surgeon. Each role sees different information and owns different buttons, so the team must
  talk. Online rooms with 4-digit codes (Supabase Realtime) or one phone passed around.
  Only preset quick calls between players: no free text between children.
- **Teacher app on the phone** (`lib/teacher/`): Today (needs help, progress ring, Pip's
  insights), Class (learning gain, skills radar, where students stop, goals, CSV report),
  Students (detail with skills vs class average and every decision), Lessons (notes, assign),
  Live (live lesson: who is on which step, help requests, pause everyone), Me (classes with
  the **age level set by the teacher**, join codes, printable username + PIN cards).
  Without a teacher account it shows a realistic **sample class**, so judges can explore it.
- **Sign-in with Clerk**, **data in Supabase** (Postgres + RLS + Realtime), **schema in
  Prisma**. Offline first: everything is saved on the phone and synced when online.
- 2D upgrades: rover, greenhouse, landing pad and rocket, ice drill, 18 new pickups, lunar
  night lighting, moonquake shaking, an edge arrow with the distance to the goal, a floatier
  low-gravity lope with backpack follow-through.

## v5: the Figma design (Mission Trainer)

### v5.1: welcome screen, new map, teacher theme

- **Welcome screen** (first screen): Nova flies in, waves and talks; tap her for a zero-gravity somersault. Stars drift, shooting stars, a satellite orbits the Moon.
- **Map**: a purple Moon surface that scrolls with the levels. The Sun circles low on the horizon (as it really does at the south pole), so crater shadows sweep around; some craters stay dark for ever with ice glinting inside. Glowing travelled path, 3D level buttons, landing site and Shackleton crater rim.
- **Teacher mode** in the Figma theme: night-sky header, Figma tab bar, borderless cards, cyan buttons, rounded inputs, sheets and dialogs.
- **Alignment**: every page uses the 24 px Figma gutter; back buttons line up with the content below them.


The app now follows the Figma file "Junior Astronaut Mission Trainer": deep navy sky, Twilight
Indigo cards, chunky Strong Cyan buttons with a 3D edge, Fredoka titles and Nunito text, line
icons, and the round-helmet astronaut with orange gloves and boots.

**New: Base Commander** (`lib/base/`), the game the Figma screens show:

| Figma | Screen | File |
|---|---|---|
| 01 Splash | first screen, waving astronaut | `base/ui/base_screens.dart` |
| 02 Missions | Moon / Mars, 5 missions each, bonus round, story missions, more | `base/ui/base_screens.dart` |
| 03 Briefing | goal, starting supplies, the new idea | `base/ui/base_screens.dart` |
| 04 Mission Control | day, Next Day (hold to fast-forward), warning, tappable base, 6 tiles | `base/ui/mission_control.dart` |
| 05 Module panel | slider, "what changes over 10 days", engineer tip, melt ice, fix seal | `base/ui/mission_control.dart` |
| 06, 20 Events | 13 emergencies (storm, leak, dust, quake, night, filter, leaves...) with real science | `base/base_content.dart` |
| 07 / 08 | complete (ratings, best decision, main problem) / failed (what happened, lesson) | `base/ui/base_results.dart` |
| 09–12 Supply Run | rocket game: steer, pods, asteroids, fuel vs weight, cargo swap | `supply/` |
| 13 How to Play, 17 Pause, 18 Settings, 19 Badges | | `base/ui/`, `screens/settings_screen.dart` |
| 14 Power, 15 Crew, 16 Log | tabs of Mission Control | `base/ui/mission_control.dart` |

- **A real simulation** (`base/base_engine.dart`, pure Dart, tested): panels make power (less with
  dust, shadow and night), five systems share 100 kW, the battery covers the rest, Life Support
  gets power first when it is empty; air, water, food and crew health are linked; the greenhouse
  makes food and air but drinks water; storms hurt the crew unless the shield is up.
- **5 Moon missions** (one new idea each: power + air, water, food, radiation, repair parts) and
  **5 Mars missions** (weaker sunlight, dust storms, ice, winter) that unlock after the Moon.
- **12 badges** with real rules, Supply Run bonuses carried into the next mission, games saved
  mid-mission, three difficulty levels from the age group (Little Explorer, Explorer, Engineer).
- **Backend**: migration `0004_base_commander` adds `base_runs`, `badges_earned`, `supply_runs`
  (row-level security, checks, offline re-sync safe) and `class_base_summary()` for the
  teacher's new "Base Commander missions" card. `backend/test/rls_test.sql` now has 86 checks.

Everything that was there before is kept: the 2D story campaigns (reached from Missions →
Story missions), co-op, survival missions, encyclopedia, skills, readiness checks, the teacher
app and your Supabase sign-in.

## v4: a living game

- **Living home screen** (`lib/screens/home_scene.dart`): Nova walks around the base with the
  same Moon physics as the game, Pip follows, dust flies from her boots. Tap the ground and she
  walks there, tap her and she jumps, tap Earth and it spins (with a fact), tap the sky for a
  shooting star, drag to look around. The colours match your next mission.
- **Mission themes** (`lib/world/mission_theme.dart`): morning, clear sky, emergency, ice crater,
  solar storm, lunar night, greenhouse, launch day, moonquake. Each changes the sky, the light on
  Nova, the hills and ground, what floats in the air (frost glints, aurora, spores, embers, dust, a
  warning beacon, a helmet-lamp cone) and the colour of the buttons. Changes blend over 1.5 s, and
  the mission name glides in.
- **Hands-on puzzles** (`lib/story/hands_on.dart`):
  - Priority puzzles are now a live emergency board. Each problem is animated (gas venting,
    sparks, flames, broken radio waves, a sinking gauge) and its danger bar grows, fastest for
    the most urgent one. Press and hold to fix.
  - Materials: drag sandbags onto the habitat roof and crates into the parts bay. Radiation
    arrows bounce off once the wall is thick enough.
  - Rations: drag the level of the food and water jars.
  - Engineering SIMs: twist rotary knobs with clicks you can feel, and read needle gauges with
    green and red zones.
- **Interactive map**: every level shows its mission colour and badge, a rover drives along the
  path to the level you pick, and tapping the ground kicks up dust.
- **Speed**: the sky, hills, ground and glow are built once per screen size and theme and then
  reused. Rocks and grains reuse their paints. The old full-width blur and the title screen's
  always-running animation are gone.

## Game feel update (v3 plan)

- **Full-screen Moon**: the dark control deck is gone. A slim top bar (level, task, round
  O₂ / HP / PWR meters that pulse when low, pause) and controls that float over the ground:
  a joystick that appears where your thumb lands (left half), and on the right the Scan and
  Hint buttons in one column, exactly as tall as the big action button beside them.
- **Smooth sky**: a 7-step gradient with fine grain, so no colour bands on phone screens.
- **Real Moon walking** (g = 1.62 m/s²): walk 3 m/s; push the stick to the edge or hold it
  to **sprint** (a bounding lope, 5.2 m/s, 30% more suit oxygen, breathing sound); swipe up
  or press JUMP for a slow 1.2 m jump that lasts 2.5 s. Low grip on dust: speeding up takes a
  moment and stopping slides. Footprints, dust that flies on clean arcs, landing squash,
  thuds through the suit, the camera looks ahead.
- **Light and depth**: the far wall of Shackleton crater, haze between layers, stones that
  scroll at different speeds, a warm rim light on Nova from the low Sun, a shine across her
  visor, and she looks around (and up at Earth) when standing still.
- **Things to touch**: tap the ground (ring and dust puff), tap Nova (she waves back), tap
  Earth, the Sun or the sky (Pip gives a fact). Radio static before Mission Control talks, a
  sparkle when gear is picked up.
- **Typing text**: dialogue and Pip's cards type themselves with one soft click sound
  (Settings → Typing sound). Reduced motion shows the text at once.
- **Simple English** for school readers: long sentences split up; a test keeps Cadet at about
  8 words a sentence and Explorer at about 12. **Word tips**: hard words (regolith,
  radiation, hysteresis…) are underlined; tap one and Pip explains it simply. It is saved in
  the encyclopedia under *Words*.

## Run it

You need Flutter **3.27.4 or newer** (stable) and Android Studio; for iPhone a Mac with Xcode.

```bash
cd shackleton_station
bash tools/setup_platforms.sh   # once: android/ and ios/, icons, portrait, INTERNET permission
flutter test                    # campaign, co-op, sync, SIM, world, physics, reading-level and engine tests
flutter run --release           # offline build: guest play, one-phone co-op, sample teacher class
```

With the cloud (sign-in, classes, online co-op, live lessons):

```bash
cp env/dev.example.json env/dev.json     # fill in the public keys (see below)
flutter run --release --dart-define-from-file=env/dev.json
flutter build apk --release --dart-define-from-file=env/dev.json
```

`env/dev.json` holds **public** keys only. The Clerk secret key and the Supabase service role
key never go in the app; they live in Supabase Edge Function secrets.

## Cloud setup (about 20 minutes)

### 1. Clerk
1. Create an application. **User & authentication**: enable *Email* (with *Email verification
   code*), *Username* and *Password*.
2. Allow native apps: **Configure → Native applications** → on.
3. Copy the publishable key (`pk_test_...`) into `env/dev.json` → `CLERK_PUBLISHABLE_KEY`.
4. Copy the secret key (`sk_test_...`) for step 3 below.
5. **Integrations → Supabase** → *Activate*. Copy your Clerk domain (`xxx.clerk.accounts.dev`).
   This adds `"role": "authenticated"` to Clerk session tokens.

### 2. Supabase
1. Create a project (Frankfurt region is closest to Beirut).
2. **Authentication → Sign In / Providers → Third-party auth → Add Clerk**, paste the domain.
3. Copy the project URL and the publishable key (`sb_publishable_...`) into `env/dev.json`.
4. Database schema (Prisma):
   ```bash
   cd backend
   npm install
   cp .env.example .env          # DIRECT_URL = session connection string (port 5432)
   npm run validate              # prisma validate
   npm run migrate:deploy        # applies 0001_init, 0002_security, 0003_catalogue
   ```

### 3. Edge Functions
```bash
cd backend
cp supabase/functions/.env.example supabase/functions/.env   # CLERK_SECRET_KEY, CLERK_WEBHOOK_SIGNING_SECRET
npx supabase login
npm run functions:secrets -- --project-ref YOUR_PROJECT_REF
npm run functions:deploy -- --project-ref YOUR_PROJECT_REF
```
| Function | What it does |
|---|---|
| `create-students` | teacher makes student accounts (username + 4-digit PIN cards), resets a PIN, removes a student |
| `clerk-webhook` | keeps profiles in step with Clerk; deleting a user deletes all their data. Add it in Clerk → Webhooks (events `user.updated`, `user.deleted`) and copy the signing secret |
| `space-weather` | today's solar flares and CMEs from NASA DONKI, cached for an hour |
| `class-report` | the class as CSV (runs as the teacher, RLS applies) |

Free tiers are enough for a class and for judging: Supabase Realtime allows 200 concurrent
connections and 100 messages/s, and Clerk's free plan easily covers a school. Supabase pauses
free projects after a week without use: open the dashboard the day before the demo.

## Backend (`backend/`)

```
prisma/schema.prisma                 every table, key and index (source of truth)
prisma.config.ts                     Prisma 7 config (connection from .env)
prisma/migrations/0001_init          generated by Prisma from the schema (+ uid(), new_join_code())
prisma/migrations/0002_security      check constraints, RLS on every table, triggers, skill_mastery
                                     view, teacher dashboard functions, co-op rooms, Realtime rules
prisma/migrations/0003_catalogue     the 70 levels, generated from lib/data/catalogue.dart
                                     (python3 tools/gen_catalogue_sql.py)
supabase/functions/                  the four Edge Functions (Deno, TypeScript)
test/rls_test.sql                    86 security and behaviour checks
test/run.mjs                         cross-platform runner: applies migrations and runs SQL tests
```

Identity: Supabase verifies the Clerk token; `public.uid()` returns its `sub` (`user_...`),
so user ids are `text`. Highlights of the rules (all tested in `test/rls_test.sql`):
students see only their own rows; teachers read only students in their classes; joining a class
sets the student to the teacher's age level, and changing the class age level moves every
student; only teachers create classes, join codes are generated; attempts cannot be rewritten
and progress is written only by a trigger; nudges are presets; co-op rooms work for guests
through functions only; the live lesson channel `class:<id>` is private to the class.

Run database checks with `cd backend` then `npm run test:db`. This requires PostgreSQL
15+ with `psql` on PATH and a local test server reachable using the standard `PGHOST`,
`PGPORT`, `PGUSER`, and `PGPASSWORD` environment variables. Use a local test server,
not the hosted Supabase database: the suite installs a Supabase test shim. The runner
creates a uniquely named temporary database, stops on the first migration or test
failure, and removes that database afterward. It works on Windows without Bash.

## Project structure

```
lib/
  data/        catalogue (all 70 ids), cadet, story (Explorer S1), explorer_s2, engineer,
               levels (lessons), readiness, encyclopedia, missions (Survival), messages
  story/       campaign registry, story model/run/controller, mini-games (minigames, wow_games,
               new_games), sims (engineering models), game_physics, level_record
  coop/        coop_engine (pure rules), coop_missions (18), coop_controller, coop_screens
  teacher/     teacher_app (6 tabs), charts, insights, demo_repo (sample class)
  cloud/       cloud (Supabase), models, teacher_repo, link + supabase_link (Realtime)
  services/    env, auth_service (Clerk), session (sign-in, class, sync, live lesson),
               sync_queue (offline), progress, audio, voice
  world/       world model, characters, world art, surface view, base view
  screens/     title, rank, map, story, account, readiness, skills, survival and info screens
backend/       Prisma schema and migrations, Edge Functions, SQL tests
tools/         setup script, catalogue SQL generator, sound generator, balance checker
test/          v2 (campaigns, co-op, sync, SIMs, physics), story, world, engine tests
```

## Privacy and safety

Children never type an email: student accounts are made by teachers (username + PIN, first
names only). No free text between players or from teachers to children. Guests' progress
never leaves the phone. Deleting an account (Clerk) deletes every row it owns.

## Design system

Palette: Frozen Water `#D9FCED`, Electric Sapphire `#405FFA`, Strong Cyan `#09BBC8`,
Twilight Indigo `#3B3664`, Evergreen `#07240F` (the teacher app uses a light version).
Type: Fraunces, Manrope, JetBrains Mono.

## Credits and sources

- Life support rates: NASA (NTRS 20040142395, 20100036823); ISS water recovery 98% (NASA 2023)
- Lunar surface radiation: Chang'e 4 LND, Science Advances, 2020
- Polar ice: LCROSS (Colaprete et al., Science 2010)
- Solar storms: NASA DONKI; moonquakes: Apollo Passive Seismic Experiment
- Fonts under the SIL Open Font License (`assets/fonts/`); sounds made for this project

## Note on Space Apps rules

The official Space Apps FAQ says teams should not start working on challenges before the
hackathon. If you use this code for your submission, get written approval from your local
lead first.
