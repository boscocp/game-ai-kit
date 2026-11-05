## What the scene shows of the XCOM-style mode, as a `TacticalModeView`
## (T85, split from `SquadRuleset` by T126).
##
## - **the fog** of the side whose board is on screen: the cells none of its
##   pieces sees, and a ghost where it last saw each enemy it remembers;
## - **the dash** in a second tint: the walks that leave a piece less than
##   one action, after which it may not shoot;
## - **the odds**, the hit chance on each target before a shot;
## - **the tint** under the cursor: each enemy the person sees that could
##   shoot that cell, and its hit chance there;
## - the status with the chance's reasons (`SquadStatus`), the legend
##   (`SquadLegend`), and the words of a win (`SquadVictory`).
##
## Everything here is drawn from what the rules answer -- the side's view,
## the shots a piece may take, the chance of each -- so the screen cannot
## offer a shot the rules refuse, or show a piece the side does not see.
##
## When not to use it: to decide anything. A controller is handed its side's
## `SideView` by the ruleset, never this.
class_name SquadView
extends TacticalModeView

## The rules, as the XCOM-style mode's: the side's view and its shots.
var squad: SquadRuleset


func _init(shown: SquadRuleset) -> void:
	super(shown)
	squad = shown


## "XCOM", the game this mode plays like: a name, the same in both languages.
func title() -> String:
	return TranslationServer.translate("XCOM")


## The line at the top of the screen.
func what_this_is() -> String:
	return TranslationServer.translate("tactics in the style of XCOM: two actions a piece, cover, flanking and fog")


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
	for enemy: Unit in squad.view(state, person).state.units:
		if enemy.faction != person and SquadCombat.can_reach(SquadScenario.rows(), enemy, cursor):
			var cover: int = SquadCover.of(SquadScenario.rows(), enemy.cell, cursor)["cover"]
			chances[enemy.cell] = SquadCombat.hit_chance(SquadTable.number(enemy.type.type_name, "aim"), defence, cover)
	return chances


## None: this mode holds no ground.
func points() -> Array[Vector2i]:
	return []


## What `side` sees of `state` for the scene to draw: the side's view, the
## cells none of its pieces sees, and a ghost where each enemy it remembers
## was last seen. `earlier` is the same side's last fog, whose memory is the
## `SideView` this one remembers from.
func fog(state: BoardState, side: int, earlier: TacticalFog) -> TacticalFog:
	var remembered: SideView = earlier.memory as SideView if earlier != null else null
	var looked: SideView = squad.view(state, side, remembered)
	var drawn := TacticalFog.new(side, looked.state)
	drawn.memory = looked
	for cell: Vector2i in SquadRuleset.every_cell():
		if not SideView.is_seen(state, SquadScenario.rows(), side, cell):
			drawn.hidden.append(cell)
	for enemy_id: int in looked.last_seen:
		# Its kind is what was seen of it; a piece never changes kind.
		drawn.ghosts[looked.last_seen[enemy_id]] = state.unit_by_id(enemy_id).type.type_name
	return drawn


## The walks that leave `unit` less than one action: dashes, after which it
## may not shoot.
func dashes(state: BoardState, unit: Unit, walks: Dictionary) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for cell: Vector2i in walks:
		if not SquadRuleset.leaves_a_shot(state, unit, walks[cell]):
			found.append(cell)
	return found


## "63%" on each enemy `shooter_id` may shoot now.
func odds(state: BoardState, shooter_id: int) -> Dictionary[Vector2i, String]:
	var labels: Dictionary[Vector2i, String] = {}
	var shooter: Unit = state.unit_by_id(shooter_id)
	if shooter == null:
		return labels
	for strike: Attack in squad.shots_of(state, shooter):
		var target: Unit = state.unit_by_id(strike.target_id)
		labels[target.cell] = "%d%%" % SquadCombat.chance_of(SquadScenario.rows(), shooter, target)
	return labels


## True when `side` sees an enemy on `after` it did not see on `before`.
func reveals(before: BoardState, after: BoardState, side: int) -> bool:
	var seen_before: Array[int] = squad.view(before, side).seen_enemies()
	for enemy_id: int in squad.view(after, side).seen_enemies():
		if not enemy_id in seen_before:
			return true
	return false


## `SquadStatus.text`: the piece in hand, its shots with their reasons.
func status(state: BoardState, in_hand: Unit, refusal: String, news: String, can_attack: bool) -> String:
	return SquadStatus.text(state, in_hand, refusal, news, can_attack)


## `SquadStatus.computer_text`: who plays, what it will do, what it weighed
## -- through the fog on screen.
func computer_status(state: BoardState, turn: BlueTurn, controller: BlueController, news: String,
		shown_fog: TacticalFog) -> String:
	return SquadStatus.computer_text(state, turn, controller, news, shown_fog)


## `SquadStatus.moved_already`: "shoot", in this mode.
func moved_already(unit: Unit, can_attack: bool, can_undo: bool) -> String:
	return SquadStatus.moved_already(unit, can_attack, can_undo)


## `SquadLegend.entries`.
func legend() -> Array[Array]:
	return SquadLegend.entries()
