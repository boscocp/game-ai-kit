## Which of a fixed set of options to try next, by what each has paid so far:
## a multi-armed bandit (AIMA 4th ed., 17.3).
##
## Each option is an *arm*, by its index. Pull one, and it pays something
## between 0 and 1. The bandit keeps, for each arm, how often it was pulled
## and the sum of what it paid -- nothing else -- and chooses the next arm
## from those. The lesson is the dilemma: the arm that has paid best so far
## may only have been lucky, and an arm tried twice may be the best. Always
## take the best mean and you can be stuck on the wrong arm for ever
## (*exploitation*); keep trying the others and you pay for it on every pull
## (*exploration*).
##
## Two answers, by `policy`:
##
## * **UCB1** [Auer, Cesa-Bianchi & Fischer 2002, figure 1]: each arm once,
##   then the arm whose bound is highest -- "the sum of two terms": its mean
##   payoff, and `exploration * sqrt(ln n / n_j)`, which grows with every
##   pull it is left out of and shrinks with every pull it gets. An arm is
##   tried again when it is either good or poorly known. With `exploration`
##   at the square root of two, what is lost to the worse arms grows with the
##   logarithm of the pulls (their theorem 1).
## * **Epsilon-greedy**, for the comparison: each arm once, then with chance
##   `epsilon` any arm at random, otherwise the best mean. At a fixed epsilon
##   it explores for ever, so what it loses grows in proportion to the pulls;
##   `test_bandit.py` measures both over 10,000 pulls.
##
## Of equal bounds or means, the first arm. A draw is spent only when
## epsilon-greedy has a choice to make, so the twin in Python
## (`gameaikit.bandit`) makes the same choices draw for draw.
##
## **It counts; it does not descend** (ADR 0016, amended 2026-10-26). A mean
## is a sum over a count, computed when it is read, and never kept: the
## incremental `mean += (payoff - mean) / n` is the same number with the
## shape of a step towards a target, and `check_no_training.py`'s N13 refuses
## it, with anything that writes the counts down. A bandit starts empty; a
## game that wants it to forget makes a new one.
##
## Complexity: `choose` and `reward` are linear in the arms; the state is two
## numbers an arm.
##
## When not to use it: options whose worth depends on the situation -- that
## is a contextual bandit, or a table of bandits, one a situation, as the
## fighting game keeps (`FightBanditOpponent`); payoffs that drift, which
## UCB1 follows slowly because an old pull counts as much as a new one; and
## too few pulls to try every arm, where a hand-written weight is better.
class_name Bandit
extends RefCounted

## Choose by the highest upper confidence bound.
const UCB1: String = "ucb1"
## Choose the best mean, except with chance `epsilon` any arm at random.
const EPSILON_GREEDY: String = "epsilon-greedy"
## UCB1's constant, the square root of two: Auer, Cesa-Bianchi and Fischer's
## bound for payoffs between 0 and 1 is `mean + sqrt(2 ln n / n_j)`.
const EXPLORATION: float = 1.4142135623730951
## How often epsilon-greedy explores, when nobody says.
const EPSILON: float = 0.1

## `UCB1` or `EPSILON_GREEDY`.
var policy: String
## How much UCB1 weighs being poorly known against having paid well.
var exploration: float
## The chance epsilon-greedy pulls an arm at random.
var epsilon: float
## How often each arm was pulled, by its index.
var pulls: PackedInt64Array = PackedInt64Array()
## What each arm paid, summed, by its index. A mean is `sums[arm] / pulls[arm]`.
var sums: PackedFloat64Array = PackedFloat64Array()

var _draws: BanditDraws


## A bandit over `arm_count` arms, none pulled yet, choosing by `choosing_by`
## and drawing from `draws_seed`. `problem` says what is wrong with any of it.
func _init(arm_count: int, choosing_by: String = UCB1, exploration_constant: float = EXPLORATION,
		explore_chance: float = EPSILON, draws_seed: int = BanditDraws.SEED_FOR_ZERO) -> void:
	policy = choosing_by
	exploration = exploration_constant
	epsilon = explore_chance
	pulls.resize(maxi(arm_count, 0))
	sums.resize(maxi(arm_count, 0))
	_draws = BanditDraws.new(draws_seed)


## What is wrong with the settings, or "" when nothing is.
func problem() -> String:
	if pulls.is_empty():
		return "a bandit needs at least one arm"
	if policy != UCB1 and policy != EPSILON_GREEDY:
		return "the policy is %s or %s, not %s" % [UCB1, EPSILON_GREEDY, policy]
	if exploration < 0.0:
		return "the exploration constant is 0 or more, and is %s" % exploration
	if epsilon < 0.0 or epsilon > 1.0:
		return "epsilon is a chance, between 0 and 1, and is %s" % epsilon
	return ""


## How many arms it chooses among.
func arms() -> int:
	return pulls.size()


## How many pulls, of every arm: the `n` in UCB1's bound.
func total() -> int:
	var counted: int = 0
	for pulled: int in pulls:
		counted += pulled
	return counted


## The arm's mean payoff, computed when it is read; 0 before its first pull.
func mean(arm: int) -> float:
	if pulls[arm] == 0:
		return 0.0
	return sums[arm] / pulls[arm]


## UCB1's bound for the arm: its mean plus the exploration term, which is
## what a person reads to see why it chose. Infinite for an arm never pulled,
## since UCB1 tries every arm before it compares any.
func bound(arm: int) -> float:
	if pulls[arm] == 0:
		return INF
	return mean(arm) + exploration * sqrt(log(float(total())) / pulls[arm])


## The arm to pull next, by the policy. Choosing changes no count: only
## `reward` does, so a game may ask and then play something else.
func choose() -> int:
	var untried: int = _first_untried()
	if untried >= 0:
		return untried
	if arms() == 1:
		return 0
	if policy == UCB1:
		return _highest(bound)
	if _draws.uniform() < epsilon:
		return _draws.index(arms())
	return _highest(mean)


## Count one pull of `arm` and add what it paid, kept to [0, 1], where
## UCB1's bound holds.
func reward(arm: int, payoff: float) -> void:
	pulls[arm] += 1
	sums[arm] += clampf(payoff, 0.0, 1.0)


# The first arm never pulled, or -1 when every one has been.
func _first_untried() -> int:
	for arm: int in range(arms()):
		if pulls[arm] == 0:
			return arm
	return -1


# The arm with the highest `score`; of equal ones, the first.
func _highest(score: Callable) -> int:
	var best: int = 0
	for arm: int in range(1, arms()):
		if score.call(arm) > score.call(best):
			best = arm
	return best
