## The bot match reading the person and answering (T100): every interval of
## match time, the player model's share is read through the table in
## `rules.json`, and the team the person is not on aims with that row's
## error. Never the person's own aim, never what a bot knows: one number
## that already exists, `MatchTeam.aim_error`, bounded by the table's first
## row (the easy level) and its last (the hard one).
##
## It is what ADR 0016's amendment lets count during play, on its three
## conditions: the model keeps counts only; a new match makes a new one,
## so it starts empty and reads the middle row; and its readings can be
## rebuilt from the person's events (`BotMatch.person_events`), which
## `PlayerModel.replay` does and a test does twice. It writes nothing and
## loads nothing (N14); the events are kept on disk only by
## `MatchEventLog`, and only when the match is opened with `-- --record`.
##
## When not to use it: to teach a bot to play better. It changes how well
## the other team is allowed to aim, not what anyone decides.
class_name MatchDifficulty
extends RefCounted

var model := PlayerModel.new()
## Whether a reading sets the knob. Off, the model still reads -- what it
## would have done -- and nobody's aim changes: the measurement's "off".
var answers: bool = true
## The table, as `rules.json` writes it, and its interval in whole steps.
var table: Dictionary
var interval_steps: int = 1
## The row read last, and every reading so far, oldest first -- each as
## `PlayerModel.reading` writes it, with "changed" when its row differs
## from the one before.
var row: int = 0
var readings: Array[Dictionary] = []
## Each team's own aim error, as the match began: what a team aims with
## when the person is not playing against it.
var _own_aim: PackedFloat64Array = PackedFloat64Array()
## How many of the person's events the model has counted.
var _counted: int = 0


func _init(world: BotMatch) -> void:
	table = world.rules.difficulty
	interval_steps = roundi(float(table["interval"]) / world.rules.step)
	row = PlayerModel.row_for(table["rows"], model.damage_share(float(table["prior_points"])))
	for team: MatchTeam in world.teams:
		_own_aim.append(team.aim_error)


## Called by the match at the start of every step: on a whole number of
## intervals, the model counts the events since its last reading, and the
## knob is set from the row it reads.
func before_step(world: BotMatch) -> void:
	if world.steps_done == 0 or world.steps_done % interval_steps != 0:
		return
	while _counted < world.person_events.size():
		model.count(world.person_events[_counted])
		_counted += 1
	var now: Dictionary = model.reading(table, world.steps_done)
	now["changed"] = int(now["row"]) != row
	row = now["row"]
	readings.append(now)
	if answers:
		_apply(world)


## The person changed (`BotMatch.seat_person`): the row read last is
## applied to whoever the person now plays against, and nobody's aim is
## changed when nobody plays. Nothing is read or counted.
func seat(world: BotMatch) -> void:
	if answers:
		_apply(world)


# Every team back to its own aim, then the one the person plays against at
# the row's. Nobody playing, nobody's aim is changed.
func _apply(world: BotMatch) -> void:
	for side: int in range(world.teams.size()):
		world.teams[side].aim_error = _own_aim[side]
	if world.person == -1:
		return
	var against: int = 1 - world.bots[world.person].team
	world.teams[against].aim_error = deg_to_rad(float(table["rows"][row]["aim_error_degrees"]))


## The rows read so far, one an interval: the knob's history, which a replay
## of the person's events must give again.
func rows_read() -> Array[int]:
	var rows: Array[int] = []
	for reading: Dictionary in readings:
		rows.append(int(reading["row"]))
	return rows


## What the game believes about the person and what it did about it, for
## the panel and the decision overlay: the counts, the share with its prior,
## the hit rate, the row and its aim error, when it last changed, and
## whether the latest reading changed it.
func overlay() -> Dictionary:
	var last_change: int = -1
	for reading: Dictionary in readings:
		if reading["changed"]:
			last_change = int(reading["step"])
	var now: Dictionary = model.reading(table, -1)
	return {"counts": now["counts"], "share": now["share"], "prior_points": int(table["prior_points"]),
			"hit_rate": now["hit_rate"], "row": row, "rows": table["rows"].size(),
			"row_name": str(table["rows"][row]["name"]), "row_from": float(table["rows"][row]["from"]),
			"aim_error_degrees": float(table["rows"][row]["aim_error_degrees"]), "changed_at_step": last_change,
			"changed_now": not readings.is_empty() and readings[-1]["changed"], "readings": readings.size()}
