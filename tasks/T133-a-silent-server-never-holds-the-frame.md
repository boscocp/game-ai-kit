# T133 — A silent server never holds the frame

Size: S · Prereqs: T130 · Files: `godot/addons/ai_llm/http_runtime.gd`, `godot/test/ai_llm/`, `scripts/check_llm_validated.py`, `docs/godot/llm-requests.md`

## Goal

The second review of T130 (`docs/reviews/133-the-talk-game-starts-its-own-model.md`)
found that an `HTTPRequest` with threads on can hold the frame for as long
as a socket stays silent. This breaks invariant 7.

At 4.7, a threaded request reads in blocking mode, and its thread checks
whether to quit only between reads. When `timeout` runs out, `_timeout`
calls `cancel_request`, which joins that thread on the main thread
(`scene/main/http_request.cpp` at 4.7-stable).

Measured on 4.7.2: a `/health` request with a 1 s timeout, against a
socket that accepts and never answers (`fake_llm_server.py --silent`),
held one frame for 58.4 s. The frame was released only when the socket
closed.

T130 moved `LlmLocalServer` off `HTTPRequest` and onto a non-blocking
`StreamPeerTCP`, with a test. `HttpRuntime` still sends each chat request
through a threaded `HTTPRequest` with a 30 s timeout, so a server that
accepts a chat request and then hangs freezes the game.

## Decisions written down first

- **Fix `HttpRuntime`, not the engine.** Either never cancel a threaded
  request on the main thread (let it end and ignore it), or read the
  answer non-blocking as `LlmLocalServer` does. The task measures both and
  picks one.
- **The gate learns the rule** if it can be stated: V3 now asks for
  `use_threads = true`, and that is the setting that blocks here.

## Steps

1. A test that fails today: `HttpRuntime` against a silent server must
   not hold any frame longer than 200 ms, and must say `failed` once its
   timeout has passed.
2. The fix, in `http_runtime.gd`.
3. `docs/godot/llm-requests.md` gains the measurement and the source
   lines it rests on. The gate is changed if the rule can be held there.

## Acceptance

```bash
make test-godot-some SUITES="test/ai_llm"
python3 scripts/check_llm_validated.py --self-test
make test-llm-vectors
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

With `make llm-serve` running, stop it with SIGSTOP (`pkill -STOP
llama-server`) and type a line in the talk game. Does the picture keep
drawing until the turn is said to have failed?

## Notes

- Found 2026-11-05 by the second review of PR #82. T130 contained it for
  `/health` only.
- Shares `godot/addons/ai_llm/` and `godot/test/ai_llm/` with T129: run one
  after the other.
- Both fixes measured (`http_frame_probe.gd`, given a second port; the
  table is in `docs/godot/llm-requests.md#a-server-that-accepts-and-never-answers`). Never cancelling a
  threaded request does not hold: freeing its node joins the same thread,
  59.0 s on one frame, and leaving the scene frees it. Threads off does:
  in the 4.7.2 source the client then reads with `get_partial_data` once a
  frame and `cancel_request` joins nothing; worst frame 7 ms. So the fix
  is one setting, the engine's own non-blocking reads, rather than a
  second hand-written HTTP client beside `LlmLocalServer`'s.
- The gate learned it: V3 asks for `use_threads = false`, the reverse of
  T92's rule, with the reason in its docstring.
- Reviewed: `docs/reviews/138-a-silent-server-never-holds-the-frame.md`
  (changes requested, no blocker, all applied).
- Done in wave 138.
