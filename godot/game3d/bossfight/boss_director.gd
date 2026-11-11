## When the boss's minions come (T158): a director that paces the waves
## through build-up, peak and relief, from what happens in the fight.
##
## Minions that keep coming at one pace make a boss fight a grind. Left 4
## Dead's director alternates a build-up, a peak and a relief [Booth 2009];
## the infiltration level's (T90) does it from the player's intensity. This
## one reads three things, all the fight's, none about how well the person
## plays (ADR 0016 is not extended):
##
## - the boss entering a phase, and whether that phase summons;
## - how many minions stand, and whether every kind stands at its cap;
## - the seconds since the last wave.
##
## Its three states, in the order a fight goes round them:
##
## - **build-up**: a wave every `wave_every` seconds. Once every kind
##   stands at its cap, the peak;
## - **peak**: no wave, until the minions standing fall to `relief_at`,
##   or for `peak_seconds` at most -- Booth sustains a peak 3 to 5 s and
##   then fades it, whether or not the player has cleared it (as
##   `docs/godot/infiltration.md` reads his slides);
## - **relief**: no wave for `relief_seconds`, then build-up again -- the
##   pause a person should feel.
##
## A phase that summons brings a wave at once and the peak, from any state
## -- the peak's seconds starting over -- : the boss calls, the director
## only times it. And no wave comes while the
## boss swings a heavy attack; one that is due waits for the blow to end.
##
## A step is constant: a few comparisons. It decides when, never how many:
## the level sets the wave's size and its cap.
##
## When not to use it: as difficulty, or to follow the person. It never
## counts their hits or their health; a fight that should get easier for
## someone losing is dynamic difficulty, a different design.
class_name BossDirector
extends RefCounted

const BUILD_UP: String = "build-up"  # shown through tr()
const PEAK: String = "peak"  # shown through tr()
const RELIEF: String = "relief"  # shown through tr()
## Why the next wave has not come yet, as the overlay says it.
const WAITS_FOR_TIME: String = "time"  # not shown: worded by BossfightText
const WAITS_FOR_HEAVY: String = "heavy"  # not shown: worded by BossfightText
const WAITS_FOR_FEWER: String = "fewer"  # not shown: worded by BossfightText
const WAITS_FOR_RELIEF: String = "relief"  # not shown: worded by BossfightText

## Seconds between two waves in build-up.
var wave_every: float = 8.0
## Minions standing at or below which the peak gives way to relief.
var relief_at: int = 2
## The longest a peak lasts, in seconds.
var peak_seconds: float = 15.0
## Seconds of relief.
var relief_seconds: float = 6.0

var state: String = BUILD_UP
## When the state was entered, and when the last wave came.
var since: float = 0.0
var last_wave_at: float = 0.0
## Waves sent, the opening one included.
var waves: int = 1
## A summoning phase whose wave waits for a heavy blow to end.
var summon_waiting: bool = false
## Every state entered and every wave, in order: {at, what, state}, and
## for a wave whether a phase summoned it.
var events: Array[Dictionary] = []
var _heavy: bool = false
var _now: float = 0.0


## Why `numbers` cannot pace a fight, or "": every one a number, the
## seconds above zero -- a wave every 0 s is a wave every step, and a peak
## of no seconds is no peak -- and `relief_at` a whole number, 0 or more.
static func why_not_numbers(numbers: Dictionary) -> String:
	for key: String in ["wave_every", "peak_seconds", "relief_seconds"]:
		if not BossDifficulty.is_number(numbers.get(key), false) or float(numbers[key]) <= 0.0:
			return "director: %s is %s; it must be a number of seconds above 0" % [key, JSON.stringify(numbers.get(key))]  # not shown: a refusal for whoever edits the data, in its keys' English
	if not BossDifficulty.is_number(numbers.get("relief_at"), true) or float(numbers["relief_at"]) < 0.0:
		return "director: relief_at is %s; it must be a whole number, 0 or more" % JSON.stringify(numbers.get("relief_at"))  # not shown: a refusal for whoever edits the data, in its keys' English
	return ""


## A director on `numbers`, `boss_fight.json`'s "director"; the opening
## wave is the fight's, at time 0.
func _init(numbers: Dictionary) -> void:
	wave_every = float(numbers.get("wave_every", wave_every))
	relief_at = int(numbers.get("relief_at", relief_at))
	peak_seconds = float(numbers.get("peak_seconds", peak_seconds))
	relief_seconds = float(numbers.get("relief_seconds", relief_seconds))


## One step at `now`: `entered` the phases the boss entered since the last
## step (its "phase" events), `standing` the minions alive, `full` true when
## every kind stands at its cap, `heavy` true while a heavy blow is
## underway. True when a wave comes now.
func step(now: float, entered: Array[Dictionary], standing: int, full: bool, heavy: bool) -> bool:
	_now = now
	_heavy = heavy
	if entered.any(func(phase: Dictionary) -> bool: return phase.get("summon", false)):
		summon_waiting = true
	if summon_waiting and not heavy:
		summon_waiting = false
		_enter(PEAK, true)
		return _wave(true)
	_move_on(standing, full)
	if state == BUILD_UP and not heavy and now - last_wave_at >= wave_every:
		return _wave(false)
	return false


## Seconds until the next wave as things stand, or -1 when it waits on
## something other than time: fewer minions standing, or a heavy blow.
func next_wave_in() -> float:
	match waits_for():
		WAITS_FOR_TIME:
			return maxf(0.0, last_wave_at + wave_every - _now)
		WAITS_FOR_RELIEF:
			return maxf(0.0, since + relief_seconds - _now)
	return -1.0


## What the next wave waits for: WAITS_FOR_HEAVY, WAITS_FOR_FEWER (the
## peak), WAITS_FOR_RELIEF, or WAITS_FOR_TIME (build-up).
func waits_for() -> String:
	var due: bool = state == BUILD_UP and _now - last_wave_at >= wave_every
	if _heavy and (summon_waiting or due):
		return WAITS_FOR_HEAVY
	match state:
		PEAK:
			return WAITS_FOR_FEWER
		RELIEF:
			return WAITS_FOR_RELIEF
	return WAITS_FOR_TIME


func _move_on(standing: int, full: bool) -> void:
	if state == BUILD_UP and full:
		_enter(PEAK)
	elif state == PEAK and (standing <= relief_at or _now - since >= peak_seconds):
		_enter(RELIEF)
	elif state == RELIEF and _now - since >= relief_seconds:
		_enter(BUILD_UP)


# Enter `next`. A summon enters the peak `again` even from the peak: its
# seconds start over, so a summon late in a peak is not followed by a
# relief a moment later.
func _enter(next: String, again: bool = false) -> void:
	if next == state and not again:
		return
	state = next
	since = _now
	events.append({"at": _now, "what": "pacing", "state": state})


func _wave(summoned: bool) -> bool:
	last_wave_at = _now
	waves += 1
	events.append({"at": _now, "what": "wave", "state": state, "summon": summoned})
	return true
