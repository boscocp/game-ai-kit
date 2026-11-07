# The minimal example on docs/techniques/ai_bayes.md, run by
# watchman_example_test.gd. A night watchman of your own who hears the dog
# and sees the gate, and wants to know whether anyone came in -- and why he
# thinks so.
extends Node

# Written by hand: a parent before its child, one row per way its parents
# can be, the chances in a row summing to 1. Nothing here changes them.
const NETWORK: Dictionary = {"variables": [
	{"name": "intruder", "values": ["yes", "no"], "parents": [], "table": [[0.05, 0.95]]},
	{"name": "dog_barks", "values": ["yes", "no"], "parents": ["intruder"], "table": [[0.8, 0.2], [0.1, 0.9]]},
	{"name": "gate_open", "values": ["yes", "no"], "parents": ["intruder"], "table": [[0.6, 0.4], [0.02, 0.98]]},
]}

var _network := BayesNetwork.new(NETWORK)
# What the watchman has noticed, yes or no; what he has not checked is left
# out, and the network sums over it.
var _seen: Dictionary = {}


func _ready() -> void:
	# A parent given after its child, a row short or a row not summing to 1
	# is refused here.
	if _network.problem() != "":
		push_error(_network.problem())


## He noticed `evidence` -- "dog_barks" or "gate_open" -- happen, or not.
func noticed(evidence: String, happened: bool) -> void:
	_seen[evidence] = "yes" if happened else "no"


## He stops counting `evidence`: he checked, and it meant nothing.
func forget(evidence: String) -> void:
	_seen.erase(evidence)


## The chance someone came in, from what he has noticed.
func chance_of_intruder() -> float:
	return _network.ask("intruder", _seen)[0]


## What moved his belief most -- the line to show over his head.
func reason() -> String:
	return BayesNetwork.most_moved(_network.influence("intruder", "yes", _seen))
