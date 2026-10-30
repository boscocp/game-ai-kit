## The fixed opponent with a bandit in each situation: it learns, during the
## fight, which of its answers works against *you* (T99).
##
## Everything T37 holds still holds: the seven situations, the level's
## options in each, the reaction it sees the fight late by, and the
## execution that spoils a choice now and then. What changes is the draw.
## T37 draws an option by a fixed weight; this keeps one `Bandit` per
## situation, from `ai_bandit`, whose arms are that situation's options, and
## asks it. UCB1 tries every option once, then the one whose mean payoff plus
## exploration term is highest -- so it keeps going back to an answer it
## knows little about, and drops one that keeps losing. T17's learner
## predicts what you will do; this one only measures what its own answers
## earned. The two are beside each other in the dummy's modes.
##
## **The payoff** of an option is what happened to the health lead while it
## played and for `PAYOFF_WINDOW` frames after: the lead when its first
## input lands, subtracted from the lead when the window closes, scaled by
## `PAYOFF_RANGE` into [0, 1] -- 0.5 for nothing changed, 1 for a swing of
## `PAYOFF_RANGE` its way. It is read off the late fight it is handed, like
## everything it knows: an option chosen on seen frame `s` has its first
## input applied to frame `s + reaction`, so its lead is read off that frame,
## and it is paid when the frame its window closes on is handed to it.
## Windows overlap -- an option chosen while the last is still being watched
## shares some of its frames, so a hit can be credited to two options --
## and an option still waiting when the fight ends is never paid. The task
## asked for a window "after the option ends"; this one starts where the
## option lands, so a strike's own hit is in its payoff.
##
## The next decision comes before the last payoff is known, so a choice is
## counted as a pull when it is made (`Bandit.pull`) and paid when its
## window closes (`Bandit.pay`): an option waiting for its payoff is not
## untried, and is not chosen again for being poorly known. An option execution spoilt is paid as
## the option chosen: what an answer earns includes how often this level
## fumbles it.
##
## The counting happens in the game, starts empty every fight, and can be
## rebuilt from the fight's input log: ADR 0016 and its amendment say why
## that is not the training invariant 6 forbids, and N13 holds the shape.
##
## Complexity: constant per frame -- a decision is a lookup and one bandit's
## choice, linear in its options.
##
## When not to use it: an opponent that should not get better at beating
## one player; and a short fight against many situations, where each bandit
## is pulled too few times to try every option -- the hard level's neutral
## has ten.
class_name FightBanditOpponent
extends FightOpponent

## How many frames after an option's last input the payoff waits for, so a
## strike's hit or a guard's punish has landed: half a second.
const PAYOFF_WINDOW: int = 30
## The health swing that is a whole payoff either way: about one heavy hit
## (the frame data's heaviest strikes do 90 to 110).
const PAYOFF_RANGE: int = 100
## UCB1's exploration constant: 0.5, not the textbook's square root of two
## (`Bandit.EXPLORATION`). That one is sized for payoffs that may lie
## anywhere in [0, 1]; over four in five of these lie within a quarter of
## 0.5, and nearly half on it (2,481 payoffs, twenty fights of the medium
## bandit against the turtle and the rushdown stand-ins), so at the square
## root of two the exploration term outweighs every difference in mean,
## and the busiest bandit is still changing its mind late in the fight.
## Measured (`make measure-bandit`, the fighting page): at 0.5 it wins at
## least as often as at the square root of two against every stand-in and
## the owner's ghost, and settles sooner -- chosen against those same
## opponents, so the page says how far to trust it.
const EXPLORATION: float = 0.5

## One bandit for each situation it has seen this fight, by the situation's
## name; and that bandit's arms, by name, in the order the level knows them.
var bandits: Dictionary = {}
var options_of: Dictionary = {}
## The arm it chose at its last decision, in `situation`'s bandit; -1 before
## its first.
var chosen_arm: int = -1
## Every arm of that bandit as it stood when it chose -- option, pulls,
## mean and bound -- for the panel to draw. Empty before its first.
var chosen_from: Array[Dictionary] = []
## The last option paid: its situation, its name and what it earned. Empty
## until the first window closes.
var last_paid: Dictionary = {}
## The exploration constant its bandits are made with: `EXPLORATION`,
## unless a measurement asks for another before the first decision.
var exploration: float = EXPLORATION

## Options played and not yet paid, oldest first: each its situation, arm,
## the frame it lands on, the frame its window closes on, and the lead it
## started from once that frame was seen.
var _waiting: Array[Dictionary] = []


## A new fight: no bandits, as ADR 0016 promises, and nothing waiting.
func new_fight() -> void:
	super()
	bandits.clear()
	options_of.clear()
	_waiting.clear()
	chosen_arm = -1
	chosen_from = []
	last_paid = {}


## As the fixed opponent's, after paying every option whose window closes
## on the frame it was handed: every frame is watched, decided on or not.
func choose(seen: FightState, me: int) -> int:
	pay(seen, me)
	return super(seen, me)


## Note the lead for the options landing on `seen`, and pay the ones whose
## window closes on it.
func pay(seen: FightState, me: int) -> void:
	var still: Array[Dictionary] = []
	for played: Dictionary in _waiting:
		if not played.has("before") and seen.frame >= played["lands"]:
			played["before"] = lead(seen, me)
		if seen.frame < played["closes"]:
			still.append(played)
			continue
		_reward(played, payoff(played["before"], lead(seen, me)))
	_waiting = still


# Count the option `played` as pulled in its situation's bandit, paying
# `earned`, and keep it as the last paid for the panel.
func _reward(played: Dictionary, earned: float) -> void:
	var name: String = played["situation"]
	(bandits[name] as Bandit).pay(played["arm"], earned)
	last_paid = {"situation": name, "option": options_of[name][played["arm"]], "payoff": earned}


## How far ahead on health player `me` is in `state`: its health less the
## other's.
static func lead(state: FightState, me: int) -> int:
	return state.fighters[me].health - state.fighters[1 - me].health


## What a change of lead from `before` to `after` earns: 0.5 for none, and
## `PAYOFF_RANGE` either way reaches 1 or 0, beyond which it stays.
static func payoff(before: int, after: int) -> float:
	return clampf(0.5 + float(after - before) / (2.0 * PAYOFF_RANGE), 0.0, 1.0)


## The bandit for the situation it last named, or null before its first
## decision: what the panel draws.
func current_bandit() -> Bandit:
	return bandits.get(situation)


# As the fixed opponent's, and the option, once chosen, waits to be paid.
func _decide(seen: FightState, me: int) -> void:
	super(seen, me)
	var lands: int = seen.frame + reaction
	_waiting.append({"situation": situation, "arm": chosen_arm, "lands": lands,
			"closes": lands + _plan.size() + PAYOFF_WINDOW})


# The bandit's choice among the options the level knows in `name`, instead
# of a draw by weight. The bandit is made the first time the situation is
# seen, one arm an option, and kept until the fight ends.
func _draw(name: String, character: String) -> String:
	if not bandits.has(name):
		var known: Array = _weighted_options(name, character)
		options_of[name] = known.map(func(option: Array) -> String: return option[0])
		bandits[name] = Bandit.new(known.size(), Bandit.UCB1, exploration)
	var bandit: Bandit = bandits[name]
	chosen_arm = bandit.choose()
	chosen_from = _rows_of(bandit, name)
	bandit.pull(chosen_arm)
	return options_of[name][chosen_arm]


# Each arm as the bandit saw it when it chose: its option, pulls, mean and
# bound. Kept, so the panel shows the numbers the choice was made from,
# not ones moved since by other windows closing.
func _rows_of(bandit: Bandit, name: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for arm: int in range(bandit.arms()):
		var option: String = options_of[name][arm]
		rows.append({"option": option, "pulls": bandit.pulls[arm], "mean": bandit.mean(arm), "bound": bandit.bound(arm)})
	return rows
