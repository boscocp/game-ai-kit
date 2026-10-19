## One guard, one intruder, one room -- and a brain for the guard that can be
## swapped while it is mid-round.
##
## The room is T14's (`StealthRoom.default_room`), and the guard walks the
## round of its first guard. The intruder is not the person: it walks a fixed
## loop through the guard's half of the room, sprinting -- loud -- and stops
## for `PAUSE` turns at each corner of it, silent, so the guard loses it, goes
## to look, and sometimes walks up on it standing there. Caught, it
## starts its loop again. So the guard notices, loses, looks, chases and
## catches with nobody at the keys -- the demo is about the guard, and a
## person steering would make every run a different lesson. Without the
## pauses the guard followed one cell behind for ever, and every brain did
## the same thing every turn (wave 56's review).
##
## A turn: the intruder steps, then the guard's brain decides on a `BoardState`
## of the room (`DecisionPolicy.choose`), the move is played, the guard turns
## to face what its deed was about, and only then perceives -- moving first,
## as T14 does, so the cone on screen is the one it looked through.
##
## When not to use it: as the stealth game. Nobody here is trying to escape.
class_name BehaviourWorld
extends RefCounted

const GUARD_ID: int = 1
const INTRUDER_ID: int = 2
const GUARDS: int = 1
const INTRUDERS: int = 0
## Enough for two cells of anything the room has: a chase is cut to two
## cells by the brain, not by a budget.
const GUARD_MOVEMENT: int = 6
## The intruder's loop through the guard's half of the room.
const INTRUDER_LOOP: Array[Vector2i] = [Vector2i(1, 6), Vector2i(8, 2), Vector2i(6, 7), Vector2i(3, 10)]
## Cells the intruder covers a turn: it sprints between corners, as a player
## does to get across -- two cells, and the noise of a sprint, which is what
## alarms a guard in T14's suspicion ("loud" alone is "alarmed").
const INTRUDER_PACE: int = 2
## Turns the intruder stands still at each corner of its loop.
const PAUSE: int = 6

var room: StealthRoom = StealthRoom.default_room()
var cone := VisionCone.new(Suspicion.SIGHT, 50.0)
var guard: Unit
var facing: Vector2i = Vector2i.RIGHT
var intruder: Unit
var senses: GuardSenses
var brain: GuardBrain
var turn: int = 0
## True on the turn the guard seized the intruder.
var caught: bool = false
## How many times it has.
var catches: int = 0
## The last move the guard's brain chose, and the board it chose it on.
var last_move: Move
var last_board: BoardState

var _search := AStarSearch.new()
var _loop_index: int = 0
var _paused: int = 0


## A fresh room with the guard at the start of its round, thinking with
## `thinker`.
func _init(thinker: GuardBrain) -> void:
	var round: Array[Vector2i] = []
	round.assign(room.rounds[0])
	guard = Unit.new(GUARD_ID, GUARDS, round[0], 10, GUARD_MOVEMENT)
	intruder = Unit.new(INTRUDER_ID, INTRUDERS, INTRUDER_LOOP[0])
	senses = GuardSenses.new(round)
	use(thinker)


## Hand the guard to `thinker`, keeping everything the guard knows. The
## brain's own memory -- a state, a plan -- starts afresh: that is the brain's.
func use(thinker: GuardBrain) -> void:
	brain = thinker
	brain.senses = senses


## The board the guard decides on: the room, the guard and the intruder.
func board() -> BoardState:
	var state := BoardState.new(room.graph, [guard, intruder] as Array[Unit], GUARDS, turn)
	state.unit_by_id(GUARD_ID).movement_points = GUARD_MOVEMENT
	return state


## One turn: the intruder steps, the guard decides and moves, then looks.
## An intruder caught last turn starts its loop again first.
func step() -> void:
	if caught:
		_start_the_loop_again()
	var noise: float = StealthWorld.SPRINT_NOISE if _intruder_steps() else 0.0
	last_board = board()
	last_move = brain.choose(last_board, GUARD_ID)
	if not last_move.path.is_empty():
		facing = last_move.path[-1] - (last_move.path[-2] if last_move.path.size() > 1 else guard.cell)
		guard.cell = last_move.path[-1]
	else:
		_turn_for(brain.deed)
	caught = brain.deed == GuardBrain.CATCH and _beside(guard.cell, intruder.cell)
	catches += 1 if caught else 0
	senses.perceive(room, cone, guard.cell, facing, intruder.cell, noise)
	turn += 1


# The intruder's step along its loop -- or a turn of its pause at a corner;
# false when it did not move.
func _intruder_steps() -> bool:
	if intruder.cell == INTRUDER_LOOP[_loop_index]:
		if _paused < PAUSE:
			_paused += 1
			return false
		_paused = 0
		_loop_index = (_loop_index + 1) % INTRUDER_LOOP.size()
	var around: GridGraph = room.graph.duplicate_graph()
	around.block(guard.cell)
	var route: Array[Vector2i] = _search.find_path(around, intruder.cell, INTRUDER_LOOP[_loop_index])
	if route.is_empty():
		return false
	intruder.cell = route[mini(INTRUDER_PACE, route.size()) - 1]
	return true


# A deed done standing still turns the guard: towards what it heard, round a
# quarter while it looks, at the intruder it seizes.
func _turn_for(deed: String) -> void:
	match deed:
		GuardBrain.CATCH:
			_face(intruder.cell)
		GuardBrain.TURN_TOWARDS:
			_face(senses.last_known)
		GuardBrain.LOOK_AROUND:
			facing = Vector2i(-facing.y, facing.x)
			senses.looked(guard.cell)


# Turn the guard square-on towards `cell`, along the longer of the two ways
# to it; a cell it stands on, or nowhere, leaves it as it was.
func _face(cell: Vector2i) -> void:
	var towards: Vector2i = cell - guard.cell
	if cell == GuardSenses.NOWHERE or towards == Vector2i.ZERO:
		return
	facing = Vector2i(signi(towards.x), 0) if absi(towards.x) >= absi(towards.y) else Vector2i(0, signi(towards.y))


# Back to a corner of its loop the guard is not standing on -- the first,
# unless the guard is there, and then the next.
func _start_the_loop_again() -> void:
	caught = false
	_paused = 0
	_loop_index = 0 if guard.cell != INTRUDER_LOOP[0] else 1
	intruder.cell = INTRUDER_LOOP[_loop_index]


static func _beside(one: Vector2i, other: Vector2i) -> bool:
	var gap: Vector2i = (one - other).abs()
	return gap.x + gap.y == 1
