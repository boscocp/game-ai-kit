## The whole match from above, in 2D, where the team decisions are easiest
## to read at once: the watched team's influence map as a heat, every bot,
## every squad's order as an arrow to its point, its confidence as a bar
## with the attack and retreat thresholds marked, and the frontline between
## the two sides' centres.
class_name BotMatchMap
extends Control

## Pixels per metre.
const SCALE: float = 7.0
const BAR_WIDTH: float = 60.0
const ATTACK_MARK: Color = Color(0.4, 0.9, 0.4)
const RETREAT_MARK: Color = Color(0.95, 0.5, 0.2)
const FRONTLINE: Color = Color(1, 1, 1, 0.6)

var world: BotMatch
## Whose influence and squads are drawn.
var watched_team: int = BotMatch.BLUE


func _draw() -> void:
	if world == null:
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(world.arena.width, world.arena.depth) * SCALE), Color(0.1, 0.1, 0.12, 0.85))
	_draw_influence(world.teams[watched_team])
	for box: AABB in world.arena.boxes:
		var footprint := Rect2(Vector2(box.position.x, box.position.z) * SCALE, Vector2(box.size.x, box.size.z) * SCALE)
		draw_rect(footprint, Color(0.7, 0.7, 0.75))
	for index: int in range(world.arena.point_places.size()):
		var owner: int = world.point_owner[index]
		var colour: Color = BotMatchDrawing.NOBODY if owner == -1 else _team_colour(owner)
		draw_arc(world.arena.point_places[index] * SCALE, world.rules.capture_radius * SCALE, 0, TAU, 24, colour, 2.0)
	for side: int in [BotMatch.BLUE, BotMatch.RED]:
		var base: Vector2 = world.arena.resupply.get(BotMatch.TEAM_NAMES[side], Vector2.INF)
		if base != Vector2.INF:
			draw_arc(base * SCALE, world.rules.resupply_radius * SCALE, 0, TAU, 16, _team_colour(side), 2.0)
	if world.supply.power_there(world.time):
		draw_rect(Rect2(world.arena.power_place * SCALE - Vector2(4, 2), Vector2(8, 4)), BotMatchDrawing.POWER)
	for bot: MatchBot in world.bots:
		if bot.alive():
			draw_circle(bot.position * SCALE, 3.5, _team_colour(bot.team))
	_draw_squads(world.teams[watched_team])
	_draw_frontline()


func _draw_influence(team: MatchTeam) -> void:
	if team.influence == null:
		return
	var values: PackedFloat64Array = team.influence.values()
	var cell: float = team.influence.cell_size * SCALE
	for row: int in range(team.influence.height):
		for column: int in range(team.influence.width):
			var value: float = clampf(values[row * team.influence.width + column], -1.0, 1.0)
			var tint: Color = _team_colour(team.side) if value > 0.0 else _team_colour(1 - team.side)
			draw_rect(Rect2(Vector2(column, row) * cell, Vector2(cell, cell)), Color(tint, absf(value) * 0.45))


# Each squad: an arrow from its centre to its point, and a confidence bar.
func _draw_squads(team: MatchTeam) -> void:
	for index: int in range(team.squads.size()):
		var centre: Vector2 = _squad_centre(team, index)
		if centre == Vector2.INF:
			continue
		var point: int = team.bot_points.get(team.squads[index][0], 0)
		draw_line(centre * SCALE, world.arena.point_places[point] * SCALE, Color(1, 1, 1, 0.8), 1.5)
		_draw_bar(centre * SCALE + Vector2(-BAR_WIDTH / 2.0, 8.0), team, index)


func _draw_bar(at: Vector2, team: MatchTeam, index: int) -> void:
	var thresholds: SquadConfidence.Thresholds = TeamTactics.thresholds_of(world.rules)
	var full: float = 2.0
	var value: float = clampf(float(world.squad_confidence[team.side].get(index, 1.0)), 0.0, full)
	draw_rect(Rect2(at, Vector2(BAR_WIDTH, 6.0)), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(at, Vector2(BAR_WIDTH * value / full, 6.0)), _team_colour(team.side))
	for mark: Array in [[thresholds.retreat_at, RETREAT_MARK], [thresholds.attack_at, ATTACK_MARK]]:
		var x: float = at.x + BAR_WIDTH * float(mark[0]) / full
		draw_line(Vector2(x, at.y - 2.0), Vector2(x, at.y + 8.0), mark[1], 2.0)
	draw_string(ThemeDB.fallback_font, at + Vector2(0, 18.0), BotMatchWords.word(team.squad_states[index]),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11)


# The line between the two sides' living centres, and its middle marked.
func _draw_frontline() -> void:
	var blue: Vector2 = _side_centre(BotMatch.BLUE)
	var red: Vector2 = _side_centre(BotMatch.RED)
	if blue == Vector2.INF or red == Vector2.INF:
		return
	draw_line(blue * SCALE, red * SCALE, FRONTLINE, 1.0)
	draw_circle((blue + red) / 2.0 * SCALE, 3.0, FRONTLINE)


func _squad_centre(team: MatchTeam, index: int) -> Vector2:
	return _centre_of(team.squads[index])


func _side_centre(side: int) -> Vector2:
	return _centre_of(world.teams[side].members)


func _centre_of(ids: Array) -> Vector2:
	var total := Vector2.ZERO
	var living: int = 0
	for bot_id: int in ids:
		if world.bots[bot_id].alive():
			total += world.bots[bot_id].position
			living += 1
	return total / living if living > 0 else Vector2.INF


static func _team_colour(side: int) -> Color:
	return BotMatchDrawing.BLUE if side == BotMatch.BLUE else BotMatchDrawing.RED
