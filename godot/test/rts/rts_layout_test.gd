# T107: the RTS's command card keeps its words a margin above the window's
# bottom, in English and in pt-BR, whatever is selected.
#
# T102's measure of a wrapped Label found the card's `Info` -- how to play,
# with nothing selected -- ending at y=741 of 720 in pt-BR (a whole line cut
# off) and 721 in English. What the card says changes with the selection: a
# unit's heading and role, a deposit's ore, a building's training bar, a
# count of each kind in a box; and `Why`, beside it, lists the reason each
# greyed button cannot be had. So both are measured with nothing selected
# and with each unit selected alone, yours and the computer's, and a box
# over all of yours (a box takes no building), over a match the queues play
# for you.
extends GdUnitTestSuite

const LOCALES: Array[String] = ["en", "pt_BR"]
## The card's wrapped Labels.
const SHOWN: Array[String] = ["Interface/Card/Info", "Interface/Card/Why"]
## Where the match is looked at: the opening, then every SPAN seconds.
const LOOKS: int = 6
const SPAN_SECONDS: int = 60

var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_the_card_keeps_a_margin_over_a_played_match() -> void:
	for locale: String in LOCALES:
		var worst: Dictionary = await _worst_card_over_a_match(locale)
		for path: String in SHOWN:
			_assert_keeps_the_margin("%s, %s" % [locale, path], worst[path])


# Prints the lowest the words went, for the review's record, and holds it
# to the gutter.
func _assert_keeps_the_margin(what: String, worst: Dictionary) -> void:
	var said: String = "%s, %s" % [what, worst["when"]]
	print("worst card: %s: y=%.0f" % [said, worst["bottom"]])
	assert_float(worst["bottom"]).override_failure_message("%s: the words end at y=%.0f, past %.0f\n%s" % [
		said, worst["bottom"], _limit(), worst["words"]]).is_less_equal(_limit())


# The queues play your side (C's watching mode) with everything revealed, so
# your buildings train and the computer's units can be clicked. At each look
# the card is measured with nothing selected, each unit alone, and a box
# over all of yours -- which, as `RtsGame._select` does, leaves buildings
# out.
func _worst_card_over_a_match(locale: String) -> Dictionary:
	var game: RtsGame = _mounted_game(locale)
	game.watching = true
	game.reveal = true
	game.restart()
	var worst: Dictionary = {}
	for path: String in SHOWN:
		worst[path] = {"bottom": 0.0, "when": "", "words": ""}
	for look: int in range(LOOKS):
		var when: String = "%d s" % (look * SPAN_SECONDS)
		await _look_with(game, [], worst, when + ", nothing selected")
		var view: RtsSnapshot = RtsSnapshot.of(game.world, RtsScenario.WEST)
		for unit: Dictionary in view.units:
			await _look_with(game, [unit["id"]], worst, "%s, %s %d alone" % [when, unit["kind"], unit["id"]])
		var movers: Array = view.mine().filter(func(unit: Dictionary) -> bool: return not RtsKinds.is_building(unit["kind"]))
		await _look_with(game, movers.map(func(unit: Dictionary) -> int: return unit["id"]), worst, when + ", a box over all yours")
		game.played.play(SPAN_SECONDS * RtsWorld.TICKS_PER_SECOND)
	return worst


# Select `ids`, as a click or a box does, and keep each card Label's lowest
# words.
func _look_with(game: RtsGame, ids: Array, worst: Dictionary, when: String) -> void:
	game._view.selected.clear()
	for id: int in ids:
		game._view.selected[id] = true
	game._refresh()
	# Control's cached combined minimum size, which `_bottom_of` reads, is
	# refreshed at the next frame after a resize -- the Label itself is
	# reshaped at once (measured on the pinned engine, docs/godot/
	# localisation.md): the screen is drawn after it, so the test waits too.
	await get_tree().process_frame
	for path: String in SHOWN:
		var shown: Label = game.get_node(path)
		if _bottom_of(shown) > worst[path]["bottom"]:
			worst[path] = {"bottom": _bottom_of(shown), "when": when, "words": shown.atr(shown.text)}


# The gutter `BoardLayout` leaves between a panel and the window's edge.
func _limit() -> float:
	return BoardLayout.window_size().y - BoardLayout.GUTTER


# A wrapped Label's minimum height is the height of its wrapped words
# (docs/godot/localisation.md, T102), so that is where they end.
func _bottom_of(shown: Label) -> float:
	return shown.get_global_rect().position.y + shown.get_combined_minimum_size().y


func _mounted_game(locale: String) -> RtsGame:
	TranslationServer.set_locale(locale)
	var game: RtsGame = auto_free((load("res://game/rts/rts.tscn") as PackedScene).instantiate())
	add_child(game)
	return game
