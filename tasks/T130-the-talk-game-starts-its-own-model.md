# T130 — The talk game starts its own model

Size: S · Prereqs: T94 · Files: `godot/addons/ai_llm/`, `godot/test/ai_llm/`, `godot/game/talk/`, `godot/test/talk/`, `godot/locale/talk.csv`, `scripts/check_llm_validated.py`, `tools/llm/llm.py`, `docs/reviews/133-the-talk-game-starts-its-own-model.md`, `docs/adr/0023-a-local-llm-is-llama-cpp-pinned-by-tag.md`, `docs/godot/talk.md`, `Makefile`

## Goal

On 2026-11-05 the owner played `make demo-talk`, typed in live mode and
got "F1: no answer came from the model": `make llm-serve` was not running.
He asked, verbatim: "nao fiz o make llm-serve, n tem como deixar isso parte
de executar o jogo?" This session proposed the design below and the owner
answered "as 3", accepting it. It amends ADR 0023.

## Decisions written down first

1. **Tab starts it when nothing answers.** On Tab into live mode the scene
   asks the server's `/health` on `HttpRuntime.PORT`. Nothing answers: it
   starts `scripts/llm serve` with `OS.create_process`, so no frame waits
   (invariant 7). The status line says the model is loading, in both
   languages, and the game keeps drawing.
2. **Ready is `/health` saying 200.** Asked every 0.25 s by an
   `HTTPRequest` with threads on; 503 is llama.cpp loading. Typing opens
   once the server is ready.
3. **Stop only what was started here.** On `_exit_tree` the server is
   stopped only if this scene started it. One already running (for
   example `make llm-serve`) is used and never stopped.
4. **Only in a checkout.** `scripts/llm` stays the only way the repo runs
   the model, so its caches stay on the large disk (invariant 8). In an
   exported build, or where `scripts/llm` is missing, live mode says to run
   the server by hand, as before. An installation that is missing shows
   up as `scripts/llm` exiting 2 while loading, and the status line names
   `make llm-bootstrap`.
5. **Recorded mode starts nothing.** The model loads only on Tab.

## Steps

1. `LlmLocalServer` in `ai_llm`: the one file allowed `OS.create_process`,
   held by `check_llm_validated.py` with planted cases.
2. The talk scene: the server made at the first Tab, typing closed while
   it loads, a status line in both languages, its state in the overlay.
3. Tests with a stand-in server (`fake_llm_server.py`), never a model: started
   when nothing answers, not started when something answers, stopped on
   exit only when started here, and the exported-build fallback. A fault
   planted for each, caught.
4. Measured once with the real server: the time to ready, and the worst
   frame while loading.
5. ADR 0023 amended, dated, quoting the owner; `docs/godot/talk.md`.

## Acceptance

```bash
make test-godot-some SUITES="test/ai_llm test/talk"
python3 scripts/check_llm_validated.py --self-test
scripts/llm --self-test
python3 scripts/check_llm_validated.py
make test-talk-vectors
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

With no server running, `make demo-talk`, then Tab. Does the status line
count the seconds while the picture keeps drawing? Does typing open once
the model is ready, in English and in pt-BR? Leave the scene: does
`pgrep llama-server` find nothing? Then start `make llm-serve` in a
terminal, open the game, Tab: is it used, and still running after you
leave?

## Notes

- Shares `godot/game/talk/talk.gd` with T132 (wave 135), which changes its
  `_notification` and the language lines of `_ready`. T130 changes neither.
- Measured on 2026-11-05 (`godot/test/talk/talk_server_measure.gd`, Vulkan,
  Ministral 3 8B): Tab to ready 2.45 to 2.51 s over six runs. The longest
  frame while loading was 7.3 and 9.3 ms headless. Windowed it was 7.8 to
  101.2 ms, the long ones 0.45 to 0.65 s after Tab, while the weights move
  onto the card the game draws with. Leaving the scene costs one frame of
  86 to 91 ms, because `OS.kill` waits for the process to end.
- The review (`docs/reviews/133-the-talk-game-starts-its-own-model.md`)
  asked for three changes, and all were applied:
  - The server now dies with the game when the game is stopped with Ctrl+C
    or `kill` (Linux, `PR_SET_PDEATHSIG`). Measured: no `llama-server` was
    left after SIGINT or SIGTERM.
  - It is started with a key made for that launch. Without the key, the
    measured answer is 401.
  - A server that goes away is found again: after an F1 turn, after Tab
    twice, and when a server found loading falls silent.

  `OS.kill` now runs only on leaving, which the gate holds.
- The fake server's tests need a POSIX shebang. Windows would need
  `python3` named as the program.

## Done (wave 133)

Done in wave 133. Decisions not settled by the design are listed in the pull request.
