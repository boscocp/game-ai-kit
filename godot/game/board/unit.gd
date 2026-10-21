## One piece on the board: who owns it, where it stands, and what it has left.
##
## Deliberately dumb. A unit knows nothing about moving itself, because the
## moment it does, every addon that wants to reason about a move has to go
## through the unit's opinion of it. `BoardState` decides; a unit is a fact.
##
## What a unit *is* -- how far it moves, what it beats -- lives in its
## `UnitType`; what it *has left* lives here.
##
## When not to use it: anything with inventory, abilities or status effects.
## This is the minimum a turn-based board needs, kept small so the AI lessons
## are about deciding and not about bookkeeping.
class_name Unit
extends RefCounted

## Factions are small integers rather than a string or an enum in `ai_core`: a
## scenario may have three sides, and an enum here would be a list this addon
## has no business owning.
var faction: int

## Where the unit stands, in board coordinates -- *not* pixels. `position` is
## taken, in Godot, for a screen-space Vector2, and a lesson that confuses the
## two produces pathfinding that works until the camera moves.
var cell: Vector2i

var health: int

## How much movement this unit has left this turn, spent by entering cells.
var movement_points: int

## Set once, never reused. Identity has to survive a state being copied, and
## two units that are equal in every field are still two different units.
var id: int

## What kind of piece it is, or null for the untyped units every scenario
## before T10 was built with. Shared, never copied: a type is data that no
## move changes.
var type: UnitType


func _init(unit_id: int, unit_faction: int, start: Vector2i,
		unit_health: int = 10, points: int = 3, kind: UnitType = null) -> void:
	id = unit_id
	faction = unit_faction
	cell = start
	health = unit_health
	movement_points = points
	type = kind


## An independent copy, same identity.
##
## `BoardState` hands out new states rather than mutating, so every unit in it
## has to be copied too -- otherwise the "new" state shares units with the old
## one and a move quietly rewrites history.
func duplicate_unit() -> Unit:
	return Unit.new(id, faction, cell, health, movement_points, type)


## True when this unit still belongs on the board.
func is_alive() -> bool:
	return health > 0
