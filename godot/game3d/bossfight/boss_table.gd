## The boss's moveset as data: each attack's three windows, and the phases
## that open at health thresholds, each with its own attacks and tells.
##
## Every attack has a **telegraph** (the wind-up the player sees), an
## **active** window (the one that hurts) and a **recovery** (the opening to
## punish). A blow the player cannot see coming is not a fair one -- DOOM's
## designers found it "unfair if the demons are attacking when the player
## cannot respond" [Thompson 2018] -- so the table carries a minimum
## telegraph and refuses an attack that would be shown for less than that
## in any phase where it is used, a later phase's faster tells included.
##
## The table is refused whole, with the reason in `refusal`, rather than read
## as something else: a telegraph of zero, a phase whose health condition can
## never be met, or a phase out of order would otherwise only show up in the
## middle of a fight.
##
## When not to use it: an enemy with no phases and one attack needs no table;
## the windows alone are three numbers.
class_name BossTable
extends RefCounted

## The shipped moveset.
const FILE: String = "res://game3d/bossfight/boss_attacks.json"
## The three windows, in the order an attack runs them.
const WINDOWS: Array[String] = ["telegraph", "active", "recovery"]  # not shown: the data's field names
## A phase needs a choice to make: with one attack, "never three in a row"
## would leave the boss with nothing to do.
const FEWEST_ATTACKS: int = 2


## One attack, a blow: its token kind, whether it takes the kind's whole pool, its
## weight and considerations for `ActionChoice`, and its three windows.
class Blow:
	extends RefCounted
	var name: String
	var kind: String
	var heavy: bool
	var weight: float
	var considerations: Array
	var telegraph: float
	var active: float
	var recovery: float


## One phase: entered when health is at most `health_at_most`; its tells are
## the attacks' telegraphs times `telegraph_scale`; `summon` is read by the
## minions' director (T158), not by the boss.
class Phase:
	extends RefCounted
	var name: String
	var health_at_most: float
	var telegraph_scale: float
	var summon: bool
	var attacks: PackedStringArray


## The shortest telegraph any attack may be shown for, in seconds.
var minimum_telegraph: float = 0.0
## The boss's place in the token queue, above the minions'.
var priority: int = 0
## By name.
var attacks: Dictionary[String, Blow] = {}
## In the order they are entered: health thresholds going down.
var phases: Array[Phase] = []
## Why the data was refused, or "".
var refusal: String = ""


## The shipped table, or a refused one whose `refusal` says why.
static func from_file(path: String = FILE) -> BossTable:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not (parser.data is Dictionary):
		var broken: BossTable = new()
		broken.refusal = "%s is not a JSON object: %s" % [path, parser.get_error_message()]  # not shown: a refusal for whoever edits the data, in its keys' English
		return broken
	return from_data(parser.data)


## A table from plain data, as the JSON file writes it. Refused data still
## gives a table, empty, with `refusal` saying why.
static func from_data(data: Dictionary) -> BossTable:
	var table: BossTable = new()
	table.refusal = why_not_table(data)
	if table.refusal != "":
		return table
	table.minimum_telegraph = float(data["minimum_telegraph"])
	table.priority = int(data.get("priority", 0))
	for attack_name: String in data["attacks"]:
		table.attacks[attack_name] = _attack_from(attack_name, data["attacks"][attack_name])
	for fields: Dictionary in data["phases"]:
		table.phases.append(_phase_from(fields))
	return table


## How long `attack_name` is telegraphed in phase `phase_index`: its own
## wind-up, made faster by the phase.
func telegraph_of(attack_name: String, phase_index: int) -> float:
	return attacks[attack_name].telegraph * phases[phase_index].telegraph_scale


## The longest any attack runs, all three windows: a token's timeout must
## be longer, or the boss loses its token mid-swing.
func longest_attack() -> float:
	var longest: float = 0.0
	for attack: Blow in attacks.values():
		longest = maxf(longest, attack.telegraph + attack.active + attack.recovery)
	return longest


## Why `data` is not a boss table, or "": the minimum telegraph above zero,
## every attack's windows and considerations sound, and the phases in order
## with every attack shown for at least the minimum.
static func why_not_table(data: Dictionary) -> String:
	if float(data.get("minimum_telegraph", 0.0)) <= 0.0:
		return "the minimum telegraph must be above zero"  # not shown: a refusal for whoever edits the data, in its keys' English
	if not (data.get("attacks") is Dictionary) or not (data.get("phases") is Array):
		return "a table needs an attacks object and a phases list"  # not shown: a refusal for whoever edits the data, in its keys' English
	for attack_name: String in data["attacks"]:
		var objection: String = _why_not_attack(attack_name, data["attacks"][attack_name])
		if objection != "":
			return objection
	return _why_not_phases(data)


static func _why_not_attack(attack_name: String, fields: Variant) -> String:
	if not (fields is Dictionary) or not (fields as Dictionary).has("kind"):
		return "attack %s needs a kind" % attack_name  # not shown: a refusal for whoever edits the data, in its keys' English
	for window: String in WINDOWS:
		var seconds: float = float(fields.get(window, 0.0))
		if seconds <= 0.0:
			return "attack %s's %s window is %.2f s; every window must be above zero" % [attack_name, window, seconds]  # not shown: a refusal for whoever edits the data, in its keys' English
	var as_action: Dictionary = {"name": attack_name, "weight": fields.get("weight", 1.0)}
	as_action["considerations"] = fields.get("considerations", [])
	return ActionChoice.why_not_actions([as_action])


# The phases in the order they are entered: the first at full health, each
# threshold below the one before, none at zero or under -- the boss is
# defeated there, so that phase would never be met.
static func _why_not_phases(data: Dictionary) -> String:
	var phases: Array = data["phases"]
	if phases.is_empty():
		return "a boss needs at least one phase"  # not shown: a refusal for whoever edits the data, in its keys' English
	var above: float = INF
	for index: int in range(phases.size()):
		var at_most: float = float(phases[index].get("health_at_most", 0.0))
		var phase_name: String = str(phases[index].get("name", index))
		if index == 0 and at_most < 1.0:
			return "the first phase, %s, must start at full health, 1.0" % phase_name  # not shown: a refusal for whoever edits the data, in its keys' English
		if at_most <= 0.0:
			return "phase %s opens at health %.2f, which is never met: the boss is defeated at 0" % [phase_name, at_most]  # not shown: a refusal for whoever edits the data, in its keys' English
		if at_most >= above:
			return "phase %s opens at %.2f, not below the phase before it" % [phase_name, at_most]  # not shown: a refusal for whoever edits the data, in its keys' English
		above = at_most
		var objection: String = _why_not_moveset(phases[index], data)
		if objection != "":
			return "phase %s: %s" % [phase_name, objection]  # not shown: a refusal for whoever edits the data, in its keys' English
	return ""


# A phase's own attacks: known, enough to choose between, and each shown for
# at least the minimum telegraph at this phase's speed.
static func _why_not_moveset(phase: Dictionary, data: Dictionary) -> String:
	var scale: float = float(phase.get("telegraph_scale", 1.0))
	if scale <= 0.0 or scale > 1.0:
		return "telegraph_scale %.2f is outside (0, 1]" % scale  # not shown: a refusal for whoever edits the data, in its keys' English
	var names: Array = phase.get("attacks", [])
	if names.size() < FEWEST_ATTACKS:
		return "%d attacks, fewer than %d to choose between" % [names.size(), FEWEST_ATTACKS]  # not shown: a refusal for whoever edits the data, in its keys' English
	var minimum: float = float(data["minimum_telegraph"])
	for attack_name: Variant in names:
		if not data["attacks"].has(attack_name):
			return "there is no attack called %s" % attack_name  # not shown: a refusal for whoever edits the data, in its keys' English
		var shown_for: float = float(data["attacks"][attack_name]["telegraph"]) * scale
		if shown_for < minimum:
			return "attack %s is telegraphed for %.2f s, under the minimum %.2f s" % [attack_name, shown_for, minimum]  # not shown: a refusal for whoever edits the data, in its keys' English
	return ""


static func _attack_from(attack_name: String, fields: Dictionary) -> Blow:
	var attack := Blow.new()
	attack.name = attack_name
	attack.kind = str(fields["kind"])
	attack.heavy = bool(fields.get("heavy", false))
	attack.weight = float(fields.get("weight", 1.0))
	attack.considerations = fields.get("considerations", [])
	attack.telegraph = float(fields["telegraph"])
	attack.active = float(fields["active"])
	attack.recovery = float(fields["recovery"])
	return attack


static func _phase_from(fields: Dictionary) -> Phase:
	var phase := Phase.new()
	phase.name = str(fields["name"])
	phase.health_at_most = float(fields["health_at_most"])
	phase.telegraph_scale = float(fields.get("telegraph_scale", 1.0))
	phase.summon = bool(fields.get("summon", false))
	phase.attacks = PackedStringArray(fields["attacks"])
	return phase
