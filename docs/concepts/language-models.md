# A language model as one more decider, behind a validator

<!-- doc-meta
half_life: concept
verified_on: 2026-10-29
tier: 1
source: https://www.cp.eng.chula.ac.th/~vishnu/gameResearch/story_november_2005/MateasSternTIDSE04.pdf ; https://ollama.com/blog/structured-outputs ; https://github.com/ggml-org/llama.cpp/blob/master/grammars/README.md
invalidated_if: the reply's shape, a refusal code, or gameaikit.llm's validate or replay changes
teaches: language-models
-->

> The lesson of `ai_llm` with no model and no engine: Python 3 and a
> recorded conversation. The addon itself is
> [techniques/ai_llm.md](../techniques/ai_llm.md).

## The problem it solves {#problem}

A text game has always had to read what the player types, and for a long
time that meant a parser that knew a few hundred words. *Façade* (Mateas and
Stern, 2004) read free text differently: its language system "maps surface
text into discourse acts" -- a small, fixed set like *agree*, *criticize*,
*flirt* -- and a second phase "maps discourse acts into one or more (joint)
character responses", "a strong many-to-few mapping". The thousand ways a
player says *I agree* all become one act, and the game's rules only ever
deal with the act.

A language model is good at the first phase and at voicing a character. It
is not a rule system: it can answer in prose instead of the format it was
asked for, invent an act the game never declared, ramble for a paragraph,
or say the one thing the game needed kept quiet. So the kit lets it do the
first phase only, and puts a validator between its text and the game.

## The shape and the rules {#rules}

Every reply is one JSON object, `{"speech", "intent", "argument"}`
(`spec/llm/reply.schema.json`). The game declares its intents and what
arguments each may carry; the validator refuses anything else, by the first
rule broken: not JSON as a whole (R1), not an object (R2), a missing or an
extra key (R3, R4), a value that is not a string (R5), an intent the game
did not declare (R6), an argument that is not its intent's (R7), and for
the speech -- empty or over 280 characters (R8), more than one line (R9),
markup (R10), a secret (R11).

A refused reply is never retried. It becomes the game's fallback at once:
a line the game wrote, the intent `unclear`, and the reason, which the game
shows beside the line. A model that keeps getting it wrong costs one turn
each time, and never a stall.

Two runtimes T93 weighs can constrain a model's output to a JSON schema --
llama.cpp through its grammars and the `response_format` field, Ollama
through `format` ("constrain a model's output to a specific format defined
by a JSON schema"). That is a convenience and not the validator: a schema
cannot say that an argument belongs to its intent, a runtime can ignore it,
and a recording can be wrong. The validator runs on every reply anyway.

## Run it {#run}

```bash
PYTHONPATH=python python3 -m gameaikit.llm.replay spec/llm/recordings/the-gatekeeper.json
```

Five turns with a gatekeeper. Three replies pass and the game acts on their
intent; one gives away the password and is refused (R11); one wraps its
object in prose and is refused (R1). The secret was never in the model's
instructions -- what the model is not told it cannot leak -- and R11 is the
net for the day somebody tells it.

`gameaikit.llm.replay.replay(recording, rules, state)` runs the same turns
through a game's rules: a function from the state and one validated reply
to the next state. `python/tests/test_llm.py` has one, `trust_rules`, in
six lines: a claim earns trust, a threat loses it, and the refused claim to
be royalty never counts -- because it never reached the rules.

## Why the two languages agree {#agree}

The game runs the addon's `LlmValidator`; this page runs Python's. Each
refusal in `spec/vectors/llm/replies.json` is refused by both with the same
code, and `make test-llm-vectors` runs both. Making them agree found
places where Godot's JSON parser and Python's disagree -- a trailing comma,
a number spelt `01`, half a UTF-16 character, a NUL escape, nesting a
thousand deep -- and where their lowercasing does (`İ`), so secrets are
found folding A to Z only. Each is now a case
(`spec/vectors/llm/README.md`).
