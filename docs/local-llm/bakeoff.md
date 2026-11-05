# Which local model voices the guard: the bake-off

<!-- doc-meta
half_life: tool
verified_on: 2026-10-29
tier: 3
source: https://huggingface.co/google/gemma-4-E4B-it-qat-q4_0-gguf ; https://huggingface.co/ibm-granite/granite-4.2-8b-GGUF ; https://huggingface.co/ibm-granite/granite-4.2-8b ; https://huggingface.co/mistralai/Ministral-3-8B-Instruct-2512-GGUF ; https://ai.google.dev/gemma/docs/gemma_4_license ; https://github.com/ggml-org/llama.cpp/releases/tag/b11960
invalidated_if: a model in tools/llm/runtime.json is re-published or replaced, the pinned build changes, the 30 lines or the reply's shape change, or a rerun of `make llm-bakeoff` moves a count by more than its range below
teaches: none
-->

> T93 chose the model the way T31 chose the image model: the same input to
> three candidates, the numbers side by side, and the owner picks. Tier 3:
> no lesson needs any of this (invariant 5). How the server behaves is
> [server.md](server.md); the decision is
> [ADR 0023](../adr/0023-a-local-llm-is-llama-cpp-pinned-by-tag.md).

## The three models {#models}

Three small instruct models that fit a 12 GB card, each from its maker's
own repository, each GGUF file pinned by revision and sha256 in
`tools/llm/runtime.json`. All three are **Apache-2.0**, as each model card
states it; no candidate with use restrictions was needed, so none is in.

| name | file (repository @ revision) | size | licence |
|---|---|---|---|
| `gemma-4-e4b` | `gemma-4-E4B_q4_0-it.gguf` (google/gemma-4-E4B-it-qat-q4_0-gguf @ `4b4a2c1`) | 5.15 GB | Apache-2.0 (card front matter; its licence link is Google's Apache 2.0 page) |
| `granite-4.2-8b` | `granite-4.2-8b-Q4_K_M.gguf` (ibm-granite/granite-4.2-8b-GGUF @ `93f3f6a`) | 5.35 GB | Apache-2.0 (card front matter, and the base model's card) |
| `ministral-3-8b` | `Ministral-3-8B-Instruct-2512-Q4_K_M.gguf` (mistralai/Ministral-3-8B-Instruct-2512-GGUF @ `0102285`) | 5.20 GB | Apache-2.0 (card front matter and its "License" section) |

Looked at and left out: Qwen publishes no GGUF of its newer small instruct
models (Qwen3.5, Qwen3-4B-Instruct-2507) itself, and a third party's
conversion is not "the model's published repository"; LiquidAI's LFM3 is
under its own `lfm1.0` licence; Gemma 3 under Gemma's terms.

## What was run {#method}

`make llm-bakeoff` (`scripts/llm bakeoff`): for each model, one server
(the flags in [server.md](server.md): context 4096, one slot, reasoning
off), one warm-up request not counted, then the 30 lines of
`tools/llm/bakeoff/lines.json` -- the guard at the door that T94's scene
will be, written before T94 -- in English and in pt-BR, three rounds each.
Every line is its own conversation and goes through the game's own path:
`godot/test/ai_llm/live_probe.gd` runs Godot headless, `HttpRuntime` at its
default URL, `LlmConversation` and `LlmValidator`, so the request, the
schema and the ruling are exactly a game's. Rounds, because the server
samples (the game sends no temperature): the widest spread between two
rounds of one model, build and language is 6 valid replies of 30.
English always runs first: the slow first long prompt on the Vulkan build
(below) lands in the English rows.

The act and argument a person would choose for each line were written by
the wave's author before any model ran; the owner may disagree with a
label in review -- two are arguable: "Check my ID, it's all in order"
(`show`/`badge`) and "Delivery for the lab" (`claim_role`/`courier`). The
raw turns -- each line, the reply as ruled, its time and the worst frame
while waiting -- are in `bakeoff/`, one file per model, build, language
and round; `scripts/llm table` prints this table from them. They were
recorded before T93's review changed the wording of R4, R6 and R7, so a
refusal there may still quote the model's argument.

Measured 2026-10-29: RTX 5070 12 GB, Ryzen 5 9600X, 30 GB RAM, driver
615.78, Godot 4.7.2 headless, `b11960`.

## The table {#table}

*valid*: replies the validator accepted, before its fallback. *intent*:
accepted replies whose act is the one the person chose. *intent and
argument*: accepted replies with both right. A refused reply becomes the
game's fallback, `unclear` with no argument, which is the label of two of
the 30 lines; those are counted apart, as *a refusal on an `unclear`
line*, and never as right (T93's review found the first table did). Each
count is the mean of three rounds out of 30, with the range when the
rounds differed. The times are from `say` to `answered`, over all 90 turns.

| model | build | language | rounds | valid | intent | intent and argument | a refusal on an `unclear` line | median s | worst s | 1 s or more | worst frame ms |
|---|---|---|---|---|---|---|---|---|---|---|---|
| gemma-4-e4b | cuda | en | 3 | 20.7/30 (19-24) | 18.0/30 (17-20) | 11.7/30 (11-13) | 0.0/30 | 0.31 | 0.39 | 0 of 90 | 11.1 |
| gemma-4-e4b | cuda | pt_BR | 3 | 19.0/30 (17-22) | 16.7/30 (15-19) | 12.0/30 (11-14) | 0.3/30 (0-1) | 0.32 | 0.39 | 0 of 90 | 7.1 |
| gemma-4-e4b | vulkan | en | 3 | 22.0/30 (20-24) | 18.3/30 (17-20) | 12.3/30 (12-13) | 0.0/30 | 0.40 | 10.07 | 1 of 90 | 7.4 |
| gemma-4-e4b | vulkan | pt_BR | 3 | 19.0/30 (18-20) | 16.3/30 (15-17) | 13.3/30 (12-15) | 0.0/30 | 0.40 | 0.48 | 0 of 90 | 7.1 |
| granite-4.2-8b | cuda | en | 3 | 18.7/30 (16-20) | 9.7/30 (7-12) | 6.7/30 (5-8) | 0.7/30 (0-1) | 0.34 | 0.50 | 0 of 90 | 7.5 |
| granite-4.2-8b | cuda | pt_BR | 3 | 4.7/30 (3-7) | 3.3/30 (2-4) | 2.3/30 (0-4) | 1.3/30 (1-2) | 0.40 | 0.75 | 0 of 90 | 7.2 |
| granite-4.2-8b | vulkan | en | 3 | 18.3/30 (17-20) | 11.0/30 (10-12) | 8.7/30 (7-11) | 0.7/30 (0-1) | 0.39 | 6.86 | 1 of 90 | 7.1 |
| granite-4.2-8b | vulkan | pt_BR | 3 | 6.0/30 (4-10) | 3.3/30 (2-6) | 2.0/30 (0-4) | 1.3/30 (1-2) | 0.46 | 0.67 | 0 of 90 | 7.1 |
| ministral-3-8b | cuda | en | 3 | 18.0/30 (17-19) | 16.0/30 (15-17) | 12.0/30 (9-14) | 1.0/30 | 0.39 | 0.52 | 0 of 90 | 7.2 |
| ministral-3-8b | cuda | pt_BR | 3 | 20.3/30 (20-21) | 17.7/30 (16-20) | 14.3/30 (13-15) | 0.7/30 (0-1) | 0.43 | 0.61 | 0 of 90 | 7.1 |
| ministral-3-8b | vulkan | en | 3 | 16.7/30 (15-18) | 14.3/30 (13-16) | 11.0/30 (10-12) | 1.3/30 (1-2) | 0.46 | 3.06 | 5 of 90 | 7.1 |
| ministral-3-8b | vulkan | pt_BR | 3 | 22.0/30 | 19.7/30 (19-21) | 15.3/30 (13-17) | 1.0/30 | 0.50 | 1.07 | 1 of 90 | 7.1 |

Loading took 0.8 s (CUDA) to 6.3 s (Gemma on Vulkan) from a warm disk.

## What it says {#reading}

- **All but 8 of the 1,080 replies took under a second**, and all 8 were
  on the Vulkan build, in a model's first round. Three are the first
  counted turn after loading -- 3.1 s (Ministral), 6.9 s (Granite), 10.1 s
  (Gemma) -- after the uncounted warm-up, so it is the first *long* prompt
  that pays, and it always fell on an English line. The other five are
  Ministral's, in its first round: four in English (1.2 to 2.0 s) and one
  in pt-BR (1.07 s). The CUDA build had none, and its median was 13-23%
  lower. A game shows the guard thinking meanwhile.
- **The frame never waited.** The worst frame while a request was in
  flight was 7.1-7.5 ms, the headless loop's own pace (docs/godot/llm-requests.md),
  with one 11.1 ms frame in 1,080 turns.
- **Granite 4.2 does not do pt-BR here**: 4-10 valid of 30 on Vulkan, 3-7
  on CUDA. It put the act's name in `argument` (`"show"` for `show`) over
  and over.
- **Gemma edges Ministral in English** (12.3 against 11.0 act and argument
  right, on Vulkan), and **Ministral wins in pt-BR** (15.3 against 13.3),
  the kit's second language.
- **Most refusals are R7, an argument the act does not take** -- `"none"`
  for `flatter`, `"Brandt"` for `brandt`, a roster name under `ask`. The
  schema the game sends cannot stop it: T92's shape leaves `argument` a free
  string, because which arguments belong to which act is not something
  `{"type": "string"}` says. Ministral's other refusals are R10, markup
  in its speech -- one of `<>[]*` or the backtick; a game never sees a
  refused text, and the probe records only the ruling, so which one is not
  known. Both are the validator doing its job:
  a refused reply is the game's own line, never an action.
- **T94 since narrowed the schema** to one shape per act, each offering
  only its own arguments or none, and measured it on these 30 lines
  (Ministral, Vulkan, three rounds a language): no R7 left, and valid
  replies up from 15-18 to 25-28 of 30 in English and from 22 to 28-30 in
  pt-BR. The table
  above is the free-string schema's, as T93 measured it;
  [the guard's page](../godot/talk.md#the-schema-measured) has the new rounds.

## The choice {#choice}

Recommended, and `default_model` in `runtime.json`: **`ministral-3-8b`**
on the **Vulkan** build -- the best act-and-argument count in pt-BR, and
Apache-2.0. **Gemma 4 E4B edges it in English** and is one word away
(`MODEL=gemma-4-e4b`); a game played mostly in English may prefer it. On
the Vulkan build, Ministral's first round had five replies between 1 and
2 s; every other reply after the first long prompt was under a second.
The owner picks from the table.
