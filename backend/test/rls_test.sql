-- Security and behaviour tests for the migrations. Runs on plain PostgreSQL with
-- test/supabase_shim.sql loaded (see test/run.sh). Every check raises on failure.
\set ON_ERROR_STOP 1
\set QUIET 1

CREATE OR REPLACE FUNCTION pg_temp.act_as(sub text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF sub IS NULL THEN
    PERFORM set_config('request.jwt.claims', '{"role":"anon"}', false);
    EXECUTE 'SET ROLE anon';
  ELSE
    PERFORM set_config('request.jwt.claims', json_build_object('sub', sub, 'role', 'authenticated')::text, false);
    EXECUTE 'SET ROLE authenticated';
  END IF;
END $$;
CREATE OR REPLACE FUNCTION pg_temp.ok(cond boolean, what text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF cond IS NOT TRUE THEN RAISE EXCEPTION 'FAILED: %', what; END IF;
  RAISE NOTICE 'ok  %', what;
END $$;
-- Runs a statement that must fail; returns true if it did.
CREATE OR REPLACE FUNCTION pg_temp.fails(stmt text) RETURNS boolean LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE stmt;
  RETURN false;
EXCEPTION WHEN OTHERS THEN
  RETURN true;
END $$;
GRANT EXECUTE ON FUNCTION pg_temp.ok(boolean, text), pg_temp.fails(text), pg_temp.act_as(text) TO anon, authenticated;

-- ── Fixture: the create-students Edge Function (service role) makes two students ──
RESET ROLE;
INSERT INTO profiles (id, role, display_name, username, created_by, age_mode)
VALUES ('user_s1', 'student', 'Rana', 'rana_7b4mxq', 'user_t1', 'explorer'),
       ('user_s2', 'student', 'Omar', 'omar_k2p9wd', 'user_t1', 'explorer'),
       ('user_x',  'student', 'Lina', NULL, NULL, 'engineer');

-- ── Teacher signs up and creates a class ──
SELECT pg_temp.act_as('user_t1');
SELECT pg_temp.ok((SELECT role FROM ensure_profile('teacher', 'Ms Haddad')) = 'teacher', 'teacher creates own profile');
SELECT pg_temp.ok((SELECT role FROM ensure_profile('student', 'ignored')) = 'teacher', 'ensure_profile never changes an existing role');
INSERT INTO classes (name, age_mode, join_code) VALUES ('Grade 6 Blue', 'cadet', 'AAAAAA');
SELECT pg_temp.ok((SELECT join_code <> 'AAAAAA' AND join_code ~ '^[A-Z0-9]{6}$' FROM classes WHERE name = 'Grade 6 Blue'),
                  'join code is generated, never chosen');
SELECT pg_temp.ok(pg_temp.fails($$UPDATE profiles SET role = 'admin' WHERE id = 'user_t1'$$), 'cannot promote self to admin');
SELECT pg_temp.ok((SELECT count(*) FROM profiles) = 1, 'teacher sees only self before anyone joins');

RESET ROLE;
CREATE TEMP TABLE fx AS SELECT id AS cid, join_code FROM classes WHERE name = 'Grade 6 Blue';
GRANT SELECT ON fx TO anon, authenticated;
-- the Edge Function adds its students to the class
INSERT INTO class_members (class_id, student_id) SELECT cid, 'user_s1' FROM fx;
UPDATE profiles SET age_mode = 'cadet' WHERE id = 'user_s1';

-- ── A student without a teacher account cannot create classes ──
SELECT pg_temp.act_as('user_s2');
SELECT pg_temp.ok(pg_temp.fails($$INSERT INTO classes (name, age_mode) VALUES ('Hack', 'cadet')$$), 'students cannot create classes');
SELECT pg_temp.ok(pg_temp.fails($$INSERT INTO class_members (class_id, student_id) SELECT cid, 'user_s2' FROM fx$$),
                  'students cannot add themselves to class_members directly');
-- joins with the code (lower case and spaces are fine) and takes the class age level
SELECT pg_temp.ok((SELECT age_mode FROM join_class(lower((SELECT join_code FROM fx)) || ' ')) = 'cadet', 'join_class returns the class age level');
SELECT pg_temp.ok((SELECT age_mode FROM profiles WHERE id = 'user_s2') = 'cadet', 'joining sets the student to the class age level');
UPDATE profiles SET age_mode = 'engineer', display_name = 'Omar K' WHERE id = 'user_s2';
SELECT pg_temp.ok((SELECT age_mode = 'cadet' AND display_name = 'Omar K' FROM profiles WHERE id = 'user_s2'),
                  'a class student can rename but not change age level');
SELECT pg_temp.ok(pg_temp.fails($$UPDATE profiles SET role = 'teacher' WHERE id = 'user_s2'$$), 'a student cannot become a teacher');
SELECT pg_temp.ok((SELECT count(*) FROM profiles) = 1, 'students cannot read other profiles');
SELECT pg_temp.ok((SELECT count(*) FROM classes) = 1, 'student reads the class they joined');
SELECT pg_temp.ok(pg_temp.fails($$SELECT * FROM join_class('ZZZZZZ')$$), 'unknown class code is rejected');

-- plays a level: attempt + skill events; progress follows by trigger
INSERT INTO attempts (client_id, level_id, age_mode, started_at, ended_at, outcome, stars, mistakes, hints, duration_s, decisions)
VALUES ('00000000-0000-4000-8000-000000000001', 'cadet-01', 'cadet', now() - interval '6 min', now(), 'complete', 2, 1, 0, 360,
        '[{"step":"order","good":false},{"step":"helmet","good":true}]');
INSERT INTO attempts (client_id, level_id, age_mode, started_at, ended_at, outcome, stars)
VALUES ('00000000-0000-4000-8000-000000000001', 'cadet-01', 'cadet', now(), now(), 'complete', 3)
ON CONFLICT (client_id) DO NOTHING;
SELECT pg_temp.ok((SELECT count(*) FROM attempts) = 1, 'offline re-sync of the same attempt is ignored');
INSERT INTO skill_events (attempt_id, skill, correct)
SELECT id, s, c FROM attempts, (VALUES ('procedure'::skill, true), ('procedure', false), ('prioritise', true)) v(s, c);
SELECT pg_temp.ok((SELECT best_stars = 2 AND attempts = 1 AND completed_at IS NOT NULL FROM level_progress WHERE level_id = 'cadet-01'),
                  'level_progress updated by the attempts trigger');
INSERT INTO attempts (client_id, level_id, age_mode, started_at, outcome, stars)
VALUES ('00000000-0000-4000-8000-000000000002', 'cadet-01', 'cadet', now(), 'complete', 3);
SELECT pg_temp.ok((SELECT best_stars = 3 AND attempts = 2 FROM level_progress WHERE level_id = 'cadet-01'), 'best stars and play count kept');
SELECT pg_temp.ok(pg_temp.fails($$UPDATE level_progress SET best_stars = 3$$), 'students cannot edit progress');
SELECT pg_temp.ok(pg_temp.fails($$INSERT INTO level_progress (level_id, best_stars) VALUES ('cadet-02', 3)$$), 'students cannot write progress directly');
SELECT pg_temp.ok(pg_temp.fails($$UPDATE attempts SET stars = 3$$), 'attempt history cannot be rewritten');
SELECT pg_temp.ok(pg_temp.fails($$INSERT INTO attempts (client_id, user_id, level_id, age_mode, started_at) VALUES (gen_random_uuid(), 'user_s1', 'cadet-02', 'cadet', now())$$),
                  'cannot write attempts for someone else');
CREATE TEMP TABLE sub AS SELECT submit_attempt('{"client_id":"00000000-0000-4000-8000-000000000003","level_id":"cadet-02","age_mode":"cadet","started_at":"2026-11-14T09:00:00Z","ended_at":"2026-11-14T09:06:00Z","outcome":"failed","stars":0,"mistakes":4,"hints":2,"duration_s":360,"decisions":[]}',
  '[{"skill":"resource_math","correct":false},{"skill":"resource_math","correct":true}]') AS id;
SELECT pg_temp.ok((SELECT id FROM sub) = submit_attempt('{"client_id":"00000000-0000-4000-8000-000000000003","level_id":"cadet-02","age_mode":"cadet","started_at":"2026-11-14T09:00:00Z"}',
  '[{"skill":"resource_math","correct":true}]'), 'submit_attempt is idempotent and returns the same id');
SELECT pg_temp.ok((SELECT count(*) FROM skill_events WHERE skill = 'resource_math') = 2, 'a retried submit does not duplicate skill events');
SELECT pg_temp.ok((SELECT best_stars = 0 AND completed_at IS NULL FROM level_progress WHERE level_id = 'cadet-02'), 'a failed attempt counts as played, not finished');
SELECT pg_temp.ok((SELECT score FROM skill_mastery WHERE skill = 'procedure') = 50, 'skill mastery view: 1 of 2 correct = 50');
INSERT INTO assessments (campaign, kind, score, max_score) VALUES ('cadet', 'pre', 3, 8);
INSERT INTO assessments (campaign, kind, score, max_score) VALUES ('cadet', 'post', 7, 8);
SELECT pg_temp.ok(pg_temp.fails($$INSERT INTO assessments (campaign, kind, score, max_score) VALUES ('cadet', 'post', 9, 8)$$), 'score cannot exceed max');
INSERT INTO fact_unlocks (fact_id) VALUES ('gravity'), ('regolith');
INSERT INTO campaign_state (campaign, carry, current_level) VALUES ('cadet', '{"health":90}', 2);
INSERT INTO settings (voice, reduced_motion) VALUES (true, false);
SELECT pg_temp.ok(pg_temp.fails($$SELECT class_overview((SELECT cid FROM fx))$$), 'students cannot open the teacher dashboard');

-- ── Another student in no class ──
SELECT pg_temp.act_as('user_x');
UPDATE profiles SET age_mode = 'explorer' WHERE id = 'user_x';
SELECT pg_temp.ok((SELECT age_mode FROM profiles WHERE id = 'user_x') = 'explorer', 'a student in no class can change age level');
SELECT pg_temp.ok((SELECT count(*) FROM attempts) = 0, 'other students see none of my attempts');
SELECT pg_temp.ok((SELECT count(*) FROM classes) = 0, 'non-members cannot see the class');

-- ── Teacher dashboard ──
SELECT pg_temp.act_as('user_t1');
SELECT pg_temp.ok((SELECT count(*) FROM profiles) = 3, 'teacher reads own profile and both students');
SELECT pg_temp.ok((SELECT count(*) FROM attempts) = 3, 'teacher reads class attempts');
SELECT pg_temp.ok((SELECT students = 2 AND active_today = 1 AND levels_total = 12 AND gain_points = 50
                   FROM class_overview((SELECT cid FROM fx))), 'class overview: 2 students, 1 active, +50 point gain');
SELECT pg_temp.ok((SELECT count(*) FROM class_students((SELECT cid FROM fx))) = 2, 'class_students lists both');
SELECT pg_temp.ok((SELECT help_reason FROM class_students((SELECT cid FROM fx)) WHERE student_id = 'user_s1') = 'not_started',
                  'a student who has not played is flagged not_started');
SELECT pg_temp.ok((SELECT score FROM class_skills((SELECT cid FROM fx)) WHERE skill = 'procedure') = 50, 'class skills average');
SELECT pg_temp.ok((SELECT help_reason FROM class_students((SELECT cid FROM fx)) WHERE student_id = 'user_s2') IS NULL, 'one failed attempt is not yet a needs-help flag');
SELECT pg_temp.ok((SELECT count(*) FROM class_skills((SELECT cid FROM fx))) = 6, 'class skills lists all six skills');
SELECT pg_temp.ok((SELECT finished FROM class_levels((SELECT cid FROM fx)) WHERE level_id = 'cadet-01') = 1, 'class levels: finished count');
SELECT pg_temp.ok((SELECT class_avg FROM student_skills('user_s2', (SELECT cid FROM fx)) WHERE skill = 'procedure') = 50, 'student skills with class average');
SELECT pg_temp.ok(pg_temp.fails($$SELECT * FROM student_skills('user_x', (SELECT cid FROM fx))$$), 'cannot inspect a student outside the class');
INSERT INTO nudges (class_id, student_id, kind, level_id) SELECT cid, 'user_s2', 'well_done', 'cadet-01' FROM fx;
SELECT pg_temp.ok(pg_temp.fails($$INSERT INTO nudges (class_id, student_id, kind) SELECT cid, 'user_x', 'hint' FROM fx$$), 'cannot nudge a student outside the class');
SELECT pg_temp.ok(pg_temp.fails($$INSERT INTO nudges (class_id, student_id, kind) SELECT cid, 'user_s2', 'free text' FROM fx$$), 'nudges are presets only');
INSERT INTO assignments (class_id, level_id) SELECT cid, 'cadet-02' FROM fx;
INSERT INTO assignments (class_id, level_id, student_id) SELECT cid, 'cadet-01', 'user_s2' FROM fx;
INSERT INTO class_goals (class_id, title, skill, target) SELECT cid, 'Everyone reaches Procedure 70', 'procedure', 70 FROM fx;
UPDATE classes SET age_mode = 'explorer' WHERE id = (SELECT cid FROM fx);
SELECT pg_temp.ok((SELECT bool_and(age_mode = 'explorer') FROM profiles WHERE id IN ('user_s1', 'user_s2')),
                  'changing the class age level moves every student');
UPDATE classes SET age_mode = 'cadet' WHERE id = (SELECT cid FROM fx);
SELECT pg_temp.ok(can_use_class_channel('class:' || (SELECT cid FROM fx)), 'teacher may use the live lesson channel');

-- ── A second teacher sees nothing of the first class ──
SELECT pg_temp.act_as('user_t2');
SELECT pg_temp.ok((SELECT role FROM ensure_profile('teacher', 'Mr Nassar')) = 'teacher', 'second teacher signs up');
SELECT pg_temp.ok((SELECT count(*) FROM attempts) = 0 AND (SELECT count(*) FROM profiles) = 1, 'other teachers see no students');
SELECT pg_temp.ok(pg_temp.fails($$SELECT * FROM class_overview((SELECT cid FROM fx))$$), 'other teachers cannot open the class dashboard');
SELECT pg_temp.ok(NOT can_use_class_channel('class:' || (SELECT cid FROM fx)), 'other teachers cannot join the live channel');
WITH u AS (UPDATE classes SET name = 'x' WHERE id = (SELECT cid FROM fx) RETURNING 1)
SELECT pg_temp.ok((SELECT count(*) FROM u) = 0, 'other teachers cannot rename the class');
SELECT pg_temp.ok(pg_temp.fails($$INSERT INTO nudges (class_id, student_id, kind) SELECT cid, 'user_s2', 'hint' FROM fx$$), 'other teachers cannot nudge');

-- ── Student side of teacher tools ──
SELECT pg_temp.act_as('user_s2');
SELECT pg_temp.ok((SELECT count(*) FROM assignments) = 2, 'student sees class-wide and own assignments');
SELECT pg_temp.ok((SELECT count(*) FROM class_goals) = 1, 'student sees class goals');
UPDATE nudges SET seen_at = now();
SELECT pg_temp.ok((SELECT seen_at IS NOT NULL FROM nudges), 'student marks a nudge seen');
SELECT pg_temp.ok(pg_temp.fails($$UPDATE nudges SET kind = 'hint'$$), 'student cannot change a nudge');
SELECT pg_temp.ok(can_use_class_channel('class:' || (SELECT cid FROM fx)), 'class member may use the live lesson channel');
SELECT pg_temp.ok(NOT can_use_class_channel('class:not-a-uuid'), 'malformed channel names are refused');
SELECT pg_temp.ok((SELECT count(*) FROM my_classes()) = 1, 'my_classes lists the class with its teacher');
SELECT pg_temp.act_as('user_s1');
SELECT pg_temp.ok((SELECT count(*) FROM assignments) = 1, 'a per-student assignment is private to that student');

-- ── Co-op as guests (not signed in) ──
SELECT pg_temp.act_as(NULL);
SELECT pg_temp.ok((SELECT count(*) FROM levels) = 70, 'guests read the level catalogue');
SELECT pg_temp.ok(pg_temp.fails($$SELECT * FROM profiles$$), 'guests cannot read profiles');
SELECT pg_temp.ok(pg_temp.fails($$SELECT * FROM attempts$$), 'guests cannot read attempts');
SELECT pg_temp.ok(pg_temp.fails($$SELECT * FROM coop_rooms$$), 'guests cannot list co-op rooms');
SELECT pg_temp.ok(pg_temp.fails($$SELECT * FROM create_coop_room('cadet-01')$$), 'only co-op missions can open a room');
CREATE TEMP TABLE room AS SELECT * FROM create_coop_room('coop-07');
SELECT pg_temp.ok((SELECT code ~ '^[0-9]{4}$' FROM room), 'guest host gets a 4-digit room code');
SELECT pg_temp.ok((SELECT mission_id FROM join_coop_room((SELECT code FROM room))) = 'coop-07', 'a guest joins by code');
SELECT set_coop_status((SELECT room_id FROM room), 'done');
SELECT pg_temp.ok(pg_temp.fails($$SELECT * FROM join_coop_room((SELECT code FROM room))$$), 'a finished room cannot be joined');
RESET ROLE;
-- the code is free again once the room is done
INSERT INTO coop_rooms (code, mission_id, status) SELECT code, 'coop-07', 'lobby' FROM room;
SELECT pg_temp.ok((SELECT count(*) FROM coop_rooms WHERE code = (SELECT code FROM room)) = 2, 'codes are reused after a room is done');
SELECT pg_temp.ok(pg_temp.fails($$INSERT INTO coop_rooms (code, mission_id) SELECT code, 'coop-07' FROM room$$), 'two open rooms cannot share a code');

-- ── Co-op result recorded by a signed-in host ──
SELECT pg_temp.act_as('user_s2');
INSERT INTO coop_results (mission_id, players, roles, outcome, stars, duration_s, mistakes)
VALUES ('coop-01', ARRAY['user_s2', 'user_s1'], '{"astronaut":"Omar","capcom":"Rana"}', 'complete', 3, 240, 0);
SELECT pg_temp.ok(pg_temp.fails($$INSERT INTO coop_results (mission_id, host_id, players, roles, outcome) VALUES ('coop-01', 'user_s1', ARRAY['user_s1'], '{}', 'complete')$$),
                  'cannot record a result as someone else');
SELECT pg_temp.act_as('user_s1');
SELECT pg_temp.ok((SELECT count(*) FROM coop_results) = 1, 'every listed player sees the co-op result');
SELECT pg_temp.act_as('user_t1');
SELECT pg_temp.ok((SELECT count(*) FROM coop_results) = 1, 'their teacher sees it too');

-- ── Account deletion (clerk-webhook, service role) removes everything ──
RESET ROLE;
DELETE FROM profiles WHERE id = 'user_s2';
SELECT pg_temp.ok((SELECT count(*) FROM attempts WHERE user_id = 'user_s2') = 0
              AND (SELECT count(*) FROM skill_events WHERE user_id = 'user_s2') = 0
              AND (SELECT count(*) FROM class_members WHERE student_id = 'user_s2') = 0
              AND (SELECT count(*) FROM nudges WHERE student_id = 'user_s2') = 0, 'deleting an account removes all of its data');

\echo ALL RLS TESTS PASSED
