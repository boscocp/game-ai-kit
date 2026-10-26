# T92 — A local LLM runtime on the large disk, pinned and measured

Size: S · Prereqs: T91 · Files: `tools/llm/`, `scripts/llm`, `scripts/check_disk_layout.py`, `docs/local-llm/`, `docs/adr/`, `Makefile`, `README.md`
Requires: a local model

## Goal

The owner, 2026-10-26: `ai_llm` "entra agora", with a game where you talk
to "um agente por texto rodando uma LLM local" (T91 quotes it whole). T91
built the addon with a recorded runtime; this task installs a real one,
for tier 3 -- the README's "run a local LLM for real, once `ai_llm`
exists" -- with everything on the large disk (invariant 8) and nothing in
`$HOME`, the way `make bootstrap` installs Godot and `make
artgen-bootstrap` the image model (ADR 0013).

No lesson needs this task: T91's recordings are the tier-1 lesson and
T93's game plays from them without it (invariant 5).

## Decisions written down first (the owner confirms in review)

- **The runtime**: llama.cpp's `llama-server` -- one binary, pinned by
  release and sha256 like the Godot download, with an OpenAI-compatible
  `/chat/completions` that takes a JSON schema "inside the
  `response_format` body field". The alternative is Ollama, which takes one
  through `format`, keeps its models where `OLLAMA_MODELS` says, and is
  what `check_acceptance.py` already expects a task to name
  (`localhost:11434`). Both satisfy T91; the choice is about pinning and
  the disk. Recommended: llama.cpp, for the sha256.
- **The model is chosen by a bake-off, as T31 chose the image model**:
  three small instruct models that fit the owner's 12 GB card (ADR 0013
  records the machine), each pinned by file sha256, run on the same 30
  recorded player lines of T93's scene **in English and in pt-BR** (the
  demos speak both, T78). Measured: valid replies out of 30 before the
  validator's fallback, the intent a person would have chosen out of 30,
  the median and worst time to the reply. The owner picks from the table.
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
3. `make llm-serve` starts it on a fixed local port; `make llm-smoke` sends
   one request through T91's `HttpRuntime` path and checks the reply
   passes the validator, exit code 0 or 1.
4. `check_disk_layout.py` learns the runtime's folders: a model or cache
   under `$HOME` is a finding, with a planted case.
5. The bake-off above, its table in `docs/local-llm/`; a short ADR
   recording the runtime and the model.
6. README: the tier-3 row says how.

## Acceptance

```bash
scripts/llm --self-test
python3 scripts/check_disk_layout.py
python3 scripts/check_disk_layout.py --self-test
make llm-smoke
python3 scripts/check_doc_freshness.py
make lint-tasks lint-status
```

## Manual check

On a machine with the runtime installed, `make llm-serve` and then T93's
game in live mode: does the character answer within a few seconds, and is
the game drawing frames while it thinks? On a machine without it, is the
message that says how to install it clear?

How invariant 13 is met: by T93's game; this task adds the time each
reply took to what the game shows beside it.

References, opened on 2026-10-26: llama.cpp, `grammars/README.md`
<https://github.com/ggml-org/llama.cpp/blob/master/grammars/README.md>;
Ollama, "Structured outputs" <https://ollama.com/blog/structured-outputs>;
Ollama FAQ, `OLLAMA_MODELS` <https://docs.ollama.com/faq>.
