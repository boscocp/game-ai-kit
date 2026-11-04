## A squad that acts at random, from its own side's view: the floor.
##
## Every piece, asked where to walk, takes one of the walks open to it on
## its side's view -- holding is one of them -- and, asked whom to shoot,
## one of the enemies it may shoot, or nobody, all equally likely. The
## numbers come from a generator seeded once, so a seeded game replays.
##
## It decides on `SideView`, never on the state it is handed: a walk it
## picks may end on a cell where an enemy it cannot see is standing, and
## the board refuses that walk as it would refuse any into an occupied cell
## (the turn keeps it in `BlueTurn.refused`, and the piece stays). That is
## fog working, not the controller breaking its contract. T85's gate is
## what holds every controller in this mode to the view.
##
## When not to use it: as an opponent. It is what the first enemy that
## weighs (T85) has to beat by a distance, and nothing more.
class_name RandomSquad
extends BlueController

var _dice := RandomNumberGenerator.new()


func _init(seed_number: int) -> void:
	_dice.seed = seed_number


## "random".
func controller_name() -> String:
	return "random"  # not shown: a roster key


## What it is, for the screen.
func describe() -> String:
	return TranslationServer.translate("a random action per piece, on its side's view")


## A squad has no workshop: it never builds.
func decide_build(state: BoardState, workshop_id: int) -> TacticalDecision:
	return TacticalDecision.hold(workshop_id, [], state.unit_by_id(workshop_id).cell)


## One of the walks open to `unit_id` on its side's view, holding included.
func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
	var seen: BoardState = _view(state)
	var unit: Unit = seen.unit_by_id(unit_id)
	var walks: Dictionary = TacticalReach.walks_for(seen, unit)
	var picked: int = _dice.randi_range(0, walks.size())
	var why: Array = Sentence.of("one of {count} choices, at random", {count = walks.size() + 1})  # shown through tr()
	if picked == walks.size():
		return TacticalDecision.hold(unit_id, why, unit.cell)
	var goal: Vector2i = walks.keys()[picked]
	return TacticalDecision.walk(unit_id, walks[goal], why, goal)


## One of the enemies `unit_id` may shoot on its side's view, or null for
## nobody -- nobody counted as one more choice.
func decide_attack(state: BoardState, unit_id: int) -> TacticalDecision:
	var seen: BoardState = _view(state)
	var targets: Array[Unit] = []
	for enemy: Unit in seen.units:
		if SquadCombat.why_refused(seen, SquadScenario.rows(), Attack.new(unit_id, enemy.id)) == BoardState.LEGAL:
			targets.append(enemy)
	var picked: int = _dice.randi_range(0, targets.size())
	if picked == targets.size():
		return null
	var why: Array = Sentence.of("one of {count} choices, at random", {count = targets.size() + 1})  # shown through tr()
	return TacticalDecision.strike(unit_id, targets[picked], why)


# The side to move's view of `state`, with no memory: a random mover has no
# use for where it last saw anyone.
func _view(state: BoardState) -> BoardState:
	return SideView.seen_by(state, SquadScenario.rows(), state.current_faction).state
