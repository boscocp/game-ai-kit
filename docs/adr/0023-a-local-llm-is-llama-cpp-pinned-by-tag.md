# 0023 — The local LLM is llama.cpp's server, pinned by build tag, fenced

Status: proposed · 2026-10-29 (T93, wave 111; the owner confirms in review)

## Context

T92 built `ai_llm` against a recorded runtime and an `HttpRuntime` that
speaks OpenAI's chat completions to a local server nobody had installed.
T94's game has a live mode (tier 3), so a real server has to be installed
somewhere, the way `make bootstrap` installs Godot (ADR 0002) and `make
artgen-bootstrap` the image model (ADR 0013): on the large disk, every byte
pinned, nothing in `$HOME`. No lesson may need it (invariant 5).

The owner's machine: an RTX 5070 with 12 GB, a Ryzen 5 9600X with an
integrated Radeon, 30 GB of RAM, Linux.

## Decision

**llama.cpp's `llama-server`, from its prebuilt release archives, pinned by
build tag and each archive's sha256** -- `b11960`, the build its first
versioned release, `v0.8.0`, names. A local build was not taken: its bytes
differ per machine, so no sha256 could pin it. The **Vulkan** build is the
default, because it runs on the NVIDIA card and on integrated graphics
alike; the CPU build is the fallback, and the CUDA 13.4 build is one word
away (`FLAVOUR=cuda`). MIT.

**The model is Ministral 3 8B Instruct** (`Ministral-3-8B-Instruct-2512`,
Q4_K_M, Mistral's own GGUF, Apache-2.0), recommended by a bake-off of three
Apache-2.0 models on the same 30 lines in English and pt-BR
([docs/local-llm/bakeoff.md](../local-llm/bakeoff.md)): the most replies
with act and argument right in pt-BR (15.3 of 30 on Vulkan, against Gemma's
13.3), counting only replies the validator accepted. **Gemma 4 E4B edges it
in English** (12.3 against 11.0) and stays one word away, with Granite 4.2
8B, pinned in `tools/llm/runtime.json`.

**Fenced like the art generator.** `tools/llm/` and `scripts/llm`, which
points every cache at `$toolchain/llm/` -- llama.cpp's own and the GPU
drivers' -- and keeps the server offline. Nothing in `python/`,
`godot/addons/` or `godot/game/` names them; `make check` never starts the
server, only the self-test of the wrapper and of the pin. The port is
written once, as `HttpRuntime.PORT` (9931, the server's own default), and
read from there by the wrapper and by `check_acceptance.py`.

**A server that refuses the request is not a reply that was refused.**
`LlmRuntime` gains `refused`, which `HttpRuntime` emits for any HTTP error
but 503, with the server's own reason, and `LlmConversation` answers as
`F2`. 503 ("Loading model") stays `F1`, a turn lost.

## Alternatives considered

- **Ollama.** Takes a schema through `format`, keeps models where
  `OLLAMA_MODELS` says, and `check_acceptance.py` already knew its port. It
  installs by a script or a package and fetches models by name and tag
  from its own registry, where the files T93 can pin by sha256 are
  llama.cpp's release archives and the makers' GGUF files. Rejected for
  the pin, as the task recommended; it would satisfy `HttpRuntime` as well.
- **A local build of llama.cpp.** Faster to follow upstream, and no sha256
  to hold it. Rejected.
- **The newest build.** Several a day, all marked pre-release since
  `v0.8.0`; the versioned release names one, and that one is pinned.
- **CUDA as the default.** Measured 13-23% faster per reply on the owner's
  card, with no reply of a second or more (the Vulkan build spent 3-10 s
  on each model's first long prompt, and Ministral had five more replies of
  1-2 s in its first round). Not the default because it needs an NVIDIA card and a
  600 MB runtime; the owner may decide otherwise from the table.

## Consequences

- Pinned by tag means fetched by tag: if upstream ever deletes the
  b11960 release or its assets, `make llm-bootstrap` fails on a fresh
  machine (a 404, said as such), and an installed toolchain keeps working.
  The way out is a new pin -- a newer build's archives and sha256 in
  `runtime.json`, `make llm-smoke`, and the bake-off rerun if the server's
  behaviour may have moved -- never an unpinned download.
- `make llm-bootstrap` costs about 5 GB on the large disk for the default;
  every model and build, 17 GB. `make llm-smoke` starts the server, sends
  one line through `HttpRuntime` and `LlmConversation` in Godot, checks the
  validator passed it and stops the server, whatever happened -- 2 when
  nothing is installed, saying how to install it.
- Measured, not trusted: `HttpRuntime`'s `response_format` form is the one
  the pinned server honours, and the README's own example is silently
  ignored (docs/local-llm/server.md); a test holds the form, and another,
  from recorded server answers, holds F1, F2 and the validator's codes apart.
- `check_disk_layout.py` fails on `~/.cache/llama.cpp`; the driver caches
  are not listed (other software keeps them), and that the wrapper moves
  them was measured by modification time.
- The bake-off's numbers are from a committed command, `make llm-bakeoff`,
  and its raw turns are committed beside the table. A rerun samples again:
  the ranges in the table are three rounds' spread, not a bound.
- Even the two better models had a quarter to a half of their replies
  refused, most of them R7, an argument the act does not take: the schema
  cannot say which arguments belong to which act. The
  validator turns each into the game's line; whether the schema should say
  more is the owner's question for T94, not this ADR's.
- Invariant 9: no model file ships. What T94 commits from a model is its
  output, named with the model and its licence beside the recordings.
