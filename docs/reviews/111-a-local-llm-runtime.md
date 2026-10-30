# Review: wave/111-a-local-llm-runtime

T93: a local LLM runtime for tier 3. llama.cpp's `llama-server` from its
prebuilt archives, and three models, each pinned by sha256 under the
toolchain on the large disk; `scripts/llm` and `tools/llm/`; `make
llm-bootstrap`, `llm-serve`, `llm-smoke` and `llm-bakeoff`; the
`response_format` form and the server's error answers measured at the pin;
`LlmRuntime.refused` and F2; `check_acceptance.py` and
`check_disk_layout.py` taught the runtime; the bake-off; ADR 0023.

A fresh context reviewed PR #51 at head 507a37c.

**Verdict: changes requested, no blockers.** Four should-fix findings and
six nits. Every one was applied on the branch.

## What was reviewed

The diff against main:

- `tools/llm/` (`llm.py`, `runtime.json`, `bakeoff/lines.json`) and
  `scripts/llm`;
- the addon changes (`http_runtime.gd`, `llm_runtime.gd`,
  `llm_conversation.gd`, `llm_reply.gd`, `llm_validator.gd`), the suite,
  `live_probe.gd` and `spec/llm/server-answers.json`;
- `check_acceptance.py` and `check_disk_layout.py`, with their self-tests;
- `docs/local-llm/server.md`, `bakeoff.md` and the 36 raw result files;
  ADR 0023; the technique page in both languages; README in both;
- the Makefile targets, `modules/ai_llm.json` and STATUS.

## What the reviewer found sound

- **Pinning.** Builds are pinned by tag and models by repository revision,
  each file by size and sha256. A mismatch is deleted and refused, with
  planted cases for a wrong sha256 and a truncated file. The archives
  unpack with tar's `filter="data"`. No binary or model is committed, and
  the raw result files hold no local path.
- **Licences.** Each model's licence is recorded with where it was read.
  Pinning a pre-release build through `v0.8.0`'s `nightly-tag.txt` is
  sound.
- **Invariant 8.** `scripts/llm` redirects every cache and keeps the
  server offline, with four planted cases. `check_disk_layout.py` has its
  planted cases.
- **The fence.** Grepped: nothing in the Python package, the addons or the
  games names `tools/llm`.
- **Invariant 5.** `make check` runs only the self-tests; it never starts
  a server.
- **F2.** It never stalls, and the intent is always `unclear`. Sending 503
  to F1 and every other HTTP error to F2 is right. The Python twin has no
  runtime, so it needs no F2.
- **The `response_format` measurement.** A schema only one answer
  satisfies tells "honoured" from "any object". It is well designed and
  held by a test.
- **The rest.** The port is written once. Module selection is correct.
  ADR 0023 is marked proposed.

## Findings

1. **The bake-off counted the game's fallback as a right answer.**
   `summary()` compared each turn's intent with its label on every turn,
   refused ones too. A refusal becomes `unclear` with no argument, and two
   of the 30 lines are labelled exactly that. For example,
   `ministral-3-8b-vulkan-en-r1.json` index 22 is R10 and counted as
   right. Recomputed on accepted replies only, Ministral on Vulkan drops in
   English from 12.3 to 11.0 and in pt-BR from 16.3 to 15.3; Gemma stays
   at 12.3 and 13.3; Granite in pt-BR drops from 3.3 to 2.0. So Gemma, not
   Ministral, is ahead in English.
2. **"Every reply took under a second, after the first" was false** for
   the recommended setup. Ministral on Vulkan, in its first English round,
   took 1.72, 1.97, 1.92 and 1.20 s at indices 4, 7, 18 and 22, and
   1.07 s at index 22 of its first pt-BR round. Three other claims were
   also wrong or missing:
   - STATUS gave Granite's pt-BR range as 3-7 valid; that is CUDA's, and
     Vulkan's is 4-10.
   - "Two runs ... 8 valid replies apart" is not in the committed data;
     the widest spread there is 6.
   - Nothing said that English always runs first, so Vulkan's slow first
     long prompt always lands in an English row.
3. **F2 put unvalidated server text where a game is told to show it.**
   `_error_of` only joined lines and cut at 160 characters before the text
   went into `LlmReply.refusal`. Removing either step was not caught by
   any test. Is there an error at the pin that echoes generated text? And
   should `refused` and `failed` be refused outside the addon, as
   `replied` is?
4. **R7 quoted the model's argument verbatim**, so a secret and markup
   could reach the player. This is T92's code, but it matters more now:
   R7 is the most common refusal, and it runs before R11, which reads only
   the speech. Measured: the argument `"the password is NIGHTJAR
   [b]x[/b]"` gave the refusal `R7 \`the password is NIGHTJAR [b]x[/b]\`
   is not an argument \`ask\` takes`.

**Nits:**

- `LlmRuntime.send`'s doc did not mention `refused`.
- `check_acceptance.py` missed `python3 tools/llm/llm.py … smoke`, and
  the port on `0.0.0.0` or `[::1]`.
- `llm.py`'s `fetch` let an `HTTPError` escape as a traceback, and
  `main()` had no docstring.
- `check_modules.py` counts a path in a Python docstring as a dependency
  (`REPO_PATH_RE`). This wave hit it.
- ADR 0023 did not say what happens if upstream deletes the pinned build.
- T94 should be told three things:
  - `LlmConversation._history` has no limit, while the server runs with
    `--ctx-size 4096`;
  - an `anyOf` per intent, to cut R7, should be measured there;
  - the labels are worth a skim.

## What was done about them

1. **Scored on accepted replies only.** `summary()` counts the act, and
   the act with its argument, only on replies the validator accepted. A
   refusal on an `unclear` line now has its own column. The table was
   regenerated from the committed raw files; no model was run again.
   Act and argument right, on Vulkan:

   | | English | pt-BR |
   |---|---|---|
   | Ministral 3 8B | 11.0 (10-12) | 15.3 (13-17) |
   | Gemma 4 E4B | 12.3 (12-13) | 13.3 (12-15) |
   | Granite 4.2 8B | 8.7 (7-11) | 2.0 (0-4) |

   "The choice" now says Ministral wins in pt-BR and Gemma edges it in
   English. ADR 0023 and STATUS say the same. `default_model` stays
   Ministral, for pt-BR, and the owner picks.
2. **Timings and ranges, recomputed from the raw files.**
   - All but 8 of the 1,080 replies took under a second, and all 8 were
     on Vulkan, in a model's first round.
   - Three of the 8 are each model's first long prompt (3.1, 6.9 and
     10.1 s), always on an English line.
   - The other five are Ministral's first round: four in English (1.2 to
     2.0 s) and one in pt-BR (1.07 s).
   - CUDA had none.
   - The table has a "1 s or more" column. Granite's ranges are given per
     build. The spread sentence says 6, and the page says English runs
     first.
3. **The server's text is cleaned.**
   - `_error_of` turns line breaks and control characters into spaces,
     drops markup (`LlmValidator.MARKUP`), and cuts at 160 characters. It
     now reads the body with `JSON.new().parse`, which prints nothing on
     a bad body.
   - A test holds all three steps, and removing any one of them turns the
     suite red. The reason a 503 sends to `failed` goes through the same
     cleaning.
   - Read in llama.cpp's source at `b11960`, and written up in
     `server.md`:
     - the route handler returns any exception's text as the error;
     - the final chat-format parse failure keeps the output in the log
       only, and the older "Failed to parse input at pos N: <output>" is
       not at this tag;
     - `compute_diffs`, on the streaming path, throws messages that
       contain generated text. `HttpRuntime` does not stream.
   - `refused` and `failed` are not refused outside the addon. "refused"
     already means other things in the tactical recording, the bot match
     and the model-file tests, and `failed` is everywhere, so a rule would
     fire across the kit. Both are listed under the gate's known misses,
     with this reason, and a game should take the text from
     `LlmReply.refusal`.
4. **No refusal quotes the model any more.** In both languages:
   - R4 is now "the reply has a key the shape does not";
   - R6 is now "the intent is not one this game declared";
   - R7 is now "the argument is not one \`<intent>\` takes", naming only
     the declared intent.

   Three vector cases plant a secret and `[b]` in a wrong argument, a
   wrong intent and an extra key. A new property, in both suites, says no
   refusal contains a secret or `[b]`. Restoring the quoting R7 in Python,
   or a quoting R6 in Godot, turns each side red. The technique pages
   describe the rules, not their sentences, so they needed no change. The
   committed raw bake-off files keep the old wording, and `bakeoff.md`
   says so.

**The nits, all applied:**

- `send`'s doc names `refused`, and `refused`'s doc gives the measured
  400 and 500 rather than "a 4xx, say".
- The acceptance pattern takes `tools/llm/llm.py … smoke|serve|bakeoff`
  and the port on `0.0.0.0` and `[::1]`, with three planted cases.
  Removing the address alternatives fails two of them.
- `fetch` turns a failed download into `Refused`, deleting the partial
  file. A real 404 against the release was seen refused by name.
  `main()` has a docstring.
- `check_modules.py`'s docstring records the docstring false positive; the
  gate is unchanged.
- ADR 0023 says a deleted upstream build breaks bootstrap on a fresh
  machine only, and that the way out is a new pin, never an unpinned
  download.
- T94's task file gained a short section for all three points.

## The reviewer's runs

- `make test-godot-some SUITES="test/ai_llm"`: 25 cases.
- `make test-llm-vectors`: 57 cases, both languages.
- The Python `test_llm*` tests: 16.
- Every gate this wave touched, with `--self-test`, and `scripts/llm
  --self-test`.
- The lints.
- A script that recomputed the bake-off from the raw files.

## Owner decisions, with the reviewer's opinion

- **The model.** Ministral 3 8B for pt-BR, saying plainly that Gemma 4
  E4B edges it in English.
- **The build.** Keep Vulkan as the default, with `FLAVOUR=cuda`
  documented as the faster choice on NVIDIA.
- **`anyOf` per intent.** Defer it to T94 and measure it there.
- **ADR 0023.** Accept it once findings 1 and 2 are corrected, which they
  now are.
- **The 30 labels.** Acceptable; the owner skims them.
