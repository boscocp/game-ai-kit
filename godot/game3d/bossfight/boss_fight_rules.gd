## The boss fight's AI knobs: from `boss_fight.json` what no level changes
## -- the token multipliers and timeouts, the three rings, the director's
## pacing -- and from one level of `difficulty.json` (T158) the token pools
## and their delays, the waves' size and their cap.
##
## Data, so a level fills the same fields and the code that reads them does
## not change. The bodies' speeds and damage are not here: they are the
## game's, not the AI's.
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
## The level these rules were read for.
var level: String = ""
## Melee and ranged minions a wave brings.
var wave: Dictionary[String, int] = {}
## How much faster (below 1) or slower the level shows the boss's tells.
var telegraph_scale: float = 1.0
## The most of each kind that may stand at once: a wave stops there.
var wave_cap: Dictionary[String, int] = {}
## The director's numbers, as `BossDirector` takes them.
var director: Dictionary = {}
## The raw token and ring sections, turned into configs on demand.
var _tokens: Dictionary = {}
var _rings: Dictionary = {}
## Why the file was refused, or "".
var refusal: String = ""


## The shipped rules at `level_name` ("" the default level), or refused
## ones whose `refusal` says why -- an unknown level among them.
static func read(path: String = FILE, level_name: String = "") -> BossFightRules:
	return BossDifficulty.read().rules_for(level_name, path)


## `path` alone, no level applied yet: what every level shares.
static func shared(path: String = FILE) -> BossFightRules:
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
	rules._tokens = data.get("tokens", {})
	rules._rings = data.get("rings", {})
	rules.director = data.get("director", {})
	return rules


## Take `fields`, one level of `difficulty.json`, named `level_name`: its
## pools and delays into the token sections, its wave and its cap.
func apply(level_name: String, fields: Dictionary) -> void:
	level = level_name
	telegraph_scale = float(fields.get("telegraph_scale", 1.0))
	_tokens = _tokens.duplicate(true)
	for section: String in ["pools", "delays"]:
		_tokens[section] = fields.get("tokens", {}).get(section, {})
	for kind: String in fields.get("wave", {}):
		wave[kind] = int(fields["wave"][kind])
		wave_cap[kind] = int(fields.get("wave_cap", {}).get(kind, wave[kind]))


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
