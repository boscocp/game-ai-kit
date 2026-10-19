## How an attack is likely to go, worked out from the rules and the faces of
## the die -- never from the board's next roll.
##
## `TacticalCombat` decides a fight by rolling dice seeded from
## `BoardState.dice_seed`. A controller that played the attack on a copy of
## the board would therefore know how it ends before choosing it, which is
## seeing the future -- a cheat, and the one a lookahead falls into first.
## What a player knows is the rules and the die: one to four, each face as
## likely. This works out, from exactly that, the chance the attacker wins
## and what each side keeps on average, by following every roll.
##
## A fight between walkers is the recursion the rules describe: the attacker
## swings, then the defender (if it can reach), round after round. The round
## matters only until the attacker's friend arrives, so rounds past that are
## one case. A siege is one swing and one back.
##
## Complexity: per fight, at most healths x healths x a few rounds of cases,
## each a sum over the die's faces; remembered by its inputs, for as long as
## the program runs -- the rules do not change while it does -- so each
## distinct fight is worked out once.
##
## When not to use it: dice with many faces or fights with long memories --
## the cases multiply, and a few hundred rolled samples are the cheaper
## answer.
class_name FightOdds
extends RefCounted

# A fight's inputs, packed by `_key` -> [chance the attacker wins, attacker's
# health left on average, defender's health left on average].
static var _known: Dictionary[int, Array] = {}


## The chance this attack wins, as [win, attacker_left, defender_left]:
## `inputs` is `TacticalCombat.inputs` for the attack, and `siege` says
## whether a building is involved (one blow and one back).
static func of(inputs: Dictionary, siege: bool) -> Array[float]:
	var key: int = _key(inputs, siege)
	if not _known.has(key):
		var cases: Dictionary = {}
		_known[key] = _siege(inputs) if siege else _round(inputs, inputs["attacker_health"], inputs["defender_health"], 1, cases)
	return _known[key]


## The odds of `attacker` attacking `defender` on `state` as it stands.
static func of_attack(state: BoardState, attacker: Unit, defender: Unit) -> Array[float]:
	var siege: bool = not attacker.type.mobile or not defender.type.mobile
	return of(TacticalCombat.inputs(state, attacker, defender), siege)


# From round `round_number` on, with these healths left: every face of the
# attacker's die, then every face of the defender's, as the rules swing them.
# `cases` remembers each (healths, round) already worked out in this fight.
static func _round(inputs: Dictionary, attacker_left: int, defender_left: int, round_number: int,
		cases: Dictionary) -> Array[float]:
	var case: Vector3i = Vector3i(attacker_left, defender_left, round_number)
	if cases.has(case):
		return cases[case]
	var faces: Array[int] = _faces()
	var total: Array[float] = [0.0, 0.0, 0.0]
	for face: int in faces:
		var defender_now: int = defender_left - face - TacticalCombat.attacker_bonus(inputs, round_number)
		if defender_now <= 0:
			_add(total, [1.0, float(attacker_left), 0.0], 1.0 / faces.size())
		elif not inputs["defender_hits_back"]:
			_add(total, _next_round(inputs, attacker_left, defender_now, round_number, cases), 1.0 / faces.size())
		else:
			_add(total, _hit_back(inputs, attacker_left, defender_now, round_number, cases), 1.0 / faces.size())
	cases[case] = total
	return total


# The defender's swing, every face, and then the next round.
static func _hit_back(inputs: Dictionary, attacker_left: int, defender_left: int, round_number: int,
		cases: Dictionary) -> Array[float]:
	var faces: Array[int] = _faces()
	var total: Array[float] = [0.0, 0.0, 0.0]
	for face: int in faces:
		var attacker_now: int = attacker_left - face - TacticalCombat.defender_bonus(inputs)
		if attacker_now <= 0:
			_add(total, [0.0, 0.0, float(defender_left)], 1.0 / faces.size())
		else:
			_add(total, _next_round(inputs, attacker_now, defender_left, round_number, cases), 1.0 / faces.size())
	return total


# The next round -- the same as this one once the friend has arrived, so a
# round number past that is one case, not a new one each time.
static func _next_round(inputs: Dictionary, attacker_left: int, defender_left: int, round_number: int,
		cases: Dictionary) -> Array[float]:
	var arrived: int = int(inputs["reinforcement_distance"]) + 1
	return _round(inputs, attacker_left, defender_left, mini(round_number + 1, arrived), cases)


# One blow, and one back -- every face of each -- if the other side can
# reach and still stands.
static func _siege(inputs: Dictionary) -> Array[float]:
	var faces: Array[int] = _faces()
	var total: Array[float] = [0.0, 0.0, 0.0]
	for face: int in faces:
		var defender_now: int = maxi(inputs["defender_health"] - face - TacticalCombat.attacker_bonus(inputs, 1), 0)
		if defender_now == 0:
			_add(total, [1.0, float(inputs["attacker_health"]), 0.0], 1.0 / faces.size())
			continue
		for back: int in faces:
			var hurt: int = back + TacticalCombat.defender_bonus(inputs) if inputs["defender_hits_back"] else 0
			var attacker_now: int = maxi(inputs["attacker_health"] - hurt, 0)
			_add(total, [0.0, float(attacker_now), float(defender_now)], 1.0 / (faces.size() * faces.size()))
	return total


# The inputs as one number, eight bits each: asked thousands of times a turn,
# a key made by printing the dictionary was most of what the search cost.
# Every input here is far inside its eight bits -- healths at most a
# building's, the rest single digits -- and the signed ones are shifted up.
static func _key(inputs: Dictionary, siege: bool) -> int:
	var fields: Array[int] = [
		inputs["attacker_health"], inputs["defender_health"], inputs["numeric_advantage"] + 64,
		inputs["defender_terrain"], inputs["reinforcement_distance"], inputs["counter"] + 1,
		1 if inputs["defender_hits_back"] else 0, 1 if siege else 0]
	var key: int = 0
	for field: int in fields:
		key = (key << 8) | (field & 0xFF)
	return key


static func _faces() -> Array[int]:
	var die: Dictionary = TacticalCombat.rules()["die"]
	var faces: Array[int] = []
	for face: int in range(int(die["lowest"]), int(die["highest"]) + 1):
		faces.append(face)
	return faces


static func _add(total: Array[float], outcome: Array[float], weight: float) -> void:
	for index: int in range(total.size()):
		total[index] += outcome[index] * weight
