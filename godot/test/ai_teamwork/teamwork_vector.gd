## One conformance vector of `spec/vectors/teamwork/`, answered by ai_teamwork.
##
## A vector is a query and the answer it must get; this builds the addon's
## own objects from the query, asks the technique, and compares every value
## with the file. The rules for what a vector is live here, so
## `teamwork_test.gd` can hand this broken vectors and watch it object.
class_name TeamworkVector
extends RefCounted

## Shared with `python/tests/test_teamwork_vectors.py`; sized for `Vector2`'s
## 32-bit floats.
const TOLERANCE: float = 1e-4
const KINDS: Array[String] = ["positions", "influence", "commander", "confidence", "aim", "passage", "action", "errands", "search", "roles"]


## Why `vector` is not a teamwork vector, or "" when it is one.
static func why_not_a_vector(vector: Dictionary) -> String:
	for key: String in ["name", "why", "kind", "query", "expect"]:
		if not vector.has(key):
			return "it has no %s" % key
	if not (str(vector["kind"]) in KINDS):
		return "its kind %s is none of %s" % [vector["kind"], KINDS]
	if not (vector["expect"] is Dictionary) or (vector["expect"] as Dictionary).is_empty():
		return "it expects nothing"
	return ""


## Every way this side's answer differs from the file's, one line each.
static func check(label: String, vector: Dictionary) -> Array[String]:
	var answer: Dictionary = answer_to(vector)
	var found: Array[String] = []
	differences(vector["expect"], answer, label, found)
	return found


## This side's answer to `vector`'s query.
static func answer_to(vector: Dictionary) -> Dictionary:
	match str(vector["kind"]):
		"positions":
			return _positions(vector)
		"influence":
			return _influence(vector)
		"commander":
			return _commander(vector)
		"aim":
			return _aim(vector)
		"passage":
			return _passage(vector)
		"action":
			return _action(vector)
		"errands":
			return _errands(vector)
		"search":
			return _search(vector)
		"roles":
			return _roles(vector)
	return _confidence(vector)


## Append to `found` every place `answer` differs from `expected`. Numbers
## agree within TOLERANCE; a whole number in JSON is a float in GDScript, so
## numbers are compared as numbers whatever their type.
static func differences(expected: Variant, answer: Variant, where: String, found: Array[String]) -> void:
	if expected is Dictionary:
		var keys_differ: bool = not (answer is Dictionary) or (answer as Dictionary).keys().size() != (expected as Dictionary).keys().size()
		if keys_differ:
			found.append("%s: %s, the file says %s" % [where, answer, expected])
			return
		for key: Variant in expected:
			differences(expected[key], (answer as Dictionary).get(key), "%s.%s" % [where, key], found)
	elif expected is Array:
		if not (answer is Array) or (answer as Array).size() != (expected as Array).size():
			found.append("%s: %s, the file says %s" % [where, answer, expected])
			return
		for index: int in range((expected as Array).size()):
			differences(expected[index], answer[index], "%s[%d]" % [where, index], found)
	elif expected == null:
		# A null in the file is "no bound" (a passage vector's INF): the
		# answer must be null too, not merely missing.
		if answer != null:
			found.append("%s: %s, the file says null" % [where, answer])
	elif _is_number(expected) and _is_number(answer):
		if absf(float(answer) - float(expected)) > TOLERANCE:
			found.append("%s: %s, the file says %s" % [where, answer, expected])
	elif str(answer) != str(expected) or typeof(answer) == TYPE_NIL:
		found.append("%s: %s, the file says %s" % [where, answer, expected])


static func _is_number(value: Variant) -> bool:
	return (value is float or value is int) and not (value is bool)


static func _vector2(pair: Array) -> Vector2:
	return Vector2(float(pair[0]), float(pair[1]))


static func _positions(vector: Dictionary) -> Dictionary:
	var query: Dictionary = vector["query"]
	var weights := TacticalPositions.Weights.new()
	for key: String in vector["weights"]:
		var value: Variant = vector["weights"][key]
		weights.set(key, value if value is bool else float(value))
	var candidates: Array[TacticalPositions.Candidate] = []
	for fields: Dictionary in query["candidates"]:
		var candidate := TacticalPositions.Candidate.new()
		for key: String in fields:
			candidate.set(key, fields[key])
		candidate.claimed_by = int(fields["claimed_by"])
		candidates.append(candidate)
	var choice: TacticalPositions.Choice = TacticalPositions.choose(int(query["bot"]), candidates,
			weights, bool(query["has_threat"]), bool(query["use_claims"]))
	return {"statuses": choice.statuses, "scores": Array(choice.scores), "chosen": choice.chosen}


static func _influence(vector: Dictionary) -> Dictionary:
	var shape: Dictionary = vector["map"]
	var grid := TeamInfluence.new(int(shape["width"]), int(shape["height"]), float(shape["cell_size"]),
			_vector2(shape["origin"]), float(shape["radius"]))
	for source: Dictionary in vector["query"]["sources"]:
		grid.add_source(_vector2(source["place"]), float(source["strength"]))
	var values: Array = []
	for place: Array in vector["query"]["asked"]:
		values.append(grid.value_at(_vector2(place)))
	return {"values": values}


static func _commander(vector: Dictionary) -> Dictionary:
	var weights := TeamCommander.Weights.new()
	for key: String in vector["weights"]:
		weights.set(key, float(vector["weights"][key]))
	var squads: Array[TeamCommander.SquadReport] = []
	for fields: Dictionary in vector["query"]["squads"]:
		var squad := TeamCommander.SquadReport.new()
		squad.id = str(fields["id"])
		squad.position = _vector2(fields["position"])
		squad.size = int(fields["size"])
		squads.append(squad)
	var objectives: Array[TeamCommander.Objective] = []
	for fields: Dictionary in vector["query"]["objectives"]:
		objectives.append(_objective(fields))
	return {"priorities": Array(TeamCommander.priorities(objectives, weights)),
			"assigned": TeamCommander.assign(squads, objectives, weights),
			"nearest": TeamCommander.nearest(squads, objectives)}


static func _objective(fields: Dictionary) -> TeamCommander.Objective:
	var objective := TeamCommander.Objective.new()
	objective.id = str(fields["id"])
	objective.position = _vector2(fields["position"])
	objective.held_by = int(fields["held_by"])
	objective.ideal = int(fields["ideal"])
	objective.influence = float(fields["influence"])
	return objective


static func _confidence(vector: Dictionary) -> Dictionary:
	var thresholds := SquadConfidence.Thresholds.new()
	for key: String in vector["thresholds"]:
		thresholds.set(key, float(vector["thresholds"][key]))
	var values: Array = []
	for fields: Dictionary in vector["query"]["facts"]:
		var facts := SquadConfidence.Facts.new()
		facts.friendly_strength = float(fields["friendly_strength"])
		facts.enemy_strength = float(fields["enemy_strength"])
		facts.kills = int(fields["kills"])
		facts.losses = int(fields["losses"])
		values.append(SquadConfidence.confidence(facts, thresholds))
	var answer: Dictionary = {"values": values,
			"states_with_retreat": _states(values, thresholds, true),
			"states_without_retreat": _states(values, thresholds, false)}
	answer["waves"] = _waves(vector["query"]["members"], vector["query"]["phases"])
	return answer


static func _aim(vector: Dictionary) -> Dictionary:
	var zones: Array[AimChoice.Zone] = []
	for fields: Dictionary in vector["query"]["zones"]:
		var zone := AimChoice.Zone.new()
		zone.name = str(fields["name"])
		zone.multiplier = float(fields["multiplier"])
		zone.aim = _vector2(fields["aim"])
		zone.exposure = float(fields["exposure"])
		for corners: Array in fields["rects"]:
			var low := Vector2(float(corners[0]), float(corners[1]))
			zone.rects.append(Rect2(low, Vector2(float(corners[2]), float(corners[3])) - low))
		zones.append(zone)
	var choice: AimChoice.Choice = AimChoice.choose(zones, float(vector["query"]["spread"]))
	var landed: Array = []
	for roll: Variant in vector["query"]["rolls"]:
		landed.append(AimChoice.land(choice.chances, float(roll)))
	return {"own_chances": Array(choice.own_chances), "expected": Array(choice.expected), "aimed": choice.aimed,
			"chances": Array(choice.chances), "landed": landed}


# JSON's null, for no bound, as INF; and INF back as null.
static func _bounded(value: Variant) -> float:
	return INF if value == null else float(value)


static func _nulled(value: float) -> Variant:
	return null if is_inf(value) else value


static func _passage(vector: Dictionary) -> Dictionary:
	var costs: Array = []
	var chosen: Array = []
	for fields: Dictionary in vector["query"]["facts"]:
		var facts := PassageChoice.Facts.new()
		for key: String in fields:
			facts.set(key, _bounded(fields[key]) if key in ["detour_metres", "spot_loss"] else fields[key])
		var choice: PassageChoice.Choice = PassageChoice.choose(facts)
		costs.append(Array(choice.costs).map(_nulled))
		chosen.append(choice.chosen)
	var prices := PassageChoice.Prices.new()
	for key: String in vector["prices"]:
		prices.set(key, float(vector["prices"][key]))
	var answers: Array = []
	for fields: Dictionary in vector["query"]["requests"]:
		var request := PassageChoice.Request.new()
		for key: String in fields:
			request.set(key, _bounded(fields[key]) if key == "saves" else fields[key])
		var reply: PassageChoice.Answer = PassageChoice.answer(request, prices)
		answers.append({"cost": _nulled(reply.cost), "granted": reply.granted})
	return {"costs": costs, "chosen": chosen, "answers": answers}


static func _action(vector: Dictionary) -> Dictionary:
	var actions: Array[ActionChoice.Action] = ActionChoice.actions_from(vector["query"]["actions"])
	var scores: Array = []
	var answers: Array = []
	var chosen: Array = []
	for percepts: Dictionary in vector["query"]["percepts"]:
		var choice: ActionChoice.Choice = ActionChoice.choose(actions, percepts)
		scores.append(Array(choice.scores))
		answers.append(choice.answers.map(func(found: PackedFloat64Array) -> Array: return Array(found)))
		chosen.append(choice.chosen)
	return {"scores": scores, "answers": answers, "chosen": chosen}


static func _search(vector: Dictionary) -> Dictionary:
	var weights := SearchCoordinator.Weights.new()
	weights.worth = float(vector["weights"]["worth"])
	weights.travel = float(vector["weights"]["travel"])
	var query: Dictionary = vector["query"]
	var spots: Array[Dictionary] = []
	for spot: Dictionary in query["spots"]:
		spots.append(spot)
	var costs: Array[PackedFloat64Array] = []
	for row: Array in query["costs"]:
		costs.append(PackedFloat64Array(row))
	var assigned: PackedInt32Array = SearchCoordinator.assign(spots, costs, bool(query["use_claims"]), weights)
	var granted: PackedInt32Array = SearchCoordinator.grant_last_known(PackedFloat64Array(query["last_known"]), int(query["cap"]))
	return {"assigned": Array(assigned), "granted": Array(granted)}


static func _roles(vector: Dictionary) -> Dictionary:
	var query: Dictionary = vector["query"]
	var requests: Array[Dictionary] = []
	for request: Dictionary in query["requests"]:
		requests.append(request)
	return {"granted": Array(RoleArbiter.grant(requests, bool(query["use_arbiter"]), int(query["max_flankers"])))}


static func _errands(vector: Dictionary) -> Dictionary:
	var weights := ErrandChoice.Weights.new()
	for key: String in vector["weights"]:
		weights.set(key, float(vector["weights"][key]))
	var query: Dictionary = vector["query"]
	var back: Array = []
	for fields: Dictionary in query["resupply"]:
		var facts := ErrandChoice.Resupply.new()
		for key: String in fields:
			facts.set(key, fields[key])
		back.append(Array(ErrandChoice.weigh_resupply(facts, weights)))
	var out: Array = []
	for fields: Dictionary in query["fetch"]:
		var facts := ErrandChoice.Fetch.new()
		for key: String in fields:
			facts.set(key, int(fields[key]) if key == "enemies_near" else fields[key])
		out.append(Array(ErrandChoice.weigh_fetch(facts, weights)))
	var hidden: Array = []
	for fields: Dictionary in query["hide"]:
		var facts := ErrandChoice.Hide.new()
		for key: String in fields:
			facts.set(key, fields[key])
		hidden.append(Array(ErrandChoice.weigh_hide(facts, weights)))
	var falling: Array = _fall_backs(query["fall_back"], weights)
	var sent: Array = (query["teams"] as Array).map(func(scores: Array) -> int:
		return ErrandChoice.fetcher(PackedFloat64Array(scores)))
	var chosen: Array = (query["pairs"] as Array).map(func(pair: Array) -> String: return _chosen(pair))
	return {"resupply": back, "fetch": out, "hide": hidden, "fall_back": falling, "fetcher": sent, "chosen": chosen}


# Each falling back's weighing, from its facts (T65).
static func _fall_backs(rows: Array, weights: ErrandChoice.Weights) -> Array:
	var falling: Array = []
	for fields: Dictionary in rows:
		var facts := ErrandChoice.FallBack.new()
		for key: String in fields:
			facts.set(key, fields[key])
		falling.append(Array(ErrandChoice.weigh_fall_back(facts, weights)))
	return falling


# A pair is [back, fetch], or [back, fetch, hide], or with fall back too:
# the errand its scores choose.
static func _chosen(pair: Array) -> String:
	var scores: Array = pair.duplicate()
	scores.resize(4)
	return ErrandChoice.choose(float(scores[0]), float(scores[1]), float(scores[2] if scores[2] != null else 0.0),
			float(scores[3] if scores[3] != null else 0.0))


static func _states(values: Array, thresholds: SquadConfidence.Thresholds, may_retreat: bool) -> Array:
	var state: String = SquadConfidence.HOLD
	var states: Array = []
	for value: float in values:
		state = SquadConfidence.next_state(state, value, thresholds, may_retreat)
		states.append(state)
	return states


static func _waves(listed: Array, phases: Array) -> Array:
	var members: Array[int] = []
	for member: Variant in listed:
		members.append(int(member))
	var result: Array = []
	for phase: Variant in phases:
		var split: SquadConfidence.Waves = SquadConfidence.waves(members, int(phase))
		result.append({"phase": int(phase), "moving": Array(split.moving), "covering": Array(split.covering)})
	return result
