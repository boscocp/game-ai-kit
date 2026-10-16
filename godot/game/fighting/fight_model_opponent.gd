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

## Every action it can see you do, and predict: `FightAction`'s.
const ACTIONS: Array[String] = FightAction.ACTIONS
## What answers each action: the options to lean towards when it is expected.
## A high is ducked and punished low; a low is guarded crouching; an
## overhead, standing; a throw loses to a strike; a jump to a strike aimed
## up; a guard to what goes round it -- a low or a throw for a standing one,
## an overhead or a throw for a crouching one; a backdash to its longest
## strike, which arrives as the backdash stops, and a throw to a backdash,
## which it passes through.
const ANSWERS: Dictionary = {
	"high": ["guard crouching", "low"], "mid": ["guard standing", "guard crouching"], "low": ["guard crouching"],
	"overhead": ["guard standing", "high"], "throw": ["high", "mid", "evade"], "jump": ["high"],
	"crouch": ["overhead", "throw"], "guard crouching": ["overhead", "throw"], "guard standing": ["low", "throw"],
	"step in": ["mid", "throw"], "step out": ["step in"], "evade": ["long", "step in"],
}
## How much weight an answer gains when the model is as sure as it can be;
## none when it knows no more than chance, and in between in proportion.
## "As sure as it can be" is the predictor's `ceiling`, not 1: at decay 0.8
## a context remembers at most five sightings, and the surest it gets about
## one of eleven actions is 6 in 16. The options' own weights are 1 to 4, so
## a sure prediction makes an answer the likely draw without making it the
## only one -- when the level has an answer at all: easy knows two options a
## situation, and against many actions none of them is one.
const LEAN: int = 8
## How many of its last guesses the panel shows the score of.
const SCORED: int = 20

## The table, read by the panel.
var model: NGramPredictor
## What it expected you to do next at its last decision, how sure it was,
## the context it was expecting it after, and whether its level had an answer
## to lean towards. The table moves on every frame it watches; these do not.
var expected: String = "nothing yet"
var confidence: float = 0.0
var expected_after: String = ""
var answered: bool = false
## For each action it has seen: whether it had guessed it. Newest last.
var guesses: Array[bool] = []

var _last_action: String = ""


## An opponent at `level_name` whose model looks at the last `order - 1`
## actions and forgets at `decay` (ADR 0016; `NGramPredictor`).
func _init(level_name: String, data: FightData, chance_seed: int = 0, order: int = 2, decay: float = 0.8) -> void:
	super(level_name, data, chance_seed)
	model = NGramPredictor.new(order, ACTIONS, decay, 1.0)
	if model.problem() != "":
		push_error("FightModelOpponent: " + model.problem())


## A new fight: an empty table, as ADR 0016 promises, and no guesses.
func new_fight() -> void:
	super()
	model = NGramPredictor.new(model.order, ACTIONS, model.decay, model.prior)
	guesses.clear()
	_last_action = ""
	expected = "nothing yet"
	confidence = 0.0
	expected_after = ""
	answered = false


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


## What fighter `index` is doing in `state`: `FightAction.of`, kept here
## under the name T17 gave it.
static func action_of(state: FightState, index: int, data: FightData) -> String:
	return FightAction.of(state, index, data)


# As the fixed opponent's, and the choice says what it was expecting.
func _decide(seen: FightState, me: int) -> void:
	super(seen, me)
	var leaning: String = "" if answered else ", no answer among its options"
	choice += " (expecting %s, %d%%%s)" % [expected, roundi(confidence * 100.0), leaning]


## How many of its last `SCORED` guesses were right, and of how many.
func score() -> Array[int]:
	var recent: Array[bool] = guesses.slice(maxi(0, guesses.size() - SCORED))
	return [recent.count(true), recent.size()]


# The level's options, the answers to the expected action weighted up by how
# much surer than chance the model is: 0 at chance, `LEAN` at its ceiling.
func _weighted_options(name: String, character: String) -> Array:
	expected = model.likeliest()
	expected_after = model.context()
	confidence = model.probabilities()[expected]
	var lean: int = lean_for(confidence)
	var answers: Array = ANSWERS[expected]
	var known: Array = super(name, character)
	answered = known.any(func(option: Array) -> bool: return option[0] in answers)
	return known.map(func(option: Array) -> Array: return [option[0], int(option[1]) + (lean if option[0] in answers else 0)])


## How much an answer gains at `sureness`: in proportion to where it lies
## between chance (nothing) and the model's ceiling (`LEAN`).
func lean_for(sureness: float) -> int:
	var chance: float = 1.0 / ACTIONS.size()
	return roundi(LEAN * clampf((sureness - chance) / (model.ceiling() - chance), 0.0, 1.0))
