## What one side knows of the board: its own pieces, the enemies it sees
## now, and where it last saw the others. Fog, by side (T84).
##
## A controller in this mode is given its side's view and never the state:
## an AI that reads the whole board while the person reads a fogged one is
## cheating, and the AIMA agent the owner asks for decides on what it
## *perceives*. So the view is a `BoardState` of its own -- the same graph,
## the same turn, the side's pieces and only the enemies one of them sees
## (`SquadSight.sees`) -- and anything written for a `BoardState` can
## decide on it unchanged.
##
## One thing is taken out besides the unseen: the dice seed, which would
## tell a search what every shot will roll. The funds and the tallies are
## empty in this mode already, and are left empty.
##
## The memory is the one thing a view carries from one look to the next:
## `last_seen`, an unseen enemy's id and the cell it was last seen on. A
## view is built from the state and, optionally, the view before it; an
## enemy seen again leaves the memory, one destroyed in sight never enters it.
##
## When not to use it: hidden information beyond position. XCOM hides an
## enemy's health and kind until it is seen, too; here a seen enemy is seen
## whole, and an unseen one is a cell and an id.
class_name SideView
extends RefCounted

## The side this is the view of.
var side: int
## The board as the side sees it.
var state: BoardState
## Enemy id -> the cell it was last seen on, for the enemies not seen now.
var last_seen: Dictionary[int, Vector2i] = {}


func _init(seeing_side: int, seen: BoardState, remembered: Dictionary[int, Vector2i]) -> void:
	side = seeing_side
	state = seen
	last_seen = remembered


## `side`'s view of `full`, on the map written in `rows`, remembering what
## `earlier` -- the same side's last view, or null -- had seen.
static func seen_by(full: BoardState, rows: Array[String], seeing_side: int, earlier: SideView = null) -> SideView:
	var kept: Array[Unit] = []
	var remembered: Dictionary[int, Vector2i] = _remembered(earlier)
	for unit: Unit in full.units:
		if unit.faction == seeing_side or is_seen(full, rows, seeing_side, unit.cell):
			kept.append(unit)
			remembered.erase(unit.id)
	_forget_the_destroyed(remembered, full)
	var seen := BoardState.new(full.graph, kept, full.current_faction, full.turn_number)
	seen.movement_graphs = full.movement_graphs
	seen.next_id = full.next_id
	return SideView.new(seeing_side, seen, remembered)


## True when one of `seeing_side`'s pieces on `full` sees `cell`.
static func is_seen(full: BoardState, rows: Array[String], seeing_side: int, cell: Vector2i) -> bool:
	for watcher: Unit in full.units_of(seeing_side):
		if SquadSight.sees(rows, watcher, cell):
			return true
	return false


## The ids of the enemies seen now.
func seen_enemies() -> Array[int]:
	var found: Array[int] = []
	for unit: Unit in state.units:
		if unit.faction != side:
			found.append(unit.id)
	return found


# Where `earlier` last saw each enemy: the ones it remembered, and the ones
# it saw then, at the cells it saw them on. Nothing for no earlier view.
static func _remembered(earlier: SideView) -> Dictionary[int, Vector2i]:
	var remembered: Dictionary[int, Vector2i] = {}
	if earlier == null:
		return remembered
	remembered = earlier.last_seen.duplicate()
	for enemy_id: int in earlier.seen_enemies():
		remembered[enemy_id] = earlier.state.unit_by_id(enemy_id).cell
	return remembered


# An enemy remembered but no longer on the board was destroyed -- a fact
# the side learns, since in this mode a destroyed piece is announced.
static func _forget_the_destroyed(remembered: Dictionary[int, Vector2i], full: BoardState) -> void:
	for enemy_id: int in remembered.keys():
		if full.unit_by_id(enemy_id) == null:
			remembered.erase(enemy_id)
