-- Shackleton Station 2.0 · 0002_security
-- Everything Prisma cannot express: check constraints, helper functions, triggers,
-- the skills view, row-level security, teacher dashboard functions, co-op rooms and
-- Realtime channel rules.
--
-- Roles (Supabase): anon = not signed in, authenticated = any signed-in Clerk user
-- (Clerk's Supabase integration adds "role": "authenticated" to the session token),
-- service_role = Edge Functions only, bypasses RLS.

-- ═══ 1. Check constraints ════════════════════════════════════════════════

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_display_name_len CHECK (char_length(btrim(display_name)) BETWEEN 2 AND 24),
  ADD CONSTRAINT profiles_avatar_valid     CHECK (avatar ~ '^[a-z0-9_]{2,24}$'),
  ADD CONSTRAINT profiles_username_valid   CHECK (username IS NULL OR username ~ '^[a-z0-9_]{4,32}$');

ALTER TABLE public.classes
  ADD CONSTRAINT classes_name_len        CHECK (char_length(btrim(name)) BETWEEN 1 AND 40),
  ADD CONSTRAINT classes_join_code_valid CHECK (join_code ~ '^[A-Z0-9]{6}$');

ALTER TABLE public.levels
  ADD CONSTRAINT levels_id_valid     CHECK (id ~ '^[a-z]+-[0-9]{2}$'),
  ADD CONSTRAINT levels_number_valid CHECK (number BETWEEN 1 AND 99);

ALTER TABLE public.level_progress
  ADD CONSTRAINT level_progress_stars CHECK (best_stars BETWEEN 0 AND 3),
  ADD CONSTRAINT level_progress_attempts CHECK (attempts >= 0);

ALTER TABLE public.attempts
  ADD CONSTRAINT attempts_outcome  CHECK (outcome IS NULL OR outcome IN ('complete', 'failed', 'quit')),
  ADD CONSTRAINT attempts_stars    CHECK (stars IS NULL OR stars BETWEEN 0 AND 3),
  ADD CONSTRAINT attempts_counts   CHECK (mistakes BETWEEN 0 AND 999 AND hints BETWEEN 0 AND 999),
  ADD CONSTRAINT attempts_duration CHECK (duration_s IS NULL OR duration_s BETWEEN 0 AND 86400),
  ADD CONSTRAINT attempts_times    CHECK (ended_at IS NULL OR ended_at >= started_at),
  ADD CONSTRAINT attempts_decisions_array CHECK (jsonb_typeof(decisions) = 'array');

ALTER TABLE public.campaign_state
  ADD CONSTRAINT campaign_state_carry_object CHECK (jsonb_typeof(carry) = 'object'),
  ADD CONSTRAINT campaign_state_level CHECK (current_level BETWEEN 1 AND 99);

ALTER TABLE public.assessments
  ADD CONSTRAINT assessments_kind  CHECK (kind IN ('pre', 'post')),
  ADD CONSTRAINT assessments_score CHECK (max_score > 0 AND score BETWEEN 0 AND max_score),
  ADD CONSTRAINT assessments_answers_array CHECK (jsonb_typeof(answers) = 'array');

ALTER TABLE public.fact_unlocks
  ADD CONSTRAINT fact_unlocks_id_valid CHECK (fact_id ~ '^[a-z0-9_:.-]{1,64}$');

ALTER TABLE public.settings
  ADD CONSTRAINT settings_text_speed CHECK (text_speed BETWEEN 0.5 AND 2.0);

ALTER TABLE public.class_goals
  ADD CONSTRAINT class_goals_title_len CHECK (char_length(btrim(title)) BETWEEN 1 AND 60),
  ADD CONSTRAINT class_goals_target CHECK (target BETWEEN 1 AND 100),
  ADD CONSTRAINT class_goals_kind CHECK (skill IS NOT NULL OR level_id IS NOT NULL);

ALTER TABLE public.assignments
  ADD CONSTRAINT assignments_note_len CHECK (note IS NULL OR char_length(note) <= 120);

ALTER TABLE public.nudges
  ADD CONSTRAINT nudges_kind CHECK (kind IN ('hint', 'replay', 'reminder', 'well_done'));

ALTER TABLE public.coop_rooms
  ADD CONSTRAINT coop_rooms_code   CHECK (code ~ '^[0-9]{4}$'),
  ADD CONSTRAINT coop_rooms_status CHECK (status IN ('lobby', 'playing', 'done'));

ALTER TABLE public.coop_results
  ADD CONSTRAINT coop_results_outcome CHECK (outcome IN ('complete', 'failed')),
  ADD CONSTRAINT coop_results_stars   CHECK (stars IS NULL OR stars BETWEEN 0 AND 3),
  ADD CONSTRAINT coop_results_roles_object CHECK (jsonb_typeof(roles) = 'object');

ALTER TABLE public.space_weather
  ADD CONSTRAINT space_weather_level CHECK (level IN ('calm', 'watch', 'storm'));

-- ═══ 2. Helper functions ═════════════════════════════════════════════════
-- SECURITY DEFINER helpers read across tables without tripping RLS recursion.
-- Each one only ever answers a yes/no question about the caller.

CREATE OR REPLACE FUNCTION public.my_role() RETURNS public.user_role
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT role FROM profiles WHERE id = public.uid() $$;

CREATE OR REPLACE FUNCTION public.is_teacher() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT coalesce((SELECT role IN ('teacher', 'admin') FROM profiles WHERE id = public.uid()), false) $$;

-- Does the caller teach this class?
CREATE OR REPLACE FUNCTION public.teaches(cid uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM classes WHERE id = cid AND teacher_id = public.uid()) $$;

-- Is the caller a student in this class?
CREATE OR REPLACE FUNCTION public.is_member_of(cid uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM class_members WHERE class_id = cid AND student_id = public.uid()) $$;

-- Is the caller the teacher of this student (in any class)?
CREATE OR REPLACE FUNCTION public.is_teacher_of(student text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM class_members m JOIN classes c ON c.id = m.class_id
                 WHERE m.student_id = student AND c.teacher_id = public.uid()) $$;

-- Is this student in this class? (used by teacher-side checks)
CREATE OR REPLACE FUNCTION public.student_in_class(student text, cid uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM class_members WHERE class_id = cid AND student_id = student) $$;

-- Is the caller in a class that locks the age level?
CREATE OR REPLACE FUNCTION public.age_mode_locked(student text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM class_members m JOIN classes c ON c.id = m.class_id
                 WHERE m.student_id = student AND NOT c.archived) $$;

-- Is the request coming from an end user (not an Edge Function or a migration)?
CREATE OR REPLACE FUNCTION public.is_end_user() RETURNS boolean
LANGUAGE sql STABLE AS $$ SELECT current_user IN ('anon', 'authenticated') $$;

-- ═══ 3. Triggers ═════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.touch_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$ BEGIN NEW.updated_at := now(); RETURN NEW; END $$;

CREATE TRIGGER profiles_touch BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER level_progress_touch BEFORE UPDATE ON public.level_progress
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER campaign_state_touch BEFORE UPDATE ON public.campaign_state
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER settings_touch BEFORE UPDATE ON public.settings
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- Users may edit their own name and avatar, never their role, username or creator.
-- A student in a class keeps the class's age level (the teacher sets it).
CREATE OR REPLACE FUNCTION public.guard_profile() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NOT public.is_end_user() THEN RETURN NEW; END IF;
  IF TG_OP = 'INSERT' THEN
    IF NEW.role NOT IN ('student', 'teacher') THEN
      RAISE EXCEPTION 'Not allowed to create a % profile', NEW.role USING ERRCODE = '42501';
    END IF;
    NEW.username := NULL;
    NEW.created_by := NULL;
    RETURN NEW;
  END IF;
  IF NEW.role IS DISTINCT FROM OLD.role
     OR NEW.username IS DISTINCT FROM OLD.username
     OR NEW.created_by IS DISTINCT FROM OLD.created_by
     OR NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'Role, username and id cannot be changed here' USING ERRCODE = '42501';
  END IF;
  IF NEW.age_mode IS DISTINCT FROM OLD.age_mode AND public.age_mode_locked(OLD.id) THEN
    NEW.age_mode := OLD.age_mode;  -- quietly keep the class's age level
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER profiles_guard BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.guard_profile();

-- Every finished attempt updates level_progress (best stars, play count, first completion).
-- Runs as owner so the app never writes level_progress directly.
CREATE OR REPLACE FUNCTION public.record_attempt() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO level_progress (user_id, level_id, best_stars, attempts, completed_at)
  VALUES (NEW.user_id, NEW.level_id,
          CASE WHEN NEW.outcome = 'complete' THEN coalesce(NEW.stars, 0) ELSE 0 END,
          1,
          CASE WHEN NEW.outcome = 'complete' THEN coalesce(NEW.ended_at, now()) END)
  ON CONFLICT (user_id, level_id) DO UPDATE SET
    attempts     = level_progress.attempts + 1,
    best_stars   = greatest(level_progress.best_stars, EXCLUDED.best_stars),
    completed_at = coalesce(level_progress.completed_at, EXCLUDED.completed_at);
  RETURN NEW;
END $$;

CREATE TRIGGER attempts_record AFTER INSERT ON public.attempts
  FOR EACH ROW EXECUTE FUNCTION public.record_attempt();

-- When the teacher changes the class age level, every student in it follows.
CREATE OR REPLACE FUNCTION public.sync_class_age_mode() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.age_mode IS DISTINCT FROM OLD.age_mode THEN
    UPDATE profiles p SET age_mode = NEW.age_mode
    FROM class_members m WHERE m.class_id = NEW.id AND m.student_id = p.id;
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER classes_age_mode AFTER UPDATE OF age_mode ON public.classes
  FOR EACH ROW EXECUTE FUNCTION public.sync_class_age_mode();

-- Only teachers create classes, and only for themselves; the join code is never chosen by hand.
CREATE OR REPLACE FUNCTION public.guard_class() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NOT public.is_end_user() THEN RETURN NEW; END IF;
  IF TG_OP = 'INSERT' THEN
    IF NOT public.is_teacher() THEN
      RAISE EXCEPTION 'Only teachers can create classes' USING ERRCODE = '42501';
    END IF;
    NEW.teacher_id := public.uid();
    NEW.join_code := public.new_join_code();
  ELSIF NEW.teacher_id IS DISTINCT FROM OLD.teacher_id THEN
    RAISE EXCEPTION 'A class cannot change teacher here' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER classes_guard BEFORE INSERT OR UPDATE ON public.classes
  FOR EACH ROW EXECUTE FUNCTION public.guard_class();

-- Co-op: open_code mirrors code while the room is open, so codes are unique only among open rooms.
CREATE OR REPLACE FUNCTION public.coop_room_open_code() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.open_code := CASE WHEN NEW.status <> 'done' THEN NEW.code END;
  RETURN NEW;
END $$;

CREATE TRIGGER coop_rooms_open_code BEFORE INSERT OR UPDATE ON public.coop_rooms
  FOR EACH ROW EXECUTE FUNCTION public.coop_room_open_code();

-- ═══ 4. Skills map ═══════════════════════════════════════════════════════
-- Mastery = share of correct decisions in the last 20 pieces of evidence per skill.

CREATE VIEW public.skill_mastery WITH (security_invoker = true) AS
SELECT user_id, skill,
       round(100.0 * avg(correct::int))::int AS score,
       count(*)::int AS evidence
FROM (SELECT user_id, skill, correct,
             row_number() OVER (PARTITION BY user_id, skill ORDER BY created_at DESC, id DESC) AS rn
      FROM public.skill_events) s
WHERE rn <= 20
GROUP BY user_id, skill;

-- ═══ 5. Row-level security ═══════════════════════════════════════════════

ALTER TABLE public.profiles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classes        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_members  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.levels         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.level_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attempts       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skill_events   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaign_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assessments    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fact_unlocks   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignments    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_goals    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nudges         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coop_rooms     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coop_results   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.space_weather  ENABLE ROW LEVEL SECURITY;

-- Table privileges: guests (anon) only read the catalogue and space weather.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
GRANT SELECT ON public.levels, public.space_weather TO anon;
GRANT SELECT ON public.skill_mastery TO authenticated;

-- profiles
CREATE POLICY "own profile: read"   ON public.profiles FOR SELECT TO authenticated
  USING (id = (SELECT public.uid()));
CREATE POLICY "own profile: create" ON public.profiles FOR INSERT TO authenticated
  WITH CHECK (id = (SELECT public.uid()));
CREATE POLICY "own profile: edit"   ON public.profiles FOR UPDATE TO authenticated
  USING (id = (SELECT public.uid())) WITH CHECK (id = (SELECT public.uid()));
CREATE POLICY "teachers read their students" ON public.profiles FOR SELECT TO authenticated
  USING (public.is_teacher_of(id));
REVOKE DELETE ON public.profiles FROM authenticated;  -- account deletion goes through Clerk

-- classes
CREATE POLICY "teacher reads own classes"   ON public.classes FOR SELECT TO authenticated
  USING (teacher_id = (SELECT public.uid()));
CREATE POLICY "teacher creates classes"     ON public.classes FOR INSERT TO authenticated
  WITH CHECK (teacher_id = (SELECT public.uid()));
CREATE POLICY "teacher edits own classes"   ON public.classes FOR UPDATE TO authenticated
  USING (teacher_id = (SELECT public.uid())) WITH CHECK (teacher_id = (SELECT public.uid()));
CREATE POLICY "teacher deletes own classes" ON public.classes FOR DELETE TO authenticated
  USING (teacher_id = (SELECT public.uid()));
CREATE POLICY "members read their class"    ON public.classes FOR SELECT TO authenticated
  USING (public.is_member_of(id));

-- class_members: joining goes through join_class(); teachers can remove students
CREATE POLICY "student reads own memberships" ON public.class_members FOR SELECT TO authenticated
  USING (student_id = (SELECT public.uid()));
CREATE POLICY "teacher reads class roster"    ON public.class_members FOR SELECT TO authenticated
  USING (public.teaches(class_id));
CREATE POLICY "teacher removes students"      ON public.class_members FOR DELETE TO authenticated
  USING (public.teaches(class_id));
REVOKE INSERT, UPDATE ON public.class_members FROM authenticated;

-- levels: the catalogue is public and read-only
CREATE POLICY "catalogue is public" ON public.levels FOR SELECT TO anon, authenticated USING (true);
REVOKE INSERT, UPDATE, DELETE ON public.levels FROM authenticated;

-- level_progress: written only by the attempts trigger
CREATE POLICY "own progress"            ON public.level_progress FOR SELECT TO authenticated
  USING (user_id = (SELECT public.uid()));
CREATE POLICY "teachers read progress"  ON public.level_progress FOR SELECT TO authenticated
  USING (public.is_teacher_of(user_id));
REVOKE INSERT, UPDATE, DELETE ON public.level_progress FROM authenticated;

-- attempts: insert and read own; history cannot be rewritten
CREATE POLICY "own attempts: read"    ON public.attempts FOR SELECT TO authenticated
  USING (user_id = (SELECT public.uid()));
CREATE POLICY "own attempts: add"     ON public.attempts FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT public.uid()));
CREATE POLICY "teachers read attempts" ON public.attempts FOR SELECT TO authenticated
  USING (public.is_teacher_of(user_id));
REVOKE UPDATE, DELETE ON public.attempts FROM authenticated;

-- skill_events: insert own, linked to an own attempt
CREATE POLICY "own skill events: read" ON public.skill_events FOR SELECT TO authenticated
  USING (user_id = (SELECT public.uid()));
CREATE POLICY "own skill events: add"  ON public.skill_events FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT public.uid())
              AND (attempt_id IS NULL OR EXISTS (SELECT 1 FROM public.attempts a
                   WHERE a.id = attempt_id AND a.user_id = (SELECT public.uid()))));
CREATE POLICY "teachers read skill events" ON public.skill_events FOR SELECT TO authenticated
  USING (public.is_teacher_of(user_id));
REVOKE UPDATE, DELETE ON public.skill_events FROM authenticated;

-- campaign_state
CREATE POLICY "own campaign state" ON public.campaign_state FOR ALL TO authenticated
  USING (user_id = (SELECT public.uid())) WITH CHECK (user_id = (SELECT public.uid()));
CREATE POLICY "teachers read campaign state" ON public.campaign_state FOR SELECT TO authenticated
  USING (public.is_teacher_of(user_id));

-- assessments
CREATE POLICY "own assessments: read" ON public.assessments FOR SELECT TO authenticated
  USING (user_id = (SELECT public.uid()));
CREATE POLICY "own assessments: add"  ON public.assessments FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT public.uid()));
CREATE POLICY "teachers read assessments" ON public.assessments FOR SELECT TO authenticated
  USING (public.is_teacher_of(user_id));
REVOKE UPDATE, DELETE ON public.assessments FROM authenticated;

-- fact_unlocks
CREATE POLICY "own facts" ON public.fact_unlocks FOR ALL TO authenticated
  USING (user_id = (SELECT public.uid())) WITH CHECK (user_id = (SELECT public.uid()));
CREATE POLICY "teachers read facts" ON public.fact_unlocks FOR SELECT TO authenticated
  USING (public.is_teacher_of(user_id));

-- settings
CREATE POLICY "own settings" ON public.settings FOR ALL TO authenticated
  USING (user_id = (SELECT public.uid())) WITH CHECK (user_id = (SELECT public.uid()));

-- assignments: the class teacher manages; students see whole-class ones and their own
CREATE POLICY "teacher manages assignments" ON public.assignments FOR ALL TO authenticated
  USING (public.teaches(class_id))
  WITH CHECK (public.teaches(class_id)
              AND (student_id IS NULL OR public.student_in_class(student_id, class_id)));
CREATE POLICY "students read assignments" ON public.assignments FOR SELECT TO authenticated
  USING (public.is_member_of(class_id) AND (student_id IS NULL OR student_id = (SELECT public.uid())));

-- class_goals
CREATE POLICY "teacher manages goals" ON public.class_goals FOR ALL TO authenticated
  USING (public.teaches(class_id)) WITH CHECK (public.teaches(class_id));
CREATE POLICY "students read goals"   ON public.class_goals FOR SELECT TO authenticated
  USING (public.is_member_of(class_id));

-- nudges: preset messages only; the student may only mark them seen
CREATE POLICY "teacher sends nudges"  ON public.nudges FOR INSERT TO authenticated
  WITH CHECK (public.teaches(class_id) AND public.student_in_class(student_id, class_id));
CREATE POLICY "teacher reads nudges"  ON public.nudges FOR SELECT TO authenticated
  USING (public.teaches(class_id));
CREATE POLICY "teacher deletes nudges" ON public.nudges FOR DELETE TO authenticated
  USING (public.teaches(class_id));
CREATE POLICY "student reads own nudges" ON public.nudges FOR SELECT TO authenticated
  USING (student_id = (SELECT public.uid()));
CREATE POLICY "student marks nudges seen" ON public.nudges FOR UPDATE TO authenticated
  USING (student_id = (SELECT public.uid())) WITH CHECK (student_id = (SELECT public.uid()));
REVOKE UPDATE ON public.nudges FROM authenticated;
GRANT UPDATE (seen_at) ON public.nudges TO authenticated;

-- coop_rooms: no direct access; use create_coop_room / join_coop_room / set_coop_status
REVOKE ALL ON public.coop_rooms FROM authenticated;

-- coop_results: the host records the result; players and their teachers read it
CREATE POLICY "host records co-op result" ON public.coop_results FOR INSERT TO authenticated
  WITH CHECK (host_id = (SELECT public.uid()) AND (SELECT public.uid()) = ANY (players));
CREATE POLICY "players read co-op results" ON public.coop_results FOR SELECT TO authenticated
  USING ((SELECT public.uid()) = ANY (players)
         OR EXISTS (SELECT 1 FROM unnest(players) p WHERE public.is_teacher_of(p)));
REVOKE UPDATE, DELETE ON public.coop_results FROM authenticated;

-- space_weather: public read, written by the space-weather Edge Function
CREATE POLICY "space weather is public" ON public.space_weather FOR SELECT TO anon, authenticated USING (true);
REVOKE INSERT, UPDATE, DELETE ON public.space_weather FROM authenticated;

-- ═══ 6. App functions (RPC) ══════════════════════════════════════════════

-- First sign-in: create the caller's profile if it does not exist yet. Teachers sign
-- themselves up; student accounts are made by the create-students Edge Function.
CREATE OR REPLACE FUNCTION public.ensure_profile(
  p_role public.user_role DEFAULT 'student',
  p_display_name text DEFAULT NULL,
  p_avatar text DEFAULT 'nova',
  p_age_mode public.age_mode DEFAULT 'explorer')
RETURNS public.profiles
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public AS $$
DECLARE me public.profiles;
BEGIN
  IF public.uid() IS NULL THEN
    RAISE EXCEPTION 'Sign in first' USING ERRCODE = '28000';
  END IF;
  SELECT * INTO me FROM profiles WHERE id = public.uid();
  IF FOUND THEN RETURN me; END IF;
  INSERT INTO profiles (id, role, display_name, avatar, age_mode)
  VALUES (public.uid(), p_role,
          coalesce(nullif(btrim(p_display_name), ''), CASE WHEN p_role = 'teacher' THEN 'Teacher' ELSE 'Cadet' END),
          coalesce(p_avatar, 'nova'), coalesce(p_age_mode, 'explorer'))
  ON CONFLICT (id) DO NOTHING;
  SELECT * INTO me FROM profiles WHERE id = public.uid();
  RETURN me;
END $$;

-- Offline sync: store one finished attempt and its skill evidence in one go.
-- Idempotent on client_id, so the app can safely retry after a lost connection.
CREATE OR REPLACE FUNCTION public.submit_attempt(attempt jsonb, skills jsonb DEFAULT '[]'::jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public AS $$
DECLARE aid uuid; cid uuid := (attempt ->> 'client_id')::uuid;
BEGIN
  IF public.uid() IS NULL THEN RAISE EXCEPTION 'Sign in first' USING ERRCODE = '28000'; END IF;
  IF jsonb_typeof(skills) <> 'array' OR jsonb_array_length(skills) > 200 THEN
    RAISE EXCEPTION 'Bad skill list' USING ERRCODE = '22023';
  END IF;
  INSERT INTO attempts (client_id, user_id, level_id, age_mode, started_at, ended_at, outcome,
                        stars, mistakes, hints, duration_s, decisions)
  VALUES (cid, public.uid(), attempt ->> 'level_id', (attempt ->> 'age_mode')::public.age_mode,
          (attempt ->> 'started_at')::timestamptz, (attempt ->> 'ended_at')::timestamptz, attempt ->> 'outcome',
          (attempt ->> 'stars')::smallint, coalesce((attempt ->> 'mistakes')::smallint, 0),
          coalesce((attempt ->> 'hints')::smallint, 0), (attempt ->> 'duration_s')::int,
          coalesce(attempt -> 'decisions', '[]'::jsonb))
  ON CONFLICT (client_id) DO NOTHING
  RETURNING id INTO aid;
  IF aid IS NULL THEN  -- already synced earlier, together with its skill events
    SELECT a.id INTO aid FROM attempts a WHERE a.client_id = cid AND a.user_id = public.uid();
    RETURN aid;
  END IF;
  INSERT INTO skill_events (attempt_id, user_id, skill, correct)
  SELECT aid, public.uid(), (e ->> 'skill')::public.skill, (e ->> 'correct')::boolean
  FROM jsonb_array_elements(skills) e;
  RETURN aid;
END $$;

-- A student joins a class by its code and from then on plays the teacher's age level.
CREATE OR REPLACE FUNCTION public.join_class(code text)
RETURNS TABLE (class_id uuid, class_name text, age_mode public.age_mode, lock_rank boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE c classes;
BEGIN
  IF public.uid() IS NULL THEN RAISE EXCEPTION 'Sign in first' USING ERRCODE = '28000'; END IF;
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = public.uid()) THEN
    RAISE EXCEPTION 'Create your profile first' USING ERRCODE = 'P0002';
  END IF;
  SELECT * INTO c FROM classes
   WHERE join_code = upper(regexp_replace(code, '[^A-Za-z0-9]', '', 'g')) AND NOT archived;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unknown class code' USING ERRCODE = 'P0002'; END IF;
  IF c.teacher_id = public.uid() THEN RAISE EXCEPTION 'You teach this class' USING ERRCODE = '22023'; END IF;
  INSERT INTO class_members (class_id, student_id) VALUES (c.id, public.uid()) ON CONFLICT DO NOTHING;
  UPDATE profiles SET age_mode = c.age_mode WHERE id = public.uid();
  RETURN QUERY SELECT c.id, c.name, c.age_mode, c.lock_rank;
END $$;

CREATE OR REPLACE FUNCTION public.leave_class(cid uuid) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  DELETE FROM class_members WHERE class_id = cid AND student_id = public.uid() $$;

-- The caller's classes (as a student) with the teacher's display name.
CREATE OR REPLACE FUNCTION public.my_classes()
RETURNS TABLE (class_id uuid, class_name text, age_mode public.age_mode, lock_rank boolean, teacher_name text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT c.id, c.name, c.age_mode, c.lock_rank, t.display_name
  FROM class_members m JOIN classes c ON c.id = m.class_id JOIN profiles t ON t.id = c.teacher_id
  WHERE m.student_id = public.uid() AND NOT c.archived
  ORDER BY m.joined_at DESC $$;

CREATE OR REPLACE FUNCTION public.require_teacher_of_class(cid uuid) RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.teaches(cid) THEN
    RAISE EXCEPTION 'Not your class' USING ERRCODE = '42501';
  END IF;
END $$;

-- ── Teacher dashboard ────────────────────────────────────────────────────

-- Today / Class tabs: the headline numbers for one class.
CREATE OR REPLACE FUNCTION public.class_overview(cid uuid)
RETURNS TABLE (
  students int, active_today int, active_week int,
  levels_total int, avg_levels_done numeric, avg_stars numeric,
  pre_avg numeric, post_avg numeric, gain_points numeric,
  weakest_skill public.skill, strongest_skill public.skill, needs_help int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE camp public.campaign;
BEGIN
  PERFORM public.require_teacher_of_class(cid);
  SELECT c.age_mode::text::public.campaign INTO camp FROM classes c WHERE c.id = cid;
  RETURN QUERY
  WITH s AS (SELECT student_id FROM class_members WHERE class_id = cid),
  done AS (
    SELECT p.user_id, count(*) FILTER (WHERE p.completed_at IS NOT NULL) AS n,
           avg(p.best_stars) FILTER (WHERE p.completed_at IS NOT NULL) AS stars
    FROM level_progress p JOIN s ON s.student_id = p.user_id
    JOIN levels l ON l.id = p.level_id AND l.campaign = camp
    GROUP BY p.user_id),
  a AS (
    SELECT x.user_id,
           (SELECT 100.0 * y.score / y.max_score FROM assessments y
             WHERE y.user_id = x.user_id AND y.campaign = camp AND y.kind = 'pre'
             ORDER BY y.taken_at ASC LIMIT 1) AS pre,
           (SELECT 100.0 * y.score / y.max_score FROM assessments y
             WHERE y.user_id = x.user_id AND y.campaign = camp AND y.kind = 'post'
             ORDER BY y.taken_at DESC LIMIT 1) AS post
    FROM s x(user_id)),
  sk AS (
    SELECT m.skill, avg(m.score) AS score FROM skill_mastery m JOIN s ON s.student_id = m.user_id
    GROUP BY m.skill),
  act AS (
    SELECT t.user_id, max(t.started_at) AS last FROM attempts t JOIN s ON s.student_id = t.user_id
    GROUP BY t.user_id)
  SELECT
    (SELECT count(*) FROM s)::int,
    (SELECT count(*) FROM act WHERE last >= date_trunc('day', now()))::int,
    (SELECT count(*) FROM act WHERE last >= now() - interval '7 days')::int,
    (SELECT count(*) FROM levels WHERE campaign = camp)::int,
    coalesce((SELECT round(avg(coalesce(d.n, 0)), 1) FROM s LEFT JOIN done d ON d.user_id = s.student_id), 0),
    (SELECT round(avg(stars), 1) FROM done),
    (SELECT round(avg(pre), 0) FROM a),
    (SELECT round(avg(post), 0) FROM a),
    (SELECT round(avg(post - pre), 0) FROM a WHERE pre IS NOT NULL AND post IS NOT NULL),
    (SELECT skill FROM sk ORDER BY score ASC, skill LIMIT 1),
    (SELECT skill FROM sk ORDER BY score DESC, skill LIMIT 1),
    (SELECT count(*) FROM public.class_students(cid) cs WHERE cs.needs_help)::int;
END $$;

-- Students tab and the needs-help list: one row per student.
CREATE OR REPLACE FUNCTION public.class_students(cid uuid)
RETURNS TABLE (
  student_id text, display_name text, avatar text, username text,
  levels_done int, stars int, current_level int, last_active timestamptz,
  attempts_week int, hints_week int, fails_recent int,
  pre_score int, post_score int, needs_help boolean, help_reason text, stuck_level text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE camp public.campaign;
BEGIN
  PERFORM public.require_teacher_of_class(cid);
  SELECT c.age_mode::text::public.campaign INTO camp FROM classes c WHERE c.id = cid;
  RETURN QUERY
  WITH s AS (
    SELECT p.id, p.display_name, p.avatar, p.username
    FROM class_members m JOIN profiles p ON p.id = m.student_id WHERE m.class_id = cid),
  prog AS (
    SELECT lp.user_id,
           count(*) FILTER (WHERE lp.completed_at IS NOT NULL)::int AS done,
           coalesce(sum(lp.best_stars), 0)::int AS stars
    FROM level_progress lp JOIN levels l ON l.id = lp.level_id AND l.campaign = camp
    WHERE lp.user_id IN (SELECT id FROM s) GROUP BY lp.user_id),
  recent AS (
    SELECT t.user_id, t.level_id, t.outcome, t.hints, t.started_at,
           row_number() OVER (PARTITION BY t.user_id ORDER BY t.started_at DESC) AS rn
    FROM attempts t WHERE t.user_id IN (SELECT id FROM s)),
  agg AS (
    SELECT r.user_id,
           max(r.started_at) AS last,
           count(*) FILTER (WHERE r.started_at >= now() - interval '7 days')::int AS att_week,
           coalesce(sum(r.hints) FILTER (WHERE r.started_at >= now() - interval '7 days'), 0)::int AS hints_week,
           count(*) FILTER (WHERE r.rn <= 3 AND r.outcome IN ('failed', 'quit'))::int AS fails,
           (array_agg(r.level_id ORDER BY r.started_at DESC))[1] AS last_level
    FROM recent r GROUP BY r.user_id),
  cs AS (
    SELECT st.user_id, st.current_level FROM campaign_state st
    WHERE st.campaign = camp AND st.user_id IN (SELECT id FROM s)),
  asm AS (
    SELECT y.user_id,
           max(CASE WHEN y.kind = 'pre'  THEN round(100.0 * y.score / y.max_score) END)::int AS pre,
           max(CASE WHEN y.kind = 'post' THEN round(100.0 * y.score / y.max_score) END)::int AS post
    FROM assessments y WHERE y.campaign = camp AND y.user_id IN (SELECT id FROM s) GROUP BY y.user_id)
  SELECT s.id, s.display_name, s.avatar, s.username,
         coalesce(prog.done, 0), coalesce(prog.stars, 0), coalesce(cs.current_level, 1)::int, agg.last,
         coalesce(agg.att_week, 0), coalesce(agg.hints_week, 0), coalesce(agg.fails, 0),
         asm.pre, asm.post,
         (coalesce(agg.fails, 0) >= 2 OR coalesce(agg.hints_week, 0) >= 6
          OR (agg.last IS NOT NULL AND agg.last < now() - interval '7 days')),
         CASE WHEN coalesce(agg.fails, 0) >= 2 THEN 'stuck'
              WHEN coalesce(agg.hints_week, 0) >= 6 THEN 'many_hints'
              WHEN agg.last IS NOT NULL AND agg.last < now() - interval '7 days' THEN 'inactive'
              WHEN agg.last IS NULL THEN 'not_started' END,
         CASE WHEN coalesce(agg.fails, 0) >= 2 THEN agg.last_level END
  FROM s LEFT JOIN prog ON prog.user_id = s.id LEFT JOIN agg ON agg.user_id = s.id
         LEFT JOIN cs ON cs.user_id = s.id LEFT JOIN asm ON asm.user_id = s.id
  ORDER BY (coalesce(agg.fails, 0) >= 2 OR coalesce(agg.hints_week, 0) >= 6) DESC, s.display_name;
END $$;

-- Class tab: average mastery per skill.
CREATE OR REPLACE FUNCTION public.class_skills(cid uuid)
RETURNS TABLE (skill public.skill, score int, students int, evidence int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.require_teacher_of_class(cid);
  RETURN QUERY
  SELECT k.skill, coalesce(round(avg(m.score)), 0)::int, count(m.user_id)::int, coalesce(sum(m.evidence), 0)::int
  FROM unnest(enum_range(NULL::public.skill)) k(skill)
  LEFT JOIN (SELECT sm.* FROM skill_mastery sm JOIN class_members cm
               ON cm.student_id = sm.user_id AND cm.class_id = cid) m ON m.skill = k.skill
  GROUP BY k.skill ORDER BY k.skill;
END $$;

-- Class tab / Lessons: how the class did on each level of its campaign.
CREATE OR REPLACE FUNCTION public.class_levels(cid uuid)
RETURNS TABLE (level_id text, number int, title text, finished int, playing int, avg_stars numeric, avg_mistakes numeric, avg_hints numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE camp public.campaign;
BEGIN
  PERFORM public.require_teacher_of_class(cid);
  SELECT c.age_mode::text::public.campaign INTO camp FROM classes c WHERE c.id = cid;
  RETURN QUERY
  WITH s AS (SELECT student_id FROM class_members WHERE class_id = cid)
  SELECT l.id, l.number::int, l.title,
         (SELECT count(*) FROM level_progress p JOIN s ON s.student_id = p.user_id
            WHERE p.level_id = l.id AND p.completed_at IS NOT NULL)::int,
         (SELECT count(*) FROM level_progress p JOIN s ON s.student_id = p.user_id
            WHERE p.level_id = l.id AND p.completed_at IS NULL)::int,
         (SELECT round(avg(p.best_stars), 1) FROM level_progress p JOIN s ON s.student_id = p.user_id
            WHERE p.level_id = l.id AND p.completed_at IS NOT NULL),
         (SELECT round(avg(t.mistakes), 1) FROM attempts t JOIN s ON s.student_id = t.user_id WHERE t.level_id = l.id),
         (SELECT round(avg(t.hints), 1) FROM attempts t JOIN s ON s.student_id = t.user_id WHERE t.level_id = l.id)
  FROM levels l WHERE l.campaign = camp ORDER BY l.number;
END $$;

-- Student detail: the student's skills next to the class average.
CREATE OR REPLACE FUNCTION public.student_skills(sid text, cid uuid)
RETURNS TABLE (skill public.skill, score int, class_avg int, evidence int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.require_teacher_of_class(cid);
  IF NOT public.student_in_class(sid, cid) THEN
    RAISE EXCEPTION 'Not in this class' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT k.skill,
         coalesce((SELECT m.score FROM skill_mastery m WHERE m.user_id = sid AND m.skill = k.skill), 0)::int,
         coalesce((SELECT round(avg(m.score)) FROM skill_mastery m JOIN class_members cm
                     ON cm.student_id = m.user_id AND cm.class_id = cid WHERE m.skill = k.skill), 0)::int,
         coalesce((SELECT m.evidence FROM skill_mastery m WHERE m.user_id = sid AND m.skill = k.skill), 0)::int
  FROM unnest(enum_range(NULL::public.skill)) k(skill) ORDER BY k.skill;
END $$;

-- ── Co-op rooms ──────────────────────────────────────────────────────────
-- Guests can play co-op too (anon), so these run as owner with their own checks.

CREATE OR REPLACE FUNCTION public.create_coop_room(mission text)
RETURNS TABLE (room_id uuid, code text, expires_at timestamptz)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE c text; r coop_rooms; tries int := 0;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM levels WHERE id = mission AND is_coop) THEN
    RAISE EXCEPTION 'Unknown co-op mission' USING ERRCODE = 'P0002';
  END IF;
  -- close rooms that ran out of time, so their codes can be reused
  UPDATE coop_rooms SET status = 'done' WHERE status <> 'done' AND coop_rooms.expires_at < now();
  LOOP
    tries := tries + 1;
    c := lpad(floor(random() * 10000)::int::text, 4, '0');
    BEGIN
      INSERT INTO coop_rooms (code, mission_id, host_id) VALUES (c, mission, public.uid()) RETURNING * INTO r;
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      IF tries > 40 THEN RAISE EXCEPTION 'No free room codes, try again' USING ERRCODE = '53000'; END IF;
    END;
  END LOOP;
  RETURN QUERY SELECT r.id, r.code, r.expires_at;
END $$;

CREATE OR REPLACE FUNCTION public.join_coop_room(room_code text)
RETURNS TABLE (room_id uuid, mission_id text, status text, expires_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN QUERY SELECT r.id, r.mission_id, r.status, r.expires_at FROM coop_rooms r
   WHERE r.open_code = btrim(room_code) AND r.expires_at > now();
  IF NOT FOUND THEN RAISE EXCEPTION 'No open room with that code' USING ERRCODE = 'P0002'; END IF;
END $$;

-- Room ids are random UUIDs only shared inside the room, so knowing one is the permission.
CREATE OR REPLACE FUNCTION public.set_coop_status(room uuid, new_status text) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF new_status NOT IN ('playing', 'done') THEN
    RAISE EXCEPTION 'Bad status' USING ERRCODE = '22023';
  END IF;
  UPDATE coop_rooms SET status = new_status WHERE id = room AND status <> 'done';
END $$;

-- ═══ 7. Function privileges ══════════════════════════════════════════════

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated, service_role;
-- Guests: co-op rooms only (uid() is needed inside the column defaults)
GRANT EXECUTE ON FUNCTION public.uid(), public.create_coop_room(text), public.join_coop_room(text),
  public.set_coop_status(uuid, text), public.is_end_user() TO anon;
-- Trigger functions and the internal helper are never called directly
REVOKE EXECUTE ON FUNCTION public.record_attempt(), public.sync_class_age_mode(),
  public.guard_profile(), public.guard_class(), public.coop_room_open_code(),
  public.touch_updated_at() FROM authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon;

-- ═══ 8. Realtime ═════════════════════════════════════════════════════════
-- Live lesson channel "class:<class uuid>" is private: only the teacher and the
-- students of that class can join, send or receive. Co-op channels "coop:<code>"
-- are public (guests play too) and carry game moves only, never personal data.

CREATE OR REPLACE FUNCTION public.can_use_class_channel(topic text) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE cid uuid;
BEGIN
  IF topic IS NULL OR topic !~ '^class:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RETURN false;
  END IF;
  cid := substr(topic, 7)::uuid;
  RETURN public.teaches(cid) OR public.is_member_of(cid);
END $$;
GRANT EXECUTE ON FUNCTION public.can_use_class_channel(text) TO authenticated;

CREATE POLICY "class channel: receive" ON realtime.messages FOR SELECT TO authenticated
  USING (public.can_use_class_channel((SELECT realtime.topic())));
CREATE POLICY "class channel: send" ON realtime.messages FOR INSERT TO authenticated
  WITH CHECK (public.can_use_class_channel((SELECT realtime.topic())));
