## The facts `TacticalPositions` scores a spot by, measured in the arena.
##
## Every fact is a sight line or a distance, from what the team knows: the
## threats are the enemies it remembers, not where they really are.
##
##   * covered from the main threat: the line from its eyes to a bot
##     crouched on the spot is blocked;
##   * fires on it: the line from a bot standing on the spot to its chest is
##     clear, and within range;
##   * covered from the others: the share of the other threats whose eyes
##     cannot see the crouched bot;
##   * hidden from all: covered from the main threat and from every other
##     one asked -- what a bot hiding to heal needs (T68).
##
## Travel is the straight distance, not the walked one. A walked distance is
## an A* per candidate; the straight one is what CryEngine's own queries
## start from, and on this arena the two differ only around a box.
class_name SpotFacts
extends RefCounted


## The candidate for place `place` (an index into the match's places), for
## `bot` choosing within `area` ([centre, radius]) under `threats`, the main
## one first.
static func build(world: BotMatch, team: MatchTeam, bot: MatchBot, place: int, area: Array,
		threats: Array[Vector2]) -> TacticalPositions.Candidate:
	var rules: MatchRules = world.rules
	var at: Vector2 = world.place_position(place)
	var candidate := TacticalPositions.Candidate.new()
	candidate.id = world.place_id(place)
	candidate.travel = bot.position.distance_to(at)
	candidate.in_area = at.distance_to(area[0]) <= float(area[1])
	candidate.claimed_by = int(team.claims.get(place, -1))
	if threats.is_empty():
		return candidate
	var main: Vector2 = threats[0]
	candidate.threat_distance = at.distance_to(main)
	candidate.covered_from_main = not _sees(world, main, at, rules.crouched_height)
	var standing: Vector3 = world.arena.above(at, rules.eye_height)
	var chest: Vector3 = world.arena.above(main, rules.chest_height)
	candidate.fires_on_main = candidate.threat_distance <= rules.max_range and world.arena.clear_line(standing, chest)
	candidate.covered_from_others = _share_covered(world, threats.slice(1), at)
	candidate.hidden_from_all = candidate.covered_from_main and (threats.size() == 1 or candidate.covered_from_others >= 1.0)
	return candidate


# Whether an enemy's eyes at `from` see a body at `at`, `height` up, each
# above the floor there.
static func _sees(world: BotMatch, from: Vector2, at: Vector2, height: float) -> bool:
	return world.arena.clear_line(world.arena.above(from, world.rules.eye_height), world.arena.above(at, height))


static func _share_covered(world: BotMatch, others: Array[Vector2], at: Vector2) -> float:
	if others.is_empty():
		return 0.0
	var covered: int = 0
	for other: Vector2 in others:
		if not _sees(world, other, at, world.rules.crouched_height):
			covered += 1
	return float(covered) / others.size()
