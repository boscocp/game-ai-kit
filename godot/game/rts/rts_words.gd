## The names the RTS shows -- a kind of unit, a resource, a squad's state, a
## region, a side, a level -- in the language chosen (T80).
##
## Each is an identifier the rules and the AI compare, so it stays English
## where it is written and is translated only here, where it is drawn (the
## owner's rule, docs/godot/localisation.md). A plan's steps and a goal's
## facts (`build_lab`, `mortars_ready`) are identifiers too, and stay as the
## code writes them even in Portuguese, as the tactical planner's do; the
## pt-BR glossary says what they are.
##
## When not to use it: for a sentence. A sentence is one key with named
## placeholders; these are the single words that fill them. Portuguese gives
## a tower and a barracks different genders, so no sentence here puts an
## article before a name.
class_name RtsWords
extends RefCounted

## Every identifier the screen shows, so the table holds each one. A test
## holds this list to `RtsKinds`, `Squad`, `RtsScenario.REGIONS` and
## `RtsLevels`: a name added there and missing here would show English
## without a sound.
const SHOWN: Array[String] = [  # shown through tr()
	"worker", "runner", "shield", "mortar", "base", "barracks", "lab", "depot", "tower", "arm", "rocks", "vent",
	"ore", "magma",
	"gather", "advance", "fight", "retreat",
	"west home", "east home", "west expansion", "east expansion", "bridge", "north ford", "south ford",
	"west", "east",
	"easy", "normal",
	"move", "attack", "build", "train", "repair",
]

## Each kind with its article, and counted: Portuguese gives a tower and a
## barracks different genders, so a sentence takes the whole phrase rather
## than an article glued before a name (T80's review).
const WITH_A: Dictionary = {
	"worker": "a worker",  # shown through tr()
	"runner": "a runner",  # shown through tr()
	"shield": "a shield",  # shown through tr()
	"mortar": "a mortar",  # shown through tr()
	"base": "a base",  # shown through tr()
	"barracks": "a barracks",  # shown through tr()
	"lab": "a lab",  # shown through tr()
	"depot": "a depot",  # shown through tr()
	"tower": "a tower",  # shown through tr()
	"arm": "an arm",  # shown through tr()
	"rocks": "a rock",  # shown through tr()
	"vent": "a vent",  # shown through tr()
}
const WITH_THE: Dictionary = {
	"worker": "the worker",  # shown through tr()
	"runner": "the runner",  # shown through tr()
	"shield": "the shield",  # shown through tr()
	"mortar": "the mortar",  # shown through tr()
	"base": "the base",  # shown through tr()
	"barracks": "the barracks",  # shown through tr()
	"lab": "the lab",  # shown through tr()
	"depot": "the depot",  # shown through tr()
	"tower": "the tower",  # shown through tr()
	"arm": "the arm",  # shown through tr()
	"rocks": "the rocks",  # shown through tr()
	"vent": "the vent",  # shown through tr()
}
const MANY: Dictionary = {
	"worker": "{count} workers",  # shown through tr()
	"runner": "{count} runners",  # shown through tr()
	"shield": "{count} shields",  # shown through tr()
	"mortar": "{count} mortars",  # shown through tr()
	"base": "{count} bases",  # shown through tr()
	"barracks": "{count} barracks",  # shown through tr()
	"lab": "{count} labs",  # shown through tr()
	"depot": "{count} depots",  # shown through tr()
	"tower": "{count} towers",  # shown through tr()
	"arm": "{count} arms",  # shown through tr()
	"rocks": "{count} rocks",  # shown through tr()
	"vent": "{count} vents",  # shown through tr()
}


## `identifier` as the screen shows it in the language chosen.
static func word(identifier: String) -> String:
	return TranslationServer.translate(identifier)


## `identifier` as a heading or a button shows it: its first letter capital.
static func title(identifier: String) -> String:
	var said: String = word(identifier)
	return said.left(1).to_upper() + said.substr(1)


## A kind with its indefinite article, "a lab", in the language chosen; any
## other identifier as `word` says it.
static func with_a(kind: String) -> String:
	return TranslationServer.translate(WITH_A[kind]) if WITH_A.has(kind) else word(kind)


## A kind with its definite article, "the lab", in the language chosen.
static func with_the(kind: String) -> String:
	return TranslationServer.translate(WITH_THE[kind]) if WITH_THE.has(kind) else word(kind)


## `count` of a kind, "3 workers" or "1 worker", in the language chosen.
static func counted(count: int, kind: String) -> String:
	if count == 1 or not MANY.has(kind):
		return "%d %s" % [count, word(kind)]
	return TranslationServer.translate(MANY[kind]).format({count = count})
