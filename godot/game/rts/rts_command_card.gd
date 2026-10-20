## The bottom panel: what is selected, what it is for, and a button for
## everything it can do -- each with its price, greyed with the reason when
## it cannot be done yet.
##
## StarCraft's command card and Age of Empires' build menu. A person who
## does not know the keys finds every order here: select workers and the
## buildings appear; select a barracks and its three fighters do. A button
## is enabled by the same questions the rules ask -- the price, the
## building it needs, the room -- so a click that the rules would refuse is
## greyed before it is made, and the reason is written under the buttons.
## The keys still work; each button shows its own.
##
## With nothing selected it says how to play, in four steps.
##
## When not to use it: to decide anything. It only offers what a person
## could already order.
class_name RtsCommandCard
extends Control

## A button was pressed: `action` is "build" or "train", `what` the kind.
signal chosen(action: String, what: String)

const ROLES: Dictionary = {
	RtsKinds.WORKER: "gathers ore and magma, and builds",
	RtsKinds.RUNNER: "fast and cheap -- beats mortars, loses to shields",
	RtsKinds.SHIELD: "slow and tough -- beats runners, loses to mortars",
	RtsKinds.MORTAR: "long reach, needs a lab -- beats shields, breaks buildings, loses to runners",
	RtsKinds.BASE: "trains workers and takes in what they carry; 10 supply",
	RtsKinds.BARRACKS: "trains runners, shields and mortars",
	RtsKinds.LAB: "lets the barracks train mortars",
	RtsKinds.DEPOT: "8 more supply, so more units",
	RtsKinds.TOWER: "sees 11 cells round it",
	RtsKinds.ROCKS: "ore, for workers to gather",
	RtsKinds.VENT: "magma, for workers to gather",
}
const KEYS: Dictionary = {
	RtsKinds.BARRACKS: "B", RtsKinds.DEPOT: "D", RtsKinds.LAB: "L", RtsKinds.TOWER: "T", RtsKinds.BASE: "E",
	RtsKinds.WORKER: "W", RtsKinds.RUNNER: "1", RtsKinds.SHIELD: "2", RtsKinds.MORTAR: "3",
}
const HOW_TO_PLAY: String = "How to play -- space starts the clock\n" \
	+ "1. Drag a box over your workers by the base; right-click a rock to mine ore.\n" \
	+ "2. Click one worker, click Barracks (B), then a green spot near the base.\n" \
	+ "3. When it is up, click the barracks and train Runners (1).\n" \
	+ "4. Select fighters, right-click an enemy. A Depot (D) when supply is full."
const BUTTON_SIZE := Vector2(74.0, 50.0)

@onready var _info: Label = $Info
@onready var _buttons: GridContainer = $Buttons
@onready var _why: Label = $Why

# What the buttons were last built for: rebuilt only when this changes, so
# a button is never freed under the click that presses it.
var _built_for: String = "-"


## Show what `selected` (ids) can do, for the side that `view` belongs to.
func show_selection(view: RtsSnapshot, selected: Dictionary) -> void:
	var units: Array[Dictionary] = []
	for unit: Dictionary in view.mine():
		if selected.has(unit["id"]):
			units.append(unit)
	_info.text = HOW_TO_PLAY if units.is_empty() else _describe(units)
	var offers: Array[Array] = _offers(units)
	var reasons: Array[String] = []
	for offer: Array in offers:
		reasons.append(_why_not(view, offer[0], offer[1], units))
	var signature: String = str(offers) + str(reasons)
	if signature == _built_for:
		return
	_built_for = signature
	_rebuild(offers, reasons)


func _rebuild(offers: Array[Array], reasons: Array[String]) -> void:
	for child: Node in _buttons.get_children():
		child.queue_free()
	var said: Array[String] = []
	for index: int in range(offers.size()):
		_add_button(offers[index][0], offers[index][1], reasons[index])
		if reasons[index] != "":
			said.append("%s: %s" % [offers[index][1], reasons[index]])
	_why.text = "\n".join(said)


# What the selection is: one unit in full, or a count of each kind.
func _describe(units: Array[Dictionary]) -> String:
	if units.size() == 1:
		var unit: Dictionary = units[0]
		var lines: Array[String] = ["%s  %d/%d" % [unit["kind"].capitalize(), unit["health"],
			RtsKinds.of(unit["kind"], "health")], ROLES[unit["kind"]]]
		if not unit["complete"]:
			lines.append("being built")
		elif not (unit["queue"] as Array).is_empty():
			lines.append("training: " + ", ".join(unit["queue"]))
		return "\n".join(lines)
	var counts: Dictionary = {}
	for unit: Dictionary in units:
		counts[unit["kind"]] = counts.get(unit["kind"], 0) + 1
	var parts: Array[String] = []
	for kind: String in counts:
		parts.append("%d %s" % [counts[kind], kind])
	return "%s\nright-click: move, attack, or (workers) gather" % ", ".join(parts)


# [action, kind] for every order the selection can be given from here.
static func _offers(units: Array[Dictionary]) -> Array[Array]:
	var offers: Array[Array] = []
	var kinds: Dictionary = {}
	for unit: Dictionary in units:
		kinds[unit["kind"]] = true
	if kinds.has(RtsKinds.WORKER):
		for building: String in [RtsKinds.BARRACKS, RtsKinds.DEPOT, RtsKinds.LAB, RtsKinds.TOWER, RtsKinds.BASE]:
			offers.append(["build", building])
	for kind: String in kinds:
		for trained: String in RtsKinds.of(kind, "trains"):
			offers.append(["train", trained])
	return offers


# Why `what` cannot be had now, in a few words; "" when it can.
static func _why_not(view: RtsSnapshot, action: String, what: String, units: Array[Dictionary]) -> String:
	var needed: String = RtsKinds.of(what, "needs")
	if needed != "" and not _has_complete(view, needed):
		return "needs a %s first" % needed
	for resource: String in RtsKinds.RESOURCES:
		if view.resources[resource] < RtsKinds.cost(what)[resource]:
			return "not enough %s" % resource
	if action == "train" and view.supply_cap - view.supply_used < int(RtsKinds.of(what, "supply")):
		return "no supply -- build a depot"
	if action == "train" and not units.any(func(unit: Dictionary) -> bool: return unit["complete"]):
		return "the building is not finished"
	return ""


static func _has_complete(view: RtsSnapshot, kind: String) -> bool:
	return view.mine(kind).any(func(unit: Dictionary) -> bool: return unit["complete"])


func _add_button(action: String, what: String, reason: String) -> void:
	var button := Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	var price: Array[String] = []
	for resource: String in RtsKinds.RESOURCES:
		if RtsKinds.cost(what)[resource] > 0:
			price.append("%d %s" % [RtsKinds.cost(what)[resource], resource])
	button.text = "%s (%s)\n%s" % [what.capitalize(), KEYS.get(what, ""), " ".join(price)]
	button.add_theme_font_size_override("font_size", 11)
	button.disabled = reason != ""
	button.tooltip_text = ROLES[what] + ("" if reason == "" else "\ncannot yet: " + reason)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: chosen.emit(action, what))
	_buttons.add_child(button)
