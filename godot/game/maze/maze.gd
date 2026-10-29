## A small Pac-Man maze: you are Pac-Man, four pellets to eat, and Blinky,
## who decides the way the arcade's ghosts decide.
##
## The game runs on a fixed clock, one cell a step for everyone, and waits
## for the first arrow. With V on (it starts on) each ghost shows what it is
## deciding before it does it: its target tile, each way it may take with
## the straight-line distance from the cell beyond to the target, and the
## way it chose, in white -- or in orange with a die, when the imprecise
## chase rule rolled. G brings in Pinky, who aims ahead of you. The rules
## are `MazeGame`'s; this node only runs the clock, reads the keys and
## draws.
##
## C hands Pac-Man to the MDP (T98): a policy value iteration computed in
## Python, looked up by `MdpPacMan`, in the regime it was solved for --
## Blinky alone, chasing for ever, no scheduled reversal. With V on, the
## value of every cell for Pac-Man is drawn as a heat map with the policy's
## arrow on it, and beside him what each of his four moves is worth. Your
## game keeps the arcade's schedule; C again gives it back to you.
class_name MazeDemo
extends Node2D

## How long a step lasts on screen, in seconds: four steps a second.
const STEP_SECONDS: float = 0.25
## The keys that walk, as directions.
const DIRECTIONS: Dictionary = {  # not shown: the rules' identifiers
	KEY_UP: "up", KEY_LEFT: "left", KEY_DOWN: "down", KEY_RIGHT: "right",
	KEY_W: "up", KEY_A: "left", KEY_S: "down", KEY_D: "right",
}
## The controller, as the keys (docs/godot/a-controller.md): the stick and
## the D-pad walk; Y the ghosts' view, B a second ghost, RB the MDP, A one step, X again,
## Menu pauses.
const PAD_BUTTONS: Dictionary = {JOY_BUTTON_DPAD_UP: KEY_UP, JOY_BUTTON_DPAD_DOWN: KEY_DOWN,
		JOY_BUTTON_DPAD_LEFT: KEY_LEFT, JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT,
		JOY_BUTTON_Y: KEY_V, JOY_BUTTON_B: KEY_G, JOY_BUTTON_A: KEY_SPACE, JOY_BUTTON_X: KEY_R,
		JOY_BUTTON_RIGHT_SHOULDER: KEY_C,
		JOY_BUTTON_START: KEY_P}
const STICK_KEYS: Array[Key] = [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]

## The game being played.
var game: MazeGame
## You, at the keys.
var person := MazePerson.new()
## The MDP's policy, looked up.
var mdp := MdpPacMan.new()
## Whether the MDP plays Pac-Man, in the regime it was solved for.
var mdp_playing: bool = false
## Whether each ghost's decision is drawn over the maze.
var view_on: bool = true
## Whether Pinky plays beside Blinky.
var two_ghosts: bool = false
## Whether the clock is stopped; space still plays one step.
var paused: bool = false
## Whether an arrow has been pressed since the game began.
var started: bool = false

var _seed: int = 1
# C was pressed and the MDP's tables were not there: said on the status line
# until the next key, and your game left as it was.
var _no_policy: bool = false
var _waited: float = 0.0
var _pad := PadAsKeys.new()

@onready var _status: Label = $Interface/Status
@onready var _panel: Label = $Interface/Decision
@onready var _legend: Legend = $Interface/Legend


func _ready() -> void:
	_pad.use(PAD_BUTTONS, STICK_KEYS)
	add_child(_pad)
	_show_legend()
	restart()
	Language.apply_if_opened_alone(self)


# The words are rebuilt in the language just chosen: a Label set from code
# keeps the text it was given.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_show_legend()
		_refresh()


func _show_legend() -> void:
	if mdp_playing:
		_show_mdp_legend()
		return
	_legend.set_entries([
		[MazeView.PACMAN, tr("Pac-Man: you")],
		[MazeView.GHOSTS["blinky"], tr("Blinky: in chase, aims at your cell")],
		[MazeView.GHOSTS["pinky"], tr("Pinky (G): aims four cells ahead of you")],
		[MazeView.PELLET, tr("pellet: eat all four to win")],
		[Color.TRANSPARENT, "  " + tr("square with a cross: a ghost's target tile")],
		[MazeView.WAY, tr("grey line: a way it may take, and the")],
		[Color.TRANSPARENT, "  " + tr("straight line from there to its target")],
		[MazeView.CHOSEN, tr("white line: the way it chose, before it moves")],
		[MazeView.DICE, tr("orange and a die: the dice chose the way")],
	] as Array[Array])
	_pad.add_to(_legend)


func _show_mdp_legend() -> void:
	_legend.set_entries([
		[MazeView.PACMAN, tr("Pac-Man: the MDP's policy, solved in Python")],
		[MazeView.GHOSTS["blinky"], tr("Blinky: chases for ever, as the MDP assumes")],
		[MazeView.PELLET, tr("pellet: eat all four to win")],
		[MazeView.VALUE_HIGH, tr("green cell: worth much to Pac-Man standing there")],
		[MazeView.VALUE_LOW, tr("red cell: worth little, or a catch to come")],
		[Color.TRANSPARENT, "  " + tr("arrow on a cell: the policy's move from there")],
		[MazeView.CHOSEN, tr("numbers beside Pac-Man: each move's worth")],
		[MazeView.WAY, tr("grey line: a way Blinky may take; white: chosen")],
		[MazeView.DICE, tr("orange and a die: the dice chose the way")],
	] as Array[Array])
	_pad.add_to(_legend)


func _process(delta: float) -> void:
	if paused or not started or not game.is_playing():
		return
	_waited += delta
	while _waited >= STEP_SECONDS and game.is_playing():
		_waited -= STEP_SECONDS
		play_step()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	_no_policy = false
	if DIRECTIONS.has(key.keycode):
		person.press(DIRECTIONS[key.keycode])
		started = true
	elif key.keycode == KEY_V:
		view_on = not view_on
	elif key.keycode == KEY_G and not mdp_playing:
		two_ghosts = not two_ghosts
		restart()
	elif key.keycode == KEY_C:
		hand_over(MdpPacMan.is_published())
	elif key.keycode == KEY_P:
		paused = not paused
	elif key.keycode == KEY_SPACE:
		paused = true
		play_step()
	elif key.keycode == KEY_R:
		_seed += 1
		restart()
	_refresh()


## C: Pac-Man to the MDP, or back to you -- unless the MDP's tables were
## never published (`published` false), when your game goes on untouched and
## the status line says why.
func hand_over(published: bool) -> void:
	if not mdp_playing and not published:
		_no_policy = true
		_refresh()
		return
	mdp_playing = not mdp_playing
	_show_legend()
	restart()


## A new game: the pellets back, everyone on their starting cell, waiting
## for an arrow -- or, with the MDP playing, under way at once, Blinky alone
## and chasing for ever. Each new game takes the next seed, so the dice differ.
func restart() -> void:
	var names: Array = ["blinky", "pinky"] if two_ghosts else MazeRules.rules()["ghosts"]
	if mdp_playing:
		game = MazeGame.new(_seed, MdpPacMan.spec()["ghosts"], MdpPacMan.spec()["schedule"])
	else:
		game = MazeGame.new(_seed, names)
	person = MazePerson.new()
	started = mdp_playing
	_waited = 0.0
	_refresh()


## One step of the game, with your move.
func play_step() -> void:
	started = true
	game.step(mdp.move_for(game) if mdp_playing else person.move_for(game))
	_refresh()


## One decision: a step with the move you would make, or a new game once
## this one is over -- the stand-in for a person that lets a test, or
## somebody watching, step through a game.
func step_decision() -> void:
	if not game.is_playing():
		_seed += 1
		restart()
	play_step()


## What every ghost is reasoning with, before it moves: its mode, its target
## and why, each way with the cell beyond and its distance to the target,
## the Dossier's way, the way chosen and how -- and the dice when rolled.
func decision_overlay() -> Dictionary:
	var ghosts: Array[Dictionary] = []
	for ghost: MazeGhost in game.ghosts:
		ghosts.append(_ghost_overlay(ghost))
	var overlay: Dictionary = {"step": game.steps, "mode": game.mode(), "pacman": game.pacman,
			"facing": game.facing, "pellets_left": game.pellets.size(), "outcome": game.outcome,
			"seed": game.seed_used, "precision": MazeRules.precision(), "ghosts": ghosts,
			"controller": "mdp" if mdp_playing else "person"}  # not shown: identifiers, worded by MazePanel
	if mdp_playing and game.is_playing():
		overlay["mdp"] = _mdp_overlay()
	return overlay


# What the MDP weighs: the state's value, and each move's from the lookahead.
func _mdp_overlay() -> Dictionary:
	var value: float = MdpPacMan.value_at(MdpPacMan.slot_of(game))
	var discount: float = float(MdpPacMan.spec()["discount"])
	return {"value": value, "moves": mdp.lookahead(game), "discount": discount}


func _ghost_overlay(ghost: MazeGhost) -> Dictionary:
	var ways: Array[Dictionary] = []
	for way: Dictionary in ghost.decision["ways"]:
		var shown: Dictionary = way.duplicate()
		shown["distance"] = sqrt(float(way["squared"]))
		ways.append(shown)
	var overlay: Dictionary = ghost.decision.duplicate()
	var personality: Dictionary = MazeRules.rules()["targets"][ghost.name]
	var facing_up: bool = game.facing == "up"  # not shown: a direction's identifier
	var bugged: bool = personality["up_also_left"] and ghost.decision["mode"] == MazeRules.CHASE and facing_up
	overlay.merge({"name": ghost.name, "cell": ghost.cell, "ways": ways, "precision": MazeRules.precision(),
			"up_bug": bugged}, true)
	return overlay


func _refresh() -> void:
	if not is_node_ready():
		return
	queue_redraw()
	var overlay: Dictionary = decision_overlay()
	_status.text = MazePanel.status(overlay, paused, started, view_on, two_ghosts, mdp_playing)
	if _no_policy:
		_status.text = tr("C: no MDP policy in data/maze -- run make solve-maze first") + "\n" + _status.text
	_panel.text = MazePanel.describe(overlay)


func _draw() -> void:
	MazeView.draw_maze(self, game.pellets)
	var thinking: bool = view_on and game.is_playing()
	if thinking and mdp_playing:
		MazeView.draw_values(self, MdpPacMan.value_map(game))
	if thinking:
		for ghost: MazeGhost in game.ghosts:
			MazeView.draw_view(self, ghost)
	MazeView.draw_pacman(self, game.pacman, game.facing)
	for ghost: MazeGhost in game.ghosts:
		MazeView.draw_ghost(self, ghost)
	if thinking and mdp_playing:
		MazeView.draw_lookahead(self, game.pacman, mdp.lookahead(game))
