#!/usr/bin/env python3
"""Generate backend/prisma/migrations/0003_catalogue/migration.sql from lib/data/catalogue.dart.

Run from the project root:  python3 tools/gen_catalogue_sql.py
The migration is an idempotent upsert, so it is safe to re-run by hand.
"""
import pathlib, re, sys

root = pathlib.Path(__file__).resolve().parent.parent
src = (root / 'lib/data/catalogue.dart').read_text()
alias = dict(re.findall(r"_(\w)\s*=\s*Skill\.(\w+)", src))
camp_alias = dict(re.findall(r"_(\w\w)\s*=\s*CampaignId\.(\w+)", src))
skill_db = {'prioritise': 'prioritise', 'systems': 'systems', 'rootCause': 'root_cause',
            'resourceMath': 'resource_math', 'procedure': 'procedure', 'teamwork': 'teamwork'}
age = ['cadet', 'explorer', 'engineer']
pat = re.compile(r"CatalogueEntry\('([a-z]+-\d\d)', _(\w\w), (\d+), '((?:[^'\\]|\\.)*)', \[([^\]]*)\](?:, minutes: (\d+))?(?:, coopAge: (\d))?\)")
rows = []
for m in pat.finditer(src):
    lid, camp, num, title, skills, minutes, coop_age = m.groups()
    camp = camp_alias[camp]
    sk = [skill_db[alias[s.strip().lstrip('_')]] for s in skills.split(',') if s.strip()]
    title = title.replace("\\'", "'").replace("'", "''")
    rows.append((lid, camp, int(num), title, sk, int(minutes or 10), None if coop_age is None else age[int(coop_age)]))
if len(rows) != src.count("CatalogueEntry('"):
    sys.exit('could not parse every catalogue entry')

out = ['-- Shackleton Station 2.0 · 0003_catalogue',
       '-- Generated from lib/data/catalogue.dart by tools/gen_catalogue_sql.py. Do not edit by hand.',
       f'-- {len(rows)} levels and co-op missions.', '',
       'INSERT INTO public.levels (id, campaign, number, title, skills, is_coop, age_mode, minutes) VALUES']
vals = []
for lid, camp, num, title, sk, minutes, ca in rows:
    arr = "'{" + ",".join(sk) + "}'::public.skill[]"
    am = 'NULL' if ca is None else f"'{ca}'"
    vals.append(f"  ('{lid}', '{camp}', {num}, '{title}', {arr}, {'true' if camp == 'coop' else 'false'}, {am}, {minutes})")
out.append(',\n'.join(vals))
out.append('ON CONFLICT (id) DO UPDATE SET campaign = EXCLUDED.campaign, number = EXCLUDED.number, title = EXCLUDED.title,')
out.append('  skills = EXCLUDED.skills, is_coop = EXCLUDED.is_coop, age_mode = EXCLUDED.age_mode, minutes = EXCLUDED.minutes;')
dst = root / 'backend/prisma/migrations/0003_catalogue/migration.sql'
dst.parent.mkdir(parents=True, exist_ok=True)
dst.write_text('\n'.join(out) + '\n')
print(f'wrote {len(rows)} rows to {dst.relative_to(root)}')
