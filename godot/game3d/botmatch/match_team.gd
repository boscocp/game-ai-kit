## One side of the bot match, and the three techniques it plays with, each
## a switch the viewer can turn off on this team alone:
##
##   * claims (`TacticalPositions`): a spot one bot chose is closed to the
##     rest of its team. Off, they bunch on the best spot;
##   * the commander (`TeamCommander` over `TeamInfluence`): each squad sent
##     to a weighed objective. Off, every bot goes to its own nearest point
##     that is not its team's;
##   * retreat (`SquadConfidence`): a squad losing falls back in two waves.
##     Off, it never falls back.
##
## What it knows of the enemy is what its bots saw, kept for a while
## (`remembered`): the team reasons with the same partial picture its bots
## have, never with where the enemy really is.
class_name MatchTeam
extends RefCounted

## What an order sends a squad or a bot to do at its point.
const ATTACK: String = "attack"
const HOLD: String = "hold"

var name: String = ""
var side: int = 0
var use_claims: bool = true
var use_commander: bool = true
var may_retreat: bool = true
## How many bots the commander wants on each point: a squad's worth.
var bots_per_point: int = BotMatch.PER_SQUAD
## True only in a planted test: the whole squad falls back at once, with
## nobody left to cover it. The effects test must catch it.
var retreat_in_one_wave: bool = false
## Whether its bots aim where a shot is worth the most damage (`AimChoice`);
## off, they always aim at the head -- the planted case the effects test
## must tell apart, at range.
var aims_by_worth: bool = true
## How its bots decide on going back to the base for rounds: by weighing it
## (`MatchSupply.WEIGH`), or -- planted -- NEVER, or ALWAYS once one is spent.
var resupply_rule: String = MatchSupply.WEIGH
## How its bots decide on breaking off to heal (T68): by weighing it
## (`MatchSupply.WEIGH`), or -- planted -- NEVER, health counting for
## nothing, or ALWAYS below `MatchHealth.ALWAYS_BELOW`, a fixed threshold.
var heal_rule: String = MatchSupply.WEIGH
## The honest knobs, the same body driven faster or better.
var reaction: float = 0.3
var turn_rate: float = deg_to_rad(270.0)
var aim_error: float = deg_to_rad(3.0)
## Bot ids, and the squads as lists of bot ids in their order.
var members: Array[int] = []
var squads: Array[Array] = []
var squad_states: Array[String] = []
var squad_phases: PackedInt32Array = PackedInt32Array()
var wave_started: PackedFloat64Array = PackedFloat64Array()
## Each bot's order: the point index it is sent to, and ATTACK or HOLD.
var bot_points: Dictionary = {}
var bot_modes: Dictionary = {}
## Each squad's objective id by squad index, as the commander gave it.
var squad_orders: Dictionary = {}
## What this team remembers of each enemy: id -> [place, when seen].
var remembered: Dictionary = {}
## Who holds which spot: spot index -> bot id.
var claims: Dictionary = {}
## When each kill and each loss happened, by squad index.
var kills: Array[PackedFloat64Array] = []
var losses: Array[PackedFloat64Array] = []
## The last influence map built, for the view.
var influence: TeamInfluence
## Each bot's last position query, for the view: bot id -> [Choice, spots].
var last_choice: Dictionary = {}


func _init(team_name: String, team_side: int, rules: MatchRules) -> void:
	name = team_name
	side = team_side
	reaction = rules.reaction
	turn_rate = deg_to_rad(rules.turn_rate_degrees)
	aim_error = deg_to_rad(rules.aim_error_degrees)


## Split `bot_ids` into squads of `per_squad`, in order.
func form_squads(bot_ids: Array[int], per_squad: int) -> void:
	members = bot_ids.duplicate()
	squads.clear()
	for index: int in range(0, bot_ids.size(), per_squad):
		squads.append(bot_ids.slice(index, index + per_squad))
		squad_states.append(SquadConfidence.HOLD)
		squad_phases.append(0)
		wave_started.append(0.0)
		kills.append(PackedFloat64Array())
		losses.append(PackedFloat64Array())


## The squad a bot is in.
func squad_of(bot_id: int) -> int:
	for index: int in range(squads.size()):
		if bot_id in squads[index]:
			return index
	return -1


## Note that this team saw `enemy` at `place` at `now`.
func remember(enemy: int, place: Vector2, now: float) -> void:
	remembered[enemy] = [place, now]


## Forget enemies not seen for `memory` seconds, and old kills and losses.
func forget(now: float, memory: float) -> void:
	for enemy: int in remembered.keys():
		if now - float(remembered[enemy][1]) > memory:
			remembered.erase(enemy)
	for index: int in range(squads.size()):
		kills[index] = _recent(kills[index], now, memory)
		losses[index] = _recent(losses[index], now, memory)


## The places of the enemies this team remembers, in id order; only those
## seen within `within` seconds of `now`, when it is given.
func known_enemies(now: float = 0.0, within: float = INF) -> Array[Vector2]:
	var places: Array[Vector2] = []
	var ids: Array = remembered.keys()
	ids.sort()
	for enemy: int in ids:
		if now - float(remembered[enemy][1]) <= within:
			places.append(remembered[enemy][0])
	return places


## Release whatever `bot_id` claimed, and claim `spot` for it (-1: nothing).
func claim(bot_id: int, spot: int) -> void:
	for held: int in claims.keys():
		if claims[held] == bot_id:
			claims.erase(held)
	if spot != -1:
		claims[spot] = bot_id


static func _recent(times: PackedFloat64Array, now: float, memory: float) -> PackedFloat64Array:
	var kept := PackedFloat64Array()
	for when: float in times:
		if now - when <= memory:
			kept.append(when)
	return kept
