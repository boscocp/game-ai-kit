## Every example in the kit, as the menu shows it: read from
## `catalogue.json`, the one list the menu and `check_demos.py` share.
##
## A card carries what the AI decides, the techniques that decide it with the
## part each plays, what to watch on screen, the keys, and the concept page.
## The file names a technique once, in its own table, and a card refers to it
## by key; this reader puts the name back, so the menu never shows a key.
class_name ExampleCatalogue
extends RefCounted

const PATH: String = "res://menu/catalogue.json"

## One card per example, in the order the file lists them. Each is the
## file's own dictionary with `techniques` rewritten as `[name, part]` pairs.
var cards: Array[Dictionary] = []
## Why the file could not be read, or "" when it was.
var problem: String = ""


## Read the catalogue at `path`. A file that cannot be read leaves `cards`
## empty and says why in `problem`, so the menu can say it rather than crash.
static func load_from(path: String = PATH) -> ExampleCatalogue:
	var catalogue := ExampleCatalogue.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not (parsed.get("examples") is Array) \
			or not (parsed.get("techniques") is Dictionary):
		var problem: String = TranslationServer.translate("{path} is not a catalogue: it needs `examples` and `techniques`")
		catalogue.problem = problem.format({path = path})
		return catalogue
	for entry: Variant in parsed["examples"]:
		catalogue.cards.append(_card_of(entry as Dictionary, parsed["techniques"]))
	return catalogue


# A card with each technique's key replaced by its name. An unknown key is
# shown as it is: check_demos.py refuses it, and the menu need not hide it.
static func _card_of(entry: Dictionary, techniques: Dictionary) -> Dictionary:
	var card: Dictionary = entry.duplicate(true)
	var named: Array[Array] = []
	for used: Dictionary in entry.get("techniques", []):
		var key: String = used.get("technique", "")
		var known: Dictionary = techniques.get(key, {})
		named.append([known.get("name", key), used.get("part", "")])
	card["techniques"] = named
	return card


## The card's words, as the menu lays them out, in BBCode: each heading in
## the accent colour, what is under it indented as a block, so a wrapped line
## stays under its heading rather than running back to the margin. All of it
## is in the language the menu speaks: the headings since T78, and since T131
## what the catalogue says under them, its English a key of `menu.csv` that
## `check_translations_game.py` (L10) holds to the file.
static func text_of(card: Dictionary, accent: Color) -> String:
	var techniques: PackedStringArray = []
	for technique: Array in card.get("techniques", []):
		techniques.append("[b]%s[/b] -- %s" % [said(technique[0]), said(technique[1])])
	# In the repository, not in the executable: someone holding only the zip
	# has neither the page nor `make` (wave 59's review), and is told so.
	var more: String = TranslationServer.translate("in the kit's repository: {docs}; [b]make {target}[/b] opens it on its own").format(
		{docs = plain(card.get("docs", "")), target = plain(card.get("target", ""))})
	var keys: String = TranslationServer.translate("{keys}; Esc comes back here").format(
		{keys = said(card.get("controls", ""))})
	var sections: Array[Array] = [
		[TranslationServer.translate("What the AI decides"), said(card.get("decides", ""))],
		[TranslationServer.translate("How it decides"), "\n".join(techniques)],
		[TranslationServer.translate("What to watch"), said(card.get("watch", ""))],
		[TranslationServer.translate("Keys"), keys],
		[TranslationServer.translate("Read more"), more],
	]
	var text: PackedStringArray = []
	for section: Array in sections:
		text.append("[color=#%s][b]%s[/b][/color]\n[indent]%s[/indent]" % [accent.to_html(false), section[0], section[1]])
	return "\n\n".join(text)


## The catalogue's English `words` in the language the menu speaks, ready for
## a BBCode label. A static function, so `TranslationServer` rather than tr().
static func said(words: Variant) -> String:
	return plain(TranslationServer.translate(str(words)))


## Words for a BBCode label, with any bracket shown rather than read as a tag.
static func plain(words: Variant) -> String:
	return str(words).replace("[", "[lb]")
