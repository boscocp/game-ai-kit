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
## did to the belief (`BayesNetwork.influence`), the *lead* -- the sign seen
## that raised it most, where a guard checking the evidence walks -- and
## the last change: which sign, and the belief before and after. The view
## draws exactly what was asked, and marks the lead it acts on (invariant
## 13). `strongest`, the largest change either way, can be a sign *not*
## seen -- "no noise" lowering the belief -- so it is kept, not acted on.
##
## A sign is let go when the guard has walked to where it was and found
## nothing there (`settled_within`), or when it is too old. Being there is
## enough, whichever way the guard faces: a guard's eyes cover its walk,
## and turning to look is the action's, not the evidence's. So a door left
## open raises the belief, the guard goes to look, shuts it, and the belief
## falls again. The tables are data, read once; nothing here changes them
## (invariant 6).
##
## A crowded level adds one sign of another shape (T152): the `figure` the
## guard's eye picked out of a group, which either blends in or stands out
## (`InfiltrationCrowd`). It is held as the others are, with its value, and
## left out of the evidence -- summed over, so it changes nothing -- while
## the guard has not picked anyone out, which on every other level is
## always. Walking in step lowers the belief; sprinting or crouching in a
## crowd raises it. The guard's sight and hearing are weighed by the crowd
## in its percept (`InfiltrationCrowd.weigh`), as the task asked; here the
## network is given that reading as evidence, so it can say why.
##
## Asked again only when what is seen changes: three signs and the figure,
## so at most 2^3 * 3 answers a guard, each a sum over the hidden variables.
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
## Each sign the guard holds, by variable: when it was last noticed, and
## where; the figure also its value.
var held: Dictionary[String, Dictionary] = {}
## P(intruder = yes | what is seen), and each hidden variable's chance of
## its first value.
var belief: float = 0.0
var chances: Dictionary = {}
## What each sign did to the belief, the one that moved it most, and the
## last change: {"by", "seen", "from", "to", "at"}; {} before any.
var moved: Dictionary = {}
var strongest: String = ""
## The sign seen that raised the belief most -- the one acted on; "" none.
var lead: String = ""
var last_change: Dictionary = {}
## The evidence the belief was last asked from, each sign yes or no: what
## the view draws, so the numbers and the signs beside them always agree.
var asked: Dictionary = {}


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
	if guard.percept.figure != "":
		notice_figure(guard.percept.figure, guard.percept.seen_place, world.time)
	reconsider(world.time)


## Hold the figure the eye picked out of a crowd at `place`, `now`, with its
## reading `value` -- blends in or stands out; ignored when the file has no
## crowd sign.
func notice_figure(value: String, place: Vector2, now: float) -> void:
	if spec.has("crowd"):
		held[str(spec["crowd"]["variable"])] = {"at": now, "place": place, "value": value}


## Count an event of `kind` at `place`, noticed `now`, as the sign it is one
## of; an event no sign names is not evidence and is ignored.
func notice_kind(kind: String, place: Vector2, now: float) -> void:
	for variable: String in spec["evidence"]:
		if (spec["evidence"][variable]["kinds"] as Array).has(kind):
			held[variable] = {"at": now, "place": place}


## What the guard has seen, `now`: each sign yes while it is held and young
## enough, no otherwise -- every sign is evidence, either way. The figure is
## evidence only while it is held and young enough, with its value.
func seen(now: float) -> Dictionary:
	var found: Dictionary = {}
	for variable: String in spec["evidence"]:
		found[variable] = SEEN if _fresh(variable, now) else NOT_SEEN
	if spec.has("crowd") and _fresh(str(spec["crowd"]["variable"]), now):
		found[spec["crowd"]["variable"]] = held[spec["crowd"]["variable"]]["value"]
	return found


# True while `variable` is held and noticed no longer ago than it is kept.
func _fresh(variable: String, now: float) -> bool:
	return held.has(variable) and now - float(held[variable]["at"]) <= kept_for(variable)


## How many seconds a sign of `variable` is kept: its own `remember_for`,
## or the crowd sign's.
func kept_for(variable: String) -> float:
	if spec["evidence"].has(variable):
		return float(spec["evidence"][variable]["remember_for"])
	return float(spec["crowd"]["remember_for"])


## Where the lead was noticed: where a guard checking the evidence walks.
## INF when no sign seen raised the belief.
func lead_place() -> Vector2:
	return held[lead]["place"] if lead != "" and held.has(lead) else Vector2.INF


# The sign seen in `evidence` whose influence in `moved` is the largest
# rise; "" when none rose it. The first of equal ones. A figure counts as
# seen whichever its value: one that stands out raises the belief.
static func _lead_of(evidence: Dictionary, moved_by: Dictionary) -> String:
	var best: String = ""
	for variable: String in moved_by:
		var rose: bool = evidence.get(variable, NOT_SEEN) != NOT_SEEN and float(moved_by[variable]) > 0.0
		if rose and (best == "" or float(moved_by[variable]) > float(moved_by[best])):
			best = variable
	return best


# Let go of every sign noticed before `now` within `settled_within` of
# `position` -- the guard is where it was and finds nothing new -- and every
# sign older than it is kept for.
func _settle(position: Vector2, now: float) -> void:
	for variable: String in held.keys():
		var sign_held: Dictionary = held[variable]
		var looked: bool = float(sign_held["at"]) < now and position.distance_to(sign_held["place"]) <= float(spec["settled_within"])
		var old: bool = now - float(sign_held["at"]) > kept_for(variable)
		if looked or old:
			held.erase(variable)


## Ask the network again, `now`, when what is seen changed since the last
## time: the belief, each hidden chance, each sign's influence, the
## strongest, the lead, and the last change.
func reconsider(now: float) -> void:
	var evidence: Dictionary = seen(now)
	if evidence == asked and not chances.is_empty():
		return
	var query: String = spec["query"]
	var suspected: int = network.values[query].find(str(spec["suspected"]))
	var before: float = belief
	belief = network.ask(query, evidence)[suspected]
	moved = network.influence(query, str(spec["suspected"]), evidence)
	strongest = BayesNetwork.most_moved(moved)
	lead = _lead_of(evidence, moved)
	for variable: String in network.names:
		if not evidence.has(variable):
			chances[variable] = belief if variable == query else network.ask(variable, evidence)[0]
	_note_change(evidence, before, now)
	asked = evidence


# The last change, when a sign in `evidence` reads otherwise than when last
# asked: a yes/no sign turned, or the figure picked out, read otherwise or
# let go ("" -- no longer evidence). The first question has none.
func _note_change(evidence: Dictionary, before: float, now: float) -> void:
	if asked.is_empty():
		return
	var variables: Array = evidence.keys()
	for variable: String in asked:
		if not variables.has(variable):
			variables.append(variable)
	for variable: String in variables:
		if asked.get(variable, "") != evidence.get(variable, ""):
			last_change = {"by": variable, "seen": evidence.get(variable, ""), "from": before, "to": belief, "at": now}


static func _read_shared() -> void:
	if _shared_network != null:
		return
	_shared_spec = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	_shared_network = BayesNetwork.new(_shared_spec)
	if _shared_network.problem() != "":
		push_error("%s: %s" % [FILE, _shared_network.problem()])
