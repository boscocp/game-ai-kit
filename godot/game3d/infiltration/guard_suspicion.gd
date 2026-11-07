## Whether one infiltration guard believes anyone is there at all, and
## why: its evidence -- a noise, a door it found open, a partner gone quiet
## -- asked of `ai_bayes`'s network (T115).
##
## `ai_perception` already says *where* the player may be; this answers the
## question before it, from signs a guard can explain. Each sign is a
## variable of `intruder_network.json`, seen yes while the guard keeps it in
## mind (its `remember_for`) and no otherwise, and the network gives
## P(intruder | everything seen). Every time what is seen changes, it is
## asked again: the belief, each hidden variable's chance, what each sign
## did to the belief (`BayesNetwork.influence`), the sign that moved it most,
## and the last change -- which sign, and the belief before and after. That
## is what the view draws (invariant 13).
##
## A sign is let go when the guard has walked to where it was and found
## nothing there (`settled_within`), or when it is too old. So a door left
## open raises the belief, the guard goes to look, shuts it, and the belief
## falls again. The tables are data, read once; nothing here changes them
## (invariant 6).
##
## Asked again only when what is seen changes: three signs, so at most
## 2^3 answers a guard, each a sum over two hidden variables.
##
## When not to use it: to say where to look. The belief map does that.
class_name GuardSuspicion
extends RefCounted

const FILE: String = "res://game3d/infiltration/intruder_network.json"
const SEEN: String = "yes"  # not shown: a value of the network's data
const NOT_SEEN: String = "no"  # not shown: a value of the network's data

static var _shared_network: BayesNetwork
static var _shared_spec: Dictionary = {}

var network: BayesNetwork
## The data file: the query, the value suspected, each sign's kinds and how
## long it is kept, and how near counts as having looked.
var spec: Dictionary = {}
## Each sign the guard holds, by variable: when it was last noticed, and where.
var held: Dictionary[String, Dictionary] = {}
## P(intruder = yes | what is seen), and each hidden variable's chance of
## its first value.
var belief: float = 0.0
var chances: Dictionary = {}
## What each sign did to the belief, the one that moved it most, and the
## last change: {"by", "seen", "from", "to", "at"}; {} before any.
var moved: Dictionary = {}
var strongest: String = ""
var last_change: Dictionary = {}
var _asked: Dictionary = {}


## A guard's suspicion over `with_network` and its `with_spec`; the
## infiltration's own file when none is given.
func _init(with_network: BayesNetwork = null, with_spec: Dictionary = {}) -> void:
	if with_network == null:
		_read_shared()
		with_network = _shared_network
		with_spec = _shared_spec
	network = with_network
	spec = with_spec
	reconsider(0.0)


## One step: let go of the signs looked into or too old, take this step's
## signs from what `guard` perceived in `world`, and ask again if they changed.
func sense(guard: InfiltrationGuard, world: InfiltrationWorld) -> void:
	_settle(guard.position, world.time)
	if guard.percept.loudness > 0.0:
		notice_kind(guard.percept.heard_kind, guard.percept.heard_place, world.time)
	if guard.quiet_place != Vector2.INF:
		notice_kind("partner_quiet", guard.quiet_place, world.time)  # not shown: an identifier
	for index: int in range(world.level.doors.size()):
		var place: Vector2 = world.level.doors[index]["place"]
		if world.doors_open[index] and GuardEyes.sees_door(guard, world.level, world.rules, place):
			notice_kind("open_door", place, world.time)  # not shown: an identifier
	reconsider(world.time)


## Count an event of `kind` at `place`, noticed `now`, as the sign it is one
## of; an event no sign names is not evidence and is ignored.
func notice_kind(kind: String, place: Vector2, now: float) -> void:
	for variable: String in spec["evidence"]:
		if (spec["evidence"][variable]["kinds"] as Array).has(kind):
			held[variable] = {"at": now, "place": place}


## What the guard has seen, `now`: each sign yes while it is held and young
## enough, no otherwise -- every sign is evidence, either way.
func seen(now: float) -> Dictionary:
	var found: Dictionary = {}
	for variable: String in spec["evidence"]:
		var fresh: bool = held.has(variable) and now - float(held[variable]["at"]) <= float(spec["evidence"][variable]["remember_for"])
		found[variable] = SEEN if fresh else NOT_SEEN
	return found


## Where the sign that raised the belief most was noticed: where a guard
## checking the evidence walks. INF when no sign seen raised it.
func lead_place() -> Vector2:
	var best: String = ""
	for variable: String in moved:
		if held.has(variable) and float(moved[variable]) > 0.0 and (best == "" or float(moved[variable]) > float(moved[best])):
			best = variable
	return held[best]["place"] if best != "" else Vector2.INF


# Let go of every sign noticed before `now` within `settled_within` of
# `position` -- the guard is where it was and finds nothing new -- and every
# sign older than it is kept for.
func _settle(position: Vector2, now: float) -> void:
	for variable: String in held.keys():
		var sign_held: Dictionary = held[variable]
		var looked: bool = float(sign_held["at"]) < now and position.distance_to(sign_held["place"]) <= float(spec["settled_within"])
		var old: bool = now - float(sign_held["at"]) > float(spec["evidence"][variable]["remember_for"])
		if looked or old:
			held.erase(variable)


## Ask the network again, `now`, when what is seen changed since the last
## time: the belief, each hidden chance, each sign's influence, the
## strongest, and the last change.
func reconsider(now: float) -> void:
	var evidence: Dictionary = seen(now)
	if evidence == _asked and not chances.is_empty():
		return
	var query: String = spec["query"]
	var suspected: int = network.values[query].find(str(spec["suspected"]))
	var before: float = belief
	belief = network.ask(query, evidence)[suspected]
	moved = network.influence(query, str(spec["suspected"]), evidence)
	strongest = BayesNetwork.most_moved(moved)
	for variable: String in network.names:
		if not evidence.has(variable):
			chances[variable] = belief if variable == query else network.ask(variable, evidence)[0]
	for variable: String in evidence:
		if _asked.has(variable) and _asked[variable] != evidence[variable]:
			last_change = {"by": variable, "seen": evidence[variable], "from": before, "to": belief, "at": now}
	_asked = evidence


static func _read_shared() -> void:
	if _shared_network != null:
		return
	_shared_spec = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	_shared_network = BayesNetwork.new(_shared_spec)
	if _shared_network.problem() != "":
		push_error("%s: %s" % [FILE, _shared_network.problem()])
