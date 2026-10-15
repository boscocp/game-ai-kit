## The fixed opponent with an n-gram behind it: it learns what you do after
## what, during the fight, and leans its choices towards the answer (T17).
##
## Everything T37 holds still holds. It is seated behind `FightDelay`, so it
## watches the same late fight it decides from: it learns from what was on
## screen `reaction` frames ago, never from a press it could not yet have
## seen. Its level's tactics and execution are unchanged; the model only
## changes how often each known option is drawn. A perfect predictor is no
## fun, and this one is not allowed to be one: it can only weight the
## options its level already has (T36's survey).
##
## What it watches is your **action**, read off your fighter as it was drawn:
## the height of the move you started, a jump, a guard you were seen holding
## (blockstun shows it), a crouch, a step in or out. A new action is one that
## differs from the last frame's; standing still between two jabs makes them
## two actions. The table is `NGramPredictor`'s, from `ai_opponent`.
##
## The counting happens in the game, and starts empty every fight: ADR 0016
## records why that is not the training invariant 6 forbids.
##
## When not to use it: an opponent that should not get better at beating
## one player -- a tutorial, a fixed difficulty somebody chose on purpose.
class_name FightModelOpponent
extends FightOpponent

## Every action it can see you do, and predict.
const ACTIONS: Array[String] = ["step in", "step out", "crouch", "jump", "high", "mid", "low", "overhead", "throw",
		"guard standing", "guard crouching"]
## What answers each action: the options to lean towards when it is expected.
## A high is ducked and punished low; a low is guarded crouching; an
## overhead, standing; a throw loses to a strike; a jump to a strike aimed
## up; a guard to what goes round it -- a low or a throw for a standing one,
## an overhead or a throw for a crouching one.
const ANSWERS: Dictionary = {
	"high": ["guard crouching", "low"], "mid": ["guard standing", "guard crouching"], "low": ["guard crouching"],
	"overhead": ["guard standing", "high"], "throw": ["high", "mid"], "jump": ["high"],
	"crouch": ["overhead", "throw"], "guard crouching": ["overhead", "throw"], "guard standing": ["low", "throw"],
	"step in": ["mid", "throw"], "step out": ["step in"],
}
## How much weight an answer gains when the model is certain; none when it
## knows no more than chance, and in between in proportion. The options'
## own weights are 1 to 4, so a sure prediction makes the answer the likely
## draw without making it the only one.
const LEAN: int = 8
## How many of its last guesses the panel shows the score of.
const SCORED: int = 20

## The table, read by the panel.
var model: NGramPredictor
## What it expects you to do next, and how sure it is, as of its last look.
var expected: String = "nothing yet"
var confidence: float = 0.0
## For each action it has seen: whether it had guessed it. Newest last.
var guesses: Array[bool] = []

var _last_action: String = ""


## An opponent at `level_name` whose model looks at the last `order - 1`
## actions and forgets at `decay` (ADR 0016; `NGramPredictor`).
func _init(level_name: String, data: FightData, chance_seed: int = 0, order: int = 2, decay: float = 0.8) -> void:
	super(level_name, data, chance_seed)
	model = NGramPredictor.new(order, ACTIONS, decay, 1.0)


## As the fixed opponent's, after watching the frame it was handed: every
## frame it is handed is watched, whether or not it decides on it.
func choose(seen: FightState, me: int) -> int:
	watch(seen, me)
	return super(seen, me)


## Read the other fighter's action in `seen` and, when it is a new one, score
## the last guess against it and count it.
func watch(seen: FightState, me: int) -> void:
	var action: String = action_of(seen, 1 - me, _data)
	if action != "" and action != _last_action:
		guesses.append(model.likeliest() == action)
		model.observe(action)
	_last_action = action


## What fighter `index` is doing in `state`, as one of `ACTIONS`, or "" when
## it is doing nothing to learn from -- standing, stunned by a hit, landing.
static func action_of(state: FightState, index: int, data: FightData) -> String:
	var fighter: FighterState = state.fighters[index]
	if fighter.is_airborne() or fighter.stun_kind == "takeoff":
		return "jump"
	if fighter.move != "":
		return data.move(fighter.character, fighter.move)["height"]
	if fighter.stun_kind == "block":
		return "guard crouching" if fighter.crouching else "guard standing"
	if fighter.stun > 0:
		return ""
	if fighter.crouching:
		return "crouch"
	var walking: int = FightInput.walk_direction(fighter.held_before)
	if walking == 0:
		return ""
	var toward: int = signi(state.fighters[1 - index].x - fighter.x)
	return "step in" if walking == toward else "step out"


# As the fixed opponent's, and the choice says what it was expecting.
func _decide(seen: FightState, me: int) -> void:
	super(seen, me)
	choice += " (expecting %s, %d%%)" % [expected, roundi(confidence * 100.0)]


## How many of its last `SCORED` guesses were right, and of how many.
func score() -> Array[int]:
	var recent: Array[bool] = guesses.slice(maxi(0, guesses.size() - SCORED))
	return [recent.count(true), recent.size()]


# The level's options, the answers to the expected action weighted up by how
# much surer than chance the model is: 0 at chance, `LEAN` when certain.
func _weighted_options(name: String, character: String) -> Array:
	expected = model.likeliest()
	confidence = model.probabilities()[expected]
	var chance: float = 1.0 / ACTIONS.size()
	var lean: int = roundi(LEAN * maxf(0.0, confidence - chance) / (1.0 - chance))
	var answers: Array = ANSWERS[expected]
	return super(name, character).map(func(option: Array) -> Array:
			return [option[0], int(option[1]) + (lean if option[0] in answers else 0)])
