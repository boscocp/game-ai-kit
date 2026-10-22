## The bot match's ammunition and its two weapons, and the two errands they
## make a decision of (the owner's asks, 2026-10-21).
##
## A rifle has 120 rounds, a magazine of 30 and three reloads, and only the
## resupply in a team's spawn room gives more. The power weapon lies in one
## place on the map: three times the rifle's damage and 20 rounds, no
## reload; taken, it comes back a minute later. Its holder has no rifle
## until it takes one at its base again, which it may once the power weapon
## is empty, and a bot that dies comes back with a full rifle. Five kills
## since its last death earn a bot the power weapon at its own base.
##
## Two errands, each weighed by `ErrandChoice` in `ai_teamwork` -- a gain
## less its costs -- and each bot takes the larger if it is above zero:
## back to its base for rounds, or out for the power weapon, one bot a team.
## This file measures the facts the technique weighs and carries out its
## answer; the weights are the rules'. The walks are read off a flood of
## walk steps made once a match, not searched each decision.
class_name MatchSupply
extends RefCounted

const RIFLE: String = "rifle"
const POWER: String = "power"
## The errands: none, back to the base, or to the power weapon.
const NO_ERRAND: String = ErrandChoice.NONE
const RESUPPLY: String = ErrandChoice.RESUPPLY
const FETCH: String = ErrandChoice.FETCH
## How a team decides on going back: weighing it, or -- planted, for the
## effects test -- never, or always once a round is spent.
const WEIGH: String = "weigh"
const NEVER: String = "never"
const ALWAYS: String = "always"

## When the power weapon is next there, in match seconds.
var power_back_at: float = 0.0
## Each side's bot sent for the power weapon, or -1.
var fetcher: PackedInt32Array = PackedInt32Array([-1, -1])
## Walk steps from each side's resupply, and from the power weapon.
var _base_steps: Array[PackedInt32Array] = []
var _power_steps: PackedInt32Array = PackedInt32Array()


func _init(arena: BotArena) -> void:
	for side: int in [BotMatch.BLUE, BotMatch.RED]:
		var base: Vector2 = arena.resupply.get(BotMatch.TEAM_NAMES[side], Vector2.INF)
		_base_steps.append(arena.steps_from(BotArena.cells_at(base)) if base != Vector2.INF else PackedInt32Array())
	if arena.power_place != Vector2.INF:
		_power_steps = arena.steps_from(BotArena.cells_at(arena.power_place))


## A rifle, full: the magazine and every reload.
static func arm_rifle(bot: MatchBot, rules: MatchRules) -> void:
	bot.weapon = RIFLE
	bot.reload_left = 0.0
	bot.ammo = rules.magazine
	bot.reserve = rules.reserve


## The power weapon, its 20 rounds, and no rifle.
static func arm_power(bot: MatchBot, rules: MatchRules) -> void:
	bot.weapon = POWER
	bot.ammo = rules.power_rounds
	bot.reserve = 0
	bot.reload_left = 0.0


## Whether the power weapon lies in its place at `now`.
func power_there(now: float) -> bool:
	return now >= power_back_at


## What `bot` standing where it is takes: at its base, a full rifle -- or
## the power weapon, its streak earning one -- unless it holds a power
## weapon with rounds left; at the power weapon's place, it, if it is
## there and the bot holds a rifle.
func touch(world: BotMatch, bot: MatchBot) -> void:
	var rules: MatchRules = world.rules
	var base: Vector2 = world.arena.resupply.get(BotMatch.TEAM_NAMES[bot.team], Vector2.INF)
	if base != Vector2.INF and bot.position.distance_to(base) <= rules.resupply_radius:
		_resupply(rules, bot)
	var at_power: bool = bot.position.distance_to(world.arena.power_place) <= rules.power_pickup_radius
	if at_power and power_there(world.time) and bot.weapon == RIFLE and _nearest_to_power(world, bot):
		arm_power(bot, rules)
		power_back_at = world.time + rules.power_respawn
		world.stats[bot.team].power_taken += 1
		fetcher[bot.team] = -1


# Whether no other bot that could take the power weapon stands nearer it:
# two arriving in one step, the nearer takes it, not the first in id order
# -- which was always blue.
func _nearest_to_power(world: BotMatch, bot: MatchBot) -> bool:
	var mine: float = bot.position.distance_to(world.arena.power_place)
	for other: MatchBot in world.bots:
		var could: bool = other != bot and other.alive() and other.weapon == RIFLE
		# Exactly as near: neither takes it this step, rather than the first
		# in id order.
		if could and other.position.distance_to(world.arena.power_place) <= mine:
			return false
	return true


func _resupply(rules: MatchRules, bot: MatchBot) -> void:
	if bot.weapon == RIFLE and bot.streak >= rules.streak_for_power:
		arm_power(bot, rules)
		bot.streak = 0
	elif bot.weapon == RIFLE and bot.ammo + bot.reserve < rules.magazine + rules.reserve:
		arm_rifle(bot, rules)
	elif bot.weapon == POWER and bot.ammo <= 0:
		arm_rifle(bot, rules)


## Every errand of `team`'s bots, decided: who is sent for the power weapon,
## and who goes back to its base. Each bot's weighing is kept for the view.
func think(world: BotMatch, team: MatchTeam) -> void:
	var weights: ErrandChoice.Weights = weights_of(world.rules)
	var weighed: Array[int] = []
	var fetch_scores := PackedFloat64Array()
	for bot_id: int in team.members:
		var bot: MatchBot = world.bots[bot_id]
		if not bot.alive() or bot.controlled:
			bot.errand = NO_ERRAND
			continue
		bot.errand_weighing = {
			RESUPPLY: ErrandChoice.weigh_resupply(resupply_facts(world, team, bot), weights),
			FETCH: ErrandChoice.weigh_fetch(fetch_facts(world, team, bot), weights),
		}
		weighed.append(bot_id)
		fetch_scores.append(bot.errand_weighing[FETCH][3])
	var sent: int = ErrandChoice.fetcher(fetch_scores)
	fetcher[team.side] = weighed[sent] if sent != -1 else -1
	for bot_id: int in weighed:
		_choose_errand(team, world.bots[bot_id])


# Its errand, by the technique -- or, planted for the effects test, always
# back once a round is spent, or never.
func _choose_errand(team: MatchTeam, bot: MatchBot) -> void:
	var back: float = bot.errand_weighing[RESUPPLY][3]
	var fetch: float = bot.errand_weighing[FETCH][3] if fetcher[team.side] == bot.id else 0.0
	if team.resupply_rule == ALWAYS and bot.errand_weighing[RESUPPLY][0] > 0.0:
		back = INF
	elif team.resupply_rule == NEVER:
		back = 0.0
	bot.errand = ErrandChoice.choose(back, fetch)


## The rules' weights, as the technique takes them.
static func weights_of(rules: MatchRules) -> ErrandChoice.Weights:
	var weights := ErrandChoice.Weights.new()
	weights.resupply_walk = rules.resupply_walk_weight
	weights.leave_holding = rules.resupply_hold_weight
	weights.leave_attacking = rules.resupply_attack_weight
	weights.power_worth = rules.power_worth
	weights.power_walk = rules.power_walk_weight
	weights.power_danger = rules.power_danger_weight
	return weights


## What going back is weighed on, for `bot`: the share of its rounds the
## base would give back, whether its streak earned the power weapon, the
## walk to its base, whether it is attacking, and whether it has no round
## left. A power weapon with rounds in it is given nothing at the base --
## it changes for a rifle only once empty -- so its spent share is no gain:
## counted as one, a sharp team's power holders went back half full and
## stood at their base for the rest of the match (T67, measured).
func resupply_facts(world: BotMatch, team: MatchTeam, bot: MatchBot) -> ErrandChoice.Resupply:
	var rules: MatchRules = world.rules
	var full: int = rules.power_rounds if bot.weapon == POWER else rules.magazine + rules.reserve
	var facts := ErrandChoice.Resupply.new()
	var refilled: bool = bot.weapon == RIFLE or bot.ammo <= 0
	facts.spent = 1.0 - float(bot.ammo + bot.reserve) / full if refilled else 0.0
	facts.earned_power = bot.weapon == RIFLE and bot.streak >= rules.streak_for_power
	facts.walk_seconds = _walk_seconds(world, _base_steps[bot.team], bot)
	facts.attacking = team.bot_modes.get(bot.id, MatchTeam.HOLD) == MatchTeam.ATTACK
	facts.empty = bot.ammo + bot.reserve <= 0
	return facts


## What fetching is weighed on, for `bot`: whether the power weapon lies
## there for it, the walk, and the enemies its team remembers near it.
func fetch_facts(world: BotMatch, team: MatchTeam, bot: MatchBot) -> ErrandChoice.Fetch:
	var rules: MatchRules = world.rules
	var facts := ErrandChoice.Fetch.new()
	facts.available = power_there(world.time) and bot.weapon != POWER and not _power_steps.is_empty()
	if not facts.available:
		return facts
	facts.walk_seconds = _walk_seconds(world, _power_steps, bot)
	facts.enemies_near = team.known_enemies().filter(func(place: Vector2) -> bool:
		return place.distance_to(world.arena.power_place) <= rules.power_danger_radius).size()
	return facts


## Where an errand sends `bot`: its base, or the power weapon.
static func errand_place(world: BotMatch, bot: MatchBot) -> Vector2:
	if bot.errand == FETCH:
		return world.arena.power_place
	return world.arena.resupply[BotMatch.TEAM_NAMES[bot.team]]


## How far a walk is never: a cell the flood did not reach.
const UNREACHED: float = 1e6


# Seconds of walking from `bot`'s cell, by the flood `steps`.
static func _walk_seconds(world: BotMatch, steps: PackedInt32Array, bot: MatchBot) -> float:
	var cell: Vector2i = BotArena.cell_of(bot.position)
	if steps.is_empty() or not world.arena.walk.contains(cell):
		return UNREACHED
	var walked: int = steps[cell.y * int(world.arena.width) + cell.x]
	return UNREACHED if walked < 0 else walked / world.rules.speed
