## A shot in the XCOM-style mode: who may shoot whom, the hit chance and its
## reasons, and what one die does.
##
## Hit chance = the shooter's aim - the target's defence - the target's
## cover against that shooter (`SquadCover`), clamped to [0, 100]. One die
## from `rules.json`'s `die`; the shot hits when it shows less than the
## chance, and a hit takes the shooter's damage off. No grazes, no criticals,
## no range penalty: XCOM has all three, and `docs/godot/squad.md` lists them
## among what this mode leaves out.
##
## `shot` is a pure function of the die it is handed, which is how the two
## languages are held to one shot: their generators differ, so the vectors
## hand both the same roll. `apply` rolls from `state.dice_seed` and hands
## the next seed on, as `TacticalCombat` does, so a shot replays.
##
## A shot ends the piece's turn -- UFOpaedia: "a unit's turn automatically
## ends after the unit performs any action other than Move on its 1st
## Action" -- by leaving it no movement; and a piece that has dashed, whose
## movement left is below one action, may not shoot.
##
## When not to use it: an area attack (XCOM's grenades). That hits cells,
## not one target, and needs another type of decision.
class_name SquadCombat
extends RefCounted


## Aim less defence less cover, clamped to [0, 100].
static func hit_chance(aim: int, defence: int, cover: int) -> int:
	return clampi(aim - defence - cover, 0, 100)


## One shot with the die showing `roll`. `inputs` holds `aim`, `defence`,
## `cover`, `damage` and `target_health`; the answer is `chance`, `hit` and
## `target_left`. The same function as Python's `shot.shot`.
static func shot(inputs: Dictionary, roll: int) -> Dictionary:
	var chance: int = hit_chance(inputs["aim"], inputs["defence"], inputs["cover"])
	var hit: bool = roll < chance
	var left: int = maxi(0, inputs["target_health"] - inputs["damage"]) if hit else inputs["target_health"]
	return {"chance": chance, "hit": hit, "target_left": left}


## The shot's inputs, read off the board, with its reasons: the cover, and
## whether the shooter flanked the target -- what T85 shows beside the chance.
static func inputs(rows: Array[String], shooter: Unit, target: Unit) -> Dictionary:
	var covered: Dictionary = SquadCover.of(rows, shooter.cell, target.cell)
	return {
		"aim": SquadTable.number(shooter.type.type_name, "aim"),
		"defence": SquadTable.number(target.type.type_name, "defence"),
		"cover": covered["cover"],
		"flanked": covered["flanked"],
		"damage": SquadTable.number(shooter.type.type_name, "damage"),
		"target_health": target.health,
	}


## The chance `shooter` has of hitting `target` from where both stand now.
static func chance_of(rows: Array[String], shooter: Unit, target: Unit) -> int:
	var given: Dictionary = inputs(rows, shooter, target)
	return hit_chance(given["aim"], given["defence"], given["cover"])


## True while `unit` may still shoot this turn: it has walked no more than
## one action. A dash or a shot leaves it less.
static func can_shoot(unit: Unit) -> bool:
	return unit.movement_points >= SquadTable.action(unit.type.type_name)


## Why this shot cannot be taken, or `BoardState.LEGAL`, in the order a
## player wants to hear it: who, whose turn, whether it still may, at whom,
## whether the shooter itself sees the target -- within its sight, with the
## line clear -- and only then how far. A shot needs the shooter's own sight
## as well as its range: a mortar reaches 7 and sees 6, and without the
## sight rule it shot an enemy its side's view did not hold (wave 113's
## review).
static func why_refused(state: BoardState, rows: Array[String], strike: Attack) -> String:
	var shooter: Unit = state.unit_by_id(strike.attacker_id)
	var target: Unit = state.unit_by_id(strike.target_id)
	if shooter == null:
		return "no unit %d is on the board" % strike.attacker_id
	if shooter.faction != state.current_faction:
		return "unit %d is not on the side to move" % shooter.id
	if not can_shoot(shooter):
		return "unit %d has dashed or shot this turn" % shooter.id
	if target != null and target.faction == shooter.faction:
		return "unit %d is on the same side" % target.id
	# A target that is gone and one the shooter cannot see get the same
	# words, which name no cell and no distance: a refusal that told the
	# shooter's side how far an unseen enemy stood would be a hole in the fog.
	if target == null or not SquadSight.sees(rows, shooter, target.cell):
		return unseen(shooter.id, strike.target_id)
	var apart: int = SquadSight.steps(shooter.cell, target.cell)
	if apart > shooter.type.attack_range:
		return "unit %d is %d away, and unit %d reaches %d" % [target.id, apart, shooter.id, shooter.type.attack_range]
	return BoardState.LEGAL


## The refusal for a shot at an enemy the shooter does not see -- or that is
## not on the board: one sentence for both, so it gives nothing away.
static func unseen(shooter_id: int, target_id: int) -> String:
	return "unit %d sees no enemy unit %d to shoot" % [shooter_id, target_id]


## The state after this shot, or null when it is refused. The die comes from
## `state.dice_seed`, the next state carries a new one, and the shooter has
## no movement left: a shot ends its turn.
static func apply(state: BoardState, rows: Array[String], strike: Attack) -> BoardState:
	if why_refused(state, rows, strike) != BoardState.LEGAL:
		return null
	var dice := RandomNumberGenerator.new()
	dice.seed = state.dice_seed
	var die: Dictionary = SquadTable.rules()["die"]
	var roll: int = dice.randi_range(int(die["lowest"]), int(die["highest"]))
	var fired: Dictionary = shot(inputs(rows, state.unit_by_id(strike.attacker_id), state.unit_by_id(strike.target_id)), roll)
	var next: BoardState = state.duplicate_state()
	next.unit_by_id(strike.attacker_id).movement_points = 0
	next.unit_by_id(strike.target_id).health = fired["target_left"]
	next.dice_seed = dice.randi()
	# Built again so a dead target is dropped, as the constructor drops it.
	return next.duplicate_state()


## One line saying what a shot did: who shot whom, at what chance and why,
## and whether it hit.
static func told(rows: Array[String], before: BoardState, strike: Attack, after: BoardState) -> String:
	var shooter: Unit = before.unit_by_id(strike.attacker_id)
	var target: Unit = before.unit_by_id(strike.target_id)
	var given: Dictionary = inputs(rows, shooter, target)
	var struck: Unit = after.unit_by_id(target.id)
	var left: int = struck.health if struck != null else 0
	var outcome: String = "missed"
	if left < target.health:
		outcome = "hit, %d health left" % left if left > 0 else "hit and destroyed it"
	return "%s %s at %s shot %s %s at %s: %d%% (cover %d%s), %s" % [
		_side(shooter.faction), shooter.type.type_name, shooter.cell,
		_side(target.faction), target.type.type_name, target.cell,
		hit_chance(given["aim"], given["defence"], given["cover"]), given["cover"],
		", flanked" if given["flanked"] else "", outcome]


static func _side(faction: int) -> String:
	return "red" if faction == TacticalScenario.RED else "blue"
