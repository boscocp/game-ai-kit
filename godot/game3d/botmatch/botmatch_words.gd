## The names the bot match shows on its panel, map and labels, in the
## language chosen (T80).
##
## A bot's action, a posture, an errand, a zone, a way past a body, a squad's
## state, a team: each is an identifier the logic compares, so it stays
## English where it is written and is translated only here, where it is
## drawn (the owner's rule, docs/godot/localisation.md). In English the
## screen shows the identifier as it is written.
##
## When not to use it: for a sentence. A sentence is one key with named
## placeholders; these are the single words that fill them.
class_name BotMatchWords
extends RefCounted

## Every identifier the screen shows, so the table holds each one. A test
## holds this list to the names in actions.json and to the constants that
## write the others: a name added there and missing here would show English
## without a sound.
const SHOWN: Array[String] = [  # shown through tr()
	"dead", "reload", "fall back", "shoot", "move", "hold", "look",
	"stand", "crouch", "walk", "sprint",
	"resupply", "fetch power", "hide to heal",
	"head", "torso", "arms", "legs",
	"rifle", "power",
	"wait", "go round", "ask to pass", "another spot",
	"attack", "retreat",
]
## The identifiers whose English word another example's table already
## translates for its own sense -- checkers' "red" pieces, its "played" move
## -- and one key has one translation in the whole game (rule L8). These are
## shown through a key of their own.
const SAID_AS: Dictionary = {
	"blue": "blue team",  # shown through tr()
	"red": "red team",  # shown through tr()
	"played": "played by a person",  # shown through tr()
}


## `identifier` as the screen shows it in the language chosen.
static func word(identifier: String) -> String:
	return TranslationServer.translate(SAID_AS.get(identifier, identifier))
