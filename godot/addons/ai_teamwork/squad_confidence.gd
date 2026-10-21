## Whether a squad attacks, holds or retreats, and how it retreats: in two
## waves, one moving back while the other covers it.
##
## Days Gone's squads keep a confidence -- friendly strength over enemy
## strength, plus kills, minus losses -- that picks attack, hold or retreat
## [Karlsson 2021]. Thresholds with a gap between entering and leaving a state
## keep a squad from flickering between two on a number that hovers at one.
## And they "retreat in waves, with half of them moving back to a new cover,
## while the other half provides cover fire": the members split in two by
## their order in the squad, one half moves while the other shoots, and they
## swap when the movers have arrived. Constant time per decision.
##
## When not to use it: for a lone bot. Confidence is a squad's, and one bot's
## health over its enemy's is just whether to flee, which a threshold says.
class_name SquadConfidence
extends RefCounted

const ATTACK: String = "attack"
const HOLD: String = "hold"
const RETREAT: String = "retreat"


## What the confidence is made of, for one squad at one moment.
class Facts extends RefCounted:
	## Each living member's health as a share of full, added.
	var friendly_strength: float = 0.0
	## The same for the enemies the squad knows of near it.
	var enemy_strength: float = 0.0
	## Enemies the squad killed, and members it lost, lately.
	var kills: int = 0
	var losses: int = 0


## The thresholds. The gaps between entering and leaving a state are what
## stop a squad flickering.
class Thresholds extends RefCounted:
	var attack_at: float = 1.3
	## An attacking squad keeps attacking down to this.
	var keep_attacking_at: float = 1.1
	var retreat_at: float = 0.7
	## A retreating squad stops retreating once back up to this.
	var recover_at: float = 1.0
	## What one kill and one loss are worth.
	var per_kill: float = 0.25
	var per_loss: float = 0.25
	## The enemy strength is at least this, so a squad that sees nobody has
	## a large, finite confidence rather than a division by zero.
	var least_enemy: float = 0.5


## Which half of a retreating squad moves, and which covers.
class Waves extends RefCounted:
	var moving: Array[int] = []
	var covering: Array[int] = []


## The squad's confidence now.
static func confidence(facts: Facts, thresholds: Thresholds) -> float:
	var ratio: float = facts.friendly_strength / maxf(facts.enemy_strength, thresholds.least_enemy)
	return ratio + thresholds.per_kill * facts.kills - thresholds.per_loss * facts.losses


## The squad's state after `previous`, at confidence `value`. `may_retreat`
## false is the toggle: a squad that never falls back holds instead.
static func next_state(previous: String, value: float, thresholds: Thresholds,
		may_retreat: bool) -> String:
	if previous == RETREAT and value < thresholds.recover_at and may_retreat:
		return RETREAT
	if value <= thresholds.retreat_at:
		return RETREAT if may_retreat else HOLD
	if value >= thresholds.attack_at:
		return ATTACK
	if previous == ATTACK and value >= thresholds.keep_attacking_at:
		return ATTACK
	return HOLD


## The two waves of a retreat, for `members` in the squad's order: even
## places move first in phase 0, odd places in phase 1. With one member it
## moves alone, in either phase -- nobody is left to cover it.
static func waves(members: Array[int], phase: int) -> Waves:
	var split := Waves.new()
	for index: int in range(members.size()):
		var moves_now: bool = members.size() == 1 or index % 2 == phase % 2
		if moves_now:
			split.moving.append(members[index])
		else:
			split.covering.append(members[index])
	return split
