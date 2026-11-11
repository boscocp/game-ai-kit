## The valley that remembers (T165, ADR 0025): you are a traveller in a
## valley of two villages, and what you do to its places stays done.
##
## There is no combat and no opponent. Six villagers live their day -- bread,
## water, fruit -- each planning with GOAP over routes A\* finds, and
## choosing between goals with utility. A plan's cost is an approximation:
## each action is priced by the walk from where the villager stands when it
## plans, not from the step before, so GOAP's costs stay fixed during one
## search; on a map this small the order of plans barely changes. You may do one deed a day to a
## place: burn the barn, pull the bridge down, dig a well. The deed is kept
## in the record, the one file the kit keeps between sessions, and the
## world of every later day, in this session and the next, is rebuilt from
## it. A burnt barn is still burnt when you come back.
##
## The panel shows why each thing happens: the deed, the fact it changed,
## the place a villager can no longer reach, the plan it chose instead and
## the A\* search that found its new way -- drawn on the ground for the
## villager you follow (Tab). Below it, what three people make of you: your
## standing, summed from your deeds by fixed weights, sets the ferryman's
## price, the merchant's, and whether the chapel's door opens.
##
## E erases the valley's memory, after you confirm: the save is removed
## and the valley starts again from its first day. This node only runs the
## clock, reads the keys and draws; the session is `ValleyGame`'s.
class_name ValleyDemo
extends Node2D

## How long a turn lasts on screen, in seconds.
const TURN_SECONDS: float = 0.3
## The keys that do the deeds on offer, in order.
const DEED_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]

## The session being played, on the game's own save.
var game := ValleyGame.new(ValleySave.new())
## The villager whose decision is drawn, by index.
var followed: int = 0
## Whether the clock is stopped; space still plays one turn.
var paused: bool = false
## Whether E was pressed and the erase waits for Y.
var confirming: bool = false
## The last thing said on the message line, as a key and its values.
var message: Array = []

var _waited: float = 0.0

@onready var _status: Label = $Interface/Status
@onready var _panel: Label = $Interface/Decision
@onready var _deeds: Label = $Interface/Deeds
@onready var _message: Label = $Interface/Message
@onready var _legend: Legend = $Interface/Legend
@onready var _erase: Button = $Interface/Erase


func _ready() -> void:
	_erase.pressed.connect(ask_to_erase)
	_show_legend()
	if game.refused != "":
		message = ["The save was refused, and is left as it is: {why}. E erases it.", {why = game.refused}]  # shown through tr()
	_refresh()
	Language.apply_if_opened_alone(self)


# The words are rebuilt in the language just chosen: a Label set from code
# keeps the text it was given.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_show_legend()
		_refresh()


func _show_legend() -> void:
	_legend.set_entries([
		[ValleyView.WEST, tr("west village: the market and the square")],
		[ValleyView.EAST, tr("east village: the barn, the mill, the orchard")],
		[ValleyView.WATER, tr("the river, crossed at the bridge or the ford")],
		[ValleyView.BRIDGE, tr("planks: a crossing open today")],
		[ValleyView.PLACE, tr("a place as it is today; dark: burnt or gone")],
		[ValleyView.FOLLOWED, tr("the ringed villager is the one followed (Tab)")],
		[ValleyView.EXPANDED, tr("yellow: the cells its A* search expanded")],
		[ValleyView.FRONTIER, tr("cyan: the search's frontier when it stopped")],
		[ValleyView.ROUTE, tr("white line and ring: its route, and where to")],
		[ValleyView.PERSON, tr("violet: the ferryman, the merchant, the priestess")],
	] as Array[Array])


func _process(delta: float) -> void:
	if paused or confirming:
		return
	_waited += delta
	if _waited < TURN_SECONDS:
		return
	while _waited >= TURN_SECONDS:
		_waited -= TURN_SECONDS
		game.step_turn()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if confirming:
		answer_erase(key.keycode == KEY_Y)
	elif key.keycode in DEED_KEYS:
		do_offered(DEED_KEYS.find(key.keycode))
	elif key.keycode == KEY_SPACE:
		paused = true
		step_decision()
	elif key.keycode == KEY_P:
		paused = not paused
	elif key.keycode == KEY_N:
		game.next_day()
	elif key.keycode == KEY_TAB:
		followed = (followed + 1) % game.villagers.size()
	elif key.keycode == KEY_E:
		ask_to_erase()
	_refresh()


## Do the deed offered at `index`, and say what became of it.
func do_offered(index: int) -> void:
	var offered: Array[Dictionary] = game.offered()
	if index >= offered.size():
		return
	var verb_place: String = "%s %s" % [offered[index]["verb"], offered[index]["place"]]
	var why: String = game.act(str(offered[index]["verb"]), str(offered[index]["place"]))
	if why == "":
		message = ["Kept, deed {number} of the record: {deed}", {number = game.record.size(),  # shown through tr()
			deed = ValleyPanel.deed_words(verb_place)}]
	else:
		message = ["Refused: {why}", {why = why}]  # shown through tr()


## E, or the button: ask before erasing anything.
func ask_to_erase() -> void:
	confirming = true
	message = ["Erase everything the valley remembers? Y erases; any other key keeps it.", {}]  # shown through tr()
	_refresh()


## The answer to the question: Y erases the save, and the valley starts
## again from its first day; anything else keeps it.
func answer_erase(erase: bool) -> void:
	confirming = false
	if not erase:
		message = ["Kept: nothing was erased.", {}]  # shown through tr()
		return
	var answer: Error = game.forget()
	message = ["Erased: the valley starts again from its first day.", {}]  # shown through tr()
	if answer != OK:
		message = ["The save could not be erased: {why}", {why = error_string(answer)}]  # shown through tr()


## One decision: a turn of every villager -- the stand-in for watching
## that lets a test, or somebody stepping, go one turn at a time.
func step_decision() -> void:
	game.step_turn()
	_refresh()


## What the villagers are deciding with, and what the three people make of
## the player: `ValleyShown`'s overlay, following the villager chosen.
func decision_overlay() -> Dictionary:
	return ValleyShown.overlay(game, followed)


func _refresh() -> void:
	if not is_node_ready():
		return
	queue_redraw()
	var overlay: Dictionary = decision_overlay()
	_status.text = ValleyPanel.status(overlay, paused)
	_panel.text = ValleyPanel.describe(overlay)
	_deeds.text = ValleyPanel.deeds_offered(overlay)
	_message.text = tr(str(message[0])).format(message[1]) if not message.is_empty() else ""
	_erase.text = tr("Erase the valley's memory (E)")


func _draw() -> void:
	var ground: ValleyMap = ValleyMap.authored()
	ValleyView.draw_ground(self, ground, game.world.facts)
	ValleyView.draw_search(self, game.villagers[followed])
	ValleyView.draw_places(self, ground, game.world.facts)
	ValleyView.draw_people(self, ground, game.manners)
	ValleyView.draw_villagers(self, game.villagers, followed)
