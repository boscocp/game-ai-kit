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
samples (the game sends no temperature): two runs of one model were 8
valid replies apart.

The act and argument a person would choose for each line were written by
the wave's author before any model ran; the owner may disagree with a
label in review. The raw turns -- each line, the reply as ruled, its time
and the worst frame while waiting -- are in `bakeoff/`, one file per model,
build, language and round; `scripts/llm table` prints this table from them.

Measured 2026-10-29: RTX 5070 12 GB, Ryzen 5 9600X, 30 GB RAM, driver
615.78, Godot 4.7.2 headless, `b11960`.

## The table {#table}

*valid*: replies the validator accepted, before its fallback. *intent*:
the act the person chose. *intent and argument*: both. Each is the mean of
three rounds out of 30, with the range when the rounds differed. The times
are from `say` to `answered`, over all 90 turns.

| model | build | language | rounds | valid | intent | intent and argument | median s | worst s | worst frame ms |
|---|---|---|---|---|---|---|---|---|---|
| gemma-4-e4b | cuda | en | 3 | 20.7/30 (19-24) | 18.0/30 (17-20) | 11.7/30 (11-13) | 0.31 | 0.39 | 11.1 |
| gemma-4-e4b | cuda | pt_BR | 3 | 19.0/30 (17-22) | 17.0/30 (15-19) | 12.3/30 (11-14) | 0.32 | 0.39 | 7.1 |
| gemma-4-e4b | vulkan | en | 3 | 22.0/30 (20-24) | 18.3/30 (17-20) | 12.3/30 (12-13) | 0.40 | 10.07 | 7.4 |
| gemma-4-e4b | vulkan | pt_BR | 3 | 19.0/30 (18-20) | 16.3/30 (15-17) | 13.3/30 (12-15) | 0.40 | 0.48 | 7.1 |
| granite-4.2-8b | cuda | en | 3 | 18.7/30 (16-20) | 10.3/30 (8-13) | 7.3/30 (6-9) | 0.34 | 0.50 | 7.5 |
| granite-4.2-8b | cuda | pt_BR | 3 | 4.7/30 (3-7) | 4.7/30 (4-5) | 3.7/30 (2-5) | 0.40 | 0.75 | 7.2 |
| granite-4.2-8b | vulkan | en | 3 | 18.3/30 (17-20) | 11.7/30 (10-13) | 9.3/30 (8-12) | 0.39 | 6.86 | 7.1 |
| granite-4.2-8b | vulkan | pt_BR | 3 | 6.0/30 (4-10) | 4.7/30 (3-7) | 3.3/30 (2-5) | 0.46 | 0.67 | 7.1 |
| ministral-3-8b | cuda | en | 3 | 18.0/30 (17-19) | 17.0/30 (16-18) | 13.0/30 (10-15) | 0.39 | 0.52 | 7.2 |
| ministral-3-8b | cuda | pt_BR | 3 | 20.3/30 (20-21) | 18.3/30 (17-20) | 15.0/30 (14-16) | 0.43 | 0.61 | 7.1 |
| ministral-3-8b | vulkan | en | 3 | 16.7/30 (15-18) | 15.7/30 (14-17) | 12.3/30 (12-13) | 0.46 | 3.06 | 7.1 |
| ministral-3-8b | vulkan | pt_BR | 3 | 22.0/30 | 20.7/30 (20-22) | 16.3/30 (14-18) | 0.50 | 1.07 | 7.1 |

Loading took 0.8 s (CUDA) to 6.3 s (Gemma on Vulkan) from a warm disk.

## What it says {#reading}

- **Every reply took under a second, after the first.** On the Vulkan
  build the first counted turn after loading took 3 s (Ministral), 7 s
  (Granite) and 10 s (Gemma) -- after the uncounted warm-up, so it is the
  first *long* prompt that pays. The CUDA build had no such turn, and its
  median was 13-23% lower. A game shows the guard thinking for that one turn.
- **The frame never waited.** The worst frame while a request was in
  flight was 7.1-7.5 ms, the headless loop's own pace (docs/godot/llm-requests.md),
  with one 11.1 ms frame in 1,080 turns.
- **Granite 4.2 does not do pt-BR here**: 3-7 valid of 30. It put the act's
  name in `argument` (`"show"` for `show`) over and over.
- **Gemma and Ministral are close in English**; Ministral is better in pt-BR, the kit's second language, on the measure that
  matters to a game: the act and its argument both right.
- **Most refusals are R7, an argument the act does not take** -- `"none"`
  for `flatter`, `"Brandt"` for `brandt`, a roster name under `ask`. The
  schema the game sends cannot stop it: T92's shape leaves `argument` a free
  string, because which arguments belong to which act is not something
  `{"type": "string"}` says. Ministral's other refusals are R10, markup
  in its speech -- one of `<>[]*` or the backtick; a game never sees a
  refused text, and the probe records only the ruling, so which one is not
  known. Both are the validator doing its job:
  a refused reply is the game's own line, never an action.

## The choice {#choice}

Recommended, and `default_model` in `runtime.json`: **`ministral-3-8b`**
on the **Vulkan** build -- the best act-and-argument count in pt-BR and as
good as any in English, every reply under a second after the first, and
Apache-2.0. Gemma 4 E4B is one word away (`MODEL=gemma-4-e4b`) and the
better English speaker by a little. The owner picks from the table.
