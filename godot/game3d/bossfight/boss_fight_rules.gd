## The boss fight's AI knobs, read from `boss_fight.json`: the token pools and
## their delays, the three rings, and the group the boss fights with.
##
## Data, so T158's difficulty table can fill the same fields per level and
## the code that reads them does not change. The bodies' speeds and damage
## are not here: they are the game's, not the AI's.
##
## When not to use it: for anything a body does -- that is `BossFightPlayer`,
## `BossMinion` and `BossFight`'s constants.
class_name BossFightRules
extends RefCounted

const FILE: String = "res://game3d/bossfight/boss_fight.json"
## The player's two states the token delays are stretched by: a melee
## minion winding up or striking at the player, or not.
const PRESSED: String = "pressed"  # shown through tr()
const FREE: String = "free"  # shown through tr()

## Seconds a world step simulates.
var step_seconds: float = 1.0 / 30.0
## Seconds between two rounds of the minions' decisions.
var decide_every: float = 0.25
## Half the arena's side, in metres; the arena is centred on the origin.
var arena_half: int = 15
## The pillars' cells: they block sight and bodies.
var pillars: Array[Vector2i] = []
## Melee and ranged minions in a wave.
var wave: Dictionary[String, int] = {}
## The raw token and ring sections, turned into configs on demand.
var _tokens: Dictionary = {}
var _rings: Dictionary = {}
## Why the file was refused, or "".
var refusal: String = ""


## The shipped rules, or refused ones whose `refusal` says why.
static func read(path: String = FILE) -> BossFightRules:
	var rules: BossFightRules = new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		rules.refusal = "%s is not a JSON object" % path  # not shown: a refusal for whoever edits the data, in its keys' English
		return rules
	var data: Dictionary = parsed
	rules.step_seconds = float(data.get("step_seconds", rules.step_seconds))
	rules.decide_every = float(data.get("decide_every", rules.decide_every))
	rules.arena_half = int(data.get("arena_half", rules.arena_half))
	for cell: Array in data.get("pillars", []):
		rules.pillars.append(Vector2i(int(cell[0]), int(cell[1])))
	for kind: String in data.get("wave", {}):
		rules.wave[kind] = int(data["wave"][kind])
	rules._tokens = data.get("tokens", {})
	rules._rings = data.get("rings", {})
	return rules


## The player's token pool's numbers, as `AttackTokens` takes them.
func token_config() -> AttackTokens.Config:
	var config := AttackTokens.Config.new()
	for kind: String in _tokens.get("pools", {}):
		config.pools[kind] = int(_tokens["pools"][kind])
		config.delays[kind] = float(_tokens.get("delays", {}).get(kind, 0.0))
		config.timeouts[kind] = float(_tokens.get("timeouts", {}).get(kind, 0.0))
	for state: String in _tokens.get("multipliers", {}):
		config.multipliers[state] = _tokens["multipliers"][state]
	config.patience = int(_tokens.get("patience", config.patience))
	return config


## The rings round the player, as `EngagementRings` takes them.
func rings_config() -> EngagementRings.Config:
	var config := EngagementRings.Config.new()
	config.spacing = float(_rings.get("spacing", config.spacing))
	for fields: Dictionary in _rings.get("rings", []):
		var ring := EngagementRings.Ring.new()
		ring.name = str(fields["name"])
		ring.radius = float(fields["radius"])
		ring.count = int(fields["count"])
		ring.phase = float(fields.get("phase", 0.0))
		config.rings.append(ring)
	return config
