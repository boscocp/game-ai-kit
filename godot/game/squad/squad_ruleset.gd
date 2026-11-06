## The XCOM-style mode of the tactical game, as a `TacticalRuleset` (T84).
##
## The same state, map, pieces and turn as the Advance Wars game; another
## shot, cover and fog. What each answer means:
##
## - **a walk** is the board's walk, plus XCOM's dash: a piece whose walking
##   this turn has gone past one action (`SquadTable.action`) is spent. Its
##   type's movement is two actions, so `movement_points` carries the whole
##   two-action turn and `Unit` gains nothing;
## - **an attack** is a shot (`SquadCombat`), which spends the piece;
## - **a turn** opens with the next side's movement refilled -- no income,
##   no points, no towers;
## - **the end** is a squad with no piece left, or the round limit
##   (`SquadVictory`).
##
## What the scene shows of it -- the fog, the dash, the odds, the tint under
## the cursor, the status and the legend (T85) -- is `SquadView` (T126).
##
## A decision is one unit's action, not a whole squad's orders: Roelofs'
## hierarchical expansion, which keeps a search's branching near one unit's
## options rather than their product (Game AI Pro 3, ch. 28). `actions`
## lists them for the side to move.
##
## The map is the tactical map until N or B builds another (T96). The map
## belongs to the ruleset (`map_rows`): a new ruleset -- the scene opened
## again from the menu -- plays on the tactical map, and `start` hands the
## rows to `SquadScenario`, where every rule of the game being played reads
## them. The ruleset keeps the last build too, `map_build`, so the scene's
## view can show it being made.
##
## When not to use it: overwatch or hunker down. Both are left out on
## purpose (`docs/godot/squad.md`): overwatch acts in the other side's turn,
## and every search in T87 and T88 would have to model it.
class_name SquadRuleset
extends TacticalRuleset

## The map this ruleset's games are played on, rows of `TacticalRules`'
## letters; empty for the tactical map, as every ruleset starts.
var map_rows: Array[String] = []
## The last map built (T96), or being shown built a step at a time; null
## while the squads fight on the tactical map.
var map_build: SquadMapBuild
## True while B is showing `map_build` being made, a step a press.
var watching_the_build: bool = false
# The seed the next map starts from: 1, then on past the last one tried, so
# the third map built is the same map every time the scene opens.
var _next_map_seed: int = 1


## A ruleset on the tactical map, whatever map an earlier one built: a map
## outlived the ruleset that built it before (wave 142's review).
func _init() -> void:
	SquadScenario.use_map(map_rows)


## "squad".
func mode_name() -> String:
	return "squad"  # not shown: a key, the screen words it


## `SquadScenario.build`: four pieces a side on this ruleset's map -- the
## tactical one, or the last map built.
func start() -> BoardState:
	SquadScenario.use_map(map_rows)
	return SquadScenario.build()


## Build the next map by wave function collapse. At once, and the next game
## is played on it; or, `watched`, ready to be shown a step at a time
## (`step_the_build`), the game kept on the old map until it is shown whole.
func build_map(watched: bool) -> void:
	map_build = SquadMapBuild.new(_next_map_seed)
	_next_map_seed = map_build.last_seed() + 1
	watching_the_build = watched
	if watched:
		map_build.watch()
	else:
		_play_on_the_build()


## One more step of the build being shown; at its end, the next game is
## played on the map.
func step_the_build() -> void:
	map_build.step()
	if map_build.finished():
		finish_the_build()


## Stop showing the build, and play the next game on its map.
func finish_the_build() -> void:
	watching_the_build = false
	_play_on_the_build()


# The rules read the map built from now on -- unless no seed gave one, and
# the squads stay where they were.
func _play_on_the_build() -> void:
	if not map_build.rows.is_empty():
		map_rows = map_build.rows.duplicate()
		SquadScenario.use_map(map_rows)


## The board's ruling on the route and the movement left -- except that a
## walk that would cross or end on a piece the walker's side cannot see is
## refused in words that name nothing: not the cell, not the piece, not that
## the cell is taken. A refusal that named them would tell the side what its
## fog hides (wave 119's review). The board's own "is blocked" gets the same
## words, so the two cannot be told apart.
func why_walk_refused(state: BoardState, move: Move) -> String:
	var walker: Unit = state.unit_by_id(move.unit_id)
	var refusal: String = state.why_refused(move)
	if walker == null or refusal == BoardState.LEGAL:
		return refusal
	if refusal.ends_with("is blocked") or _crosses_the_unseen(state, walker, move):  # not shown: the board's English, compared
		return blocked(move.unit_id)
	return refusal


## The refusal of a walk that is blocked, by the ground or by what the
## walker's side does not see: one sentence for both.
static func blocked(unit_id: int) -> String:
	return "unit %d cannot walk there" % unit_id  # not shown: worded by SquadStatus.SHAPES


## True when `move` steps on a cell where a piece stands that `walker`'s side
## cannot see.
func _crosses_the_unseen(state: BoardState, walker: Unit, move: Move) -> bool:
	for step: Vector2i in move.path:
		var standing: Unit = state.unit_at(step)
		var an_enemy: bool = standing != null and standing.faction != walker.faction
		if an_enemy and not SideView.is_seen(state, SquadScenario.rows(), walker.faction, step):
			return true
	return false


## The board's walk; a walk that leaves the piece less than one action is a
## dash, and spends it.
func walk(state: BoardState, move: Move) -> BoardState:
	var next: BoardState = state.apply(move)
	if next == null:
		return null
	var walker: Unit = next.unit_by_id(move.unit_id)
	if not SquadCombat.can_shoot(walker):
		walker.movement_points = 0
	return next


## `SquadCombat.why_refused` on the tactical map.
func why_attack_refused(state: BoardState, strike: Attack) -> String:
	return SquadCombat.why_refused(state, SquadScenario.rows(), strike)


## `SquadCombat.apply`: one shot, one die.
func attack(state: BoardState, strike: Attack) -> BoardState:
	return SquadCombat.apply(state, SquadScenario.rows(), strike)


## `SquadCombat.told`: the chance, the cover, and what the die did.
func told(before: BoardState, strike: Attack, after: BoardState) -> Array:
	return SquadCombat.told(SquadScenario.rows(), before, strike, after)


## The turn passes and the next side's movement is refilled; nothing else
## happens as it opens.
func open_turn(state: BoardState) -> Array:
	return [state.end_turn(TacticalScenario.FACTIONS), [] as Array[Array]]


## `SquadVictory.winner`.
func winner(state: BoardState) -> int:
	return SquadVictory.winner(state)


## `SquadRoster.names`.
func roster_names() -> Array[String]:
	return SquadRoster.names()


## `SquadRoster.build`, for the scene: an enemy that searches is built to
## search a frame at a time (`SearchingSquad.spread_over_frames`), so the
## board keeps drawing while it thinks.
func build_controller(row_name: String, seed_number: int) -> BlueController:
	var built: BlueController = SquadRoster.build(row_name, seed_number)
	if built is SearchingSquad:
		(built as SearchingSquad).spread_over_frames()
	return built


## Every cell of the map, row by row.
static func every_cell() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var rows: Array[String] = SquadScenario.rows()
	for row: int in range(rows.size()):
		for column: int in range(rows[row].length()):
			cells.append(Vector2i(column, row))
	return cells


## True when walking `path` leaves `unit` a shot: no more than one action.
static func leaves_a_shot(state: BoardState, unit: Unit, path: Array[Vector2i]) -> bool:
	var cost: int = Move.new(unit.id, path).cost_on(state.graph_for(unit))
	return unit.movement_points - cost >= SquadTable.action(unit.type.type_name)


## A piece that dashed or shot may not shoot.
func can_still_attack(_state: BoardState, unit: Unit) -> bool:
	return SquadCombat.can_shoot(unit)


## `SquadView`: the fog, the dash, the odds and the chance under the cursor.
func mode_view() -> TacticalModeView:
	return SquadView.new(self)


## `side`'s view of `state` (`SideView`), remembering `earlier`'s.
func view(state: BoardState, side: int, earlier: SideView = null) -> SideView:
	return SideView.seen_by(state, SquadScenario.rows(), side, earlier)


## Every legal action of the side to move, each one unit's: every walk of
## each piece with movement left, then every shot of each piece that may
## still shoot. Holding is not listed; it is always legal, and changes
## nothing.
func actions(state: BoardState) -> Array:
	var found: Array = []
	for unit: Unit in state.units_of(state.current_faction):
		var walks: Dictionary = TacticalReach.walks_for(state, unit)
		for goal: Vector2i in walks:
			found.append(Move.new(unit.id, walks[goal]))
	for unit: Unit in state.units_of(state.current_faction):
		found.append_array(shots_of(state, unit))
	return found


## Every shot `unit` may take now, one per enemy it may shoot.
func shots_of(state: BoardState, unit: Unit) -> Array[Attack]:
	var found: Array[Attack] = []
	for enemy: Unit in state.units:
		var strike := Attack.new(unit.id, enemy.id)
		if why_attack_refused(state, strike) == BoardState.LEGAL:
			found.append(strike)
	return found


## `action` -- a `Move` or an `Attack` -- played on `state`, or null when
## it is refused.
func play(state: BoardState, action: Object) -> BoardState:
	if action is Move:
		return walk(state, action as Move)
	return attack(state, action as Attack)
