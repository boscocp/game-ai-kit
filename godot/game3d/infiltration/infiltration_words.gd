## The names the infiltration level shows on its panel and over its guards,
## in the language chosen (T80).
##
## A guard's phase and action, its type and role, a sound's kind, the
## player's stance, the outcome: each is an identifier the logic compares
## or reads from data, so it stays English where it is written and is
## translated only here, where it is drawn (the owner's rule,
## docs/godot/localisation.md). The eye's reason is a sentence the
## perception addon writes in English; `eye` translates its three shapes,
## and a test holds them to the addon.
##
## When not to use it: for a sentence of the demo's own. That is one key
## with named placeholders; these fill them.
class_name InfiltrationWords
extends RefCounted

## Every identifier the screen shows, so the table holds each one. A test
## holds this list to guard_actions.json, guard_types.json and the constants
## that write the others: a name added there and missing here would show
## English without a sound.
const SHOWN: Array[String] = [  # shown through tr()
	"unaware", "suspicious", "searching", "alert",
	"patrol", "glance", "investigate", "search", "cover a way out", "report", "call for help",
	"raise the alarm", "check on a partner", "engage", "flank", "take cover", "return",
	"sentry", "shooter", "flanker",
	"standing", "crouched", "prone",
	"beside", "ahead", "far",
	"sight", "body", "footstep", "thrown_object", "open_door", "shot", "call_for_help", "creep",
	"takedown", "radio_report", "alarm", "guard_shot", "check_in", "partner_quiet",
]
## Identifiers whose English word another example's table already translates
## for its own sense -- the bot match's "sprint" is a pace, here it is a
## sound -- or that are file names. One key has one translation in the whole
## game (rule L8), so these are shown through a key of their own.
const SAID_AS: Dictionary = {
	"sprint": "a sprint",  # shown through tr()
	"the_warehouse": "the warehouse",  # shown through tr()
	"the_courtyard": "the courtyard",  # shown through tr()
	"build_up": "building up",  # shown through tr()
	"sustain_peak": "holding the peak",  # shown through tr()
	"peak_fade": "fading",  # shown through tr()
	"relax": "relaxing",  # shown through tr()
}
## What `VisionShape.percept` writes as its reason, as keys. Copied from the
## addon, which writes English and is not translated: a test holds these to
## its words, since a changed shape would fall back to English unseen.
const OUTSIDE: String = "outside every zone"  # shown through tr()
const TOO_FEW_RE: String = "^(\\d+) of (\\d+) points clear; the stance needs (\\d+)$"  # not shown: a pattern
const IN_ZONE_RE: String = "^in (.+)$"  # not shown: a pattern
## A generated level's name, as `Infiltration` writes it with its seed.
const GENERATED_RE: String = "^generated (\\d+)$"  # not shown: a pattern
## A level the constraint solver placed (T95), with its seed.
const SOLVED_RE: String = "^solved (\\d+)$"  # not shown: a pattern

static var _too_few := RegEx.create_from_string(TOO_FEW_RE)
static var _in_zone := RegEx.create_from_string(IN_ZONE_RE)
static var _generated := RegEx.create_from_string(GENERATED_RE)
static var _solved := RegEx.create_from_string(SOLVED_RE)


## `identifier` as the screen shows it in the language chosen.
static func word(identifier: String) -> String:
	return TranslationServer.translate(SAID_AS.get(identifier, identifier))


## The eye's reason, `why` as the perception addon wrote it, in the language
## chosen; "" stays "", and a shape it does not know is shown as written.
static func eye(why: String) -> String:
	if why == OUTSIDE:
		return TranslationServer.translate(OUTSIDE)
	var found: RegExMatch = _too_few.search(why)
	if found != null:
		return TranslationServer.translate("{clear} of {points} points clear; the stance needs {needed}").format({
			clear = found.get_string(1), points = found.get_string(2), needed = found.get_string(3)})
	found = _in_zone.search(why)
	if found != null:
		return TranslationServer.translate("in {zone}").format({zone = word(found.get_string(1))})
	return why


## A level's name as the panel shows it: a hand-made level's, or "generated"
## or "solved" and its seed.
static func level(name: String) -> String:
	var found: RegExMatch = _generated.search(name)
	if found != null:
		return TranslationServer.translate("generated level {seed}").format({seed = found.get_string(1)})
	found = _solved.search(name)
	if found != null:
		return TranslationServer.translate("solved level {seed}").format({seed = found.get_string(1)})
	return word(name)
