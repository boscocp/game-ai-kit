# The reply's shape, and recorded conversations

<!-- doc-meta
half_life: structure
verified_on: 2026-11-06
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: the reply's shape or the recording format changes
teaches: none
-->

> What `ai_llm` and `gameaikit.llm` agree a model's reply looks like, and
> the recordings that let a game talk to a model with none installed.

`reply.schema.json` is the one shape a reply may take: `speech`, `intent`
and `argument`, all strings, nothing else. A game narrows `intent` to the
acts it declared (`LlmValidator.json_schema()`,
`gameaikit.llm.validator.json_schema`) and hands that to a runtime that can
constrain its output, one shape per intent, so the schema also says which
arguments belong to which intent.

Since T116, `speech` carries a `pattern` (`LlmValidator.SPEECH_PATTERN`,
`gameaikit.llm.validator.SPEECH_PATTERN`). It says what R8 to R10 check:
one to 280 characters, with no line break or other control character, and
no markup. Since T129 a control character is all of Unicode's (C0, DEL
and the C1 range, U+0080 to U+009F), and a line break includes U+2028
and U+2029, the line and paragraph separators. The file writes those two
as JSON escapes, so the pattern it decodes to holds the characters
themselves: Godot's `RegEx` refuses a `\u2028` in a pattern, and every
reader of this one takes the character. The schema still cannot say that a speech holds no secret, and a
runtime may ignore it, which is why the validator checks every reply anyway.

The pattern is **stricter than the validator** in one place: it also leaves
out the straight quote and the backslash. The pinned llama.cpp server reads
a pattern against the string's JSON text, escapes and all
(`docs/local-llm/server.md`), and this is the one spelling that means the
same there and in JSON Schema. A model held to the schema cannot write
`"`; a reply from any other runtime that contains one is still accepted.
`json_schema()` always adds the pattern, so a game cannot opt out today.
That waits until a second game needs to.

`recordings/` holds conversations: a JSON object with the game's
`declaration` (intents, fallback line, secrets) and `turns`, each the line
the player typed (`player`) and the model's text, untouched (`raw`).
`RecordedRuntime.from_file` answers with the `raw` texts in order;
`python3 -m gameaikit.llm.replay` plays one through the Python validator.
`the-gatekeeper.json` was written by hand to walk every path a reply can
take, and says so; a recording from a model carries the model's name and
licence beside it (T94).

`server-answers.json` is what llama.cpp's server answered at the pinned build
when it would not take a request -- a 400, a 500, a 503 -- and its envelope
around a reply the validator refuses (T93, `docs/local-llm/server.md`).
`llm_test.gd` replays each through `HttpRuntime` with no server running and
holds them apart: the request refused (F2), no reply yet (F1), the reply
refused (an R code).
