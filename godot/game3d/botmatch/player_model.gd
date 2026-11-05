## How well the person plays, read from counts during one match (T100, T123).
##
## Hamlet, a dynamic difficulty system on Valve's Half-Life engine, models
## the damage a player takes as a distribution [Hunicke & Chapman]; Ocio
## Barriales balances difficulty through the enemies' accuracy [GAP3 ch. 33].
## This is the smallest honest version of both: it counts what the person's
## bot did -- shots, hits, kills, deaths, damage dealt and taken -- and the
## damage its whole team dealt and took, and reads the team's share as a
## Beta mean with a fixed prior,
##
##     share = (team_dealt + prior) / (team_dealt + team_taken + 2 * prior)
##
## which the table in `rules.json` turns into the other team's aim error
## (`MatchDifficulty`). The team's, not the bot's: the knob is six bots'
## aim, and one bot's share swung the whole match past even (T123). A share
## inside the table's band moves nothing -- the row read last stays -- so a
## match that has come even is left where it came even. The hit rate,
## (hits + 1) / (shots + 2), is shown beside it and sets nothing.
##
## A seat on the other team empties the counts: what the person did for
## blue says nothing of how red, with them in it, is doing.
##
## Each event is one addition and each reading one division. A mean is
## never kept: it is computed from the counts when it is read. There is no
## rating and no step towards a result -- an Elo or a TrueSkill update is
## one, and ADR 0016's amendment refuses it at game time (N14).
##
## When not to use it: to know a player across matches. It starts empty
## with every match and is never written down, so it is a reading of this
## person now, not a profile. `gameaikit.botmatch.player_model` is its
## Python twin, and `spec/vectors/player_model/` holds the two to one answer.
class_name PlayerModel
extends RefCounted

## The kinds of event it counts, as `BotMatch.note` writes them.
const SHOT: String = "shot"
const HIT: String = "hit"
const HURT: String = "hurt"
const KILL: String = "kill"
const DEATH: String = "death"
## A hit landed by, and a hurt taken by, another bot of the person's team.
const MATE_HIT: String = "mate_hit"
const MATE_HURT: String = "mate_hurt"
## The person took a bot, on the event's "team".
const SEAT: String = "seat"

var shots: int = 0
var hits: int = 0
var kills: int = 0
var deaths: int = 0
## The damage of the person's hits on enemies, and of enemies' hits on the
## person's bot, as the rules deal it: a killing hit counts its whole
## damage, even past the health that was left -- at most one hit's
## overshoot a kill.
var dealt: int = 0
var taken: int = 0
## The same damage for the whole team, the person's bot's included: what
## the share is read from.
var team_dealt: int = 0
var team_taken: int = 0
## The team the counts are of, -1 before the first seat; and how many times
## a seat on the other team emptied them.
var team: int = -1
var restarts: int = 0


## Add one event: of the person's bot, a shot fired, a hit landed (its
## points dealt), a hurt (its points taken), a kill or a death; of a
## team-mate, a hit or a hurt; or a seat. An event of another kind is
## refused, loudly: a log the model does not read is a log it cannot be
## rebuilt from.
func count(event: Dictionary) -> void:
	var points: int = int(event.get("points", 0))
	match str(event["kind"]):
		SHOT:
			shots += 1
		HIT:
			hits += 1
			dealt += points
			team_dealt += points
		HURT:
			taken += points
			team_taken += points
		MATE_HIT:
			team_dealt += points
		MATE_HURT:
			team_taken += points
		KILL:
			kills += 1
		DEATH:
			deaths += 1
		SEAT:
			_seat(int(event["team"]))
		_:
			push_error("PlayerModel: not an event it counts: %s" % event)  # not shown


# A seat on `seated`: on another team than the counts are of, they start
# empty. The same team, or the first seat, keeps them.
func _seat(seated: int) -> void:
	if team != -1 and seated != team:
		shots = 0
		hits = 0
		kills = 0
		deaths = 0
		dealt = 0
		taken = 0
		team_dealt = 0
		team_taken = 0
		restarts += 1
	team = seated


## Count `event`, and say whether it emptied the counts -- a seat on the
## other team, after which the knob starts again from the middle row.
func counted_from_empty(event: Dictionary) -> bool:
	var before: int = restarts
	count(event)
	return restarts != before


## Every count by name, as the vectors write them.
func counts() -> Dictionary:
	return {"shots": shots, "hits": hits, "kills": kills, "deaths": deaths, "dealt": dealt, "taken": taken,
			"team_dealt": team_dealt, "team_taken": team_taken, "restarts": restarts}


## The share of the damage the person's team dealt, as if `prior_points`
## had been dealt and as many taken before the match: what the knob is read
## from. An empty model reads 0.5.
func damage_share(prior_points: float) -> float:
	return (float(team_dealt) + prior_points) / (float(team_dealt + team_taken) + 2.0 * prior_points)


## Hits over shots with one of each before the match, Laplace's rule:
## shown, and setting nothing.
func hit_rate() -> float:
	return (float(hits) + 1.0) / (float(shots) + 2.0)


## The index of the last of `rows` whose "from" `share` reaches: a share
## exactly on a boundary takes the row above it.
static func row_for(rows: Array, share: float) -> int:
	var chosen: int = 0
	for index: int in range(rows.size()):
		if share >= float(rows[index]["from"]):
			chosen = index
	return chosen


## The row every match starts on, and a change of team starts again on:
## the one an empty model's share, 0.5, reaches.
static func start_row(table: Dictionary) -> int:
	return row_for(table["rows"], 0.5)


## The row a reading of `share` sets, `before` being the row read last: a
## share inside the table's band -- from its "from", short of its "to" --
## keeps it, so a match that has come even is left alone; any other share
## takes its own row.
static func next_row(table: Dictionary, share: float, before: int) -> int:
	if in_band(table, share):
		return before
	return row_for(table["rows"], share)


## Whether `share` is inside the table's band, where it moves nothing.
static func in_band(table: Dictionary, share: float) -> bool:
	return share >= float(table["band"]["from"]) and share < float(table["band"]["to"])


## Every interval's reading over `events` -- in order, each with the step
## it happened in -- up to `last_step`, by a fresh model: at each whole
## number of intervals, before that step's events, the counts, the share,
## the hit rate and the row. A seat that empties the counts puts the row
## back to the start, as the match does. What the bot match did live, and
## what condition 3 of ADR 0016's amendment replays.
static func replay(table: Dictionary, events: Array, last_step: int, interval_steps: int) -> Array[Dictionary]:
	var model := PlayerModel.new()
	var row: int = start_row(table)
	var readings: Array[Dictionary] = []
	var next: int = 0
	for tick: int in range(interval_steps, last_step + 1, interval_steps):
		while next < events.size() and int(events[next]["step"]) < tick:
			row = start_row(table) if model.counted_from_empty(events[next]) else row
			next += 1
		var now: Dictionary = model.reading(table, tick, row)
		row = int(now["row"])
		readings.append(now)
	return readings


## What the model reads at `step` through `table`, the row read last being
## `before`: its counts, the share and the hit rate, the row with its aim
## error, and whether the share was inside the band, which held the row.
func reading(table: Dictionary, step: int, before: int) -> Dictionary:
	var share: float = damage_share(float(table["prior_points"]))
	var row: int = next_row(table, share, before)
	return {"step": step, "counts": counts(), "share": share, "hit_rate": hit_rate(), "row": row,
			"aim_error_degrees": float(table["rows"][row]["aim_error_degrees"]),
			"held": in_band(table, share)}
