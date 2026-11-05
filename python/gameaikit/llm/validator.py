"""What a language model's reply may contain, and what happens when it does not.

The game asks a model to read what the player typed and answer in one fixed
shape, `{"speech": ..., "intent": ..., "argument": ...}`
(`spec/llm/reply.schema.json`). This file decides whether a reply is that
shape. It is the only door between the model and the game: a reply that
passes becomes a `Reply` the game's rules may act on, and one that does not
becomes the game's own fallback -- `intent: "unclear"`, a line the game wrote,
and the reason it was refused.

The shape follows Facade's language system, which "maps surface text into
discourse acts" -- a small, fixed set the game understands -- and leaves to
the game's own rules what each act does (Mateas and Stern, 2004). The model
does the first half and voices the character. It never decides an outcome:
`intent` is one of the game's declared acts, `argument` one of that act's
declared values, and what follows from them is the game's.

Every rule has a code, so the two validators -- this one and `ai_llm`'s
`LlmValidator` -- can be held to one answer per reply by
`spec/vectors/llm/`. The sentence after the code is each language's own.

  R1  the text is not JSON, as a whole: prose around an object is refused;
      and what the two languages' parsers read differently (a NUL escape,
      nesting deeper than MAX_DEPTH) is refused before either reads it
  R2  it is JSON, but not an object
  R3  a key of the shape is missing
  R4  a key the shape does not have
  R5  a value that is not a string
  R6  an intent the game did not declare
  R7  an argument that is not empty and not one of its intent's values
  R8  a speech that is empty, or longer than SPEECH_LIMIT characters
  R9  a speech with a line break, or another control character, in it
  R10 a speech with markup in it
  R11 a speech that contains one of the game's secrets

Complexity: one parse and one pass over the speech per secret.

When not to use it: a reply the game shows and never acts on -- a line of
flavour with no intent -- needs only R8 to R11, and a schema this strict
would refuse good prose for nothing.
"""

from __future__ import annotations

import dataclasses
import json
import re

from gameaikit.techniques import technique

# The three keys of a reply, in the order the rules walk them.
REPLY_KEYS = ("speech", "intent", "argument")

# One line a person reads in a speech bubble. The count is of characters
# (code points), as Python's `len` and Godot's `String.length` both count.
SPEECH_LIMIT = 280

# Characters a rich-text label would read as formatting rather than speech:
# HTML and BBCode brackets, Markdown's emphasis and code.
MARKUP = "<>[]*`"

# The speech as a pattern, for the schema a constraining runtime is handed:
# one to SPEECH_LIMIT characters, none of them MARKUP, a control character, a
# quote or a backslash. llama.cpp turns a pattern into a grammar over the
# string's JSON text, escapes and all, so a class without the quote and the
# backslash is the one spelling that means the same there and in JSON
# Schema, which reads the decoded string. It also drops `maxLength` when a
# pattern is present, so the length is in the pattern too (T116,
# docs/local-llm/server.md). The guard loses the straight quote; the
# validator still admits one (R10 is the check, not this).
SPEECH_PATTERN = r'^[^"\\<>\[\]*`\x00-\x1F\x7F]{1,%d}$' % SPEECH_LIMIT

# How deep objects and lists may nest. A reply is one flat object; past
# this, Godot's parser and Python's give up at different depths, so both
# validators stop at the same one first.
MAX_DEPTH = 32

# A JSON escape for the NUL character: an odd run of backslashes, then u0000.
# Godot's parser turns it into U+FFFD and Python's into a real NUL, so it is
# refused before either parser sees it.
NUL_ESCAPE = re.compile(r"(?<!\\)(?:\\\\)*\\u0000")

# Secrets are found whatever their case, folding A-Z only. Python's lower()
# and Godot's to_lower() fold other letters differently (`İ`), and a rule the
# two languages answer differently is two rules.
ASCII_LOWER = str.maketrans("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz")

# What a refused reply becomes. The game declares the line; the intent is
# always this one, so the game's rules have exactly one case to handle.
FALLBACK_INTENT = "unclear"


@dataclasses.dataclass(frozen=True)
class Declaration:
    """What one game understands, written by the game and never by the model.

    `intents` maps each discourse act to the arguments it may carry (an empty
    list: none). `fallback_speech` is what the character says when a reply is
    refused. `secrets` are strings no reply may contain -- a net, because the
    real protection is that a secret never enters a prompt.
    """

    intents: dict[str, list[str]]
    fallback_speech: str
    secrets: tuple[str, ...] = ()


@dataclasses.dataclass(frozen=True)
class Reply:
    """A reply the game may act on, or its fallback with the reason why.

    `refusal` is "" for a reply that passed every rule, and otherwise the
    code and sentence of the first rule it broke -- what a game shows beside
    the character's line, so a person can see the model was overruled.
    """

    speech: str
    intent: str
    argument: str
    refusal: str = ""

    @property
    def accepted(self) -> bool:
        """True when the model's own words passed, and the game may act on them."""
        return self.refusal == ""


@technique("llm-validator", "a language model's reply admitted only as one declared intent, or refused")
def validate(raw_text: str, declaration: Declaration) -> Reply:
    """The reply in `raw_text`, or the game's fallback with the reason.

    Never raises on anything a model can send, and never asks again: a
    refused reply is answered at once with the game's line, so a model that
    keeps getting it wrong costs one turn each time and never a stall.
    """
    wrong = why_refused(raw_text, declaration)
    if wrong:
        return fallback(declaration, wrong)
    data = json.loads(raw_text, strict=False)
    return Reply(data["speech"], data["intent"], data["argument"])


def fallback(declaration: Declaration, refusal: str) -> Reply:
    """The game's own answer, standing in for a reply that was refused."""
    return Reply(declaration.fallback_speech, FALLBACK_INTENT, "", refusal)


def why_refused(raw_text: str, declaration: Declaration) -> str:
    """The code and sentence of the first rule `raw_text` breaks, or "".

    The sentence never quotes what the model wrote: a game shows it beside
    its line, and a key, an intent or an argument the model made up is
    exactly what R10 and R11 never looked at -- markup, a secret (T93's
    review). It names only what the game declared.
    """
    data, wrong = _parsed(raw_text)
    if wrong:
        return wrong
    for key in REPLY_KEYS:
        if key not in data:
            return f"R3 the reply has no `{key}`"
    for key in sorted(data):
        if key not in REPLY_KEYS:
            return "R4 the reply has a key the shape does not"
    for key in REPLY_KEYS:
        if not isinstance(data[key], str):
            return f"R5 `{key}` is not a string"
    intent, argument = data["intent"], data["argument"]
    if intent not in declaration.intents:
        return "R6 the intent is not one this game declared"
    if argument and argument not in declaration.intents[intent]:
        return f"R7 the argument is not one `{intent}` takes"
    return why_speech_is_wrong(data["speech"], declaration.secrets)


def why_speech_is_wrong(speech: str, secrets: tuple[str, ...]) -> str:
    """R8 to R11, on one line of speech. The game's fallback is held to them too."""
    if not speech or len(speech) > SPEECH_LIMIT:
        return f"R8 the speech is {len(speech)} characters; 1 to {SPEECH_LIMIT} are allowed"
    if any(ord(character) < 32 or ord(character) == 127 for character in speech):
        return "R9 the speech is more than one line, or has a control character"
    if any(character in MARKUP for character in speech):
        return f"R10 the speech has markup in it, one of {MARKUP}"
    lowered = speech.translate(ASCII_LOWER)
    for secret in secrets:
        if secret.translate(ASCII_LOWER) in lowered:
            return "R11 the speech gives away one of the game's secrets"
    return ""


def why_declaration_is_wrong(declaration: Declaration) -> str:
    """Why a game's declaration cannot be validated against, or "".

    Checked once, when the game is built, so a typo in the game is found
    there and not on the first reply.
    """
    if not declaration.intents:
        return "the game declares no intents"
    for intent, arguments in declaration.intents.items():
        if not intent or any(not argument for argument in arguments):
            return f"intent `{intent}` is empty or has an empty argument"
    if any(not secret for secret in declaration.secrets):
        return "an empty secret would be found in every speech"
    wrong = why_speech_is_wrong(declaration.fallback_speech, declaration.secrets)
    if wrong:
        return f"the fallback speech breaks the rules it stands in for: {wrong}"
    return ""


def json_schema(declaration: Declaration) -> dict:
    """`spec/llm/reply.schema.json`, narrowed to this game: one shape per intent.

    An `anyOf` of one object per intent, sorted by name, each naming its
    intent and offering only its own arguments, or the empty one R7 allows
    every intent, and a speech held to SPEECH_PATTERN. What a runtime that
    constrains its output is handed. A convenience, not the validator: it
    cannot say that a speech holds no secret, and a runtime can ignore it.
    Measured on the pinned llama.cpp server only (docs/godot/talk.md):
    narrowed this way, it stopped sending arguments an act does not take
    (R7, T94), and with the pattern, markup (R10, T116).
    """
    shapes = []
    for name in sorted(declaration.intents):
        arguments = [*declaration.intents[name], ""]
        shapes.append({
            "type": "object",
            "properties": {
                "speech": {"type": "string", "minLength": 1, "maxLength": SPEECH_LIMIT,
                           "pattern": SPEECH_PATTERN},
                "intent": {"type": "string", "enum": [name]},
                "argument": {"type": "string", "enum": arguments},
            },
            "required": list(REPLY_KEYS),
            "additionalProperties": False,
        })
    return {"anyOf": shapes}


def _parsed(raw_text: str) -> tuple[dict, str]:
    """The reply as an object, or the R1 or R2 refusal."""
    # strict=False lets a control character through the parser, as Godot's
    # lets it through: R9 then refuses it in the speech, the same code on
    # both sides. NaN and Infinity are not JSON, and only Python's parser
    # takes them unless told not to.
    # A lone surrogate (`"\ud83d"`) is half a character: Python's parser
    # keeps it and Godot's refuses it, so it is refused here too, found by
    # the one thing it cannot do -- become UTF-8.
    wrong = _why_not_plain(raw_text)
    if wrong:
        return {}, f"R1 the reply is not JSON: {wrong}"
    try:
        data = json.loads(raw_text, strict=False, parse_constant=_not_json)
        json.dumps(data, ensure_ascii=False).encode("utf-8")
    except ValueError as error:
        return {}, f"R1 the reply is not JSON: {error}"
    if not isinstance(data, dict):
        return {}, "R2 the reply is JSON, but not an object"
    return data, ""


def _why_not_plain(raw_text: str) -> str:
    """What the two parsers would read differently, found before either reads it."""
    if "\x00" in raw_text or NUL_ESCAPE.search(raw_text):
        return "a NUL character"
    if _deepest(raw_text) > MAX_DEPTH:
        return f"nested deeper than {MAX_DEPTH}"
    return ""


def _deepest(text: str) -> int:
    """How deep objects and lists nest in `text`, counted outside strings."""
    depth = deepest = 0
    inside = escaped = False
    for character in text:
        if inside:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                inside = False
        elif character == '"':
            inside = True
        elif character in "[{":
            depth += 1
            deepest = max(deepest, depth)
        elif character in "]}":
            depth -= 1
    return deepest


def _not_json(name: str) -> object:
    """Refuse NaN and Infinity, which Python's parser takes and JSON does not."""
    raise ValueError(f"{name} is not JSON")
