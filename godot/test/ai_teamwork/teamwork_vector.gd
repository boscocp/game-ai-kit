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
const KINDS: Array[String] = ["positions", "influence", "commander", "confidence", "passage", "search", "roles", "tokens", "rings"]
## The types each kind reads, beside the keys every vector has, checked
## before anything reads them (T121): a cast that fails in a `-s` script is
## a SCRIPT ERROR the run survives. `expect` is left to `differences`, which
## compares any value without casting it.
const SHAPES: Dictionary = {
	"rings": {
		"query": {"config": {"rings": [{"name": VectorShape.TEXT, "radius": VectorShape.NUMBER,
				"count": VectorShape.NUMBER, "phase": VectorShape.NUMBER}], "spacing": VectorShape.NUMBER,
				"weights": {"partial_cover": VectorShape.NUMBER, "line_of_fire": VectorShape.NUMBER,
				"other_cover": VectorShape.NUMBER, "nearness": VectorShape.NUMBER,
				"preferred_range": VectorShape.NUMBER, "preferred_metres": VectorShape.NUMBER,
				"range_band": VectorShape.NUMBER, "max_travel": VectorShape.NUMBER}},
				"target": [VectorShape.NUMBER], "view_from": [VectorShape.NUMBER],
				"view_forward": [VectorShape.NUMBER], "blocked": [VectorShape.TEXT],
				"script": [{"do": VectorShape.TEXT, "id?": VectorShape.NUMBER, "ring?": VectorShape.TEXT,
				"from?": [VectorShape.NUMBER], "holds_token?": VectorShape.FLAG, "ranged?": VectorShape.FLAG,
				"target?": [VectorShape.NUMBER]}]},
	},
	"tokens": {
		"query": {"config": {"pools": {"melee": VectorShape.NUMBER, "ranged": VectorShape.NUMBER},
				"delays": {"melee": VectorShape.NUMBER, "ranged": VectorShape.NUMBER},
				"timeouts": {"melee": VectorShape.NUMBER, "ranged": VectorShape.NUMBER},
				"multipliers": {"busy": {"melee": VectorShape.NUMBER, "ranged": VectorShape.NUMBER},
				"idle": {"melee": VectorShape.NUMBER, "ranged": VectorShape.NUMBER}},
				"patience": VectorShape.NUMBER, "tie_seed": VectorShape.NUMBER},
				"script": [{"do": VectorShape.TEXT, "at": VectorShape.NUMBER, "id?": VectorShape.TEXT,
				"kind?": VectorShape.TEXT, "cost?": VectorShape.NUMBER, "priority?": VectorShape.NUMBER,
				"distance?": VectorShape.NUMBER, "state?": VectorShape.TEXT, "reason?": VectorShape.TEXT}]},
	},
	"confidence": {
		"thresholds": {"attack_at": VectorShape.NUMBER, "keep_attacking_at": VectorShape.NUMBER,
				"retreat_at": VectorShape.NUMBER, "recover_at": VectorShape.NUMBER,
				"per_kill": VectorShape.NUMBER, "per_loss": VectorShape.NUMBER,
				"least_enemy": VectorShape.NUMBER},
		"query": {"facts": [{"friendly_strength": VectorShape.NUMBER, "enemy_strength": VectorShape.NUMBER,
				"kills": VectorShape.NUMBER, "losses": VectorShape.NUMBER}], "members": [VectorShape.NUMBER],
				"phases": [VectorShape.NUMBER]},
	},
	"passage": {
		"prices": {"step_seconds": VectorShape.NUMBER, "per_enemy_seen": VectorShape.NUMBER,
				"shooting": VectorShape.NUMBER, "reloading": VectorShape.NUMBER,
				"covering_a_retreat": VectorShape.NUMBER},
		"query": {"facts": [{"gap": VectorShape.NUMBER, "leaving_speed": VectorShape.NUMBER,
				"detour_metres": VectorShape.NUMBER_OR_NULL, "speed": VectorShape.NUMBER,
				"teammate": VectorShape.FLAG, "refused": VectorShape.FLAG, "ask_seconds": VectorShape.NUMBER,
				"spot_loss": VectorShape.NUMBER_OR_NULL, "points_a_second": VectorShape.NUMBER}],
				"requests": [{"saves": VectorShape.NUMBER_OR_NULL, "enemies_in_sight": VectorShape.NUMBER,
				"shooting": VectorShape.FLAG, "reloading": VectorShape.FLAG,
				"covering_a_retreat": VectorShape.FLAG, "driven_by_a_person": VectorShape.FLAG,
				"room_to_step": VectorShape.FLAG}]},
	},
	"influence": {
		"map": {"width": VectorShape.NUMBER, "height": VectorShape.NUMBER, "cell_size": VectorShape.NUMBER,
				"origin": [VectorShape.NUMBER], "radius": VectorShape.NUMBER},
		"query": {"sources": [{"place": [VectorShape.NUMBER], "strength": VectorShape.NUMBER}],
				"asked": [[VectorShape.NUMBER]]},
	},
	"commander": {
		"weights": {"take": VectorShape.NUMBER, "hold": VectorShape.NUMBER, "defend": VectorShape.NUMBER,
				"nearest_metres": VectorShape.NUMBER},
		"query": {"squads": [{"id": VectorShape.TEXT, "position": [VectorShape.NUMBER],
				"size": VectorShape.NUMBER}], "objectives": [{"id": VectorShape.TEXT,
				"position": [VectorShape.NUMBER], "held_by": VectorShape.NUMBER, "ideal": VectorShape.NUMBER,
				"influence": VectorShape.NUMBER}]},
	},
	"search": {
		"weights": {"worth": VectorShape.NUMBER, "travel": VectorShape.NUMBER},
		"query": {"spots": [{"worth": VectorShape.NUMBER, "searched": VectorShape.FLAG}],
				"costs": [[VectorShape.NUMBER]], "use_claims": VectorShape.FLAG, "cap": VectorShape.NUMBER,
				"last_known": [VectorShape.NUMBER]},
	},
	"positions": {
		"weights": {"partial_cover": VectorShape.NUMBER, "line_of_fire": VectorShape.NUMBER,
				"other_cover": VectorShape.NUMBER, "nearness": VectorShape.NUMBER,
				"preferred_range": VectorShape.NUMBER, "preferred_metres": VectorShape.NUMBER,
				"range_band": VectorShape.NUMBER, "max_travel": VectorShape.NUMBER,
				"cover_from_all?": VectorShape.FLAG},
		"query": {"bot": VectorShape.NUMBER, "has_threat": VectorShape.FLAG, "use_claims": VectorShape.FLAG,
				"candidates": [{"id": VectorShape.TEXT, "travel": VectorShape.NUMBER,
				"threat_distance": VectorShape.NUMBER, "covered_from_main": VectorShape.FLAG,
				"fires_on_main": VectorShape.FLAG, "covered_from_others": VectorShape.NUMBER,
				"in_area": VectorShape.FLAG, "claimed_by": VectorShape.NUMBER,
				"hidden_from_all": VectorShape.FLAG}]},
	},
	"roles": {
		"query": {"requests": [{"role": VectorShape.TEXT, "score": VectorShape.NUMBER,
				"can_shoot": VectorShape.FLAG}], "use_arbiter": VectorShape.FLAG,
				"max_flankers": VectorShape.NUMBER},
	},
}


## Why `vector` is not a teamwork vector, or "" when it is one.
static func why_not_a_vector(vector: Dictionary) -> String:
	for key: String in ["name", "why", "kind", "query", "expect"]:
		if not vector.has(key):
			return "it has no %s" % key
	if not (str(vector["kind"]) in KINDS):
		return "its kind %s is none of %s" % [vector["kind"], KINDS]
	var types: String = VectorShape.why_not(vector, SHAPES[str(vector["kind"])])
	if types != "":
		return types
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
		"passage":
			return _passage(vector)
		"search":
			return _search(vector)
		"roles":
			return _roles(vector)
		"tokens":
			return _tokens(vector)
		"rings":
			return _rings(vector)
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


## An `AttackTokens.Config` from a vector's `config`: JSON's numbers are
## floats, the pools are whole tokens.
static func tokens_config(fields: Dictionary) -> AttackTokens.Config:
	var config := AttackTokens.Config.new()
	for kind: String in fields["pools"]:
		config.pools[kind] = int(fields["pools"][kind])
	for kind: String in fields["delays"]:
		config.delays[kind] = float(fields["delays"][kind])
	for kind: String in fields["timeouts"]:
		config.timeouts[kind] = float(fields["timeouts"][kind])
	for state: String in fields["multipliers"]:
		config.multipliers[state] = fields["multipliers"][state]
	config.patience = int(fields["patience"])
	config.tie_seed = int(fields["tie_seed"])
	return config


static func _tokens(vector: Dictionary) -> Dictionary:
	var config: AttackTokens.Config = tokens_config(vector["query"]["config"])
	var pool := AttackTokens.new(config)
	var answers: Array = []
	for event: Dictionary in vector["query"]["script"]:
		answers.append(_play_tokens(pool, config, event))
	var events: Array = []
	for each: Dictionary in pool.events:
		events.append([each["at"], each["id"], each["kind"], each["what"]])
	return {"answers": answers, "events": events}


static func _play_tokens(pool: AttackTokens, config: AttackTokens.Config, event: Dictionary) -> Variant:
	var now: float = float(event["at"])
	var action: String = str(event["do"])
	if action == "request":
		var cost: int = int(event["cost"])
		var priority: int = int(event["priority"])
		return pool.request(str(event["id"]), str(event["kind"]), cost, priority, float(event["distance"]), now)
	if action == "release":
		return pool.release(str(event["id"]), str(event["reason"]), now)
	if action == "withdraw":
		return pool.withdraw(str(event["id"]), now)
	if action == "revoke":
		return Array(pool.revoke_kind(str(event["kind"]), now))
	var granted: PackedStringArray = pool.step(now, str(event["state"]))
	var free: Dictionary = {}
	var holders: Dictionary = {}
	for kind: String in config.pools:
		free[kind] = pool.free_tokens(kind)
		holders[kind] = Array(pool.holders(kind))
	return {"granted": Array(granted), "free": free, "holders": holders}


## An `EngagementRings.Config` from a vector's `config`.
static func rings_config(fields: Dictionary) -> EngagementRings.Config:
	var config := EngagementRings.Config.new()
	for ring_fields: Dictionary in fields["rings"]:
		var ring := EngagementRings.Ring.new()
		ring.name = str(ring_fields["name"])
		ring.radius = float(ring_fields["radius"])
		ring.count = int(ring_fields["count"])
		ring.phase = float(ring_fields["phase"])
		config.rings.append(ring)
	config.spacing = float(fields["spacing"])
	for key: String in fields["weights"]:
		config.weights.set(key, float(fields["weights"][key]))
	return config


static func _rings(vector: Dictionary) -> Dictionary:
	var query: Dictionary = vector["query"]
	var field := EngagementRings.new(rings_config(query["config"]), _vector2(query["target"]))
	for point: EngagementRings.Point in field.points:
		point.line_of_sight = not (point.id in query["blocked"])
	var answers: Array = []
	for event: Dictionary in query["script"]:
		answers.append(_play_rings(field, query, event))
	var points: Array = []
	var claims: Dictionary = {}
	for point: EngagementRings.Point in field.points:
		points.append([point.position.x, point.position.y])
		if point.claimed_by != -1:
			claims[point.id] = point.claimed_by
	return {"points": points, "answers": answers, "claims": claims}


static func _play_rings(field: EngagementRings, query: Dictionary, event: Dictionary) -> Variant:
	if event["do"] == "place":
		field.place(_vector2(event["target"]))
		return null
	if event["do"] == "release":
		return field.release(int(event["id"]))
	if event["do"] == "ring_for":
		return EngagementRings.ring_for(bool(event["holds_token"]), bool(event["ranged"]))
	var chosen: int = field.choose(int(event["id"]), str(event["ring"]), _vector2(event["from"]),
			_vector2(query["view_from"]), _vector2(query["view_forward"]))
	return {"point": field.points[chosen].id if chosen != -1 else "", "statuses": field.last_choice.statuses,
			"behind": field.last_behind.duplicate(), "bumped": field.last_bumped.duplicate()}


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
