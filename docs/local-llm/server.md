# llama.cpp's server at the pinned build: what it says, and what it does

<!-- doc-meta
half_life: tool
verified_on: 2026-11-06
tier: 3
source: https://github.com/ggml-org/llama.cpp/releases/tag/b11960 ; https://github.com/ggml-org/llama.cpp/releases/tag/v0.8.0 ; https://github.com/ggml-org/llama.cpp/blob/b11960/tools/server/README.md ; https://github.com/ggml-org/llama.cpp/blob/b11960/tools/server/server-common.cpp ; https://github.com/ggml-org/llama.cpp/blob/b11960/LICENSE ; https://github.com/ggml-org/llama.cpp/blob/b11960/grammars/README.md ; https://github.com/ggml-org/llama.cpp/blob/b11960/common/json-schema-to-grammar.cpp ; https://github.com/ggml-org/llama.cpp/blob/b11960/src/llama-grammar.cpp
invalidated_if: tools/llm/runtime.json pins another build, or the server's README at the pinned tag changes what it says about --port, --reasoning, --offline, response_format or a schema's pattern
teaches: none
-->

> The local LLM is tier 3 and no lesson needs it (invariant 5): the
> recordings are the lesson. This page is what T93 read before relying on
> the server, then what it measured, on 2026-10-29, on the owner's machine:
> an RTX 5070 (12 GB), a Ryzen 5 9600X, 30 GB of RAM, Linux, NVIDIA driver
> 615.78. The decision is [ADR 0023](../adr/0023-a-local-llm-is-llama-cpp-pinned-by-tag.md);
> the models are compared in [the bake-off](bakeoff.md).

## The release that is pinned {#release}

T93 was written on 2026-10-26 against a release list where every build
(`b11901` that day) was a release. On 2026-10-29 it is not quite so: the
builds (`b11988` the newest that evening, several a day) are marked
*pre-release*, and one release, `v0.8.0` (2026-10-28), carries a single
file, `nightly-tag.txt`, which says `b11960`. So the pin is **`b11960`**,
the build the project's first versioned release names -- commit
`8642541b2`, MIT (its `LICENSE`, shipped in every archive). Each archive is
pinned in `tools/llm/runtime.json` by size and sha256; the sha256s are the
digests GitHub lists for the assets, and each was checked against the
downloaded bytes.

| flavour | archive | size |
|---|---|---|
| Vulkan (default) | `llama-b11960-bin-ubuntu-vulkan-x64.tar.gz` | 35 MB |
| CPU (fallback) | `llama-b11960-bin-ubuntu-x64.tar.gz` | 23 MB |
| CUDA 13.4 | `llama-b11960-bin-ubuntu-cuda-13.4-x64.tar.gz` and its `cudart-` archive | 164 MB + 440 MB |

Each unpacks to `$toolchain/llm/bin/b11960-<flavour>/`, a folder that
runs as it is: `llama-server` finds its libraries beside it.

## What the documentation says {#documented}

From `tools/server/README.md` at `b11960`, opened 2026-10-29:

- **`--port PORT`**: "port to listen (default: 9931)". The kit passes it
  anyway, from `HttpRuntime.PORT` -- the one place it is written.
- **`--host`**: "default: 127.0.0.1". Passed anyway.
- **`-c, --ctx-size N`**: "default: 0, 0 = loaded from model" -- up to
  256K tokens for Gemma 4, which the KV cache would then be sized for. The
  kit passes 4096: a few turns of a short conversation.
- **`-rea, --reasoning [on|off|auto]`**: "Use reasoning/thinking in the
  chat". Granite 4.2 thinks by default (its card: "full thinking
  (default)"), and Gemma 4's template has a thinking channel; a guard who thinks for a paragraph answers in
  tens of seconds. The kit passes `off`.
- **`--offline`** / `LLAMA_ARG_OFFLINE`: "forces use of cache, prevents
  network access". `scripts/llm` sets it: only bootstrap downloads, pinned.
- **`LLAMA_CACHE`**: where the server keeps models it fetches itself
  (`-hf`). `scripts/llm` points it at the toolchain.
- **`response_format`**: "supports both plain JSON output (e.g.
  `{"type": "json_object"}`) and schema-constrained JSON (e.g.
  `{"type": "json_object", "schema": {...}}` or `{"type": "json_schema",
  "schema": {...}}`)".

The last example is wrong, and the source says so: `server-common.cpp` at
the same tag reads, for `"type": "json_schema"`, the schema from
`response_format.json_schema.schema` -- OpenAI's nesting -- and for
`json_object` from `response_format.schema`. The README's `json_schema`
form, with `schema` beside `type`, is read as an empty schema: "any object".

## What measuring says {#measured}

The schema that tells the forms apart asks for one key nobody writes
unasked, `{"zzz": "qqq"}`, and the prompt asks for `{"name": ...}`. Gemma 4
E4B on the Vulkan build:

| `response_format` | answer | schema |
|---|---|---|
| `{"type": "json_schema", "json_schema": {"name": ..., "strict": true, "schema": S}}` (HttpRuntime's) | `{"zzz": "qqq"}` | **honoured** |
| `{"type": "json_schema", "schema": S}` (the README's) | `{"name": "Gemma 4"}` | ignored: any object |
| `{"type": "json_object", "schema": S}` | `{"zzz": "qqq"}` | honoured |
| `{"type": "json_object"}` | `{"name": "Gemma 4"}` | any object |

So **`HttpRuntime`'s form is the right one and is unchanged**; a test now
holds it (`test_the_schema_goes_in_the_form_the_pinned_server_honours`).
`strict` is not read; it is harmless. The game's schema -- `maxLength: 280`
on `speech`, an `enum` of intents -- converts without a warning.

What the server answers when it will not take a request, recorded in
`spec/llm/server-answers.json` and replayed by `llm_test.gd`:

| request | status | body (`error.message`) |
|---|---|---|
| `response_format.type: "bogus"` | 400 | `response_format type must be one of "text" or "json_object", but got: bogus` |
| a schema with a `$ref` to nothing | **500** | `JSON schema error at #: cannot resolve $ref #/definitions/missing, definitions not found` |
| any request while the model loads | 503 | `Loading model` (for 0.1 to 7 s after start, here) |
| a `pattern` with a lookbehind | 200 | the pattern dropped, with a warning in the log: "accepting any string" |
| a `schema` that is a string, not an object | 200 | the schema ignored |

T92's review guessed a schema the server cannot read would be "a 400,
say"; it is a 500. So `HttpRuntime` does not split on 4xx: **503 is
`failed` (F1, the server not ready, a turn lost); any other non-200 is
`refused` (F2), with the server's own sentence, cleaned (below)** -- the request itself is
wrong, and every turn will be refused the same way until it is fixed.
Before T93 both were F1, and a server that refused every request read as
a run of "no reply came".

**Can a server error carry the model's own words?** Read in the source at
`b11960` (`common/chat.cpp`, `tools/server/server-task.cpp`,
`server-context.cpp`), not measured. The route handler sends any
exception's text back as the error message ("got exception: ..."). The
final parse of a reply that does not fit the chat format throws "The model
produced output that does not match the expected ... format", with the
output itself only in the server's log; the older "Failed to parse input
at pos N: <output>" is not at this tag. But `compute_diffs` -- reached from
`update_chat_msg` on the streaming path, which `HttpRuntime` does not use
-- throws "Invalid diff: '<earlier text>' not found at start of '<later
text>'" and "Current msg text content: <text>", which are generated text.
So the answer is "not on the path the kit takes, at this build", and the
next build may differ. That is why `HttpRuntime` cleans the reason before
it reaches `LlmReply.refusal`, which a game shows: line breaks and control
characters become spaces, markup (`<>[]*` and the backtick) is dropped,
and it is cut to 160 characters (T93's review; a test holds all three).

One more, which the validator catches and the schema does not prevent:
asked for a poem with the game's schema, Gemma 4 wrote its reasoning into
`reasoning_content` despite `--reasoning off`, ran out of tokens, and
returned an empty `content`. Empty content is R1, the game's line. A
schema constrains the reply; it does not make one arrive.

## A `pattern` on a string

T116 asked whether the server can be held to a speech with no markup, a
`pattern` on `speech`, under `strict: true`. Read on 2026-11-05 at
`b11960`:

- `grammars/README.md`, the server's schema support, in its "known
  limitations": "[pattern]s must start with `^` and end with `$`", and
  "Unsupported features are skipped silently."
- `common/json-schema-to-grammar.cpp`, which the README does not cover:
  - A string with a `pattern` becomes that pattern's grammar, and
    `minLength` and `maxLength` are not read beside it. The string branch
    returns on the pattern first. So a length has to be in the pattern.
  - The grammar matches the string's JSON text between its quotes, escapes
    and all, not the decoded string. A class like `[^*]` would let a raw
    `"` or a line break through and break the JSON, so the class must
    leave out the quote, the backslash and the control characters too.
  - A pattern the converter cannot translate is dropped with a warning,
    "accepting any string". That is the lookbehind row in the table above.
    A malformed one is an error.
  - Inside a class it reads `\x`, `\u`, `\t`, `\n`, `\\`, `\"`, `\[`, `\]`
    and `\-`.

Measured on Ministral 3 8B, Vulkan build:
`` ^[^"\\<>\[\]*`\x00-\x1F\x7F]{1,280}$ ``. The model was asked to write `*very*`, `[sighs]`, a backtick and a quoted word.
Without the pattern it wrote all four. With it, it wrote none, and the log
had no warning. The game's schema now carries this pattern
(`LlmValidator.SPEECH_PATTERN`); what it did to the 30 lines is in
[the talk page](../godot/talk.md#the-schema-measured). The validator's R10
is unchanged, because a runtime may ignore the schema.

Sources, opened 2026-11-05:
<https://github.com/ggml-org/llama.cpp/blob/b11960/grammars/README.md>;
<https://github.com/ggml-org/llama.cpp/blob/b11960/common/json-schema-to-grammar.cpp>.

### The line separators and the C1 controls (T129)

T129 added the C1 controls, U+0080 to U+009F, and the line and paragraph
separators, U+2028 and U+2029, to R9 and to the pattern's class:
`\x7F-\x9F`, then the two separators as the characters themselves. Before
relying on the server to read them, the source at `b11960` was read again on
2026-11-06. Nothing was measured against a model.

- `common/json-schema-to-grammar.cpp` copies a class into the grammar as
  it is written. An escape must be one `gbnf_escape_length` knows: `\x`
  with two hex digits, `\u` with four, `\U` with eight, or one of
  `\t \r \n \\ \" \[ \] \-`. Any other character, a separator's three
  UTF-8 bytes included, is copied byte by byte. None of those bytes is a
  `]` or a `\`, so the class still ends where it should.
- `src/llama-grammar.cpp` then parses each member with `parse_char`. It
  reads `\x9F` with `parse_hex` as code point 0x9F, and a character
  written as itself with `decode_utf8` as its code point. The text the
  model generates is decoded the same way, to code points, before the
  class is checked. So `\x7F-\x9F` is the range of code points 0x7F to
  0x9F, and U+2028 is U+2028, not three bytes.
- The model cannot write the escape `\u2028` either: the backslash is
  already out of the class, so the separator can only be written raw,
  and the class refuses that.
- The separators are written as characters, not as `\u2028`, because
  Godot's `RegEx` (PCRE2) refuses that escape. Measured on 4.7.2:
  `RegEx.compile("^[^\\u2028]$")` fails with "PCRE2 does not support \F,
  \L, \l, \N{name}, \U, or \u". PCRE2's `\x{2028}` compiles there, but
  Python's `re` and the converter do not read it. The character itself
  means the same to all of them, and to JSON Schema.

Sources, opened 2026-11-06:
<https://github.com/ggml-org/llama.cpp/blob/b11960/common/json-schema-to-grammar.cpp>;
<https://github.com/ggml-org/llama.cpp/blob/b11960/src/llama-grammar.cpp>.

## Nothing in `$HOME` {#home}

Left to their defaults, llama.cpp downloads into `~/.cache/llama.cpp`, the
NVIDIA driver keeps shaders in `~/.cache/nvidia` and kernels in `~/.nv`,
and Mesa -- which answers for the integrated Radeon when the Vulkan build
lists its devices -- in `~/.cache/mesa_shader_cache` and
`~/.cache/radv_builtin_shaders`. `scripts/llm` points `LLAMA_CACHE`,
`XDG_CACHE_HOME`, `MESA_SHADER_CACHE_DIR`, `__GL_SHADER_DISK_CACHE_PATH`
and `CUDA_CACHE_PATH` under `$toolchain/llm/cache/`.

Measured by modification time, after bootstrap, the smoke and every
bake-off run: none of the home folders above changed (their newest dates
are 2026-10-21 and older), and Mesa's two caches appeared under
`$toolchain/llm/cache/mesa/`. `check_disk_layout.py` fails on
`~/.cache/llama.cpp` (and `%LOCALAPPDATA%/llama.cpp`); the driver caches
are not listed there, because other software on this machine keeps them.

## What it costs {#cost}

On the large disk: the three builds 0.9 GB unpacked plus 0.6 GB of
archives; the three models 15 GB; the default alone about 5 GB.
