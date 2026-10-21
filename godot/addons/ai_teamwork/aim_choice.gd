## Where on a body to aim: at the zone whose shot is worth the most damage,
## counting the chance of hitting it and of hitting its neighbours instead.
##
## A head is worth more and is harder to hit. Which wins depends on range
## and on the hand: close and steady, the head; far or shaky, the torso,
## because a shot aimed at a head that misses it mostly misses the body. The
## technique says how much each is worth and lets the bot take the larger.
##
## The model is the plainest that keeps both effects. Aimed at a point, a
## shot lands anywhere in a square `spread` either side of it -- the spread
## is the distance times the tangent of the aim error -- with equal chance.
## Each zone is one or more rectangles on the target as the shooter faces
## it, across and up from its feet; the chance of landing in a zone is how
## much of the square its rectangles cover, times how much of it is exposed
## (none, behind cover). A shot that lands in no zone misses. The expected
## damage of aiming at a zone is each zone's chance times its multiplier,
## summed: the spill onto a neighbour counts, as it should.
##
## Constant time: zones times rectangles, a handful. When not to use it: a
## spread that is not even -- a recoil that climbs, a gaussian hand. Then the
## chance of a rectangle is an integral of that density, and the square here
## is the wrong shape; the choice by expected damage stays.
class_name AimChoice
extends RefCounted

## The least spread taken, in metres: a perfectly steady hand.
const SMALLEST_SPREAD: float = 0.001


## One zone of a target: what a hit there is worth, where it is, and how
## much of it the shooter can see.
class Zone extends RefCounted:
	var name: String = ""
	var multiplier: float = 1.0
	## Where a shot aimed at this zone is pointed: across, up from the feet.
	var aim: Vector2 = Vector2.ZERO
	## Its rectangles, in the same plane: position the low corner, size
	## positive. A zone of two parts -- two arms -- has two.
	var rects: Array[Rect2] = []
	## The share of it the shooter can see, 0 to 1.
	var exposure: float = 1.0


## What aiming at each zone is worth, and which won.
class Choice extends RefCounted:
	## For each zone, aimed at: the chance of hitting that zone itself.
	var own_chances: PackedFloat64Array = PackedFloat64Array()
	## For each zone, aimed at: the damage a shot is worth, in multipliers.
	var expected: PackedFloat64Array = PackedFloat64Array()
	## The zone aimed at, the first of equal worth, and where each zone is
	## hit from that aim.
	var aimed: int = -1
	var chances: PackedFloat64Array = PackedFloat64Array()


## The chance a shot aimed at `aim`, spread `spread` either side, lands in
## each zone, in the zones' order.
static func chances_from(aim: Vector2, spread: float, zones: Array[Zone]) -> PackedFloat64Array:
	# Never under a millimetre: `Rect2` is 32-bit, and at a micrometre the
	# overlap of a square round a point a metre up rounds to more than the
	# square -- a chance of 1.013, measured by a vector.
	var reach: float = maxf(spread, SMALLEST_SPREAD)
	var square := Rect2(aim - Vector2(reach, reach), Vector2(reach, reach) * 2.0)
	var found := PackedFloat64Array()
	for zone: Zone in zones:
		var covered: float = 0.0
		for rect: Rect2 in zone.rects:
			covered += _overlap(square, rect)
		found.append(covered / square.get_area() * zone.exposure)
	return found


## The damage a shot aimed at `aim` is worth, in multipliers.
static func expected_from(aim: Vector2, spread: float, zones: Array[Zone]) -> float:
	var chances: PackedFloat64Array = chances_from(aim, spread, zones)
	var worth: float = 0.0
	for index: int in range(zones.size()):
		worth += chances[index] * zones[index].multiplier
	return worth


## Aim at each zone in turn, and keep the one worth the most -- the first,
## of equal worth. No zone, or none worth anything, aims at nothing.
static func choose(zones: Array[Zone], spread: float) -> Choice:
	var choice := Choice.new()
	var best: float = 0.0
	for index: int in range(zones.size()):
		var chances: PackedFloat64Array = chances_from(zones[index].aim, spread, zones)
		choice.own_chances.append(chances[index])
		choice.expected.append(expected_from(zones[index].aim, spread, zones))
		if choice.expected[index] > best:
			best = choice.expected[index]
			choice.aimed = index
			choice.chances = chances
	return choice


## Where a shot lands, given the chances from its aim and one even random
## number in [0, 1): the zones are laid end to end, and `roll` falls in one
## of them or past them all. The zone's index, or -1 for a miss.
static func land(chances: PackedFloat64Array, roll: float) -> int:
	var reached: float = 0.0
	for index: int in range(chances.size()):
		reached += chances[index]
		if roll < reached:
			return index
	return -1


# The area two rectangles share.
static func _overlap(one: Rect2, other: Rect2) -> float:
	var across: float = minf(one.end.x, other.end.x) - maxf(one.position.x, other.position.x)
	var up: float = minf(one.end.y, other.end.y) - maxf(one.position.y, other.position.y)
	return maxf(across, 0.0) * maxf(up, 0.0)
