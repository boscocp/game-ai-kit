## The guard's deeds as a planner sees them: what each needs, what it makes
## true, and what it costs -- shared by the GOAP and HTN brains, so the two
## plan over one description and differ only in how they search it.
##
## When not to use it: as the deeds' meaning on the board. Where a deed walks
## is `GuardBrain`'s; this is only what a planner may assume of it.
class_name GuardActions
extends RefCounted


## The deeds as GOAP actions, every one costing 1.
static func goap() -> Array[GoapAction]:
	var actions: Array[GoapAction] = []
	for row: Array in _deeds():
		actions.append(GoapAction.new(row[0], 1, row[1], row[2]))
	return actions


## The deeds as the HTN's primitive tasks, and the one compound task, "guard",
## with its five methods in the order a designer would rank them.
static func htn() -> HtnDomain:
	var domain := HtnDomain.new()
	for row: Array in _deeds():
		domain.add_primitive(row[0], row[1], row[2])
	domain.add_method("guard", "seize them", {"alerted": true, "next_to_player": true}, [GuardBrain.CATCH] as Array[String])  # shown through tr()
	domain.add_method("guard", "chase them", {"alerted": true, "sees_player": true}, [GuardBrain.CHASE, GuardBrain.CATCH] as Array[String])  # shown through tr()
	# Without this one the HTN walked to where it already stood: it knows only
	# the orders its methods write, and "go, then look" was the only one.
	domain.add_method("guard", "look here", {"suspicious": true, "at_last_known": true, "area_checked": false},  # shown through tr()
		[GuardBrain.LOOK_AROUND] as Array[String])
	domain.add_method("guard", "go and look", {"suspicious": true, "knows_where": true, "area_checked": false},  # shown through tr()
		[GuardBrain.GO_TO_LAST_KNOWN, GuardBrain.LOOK_AROUND] as Array[String])
	domain.add_method("guard", "walk the round", {}, [GuardBrain.WALK_ROUND] as Array[String])  # shown through tr()
	return domain


## The goal the guard is after on these facts, most pressing first -- what a
## GOAP agent chooses before it plans.
static func goal(facts: Dictionary) -> Dictionary:
	if facts["alerted"] and (facts["sees_player"] or facts["next_to_player"]):
		return {"player_caught": true}
	if (facts["suspicious"] or facts["alerted"]) and facts["knows_where"] and not facts["area_checked"]:
		return {"area_checked": true}
	return {"round_walked": true}


# [deed, needs, makes]. Turning towards a noise is the state machine's alone:
# a planner with no goal it serves never chooses it.
static func _deeds() -> Array[Array]:
	return [
		[GuardBrain.WALK_ROUND, {}, {"round_walked": true}],
		[GuardBrain.GO_TO_LAST_KNOWN, {"knows_where": true}, {"at_last_known": true}],
		[GuardBrain.LOOK_AROUND, {"at_last_known": true}, {"area_checked": true}],
		[GuardBrain.CHASE, {"sees_player": true}, {"next_to_player": true}],
		[GuardBrain.CATCH, {"next_to_player": true, "alerted": true}, {"player_caught": true}],
	]
