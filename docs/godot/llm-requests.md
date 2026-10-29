# An HTTPRequest and the frame, threads on and off

<!-- doc-meta
half_life: practice
verified_on: 2026-10-29
tier: 2
source: https://docs.godotengine.org/en/4.7/classes/class_httprequest.html ; https://docs.godotengine.org/en/4.7/classes/class_json.html
invalidated_if: the pinned engine changes, or HTTPRequest's use_threads, timeout or request() documentation changes
teaches: none
-->

> Invariant 7 says the LLM never blocks a frame. `ai_llm` asks a local
> server through `HTTPRequest`, so before writing the rule "threads on",
> this page reads what Godot 4.7 documents and measures what 4.7.2 does.
> Measured on 2026-10-29, on the owner's Linux desktop, headless.

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

## What the kit does with it {#rule}

Threads stay on. The measurement says threads off did no harm *here*, on
loopback and on one network; the documentation does not promise it, and
the one place it hints at blocking (`ERR_CANT_CONNECT`) is the threads-off
path. A rule that rests on one machine's numbers is the kind this
repository writes down before it is bitten by them. So `HttpRuntime` sets
`use_threads = true` and a fixed `timeout`, and `check_llm_validated.py`
(V3) refuses an `HTTPRequest` in `ai_llm` without it.

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
`spec/vectors/llm/replies.json`.
