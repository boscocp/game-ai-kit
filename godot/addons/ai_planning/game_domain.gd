## The game's own domain: everything the AI can do, and what each thing needs
## first.
##
## This is the file to open to find out what the AI is actually reasoning
## about. It is written out in GDScript rather than loaded from a file because
## a domain you can read beside the planner that runs it is the lesson; the
## PDDL reader in `python/gameaikit/pddl/` is for domains somebody else wrote.
##
## When not to use it: as the real game's domain. It is deliberately the
## smallest chain that a reactive rule cannot produce, and T11 is where a
## faction actually plays with it.
class_name GameDomain
extends RefCounted

## The army is at home and has not moved.
const ARMY_IN_RESERVE: String = "army_in_reserve"

## The army is standing on the resource node.
const ARMY_AT_NODE: String = "army_at_node"

## The node is ours and produces.
const NODE_HELD: String = "node_held"

## There is enough in the bank to pay for one thing. One thing, and the two
## actions that spend it are the reason this domain needs a planner.
const RESOURCES_BANKED: String = "resources_banked"

## Somewhere to train units.
const BARRACKS_BUILT: String = "barracks_built"

## A unit is trained and waiting.
const UNIT_TRAINED: String = "unit_trained"

## We know where the enemy is.
const ENEMY_SCOUTED: String = "enemy_scouted"

## The thing the AI is for.
const ENEMY_BEATEN: String = "enemy_beaten"


## Every action the AI may take.
##
## | action          | needs                        | deletes          | adds            |
## |-----------------|------------------------------|------------------|-----------------|
## | march_to_node   | army_in_reserve              | army_in_reserve  | army_at_node    |
## | take_the_node   | army_at_node                 | --               | node_held       |
## | mine_the_node   | node_held                    | --               | resources_banked|
## | build_barracks  | resources_banked             | resources_banked | barracks_built  |
## | train_unit      | resources_banked, barracks   | resources_banked | unit_trained    |
## | scout_the_enemy | army_at_node                 | --               | enemy_scouted   |
## | attack          | unit_trained, enemy_scouted  | unit_trained     | enemy_beaten    |
##
## The delete lists are where the planning is. `build_barracks` and
## `train_unit` both spend the same single bank of resources, so the AI has to
## mine **twice**, with the barracks in between -- and a reactive rule saying
## "if you have resources, train a unit" never builds the barracks it needs.
static func actions() -> Array[StripsAction]:
	return [
		StripsAction.new("march_to_node",
			[ARMY_IN_RESERVE], [ARMY_IN_RESERVE], [ARMY_AT_NODE]),
		StripsAction.new("take_the_node",
			[ARMY_AT_NODE], [], [NODE_HELD]),
		StripsAction.new("mine_the_node",
			[NODE_HELD], [], [RESOURCES_BANKED]),
		StripsAction.new("build_barracks",
			[RESOURCES_BANKED], [RESOURCES_BANKED], [BARRACKS_BUILT]),
		StripsAction.new("train_unit",
			[RESOURCES_BANKED, BARRACKS_BUILT], [RESOURCES_BANKED], [UNIT_TRAINED]),
		StripsAction.new("scout_the_enemy",
			[ARMY_AT_NODE], [], [ENEMY_SCOUTED]),
		StripsAction.new("attack",
			[UNIT_TRAINED, ENEMY_SCOUTED], [UNIT_TRAINED], [ENEMY_BEATEN]),
	]


## The world at the start of the scenario: an army at home and nothing else.
static func opening_world() -> WorldState:
	return WorldState.new([ARMY_IN_RESERVE])


## What the AI is trying to bring about.
static func goal() -> PackedStringArray:
	return PackedStringArray([ENEMY_BEATEN])
