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
## - **the tint** is nothing yet: T85 decides what T shows in this mode.
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


## Nothing yet: T85 decides what the T key shows in this mode.
func tint(_state: BoardState, _side: int) -> Dictionary[Vector2i, int]:
	return {}


## None: this mode holds no ground.
func points() -> Array[Vector2i]:
	return []


## `SquadRoster.names`.
func roster_names() -> Array[String]:
	return SquadRoster.names()


## `SquadRoster.build`.
func build_controller(row_name: String, seed_number: int) -> BlueController:
	return SquadRoster.build(row_name, seed_number)


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
