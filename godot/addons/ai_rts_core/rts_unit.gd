## One unit or building in a real-time match, changed in place every tick.
##
## A turn-based board's unit is a fact a new board copies; this one is a
## thing the world moves. It stands at a `position` in cells, as a fraction
## -- (3.5, 2.5) is the middle of cell (3, 2) -- because a unit half way
## between two cells is where an RTS unit spends most of its life. It carries its current
## order and how far through it is; the world reads both every tick.
##
## Only `RtsWorld` writes to one. An AI never holds one at all: it is handed
## an `RtsSnapshot`, which copies what it may see into plain values.
##
## When not to use it: a turn-based board, where an immutable unit and a
## fresh state per move are simpler and every search depends on them.
class_name RtsUnit
extends RefCounted

## What a unit with no order does: nothing, or -- a fighter -- whatever enemy
## comes into sight.
const IDLE: String = "idle"

var id: int
## Which side owns it; `RtsWorld.NEUTRAL` for a deposit.
var side: int
## A name in `RtsKinds.TABLE`: what it is, how fast, how strong.
var kind: String
var position: Vector2
var health: int
## The order it is carrying out: `IDLE` or one of `RtsCommand.KINDS`.
var order: String = IDLE
## The cell a move order goes to, or a build order builds on.
var goal: Vector2i = Vector2i.ZERO
## The unit an attack or gather order is aimed at.
var target_id: int = 0
## What a worker holds on its way back to a base, and which resource it is.
var carrying: int = 0
var carried: String = ""
## Ticks spent on the current piece of work: gathering, raising a building,
## training the first unit in the queue.
var progress: int = 0
## Ticks until it may strike again.
var cooldown: int = 0
## False for a building still being raised, which can neither train nor fight.
var complete: bool = true
## What a building has been told to train, first first.
var queue: Array[String] = []


func _init(unit_id: int, unit_side: int, unit_kind: String, at: Vector2, unit_health: int) -> void:
	id = unit_id
	side = unit_side
	kind = unit_kind
	position = at
	health = unit_health


## The cell it stands in.
func cell() -> Vector2i:
	return Vector2i(floori(position.x), floori(position.y))


## Everything that changes, as plain values in a fixed order: what a digest of
## the world is taken over, and what a snapshot copies.
func state() -> Array:
	return [id, side, kind, position.x, position.y, health, order, goal.x, goal.y, target_id,
		carrying, carried, progress, cooldown, complete, queue.duplicate()]
