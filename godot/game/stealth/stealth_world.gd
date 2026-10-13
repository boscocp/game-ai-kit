## The stealth scenario's rules: the player moves, then every guard takes a turn.
##
## Turn-based like the rest of the kit (ADR 0006): one key press is one turn,
## so a person can stop and read what every guard is thinking before the next.
## The player is a `Unit` on the room's `GridGraph`, and so is every guard.
## Reaching the exit wins, even halfway through a sprint; an alert guard next
## to the player, facing them with nothing between, ends it the other way.
class_name StealthWorld
extends RefCounted

const PLAYER: int = 0
const GUARDS: int = 1

## How far each action carries, in cells. Waiting is silent.
const WALK_NOISE: float = 3.0
const SPRINT_NOISE: float = 7.0

const PLAYING: String = ""
const ESCAPED: String = "escaped"
const CAUGHT: String = "caught"

var room: StealthRoom
var cone := VisionCone.new(Suspicion.SIGHT, 50.0)
var player: Unit
var guards: Array[StealthGuard] = []
var turn: int = 0
var outcome: String = PLAYING

## How far the player's last action carried; the guards hear it this turn.
var last_noise: float = 0.0


func _init(stealth_room: StealthRoom) -> void:
	room = stealth_room
	player = Unit.new(0, PLAYER, room.player_start)
	for index: int in range(room.rounds.size()):
		var start: Vector2i = room.rounds[index][0]
		guards.append(StealthGuard.new(Unit.new(index + 1, GUARDS, start), room.rounds[index]))


## Move the player one cell (two when sprinting) and let the guards answer.
##
## `direction` zero is waiting. A step into a wall, off the board, or onto a
## guard stops where it is; the turn still passes, because standing still is
## an answer too. Returns false when the game is already over.
func play(direction: Vector2i, sprint: bool = false) -> bool:
	if outcome != PLAYING:
		return false
	var steps: int = 0
	for _attempt: int in range(2 if sprint else 1):
		steps += 1 if _step(direction) else 0
	last_noise = 0.0 if steps == 0 else (SPRINT_NOISE if sprint else WALK_NOISE)
	_guards_answer()
	turn += 1
	return true


## How dangerous each cell is right now: where the guards see, and where
## their routes take them in the next few turns.
func danger() -> InfluenceMap:
	var eyes: Array[Vector2i] = []
	var facings: Array[Vector2i] = []
	for guard: StealthGuard in guards:
		eyes.append(guard.unit.cell)
		facings.append(guard.facing)
	var map := InfluenceMap.of_watchers(room.graph, cone, eyes, facings)
	for guard: StealthGuard in guards:
		map.raise_along(guard.upcoming(4), 0.6)
	return map


func _guards_answer() -> void:
	if player.cell == room.exit:
		outcome = ESCAPED
		return
	for guard: StealthGuard in guards:
		guard.take_turn(room, cone, player, last_noise, _occupied_except(guard))
		if _catches(guard):
			outcome = CAUGHT
			return


func _catches(guard: StealthGuard) -> bool:
	var gap: Vector2i = (guard.unit.cell - player.cell).abs()
	return guard.state == StealthGuard.ALERT and gap.x + gap.y == 1 \
			and cone.sees(room.graph, guard.unit.cell, guard.facing, player.cell)


# One cell of the player's move, or none: a sprint stops on the exit rather
# than running over it.
func _step(direction: Vector2i) -> bool:
	if player.cell == room.exit or direction == Vector2i.ZERO or not _can_enter(player.cell + direction):
		return false
	player.cell += direction
	return true


func _can_enter(cell: Vector2i) -> bool:
	if not room.graph.contains(cell) or room.graph.is_blocked(cell):
		return false
	for guard: StealthGuard in guards:
		if guard.unit.cell == cell:
			return false
	return true


func _occupied_except(moving: StealthGuard) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [player.cell]
	for guard: StealthGuard in guards:
		if guard != moving:
			cells.append(guard.unit.cell)
	return cells
