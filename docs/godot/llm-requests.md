# An HTTPRequest and the frame, threads on and off

<!-- doc-meta
half_life: practice
verified_on: 2026-11-05
tier: 2
source: https://docs.godotengine.org/en/4.7/classes/class_httprequest.html ; https://docs.godotengine.org/en/4.7/classes/class_json.html ; https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/http_request.cpp ; https://github.com/godotengine/godot/blob/4.7.2-stable/core/io/http_client_tcp.cpp
invalidated_if: the pinned engine changes, or HTTPRequest's use_threads, timeout or request() documentation changes, or http_request.cpp stops joining its thread in cancel_request
teaches: none
-->

> Invariant 7 says the LLM never blocks a frame. `ai_llm` asks a local
> server through `HTTPRequest`, so before writing the rule "threads on",
> this page reads what Godot 4.7 documents and measures what 4.7.2 does.
> Measured on 2026-10-29, on the owner's Linux desktop, headless. On
> 2026-11-05 a server that accepts and never answers turned the rule
> round: [threads off](#a-server-that-accepts-and-never-answers), since T133.

## What the documentation says {#documented}

From the Godot 4.7 [`HTTPRequest`](https://docs.godotengine.org/en/4.7/classes/class_httprequest.html)
page, opened 2026-10-29:

> **`use_threads`** -- If `true`, multithreading is used to improve
> performance.
>
> **`timeout`** -- The duration to wait before a request times out, in
> seconds (independent of `Engine.time_scale`). If timeout is set to `0.0`,
> the request will never time out.
>
> **`request()`** -- Returns `OK` if request is successfully created. (Does
> not imply that the server has responded), `ERR_UNCONFIGURED` if not in
> the tree, `ERR_BUSY` if still processing previous request,
> `ERR_INVALID_PARAMETER` if given string is not a valid URL format, or
> `ERR_CANT_CONNECT` if not using thread and the HTTPClient cannot connect
> to host.

So the page promises the answer comes later, by `request_completed`; it
does not say whether connecting, without threads, happens inside the call.
`ERR_CANT_CONNECT` "if not using thread" reads as if it might.

## What measuring says {#measured}

`make measure-llm-requests` starts `gameaikit.llm.stub_server` -- it
answers like a chat-completions server, after half a second, with no model
-- and runs `godot/test/ai_llm/http_frame_probe.gd`, which times
`request()` itself and every frame until `request_completed`, three rounds
per case. Headless, Godot paces frames at about 6.9 ms here, so a stall
would show as a frame above that, and one shorter than a frame is caught by
timing `request()` on its own.

| case | threads | `request()` took | worst frame | result |
|---|---|---|---|---|
| nothing sent (the loop alone) | -- | -- | 7.0 ms | -- |
| the stub, answering after 0.5 s | off | 0.05-0.08 ms | 6.95 ms | success |
| the stub, answering after 0.5 s | on | 0.02-0.05 ms | 6.96 ms | success |
| a closed port, 127.0.0.1:1 | off | 0.05 ms | 6.90 ms | `RESULT_CANT_CONNECT`, 2 frames later |
| a closed port | on | 0.02 ms | 6.91 ms | `RESULT_CANT_CONNECT`, 2 frames later |
| an address nobody answers, 10.255.255.1 | off | 0.03-0.05 ms | 7.01 ms | `RESULT_TIMEOUT` at the 2 s timeout |
| an address nobody answers | on | 0.02 ms | 7.02 ms | `RESULT_TIMEOUT` at the 2 s timeout |
| a name to resolve, `llm.invalid` | off | 0.01 ms | 6.91 ms | `RESULT_CANT_RESOLVE` |
| a name to resolve | on | 0.02 ms | 6.91 ms | `RESULT_CANT_RESOLVE` |

On this machine, **no case stalled a frame, with threads off or on.**
`request()` returned `OK` in under a tenth of a millisecond every time, and
even the closed port came back as `RESULT_CANT_CONNECT` by the signal, not
as `ERR_CANT_CONNECT` from the call. The 0.5 s the stub spent thinking was
spent between frames, never inside one.

## A server that accepts and never answers

The table above has no case for a server that takes the connection and
then says nothing: a `llama-server` stopped with SIGSTOP, or hung. The
second review of T130 found it, and T133 measured it.

**What the documentation says.** Nothing about it. Re-read on 2026-11-05,
the 4.7 page says of `use_threads` only "If `true`, multithreading is used
to improve performance", of `cancel_request` "Cancels the current
request", and nothing about the main thread.

**What the source says**, at 4.7.2-stable:

- `scene/main/http_request.cpp`, `request_raw()`: with `use_threads`, it
  calls `client->set_blocking_mode(true)` and starts `_thread_func`, which
  loops on `_update_connection()` until `thread_request_quit` is set.
  Without threads, `set_blocking_mode(false)`, and the same
  `_update_connection()` runs once per frame, from
  `NOTIFICATION_INTERNAL_PROCESS`.
- `cancel_request()`, threads on: `thread_request_quit.set()`, then
  `thread.wait_to_finish()` -- on the thread that called it. Threads off:
  `set_process_internal(false)`, and nothing waits.
- `_timeout()` calls `cancel_request()`, and so does
  `NOTIFICATION_EXIT_TREE` when a request is in flight. Both run on the
  main thread.
- `core/io/http_client_tcp.cpp`, `_get_http_data()`: in blocking mode it
  loops `while (left > 0)` on `get_partial_data`, with no timeout, so the
  thread never comes back to look at `thread_request_quit` while the
  socket stays open and silent. In non-blocking mode it returns what has
  arrived, possibly nothing, and `poll()` returns `OK` to try next frame.
  The name lookup is queued (`resolve_hostname_queue_item`) and the
  connect polled, in both modes.

So threaded, a timeout or a node leaving the tree waits on the frame for
the socket. Not threaded, nothing does.

**What measuring says.** `http_frame_probe.gd` takes a second port and
adds three cases, each against its own `fake_llm_server.py --silent`
(the probe's header has the commands). One round each, on 2026-11-05:

| case | timeout | worst frame | result |
|---|---|---|---|
| silent, threads off | 1 s | 6.99 ms | `RESULT_TIMEOUT` after 1 s |
| silent, threads on | 1 s | **38 571 ms** | `RESULT_TIMEOUT`, once the socket closed |
| silent, threads on, never cancelled, the node freed after 1 s | none | **58 996 ms** | none: the node was gone |

The held frames end when the fake closes its socket (60 s and 120 s after
it started), not when the timeout says. The third row is the other fix
T133 weighed, "never cancel a threaded request, let it end and ignore
it": the node can never be freed without the same join, and leaving the
scene or quitting the game frees it. The `/health` probe T130 measured,
1 s timeout, held 58.4 s the same way ([talk.md](talk.md)).

## What the kit does with it {#rule}

**Threads off, since T133.** Until then the rule was threads on: the
table above found no harm either way on this machine, the documentation
promises nothing, and its one hint at blocking (`ERR_CANT_CONNECT`) is on
the threads-off path. The source answers that hint: the connect and the
name lookup are polled in both modes, and only the threaded path reads in
blocking mode -- and joins. So `HttpRuntime` sets `use_threads = false`
and a fixed `timeout`, and `check_llm_validated.py` (V3) refuses an
`HTTPRequest` in `ai_llm` without it, or with anything else. Off is the
engine's default; the gate asks for it written down, so the reader sees
the choice. `LlmLocalServer` reads `/health` over its own non-blocking
`StreamPeerTCP` (T130), which is the same reads by hand.

Held by `test_a_chat_request_to_a_server_that_never_answers_never_holds_the_frame`
(`godot/test/ai_llm/llm_local_server_test.gd`): against a silent server
with a 1 s timeout, no frame takes 200 ms, `failed` says the server did
not answer in 1 s, and freeing the runtime mid-request takes under
200 ms. With threads on it failed on a 58.5 s frame.

The other half of "never on the frame" is not the engine's at all: the
game must not wait for the answer. `RecordedRuntime` answers a frame or
more later, never inside `send`, so a game written against recordings
cannot come to depend on an instant reply.

## One more finding: Godot's JSON is lenient where Python's is not {#json}

Measured on 4.7.2 while making the two validators agree: `JSON.parse()`
accepts a trailing comma (`{"a": "x",}`, `[1,]`) and the numbers `01` and
`1.`, all of which Python's `json` refuses and RFC 8259 does not allow. It
refuses a lone UTF-16 surrogate (`"\ud83d"`), which Python keeps, and it
keeps the last of a key written twice, as Python does. `LlmValidator`
refuses the first three itself, outside strings, and `gameaikit.llm`
refuses the fourth, so both answer R1 -- each a case in
`spec/vectors/llm/replies.json`. The review of wave 102 measured three
more: a `\u0000` escape becomes U+FFFD in Godot (with a Unicode error
printed) and a real NUL in Python; Godot gives up on lists nested about a
thousand deep and Python does not; and `to_lower()` and Python's `lower()`
fold `İ` differently. Both validators refuse the first two before parsing,
and fold A to Z only when looking for a secret.
