# ai_sifting — which moments are worth telling?

<!-- doc-meta
half_life: practice
verified_on: 2026-11-11
tier: 1
source: https://github.com/mkremins/winnow
invalidated_if: the kit's StorySifter or SiftPattern signature changes, a pattern's keys change, or the valley's chronicle is renamed
teaches: story-sifting
-->

> Português: [ai_sifting.pt-BR.md](ai_sifting.pt-BR.md). The words that
> stay in English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

Which moments of a record of events are worth telling. A simulation
writes down everything that happens -- a deed, a fact that changed
overnight -- and most of it is not a story. A story is a shape among the
events: the barn burned, and later it was rebuilt; the bridge came down
for the third time. Story sifting [Ryan 2018] is finding those shapes in
the record after the fact, rather than planning them in advance.

`StorySifter` does it as Felt does [Kreminski, Dickinson & Wardrip-Fruin
2019]: a designer writes a **pattern** -- the events to find, each named;
**variables** (`?place`) that join them, so two events are about the same
place; an order (`before`); and events that must **not** be there
(`unless`), between two of the found ones or before or after one. The
sifter returns every match, each with the events that made it and what
each variable was bound to. What to do with a match -- a line of a
chronicle, a villager's gossip -- is the game's.

## When not to use it {#when-not}

When the record grows while the game runs and the stories are wanted
every frame: sifting the whole record again each time repeats all the
work, and a pattern of k events costs up to n^k tries. Winnow [Kreminski,
Dickinson & Mateas 2021] keeps the partial matches and extends them as
each event arrives; it is not in the kit. When the world should *act* on
a story: a match is something to tell, and a villager, a price or a door
that read it would let a designer's choice of stories change the game --
those read the facts. And when the question is a number -- how many days
between, how much was lost: a pattern asks only "these events, in this
order, and not those"; put the number in the events.

## Where to watch it {#watch}

- `make demo-valley` -- do a deed a day (burn the barn, pull the bridge
  down), end a few days with N, then press **C**. The panel turns to the
  valley's chronicle: each line the patterns found -- the market out of
  bread after a deed, the barn rebuilt, the third time the same deed was
  done to a place -- and under it, the events it matched. C again goes
  back to the villagers' reasons.
- Which demo uses which technique, both ways: the
  [catalogue](catalogue.md).

## In this kit {#in-this-kit}

`godot/game/valley/valley_chronicle.gd` derives the valley's events from
its record of deeds -- each night's changed facts, then that day's deeds
-- every time it is told, and never saves them (ADR 0025 keeps deeds and
nothing derived). Its patterns are `godot/game/valley/chronicle.json`, and
each pattern's sentence is in `ValleyPanel.CHRONICLE`. The knobs that
matter:

| knob | where | what it changes |
|---|---|---|
| `find` | the pattern | the events to find, each `{as, where}`: a name, and the fields an event must have |
| a variable | a value `"?name"` in a `where` | joins events: the first binds it, later ones must hold the same value |
| `before` | the pattern, pairs of names | the first found earlier in the record than the second |
| `unless` | the pattern, each `{where, after?, before?}` | an event that must not lie between `after` and `before`; "the third time" is three finds and three `unless` |
| the record | the first argument to `sift` | an `Array` of `Dictionary`, in the order things happened; an event is its index |

Two values are the same only when they are the same kind: `1` and `1.0`
are one number, and `false` is never `0`, in GDScript and in Python.
`gameaikit.sifting` is the twin, and `spec/vectors/sifting/` holds both to
the same matches.

## In your own project {#your-project}

### What to copy {#copy}

From the library: unzip `ai_sifting-<version>.zip` into your project's
root, `res://` -- [using the library](using-the-library.md) has every step,
the Python wheel too. Or copy it from a checkout:

One folder: `godot/addons/ai_sifting/`. It uses nothing else, not even
`ai_core`. Open the project once, or run `godot --headless --import`, so
Godot registers its classes.

### A minimal example {#example}

A tavern keeper of your own who retells what happened in town. The game
writes an event each time something happens; the keeper sifts them for
one story -- a thief caught in the shop they stole from, and only the
theft the catch answered. This file is run by `gossip_example_test.gd`,
and the gate holds the page equal to it.

<!-- example: godot/test/ai_sifting/gossip_example.gd -->
```gdscript
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
```

### What you implement {#implement}

The record: append an event, a `Dictionary` of plain values -- text,
numbers, true or false -- whenever something happens that a story could
be about, and never edit one after. Give every event the fields your
patterns ask for (`what`, `who`, `where`, a day); an event without a
field a pattern names does not match it. Then the patterns, as data, and
what a match becomes: a sentence from the bindings and the found events'
fields, shown beside those events so the player can see why it was told.
Call `SiftPattern.problem(pattern)` once: `""` means it is sound, and
anything else -- a misspelt key, an `unless` bounded by a name nobody
found -- starts with its rule, P1 to P5. Hand the sifter the record and
read what it returns; it writes nothing into the record, and the tests
hold that.

## Deeper {#deeper}

- How the valley remembers, and what it refuses to keep:
  [concepts/karma-and-world-memory.md](../concepts/karma-and-world-memory.md)
  and [ADR 0025](../adr/0025-a-save-is-a-record-of-deeds.md).
- The game itself: [godot/valley.md](../godot/valley.md).
- Where story sifting sits among the field's techniques:
  [concepts/the-literature-and-the-kit.md](../concepts/the-literature-and-the-kit.md).
