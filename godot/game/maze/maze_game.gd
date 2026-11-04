## One game in the maze, a step at a time: the rules, without a screen.
##
## A step is the six moments `rules.json`'s "about" lists, in that order:
## Pac-Man moves (into a wall he stays), is caught if he walked onto a
## ghost, eats a pellet and wins with the last; every ghost takes the move
## it chose last step and catches him on his cell; then every ghost chooses
## its next move. Choosing at the end of a step puts the choice on the
## screen before it is taken -- and it is the Dossier's order too, where a
## ghost decides a tile before it turns.
##
## The game is a pure function of its seed and Pac-Man's moves:
## `gameaikit.maze.game` is the same game in Python, and the vectors in
## `spec/vectors/maze/` hold the two to the same position after every step.
## T98's value iteration runs on the Python one, so this one must not drift.
##
## When not to use it: a real-time maze game. One cell a step for everyone
## is a board game's clock; the arcade's runs a sixtieth of a second.
class_name MazeGame
extends RefCounted

const PLAYING: String = "playing"  # not shown: an identifier, worded by MazePanel
const WON: String = "won"  # not shown: an identifier, worded by MazePanel
const CAUGHT: String = "caught"  # not shown: an identifier, worded by MazePanel

## The seed the dice started from: the same seed and moves, the same game.
var seed_used: int = 1
## Pac-Man's cell, and the direction of his last move that moved him.
var pacman: Vector2i = Vector2i.ZERO
var facing: String = "left"  # not shown: an identifier, worded by MazePanel
## The pellets not eaten yet.
var pellets: Array[Vector2i] = []
## The ghosts, in the order they decide and draw.
var ghosts: Array[MazeGhost] = []
## Steps played.
var steps: int = 0
## PLAYING, WON or CAUGHT.
var outcome: String = PLAYING
## The ghosts' modes over time: empty for the arcade's in `rules.json`, or
## another -- T98's MDP plays chase for ever, `mdp.json`'s.
var schedule: Array = []

var _dice: Xorshift


## A game from `from_seed` with `ghost_names` playing, every ghost's first
## move already chosen. null: the ones `rules.json` plays by default; an
## empty list: no ghost at all. `modes` is the schedule, empty for the
## arcade's.
func _init(from_seed: int = 1, ghost_names: Variant = null, modes: Array = []) -> void:
	seed_used = from_seed
	schedule = modes
	_dice = Xorshift.new(from_seed)
	var start: Dictionary = MazeRules.maze()["pacman"]
	pacman = MazeRules.cell_of(start["cell"])
	facing = start["facing"]
	for pair: Array in MazeRules.maze()["pellets"]:
		pellets.append(MazeRules.cell_of(pair))
	var names: Array = MazeRules.rules()["ghosts"] if ghost_names == null else ghost_names
	for ghost_name: String in names:
		ghosts.append(MazeGhost.new(ghost_name))
	for ghost: MazeGhost in ghosts:
		ghost.decide(mode(), pacman, facing, false, _dice)


## The ghosts' mode for the step about to be played.
func mode() -> String:
	return MazeRules.mode_at(steps, schedule)


## Whether the game is still on.
func is_playing() -> bool:
	return outcome == PLAYING


## Play one step with Pac-Man's `move`. A finished game stays as it is.
func step(move: String) -> void:
	if not is_playing():
		return
	if MazeRules.is_open(MazeRules.moved(pacman, move)):
		pacman = MazeRules.moved(pacman, move)
		facing = move
	if _ghost_on_pacman():
		outcome = CAUGHT
		return
	if pacman in pellets:
		pellets.erase(pacman)
		if pellets.is_empty():
			outcome = WON
			return
	# Every ghost moves, even after one has caught him. Passing through him
	# is not a case: he moved first, and walking onto a ghost was a catch.
	for ghost: MazeGhost in ghosts:
		ghost.move()
	if _ghost_on_pacman():
		outcome = CAUGHT
		return
	var reversing: bool = MazeRules.mode_at(steps + 1, schedule) != MazeRules.mode_at(steps, schedule)
	steps += 1
	for ghost: MazeGhost in ghosts:
		ghost.decide(mode(), pacman, facing, reversing, _dice)


## Where everything is, as a vector records it after each step.
func snapshot() -> Dictionary:
	var seen: Array = []
	for ghost: MazeGhost in ghosts:
		var goal: Vector2i = ghost.decision["target"]
		seen.append([ghost.cell.x, ghost.cell.y, ghost.next_move, ghost.decision["kind"], goal.x, goal.y])
	return {"pacman": [pacman.x, pacman.y], "facing": facing, "ghosts": seen,
			"pellets": pellets.size(), "mode": mode(), "outcome": outcome}


func _ghost_on_pacman() -> bool:
	for ghost: MazeGhost in ghosts:
		if ghost.cell == pacman:
			return true
	return false
