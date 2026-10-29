# T93 — A local LLM runtime on the large disk, pinned and measured

Size: M · Prereqs: T92 · Files: `tools/llm/`, `scripts/llm`, `scripts/check_disk_layout.py`, `scripts/check_acceptance.py`, `docs/local-llm/`, `docs/adr/`, `Makefile`, `README.md`
Requires: a local model

## Goal

The owner, 2026-10-26: `ai_llm` "entra agora", with a game where you talk
to "um agente por texto rodando uma LLM local" (T92 quotes it whole). T92
built the addon with a recorded runtime; this task installs a real one,
for tier 3 -- the README's "run a local LLM for real, once `ai_llm`
exists" -- with everything on the large disk (invariant 8) and nothing in
`$HOME`, the way `make bootstrap` installs Godot and `make
artgen-bootstrap` the image model (ADR 0013).

No lesson needs this task: T92's recordings are the tier-1 lesson and
T94's game plays from them without it (invariant 5).

## Decisions written down first (the owner confirms in review)

- **The runtime**: llama.cpp's `llama-server`, a **prebuilt release
  archive** pinned by its build tag and sha256 like the Godot download --
  not a local build, whose bytes differ per machine, so a sha256 could not
  pin it. Checked on 2026-10-26 with `gh api
  repos/ggml-org/llama.cpp/releases`: each build (`b11901` that day; a new
  one several times a day) ships Linux x64 archives for the CPU
  (`llama-<tag>-bin-ubuntu-x64.tar.gz`), Vulkan, CUDA 12.8 and 13.4, ROCm,
  SYCL and OpenVINO. Recommended: the Vulkan build, which runs on the
  owner's NVIDIA card and on integrated graphics alike, with the CPU build
  as the fallback; the CUDA build is the faster alternative on NVIDIA,
  measured in the bake-off. The server has an OpenAI-compatible
  `/chat/completions` that takes a JSON schema "inside the
  `response_format` body field". The alternative is Ollama, which takes one
  through `format`, keeps its models where `OLLAMA_MODELS` says, and is
  what `check_acceptance.py` already expects a task to name
  (`localhost:11434`). Both satisfy T92; the choice is about pinning and
  the disk. Recommended: llama.cpp, for the sha256.
- **The model is chosen by a bake-off, as T31 chose the image model**:
  three small instruct models that fit the owner's 12 GB card (ADR 0013
  records the machine), each pinned by file sha256, run on the same 30
  recorded player lines of T94's scene **in English and in pt-BR** (the
  demos speak both, T78). Measured: valid replies out of 30 before the
  validator's fallback, the intent a person would have chosen out of 30,
  the median and worst time to the reply, **and each model's licence** as
  its model card states it. Apache-2.0 or MIT models are preferred; a model
  under a licence with use restrictions is listed with them, and the owner
  decides. Invariant 9: nothing of a model ships (it lives on the large
  disk), but the recordings T94 commits are its output, so T94 names the
  model and its licence beside `data/talk/recordings/`. The owner picks
  from the table.
- **Fenced like the art generator**: `tools/llm/` and `scripts/llm`, which
  point every cache at the toolchain directory; nothing in `python/`,
  `godot/addons/` or `godot/game/` names them, and `make check` never
  starts the runtime.

## Steps

1. Read the runtime's own documentation for the pinned release (server
   flags, the schema field, the context size) -- CLAUDE.md's order:
   documentation, then measurement. Findings in `docs/local-llm/` (the
   `tool` layer, 91 days) with source URLs and `verified_on`.
2. `make llm-bootstrap`: download the binary and the chosen model into the
   toolchain directory, check each sha256, refuse a mismatch; `--self-test`
   plants a mismatched file and must see it refused.
3. `make llm-serve` starts it on a fixed local port (the server's README,
   read on 2026-10-26, gives `--port`'s default as 9931; the task passes
   the port explicitly and writes it in one place); `make llm-smoke`
   **starts the server itself, waits for it to answer, sends one request
   through T92's `HttpRuntime` path, checks the reply passes the
   validator, and stops the server**, whatever happened -- exit code 0 or
   1, and 2 when the runtime is not installed, saying how to install it.
   T92's review (wave 102) adds two things here. `HttpRuntime` sends the
   schema as OpenAI's `response_format: {"type": "json_schema",
   "json_schema": {...}}`, written from the documentation and never
   measured: measure that the pinned server takes that form, and change
   the runtime if it does not. And add a recorded test (a stub answer, no
   model) that tells "the server refused the request" (an HTTP 400, say,
   for a schema it cannot read) apart from "the model's reply was
   refused": today both reach the game as the fallback, the first as F1
   with the status in its sentence -- without a test that keeps them
   apart, a server that rejects every request turns every turn silently
   into F1. `HttpRuntime`'s default URL says port 8080; set it from the
   one place step 3 writes the port.
4. `check_acceptance.py` today recognises acceptance that needs a local
   model only by `ollama`, `localhost:11434` and `api/chat`
   (`NEEDS_LOCAL_MODEL`). Teach it `llm-smoke`, `llm-serve` and the fixed
   port, so a task that runs them without `Requires: a local model` is
   refused; a planted case in its self-test.
5. `check_disk_layout.py` learns the runtime's folders: a model or cache
   under `$HOME` is a finding, with a planted case.
6. The bake-off above, its table in `docs/local-llm/`; a short ADR
   recording the runtime and the model.
7. README: the tier-3 row says how.

## Acceptance

```bash
scripts/llm --self-test
python3 scripts/check_acceptance.py
python3 scripts/check_acceptance.py --self-test
python3 scripts/check_disk_layout.py
python3 scripts/check_disk_layout.py --self-test
make llm-smoke
python3 scripts/check_doc_freshness.py
make lint-tasks lint-status
```

## Manual check

On a machine with the runtime installed, `make llm-serve` and then T94's
game in live mode: does the character answer within a few seconds, and is
the game drawing frames while it thinks? On a machine without it, is the
message that says how to install it clear?

How invariant 13 is met: by T94's game; this task adds the time each
reply took to what the game shows beside it.

References, opened on 2026-10-26: llama.cpp, `grammars/README.md`
<https://github.com/ggml-org/llama.cpp/blob/master/grammars/README.md>;
Ollama, "Structured outputs" <https://ollama.com/blog/structured-outputs>;
Ollama FAQ, `OLLAMA_MODELS` <https://docs.ollama.com/faq>; llama.cpp,
`tools/server/README.md` (`--port`)
<https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md>;
the release list <https://github.com/ggml-org/llama.cpp/releases>.
