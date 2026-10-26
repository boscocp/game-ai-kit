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


## `identifier` as the screen shows it in the language chosen.
static func word(identifier: String) -> String:
	return TranslationServer.translate(identifier)


## `identifier` as a heading or a button shows it: its first letter capital.
static func title(identifier: String) -> String:
	var said: String = word(identifier)
	return said.left(1).to_upper() + said.substr(1)
