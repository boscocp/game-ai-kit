## How well the person plays, read from counts during one match (T100).
##
## Hamlet, a dynamic difficulty system on Valve's Half-Life engine, models
## the damage a player takes as a distribution [Hunicke & Chapman]; Ocio
## Barriales balances difficulty through the enemies' accuracy [GAP3 ch. 33].
## This is the smallest honest version of both: it counts what the person's
## bot did -- shots, hits, kills, deaths, damage dealt and taken -- and reads
## the share of the damage it dealt as a Beta mean with a fixed prior,
##
##     share = (dealt + prior) / (dealt + taken + 2 * prior)
##
## which the table in `rules.json` turns into the other team's aim error
## (`MatchDifficulty`). The hit rate, (hits + 1) / (shots + 2), is shown
## beside it and sets nothing.
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

var shots: int = 0
var hits: int = 0
var kills: int = 0
var deaths: int = 0
## Health points the person's shots took off enemies, and that enemies'
## shots took off the person's bot.
var dealt: int = 0
var taken: int = 0


## Add one event of the person's bot: a shot fired, a hit landed (its
## points dealt), a hurt (its points taken), a kill or a death. An event of
## another kind is refused, loudly: a log the model does not read is a log
## it cannot be rebuilt from.
func count(event: Dictionary) -> void:
	var points: int = int(event.get("points", 0))
	match str(event["kind"]):
		SHOT:
			shots += 1
		HIT:
			hits += 1
			dealt += points
		HURT:
			taken += points
		KILL:
			kills += 1
		DEATH:
			deaths += 1
		_:
			push_error("PlayerModel: not an event it counts: %s" % event)  # not shown


## Every count by name, as the vectors write them.
func counts() -> Dictionary:
	return {"shots": shots, "hits": hits, "kills": kills, "deaths": deaths, "dealt": dealt, "taken": taken}


## The share of the damage the person dealt, as if `prior_points` had been
## dealt and as many taken before the match: what the knob is read from.
## An empty model reads 0.5.
func damage_share(prior_points: float) -> float:
	return (float(dealt) + prior_points) / (float(dealt + taken) + 2.0 * prior_points)


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


## Every interval's reading over `events` -- the person's, in order, each
## with the step it happened in -- up to `last_step`, by a fresh model: at
## each whole number of intervals, before that step's events, the counts,
## the share, the hit rate and the row. What the bot match did live, and
## what condition 3 of ADR 0016's amendment replays.
static func replay(table: Dictionary, events: Array, last_step: int, interval_steps: int) -> Array[Dictionary]:
	var model := PlayerModel.new()
	var readings: Array[Dictionary] = []
	var next: int = 0
	for tick: int in range(interval_steps, last_step + 1, interval_steps):
		while next < events.size() and int(events[next]["step"]) < tick:
			model.count(events[next])
			next += 1
		readings.append(model.reading(table, tick))
	return readings


## What the model reads at `step` through `table`: its counts, the share and
## the hit rate, and the row with its aim error.
func reading(table: Dictionary, step: int) -> Dictionary:
	var share: float = damage_share(float(table["prior_points"]))
	var row: int = row_for(table["rows"], share)
	return {"step": step, "counts": counts(), "share": share, "hit_rate": hit_rate(), "row": row,
			"aim_error_degrees": float(table["rows"][row]["aim_error_degrees"])}
