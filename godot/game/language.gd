## Which language the examples speak: English, or Brazilian Portuguese (T78).
##
## The words themselves live in `godot/locale/<module>.csv`, one file per
## module, keyed by the English text, and Godot's TranslationServer does the
## looking up. This only decides the locale: the person's saved choice if
## there is one, otherwise the system's -- `pt` means pt-BR, anything else
## English -- and remembers a choice made in the menu.
##
## The engine already starts in the system's locale (measured on 4.7.2, see
## docs/godot/localisation.md); this is here so a choice survives closing the
## game, and so a Portuguese system from Portugal still gets the pt-BR words
## by a rule a person can read, not by the engine's nearest match.
##
## When not to use it: a game with more than two languages wants a list, not
## a toggle.
class_name Language
extends RefCounted

const ENGLISH: String = "en"
const PORTUGUESE: String = "pt_BR"
## Where the choice is kept. `user://`, which `scripts/godot` redirects off
## the home folder and into the checkout's own `.user-data/` (ADR 0002, 0022).
const SETTINGS: String = "user://settings.cfg"
const SECTION: String = "language"
const KEY: String = "locale"


## The locale for a system whose language is `system_language`, as
## `OS.get_locale_language()` reports it: Portuguese of any country reads the
## pt-BR words, everything else the English ones.
static func for_system(system_language: String) -> String:
	return PORTUGUESE if system_language == "pt" else ENGLISH


## The choice saved in `path`, or "" when nothing usable is saved there.
static func saved(path: String = SETTINGS) -> String:
	var settings := ConfigFile.new()
	if settings.load(path) != OK:
		return ""
	var locale: String = str(settings.get_value(SECTION, KEY, ""))
	return locale if locale in [ENGLISH, PORTUGUESE] else ""


## The locale to speak: the saved choice, else the system's.
static func chosen(path: String = SETTINGS) -> String:
	var remembered: String = saved(path)
	return remembered if remembered != "" else for_system(OS.get_locale_language())


## Speak the chosen language. The menu calls it once, when it opens.
static func apply(path: String = SETTINGS) -> void:
	TranslationServer.set_locale(chosen(path))


## Speak the chosen language when `scene` was opened on its own -- `make run`,
## `make demo-search` -- and not from the menu, which has chosen already, nor
## from a test, which sets its own. Measured on 4.7.2: a scene the engine
## opens as the main scene is already `current_scene` in its `_ready`; one the
## menu or a test adds is not. Call it last in `_ready`: the change of locale
## notifies at once, and the scene rebuilds its words then.
static func apply_if_opened_alone(scene: Node, path: String = SETTINGS) -> void:
	if scene.get_tree().current_scene == scene:
		apply(path)


## Speak `locale` from now on, and remember it in `path`. Every Control and
## every node listening for NOTIFICATION_TRANSLATION_CHANGED redraws itself.
static func choose(locale: String, path: String = SETTINGS) -> Error:
	TranslationServer.set_locale(locale)
	var settings := ConfigFile.new()
	settings.load(path)
	settings.set_value(SECTION, KEY, locale)
	return settings.save(path)


## The other language: what the menu's switch changes to.
static func other() -> String:
	return ENGLISH if is_portuguese() else PORTUGUESE


## True while the examples speak Portuguese.
static func is_portuguese() -> bool:
	return TranslationServer.get_locale().begins_with("pt")


## `value` with `places` decimals, its separator the language's: "1.5" in
## English, "1,5" in Portuguese (T80). Only for a number a person reads as
## prose -- a lap time, a margin -- never for one a gate or a log parses,
## which keeps the point whatever the language.
static func decimal(value: float, places: int) -> String:
	var written: String = ("%." + str(places) + "f") % value
	return written.replace(".", ",") if is_portuguese() else written
