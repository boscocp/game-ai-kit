## One order, as a person or an AI gives it: the only way anything changes the
## world.
##
## Five kinds, the ones every RTS since Dune II has: move, attack, gather,
## build, train. A person's click and an AI's decision both become one of
## these and pass through `RtsWorld.why_refused`, so the never-cheat rule is
## one function, and actions per minute are counted the same way for both.
## A command is plain data -- ids and a cell, never a unit -- so it can be
## written to a recording and read back, and so an AI holding one holds
## nothing of the world.
##
## When not to use it: orders that need a shape (a formation, a patrol
## route). Those are more fields, or a second kind of command.
class_name RtsCommand
extends RefCounted

const MOVE: String = "move"
const ATTACK: String = "attack"
const GATHER: String = "gather"
const BUILD: String = "build"
const TRAIN: String = "train"
const KINDS: Array[String] = [MOVE, ATTACK, GATHER, BUILD, TRAIN]

## Which of the five.
var kind: String
## The units given the order: one producer for TRAIN, one worker for BUILD.
var unit_ids: Array[int] = []
## Where to go, or where to build.
var cell: Vector2i = Vector2i.ZERO
## Whom to attack, or which mine to gather from.
var target_id: int = 0
## What to build, or what to train.
var what: String = ""


## A command of `order_kind` for `ids`. The rest is filled in by the helpers
## below, one per kind, which say what each needs.
func _init(order_kind: String = MOVE, ids: Array[int] = []) -> void:
	kind = order_kind
	unit_ids = ids.duplicate()


## Walk `ids` to `destination`.
static func move(ids: Array[int], destination: Vector2i) -> RtsCommand:
	var command := RtsCommand.new(MOVE, ids)
	command.cell = destination
	return command


## Send `ids` after the unit `target`, to fight it until it falls.
static func attack(ids: Array[int], target: int) -> RtsCommand:
	var command := RtsCommand.new(ATTACK, ids)
	command.target_id = target
	return command


## Set workers `ids` carrying from `mine` to the nearest base, over and over.
static func gather(ids: Array[int], mine: int) -> RtsCommand:
	var command := RtsCommand.new(GATHER, ids)
	command.target_id = mine
	return command


## Have `worker` raise a `building` at `where`, paid for now.
static func build(worker: int, building: String, where: Vector2i) -> RtsCommand:
	var command := RtsCommand.new(BUILD, [worker] as Array[int])
	command.what = building
	command.cell = where
	return command


## Queue one `unit_kind` at the building `producer`, paid for now.
static func train(producer: int, unit_kind: String) -> RtsCommand:
	var command := RtsCommand.new(TRAIN, [producer] as Array[int])
	command.what = unit_kind
	return command


## The command as plain values, for a recording.
func to_dict() -> Dictionary:
	return {"kind": kind, "units": unit_ids.duplicate(), "cell": [cell.x, cell.y],
		"target": target_id, "what": what}


## A command read back from `to_dict`'s form; null when it is not one, so a
## damaged recording is refused rather than half-replayed.
static func from_dict(values: Dictionary) -> RtsCommand:
	if not values.get("kind", "") in KINDS or not (values.get("units") is Array) \
			or not (values.get("cell") is Array) or (values.get("cell") as Array).size() != 2:
		return null
	var ids: Array[int] = []
	for id: Variant in values["units"]:
		ids.append(int(id))
	var command := RtsCommand.new(values["kind"], ids)
	command.cell = Vector2i(int(values["cell"][0]), int(values["cell"][1]))
	command.target_id = int(values.get("target", 0))
	command.what = str(values.get("what", ""))
	return command
