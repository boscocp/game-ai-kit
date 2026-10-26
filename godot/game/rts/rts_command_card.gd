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

## A button was pressed: `action` is "build", "train" or "repair", `what`
## the kind -- for "repair", the kind of the building to mend.
signal chosen(action: String, what: String)

const ROLES: Dictionary = {  # shown through tr()
	RtsKinds.WORKER: "gathers ore and magma, and builds",
	RtsKinds.RUNNER: "fast and cheap -- beats mortars, loses to shields",
	RtsKinds.SHIELD: "slow and tough -- beats runners, loses to mortars",
	RtsKinds.MORTAR: "long reach, needs a lab -- beats shields, breaks buildings, loses to runners",
	RtsKinds.BASE: "trains workers and takes in what they carry; 10 supply",
	RtsKinds.BARRACKS: "trains runners, shields and mortars",
	RtsKinds.LAB: "lets the barracks train mortars",
	RtsKinds.DEPOT: "8 more supply, so more units",
	RtsKinds.TOWER: "sees 11 cells round it once built; armed (A), it shoots what it sees within 6",
	RtsKinds.ARM: "a gun for this tower: it strikes the nearest enemy it sees within 6 cells, never through a wall",
	RtsKinds.ROCKS: "ore, for workers to gather",
	RtsKinds.VENT: "magma, for workers to gather",
}
const KEYS: Dictionary = {
	RtsKinds.BARRACKS: "B", RtsKinds.DEPOT: "D", RtsKinds.LAB: "L", RtsKinds.TOWER: "T", RtsKinds.BASE: "E",
	RtsKinds.WORKER: "W", RtsKinds.RUNNER: "1", RtsKinds.SHIELD: "2", RtsKinds.MORTAR: "3", RtsKinds.ARM: "A",
}
## With nothing selected: how to play, a line a key.
const HOW_TO_PLAY: Array[String] = [  # shown through tr()
	"How to play -- space starts the clock",
	"1. Drag a box over your workers by the base; right-click a rock to mine ore.",
	"2. Click one worker, click Barracks (B), then a green spot near the base.",
	"3. When it is up, click the barracks and train Runners (1).",
	"4. Select fighters, right-click an enemy. A Depot (D) when supply is full.",
]
const BUTTON_SIZE := Vector2(74.0, 50.0)

@onready var _info: Label = $Info
@onready var _buttons: GridContainer = $Buttons
@onready var _why: Label = $Why

# What the buttons were last built for: rebuilt only when this changes, so
# a button is never freed under the click that presses it.
var _built_for: String = "-"


## Build the buttons again at the next selection shown: their words were
## written in the language before (T80).
func forget_buttons() -> void:
	_built_for = "-"


## Show what `selected` (ids) can do, for the side that `view` belongs to.
func show_selection(view: RtsSnapshot, selected: Dictionary) -> void:
	var units: Array[Dictionary] = []
	for unit: Dictionary in view.units:
		if selected.has(unit["id"]):
			units.append(unit)
	_info.text = "\n".join(HOW_TO_PLAY.map(tr)) if units.is_empty() else _describe(units)
	var yours: bool = units.all(func(unit: Dictionary) -> bool: return unit["side"] == view.side)
	var offers: Array[Array] = []
	if yours:
		offers = _offers(units)
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
			said.append("%s: %s" % [RtsWords.word(offers[index][1]), reasons[index]])
	_why.text = "\n".join(said)


# What the selection is: one unit in full, or a count of each kind.
func _describe(units: Array[Dictionary]) -> String:
	if units.size() == 1 and RtsKinds.is_deposit(units[0]["kind"]):
		var deposit: Dictionary = units[0]
		return tr("{kind}: {left} {resource} left of {full}").format({kind = RtsWords.title(deposit["kind"]),
			left = deposit["health"], resource = RtsWords.word(RtsKinds.of(deposit["kind"], "yields")),
			full = RtsKinds.of(deposit["kind"], "health")}) + "\n" + tr(ROLES[deposit["kind"]])
	if units.size() == 1:
		var unit: Dictionary = units[0]
		var mine: bool = unit.has("order")
		var heading: String = "{kind}  {health}/{full}" if mine else "the computer's {kind}  {health}/{full}"  # shown through tr()
		var lines: Array[String] = [tr(heading).format({kind = RtsWords.title(unit["kind"]), health = unit["health"],
			full = RtsKinds.of(unit["kind"], "health")}), tr(ROLES[unit["kind"]])]
		if unit["armed"]:
			lines.append(tr("armed"))
		if not unit["complete"]:
			lines.append(tr("being built"))
		elif not (unit.get("queue", []) as Array).is_empty():
			lines.append(training_line(unit))
		return "\n".join(lines)
	var counts: Dictionary = {}
	for unit: Dictionary in units:
		counts[unit["kind"]] = counts.get(unit["kind"], 0) + 1
	var parts: Array[String] = []
	for kind: String in counts:
		parts.append("%d %s" % [counts[kind], RtsWords.word(kind)])
	return ", ".join(parts) + "\n" + tr("right-click: move, attack, or (workers) gather")


# [action, kind] for every order the selection can be given from here.
## What a building's queue is doing, as a bar: "training runner
## [######----] 3 s, then 2 more". The first in the queue is the one
## being trained; the bar is its share of its build time done.
static func training_line(unit: Dictionary) -> String:
	var first: String = unit["queue"][0]
	var needed: int = RtsKinds.of(first, "ticks")
	var share: float = clampf(float(unit["progress"]) / needed, 0.0, 1.0)
	var filled: int = roundi(share * 10.0)
	var left: float = float(needed - int(unit["progress"])) / RtsWorld.TICKS_PER_SECOND
	var line: String = "training {kind} {bar} {seconds} s" if unit["queue"].size() == 1 else "training {kind} {bar} {seconds} s, then {more} more"  # shown through tr()
	return TranslationServer.translate(line).format({kind = RtsWords.word(first),
		bar = "[%s%s]" % ["#".repeat(filled), "-".repeat(10 - filled)], seconds = ceili(left), more = unit["queue"].size() - 1})


static func _offers(units: Array[Dictionary]) -> Array[Array]:
	var offers: Array[Array] = []
	var kinds: Dictionary = {}
	for unit: Dictionary in units:
		kinds[unit["kind"]] = true
	if units.size() == 1 and RtsKinds.is_building(units[0]["kind"]) and units[0]["complete"]:
		offers.append(["repair", units[0]["kind"]])  # not shown: an identifier
	if kinds.has(RtsKinds.WORKER):
		for building: String in [RtsKinds.BARRACKS, RtsKinds.DEPOT, RtsKinds.LAB, RtsKinds.TOWER, RtsKinds.BASE]:
			offers.append(["build", building])  # not shown: an identifier
	for kind: String in kinds:
		for trained: String in RtsKinds.of(kind, "trains"):
			offers.append(["train", trained])  # not shown: an identifier
	return offers


# Why `what` cannot be had now, in a few words; "" when it can.
static func _why_not(view: RtsSnapshot, action: String, what: String, units: Array[Dictionary]) -> String:
	if action == "repair":  # not shown: an identifier
		if units[0]["health"] >= int(RtsKinds.of(what, "health")):
			return TranslationServer.translate("not damaged")
		return "" if not view.mine(RtsKinds.WORKER).is_empty() else TranslationServer.translate("no worker to send")
	var needed: String = RtsKinds.of(what, "needs")
	if needed != "" and not _has_complete(view, needed):
		return TranslationServer.translate("needs this first: {kind}").format({kind = RtsWords.word(needed)})
	for resource: String in RtsKinds.RESOURCES:
		if view.resources[resource] < RtsKinds.cost(what)[resource]:
			return TranslationServer.translate("not enough {resource}").format({resource = RtsWords.word(resource)})
	if action == "train" and view.supply_cap - view.supply_used < int(RtsKinds.of(what, "supply")):  # not shown: an identifier
		return TranslationServer.translate("no supply -- build a depot")
	if action == "train" and not units.any(func(unit: Dictionary) -> bool: return unit["complete"]):  # not shown: an identifier
		return TranslationServer.translate("the building is not finished")
	if RtsKinds.is_upgrade(what) and units.all(func(unit: Dictionary) -> bool: return unit["armed"] or what in unit["queue"]):
		return TranslationServer.translate("already armed")
	return ""


static func _has_complete(view: RtsSnapshot, kind: String) -> bool:
	return view.mine(kind).any(func(unit: Dictionary) -> bool: return unit["complete"])


func _add_button(action: String, what: String, reason: String) -> void:
	var button := Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	var price: Array[String] = []
	for resource: String in RtsKinds.RESOURCES:
		if RtsKinds.cost(what)[resource] > 0:
			price.append("%d %s" % [RtsKinds.cost(what)[resource], RtsWords.word(resource)])
	button.text = "%s (%s)\n%s" % [RtsWords.title(what), KEYS.get(what, ""), " ".join(price)]
	if action == "repair":  # not shown: an identifier
		button.text = tr("Repair") + "\n" + tr("free, a worker")
		price.clear()
	button.add_theme_font_size_override("font_size", 11)
	button.disabled = reason != ""
	var role: String = tr("send the nearest worker to mend it") if action == "repair" else tr(ROLES[what])  # not shown: an identifier
	button.tooltip_text = role + ("" if reason == "" else "\n" + tr("cannot yet: {why}").format({why = reason}))
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: chosen.emit(action, what))
	_buttons.add_child(button)
