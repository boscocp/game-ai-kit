"""Write the utility vectors in this directory.

Imports nothing from the repository, so the answers come from neither
implementation the vectors hold -- a third copy of the rules, in plain
dictionaries. These rules were in the teamwork vectors' derive.py until
T101 moved utility choice into `ai_utility`, unchanged:

    python3 spec/vectors/utility/derive.py spec/vectors/utility
"""
import json, pathlib, sys

# --- what to do now: utility -------------------------------------------------

def curve_answer(c, percepts):
    value = float(percepts.get(c["percept"], 0.0))
    if c.get("curve", "linear") == "step":
        return c.get("above", 1.0) if value >= c.get("at", 0.5) else c.get("below", 0.0)
    return min(max(c.get("slope", 1.0) * value + c.get("intercept", 0.0), 0.0), 1.0)

def action(name, why, actions, records):
    scores, answers, chosen = [], [], []
    for percepts in records:
        row, why_row, best, taken = [], [], 0.0, -1
        for index, a in enumerate(actions):
            found = [curve_answer(c, percepts) for c in a.get("considerations", [])]
            score = a.get("weight", 1.0)
            for value in found:
                score *= value
            row.append(score)
            why_row.append(found)
            if score > best:
                best, taken = score, index
        scores.append(row)
        answers.append(why_row)
        chosen.append(taken)
    return {"name": name, "why": why, "kind": "action", "query": {"actions": actions, "percepts": records},
            "expect": {"scores": scores, "answers": answers, "chosen": chosen}}

def line_of(percept, slope=1.0, intercept=0.0):
    return {"percept": percept, "curve": "linear", "slope": slope, "intercept": intercept}

def when(percept, at=0.5, below=0.0, above=1.0):
    return {"percept": percept, "curve": "step", "at": at, "below": below, "above": above}

# The bot match's own actions (godot/game3d/botmatch/actions.json), copied
# here by hand: this file reads nothing from the repository.
BOT_ACTIONS = [
    {"name": "reload", "weight": 1.0, "considerations": [line_of("rounds_left", -1.5, 1.0), when("has_reserve"),
                                                         when("could_fire", 0.5, 1.0, 0.4), when("to_go", 0.3, 1.0, 0.6)]},
    {"name": "fall back", "weight": 0.8, "considerations": [when("in_retreat_wave")]},
    {"name": "shoot", "weight": 1.0, "considerations": [when("ready_to_fire"), line_of("shot_worth", 8.0)]},
    {"name": "move", "weight": 0.5, "considerations": [when("to_go", 0.3)]},
    {"name": "look", "weight": 0.45, "considerations": [line_of("heard", 2.0), when("enemy_in_sight", 0.5, 1.0, 0.0)]},
    {"name": "hold", "weight": 0.3, "considerations": []},
]

BOT_POSTURES = [
    {"name": "stand", "weight": 0.33, "considerations": []},
    {"name": "crouch", "weight": 1.0, "considerations": [when("moving", 0.5, 1.0, 0.1), when("shooting", 0.5, 1.0, 0.2),
                                                         line_of("cover", 0.4, 0.6), line_of("danger", 0.5, 0.6),
                                                         when("reloading", 0.5, 0.85, 1.0)]},
]

BOT_PACES = [
    {"name": "walk", "weight": 0.5, "considerations": []},
    {"name": "sprint", "weight": 1.0, "considerations": [when("moving"), line_of("to_go", 0.0625),
                                                         when("enemy_in_sight", 0.5, 1.0, 0.0), line_of("danger", -0.8, 1.0)]},
]

def action_vectors():
    simple = [{"name": "shoot", "weight": 1.0, "considerations": [when("ready_to_fire"), line_of("shot_worth", 8.0)]},
              {"name": "reload", "weight": 1.0, "considerations": [line_of("rounds_left", -1.5, 1.0), when("has_reserve")]},
              {"name": "hold", "weight": 0.25, "considerations": []}]
    yield action("the-best-reason-wins",
                 "Loaded with a shot worth 0.25: shoot, 1. Empty with rounds in reserve: shooting is vetoed and "
                 "reload is 1. Full, nobody to shoot: only holding is worth anything.",
                 simple, [{"ready_to_fire": 1.0, "shot_worth": 0.25, "rounds_left": 0.5, "has_reserve": 1.0},
                          {"ready_to_fire": 0.0, "shot_worth": 0.25, "rounds_left": 0.0, "has_reserve": 1.0},
                          {"ready_to_fire": 1.0, "shot_worth": 0.0, "rounds_left": 1.0, "has_reserve": 1.0}])
    yield action("one-zero-vetoes-the-rest",
                 "Two answers of 1 and one of 0: the product, and the score, is 0, and holding wins.",
                 [{"name": "charge", "weight": 1.0, "considerations": [when("brave"), when("loaded"), when("path_open")]},
                  {"name": "hold", "weight": 0.25, "considerations": []}],
                 [{"brave": 1.0, "loaded": 1.0, "path_open": 0.0}, {"brave": 1.0, "loaded": 1.0, "path_open": 1.0}])
    yield action("a-step-on-its-threshold-is-above",
                 "A step at 0.5: exactly 0.5 answers `above`, 0.25 answers `below` -- the comparison is >=.",
                 [{"name": "go", "weight": 1.0, "considerations": [when("far", 0.5, 0.25, 0.75)]}],
                 [{"far": 0.5}, {"far": 0.25}])
    yield action("a-line-is-clamped-at-both-ends",
                 "Twice the percept less a half: at 0 it would be -0.5 and answers 0, at 1 it would be 1.5 and "
                 "answers 1, at 0.5 it is 0.5.",
                 [{"name": "go", "weight": 1.0, "considerations": [line_of("x", 2.0, -0.5)]}], [{"x": 0.0}, {"x": 1.0}, {"x": 0.5}])
    yield action("equal-scores-take-the-first",
                 "Two actions scoring 0.5 each: the first listed is taken, on both sides.",
                 [{"name": "left", "weight": 0.5, "considerations": []}, {"name": "right", "weight": 0.5, "considerations": []}],
                 [{}])
    yield action("nothing-above-zero-chooses-nothing",
                 "Every action vetoed: nothing is chosen, -1, rather than the first of zeros.",
                 [{"name": "shoot", "weight": 1.0, "considerations": [when("loaded")]},
                  {"name": "reload", "weight": 1.0, "considerations": [when("has_reserve")]}],
                 [{"loaded": 0.0, "has_reserve": 0.0}])
    yield action("an-absent-percept-is-nothing",
                 "A percept not given counts as 0: a line through it answers its intercept, 0.25, and a step its "
                 "`below`, 0.5.",
                 [{"name": "go", "weight": 1.0, "considerations": [line_of("unseen", 1.0, 0.25), when("unheard", 0.5, 0.5, 1.0)]}],
                 [{}])
    yield action("the-bot-match-weighs-its-actions",
                 "The bot match's own six actions. Loaded at its spot, a shot worth 0.25: shoot. Empty, away from "
                 "its goal with an enemy near: reload, 0.6, beats moving on, 0.5. Ten rounds left at its spot, "
                 "nobody in sight: reload early, 0.5. A loud shot heard (0.75) at its spot with nobody in sight: "
                 "look, 0.45, beats holding. In the moving wave of a retreat with a poor shot (0.0625): fall "
                 "back, 0.8, beats the shot, 0.5.",
                 BOT_ACTIONS,
                 [{"ready_to_fire": 1.0, "shot_worth": 0.25, "rounds_left": 1.0, "has_reserve": 1.0, "could_fire": 1.0,
                   "to_go": 0.0, "enemy_in_sight": 1.0},
                  {"ready_to_fire": 0.0, "shot_worth": 0.0, "rounds_left": 0.0, "has_reserve": 1.0, "could_fire": 0.0,
                   "to_go": 6.0, "enemy_in_sight": 1.0},
                  {"ready_to_fire": 1.0, "shot_worth": 0.0, "rounds_left": 0.3333333333333333, "has_reserve": 1.0,
                   "could_fire": 0.0, "to_go": 0.0, "enemy_in_sight": 0.0},
                  {"ready_to_fire": 1.0, "rounds_left": 1.0, "has_reserve": 1.0, "heard": 0.75, "to_go": 0.0},
                  {"ready_to_fire": 1.0, "shot_worth": 0.0625, "rounds_left": 1.0, "has_reserve": 1.0, "could_fire": 1.0,
                   "to_go": 8.0, "enemy_in_sight": 1.0, "in_retreat_wave": 1.0}])


# --- errands -----------------------------------------------------------------

# The bot match's own numbers, from its rules.json, copied here by hand.
ERRAND_WEIGHTS = {"resupply_walk": 0.05, "leave_holding": 0.3, "leave_attacking": 0.5,
                  "health_worth": 1.0, "power_worth": 1.0, "power_walk": 0.08, "power_danger": 0.3, "hide_second": 0.02}

def going_back(spent=0.0, earned=False, walk=0.0, attacking=False, empty=False, hurt=0.0, exposure=0.0):
    return {"spent": spent, "hurt": hurt, "exposure": exposure, "earned_power": earned, "walk_seconds": walk, "attacking": attacking, "empty": empty}

def fetching(available=True, walk=0.0, near=0):
    return {"available": available, "walk_seconds": walk, "enemies_near": near}

def hiding(available=True, hurt=0.0, walk=0.0, wait=0.0, attacking=False, exposure=1.0):
    return {"available": available, "hurt": hurt, "exposure": exposure, "walk_seconds": walk, "wait_seconds": wait, "attacking": attacking}

def weigh_hide(f, w):
    if not f["available"]:
        return [0.0, 0.0, 0.0, 0.0]
    gain, away = f["hurt"] * f["exposure"] * w["health_worth"], f["walk_seconds"] + f["wait_seconds"]
    leaving = w["leave_attacking"] if f["attacking"] else w["leave_holding"]
    return [gain, away, leaving, gain - away * w["hide_second"] - leaving]

def weigh_back(f, w):
    gain = f["spent"] + f["hurt"] * f["exposure"] * w["health_worth"] + (w["power_worth"] if f["earned_power"] else 0.0)
    leaving = 0.0 if f["empty"] else (w["leave_attacking"] if f["attacking"] else w["leave_holding"])
    return [gain, f["walk_seconds"], leaving, gain - f["walk_seconds"] * w["resupply_walk"] - leaving]

def weigh_out(f, w):
    if not f["available"]:
        return [0.0, 0.0, 0.0, 0.0]
    danger = f["enemies_near"] * w["power_danger"]
    return [w["power_worth"], f["walk_seconds"], danger, w["power_worth"] - f["walk_seconds"] * w["power_walk"] - danger]

def sent(scores):
    best, top = -1, 0.0
    for index, score in enumerate(scores):
        if score > top:
            best, top = index, score
    return best

def errand_of(back, out, hide=0.0):
    best = max(back, out, hide)
    if best <= 0.0:
        return ""
    if back >= best:
        return "resupply"
    return "fetch power" if out >= best else "hide to heal"

def errands(name, why, back=(), out=(), teams=(), pairs=(), hide=(), weights=ERRAND_WEIGHTS):
    w = weights
    return {"name": name, "why": why, "kind": "errands", "weights": w,
            "query": {"resupply": list(back), "fetch": list(out), "hide": list(hide), "teams": list(teams), "pairs": list(pairs)},
            "expect": {"resupply": [weigh_back(f, w) for f in back], "fetch": [weigh_out(f, w) for f in out],
                       "hide": [weigh_hide(f, w) for f in hide],
                       "fetcher": [sent(scores) for scores in teams], "chosen": [errand_of(*pair) for pair in pairs]}}

def errand_vectors():
    yield errands("back-for-rounds-when-spent-and-near",
                  "Three quarters spent, two seconds from its base, holding: 0.75 - 0.1 - 0.3 = 0.35, worth going. "
                  "Full, the same walk: -0.4, and it stays.",
                  back=[going_back(0.75, walk=2.0), going_back(0.0, walk=2.0)])
    yield errands("an-empty-bot-has-no-post-to-leave",
                  "No round left, attacking, ten seconds away: leaving costs it nothing, 1 - 0.5 = 0.5. With a "
                  "tenth left it has a post: 0.9 - 0.5 - 0.5 = -0.1.",
                  back=[going_back(1.0, walk=10.0, attacking=True, empty=True), going_back(0.9, walk=10.0, attacking=True)])
    yield errands("home-heals-whole-so-health-counts",
                  "Full of rounds, three quarters of its health gone, under fire (exposure 1), four seconds from its "
                  "base, holding: 0 + 0.75 - 0.2 - 0.3 = 0.25, worth going to be healed whole. A quarter gone: "
                  "-0.25, it stays.",
                  back=[going_back(walk=4.0, hurt=0.75, exposure=1.0), going_back(walk=4.0, hurt=0.25, exposure=1.0)])
    yield errands("unseen-it-heals-where-it-stands",
                  "The review's case: three quarters gone, four seconds from its base, no enemy known and no hit "
                  "lately (exposure 0): its health comes back where it stands, so the health is worth nothing to "
                  "an errand, -0.5, and it stays. Half exposed: 0.375 - 0.5 = -0.125, still stays. Hiding, unseen: "
                  "0 - 10 x 0.02 - 0.3 = -0.5.",
                  back=[going_back(walk=4.0, hurt=0.75), going_back(walk=4.0, hurt=0.75, exposure=0.5)],
                  hide=[hiding(hurt=0.75, walk=2.0, wait=8.0, exposure=0.0)])
    yield errands("health-worth-half-of-the-rounds",
                  "Health worth 0.5 of all the rounds: three quarters gone under fire, four seconds from home, "
                  "holding: 0.375 - 0.2 - 0.3 = -0.125, it stays; hiding two seconds off with an eight-second wait: "
                  "0.375 - 0.2 - 0.3 = -0.125.",
                  back=[going_back(walk=4.0, hurt=0.75, exposure=1.0)],
                  hide=[hiding(hurt=0.75, walk=2.0, wait=8.0)],
                  weights=dict(ERRAND_WEIGHTS, health_worth=0.5))
    yield errands("the-streak-earns-the-power-weapon-at-home",
                  "Full of rounds, but five kills earned the power weapon at its base: 0 + 1 - 0.2 - 0.3 = 0.5.",
                  back=[going_back(0.0, earned=True, walk=4.0)])
    yield errands("fetch-unless-far-guarded-or-gone",
                  "Five seconds from it: 1 - 0.4 = 0.6. Two enemies near it: 0. Three: -0.3. Not there, or held: "
                  "nothing at all.",
                  out=[fetching(walk=5.0), fetching(walk=5.0, near=2), fetching(walk=5.0, near=3), fetching(False, 5.0)])
    yield errands("the-team-sends-the-one-it-is-worth-most-to",
                  "Of 0.25, 0.5, 0.5 and -0.125 the first 0.5 is sent; when none is above zero, nobody is. Powers "
                  "of two, so the tie is exact on both sides.",
                  teams=[[0.25, 0.5, 0.5, -0.125], [-0.125, 0.0], []])
    yield errands("going-back-wins-a-tie-and-zero-is-no-errand",
                  "Equal scores, 0.5 each: back. Back 0.25, fetch 0.5: fetch. Back exactly 0: fetch 0.25. Both "
                  "0, or both below: no errand.",
                  pairs=[[0.5, 0.5], [0.25, 0.5], [0.0, 0.25], [0.0, 0.0], [-1.0, -1.0]])

    yield errands("hide-when-the-wound-is-deep-and-the-wait-short",
                  "Under fire (exposure 1). Hurt 0.75, cover two seconds off, eight seconds' wait, holding: "
                  "0.75 - 10 x 0.02 - 0.3 = 0.25, "
                  "worth hiding. Hurt 0.25: -0.25, a scratch is not. Hurt 0.75 attacking with a 25 s wait: -0.29. "
                  "Nowhere to hide: nothing at all.",
                  hide=[hiding(hurt=0.75, walk=2.0, wait=8.0), hiding(hurt=0.25, walk=2.0, wait=8.0),
                        hiding(hurt=0.75, walk=2.0, wait=25.0, attacking=True), hiding(False, 0.75, 2.0, 8.0)])
    yield errands("the-highest-of-three-and-ties-go-back-then-fetch",
                  "Hide 0.5 over back 0.25 and fetch 0: hide. All three 0.5: back. Fetch and hide 0.5, back 0.25: "
                  "fetch. Hide alone below zero: no errand.",
                  pairs=[[0.25, 0.0, 0.5], [0.5, 0.5, 0.5], [0.25, 0.5, 0.5], [0.0, 0.0, -0.25]])

def posture_vectors():
    yield action("the-bot-match-weighs-its-posture",
                 "The bot match's postures (a copy of `actions.json`). Idle in the open, nothing perceived: crouching "
                 "is 0.306 against standing's 0.33. Idle at low cover: 0.51, crouch. Reloading in the open: 0.36, "
                 "crouch. Shooting at low cover with an enemy in sight: 0.17, stand -- crouched it would shoot into "
                 "the box. Walking: 0.085, stand, for a crouch halves its speed.",
                 BOT_POSTURES,
                 [{}, {"cover": 1.0}, {"reloading": 1.0}, {"shooting": 1.0, "cover": 1.0, "danger": 1.0},
                  {"moving": 1.0, "cover": 1.0, "danger": 1.0}])
    yield action("the-bot-match-weighs-its-pace",
                 "The bot match's paces (a copy of `actions.json`). Moving, 16 m to go, nothing perceived: sprint, 1. "
                 "Eight metres: 0.5, a tie, and walking is listed first. Twelve metres with a shot heard at 0.5: "
                 "0.45, walk. An enemy in sight: sprinting is vetoed, for a sprinting bot may not fire. Holding, "
                 "not moving: 0.",
                 BOT_PACES,
                 [{"moving": 1.0, "to_go": 16.0}, {"moving": 1.0, "to_go": 8.0}, {"moving": 1.0, "to_go": 12.0, "danger": 0.5},
                  {"moving": 1.0, "to_go": 16.0, "enemy_in_sight": 1.0, "danger": 1.0}, {"to_go": 16.0}])

def main(directory):
    folder = pathlib.Path(directory)
    for vector in list(action_vectors()) + list(errand_vectors()) + list(posture_vectors()):
        (folder / f"{vector['name']}.json").write_text(json.dumps(vector, indent=1) + "\n", encoding="utf-8")

if __name__ == "__main__":
    main(sys.argv[1])
