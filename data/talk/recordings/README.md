# The guard's recorded conversations

What a local language model answered when the lines in `../lines.json` were
said to Bram, the guard at the door (T94; `docs/godot/talk.md`). Each file
is one conversation in one language: the player's lines and the model's
text, untouched -- including the replies the validator refused. They are
the game's recorded mode and the vectors in `spec/vectors/talk/`.

## The model that wrote them

These are the model's output, so they carry its name and its licence
(invariant 9):

| | |
|---|---|
| model | Ministral 3 8B Instruct (2512), `ministral-3-8b` in `tools/llm/runtime.json` |
| file | `Ministral-3-8B-Instruct-2512-Q4_K_M.gguf`, from mistralai/Ministral-3-8B-Instruct-2512-GGUF at revision `0102285ad796bd99af90f58de616092e5630e970` |
| sha256 | `33e7a72cf5e6e2cfc2f2847075acc013d68bba023e35310cef86b5cf8fdca761` |
| licence | Apache-2.0, as its model card states it (front matter and its "License" section; read 2026-10-29, `docs/local-llm/bakeoff.md`) |
| server | llama.cpp `llama-server` b11960, Vulkan build, `scripts/llm serve` (context 4096, one slot, reasoning off) |
| recorded | 2026-11-05, with `make record-talk`, through the game's own `TalkGuard`, `RecordingRuntime` and `HttpRuntime` |

The server samples (the game sends no temperature), so recording again
gives different answers. After recording, write the vectors with
`PYTHONPATH=python python3 spec/vectors/talk/write.py` and read them
against `spec/talk/gate.json` before committing.

Recordings made by playing (`make record-talk-live`) land here too, named
by the time they ended; nothing is recorded unless asked (ADR 0017).
