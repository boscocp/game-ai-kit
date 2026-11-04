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
##   (`SquadVictory`);
## - **the tint** is T85's: with the cursor on a cell, each enemy the
##   person sees that could shoot there, and its hit chance.
##
## And what the scene shows (T85): the fog of the side whose board is on
## screen (`fog`), the dash in a second tint (`dashes`), the hit chance on
## each target before a shot (`odds`), the status with the chance's reasons
## (`SquadStatus`) and the legend (`SquadLegend`).
##
## A decision is one unit's action, not a whole squad's orders: Roelofs'
## hierarchical expansion, which keeps a search's branching near one unit's
## options rather than their product (Game AI Pro 3, ch. 28). `actions`
## lists them for the side to move.
##
## When not to use it: overwatch or hunker down. Both are left out on
## purpose (`docs/godot/squad.md`): overwatch acts in the other side's turn,
## and every search in T87 and T88 would have to model it.
class_name SquadRuleset
extends TacticalRuleset


## "squad".
func mode_name() -> String:
	return "squad"  # not shown: a key, the screen words it


## "XCOM", the game this mode plays like: a name, the same in both languages.
func title() -> String:
	return TranslationServer.translate("XCOM")


## The line at the top of the screen.
func what_this_is() -> String:
	return TranslationServer.translate("tactics in the style of XCOM: two actions a piece, cover, flanking and fog")


## `SquadScenario.build`: four pieces a side on the tactical map.
func start() -> BoardState:
	return SquadScenario.build()


## The board's ruling on the route and the movement left.
func why_walk_refused(state: BoardState, move: Move) -> String:
	return state.why_refused(move)


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
func told(before: BoardState, strike: Attack, after: BoardState) -> String:
	return SquadCombat.told(SquadScenario.rows(), before, strike, after)


## The turn passes and the next side's movement is refilled; nothing else
## happens as it opens.
func open_turn(state: BoardState) -> Array:
	return [state.end_turn(TacticalScenario.FACTIONS), [] as Array[String]]


## `SquadVictory.winner`.
func winner(state: BoardState) -> int:
	return SquadVictory.winner(state)


## `SquadVictory.rule`.
func rule() -> String:
	return SquadVictory.rule()


## `SquadVictory.announcement`.
func announcement(winner_side: int, state: BoardState) -> String:
	return SquadVictory.announcement(winner_side, state)


## Nothing with no cursor: the threat in this mode is a hit chance, and a
## chance is against a cell (`tint_at`).
func tint(_state: BoardState, _side: int) -> Dictionary[Vector2i, int]:
	return {}


## On each enemy `person` sees that could shoot `cursor` from where it
## stands, its hit chance there: against the person's piece on that cell,
## or else the piece in hand -- the defence is the defender's -- with the
## cover the cell has against that enemy.
func tint_at(state: BoardState, _side: int, cursor: Vector2i, person: int, in_hand_id: int) -> Dictionary[Vector2i, int]:
	var chances: Dictionary[Vector2i, int] = {}
	if not state.graph.contains(cursor):
		return chances
	var defender: Unit = state.unit_at(cursor)
	if defender == null or defender.faction != person:
		defender = state.unit_by_id(in_hand_id)
	var defence: int = SquadTable.number(defender.type.type_name, "defence") if defender != null else 0
	for enemy: Unit in view(state, person).state.units:
		if enemy.faction != person and SquadCombat.can_reach(SquadScenario.rows(), enemy, cursor):
			var cover: int = SquadCover.of(SquadScenario.rows(), enemy.cell, cursor)["cover"]
			chances[enemy.cell] = SquadCombat.hit_chance(SquadTable.number(enemy.type.type_name, "aim"), defence, cover)
	return chances


## None: this mode holds no ground.
func points() -> Array[Vector2i]:
	return []


## `SquadRoster.names`.
func roster_names() -> Array[String]:
	return SquadRoster.names()


## `SquadRoster.build`.
func build_controller(row_name: String, seed_number: int) -> BlueController:
	return SquadRoster.build(row_name, seed_number)


## What `side` sees of `state` for the scene to draw: the side's view, the
## cells none of its pieces sees, and a ghost where each enemy it remembers
## was last seen. `earlier` is the same side's last fog, whose memory is the
## `SideView` this one remembers from.
func fog(state: BoardState, side: int, earlier: TacticalFog) -> TacticalFog:
	var remembered: SideView = earlier.memory as SideView if earlier != null else null
	var looked: SideView = view(state, side, remembered)
	var drawn := TacticalFog.new(side, looked.state)
	drawn.memory = looked
	for cell: Vector2i in every_cell():
		if not SideView.is_seen(state, SquadScenario.rows(), side, cell):
			drawn.hidden.append(cell)
	for enemy_id: int in looked.last_seen:
		# Its kind is what was seen of it; a piece never changes kind.
		drawn.ghosts[looked.last_seen[enemy_id]] = state.unit_by_id(enemy_id).type.type_name
	return drawn


## Every cell of the map, row by row.
static func every_cell() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var rows: Array[String] = SquadScenario.rows()
	for row: int in range(rows.size()):
		for column: int in range(rows[row].length()):
			cells.append(Vector2i(column, row))
	return cells


## The walks that leave `unit` less than one action: dashes, after which it
## may not shoot.
func dashes(state: BoardState, unit: Unit, walks: Dictionary) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for cell: Vector2i in walks:
		if not leaves_a_shot(state, unit, walks[cell]):
			found.append(cell)
	return found


## True when walking `path` leaves `unit` a shot: no more than one action.
static func leaves_a_shot(state: BoardState, unit: Unit, path: Array[Vector2i]) -> bool:
	var cost: int = Move.new(unit.id, path).cost_on(state.graph_for(unit))
	return unit.movement_points - cost >= SquadTable.action(unit.type.type_name)


## "63%" on each enemy `shooter_id` may shoot now.
func odds(state: BoardState, shooter_id: int) -> Dictionary[Vector2i, String]:
	var labels: Dictionary[Vector2i, String] = {}
	var shooter: Unit = state.unit_by_id(shooter_id)
	if shooter == null:
		return labels
	for strike: Attack in shots_of(state, shooter):
		var target: Unit = state.unit_by_id(strike.target_id)
		labels[target.cell] = "%d%%" % SquadCombat.chance_of(SquadScenario.rows(), shooter, target)
	return labels


## `SquadStatus.text`: the piece in hand, its shots with their reasons.
func status(state: BoardState, in_hand: Unit, refusal: String, news: String, can_attack: bool) -> String:
	return SquadStatus.text(state, in_hand, refusal, news, can_attack)


## `SquadStatus.computer_text`: who plays, what it will do, what it weighed.
func computer_status(state: BoardState, turn: BlueTurn, controller: BlueController, news: String) -> String:
	return SquadStatus.computer_text(state, turn, controller, news)


## `SquadLegend.entries`.
func legend() -> Array[Array]:
	return SquadLegend.entries()


## True when `side` sees an enemy on `after` it did not see on `before`.
func reveals(before: BoardState, after: BoardState, side: int) -> bool:
	var seen_before: Array[int] = view(before, side).seen_enemies()
	for enemy_id: int in view(after, side).seen_enemies():
		if not enemy_id in seen_before:
			return true
	return false


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
