## The window the executable opens on: every example in the kit, a card
## saying what its AI decides and how, and a way in and back out.
##
## The examples are listed down the left, from `catalogue.json`; the card of
## the one selected fills the right. Up and down choose, enter or the button
## plays, and Escape, from inside any example, frees it and comes back here.
## Mouse and keyboard both work throughout.
##
## An example is mounted beside the menu, as a child of the root, and made
## the tree's current scene, so it runs as it does opened on its own with
## `make demo-<name>`: the skirmish's R reloads the current scene, which is
## then the example and not this menu. Whether an example is playing is read
## off the tree -- the current scene is not the menu -- never off a kept
## reference, because after a reload the example is a new node and the old
## one is freed (wave 59's review: Escape stopped working after R).
##
## The menu keeps itself the root's last child while an example plays.
## `_input` runs in reverse tree order, last child first, so that is what
## puts the menu's Escape ahead of any example's own `_input`.
##
## A catalogue, not a game, and laid out like one: light text on a dark
## ground, nothing under 17 px, nothing pinned small in a corner (T8).
##
## The button at the top right, or L, or Y on a pad, switches every example
## between English and Brazilian Portuguese at once, and the choice is kept
## for next time (T78, `Language`). The cards themselves are still English:
## their words are the catalogue's, translated in a later task.
class_name ExampleMenu
extends Control

const BACKGROUND := Color(0.11, 0.12, 0.14)
const TEXT := Color(0.93, 0.93, 0.93)
const QUIET := Color(0.70, 0.72, 0.76)
const ACCENT := Color(1.0, 0.80, 0.30)
const MARGIN: float = 32.0
const LIST_WIDTH: float = 360.0
const TITLE_SIZE: int = 30
const LIST_SIZE: int = 22
const CARD_SIZE: int = 17
## The controller on the menu (wave 84): the D-pad or the stick chooses, A
## plays, LB and RB scroll the card. Godot 4.7's own `ui_*` actions name no
## pad button at all, measured, so nothing here would move without it.
const MENU_PAD: Dictionary = {JOY_BUTTON_DPAD_UP: KEY_UP, JOY_BUTTON_DPAD_DOWN: KEY_DOWN,
		JOY_BUTTON_A: KEY_ENTER, JOY_BUTTON_LEFT_SHOULDER: KEY_PAGEUP,
		JOY_BUTTON_RIGHT_SHOULDER: KEY_PAGEDOWN, JOY_BUTTON_Y: KEY_L}
## Inside an example, only View, as Escape, back to the menu: every other
## button is the example's own.
const PLAYING_PAD: Dictionary = {JOY_BUTTON_BACK: KEY_ESCAPE}

## The cards, in the order they are listed.
var catalogue: ExampleCatalogue
## Where the language chosen is kept. A test points it somewhere of its own
## before the menu enters the tree, so a person's choice never leaks into a
## test, nor a test's into the person's game.
var settings_path: String = Language.SETTINGS

var _pad := PadAsKeys.new()
var _pad_on_menu: bool = false
var _list: ItemList
var _heading: Label
var _card: RichTextLabel
var _play: Button
var _title: Label
var _help: Label
var _language: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	catalogue = ExampleCatalogue.load_from()
	_build()
	# After the build: the change of locale notifies at once, and
	# `is_node_ready()` is already true inside _ready, so the words it sets
	# must have somewhere to go.
	Language.apply(settings_path)
	for card: Dictionary in catalogue.cards:
		_list.add_item(card.get("title", "?"))
		# A card's title is the catalogue's, not a key: never looked up.
		_list.set_item_auto_translate_mode(_list.item_count - 1, Node.AUTO_TRANSLATE_MODE_DISABLED)
	if not catalogue.cards.is_empty():
		select(0)
	else:
		_card.text = ExampleCatalogue.plain(catalogue.problem)
	_retranslate()
	_list.grab_focus()
	add_child(_pad)


## Speak the other language, everywhere, and remember it.
func switch_language() -> void:
	Language.choose(Language.other(), settings_path)


# Text set from code keeps the words it was given; set it again in the
# language just chosen. Also sent on entering the tree, before _ready.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_retranslate()


func _retranslate() -> void:
	_title.text = tr("game-ai-kit: every example")
	_help.text = "\n".join([
		tr("Up and down choose, Enter plays, Page Up and Down scroll the card, L switches the language;"),
		tr("Esc inside an example comes back here. On a pad: the D-pad, A, LB and RB, Y, and View."),
	])
	_play.text = tr("Play  (Enter)")
	_language.text = tr("Language: English  (L)")
	if catalogue.cards.is_empty():
		_heading.text = tr("No examples to show")


## True while an example, not the menu, is the current scene.
func is_playing() -> bool:
	return get_tree().current_scene != self


## Show card `index` and select it in the list.
func select(index: int) -> void:
	_list.select(index)
	_list.ensure_current_is_visible()
	var card: Dictionary = catalogue.cards[index]
	_heading.text = card.get("title", "")
	_card.text = ExampleCatalogue.text_of(card, ACCENT)
	_card.scroll_to_line(0)


## Open the selected example in place of the menu.
func play() -> void:
	var chosen: PackedInt32Array = _list.get_selected_items()
	if chosen.is_empty():
		return
	var packed: PackedScene = load(catalogue.cards[chosen[0]].get("scene", "")) as PackedScene
	if packed != null:
		open(packed.instantiate())


## Mount `example` as the current scene and hide the menu. Public so a test
## can hand it an example built in memory, broken on purpose.
func open(example: Node) -> void:
	visible = false
	get_tree().root.add_child(example)
	get_tree().current_scene = example
	get_tree().root.move_child(self, -1)


## Free whatever example is playing and show the menu again.
func back() -> void:
	var current: Node = get_tree().current_scene
	if current != null and current != self:
		current.queue_free()
	get_tree().current_scene = self
	visible = true
	_list.grab_focus()


# A reload adds the new example after the menu again; take back the last
# place, so the next Escape still reaches the menu first.
func _process(_delta: float) -> void:
	if is_playing() and get_index() != get_parent().get_child_count() - 1:
		get_parent().move_child(self, -1)
	if is_playing() == _pad_on_menu:
		_pad_on_menu = not is_playing()
		if _pad_on_menu:
			_pad.use(MENU_PAD, [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN])
		else:
			_pad.use(PLAYING_PAD)


# Escape is read here, in `_input`, before the GUI and -- because the menu
# is the root's last child -- before any example's own `_input`, so no
# example has to know the menu exists. On the menu,
# page up and down scroll a card too long for the window -- the tactical
# board's lists nine techniques -- since the list keeps the arrow keys.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if is_playing() and key.keycode == KEY_ESCAPE and not key.echo:
		get_viewport().set_input_as_handled()
		back()
	elif not is_playing() and key.keycode == KEY_L and not key.echo:
		get_viewport().set_input_as_handled()
		switch_language()
	elif not is_playing() and key.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		var bar: VScrollBar = _card.get_v_scroll_bar()
		bar.value += bar.page * (1.0 if key.keycode == KEY_PAGEDOWN else -1.0)
		get_viewport().set_input_as_handled()


func _build() -> void:
	var ground := ColorRect.new()
	ground.color = BACKGROUND
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	var size_now: Vector2 = get_viewport_rect().size
	_title = _label(Vector2(MARGIN, MARGIN), TITLE_SIZE, TEXT)
	add_child(_title)
	_help = _label(Vector2(MARGIN, size_now.y - MARGIN - 48.0), CARD_SIZE, QUIET)
	add_child(_help)
	_language = Button.new()
	_language.position = Vector2(size_now.x - MARGIN - 340.0, MARGIN)
	_language.size = Vector2(340.0, 40.0)
	_language.add_theme_font_size_override("font_size", CARD_SIZE)
	_language.focus_mode = Control.FOCUS_NONE
	_language.pressed.connect(switch_language)
	add_child(_language)
	_list = ItemList.new()
	_list.position = Vector2(MARGIN, MARGIN * 3.0)
	_list.size = Vector2(LIST_WIDTH, size_now.y - MARGIN * 5.5 - 24.0)
	_list.add_theme_font_size_override("font_size", LIST_SIZE)
	_list.add_theme_constant_override("v_separation", 12)
	_list.item_selected.connect(select)
	_list.item_activated.connect(func(_index: int) -> void: play())
	add_child(_list)
	_build_card(size_now)


func _build_card(size_now: Vector2) -> void:
	var left: float = MARGIN * 2.0 + LIST_WIDTH
	var width: float = size_now.x - left - MARGIN
	_heading = _label(Vector2(left, MARGIN * 3.0), TITLE_SIZE - 4, ACCENT)
	# The heading shows a card's title, from the catalogue: not a key.
	_heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(_heading)
	_card = RichTextLabel.new()
	_card.bbcode_enabled = true
	_card.position = Vector2(left, MARGIN * 3.0 + 48.0)
	_card.size = Vector2(width, size_now.y - MARGIN * 5.5 - 112.0)
	_card.add_theme_font_size_override("normal_font_size", CARD_SIZE)
	_card.add_theme_font_size_override("bold_font_size", CARD_SIZE)
	_card.add_theme_color_override("default_color", TEXT)
	_card.focus_mode = Control.FOCUS_NONE
	add_child(_card)
	_play = Button.new()
	_play.position = Vector2(left, size_now.y - MARGIN * 2.5 - 48.0)
	_play.add_theme_font_size_override("font_size", LIST_SIZE)
	_play.focus_mode = Control.FOCUS_NONE
	_play.pressed.connect(play)
	add_child(_play)


func _label(where: Vector2, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.position = where
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label
