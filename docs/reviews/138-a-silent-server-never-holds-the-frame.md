# Review: wave/138, T133 -- a silent server never holds the frame

T133: the second review of T130 found that a threaded `HTTPRequest`, timed
out against a server that accepts and never answers, holds one frame until
the socket closes. `HttpRuntime`'s chat request had that flaw. The PR sets
`use_threads = false` in `http_runtime.gd` and gives `RESULT_TIMEOUT` its own
`failed` message. It adds
`test_a_chat_request_to_a_server_that_never_answers_never_holds_the_frame`
and moves the frame loop into a shared `_longest_frame_until`. It gives
`http_frame_probe.gd` three silent cases and `fake_llm_server.py` a
`--lifetime`. V3 in `check_llm_validated.py` now asks for threads off. A new
section in `docs/godot/llm-requests.md` holds the source lines and the table.

A fresh context reviewed PR #85 at head 88a61da. It read the code, the
official class reference and the engine source, and ran narrow checks in a
throwaway worktree. It made no commit, push or PR comment.

**Verdict: changes requested, no blocker.** The mechanism is right, the fix
is the right size, and both mutations the wave rests on turn the test red.
One should-fix is about the gate: V3 is rewritten in this wave, and it still
passes `_request.set_use_threads(true)`. That is the setter the class
reference names. It would let in the exact defect T133 removes, and the
docstring does not list it as a known way round. Three nits follow.

## What was reviewed

- The whole diff: `http_runtime.gd`, `llm_local_server_test.gd`,
  `llm_test.gd`, `http_frame_probe.gd`, `fake_llm_server.py`,
  `check_llm_validated.py` (docstring, regexes, `SOUND_ADDON`, the planted
  cases), `llm-requests.md`, `talk.md`, the task file and the STATUS row.
- The kill path in `llm_local_server.gd` (`_start`, `_exit_tree`,
  `_still_running`), read before running anything that starts a fake.
  `OS.kill` runs only on the pid that `OS.create_process` returned, and
  only when it is not -1.
- The class reference at `4.7.2-stable`, `doc/classes/HTTPRequest.xml`:
  `use_threads` (setter `set_use_threads`, default `false`, "If `true`,
  multithreading is used to improve performance"), `cancel_request`
  ("Cancels the current request"), `timeout`, `download_chunk_size`. The
  PR quotes them correctly, and they say nothing about the main thread.
- The engine source at `4.7.2-stable`: `scene/main/http_request.cpp`,
  `core/io/http_client_tcp.cpp`, `core/io/ip.cpp`,
  `modules/mbedtls/stream_peer_mbedtls.cpp`.

## What was run (green at 88a61da unless stated)

- `make worktree-setup`, then an `--import`.
- `make test-godot-some SUITES="test/ai_llm"`: 47 cases, 0 failures, no
  `SCRIPT ERROR`. The leak warnings at exit (143 ObjectDB instances, 100
  resources, 4 PagedAllocator lines) are the same on `origin/main`'s
  `godot/` (46 cases). The new test adds none.
- `python3 scripts/check_llm_validated.py --self-test`: ok.
  `python3 scripts/check_llm_validated.py`: exit 0.
- `make test-llm-vectors`: 60 cases, 0 failures.
- `python3 scripts/check_readability.py`: exit 0. `make lint-tasks
  lint-status lint-links`: ok.
- At the end, `pgrep -af fake_llm_server` matched only the shell running
  `pgrep` itself, and `pgrep llama-server` matched nothing. Every fake came
  from the suite's own `LlmLocalServer`.

## The central claim (verified)

The claim holds, line by line, at `4.7.2-stable`:

- `HTTPRequest::request_raw`: threaded, `client->set_blocking_mode(true)`
  and `thread.start(_thread_func)`. Not threaded,
  `set_blocking_mode(false)`, `_request()` and `set_process_internal(true)`.
- `HTTPRequest::cancel_request`: threaded, `thread_request_quit.set()`
  then `thread.wait_to_finish()`. Not threaded,
  `set_process_internal(false)` and nothing else.
- `_timeout()` is `cancel_request(); _defer_done(RESULT_TIMEOUT, ...)`, and
  `NOTIFICATION_EXIT_TREE` calls `cancel_request()` when `requesting`. Both
  run on the main thread.
- `HTTPClientTCP::_get_http_data`, blocking: `while (left > 0)` around
  `get_partial_data`, which leaves only on `ERR_FILE_EOF` or an error. It is
  a spin, not a blocking read, and it has no timeout. The thread therefore
  never reaches `thread_request_quit` while the socket stays open, which
  matches the frame ending when the fake closes its socket.

**Costs of threads off that the PR does not name.** I looked for them, and
none of them blocks:

- *A large answer.* Each frame reads one chunk of up to
  `download_chunk_size` (65536 by default). `BODY_SIZE_LIMIT` is 65536, so
  the largest answer accepted takes one or two frames of `memcpy`. The JSON
  parse in `_on_request_completed` was already on the frame in both modes,
  because `request_completed` is emitted deferred.
- *DNS.* `resolve_hostname_queue_item` posts to the resolver thread when
  that thread exists, which it does in every threaded build. The URL is an
  IP literal anyway.
- *TLS.* The handshake is polled (`tls_conn->poll()`) in both modes. Each
  step's crypto runs on the frame with threads off. That cost is a few
  milliseconds, and `ai_llm` talks plain HTTP on loopback.
- *Latency.* The state machine moves at most one step a frame: connect,
  send, headers, body. That is a few frames on top of seconds of
  generation, so it does not matter.
- *Pause.* This one is real but latent; see nit 2.

## Mutation round

Each change was one edit, run against the narrow suite, then restored:

| mutation | caught by |
|---|---|
| `_request.use_threads = true` in `http_runtime.gd` | the new test, `Expecting to be less than 200000 but was 58536169` (a 58.5 s frame); `llm_test`'s `is_false`; the gate, two V3 findings (line 74 sets it, line 73 never sets false) |
| the `RESULT_TIMEOUT` branch in `_on_request_completed` removed | the new test, on `contains("did not answer in 1 s")` |

The test is a real frame measurement. `_longest_frame_until` takes the gap
between two `process_frame`s, and with threads on the join happens inside
`_timeout()` on the main thread, between two of them. It cannot go green on
an empty scene. It needs exactly one `failed`, with the timeout's wording,
more than 0.9 s after `send`. A missing server gives `RESULT_CANT_CONNECT`
and the other wording, so it fails. The `runtime.free()` timing measures
the `EXIT_TREE` join synchronously.

Gate plants, in the addon's `_ready`, after `use_threads = false`:

| plant | gate exit |
|---|---|
| `_request.set_use_threads(true)` | **0** |
| `_request.use_threads = false if url == "" else true` | **0** |
| `var threaded: bool = true` / `_request.use_threads = threaded` | 1 |
| `_request.use_threads  =  true` | 1 |
| `_request.use_threads = (true)` | 1 |
| `_request.use_threads = not false` | 1 |

`__pycache__` was cleared after the round.

## Findings

### 1. should-fix -- V3 passes the setter spelling, and does not say so

`scripts/check_llm_validated.py:156` and `:360`. `THREADS_NOT_FALSE_RE`
looks only at `.use_threads =`. `_request.set_use_threads(true)`, the
setter the class reference names for this property, gets through, and so
does a conditional that starts with `false`. The gap is older than this
wave: the old rule passed `set_use_threads(false)` the same way. But this
wave rewrites V3 because of exactly this setting. The docstring's "Not
caught, known" list (`:63-67`) names `set("use_threads", true)` and not
the setter. CLAUDE.md says a rule you believe is enforced is worse than
none. `llm_test`'s `is_false` would catch the setter on `HttpRuntime`'s own
request at run time. A second `HTTPRequest` in the addon would have no test
to catch it.

Fix: in the line check, also flag `\bset_use_threads\s*\(\s*(?!false\s*\))`.
Accept `name.set_use_threads(false)` beside `name.use_threads = false` in
`requests_without_threads`, or refuse the setter outright so there is one
spelling. Add a planted case,
`.replace("\tadd_child(_request)\n", "\t_request.set_use_threads(true)\n\tadd_child(_request)\n")`.
Name the conditional expression in the "Not caught, known" list, or anchor
the `= false` match at the end of the line
(`=\s*false\s*(?:#.*)?$`).

### 2. nit -- threads off stops the request while the tree is paused

`godot/addons/ai_llm/http_runtime.gd:15-30` (the header) and the
`#rule` section of `docs/godot/llm-requests.md`. With threads off, the
request moves forward only in `NOTIFICATION_INTERNAL_PROCESS`, so under
`SceneTree.paused` with the default `PROCESS_MODE_INHERIT` it stops. The
`HTTPRequest`'s internal `Timer` stops too, so the timeout does not run
down either. With threads on, the thread kept reading through a pause.
Nothing in the talk game pauses the tree (`git grep paused` finds nothing
under the talk scene or `ai_llm`). But `ai_llm` is an addon meant to be
copied, and a pause menu over a conversation is an ordinary thing to
build. Fix: one sentence in the header, near "When not to use it", saying
a paused tree pauses the request and its timeout. Or set
`_request.process_mode = PROCESS_MODE_ALWAYS` if the owner wants a reply to
arrive under a pause menu. Measure that before writing it.

### 3. nit -- a fixed 0.5 s wait for the silent server to listen

`godot/test/ai_llm/llm_local_server_test.gd:254`. The test sleeps 0.5 s
after `silent.begin()` and assumes Python is listening by then. If it is
not, under load from a parallel batch, the request gets
`RESULT_CANT_CONNECT` and the test goes red for the wrong reason. It fails
safe, never falsely green, but a timing failure costs a rerun. Fix: poll a
`StreamPeerTCP` on 39960 until it reaches `STATUS_CONNECTED`, within
PATIENCE. Or wait until `silent.state` leaves `CHECKING` and then poll
briefly.

### 4. nit -- the page's opening still frames the rule as "threads on"

`docs/godot/llm-requests.md:1` and `:13`. The title is fine. The intro
still says "before writing the rule 'threads on'", and the next sentence
turns it round. A reader who stops at the first sentence takes away the old
rule. Fix: "before writing the rule for `use_threads`".

## Decisions for the owner

1. **Threads off, not a second hand-written HTTP client.** Agree: keep it.
   The source shows that the non-threaded path is the engine's own
   non-blocking client. It polls name lookup, connect and TLS, and it
   handles chunked bodies and `body_size_limit`. A second client beside
   `LlmLocalServer`'s `StreamPeerTCP` would be more code to teach for no
   gain. The only cost found is the pause behaviour in nit 2, and that is
   a sentence, not a reason to change course.
2. **V3 asks for `use_threads = false` written out.** Agree: keep it, for
   the reason the PR gives. The threads-on mutant was caught twice. But a
   rule that asks for one spelling must also refuse the other spelling of
   the same setting, which is finding 1.
3. **The manual check is left to the owner.** Agree, and it cannot be
   gated: `--headless` cannot show whether the picture keeps drawing. A
   llama-server stopped with SIGSTOP still has the kernel complete the TCP
   handshake from the listen backlog. That is the same state the fake's
   `--silent` socket puts the client in, so the automated test is a
   faithful stand-in for the mechanism. The manual check confirms the
   picture, not the mechanism, so running it on the merged head is
   enough.

## Applied

All four findings applied at d82d1b5, on the same branch.

1. **Applied.** V3 now refuses `set_use_threads(` in any form, `false`
   included, so the property is the one spelling the gate reads. A
   `.use_threads =` line passes only when a plain `false` ends it. That
   refuses the conditional `false if url == "" else true`, and
   `requests_without_threads` asks for the same anchored `false`. The
   self-test has three new planted cases: the setter with `true`, the
   setter with `false`, and the conditional. On the real `http_runtime.gd`,
   `_request.set_use_threads(true)` exits 1 (one V3 finding), and the
   conditional exits 1 (two V3 findings). Restored, the gate exits 0. The
   docstring names both.
2. **Applied as a sentence.** The header of `http_runtime.gd` and the rule
   section of `llm-requests.md` both say that with threads off, a paused
   tree pauses the request and its timeout. The process mode is unchanged
   and is left for the owner to decide.
3. **Applied.** The fixed 0.5 s wait is gone. `_until_listening` sends a
   short chat request (0.2 s timeout) and sends it again while it finds
   nothing there, until one times out, which means a silent server is
   listening. A socket of the test's own is not used, because V1 keeps
   network classes inside the addon. These timeouts are held to 200 ms a
   frame as well. Without that, the threads-on mutant spent its 59 s
   inside the wait, and the test went red only on the wording. With it,
   the mutant fails on `200000 but was 59786982`. `test/ai_llm`: 47
   cases, 0 failures.
4. **Applied.** The page's opening now reads "before writing the rule for
   `use_threads`".
