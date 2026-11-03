"""Python mirror of the Shackleton Station engine, used only to balance missions.
Keep constants and rules identical to lib/engine/simulation.dart."""
import math, copy

# ---- NASA-based values (per crew member per day) ----
O2_DAY = 0.84
WATER_DAY = 2.37 + 0.63   # drinking + food prep (NASA) + simplified hygiene (game)
FOOD_DAY = 0.62
SURFACE_DOSE_H = 1.369 / 24.0   # mSv/h, Chang'e 4 LND

# ---- game engineering values ----
ELEC_MAX_O2_H = 0.15
ELEC_WATER_PER_O2 = 1.125
ELEC_KW = 1.2
RECYCLER_KW = 0.3
RECYCLER_EFF = 0.85
GREEN_KW = 1.5
GREEN_GROW_H = 1 / 60.0
GREEN_HARVEST_KG = 2.5
GREEN_WATER_H = 0.03
HEATER_KW = 0.8
BASE_KW = 0.6
LAB_KW = 0.4
HAB_SHIELD = 0.6
HAB_SHIELD_BERM = 0.3
SHELTER_SHIELD = 0.1
STORM_DOSE_H = {"X": 1.6, "M": 0.7, "C": 0.25}
DUST_RATE_H = 0.003
DUST_EVA_H = 0.01
CLEAN_RATE_H = 0.12

ACT_O2 = {"rest": 0.85, "exercise": 1.3, "eva": 1.6, "shelter": 0.9}
EVA_TARGETS = {
    "ice": {"hours": 6},
    "science": {"hours": 5},
    "ridge": {"hours": 6},
    "berm": {"hours": 8},
}


def new_state(m):
    s = dict(
        hour=0, crew=m["crew"], o2=m["o2"], water=m["water"], food=m["food"],
        battery=m["battery"], batteryCap=m["batteryCap"], solarCap=m["solarCap"], dust=m.get("dust", 0.05),
        dose=0.0, health=100.0, morale=80.0, fatigue=10.0,
        elec_on=True, elec_rate=0.25, elec_broken=False,
        rec_on=not m.get("recOff", False), rec_broken=False,
        green_on=m.get("greenhouse", False), green_broken=False, growth=0.3, hasGreen=m.get("greenhouse", False),
        heat_on=True, lab_on=False,
        location="hab", activity="rest", eva=None, eva_left=0, repair_target=None, repair_prog=0.0,
        samples=0, ice=0.0, science=0.0, panelInstalled=False, berm=m.get("berm", False), spare_panels=m.get("spares", 0),
        sun=True, storm=None, outcome=None, brownout=False, log=[],
    )
    return s


def solar_out(s):
    if not s["sun"]:
        return 0.0
    return s["solarCap"] * (1 - s["dust"])


def load(s):
    kw = BASE_KW
    if s["elec_on"] and not s["elec_broken"]:
        kw += ELEC_KW * s["elec_rate"]
    if s["rec_on"] and not s["rec_broken"]:
        kw += RECYCLER_KW
    if s["hasGreen"] and s["green_on"] and not s["green_broken"]:
        kw += GREEN_KW
    if s["heat_on"] and not s["sun"]:
        kw += HEATER_KW
    if s["lab_on"]:
        kw += LAB_KW
    return kw


def dose_rate(s):
    out = SURFACE_DOSE_H
    if s["storm"] and s["storm"]["phase"] == "active":
        out += STORM_DOSE_H[s["storm"]["cls"]]
    loc = s["location"]
    if loc == "eva" or s["activity"] == "clean":
        return out
    if loc == "shelter":
        return out * SHELTER_SHIELD
    return out * (HAB_SHIELD_BERM if s["berm"] else HAB_SHIELD)


def tick(s, m):
    if s["outcome"]:
        return
    n = s["crew"]
    act = "eva" if s["location"] == "eva" else s["activity"]
    # events
    for e in m["events"]:
        if e["h"] == s["hour"]:
            apply_event(s, e)
    if s["storm"]:
        st = s["storm"]
        st["left"] -= 1
        if st["left"] <= 0:
            if st["phase"] == "warning":
                st["phase"] = "active"; st["left"] = st["dur"]
            else:
                s["storm"] = None
    # power
    gen = solar_out(s)
    need = load(s)
    s["brownout"] = False
    order = ["lab", "green", "elec", "rec", "heat"]
    while s["battery"] + gen - need < 0 and order:
        k = order.pop(0)
        if k == "lab" and s["lab_on"]: s["lab_on"] = False; s["brownout"] = True
        elif k == "green" and s["green_on"]: s["green_on"] = False; s["brownout"] = True
        elif k == "elec" and s["elec_on"]: s["elec_on"] = False; s["brownout"] = True
        elif k == "rec" and s["rec_on"]: s["rec_on"] = False; s["brownout"] = True
        elif k == "heat" and s["heat_on"]: s["heat_on"] = False; s["brownout"] = True
        need = load(s)
    s["battery"] = max(0.0, min(s["batteryCap"], s["battery"] + gen - need))
    # crew needs
    o2use = O2_DAY / 24 * n * ACT_O2.get(act, 1.0)
    water_use = WATER_DAY / 24 * n
    food_use = FOOD_DAY / 24 * n
    s["o2"] -= o2use
    if s["rec_on"] and not s["rec_broken"]:
        water_use *= (1 - RECYCLER_EFF)
    s["water"] -= water_use
    s["food"] -= food_use
    if s["elec_on"] and not s["elec_broken"] and s["water"] > 0:
        made = ELEC_MAX_O2_H * s["elec_rate"]
        made = min(made, s["water"] / ELEC_WATER_PER_O2)
        s["o2"] += made
        s["water"] -= made * ELEC_WATER_PER_O2
    if s["hasGreen"] and s["green_on"] and not s["green_broken"] and s["water"] > 0:
        s["water"] -= GREEN_WATER_H
        s["growth"] += GREEN_GROW_H * (2 if act == "greenhouse" else 1)
        if s["growth"] >= 1:
            s["growth"] -= 1; s["food"] += GREEN_HARVEST_KG; s["morale"] = min(100, s["morale"] + 8)
    # activity effects
    if act == "rest":
        s["fatigue"] -= 5; s["morale"] += 0.4
    elif act == "exercise":
        s["fatigue"] += 2; s["health"] += 0.6
    elif act == "science":
        s["fatigue"] += 1.5
        if s["lab_on"]: s["science"] += 1; s["morale"] += 0.4
    elif act == "greenhouse":
        s["fatigue"] += 1.2; s["morale"] += 0.3
    elif act == "clean":
        s["fatigue"] += 2; s["dust"] = max(0, s["dust"] - CLEAN_RATE_H)
    elif act == "repair":
        s["fatigue"] += 2
        if s["repair_target"]:
            s["repair_prog"] += 1 / 3 * (0.6 if s["morale"] < 30 else 1)
            if s["repair_prog"] >= 1:
                s[s["repair_target"] + "_broken"] = False; s["repair_target"] = None; s["repair_prog"] = 0
    elif act == "shelter":
        s["fatigue"] -= 2; s["morale"] -= 0.4
    elif act == "eva":
        s["fatigue"] += 4; s["dust"] += DUST_EVA_H
        s["eva_left"] -= 1
        if s["eva_left"] <= 0:
            finish_eva(s)
    s["dust"] = min(0.9, s["dust"] + DUST_RATE_H)
    # radiation
    d = dose_rate(s)
    s["dose"] += d
    s["health"] -= d * 1.2
    # damage
    if s["o2"] <= 0: s["o2"] = 0; s["health"] -= 25
    if s["water"] <= 0: s["water"] = 0; s["health"] -= 6
    if s["food"] <= 0: s["food"] = 0; s["health"] -= 1
    if not s["sun"] and not s["heat_on"]: s["health"] -= 2.5; s["morale"] -= 1
    if s["fatigue"] > 85: s["health"] -= 0.5
    if s["morale"] < 25: s["health"] -= 0.2
    s["morale"] -= 0.25
    s["fatigue"] = max(0, min(100, s["fatigue"]))
    s["morale"] = max(0, min(100, s["morale"]))
    s["health"] = min(100, s["health"])
    s["hour"] += 1
    # outcome
    if s["health"] <= 0: s["outcome"] = ("lost", "health")
    elif s["dose"] > m["doseLimit"]: s["outcome"] = ("lost", "dose")
    elif s["hour"] >= m["days"] * 24:
        ok = s["samples"] >= m.get("samples", 0) and s["ice"] >= m.get("ice", 0) and (s["panelInstalled"] or not m.get("panel")) and (s["berm"] or not m.get("needBerm"))
        s["outcome"] = ("won", None) if ok else ("lost", "objectives")


def finish_eva(s):
    t = s["eva"]
    if t == "ice": s["ice"] += 8; s["water"] += 8
    elif t == "science": s["samples"] += 2; s["morale"] += 6
    elif t == "ridge":
        if s["spare_panels"] > 0:
            s["spare_panels"] -= 1; s["solarCap"] += 1.5; s["panelInstalled"] = True
    elif t == "berm": s["berm"] = True
    s["location"] = "hab"; s["eva"] = None; s["activity"] = "rest"


def apply_event(s, e):
    t = e["t"]
    if t == "storm":
        s["storm"] = {"phase": "warning", "left": e["warn"], "dur": e["dur"], "cls": e["cls"]}
    elif t == "fail": s[e["sys"] + "_broken"] = True
    elif t == "dust": s["dust"] = min(0.9, s["dust"] + e["amt"])
    elif t == "night": s["sun"] = False
    elif t == "day": s["sun"] = True
    elif t == "cargo":
        c = e.get("pick", "water")
        if c == "water": s["water"] += 20
        elif c == "food": s["food"] += 6
        elif c == "battery": s["batteryCap"] += 15; s["battery"] += 15
        elif c == "panel": s["spare_panels"] += 1
        elif c == "o2": s["o2"] += 8
    elif t == "home": s["morale"] = min(100, s["morale"] + 15)


# ---------------- strategies ----------------

def competent(s, m):
    if s["location"] == "eva":
        if s["storm"] and s["storm"]["phase"] in ("warning", "active"):
            # recall
            s["location"] = "hab"; s["eva"] = None; s["activity"] = "shelter"; s["location"] = "shelter"
        return
    st = s["storm"]
    if st and (st["phase"] == "active" or (st["phase"] == "warning" and st["left"] <= 2)):
        s["location"] = "shelter"; s["activity"] = "shelter"; return
    if s["location"] == "shelter":
        s["location"] = "hab"; s["activity"] = "rest"
    n = s["crew"]
    # electrolyzer rate: match consumption
    target = O2_DAY / 24 * n * 1.05 / ELEC_MAX_O2_H
    days_o2 = s["o2"] / (O2_DAY * n)
    s["elec_rate"] = min(1.0, target + (0.3 if days_o2 < 1.5 else 0))
    s["elec_on"] = True; s["rec_on"] = True; s["heat_on"] = True
    remaining = m["days"] - s["hour"] / 24
    if not s["sun"] and days_o2 > remaining + 0.4:
        s["elec_on"] = False
    if not s["sun"] and s["water"] / (WATER_DAY * n) > remaining + 0.3:
        s["rec_on"] = False
    if s["hasGreen"]:
        s["green_on"] = s["battery"] > 0.35 * s["batteryCap"] or s["sun"]
        if not s["sun"]: s["green_on"] = s["battery"] > 0.7 * s["batteryCap"]
    for k in ("elec", "rec", "green"):
        if s[k + "_broken"]:
            s["activity"] = "repair"; s["repair_target"] = k; return
    if s["fatigue"] > 60:
        s["activity"] = "rest"; return
    if s["dust"] > 0.3 and s["sun"]:
        s["activity"] = "clean"; return
    # objectives
    safe = not st
    if safe and s["fatigue"] < 40:
        if m.get("needBerm") and not s["berm"]: return start_eva(s, "berm")
        if s["ice"] < m.get("ice", 0): return start_eva(s, "ice")
        if s["samples"] < m.get("samples", 0): return start_eva(s, "science")
        if m.get("panel") and not s["panelInstalled"] and s["spare_panels"]: return start_eva(s, "ridge")
        if s["water"] < 8 and m.get("iceAvailable"): return start_eva(s, "ice")
    if s["hasGreen"] and s["green_on"]:
        s["activity"] = "greenhouse"; return
    s["activity"] = "rest"


def start_eva(s, t):
    s["location"] = "eva"; s["eva"] = t; s["eva_left"] = EVA_TARGETS[t]["hours"]; s["activity"] = "eva"


def naive(s, m):
    # never adjusts anything, never shelters, rests always; does objectives
    if s["location"] == "eva": return
    if s["fatigue"] < 40:
        if s["ice"] < m.get("ice", 0): return start_eva(s, "ice")
        if s["samples"] < m.get("samples", 0): return start_eva(s, "science")
    s["activity"] = "rest"


def run(m, strat):
    s = new_state(m)
    while not s["outcome"]:
        strat(s, m)
        tick(s, m)
    return s


def summary(s, m):
    n = s["crew"]
    return (f"{s['outcome'][0]:4} {str(s['outcome'][1]):10} h={s['hour']:3} hp={s['health']:5.1f} dose={s['dose']:5.1f}/{m['doseLimit']} "
            f"o2={s['o2']:5.1f}({s['o2']/(O2_DAY*n):.1f}d) w={s['water']:5.1f} f={s['food']:4.1f} bat={s['battery']:4.1f}/{s['batteryCap']} "
            f"mor={s['morale']:4.0f} fat={s['fatigue']:3.0f} dust={s['dust']:.2f}")
