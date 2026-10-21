## One unit attacking another: who, and whom. Nothing else.
##
## It sits beside `Move` and `ProductionOrder` and is as thin as they are. What
## an attack is allowed to do, and how the fight goes, are a scenario's rules
## -- dice, a counter table, cover -- and the board holds types, not rules, so
## the tactical board judges and plays it (`TacticalCombat`).
##
## When not to use it: an area attack, or anything that hits more than one
## target. Then the target is a cell or a list, and that is another type.
class_name Attack
extends RefCounted

## The unit attacking.
var attacker_id: int

## The unit attacked.
var target_id: int


func _init(attacking_id: int, attacked_id: int) -> void:
	attacker_id = attacking_id
	target_id = attacked_id
