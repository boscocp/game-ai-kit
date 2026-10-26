## A sentence as an AI keeps it: its English key and the values that fill
## it, `[key, {name: value}]` -- so the AI's state never depends on the
## language on screen (T80's review).
##
## The key is the English text with named placeholders, the same key the
## translation tables hold. A value is a number, an identifier, or another
## sentence. `english` writes it for a log, a test or an overlay;
## `translated` writes it for the screen, in the language chosen, wording
## each identifier with the demo's own `word` (its `*Words.word`).
##
## When not to use it: for a sentence written where it is shown. That one
## is a `tr()` call with its values, there and then.
class_name Sentence
extends RefCounted


## The sentence `key` with `values`, as the AI keeps it.
static func of(key: String, values: Dictionary = {}) -> Array:
	return [key, values]


## `sentence` in English: its key filled with its values, a value that is a
## sentence written in English too. "" for an empty sentence.
static func english(sentence: Array) -> String:
	if sentence.is_empty():
		return ""
	var values: Dictionary = {}
	for name: Variant in sentence[1]:
		var value: Variant = sentence[1][name]
		values[name] = english(value) if value is Array else value
	return (sentence[0] as String).format(values)


## `sentence` in the language chosen: its key translated, every value that
## is a sentence translated too, and every value that is a word passed
## through `word` -- which returns an identifier's translation, or the text
## itself when it has none.
static func translated(sentence: Array, word: Callable) -> String:
	if sentence.is_empty():
		return ""
	var values: Dictionary = {}
	for name: Variant in sentence[1]:
		var value: Variant = sentence[1][name]
		if value is Array:
			values[name] = translated(value, word)
		elif value is String:
			values[name] = word.call(value)
		else:
			values[name] = value
	return TranslationServer.translate(sentence[0]).format(values)
