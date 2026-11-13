-- Base Commander (the Figma "Mission Trainer" game): finished missions,
-- badges and Supply Runs. Generated from prisma/schema.prisma, plus the
-- checks and row-level security below (same rules as attempts).

-- CreateTable
CREATE TABLE "base_runs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "client_id" UUID,
    "user_id" TEXT NOT NULL DEFAULT public.uid(),
    "mission" SMALLINT NOT NULL,
    "level" TEXT NOT NULL,
    "won" BOOLEAN NOT NULL,
    "stars" SMALLINT NOT NULL DEFAULT 0,
    "day_reached" SMALLINT NOT NULL,
    "days" SMALLINT NOT NULL,
    "crew_health" SMALLINT NOT NULL,
    "research" INTEGER NOT NULL DEFAULT 0,
    "ratings" JSONB NOT NULL DEFAULT '{}',
    "main_problem" TEXT,
    "best_decision" TEXT,
    "lost_cause" TEXT,
    "decisions" JSONB NOT NULL DEFAULT '[]',
    "played_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "base_runs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "badges_earned" (
    "user_id" TEXT NOT NULL DEFAULT public.uid(),
    "badge_id" TEXT NOT NULL,
    "earned_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "badges_earned_pkey" PRIMARY KEY ("user_id","badge_id")
);

-- CreateTable
CREATE TABLE "supply_runs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "client_id" UUID,
    "user_id" TEXT NOT NULL DEFAULT public.uid(),
    "stars" SMALLINT NOT NULL,
    "pods" SMALLINT NOT NULL,
    "fuel_left" SMALLINT NOT NULL,
    "hits" SMALLINT NOT NULL DEFAULT 0,
    "played_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "supply_runs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "base_runs_client_id_key" ON "base_runs"("client_id");

-- CreateIndex
CREATE INDEX "base_runs_user_id_mission_idx" ON "base_runs"("user_id", "mission");

-- CreateIndex
CREATE UNIQUE INDEX "supply_runs_client_id_key" ON "supply_runs"("client_id");

-- CreateIndex
CREATE INDEX "supply_runs_user_id_idx" ON "supply_runs"("user_id");

-- AddForeignKey
ALTER TABLE "base_runs" ADD CONSTRAINT "base_runs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "badges_earned" ADD CONSTRAINT "badges_earned_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "supply_runs" ADD CONSTRAINT "supply_runs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- ---------------------------------------------------------------- checks

ALTER TABLE public.base_runs
  ADD CONSTRAINT base_runs_mission  CHECK (mission BETWEEN 1 AND 10),
  ADD CONSTRAINT base_runs_level    CHECK (level IN ('littleExplorer', 'explorer', 'engineer')),
  ADD CONSTRAINT base_runs_stars    CHECK (stars BETWEEN 0 AND 3 AND (won OR stars = 0)),
  ADD CONSTRAINT base_runs_days     CHECK (days BETWEEN 1 AND 60 AND day_reached BETWEEN 1 AND days),
  ADD CONSTRAINT base_runs_health   CHECK (crew_health BETWEEN 0 AND 100),
  ADD CONSTRAINT base_runs_research CHECK (research BETWEEN 0 AND 1000),
  ADD CONSTRAINT base_runs_cause    CHECK (lost_cause IS NULL OR lost_cause IN ('oxygen', 'water', 'food', 'power', 'crew', 'launch')),
  ADD CONSTRAINT base_runs_ratings  CHECK (jsonb_typeof(ratings) = 'object'),
  ADD CONSTRAINT base_runs_decisions CHECK (jsonb_typeof(decisions) = 'array' AND jsonb_array_length(decisions) <= 200),
  ADD CONSTRAINT base_runs_text     CHECK (coalesce(length(main_problem), 0) <= 200 AND coalesce(length(best_decision), 0) <= 200);

ALTER TABLE public.badges_earned
  ADD CONSTRAINT badges_known CHECK (badge_id IN ('first_mission', 'water_saver', 'power_master', 'supply_runner', 'green_thumb', 'solar_survivor',
                                                 'radiation_ready', 'perfect_crew', 'researcher', 'fixer', 'lunar_commander', 'mars_pioneer'));

ALTER TABLE public.supply_runs
  ADD CONSTRAINT supply_runs_stars CHECK (stars BETWEEN 0 AND 3),
  ADD CONSTRAINT supply_runs_pods  CHECK (pods BETWEEN 0 AND 10),
  ADD CONSTRAINT supply_runs_fuel  CHECK (fuel_left BETWEEN 0 AND 100),
  ADD CONSTRAINT supply_runs_hits  CHECK (hits BETWEEN 0 AND 100);

-- ---------------------------------------------------------------- security

ALTER TABLE public.base_runs     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.badges_earned ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supply_runs   ENABLE ROW LEVEL SECURITY;

-- players add and read their own; their teachers read them; nobody rewrites history
CREATE POLICY "own base runs: read"    ON public.base_runs FOR SELECT TO authenticated USING (user_id = (SELECT public.uid()));
CREATE POLICY "own base runs: add"     ON public.base_runs FOR INSERT TO authenticated WITH CHECK (user_id = (SELECT public.uid()));
CREATE POLICY "teachers read base runs" ON public.base_runs FOR SELECT TO authenticated USING (public.is_teacher_of(user_id));
REVOKE UPDATE, DELETE ON public.base_runs FROM authenticated;

CREATE POLICY "own badges: read"    ON public.badges_earned FOR SELECT TO authenticated USING (user_id = (SELECT public.uid()));
CREATE POLICY "own badges: add"     ON public.badges_earned FOR INSERT TO authenticated WITH CHECK (user_id = (SELECT public.uid()));
CREATE POLICY "teachers read badges" ON public.badges_earned FOR SELECT TO authenticated USING (public.is_teacher_of(user_id));
REVOKE UPDATE, DELETE ON public.badges_earned FROM authenticated;

CREATE POLICY "own supply runs: read"    ON public.supply_runs FOR SELECT TO authenticated USING (user_id = (SELECT public.uid()));
CREATE POLICY "own supply runs: add"     ON public.supply_runs FOR INSERT TO authenticated WITH CHECK (user_id = (SELECT public.uid()));
CREATE POLICY "teachers read supply runs" ON public.supply_runs FOR SELECT TO authenticated USING (public.is_teacher_of(user_id));
REVOKE UPDATE, DELETE ON public.supply_runs FROM authenticated;

GRANT SELECT, INSERT ON public.base_runs, public.badges_earned, public.supply_runs TO authenticated;

-- ---------------------------------------------------------------- teacher view

-- One row per student and mission: best stars, tries, wins, and the most
-- common reason the mission was lost (for "where the class gets stuck").
CREATE OR REPLACE FUNCTION public.class_base_summary(cid uuid)
RETURNS TABLE (student_id text, display_name text, mission smallint, best_stars smallint, tries bigint, wins bigint, top_cause text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT m.student_id, p.display_name, r.mission,
         max(r.stars)::smallint, count(*), count(*) FILTER (WHERE r.won),
         mode() WITHIN GROUP (ORDER BY r.lost_cause) FILTER (WHERE NOT r.won)
  FROM class_members m
  JOIN profiles p ON p.id = m.student_id
  JOIN base_runs r ON r.user_id = m.student_id
  WHERE m.class_id = cid AND public.teaches(cid)
  GROUP BY m.student_id, p.display_name, r.mission
  ORDER BY p.display_name, r.mission $$;

REVOKE ALL ON FUNCTION public.class_base_summary(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.class_base_summary(uuid) TO authenticated;
