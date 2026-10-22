## Who does what once a fight starts: requests for a role, granted or
## refused so that someone always shoots and only one goes round.
##
## The Last of Us keeps its fights readable by limiting roles: an arbiter
## grants a flank to one enemy at a time, while the others hold and shoot
## [McIntosh 2015]. So each fighter asks for a role -- shooter or flanker --
## with a score for how well it fits, and whether it can shoot at all. The
## arbiter grants at most `max_flankers` flanks, best score first; every
## other flank request is refused, and the fighter shoots instead when it
## can. Every shooter request is granted. And if no one would be shooting
## though someone can, the best-scoring one who can is made a shooter --
## the fight never goes quiet because everyone went round. Switched off,
## everyone who can shoot does, and no one flanks. Requests are plain data;
## the example decides who asks.
##
## O(requests log requests), for the sort by score.
##
## When not to use it: roles that are places, not jobs -- who holds which
## door. That is `TacticalPositions` with claims.
class_name RoleArbiter
extends RefCounted

const SHOOTER: String = "shooter"
const FLANKER: String = "flanker"
const NONE: String = "none"


## The role each request gets, in the requests' order. `requests`: [{role,
## score, can_shoot}]. `use_arbiter` false: shooter for all who can shoot.
static func grant(requests: Array[Dictionary], use_arbiter: bool, max_flankers: int = 1) -> PackedStringArray:
	var granted := PackedStringArray()
	for request: Dictionary in requests:
		granted.append(SHOOTER if bool(request["can_shoot"]) else NONE)
	if not use_arbiter:
		return granted
	var flankers: int = 0
	for index: int in _by_score(requests):
		if str(requests[index]["role"]) != FLANKER:
			continue
		if flankers < max_flankers:
			granted[index] = FLANKER
			flankers += 1
	_keep_a_shooter(requests, granted)
	return granted


## How many of `granted` are `role`.
static func count(granted: PackedStringArray, role: String) -> int:
	return Array(granted).count(role)


# If no one is shooting and someone who can is flanking, the best of them
# shoots instead.
static func _keep_a_shooter(requests: Array[Dictionary], granted: PackedStringArray) -> void:
	if count(granted, SHOOTER) > 0:
		return
	for index: int in _by_score(requests):
		if bool(requests[index]["can_shoot"]) and granted[index] == FLANKER:
			granted[index] = SHOOTER
			return


# The requests' indices, highest score first; the earlier of equal scores.
static func _by_score(requests: Array[Dictionary]) -> Array[int]:
	var order: Array[int] = []
	for index: int in range(requests.size()):
		order.append(index)
	order.sort_custom(func(one: int, other: int) -> bool:
		var first: float = float(requests[one]["score"])
		var second: float = float(requests[other]["score"])
		return first > second or (first == second and one < other))
	return order
