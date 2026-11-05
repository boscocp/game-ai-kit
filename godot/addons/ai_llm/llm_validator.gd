## What a language model's reply may contain, and what happens when it does not.
##
## The only door between a model and a game. A model is asked to read what
## the player typed and answer in one shape, `{"speech", "intent",
## "argument"}` (spec/llm/reply.schema.json). `validate` takes the text it
## answered and returns an `LlmReply`: the model's words when they pass every
## rule below, and otherwise the game's fallback -- the game's own line, the
## intent `unclear`, and the reason. Never a retry, never a stall.
##
## The model never decides an outcome. The game declares the discourse acts
## it understands (`intents`, after Facade: "a strong many-to-few mapping",
## Mateas and Stern 2004) and what each may carry; the model only says which
## one the player's words were, and voices the character. What follows is the
## game's rules'.
##
##   R1  not JSON, as a whole: prose around an object is refused; and
##       what the two languages' parsers read differently (a NUL escape,
##       nesting deeper than MAX_DEPTH) is refused before either reads it
##   R2  JSON, but not an object
##   R3  a key of the shape is missing
##   R4  a key the shape does not have
##   R5  a value that is not a string
##   R6  an intent the game did not declare
##   R7  an argument that is not empty and not one of its intent's values
##   R8  a speech that is empty, or longer than SPEECH_LIMIT characters
##   R9  a speech with a line break, or another control character
##   R10 a speech with markup in it
##   R11 a speech that contains one of the game's secrets
##
## `gameaikit.llm.validator` is the same rules in Python; spec/vectors/llm/
## holds both to one code per reply. Complexity: one parse, one pass over the
## text, and one search of the speech per secret.
##
## When not to use it: a line of flavour the game shows and never acts on --
## it needs only R8 to R11, and this shape would refuse good prose for nothing.
class_name LlmValidator
extends RefCounted

## The three keys of a reply, in the order the rules walk them.
const REPLY_KEYS: Array[String] = ["speech", "intent", "argument"]

## One line in a speech bubble, counted in characters as Python counts them.
const SPEECH_LIMIT: int = 280

## What a RichTextLabel or a chat model's Markdown would read as formatting.
const MARKUP: String = "<>[]*`"

## The speech as a pattern, for the schema a constraining runtime is handed:
## one to SPEECH_LIMIT characters, none of them MARKUP, a control character,
## a quote or a backslash. llama.cpp turns a pattern into a grammar over the
## string's JSON text, escapes and all, so a class without the quote and
## the backslash is the one spelling that means the same there and in JSON
## Schema, which reads the decoded string. It also drops `maxLength` when a
## pattern is present, so the length is in the pattern too (T116,
## docs/local-llm/server.md). The guard loses the straight quote; the
## validator still admits one (R10 is the check, not this).
const SPEECH_PATTERN: String = "^[^\"\\\\<>\\[\\]*`\\x00-\\x1F\\x7F]{1,280}$"

## How deep objects and lists may nest. A reply is one flat object; past
## this, Godot's parser and Python's give up at different depths, so both
## validators stop at the same one first.
const MAX_DEPTH: int = 32

## A JSON escape for the NUL character: an odd run of backslashes, then
## u0000. Godot's parser turns it into U+FFFD and Python's into a real NUL,
## so both refuse it before parsing.
const NUL_ESCAPE: String = "(?<!\\\\)(?:\\\\\\\\)*\\\\u0000"

## The intent of every refused reply: the one case the game always handles.
const FALLBACK_INTENT: String = "unclear"

## A JSON number as RFC 8259 spells it. Godot's parser also takes `01` and
## `1.` (measured on 4.7.2); Python's refuses both, so this refuses them too.
const JSON_NUMBER: String = "^-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]+)?$"

# Intent name to the PackedStringArray of arguments it may carry.
var _intents: Dictionary = {}
var _fallback_speech: String = ""
var _secrets: PackedStringArray = PackedStringArray()
var _number: RegEx = RegEx.create_from_string(JSON_NUMBER)
var _nul_escape: RegEx = RegEx.create_from_string(NUL_ESCAPE)
# A comma just before the end of an object or a list.
var _trailing_comma: RegEx = RegEx.create_from_string(",\\s*[}\\]]")
# Something outside a string that starts like a number, `true` and `null`
# being the words that do not.
var _number_like: RegEx = RegEx.create_from_string("[-+.0-9][-+.0-9eE]*")


## A validator for one game: the discourse acts it understands (`intents`,
## each name to the arguments it may take, empty for none), the line its
## character says when a reply is refused, and the strings no reply may
## contain. Call `problem()` once after building.
func _init(intents: Dictionary, fallback_speech: String,
		secrets: PackedStringArray = PackedStringArray()) -> void:
	for name: Variant in intents:
		_intents[str(name)] = PackedStringArray(intents[name])
	_fallback_speech = fallback_speech
	_secrets = secrets


## Why this game's declaration cannot be validated against, or "". Found
## when the game is built, rather than on the first reply.
func problem() -> String:
	if _intents.is_empty():
		return "the game declares no intents"
	for intent: String in _intents:
		if intent == "" or (_intents[intent] as PackedStringArray).has(""):
			return "intent `%s` is empty or has an empty argument" % intent
	if _secrets.has(""):
		return "an empty secret would be found in every speech"
	var wrong: String = why_speech_is_wrong(_fallback_speech)
	if wrong != "":
		return "the fallback speech breaks the rules it stands in for: %s" % wrong
	return ""


## The reply in `raw_text`, or the game's fallback carrying the reason.
func validate(raw_text: String) -> LlmReply:
	var wrong: String = why_refused(raw_text)
	if wrong != "":
		return fallback(wrong, raw_text)
	var reader := JSON.new()
	reader.parse(raw_text)
	var data: Dictionary = reader.data
	return LlmReply.new(data["speech"], data["intent"], data["argument"], "", raw_text)


## The game's own answer, standing in for a reply that was refused -- or for
## no reply at all, when the runtime failed (`F1`) or the server refused
## the request (`F2`), which are not rules of this validator but are
## answered the same way.
func fallback(refusal: String, raw_text: String = "") -> LlmReply:
	return LlmReply.new(_fallback_speech, FALLBACK_INTENT, "", refusal, raw_text)


## The code and sentence of the first rule `raw_text` breaks, or "". The
## sentence never quotes what the model wrote -- a made-up key, intent or
## argument is what R10 and R11 never read, and a game shows the sentence --
## only what the game declared (T93's review).
func why_refused(raw_text: String) -> String:
	# First what the parser would take and should not, or read differently
	# from Python's -- before it reads it: a NUL escape makes it print a
	# Unicode error of its own.
	var not_strict: String = _why_not_strict_json(raw_text)
	if not_strict != "":
		return "R1 the reply is not JSON: %s" % not_strict
	var reader := JSON.new()
	# `JSON.new().parse()`, not the static parse_string: that one prints an
	# engine error on bad input (docs/godot/reading-json-in-godot.md).
	if reader.parse(raw_text) != OK:
		return "R1 the reply is not JSON: %s" % reader.get_error_message()
	if not (reader.data is Dictionary):
		return "R2 the reply is JSON, but not an object"
	var data: Dictionary = reader.data
	return _why_shape_is_wrong(data)


## R8 to R11, on one line of speech. The game's own fallback is held to them.
func why_speech_is_wrong(speech: String) -> String:
	if speech.is_empty() or speech.length() > SPEECH_LIMIT:
		return "R8 the speech is %d characters; 1 to %d are allowed" % [
			speech.length(), SPEECH_LIMIT]
	for index: int in speech.length():
		var code: int = speech.unicode_at(index)
		if code < 32 or code == 127:
			return "R9 the speech is more than one line, or has a control character"
	for character: String in MARKUP:
		if speech.contains(character):
			return "R10 the speech has markup in it, one of %s" % MARKUP
	if gives_away_a_secret(speech):
		return "R11 the speech gives away one of the game's secrets"
	return ""


## True when `text` contains one of the game's secrets, whatever the case
## of its letters A to Z. Also what `LlmConversation` asks of the
## instructions, before any request.
func gives_away_a_secret(text: String) -> bool:
	var lowered: String = _ascii_lower(text)
	for secret: String in _secrets:
		if secret != "" and lowered.contains(_ascii_lower(secret)):
			return true
	return false


# A to Z folded to a to z, and nothing else. String.to_lower() folds other
# letters too, differently from Python's lower() (`İ`), and a rule the two
# languages answer differently is two rules.
static func _ascii_lower(text: String) -> String:
	var folded: PackedStringArray = PackedStringArray()
	for character: String in text:
		var code: int = character.unicode_at(0)
		folded.append(char(code + 32) if code >= 65 and code <= 90 else character)
	return "".join(folded)


# How deep objects and lists nest, in text whose strings are already emptied.
static func _deepest(outside: String) -> int:
	var depth: int = 0
	var deepest: int = 0
	for character: String in outside:
		if character == "{" or character == "[":
			depth += 1
			deepest = maxi(deepest, depth)
		elif character == "}" or character == "]":
			depth -= 1
	return deepest


## spec/llm/reply.schema.json narrowed to this game: one shape per intent,
## `anyOf`, each naming its intent and offering only its own arguments, or
## the empty one R7 allows every intent, and a speech held to
## SPEECH_PATTERN. What a runtime that can constrain its output is handed. A
## convenience, not the validator: a runtime may ignore it, and every reply
## is validated anyway. Measured on the pinned llama.cpp server only
## (docs/godot/talk.md): with the narrowed shape it no longer sends an
## argument the act does not take (R7, T94), and with the pattern no markup
## (R10, T116).
func json_schema() -> Dictionary:
	var names: Array = _intents.keys()
	names.sort()
	return {"anyOf": names.map(_shape_of)}


# The reply's shape for one intent: its name, and only its own arguments.
func _shape_of(intent: String) -> Dictionary:
	var arguments: PackedStringArray = _intents[intent]
	var speech: Dictionary = {"type": "string", "minLength": 1, "maxLength": SPEECH_LIMIT,
		"pattern": SPEECH_PATTERN}
	var allowed: Array = Array(arguments) + [""]
	return {
		"type": "object",
		"properties": {"speech": speech, "intent": {"type": "string", "enum": [intent]},
			"argument": {"type": "string", "enum": allowed}},
		"required": REPLY_KEYS.duplicate(),
		"additionalProperties": false,
	}


## The shape and the acts, in words, for the model's instructions. Generated
## from the same declaration the replies are checked against, so the prompt
## cannot promise the model an intent the validator would refuse.
func instructions() -> String:
	var lines: PackedStringArray = PackedStringArray([
		"Answer with one JSON object and nothing else: " +
		"{\"speech\": \"...\", \"intent\": \"...\", \"argument\": \"...\"}.",
		"speech: what you say, one line, at most %d characters, no markup." % SPEECH_LIMIT,
		"intent: which of these the player's words were; argument: one of its values, or empty.",
	])
	var names: Array = _intents.keys()
	names.sort()
	for name: String in names:
		var arguments: PackedStringArray = _intents[name]
		var values: String = ", ".join(arguments) if not arguments.is_empty() else "(none)"
		lines.append("- %s: %s" % [name, values])
	return "\n".join(lines)


# R3 to R11, on content that parsed as an object.
func _why_shape_is_wrong(data: Dictionary) -> String:
	for key: String in REPLY_KEYS:
		if not data.has(key):
			return "R3 the reply has no `%s`" % key
	var keys: Array = data.keys()
	keys.sort()
	for key: Variant in keys:
		if not REPLY_KEYS.has(key):
			return "R4 the reply has a key the shape does not"
	for key: String in REPLY_KEYS:
		if not (data[key] is String):
			return "R5 `%s` is not a string" % key
	var intent: String = data["intent"]
	var argument: String = data["argument"]
	if not _intents.has(intent):
		return "R6 the intent is not one this game declared"
	if argument != "" and not (_intents[intent] as PackedStringArray).has(argument):
		return "R7 the argument is not one `%s` takes" % intent
	return why_speech_is_wrong(data["speech"])


# What Godot's parser takes and JSON does not, measured on 4.7.2: a comma
# before `}` or `]`, and a number spelt `01` or `1.`; and what it reads
# differently from Python's: a NUL escape, and nesting deep enough for one
# of them to give up. Read outside strings, except the NUL escape, so a
# speech may say "1." and end a list with ", ]".
func _why_not_strict_json(text: String) -> String:
	if _nul_escape.search(text) != null:
		return "a NUL character"
	var outside: String = _outside_strings(text)
	if _deepest(outside) > MAX_DEPTH:
		return "nested deeper than %d" % MAX_DEPTH
	if _trailing_comma.search(outside) != null:
		return "a comma before the end of an object or a list"
	for found: RegExMatch in _number_like.search_all(outside):
		if _number.search(found.get_string()) == null:
			return "`%s` is not a JSON number" % found.get_string()
	return ""


# The text with every string literal emptied to `""`, so only the structure
# between them is left to read. A quote closes a string unless the character
# before it was an escaping backslash.
func _outside_strings(text: String) -> String:
	var kept: PackedStringArray = PackedStringArray()
	var inside: bool = false
	var escaped: bool = false
	for character: String in text:
		var was_inside: bool = inside
		if character == "\"" and not escaped:
			inside = not inside
		escaped = inside and not escaped and character == "\\"
		if not (was_inside and inside):
			kept.append(character)
	return "".join(kept)
