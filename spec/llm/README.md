# The reply's shape, and recorded conversations

<!-- doc-meta
half_life: structure
verified_on: 2026-10-29
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
constrain its output. The schema cannot say everything -- that an argument
belongs to its intent, that a speech holds no line break, markup or secret
-- which is why the validator checks every reply anyway.

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
