# The minimal example on docs/techniques/ai_sifting.md, run by
# gossip_example_test.gd. A tavern keeper of your own who retells what
# happened in town: the game writes events down as they happen, and the
# keeper sifts them for one story -- a thief caught where they stole before.
extends Node

# The story, as data: the same thief, the same shop, a theft and then a
# catch, and no other theft by them there in between.
const CAUGHT_AGAIN: Dictionary = {
	"name": "caught-where-they-stole",
	"find": [
		{"as": "theft", "where": {"what": "theft", "who": "?thief", "where": "?shop"}},
		{"as": "catch", "where": {"what": "caught", "who": "?thief", "where": "?shop"}},
	],
	"before": [["theft", "catch"]],
	"unless": [{"where": {"what": "theft", "who": "?thief", "where": "?shop"}, "after": "theft", "before": "catch"}],
}

# What happened, in order. The game appends; nothing here edits an event.
var _events: Array[Dictionary] = []
var _sifter := StorySifter.new()


func _ready() -> void:
	# A misspelt key or an `unless` bounded by no event is refused here.
	if SiftPattern.problem(CAUGHT_AGAIN) != "":
		push_error(SiftPattern.problem(CAUGHT_AGAIN))


## Something happened in town.
func happened(day: int, what: String, who: String, where: String) -> void:
	_events.append({"day": day, "what": what, "who": who, "where": where})


## The keeper's stories, one line each, and the events each one is about:
## show both, and the player sees why the keeper tells it.
func stories() -> Array[Dictionary]:
	var told: Array[Dictionary] = []
	for match: Dictionary in _sifter.sift(_events, CAUGHT_AGAIN):
		var theft: Dictionary = _events[match["events"]["theft"]]
		var caught: Dictionary = _events[match["events"]["catch"]]
		var line: String = "%s stole from the %s on day %d, and was caught there on day %d." % [
			match["bindings"]["thief"], match["bindings"]["shop"], theft["day"], caught["day"]]
		told.append({"line": line, "events": match["events"].values()})
	return told
