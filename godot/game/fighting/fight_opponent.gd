## An opponent that does not learn: hand-written reactions to seven
## situations, at three levels, none of which sees the fight sooner than a
## person could.
##
## This is how most fighting games make their opponents (T36's survey). It
## looks at the fight -- which it is handed `reaction` frames late, by
## `FightDelay` -- names the situation it sees, draws one of that situation's
## options by weight, and plays it out frame by frame before it looks again.
## The chance is on purpose: an opponent that always answered a whiff the same
## way would be learnt in a minute, and one director says the chance is what
## makes it react more like a person.
##
## Difficulty is three knobs, written down in `LEVELS`, after the arena and a
## shipped game's two axes:
##
## * **reaction** -- how old the fight it sees is, never under 15 frames;
## * **tactics** -- how many of each situation's options it has, first ones
##   first: an easy opponent only knows the obvious answers;
## * **execution** -- how often what it chose comes out as chosen, rather
##   than late or as something else.
##
## So the hard opponent is hard because it decides better and sees sooner --
## and never sooner than a person would. Measured with every level's
## reaction the same, hard still beats medium 92 to 95 times in 100: most of
## its edge is the deciding. It sees nothing the others do not: the same
## fight, only less old.
##
## The weights were retuned in T40, when the owner found hard easy, by what
## each option won or lost against the owner's ghost: walking in loses to a
## player who kicks mid, an overhead is too slow for a crouch, and lows,
## mids and throws win. `test/fighting/opponent_levels.gd` holds hard to beating a
## frozen copy of that ghost; since the ghost is what it was tuned against,
## that number flatters it, and T18's turtle, which it was not tuned against
## and does worst against, is held as the check.
##
## Complexity: constant per frame. A decision is a lookup and a weighted draw.
##
## When not to use it: an opponent that should adapt to the player. This one
## never changes; T17's opponent model is the one that learns.
class_name FightOpponent
extends RefCounted

## The three levels' knobs. Reaction is in frames, tactics is how many of
## each situation's options, execution is a percentage.
const LEVELS: Dictionary = {
	"easy": {"reaction": 30, "tactics": 2, "execution": 60},
	"medium": {"reaction": 22, "tactics": 4, "execution": 85},
	"hard": {"reaction": 15, "tactics": 10, "execution": 100},
}

## Each situation's options, `[option, weight]`, the ones every level knows
## first. A level with `tactics` 2 draws from the first two only. The order
## is the lesson: the first options are what a beginner reaches for -- a
## punch at a crouching fighter, which passes over it -- and the later ones
## are the answers that work.
##
## The backdash came with T40, as "evade" -- out of pressure, early in
## "after blocking", because getting out is the first thing a beginner
## reaches for -- and with two situations, "it blocked" and "it evaded".
## There is no strike in "it evaded" that punishes the backdash it saw:
## seen 15 frames late, it is over before any strike here arrives (measured:
## a long strike caught it 5 times in about 800). What it does is follow:
## a backdash gives up ground, and one more into the corner goes nowhere.
const SITUATIONS: Dictionary = {
	"after being hit": [["high", 3], ["step out", 2], ["guard standing", 3], ["guard crouching", 2], ["low", 3],  # not shown as written: an identifier, or the digest's English (FightWords)
			["evade", 1]],
	"after blocking": [["high", 2], ["evade", 1], ["guard standing", 2], ["throw", 3], ["low", 3],  # not shown as written: an identifier, or the digest's English (FightWords)
			["guard crouching", 1]],  # not shown as written: an identifier, or the digest's English (FightWords)
	"it blocked": [["high", 3], ["throw", 3], ["step in", 1], ["low", 3]],  # not shown as written: an identifier, or the digest's English (FightWords)
	"it evaded": [["step in", 3], ["high", 1]],  # not shown as written: an identifier, or the digest's English (FightWords)
	"it whiffed": [["step in", 2], ["high", 2], ["mid", 4], ["low", 4]],  # not shown as written: an identifier, or the digest's English (FightWords)
	"it crouches": [["high", 3], ["step in", 1], ["throw", 4], ["mid", 3], ["overhead", 2]],  # not shown as written: an identifier, or the digest's English (FightWords)
	"neutral": [["step in", 3], ["high", 2], ["guard standing", 2], ["mid", 4], ["low", 4],  # not shown as written: an identifier, or the digest's English (FightWords)
			["throw", 3], ["guard crouching", 1], ["overhead", 1], ["step out", 1], ["evade", 1]],  # not shown as written: an identifier, or the digest's English (FightWords)
}

## How long a guard or a step is held, in frames, before it looks again.
const GUARD_FRAMES: int = 12
const STEP_FRAMES: int = 10
## How late a fumble that comes out slow is, in frames.
const HESITATION_FRAMES: int = 10

## How many frames late it sees the fight. `FightDelay` reads this once.
var reaction: int = FightDelay.MINIMUM_REACTION
## Which level, by its name in `LEVELS`, or the name a planted one gives.
var level: String = ""
## Its last decision, for the panel: the situation it saw, the frame it saw
## it on, and what it chose. -1 and "nothing yet" before its first.
var situation: String = "nothing seen yet"  # not shown as written: an identifier, or the digest's English (FightWords)
var seen_frame: int = -1
var choice: String = "nothing yet"  # not shown as written: an identifier, or the digest's English (FightWords)

var _tactics: int = 0
var _execution: int = 100
var _data: FightData
var _rng := RandomNumberGenerator.new()
## The inputs it has decided on and not yet held, the next one first.
var _plan: Array[int] = []


## An opponent at `level_name`, drawing its chances from `chance_seed`: the same
## seed against the same inputs plays the same fight.
func _init(level_name: String, data: FightData, chance_seed: int = 0) -> void:
	level = level_name
	_data = data
	_rng.seed = chance_seed
	if LEVELS.has(level_name):
		reaction = int(LEVELS[level_name]["reaction"])
		_tactics = int(LEVELS[level_name]["tactics"])
		_execution = int(LEVELS[level_name]["execution"])


## A new fight has begun: whatever it was doing is dropped. `FightDelay`
## calls this when the fights it is handed stop following on from each other;
## an opponent that remembers more than its plan forgets it here too.
func new_fight() -> void:
	_plan.clear()
	situation = "nothing seen yet"  # not shown as written: an identifier, or the digest's English (FightWords)
	seen_frame = -1
	choice = "nothing yet"  # not shown as written: an identifier, or the digest's English (FightWords)


## Its input this frame, as player `me`, from `seen` -- the fight as it was
## `reaction` frames ago. It carries on with what it last decided, and looks
## at `seen` again only once that is played out.
func choose(seen: FightState, me: int) -> int:
	if _plan.is_empty():
		_decide(seen, me)
	return _plan.pop_front()


# Name the situation, draw an option the level knows, let execution spoil it
# or not, and turn it into inputs.
func _decide(seen: FightState, me: int) -> void:
	seen_frame = seen.frame
	situation = situation_of(seen, me, _data)
	var chosen: String = _draw(situation, seen.fighters[me].character)
	choice = FightWords.word(chosen)
	var late: int = 0
	if _rng.randi_range(1, 100) > _execution:
		if _rng.randi_range(0, 1) == 0:
			late = HESITATION_FRAMES
			choice += " " + tr("(fumbled: late)")
		else:
			chosen = _slip(seen.fighters[me].character)
			choice += " " + tr("(fumbled: came out as {action})").format({action = FightWords.word(chosen)})
	_plan = _held(0, late) + _inputs_for(chosen, seen, me)


## Which of the seven situations `seen` is, for player `me`: its own stun
## first, then what the other fighter is doing -- blocking, evading, a move
## past its active frames that has not connected, which has missed, or a
## crouch.
static func situation_of(seen: FightState, me: int, data: FightData) -> String:
	var mine: FighterState = seen.fighters[me]
	var other: FighterState = seen.fighters[1 - me]
	if mine.stun_kind == "hit":
		return "after being hit"  # not shown as written: an identifier, or the digest's English (FightWords)
	if mine.stun_kind == "block":
		return "after blocking"  # not shown as written: an identifier, or the digest's English (FightWords)
	if other.stun_kind == "block":
		return "it blocked"  # not shown as written: an identifier, or the digest's English (FightWords)
	if other.stun_kind == FightBackdash.KIND:
		return "it evaded"  # not shown as written: an identifier, or the digest's English (FightWords)
	if other.move != "" and not other.connected and FightBoxes.phase(other, data) == "recovery":
		return "it whiffed"  # not shown as written: an identifier, or the digest's English (FightWords)
	if other.crouching and other.is_free():
		return "it crouches"  # not shown as written: an identifier, or the digest's English (FightWords)
	return "neutral"  # not shown: an identifier


# One of the options the level knows, drawn by weight.
func _draw(name: String, character: String) -> String:
	var known: Array = _weighted_options(name, character)
	var total: int = 0
	for option: Array in known:
		total += int(option[1])
	var ticket: int = _rng.randi_range(1, total)
	for option: Array in known:
		ticket -= int(option[1])
		if ticket <= 0:
			return option[0]
	return known.back()[0]


## The options the level knows in the situation `name`, as `[option, weight]`
## -- the first `tactics` of its list that `character` has a move for. An
## opponent that learns (T17) changes the weights here and nothing else.
func _weighted_options(name: String, character: String) -> Array:
	return SITUATIONS[name].slice(0, _tactics).filter(
			func(option: Array) -> bool: return _has_option(character, option[0]))


# Any option of the neutral list, the longest: what a slipped hand does.
func _slip(character: String) -> String:
	var every: Array = SITUATIONS["neutral"].filter(
			func(option: Array) -> bool: return _has_option(character, option[0]))
	return every[_rng.randi_range(0, every.size() - 1)][0]


# True when the character can do the option: every guard, step and evade,
# and a strike only at a height it has a move for -- the dancer has no
# overhead.
func _has_option(character: String, option: String) -> bool:
	return not option in FightData.HEIGHTS or strike_for(_data, character, option) != ""


## The character's quickest move from the ground at `height`, or "" when it
## has none. Quickest, because an answer to a situation seen late is already
## late; from the ground, because this opponent does not jump.
static func strike_for(data: FightData, character: String, height: String) -> String:
	var found: String = ""
	var moves: Dictionary = data.character(character)["moves"]
	for name: String in moves:
		if moves[name]["stance"] == "air" or moves[name]["height"] != height:  # not shown: an identifier
			continue
		if found == "" or moves[name]["startup"] < moves[found]["startup"]:
			found = name
	return found


# The option as one input per frame, aimed from where the two stood in `seen`.
# A crouch and a jump are here for the opponents that imitate a player
# (T18); no situation of this one's offers them.
func _inputs_for(option: String, seen: FightState, me: int) -> Array[int]:
	var mine: FighterState = seen.fighters[me]
	var other: FighterState = seen.fighters[1 - me]
	var toward: int = FightInput.RIGHT if other.x > mine.x else FightInput.LEFT
	var away: int = FightInput.LEFT if toward == FightInput.RIGHT else FightInput.RIGHT
	match option:
		"guard standing":
			return _held(away, GUARD_FRAMES)
		"guard crouching":
			return _held(away | FightInput.DOWN, GUARD_FRAMES)
		"step in":
			return _held(toward, STEP_FRAMES)
		"step out":
			return _held(away, STEP_FRAMES)
		"crouch":
			return _held(FightInput.DOWN, GUARD_FRAMES)
		"jump":
			return _held(FightInput.UP | toward, STEP_FRAMES)
		"evade":
			return _evade(mine.character)
	var move: String = strike_for(_data, mine.character, option)
	if not _reaches(move, mine, other):
		choice += tr(", out of reach: steps in")
		return _held(toward, STEP_FRAMES)
	choice += " -- " + move
	return _pressed(move, mine.character)


# True when the move's hitbox, thrown from where it stood, would find the
# other's body where it stood.
func _reaches(move: String, mine: FighterState, other: FighterState) -> bool:
	var far: int = int(_data.move(mine.character, move)["hitbox"][1])
	var body: int = int(_data.character(other.character)["body"])
	return absi(other.x - mine.x) - body <= far


# The move's button pressed on one frame, then nothing held for the rest of
# the move -- or down held throughout, for a crouching move, so that it comes
# out crouching even if the press waits in the buffer.
func _pressed(move: String, character: String) -> Array[int]:
	var frames: Dictionary = _data.move(character, move)
	var down: int = FightInput.DOWN if frames["stance"] == "crouching" else 0  # not shown: an identifier
	var inputs: Array[int] = _held(down, _data.length_of(character, move))
	inputs[0] = FightInput.BUTTONS[frames["button"]] | down
	return inputs


# The evade pressed on one frame, then nothing held while the backdash lasts.
func _evade(character: String) -> Array[int]:
	var inputs: Array[int] = _held(0, int(_data.character(character)["backdash"]["frames"]))
	inputs[0] = FightInput.EVADE
	return inputs


# `input` held for `frames` frames.
static func _held(input: int, frames: int) -> Array[int]:
	var inputs: Array[int] = []
	inputs.resize(frames)
	inputs.fill(input)
	return inputs
