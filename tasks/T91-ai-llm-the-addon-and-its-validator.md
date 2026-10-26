# T91 — `ai_llm`: the addon, its validator, and invariant 7's gate

Size: M · Prereqs: none · Files: `godot/addons/ai_llm/`, `godot/test/ai_llm/`, `modules/ai_llm.json`, `python/gameaikit/llm/`, `python/tests/`, `spec/llm/`, `spec/vectors/llm/`, `scripts/check_llm_validated.py`, `Makefile`, `CLAUDE.md`, `docs/techniques/`, `docs/concepts/`

## Goal

The owner, 2026-10-26, answering T73's question 7: `ai_llm` "entra agora"
-- it goes on the roadmap now, not after the library (T64). Its example is
the owner's own idea: "algum exemplo de jogo textual de narrativa que
envolve algum desafio narrativo de conversar com um agente por texto
rodando uma LLM local" -- a text narrative game where you converse with an
agent run by a local LLM and must overcome a narrative challenge. That game
is T93; the local runtime is T92; this task is the addon and the rule that
holds it.

Invariant 7, throughout: **the LLM never blocks a frame, and nothing it
returns becomes an action without passing a validator.** CLAUDE.md lists
its gate as "none yet -- arrives with the addon". This is the addon, so
this task creates the gate, born with planted cases it must reject
(invariant 4).

The shape follows the oldest well-documented game that understood typed
text, *Façade*: its language system "maps surface text into discourse
acts", a small fixed set, and a second phase "maps discourse acts into one
or more (joint) character responses" -- "a strong many-to-few mapping"
[Mateas & Stern 2004]. Here the LLM does the first phase and voices the
character; the game's rules do the second. The LLM never decides an
outcome.

## Decisions written down first (the owner confirms in review)

- **The reply is one fixed shape**: `{"speech": string, "intent": string,
  "argument": string}`, declared in `spec/llm/reply.schema.json`. `intent`
  is one of a list the *game* declares (the discourse acts it
  understands), `argument` one of that intent's declared values or empty;
  `speech` one line, at most 280 characters, no markup. Anything else is
  refused, and a refused reply becomes the game's declared fallback
  (`intent: "unclear"` with a line the game wrote) -- never a retry loop,
  never a stall.
- **Constrained decoding is a convenience, not the validator.** The
  runtimes T92 weighs can constrain output to a JSON schema (llama.cpp
  passes it "inside the `response_format` body field" of
  `/chat/completions`; Ollama "constrain[s] a model's output to a specific
  format defined by a JSON schema" through `format`). The validator runs
  on every reply anyway: a model, a runtime or a recording can be wrong.
- **Never on the frame**: requests go through Godot's `HTTPRequest` with
  `use_threads` on, one in flight per conversation, a fixed timeout; the
  answer arrives by `request_completed`, and the game shows the character
  thinking until then. Godot's docs say `request()` "does not imply that
  the server has responded", but also that without threads it can fail
  with `ERR_CANT_CONNECT` "if not using thread and the HTTPClient cannot
  connect" -- so whether connecting blocks without threads is measured
  here (`docs/godot/`), not assumed.
- **A runtime is a port**: `LlmRuntime` (send a request, signal a reply)
  with two implementations -- `RecordedRuntime`, which answers from
  committed recordings and needs nothing installed (tier 1 and 2), and
  `HttpRuntime` for T92's local server (tier 3). If T64's prefix ADR has
  landed, the port is named by it; otherwise T64's rename covers it.
- **What the LLM is not told it cannot leak**: the game's secrets (a
  password, the truth of a case) never enter a prompt. The validator also
  refuses a reply containing any string the game marks secret, as a net.

## Steps

1. Read Godot's `HTTPRequest` and `JSON` pages for the pinned version
   (CLAUDE.md: documentation before the rule), then measure a request to a
   local stub server with threads on and off: the worst frame time each.
   Findings in `docs/godot/` with the source URL and `verified_on`.
2. `python/gameaikit/llm/`: the validator, the fallback, and a replay of a
   recorded conversation through a game's rules -- tier 1, standard
   library only, no model.
3. `godot/addons/ai_llm/`: `LlmValidator` (the same rules, held to Python
   by vectors), `LlmReply` (built only by the validator), `LlmRuntime`,
   `RecordedRuntime`, `HttpRuntime`, `LlmConversation` (the history, the
   one request in flight, the thinking state).
4. `spec/vectors/llm/`: replies the validator must accept and ones it must
   refuse -- not JSON, a missing key, an extra key, an intent not
   declared, an argument not of its intent, two lines, 281 characters, a
   secret in the speech, a JSON object wrapped in prose -- read by both
   languages (`make test-llm-vectors`).
5. **Invariant 7's gate**, `scripts/check_llm_validated.py`, exit codes
   0/1/2, `--self-test`:
   - V1 no GDScript outside `ai_llm` uses `HTTPRequest`, `HTTPClient` or a
     raw TCP stream to reach a runtime;
   - V2 no GDScript outside `ai_llm`'s validator constructs an `LlmReply`,
     and none outside the addon reads a reply's raw text;
   - V3 nothing in `ai_llm` waits on the frame: no `OS.delay_msec`, no
     `Thread.wait_to_finish` outside teardown, no polling loop, and every
     `HTTPRequest` it creates sets `use_threads`;
   - V4 every refusal vector is refused by both validators.
   Planted cases, each must be rejected: a game script that opens its own
   `HTTPRequest`; one that builds an `LlmReply` by hand; a `while` loop
   polling an `HTTPClient`; a validator that accepts an undeclared intent.
   In `make check` and `make lint-selftests`.
6. `CLAUDE.md`: invariant 7's row names the gate; `modules/ai_llm.json`;
   the technique page in both languages (T74's shape), its minimal example
   a `RecordedRuntime` conversation; the literature page's LLM row names
   `ai_llm`.

## Acceptance

```bash
python3 scripts/check_llm_validated.py
python3 scripts/check_llm_validated.py --self-test
make test-llm-vectors
python3 -m unittest discover -s python/tests -t python -p "test_llm*.py"
make test-godot-some SUITES="test/ai_llm"
python3 scripts/check_addon_deps.py
python3 scripts/check_translations_docs.py
python3 scripts/check_literature_table.py
make lint-modules
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Read `LlmValidator` and its page: could a person who has never used an
LLM say, from them, what a reply may contain and what happens when it does
not? Is it clear that the game, not the model, decides?

How invariant 13 is met: by the game (T93) -- every reply is shown with
its intent and argument as the validator accepted them, or with the
reason it was refused, beside the character's line. This task gives the
game what to show: `LlmReply` carries the raw text's refusal reason.

References, opened on 2026-10-26: Mateas, M., Stern, A. "Natural Language
Understanding in Façade: Surface-text Processing." TIDSE 2004 (per the
file's name), sections 1-3
<https://www.cp.eng.chula.ac.th/~vishnu/gameResearch/story_november_2005/MateasSternTIDSE04.pdf>;
llama.cpp, `grammars/README.md`
<https://github.com/ggml-org/llama.cpp/blob/master/grammars/README.md>;
Ollama, "Structured outputs", 2024-12-06
<https://ollama.com/blog/structured-outputs>; Godot, `HTTPRequest`
<https://docs.godotengine.org/en/stable/classes/class_httprequest.html>
(the stable page; step 1 reads the pinned version's).
