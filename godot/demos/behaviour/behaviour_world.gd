## One guard, one intruder, one room -- and a brain for the guard that can be
## swapped while it is mid-round.
##
## The room is T14's (`StealthRoom.default_room`), and the guard walks the
## round of its first guard. The intruder is not the person: it walks a fixed
## loop through the guard's half of the room, making the noise of a walk, so
## the guard has something to notice, lose and look for with nobody at the
## keys -- the demo is about the guard, and a person steering would make
## every run a different lesson.
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
const INTRUDER_LOOP: Array[Vector2i] = [Vector2i(1, 6), Vector2i(6, 7), Vector2i(3, 10), Vector2i(1, 3)]

var room: StealthRoom = StealthRoom.default_room()
var cone := VisionCone.new(Suspicion.SIGHT, 50.0)
var guard: Unit
var facing: Vector2i = Vector2i.RIGHT
var intruder: Unit
var senses: GuardSenses
var brain: GuardBrain
var turn: int = 0
## True once the guard has seized the intruder.
var caught: bool = false
## The last move the guard's brain chose, and the board it chose it on.
var last_move: Move
var last_board: BoardState

var _search := AStarSearch.new()
var _loop_index: int = 0


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
func step() -> void:
	if caught:
		return
	var noise: float = StealthWorld.WALK_NOISE if _intruder_steps() else 0.0
	last_board = board()
	last_move = brain.choose(last_board, GUARD_ID)
	if not last_move.path.is_empty():
		facing = last_move.path[-1] - (last_move.path[-2] if last_move.path.size() > 1 else guard.cell)
		guard.cell = last_move.path[-1]
	else:
		_turn_for(brain.deed)
	caught = brain.deed == GuardBrain.CATCH and _beside(guard.cell, intruder.cell)
	senses.perceive(room, cone, guard.cell, facing, intruder.cell, noise)
	turn += 1


# The intruder's step along its loop; false when it could not move.
func _intruder_steps() -> bool:
	if intruder.cell == INTRUDER_LOOP[_loop_index]:
		_loop_index = (_loop_index + 1) % INTRUDER_LOOP.size()
	var around: GridGraph = room.graph.duplicate_graph()
	around.block(guard.cell)
	var route: Array[Vector2i] = _search.find_path(around, intruder.cell, INTRUDER_LOOP[_loop_index])
	if route.is_empty():
		return false
	intruder.cell = route[0]
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


static func _beside(one: Vector2i, other: Vector2i) -> bool:
	var gap: Vector2i = (one - other).abs()
	return gap.x + gap.y == 1
