## The bot match you watch (T51): two teams of six bots, no network, on a
## capture-and-hold arena. You switch each team's techniques on and off and
## see the difference -- the claims, the commander, the retreat -- and watch
## one bot at a time weigh its spots.
##
## Keys: 1, 2, 3 switch blue's claims, commander and retreat; with Shift,
## red's. Tab watches the next bot, M shows the other team's map, C follows
## the watched bot or frees the camera (arrows turn and zoom it), F runs at
## four times speed, P pauses, Space one decision while paused, N a new match.
##
## T takes the watched bot over, either team, and T again gives it back to
## its priority list (the owner's choice, 2026-10-21): the same body by the
## same rules, in third person -- WASD walks, the mouse turns, a click fires,
## R reloads, Ctrl crouches. Its teammates leave the spot it stands on to it,
## and its squad's commander counts it like any other bot.
extends Node3D

const SEEDS_FROM: int = 1
## Where the free camera turns about: the arena's middle.
const CENTRE: Vector3 = Vector3(24, 0, 16)
## Radians the view turns per pixel of mouse movement.
const MOUSE_TURN: float = 0.004

var world: BotMatch
var _seed: int = SEEDS_FROM
var _watched: int = 0
var _paused: bool = false
var _fast: bool = false
var _follow: bool = false
var _orbit_angle: float = 0.0
var _orbit_distance: float = 38.0
var _carried: float = 0.0
## The bot a person drives, or -1.
var _played: int = -1

@onready var _drawing: BotMatchDrawing = $Drawing
@onready var _map: BotMatchMap = $Interface/Map
@onready var _panel: Label = $Interface/Panel
@onready var _camera: Camera3D = $Camera


func _ready() -> void:
	($Interface/Legend as Legend).set_entries([
		[BotMatchDrawing.BLUE, "blue bot; its line runs to the spot it claimed"],
		[BotMatchDrawing.RED, "red bot"],
		[BotMatchDrawing.KEPT, "a spot the watched bot weighed: taller scored higher"],
		[BotMatchDrawing.CHOSEN, "the spot it chose"],
		[BotMatchDrawing.CLAIMED, "closed: a teammate claimed it"],
		[BotMatchDrawing.EXPOSED, "dropped: no cover and no line of fire"],
		[BotMatchDrawing.DROPPED, "dropped: too far, or outside its squad's area"],
		[BotMatchDrawing.SIGHT, "the watched bot's sight lines"],
	])
	_new_match()


func _physics_process(delta: float) -> void:
	_read_the_person()
	if not _paused and not world.over():
		_carried += delta * (4.0 if _fast else 1.0)
		while _carried >= world.rules.step:
			world.step()
			_carried -= world.rules.step
	_show()


## Advance one decision: every bot looks and decides once, and the world
## runs until the next decision.
func step_decision() -> void:
	var until: float = world.time + world.rules.decision_interval
	while world.time < until - 1e-6 and not world.over():
		world.step()
	_show()


## What the AI is reasoning with now: the watched bot's choice of spot, with
## every candidate's status and score, and every squad's confidence, state
## and order.
func decision_overlay() -> Dictionary:
	var bot: MatchBot = world.bots[_watched]
	var team: MatchTeam = world.teams[bot.team]
	var candidates: Array = []
	var chosen: String = "none yet"
	if team.last_choice.has(bot.id):
		var choice: TacticalPositions.Choice = team.last_choice[bot.id][0]
		var places: Array = team.last_choice[bot.id][1]
		for index: int in range(places.size()):
			var spot: String = world.place_id(places[index])
			candidates.append({"spot": spot, "status": choice.statuses[index], "score": choice.scores[index]})
		chosen = world.place_id(places[choice.chosen]) if choice.chosen != -1 else "none"
	var watched: Dictionary = {"bot": bot.id, "action": bot.action, "chosen": chosen, "candidates": candidates}
	return {"time": world.time, "watched": watched, "squads": _squads_overlay()}


func _squads_overlay() -> Array:
	var squads: Array = []
	for team: MatchTeam in world.teams:
		for index: int in range(team.squads.size()):
			squads.append(_squad_overlay(team, index))
	return squads


func _squad_overlay(team: MatchTeam, index: int) -> Dictionary:
	var point: String = world.arena.point_ids[team.bot_points.get(team.squads[index][0], 0)]
	var confidence: float = float(world.squad_confidence[team.side].get(index, 0.0))
	return {"team": team.name, "squad": index, "state": team.squad_states[index],
			"confidence": confidence, "point": point}


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and _played != -1:
		world.bots[_played].facing += motion.relative.x * MOUSE_TURN
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var team: MatchTeam = world.teams[BotMatch.RED if key.shift_pressed else BotMatch.BLUE]
	match key.keycode:
		KEY_1:
			team.use_claims = not team.use_claims
		KEY_2:
			team.use_commander = not team.use_commander
		KEY_3:
			team.may_retreat = not team.may_retreat
		_:
			_view_key(key.keycode)


func _view_key(keycode: Key) -> void:
	match keycode:
		KEY_TAB:
			_watch_next()
		KEY_M:
			_map.watched_team = 1 - _map.watched_team
		KEY_C:
			_follow = not _follow
		KEY_F:
			_fast = not _fast
		KEY_P:
			_paused = not _paused
		KEY_SPACE:
			step_decision()
		KEY_N:
			_seed += 1
			_new_match()
		KEY_T:
			_take_over_or_give_back()
		KEY_R:
			_reload_by_hand()
		KEY_LEFT, KEY_RIGHT:
			_orbit_angle += 0.15 if keycode == KEY_RIGHT else -0.15
		KEY_UP, KEY_DOWN:
			_orbit_distance = clampf(_orbit_distance + (-3.0 if keycode == KEY_UP else 3.0), 12.0, 70.0)


# The next bot, unless a person is driving one: then the view stays on it.
func _watch_next() -> void:
	if _played == -1:
		_watched = (_watched + 1) % world.bots.size()


func _take_over_or_give_back() -> void:
	if _played != -1:
		world.bots[_played].controlled = false
		_played = -1
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	_played = _watched
	world.bots[_played].controlled = true
	_follow = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _reload_by_hand() -> void:
	if _played == -1:
		return
	var bot: MatchBot = world.bots[_played]
	if bot.alive() and bot.ammo < world.rules.magazine and bot.reload_left <= 0.0:
		bot.reload_left = world.rules.reload_time


# What the person asks of their bot this frame: WASD relative to where it
# faces, the trigger, and crouching.
func _read_the_person() -> void:
	if _played == -1:
		return
	var bot: MatchBot = world.bots[_played]
	var forward := Vector2.RIGHT.rotated(bot.facing)
	var right := Vector2(-forward.y, forward.x)
	var push: Vector2 = Input.get_vector(&"ui_left", &"ui_right", &"ui_down", &"ui_up")
	push += Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S)))
	bot.wants_to_walk = (forward * push.y + right * push.x).limit_length(1.0)
	bot.wants_to_fire = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	bot.wants_to_crouch = Input.is_key_pressed(KEY_CTRL)


# A match from the current seed, keeping each team's switches.
func _new_match() -> void:
	var rules := MatchRules.new()
	var blue := MatchTeam.new("blue", BotMatch.BLUE, rules)
	var red := MatchTeam.new("red", BotMatch.RED, rules)
	if world != null:
		for side: int in [BotMatch.BLUE, BotMatch.RED]:
			var fresh: MatchTeam = blue if side == BotMatch.BLUE else red
			fresh.use_claims = world.teams[side].use_claims
			fresh.use_commander = world.teams[side].use_commander
			fresh.may_retreat = world.teams[side].may_retreat
	world = BotMatch.new(_seed, blue, red, rules)
	_played = -1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for child: Node in _drawing.get_children():
		child.free()
	_drawing.build(world)
	_map.world = world
	_show()


func _show() -> void:
	_drawing.refresh(world, _watched)
	_map.queue_redraw()
	_place_camera()
	_panel.text = _panel_text()


func _place_camera() -> void:
	var bot: MatchBot = world.bots[_watched]
	if _follow and bot.alive():
		var close: bool = _played == bot.id
		var behind := Vector2.RIGHT.rotated(bot.facing) * (-3.5 if close else -5.0)
		var ahead := Vector2.RIGHT.rotated(bot.facing) * (6.0 if close else 0.0)
		_camera.position = Vector3(bot.position.x + behind.x, 2.6 if close else 3.5, bot.position.y + behind.y)
		_camera.look_at(Vector3(bot.position.x + ahead.x, 1.3, bot.position.y + ahead.y))
		return
	var offset := Vector3(sin(_orbit_angle), 0.0, cos(_orbit_angle)) * _orbit_distance * 0.6
	_camera.position = CENTRE + offset + Vector3(0, _orbit_distance * 0.8, 0)
	_camera.look_at(CENTRE)


func _panel_text() -> String:
	var bot: MatchBot = world.bots[_watched]
	var over: String = "   (over)" if world.over() else ""
	var lines: Array[String] = ["%.0f s   blue %.0f - %.0f red%s" % [world.time, world.score[0], world.score[1], over]]
	for team: MatchTeam in world.teams:
		var switches: Array = [team.name, _on(team.use_claims), _on(team.use_commander), _on(team.may_retreat)]
		lines.append("%s: claims %s, commander %s, retreat %s" % switches)
	var target: String = " at bot %d" % bot.target if bot.target != -1 else ""
	var you: String = "  -- YOU: %d/%d ammo, %d health" % [bot.ammo, world.rules.magazine, bot.health] if _played == bot.id else ""
	lines.append("watching bot %d (%s): %s%s%s" % [bot.id, world.teams[bot.team].name, bot.action, target, you])
	lines.append("1/2/3 blue's switches, Shift red's; Tab bot, T take it over, M map, C camera, F fast, P pause, N new")
	if _played != -1:
		lines.append("playing: WASD walk, mouse turns, click fires, R reloads, Ctrl crouches, T gives it back")
	return "\n".join(lines)


static func _on(value: bool) -> String:
	return "on" if value else "OFF"
