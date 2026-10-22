## The bot match you watch (T51): two teams of six bots, no network, on a
## capture-and-hold arena. You switch each team's techniques on and off and
## see the difference -- the claims, the commander, the retreat -- and watch
## one bot at a time weigh its spots.
##
## Keys: 1, 2, 3 switch blue's claims, commander and retreat; with Shift,
## red's. Tab watches the next bot, M shows the other team's map, C follows
## the watched bot or frees the camera (arrows turn and zoom it), F runs at
## four times speed, P pauses, Space one decision while paused, N a new match,
## L the next arena -- the same agents on another map.
##
## T takes the watched bot over, either team, and T again gives it back to
## its priority list (the owner's choice, 2026-10-21): the same body by the
## same rules, in first person as in Counter-Strike or Unreal (the owner,
## after playing it in third) -- WASD walks, the mouse aims up, down and
## round, a click fires, R reloads, Ctrl crouches, Shift sprints (and
## while it does, the rifle does not fire). Every shot leaves a
## tracer; a hit on someone shows a marker, and being hit reddens the edge.
## A reload is heard from wherever it happens, and a person's own lowers the
## rifle and shows its progress. Its teammates leave the spot it stands on to it,
## and its squad's commander counts it like any other bot.
extends Node3D

const SEEDS_FROM: int = 1
## Radians the view turns per pixel of mouse movement.
const MOUSE_TURN: float = 0.0025
## How far up or down a person can look.
const LOOK_LIMIT: float = deg_to_rad(80.0)
## How many shots can sound at once.
const SPEAKERS: int = 8

var world: BotMatch
var _seed: int = SEEDS_FROM
## Which of `BotArena.ARENAS` the match is played on (L cycles them).
var _arena_index: int = 0
var _watched: int = 0
var _paused: bool = false
var _fast: bool = false
var _follow: bool = false
var _orbit_angle: float = 0.0
var _orbit_distance: float = 38.0
var _carried: float = 0.0
## The bot a person drives, or -1.
var _played: int = -1
## While playing, whether the AI's reasoning is drawn over the world (V).
var _thinking_shown: bool = false
## Players for the shots heard, reused in turn, and how many shots were heard.
var _speakers: Array[AudioStreamPlayer3D] = []
var _next_speaker: int = 0
var _heard: int = 0
## Who was reloading at the last frame, by bot id, to hear each reload start.
var _was_reloading: Dictionary = {}
var _reload_speakers: Array[AudioStreamPlayer3D] = []
## The rifle in the person's hands, on the camera while they play.
var _viewmodel := Viewmodel.new()

@onready var _drawing: BotMatchDrawing = $Drawing
@onready var _map: BotMatchMap = $Interface/Map
@onready var _panel: Label = $Interface/Panel
@onready var _camera: Camera3D = $Camera
@onready var _hud: BotMatchHud = $Interface/Hud
@onready var _legend: Legend = $Interface/Legend


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
	_viewmodel.visible = false
	_camera.add_child(_viewmodel)
	var sound: AudioStreamWAV = GunshotSound.make()
	for index: int in range(SPEAKERS):
		var speaker := AudioStreamPlayer3D.new()
		speaker.stream = sound
		speaker.unit_size = 6.0
		add_child(speaker)
		_speakers.append(speaker)
	var reload: AudioStreamWAV = ReloadSound.make(MatchRules.new().reload_time)
	for index: int in range(BotMatch.BOTS_A_SIDE * 2):
		var speaker := AudioStreamPlayer3D.new()
		speaker.stream = reload
		speaker.unit_size = 4.0
		add_child(speaker)
		_reload_speakers.append(speaker)
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
## every candidate's status and score, where its last shot was aimed and
## what each zone was worth, its health and where it would hide (T68), and
## every squad's confidence, state and order.
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
	if candidates.is_empty():
		# On an errand, or not yet asked: say which, rather than show nothing.
		var why: String = "on an errand: %s" % bot.errand if bot.errand != "" else "not chosen yet"
		candidates.append({"spot": "none", "status": why, "score": 0.0})
	var watched: Dictionary = {"bot": bot.id, "action": bot.action, "chosen": chosen, "candidates": candidates,
			"aim": BotMatchLines.aim_overlay(bot), "errand": bot.errand if bot.errand != "" else "none",
			"errands": bot.errand_weighing if not bot.errand_weighing.is_empty() else {"weighed": "not yet"},
			"passage": BotMatchLines.passage_overlay(bot), "actions": BotMatchLines.action_overlay(bot),
			"health": _health_overlay(bot)}
	return {"time": world.time, "watched": watched, "squads": _squads_overlay()}


# The watched bot's health (T68): how much, how long until it comes back,
# and where it would hide to let it.
func _health_overlay(bot: MatchBot) -> Dictionary:
	var hiding: String = world.place_id(bot.hide_spot) if bot.hide_spot != -1 else "nowhere asked"
	return {"health": bot.health, "comes back in": MatchHealth.delay_left(world.rules, bot, world.time),
			"would hide at": hiding}


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
		var bot: MatchBot = world.bots[_played]
		bot.facing += motion.relative.x * MOUSE_TURN
		bot.pitch = clampf(bot.pitch - motion.relative.y * MOUSE_TURN, -LOOK_LIMIT, LOOK_LIMIT)
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
		KEY_L:
			_arena_index = (_arena_index + 1) % BotArena.ARENAS.size()
			_new_match()
		KEY_N:
			_seed += 1
			_new_match()
		KEY_T:
			_take_over_or_give_back()
		KEY_V:
			_thinking_shown = not _thinking_shown
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
		var given_back: MatchBot = world.bots[_played]
		given_back.controlled = false
		given_back.pitch = 0.0
		# Its old path starts from where it stood before it was played;
		# walked from here, it could cross a box. It chooses afresh.
		given_back.path.clear()
		given_back.goal = given_back.position
		given_back.chose_at = -INF
		_played = -1
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_played = _watched
		world.bots[_played].controlled = true
		_follow = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_hud.played = _played
	_legend.visible = _played == -1
	_viewmodel.visible = _played != -1


func _reload_by_hand() -> void:
	if _played == -1:
		return
	var bot: MatchBot = world.bots[_played]
	if bot.alive() and bot.ammo < world.rules.magazine and bot.reserve > 0 and bot.reload_left <= 0.0:
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
	bot.wants_to_sprint = Input.is_key_pressed(KEY_SHIFT)


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
	world = BotMatch.new(_seed, blue, red, rules, BotArena.new(rules.body_radius, BotArena.ARENAS[_arena_index]))
	_heard = 0
	_played = -1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.world = world
	_hud.played = -1
	_legend.visible = true
	_viewmodel.visible = false
	for child: Node in _drawing.get_children():
		child.free()
	_drawing.build(world)
	_map.world = world
	_show()


# Every shot fired since the last frame, from where it was fired; the newest
# SPEAKERS of them, when more came at once.
func _hear_new_shots() -> void:
	var new_shots: int = mini(world.shots_fired - _heard, world.recent_shots.size())
	_heard = world.shots_fired
	for shot: Array in world.recent_shots.slice(world.recent_shots.size() - new_shots):
		var speaker: AudioStreamPlayer3D = _speakers[_next_speaker]
		_next_speaker = (_next_speaker + 1) % _speakers.size()
		speaker.position = shot[4]
		speaker.volume_db = 0.0 if int(shot[1]) == _played else -6.0
		speaker.play()
		if int(shot[1]) == _played:
			_viewmodel.fire()


# Each reload that began since the last frame, heard from where the bot is:
# one speaker a bot, so a reload is never cut off by another's.
func _hear_reloads() -> void:
	for bot: MatchBot in world.bots:
		var reloading: bool = bot.alive() and bot.reload_left > 0.0
		if reloading and not _was_reloading.get(bot.id, false):
			var speaker: AudioStreamPlayer3D = _reload_speakers[bot.id]
			speaker.position = MatchActions.eyes_of(world, bot)
			speaker.volume_db = 0.0 if bot.id == _played else -4.0
			speaker.play()
		_was_reloading[bot.id] = reloading
	if _played != -1:
		var mine: MatchBot = world.bots[_played]
		_viewmodel.lowered = mine.reload_left > 0.0 or mine.sprinting


func _show() -> void:
	_hear_new_shots()
	_hear_reloads()
	_drawing.refresh(world, _watched, _played, _played == -1 or _thinking_shown)
	_map.queue_redraw()
	_hud.queue_redraw()
	_place_camera()
	_panel.text = _panel_text()


func _place_camera() -> void:
	var bot: MatchBot = world.bots[_watched]
	if _played == bot.id:
		# First person: the eyes the shot comes from, looking where it goes.
		var eyes: Vector3 = MatchActions.eyes_of(world, bot)
		_camera.position = eyes
		_camera.look_at(eyes + MatchActions.look_of(bot), Vector3.UP)
		return
	if _follow and bot.alive():
		var behind := Vector2.RIGHT.rotated(bot.facing) * -5.0
		_camera.position = world.arena.above(bot.position, 3.5) + Vector3(behind.x, 0.0, behind.y)
		_camera.look_at(world.arena.above(bot.position, 1.2))
		return
	var offset := Vector3(sin(_orbit_angle), 0.0, cos(_orbit_angle)) * _orbit_distance * 0.6
	# The free camera turns about the arena's middle, whichever arena it is.
	var centre := Vector3(world.arena.width / 2.0, 0.0, world.arena.depth / 2.0)
	_camera.position = centre + offset + Vector3(0, _orbit_distance * 0.8, 0)
	_camera.look_at(centre)


func _panel_text() -> String:
	var bot: MatchBot = world.bots[_watched]
	if _played != -1:
		var shown: Array = [world.time, world.score[0], world.score[1], "hide" if _thinking_shown else "show"]
		return "%.0f s   blue %.0f - %.0f red     T give it back, V %s the AI's thinking" % shown
	var over: String = "   (over)" if world.over() else ""
	var lines: Array[String] = ["%.0f s   blue %.0f - %.0f red%s" % [world.time, world.score[0], world.score[1], over]]
	for team: MatchTeam in world.teams:
		var switches: Array = [team.name, _on(team.use_claims), _on(team.use_commander), _on(team.may_retreat)]
		lines.append("%s: claims %s, commander %s, retreat %s" % switches)
	var target: String = " at bot %d" % bot.target if bot.target != -1 else ""
	var health: String = BotMatchHud.health_text(world.rules, bot, world.time)
	var you: String = "  -- YOU: %d/%d ammo, %s" % [bot.ammo, world.rules.magazine, health] if _played == bot.id else ""
	lines.append("watching bot %d (%s): %s%s%s" % [bot.id, world.teams[bot.team].name, bot.action, target, you])
	lines.append(BotMatchLines.action_line(bot))
	lines.append(BotMatchLines.aim_line(bot))
	lines.append(BotMatchLines.errand_line(bot))
	lines.append(BotMatchLines.passage_line(bot))
	lines.append("1/2/3 blue's switches, Shift red's; Tab bot, T take it over, M map, C camera, F fast, P pause, N new, L arena")
	if _played != -1:
		lines.append("playing: WASD walk, Shift sprint, mouse turns, click fires, R reloads, Ctrl crouches, T gives it back")
	return "\n".join(lines)


static func _on(value: bool) -> String:
	return "on" if value else "OFF"
