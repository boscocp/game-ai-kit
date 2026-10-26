## What falling back is measured by (T65), counted as a match plays: how
## often a bot in each band of health and exposure dies soon after, and
## how often a fall-back from a point is followed by losing it.
##
## Printed by the effects gate, never claimed and never read by a bot.
## Wave 97 built a fall-back weighed from the first table, and measured it
## with the second; it lost to never falling back, and the owner closed T65
## as measured, reverting it (docs/godot/botmatch.md). The counts stayed:
## they read today's retreat without changing a step of it.
##
## Constant work a bot a decision, plus a ray per known enemy for each bot
## sampled. When not to use it: to decide anything. It only counts.
class_name MatchFallBacks
extends RefCounted

## A bot sampled at a decision counts as dying in its band when it dies
## within this many seconds after.
const DYING_WITHIN: float = 5.0
## A fall-back from a held point counts as losing it when the point is
## neutralised within this many seconds: a point given up is neutral in 4 s
## and the enemy's in 8.
const LOST_WITHIN: float = 8.0
## Health in tenths, exposure in three: none, a half, all.
const HEALTH_BANDS: int = 10
const EXPOSURE_BANDS: int = 3

## Whether this match samples dying -- a ray per enemy known, each bot each
## decision -- or only counts its fall-backs.
var samples_dying: bool = false
## Whether each bot was falling back at the last decision.
var _was_falling: Dictionary = {}
## Each side's fall-backs from a held point not yet resolved: [when, point].
var _pending: Array[Array] = [[], []]
## Each bot's samples of the last DYING_WITHIN seconds: [[when, band]].
var _samples: Dictionary = {}


## A table of zeros, one per band.
static func empty_bands() -> PackedFloat64Array:
	var bands := PackedFloat64Array()
	bands.resize(HEALTH_BANDS * EXPOSURE_BANDS)
	bands.fill(0.0)
	return bands


## The band of a bot with `health_share` of its health, 0 to 1, and
## `exposure`, 0 to 1: health band times EXPOSURE_BANDS plus exposure band.
static func band(health_share: float, exposure: float) -> int:
	var health_band: int = clampi(floori(health_share * HEALTH_BANDS), 0, HEALTH_BANDS - 1)
	var exposure_band: int = clampi(roundi(exposure * (EXPOSURE_BANDS - 1)), 0, EXPOSURE_BANDS - 1)
	return health_band * EXPOSURE_BANDS + exposure_band


## After every bot decided: note each fall-back begun, and sample each
## living bot's band when this match samples dying.
func after_decision(world: BotMatch) -> void:
	for bot: MatchBot in world.bots:
		var team: MatchTeam = world.teams[bot.team]
		var falling: bool = bot.alive() and TeamTactics.moving_in_retreat(world, team, bot)
		if falling and not _was_falling.get(bot.id, false):
			_began(world, bot)
		_was_falling[bot.id] = falling
		if samples_dying and bot.alive():
			_sample(world, team, bot)
	for side: int in [BotMatch.BLUE, BotMatch.RED]:
		_pending[side] = _pending[side].filter(func(entry: Array) -> bool:
			return world.time - float(entry[0]) <= LOST_WITHIN)


## `victim` died: every sample of its last DYING_WITHIN seconds died.
func died(world: BotMatch, victim: MatchBot) -> void:
	_was_falling[victim.id] = false
	var stats: MatchStats = world.stats[victim.team]
	for sample: Array in _samples.get(victim.id, []):
		if world.time - float(sample[0]) <= DYING_WITHIN:
			stats.dying_deaths[int(sample[1])] += 1.0
	_samples.erase(victim.id)


## `side` lost point `point` at `now`: each of its fall-backs from it in
## the last LOST_WITHIN seconds is counted as followed by the loss.
func neutralised(world: BotMatch, side: int, point: int) -> void:
	var kept: Array = []
	for entry: Array in _pending[side]:
		if int(entry[1]) == point and world.time - float(entry[0]) <= LOST_WITHIN:
			world.stats[side].fall_backs_lost += 1
		else:
			kept.append(entry)
	_pending[side] = kept


func _began(world: BotMatch, bot: MatchBot) -> void:
	var stats: MatchStats = world.stats[bot.team]
	stats.fall_backs += 1
	var point: int = held_point_near(world, bot.team, bot.position)
	if point != -1:
		stats.fall_backs_held += 1
		_pending[bot.team].append([world.time, point])


## The nearest point `side` owns within the rules' area radius of `place`,
## or -1: the point a bot standing there holds.
static func held_point_near(world: BotMatch, side: int, place: Vector2) -> int:
	var nearest: int = -1
	for index: int in range(world.arena.point_places.size()):
		var distance: float = world.arena.point_places[index].distance_to(place)
		var nearer: bool = nearest == -1 or distance < world.arena.point_places[nearest].distance_to(place)
		if world.point_owner[index] == side and distance <= world.rules.area_radius and nearer:
			nearest = index
	return nearest


func _sample(world: BotMatch, team: MatchTeam, bot: MatchBot) -> void:
	var share: float = float(bot.health) / world.rules.health
	var which: int = band(share, MatchHealth.exposure(world, team, bot))
	world.stats[bot.team].dying_samples[which] += 1.0
	var kept: Array = (_samples.get(bot.id, []) as Array).filter(func(sample: Array) -> bool:
		return world.time - float(sample[0]) <= DYING_WITHIN)
	kept.append([world.time, which])
	_samples[bot.id] = kept
