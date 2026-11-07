# ai_llm — a language model behind a validator

<!-- doc-meta
half_life: practice
verified_on: 2026-10-29
tier: 2
source: https://www.cp.eng.chula.ac.th/~vishnu/gameResearch/story_november_2005/MateasSternTIDSE04.pdf ; https://docs.godotengine.org/en/4.7/classes/class_httprequest.html ; https://ollama.com/blog/structured-outputs
invalidated_if: the kit's LlmValidator, LlmReply, LlmRuntime, RecordedRuntime, HttpRuntime or LlmConversation signatures change, the reply's shape or its refusal codes change, or T94's game lands and this page does not name it
teaches: language-models
-->

> Português: [ai_llm.pt-BR.md](ai_llm.pt-BR.md). The words that stay in
> English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

Which of the game's discourse acts the player's words were -- and nothing
else. The player types a line; a language model reads it and answers in one
fixed shape, `{"speech", "intent", "argument"}`: what the character says,
which act the line was (`intent`, one the game declared), and one of that
act's declared values (`argument`). `LlmValidator` then rules on the text.
A reply that passes every rule becomes an `LlmReply` the game's rules act
on; one that does not becomes the game's fallback -- its own line, the
intent `unclear`, and in `refusal` the reason. What follows from an act --
trust gained, a door opened -- is decided by the game, never by the model.
The shape is *Façade*'s: its language system "maps surface text into
discourse acts", a small fixed set, and the game's own rules map those to
what the characters do (Mateas and Stern, 2004).

Invariant 7 holds the addon to two things, and `check_llm_validated.py` to
both: **the model never blocks a frame** -- a runtime answers by a signal,
never inside the call -- and **nothing it returns becomes an action
without passing the validator**.

## When not to use it {#when-not}

A decision the game can make with rules: a model is slow (seconds, not
microseconds), costs a GPU to run live, and is wrong in ways no test
enumerates -- every one of those is paid for here only because typed text
cannot be read any other way. A line of flavour the game never acts on:
it needs R8 to R11, not the whole shape. And a game that cannot afford a
refusal: some replies will be refused -- how many, for a given model, is
T93's to measure -- and the player then hears the fallback -- design the conversation so that "say that again" is
a fair answer.

## Where to watch it {#watch}

- `make demo-talk`, *talk your way past the guard* (tier 2): keys 1-9
  say a recorded line, V shows the act the model read, the rule that fired,
  trust and suspicion; Tab types to a live local model (tier 3).
- With nothing but Python (tier 1),
  `PYTHONPATH=python python3 -m gameaikit.llm.replay spec/llm/recordings/the-gatekeeper.json`
  plays a recorded conversation and prints, for each turn, the act the
  game acted on or the reason the reply was refused. The minimal example
  below is run by its test.
- `make test-llm-vectors` runs both validators -- Python's and the
  addon's -- over every reply in `spec/vectors/llm/`, and prints the count.
- Which demo uses which technique, both ways: [the catalogue](catalogue.md#ai_llm).

## In this kit {#in-this-kit}

`godot/addons/ai_llm/` is six files. `llm_validator.gd` holds the rules,
each with a code; read its header first. `llm_reply.gd` is what it builds.
`llm_runtime.gd` is the port a request goes through; `recorded_runtime.gd`
answers from a recording and `http_runtime.gd` from a local server (T93
pins and measures one). `llm_conversation.gd` holds the history, the one
request in flight and the thinking state. The rules:

| code | a reply is refused when |
|---|---|
| R1 | the text is not JSON as a whole -- prose around an object, a code fence, a trailing comma -- or holds what the two languages' parsers read differently: a NUL escape, nesting deeper than 32 |
| R2 | it is JSON, but not an object |
| R3, R4 | a key of the shape is missing, or there is one the shape does not have |
| R5 | a value is not a string |
| R6 | `intent` is not one the game declared |
| R7 | `argument` is not empty and not one of that intent's values |
| R8 | `speech` is empty, or longer than 280 characters |
| R9, R10 | `speech` has a line break or control character, or a format control (Unicode's Cf: zero-width characters, bidirectional marks and overrides, the soft hyphen), or markup (`<>[]*` and the backtick) |
| R11 | `speech` contains one of the game's secrets, the case of A to Z ignored (only those letters: Python and Godot fold the others differently) |
| F1 | no reply came at all: the runtime failed or timed out |
| F2 | the server refused the request itself, and said why (any HTTP error but 503): it will refuse every turn until the request is fixed, so it is not F1 |

The knobs that matter:

| knob | where | what it changes |
|---|---|---|
| the acts | `LlmValidator.new(intents, ...)` | which discourse acts exist, and the arguments each may carry |
| the fallback | `LlmValidator.new(..., fallback_speech, ...)` | what the character says when a reply is refused; held to R8 to R11 itself |
| the secrets | `LlmValidator.new(..., secrets)` | strings no reply may contain -- a net: a secret never enters a prompt |
| the wait | `RecordedRuntime.frames_to_wait` | how many frames a recorded answer takes; at least one |
| the server | `HttpRuntime.new(endpoint)`, `timeout_seconds` | where the request goes, and when it is given up on |

## In your own project {#your-project}

### What to copy {#copy}

From the library: unzip `ai_llm-<version>.zip` into your project's
root, `res://` -- [using the library](using-the-library.md) has every step,
the Python wheel too. Or copy it from a checkout:

One folder: `godot/addons/ai_llm/`. It needs nothing else, not even
`ai_core`. Open the project once, or run `godot --headless --import`, so
Godot registers its classes. A recording is any JSON file whose `turns`
each carry a `raw` text, as `spec/llm/recordings/the-gatekeeper.json`
does; the Python twin, which replays one with no engine, is
`python/gameaikit/llm/`.

### A minimal example {#example}

A gatekeeper of yours, voiced by two recorded replies. The first passes and
earns trust; the second tried to open the gate itself, in prose around the
JSON, and is refused. This file is run by `gatekeeper_example_test.gd`, and
the gate holds the page equal to it.

<!-- example: godot/test/ai_llm/gatekeeper_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_llm.md, run by
# gatekeeper_example_test.gd. A gatekeeper of your own, voiced by recorded
# replies: the model says which act the player's words were, and this
# script -- never the model -- decides whether the gate opens.
extends Node

## What the gatekeeper said, and why: the act the game acted on, or the
## reason the model's reply was refused. Show both, beside the line.
signal spoke(line: String, why: String)

# What a model once answered, untouched. The second tried to open the gate
# itself, in prose around the JSON: it is refused, and the game's line
# stands in for it.
const RECORDED: PackedStringArray = [
	'{"speech": "A merchant? At this hour?", "intent": "claim", "argument": "merchant"}',
	'Sure! {"speech": "Fine, go in.", "intent": "open_the_gate", "argument": ""}',
]

## How far the gatekeeper trusts the player. The game's number, not the model's.
var trust: int = 0

var _conversation: LlmConversation


func _ready() -> void:
	var runtime := RecordedRuntime.new(RECORDED)
	add_child(runtime)
	var validator := LlmValidator.new(
		{"greet": [], "claim": ["merchant", "soldier"], "threaten": []},
		"Say that again, slower.", PackedStringArray(["owl-eyes"]))
	_conversation = LlmConversation.new(runtime, validator,
		"You guard a city gate at night. You are tired, and you trust nobody.")
	# An undeclared intent, an empty secret, a secret in the instructions:
	# refused here, before anything is sent.
	if _conversation.problem() != "":
		push_error(_conversation.problem())
	_conversation.answered.connect(_on_answered)


## Sends what the player typed; the answer comes by `spoke`, frames later.
func ask(line: String) -> Error:
	return _conversation.say(line)


## True while the gatekeeper is thinking: draw it so, and keep the game running.
func is_thinking() -> bool:
	return _conversation.is_thinking()


## The game's rule, the only one that opens the gate.
func gate_is_open() -> bool:
	return trust >= 2


# What each act is worth. A reply that was refused arrives as `unclear`,
# which is worth nothing.
func _on_answered(reply: LlmReply) -> void:
	if reply.intent == "claim" and reply.argument == "merchant":
		trust += 1
	elif reply.intent == "threaten":
		trust -= 2
	var why: String = "%s %s" % [reply.intent, reply.argument] if reply.is_accepted() \
		else reply.refusal
	spoke.emit(reply.speech, why.strip_edges())
```

### What you implement {#implement}

The acts and what each is worth. Declare the discourse acts your game
understands -- a handful, not a hundred -- and write, in your own code, what
each does to your game's state; `unclear` is the one every game must
handle, because every refusal arrives as it. The instructions: who the
character is, in a sentence or two, with no secret in them -- the
conversation refuses to start if one is there, and the shape and the acts
are appended from the validator, so the prompt cannot promise an act the
rules would refuse. And the waiting: `say` returns at once, `answered`
comes later; draw the character thinking while `is_thinking()` is true,
and show each reply's `refusal` beside the line when it is not empty, so a
player can see the model was overruled. Never read `raw_text`, nor
listen to a runtime's `replied`: both are the text nobody validated, and
the gate refuses them outside the addon. Listen to `answered`. A reply
is read-only -- writing `intent` after the ruling is refused at run
time -- and a conversation dies with its runtime: free them together.

## Deeper {#deeper}

- Why a model's reply is validated, and what the rules are for, in Python
  only: [concepts/language-models.md](../concepts/language-models.md).
- Measured: an `HTTPRequest` and the frame, threads on and off:
  [godot/llm-requests.md](../godot/llm-requests.md).
- Where the field puts language models, and what the kit has of them:
  [the literature and the kit](../concepts/the-literature-and-the-kit.md).
