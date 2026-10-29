# Review: wave/102-ai-llm-the-addon-and-its-validator

T92: `ai_llm`, a language model as one more decider behind a validator.
The reply's one shape and the game's declared intents; `LlmValidator` and
its Python twin, held together by `spec/vectors/llm/`; `RecordedRuntime`
and `HttpRuntime` behind the `LlmRuntime` port; `LlmConversation`; the
`HTTPRequest` measurement; and invariant 7's gate,
`check_llm_validated.py`.

A fresh context reviewed PR #42 at head 2e896f4.

**Verdict: changes requested.** Two blockers, eight should-fix findings,
three nits. Every one was applied on the branch. Re-reviewed at 66aa419:
ready to merge (see the end).

## What was reviewed

The diff against main:

- the six addon files and their gdUnit suites, the vector runner and the
  frame probe;
- `gameaikit.llm` (validator, replay, stub server) and its tests;
- the 43-case vector, the reply schema and the recording;
- the gate, its docstring and its self-test;
- the technique page in both languages, the concept page, the measurement
  page, the glossary, the literature row and README;
- CLAUDE.md's row 7, the manifest, the Makefile targets and STATUS.

## What the reviewer found sound

- Both validators read the rules in the same order, and the order is the
  docstring's.
- A refusal becomes the fallback at once. There is no retry and no stall.
- The fallback line is held to the speech rules it stands in for.
- The parser differences the PR claimed were re-measured, and they agree:
  Godot takes a trailing comma, `01` and `1.`; Python takes `NaN` and a
  lone surrogate.
- `RecordedRuntime` answers frames later, never inside `send`.
- `HttpRuntime` has threads on, a timeout, one request in flight, and F1
  on failure.
- The history keeps only what was ruled.
- Secrets never enter a prompt, and R11 is the net.
- The measurement page reads the documentation first and carries
  `verified_on`.
- LICENSE and NOTICE ship in the addon. Invariant 2 holds.
- The pt-BR page matches 25 of 25 headings.
- The gate's exit codes are 0, 1 and 2, and its exemptions are not prefix
  matches.

## Findings

1. **B1, blocker: the gate missed the runtime's `replied` signal.** A game
   could `runtime.replied.connect(_on_text)` and act on
   `text.contains("open")`, which is raw model text driving a rule, and the
   gate exited 0. The same held for `$Runtime.connect("replied", ...)` and
   for `HttpRuntime.text_of(body)["text"]`, a public static returning raw
   text. V2 caught only `LlmReply.new`, `llm_reply.gd` and `.raw_text`.
2. **B2, blocker: CLAUDE.md overstated the gate.** By its own docstring it
   is a net for plain spellings, which is exactly why row 6 says "half
   held". Row 7 claimed more, and the prose dropped 7 from the list of
   invariants not fully held.
3. **A conversation could stay "thinking" forever (measured).** `say`, then
   take the runtime out of the tree mid-request: `is_thinking()` stayed
   true, `is_busy()` was false, and every later `say` was ERR_BUSY.
   - `RecordedRuntime` returned without emitting anything.
   - `HttpRuntime._exit_tree` cancelled without `failed`.
4. **V0 passed on an empty `godot/addons/ai_llm/`.** This is invariant 4's
   empty-scene question.
5. **V1's exemption covered all of `godot/test/ai_llm/`.** That included
   `gatekeeper_example.gd`, the file the page tells readers to copy.
6. **Other bypasses exited 0 when planted.**
   - Outside the addon:
     - `OS.execute("curl")`;
     - `PacketPeerUDP`, `WebSocketMultiplayerPeer`, `JavaScriptBridge`;
     - `reply.get("raw_text")`;
     - `const Made := LlmReply`;
     - `preload("uid://...")` of `llm_reply.gd`;
     - a game spinning `while conversation.is_thinking(): OS.delay_msec(10)`.
   - Inside the addon:
     - `OS.execute`;
     - `Semaphore.wait()`;
     - `use_threads = true`, then `= false`;
     - a busy `while not _done: pass`.
7. **`_strip_line` ignored backslash escapes.** On the line
   `var s := "a\"b"; add_child(HTTPRequest.new())`, everything after the
   escaped quote was blanked, so the gate exited 0.
8. **The gate took about 11 s a run.** Each line resolved paths twice, and
   each line re-split the whole file (quadratic).
9. **Vector gaps.**
   - Python mutants that survived every `test_llm*`:
     - `strict=False` set to `True`;
     - DEL dropped from R9;
     - the backtick dropped from `MARKUP`;
     - the `RecursionError` catch dropped.
   - A Godot mutant survived: DEL dropped from R9.
   - Three real disagreements:
     - `"\u0000"` in a speech: Python R9; Godot accepts, its parser making
       U+FFFD.
     - Nesting about 1100 deep: Godot R1; Python R4.
     - A secret `istanbul` and the speech `"İstanbul"`: Godot R11; Python
       accepts, because `"İ".lower()` is i plus a combining dot.
10. **The manifest's gates.** `modules/ai_llm.json` lists only
    `test-llm-vectors`. Does a runtime-only change select the `test/ai_llm`
    suites?
11. **Nits.**
    - `HttpRuntime.timeout_seconds` was read only in `_ready`, so setting it
      later did nothing.
    - `body_size_limit` was unlimited.
    - The gate did not read `.tres`.

## What was done about them

1. **V2 now refuses `replied` outside the addon**, written either as
   `.replied` or as the string `"replied"`. `text_of` is now `_text_of`,
   private, and V2 refuses a call to it outside the addon. There is a
   planted case for each spelling.
   - `llm_test.gd` no longer listens to `replied`: it listens to
     `answered`, as a game must.
   - The envelope test now goes through the conversation, feeding the
     runtime's completion handler, and adds an HTTP 400.
2. **CLAUDE.md row 7 reads "half held"**, saying the gate is a static net
   for the common spellings, mirroring row 6. The prose lists 4, 6, 7 and
   13 again. The gate's docstring says "half-hold" and lists what it does
   not catch.
3. **Both runtimes emit `failed` when taken out of the tree mid-request.**
   `RecordedRuntime` does it from its waiting coroutine; `HttpRuntime` does
   it deferred from `_exit_tree`, after cancelling. A test for each runtime
   takes it out mid-request and checks three things: the conversation is
   not thinking, the reply is F1, and the next `say` is OK.
   - `LlmConversation.say` does not clear `_thinking` itself. The deferred
     `failed` would then answer the next request.
4. **V0 requires `llm_validator.gd` and `llm_reply.gd`.** Planted case: an
   addon with no validator.
5. **The V1 exemption is now `http_frame_probe.gd`, by path**, for
   `HTTPRequest` and `HTTPClient` only. Planted case: an `HTTPRequest` in
   `godot/test/ai_llm/gatekeeper_example.gd`.
6. **New rules, each with a planted case:**
   - V1:
     - `OS.execute`, `execute_with_pipe` and `create_process`;
     - `PacketPeerUDP`, `UDPServer`, `WebSocketMultiplayerPeer` and
       `JavaScriptBridge`.
   - V2:
     - `"raw_text"` as a string;
     - an alias of `LlmReply`;
     - `llm_reply.gd`'s uid, read from its `.uid` file.
   - V3, in the addon:
     - another program, or a `Semaphore`;
     - `use_threads` set to anything but `true`;
     - a `while` that never `await`s.
   - V3, anywhere: a `while` on `is_thinking()` or `is_busy()` that never
     `await`s. The sound tree keeps a game that waits by yielding.
   - Still not caught, now listed in the docstring:
     - names built at run time (`ClassDB.instantiate`, `Callable`,
       `Expression`);
     - `set("use_threads", false)`;
     - a node made by an instanced script;
     - a thread the addon starts and a game joins;
     - a game that parses `speech` instead of acting on `intent`.
7. **`strip_line` tracks the backslash inside strings.** Planted case: the
   reviewer's line.
8. **Each file is read once into a `Source`**, with its place, its code
   and its uncommented text. A run now takes 0.3 s.
9. **Vectors: 43 to 56 cases.**
   - New cases:
     - a tab and a line break written literally inside the string (R9);
     - DEL (R9);
     - a lone backtick (R10);
     - a `\u0000` escape (R1);
     - an escaped backslash before `u0000`, accepted;
     - nesting 40 deep (R1), 32 deep (R4) and 1100 deep (R1);
     - forty brackets inside a string after an escaped quote (R4);
     - a non-ASCII secret in capitals (R11);
     - the same secret lowercased past Z, accepted;
     - `İstanbul` against `istanbul`, accepted.
   - Each disagreement now has one answer.
     - **NUL:** both refuse a `\u0000` escape before parsing (an odd run of
       backslashes, the same regex in both), and Python a literal NUL.
     - **Depth:** both cap nesting at 32, counted outside strings, as R1.
       Python's `RecursionError` catch is gone, since it is unreachable.
     - **Secrets:** both fold A to Z only. This is the honest common
       ground: a secret's other letters must match as written. The page
       says so.
   - Godot now runs the strictness checks before its parser, so a NUL
     escape no longer prints the engine's Unicode error.
10. **The manifest is right as it is.** Measured with `affected.py --paths`
    on `godot/addons/ai_llm/recorded_runtime.gd`, the selection is:
    - `test-python-some PYTESTS="test_llm test_llm_vectors"`;
    - `test-llm-vectors`;
    - `test-godot-some SUITES="test/project_settings_test.gd test/ai_llm"`;
    - `lint-llm-validated` among the lints.
11. **The nits.**
    - `timeout_seconds` is read by every `send`.
    - `BODY_SIZE_LIMIT` is 64 KiB, and a test reads it off the request.
    - The gate reads `.tres` as it reads `.tscn`.

On the open points:

- **`response_format`:** left to T93, as the reviewer agreed. T93's task
  file now asks it to measure the form on the pinned llama.cpp. It also
  asks for a recorded test that tells "the server refused the request"
  (say, a 400) apart from "the model's reply was refused", and for the
  runtime's default port to come from T93's one place.
- **The mutation self-test** in the gate was not added, as agreed. That
  effort went into the vectors.

## The reviewer's runs

- 21 planted files of the reviewer's own against the gate: 16 were not
  caught at 2e896f4.
- 6 Python mutants: 4 survived.
- 1 Godot mutant: it survived.
- Probes for the stuck conversation and for the three parser and
  lowercasing disagreements.

## The second mutation round

Each mutation broke one rule, and its suite had to fail.

- **The reviewer's survivors (5):** `strict=True`; DEL dropped, in Python
  and in Godot; the backtick dropped, in Python and in Godot.
- **The new validator rules (6):** the NUL escape, the depth cap and the
  ASCII fold, each on both sides.
- **The runtimes (3):** no `failed` on leaving the tree, in each runtime;
  no body limit.
- **The gate (16):**
  - V0 on a hollow addon;
  - the probe exempted by folder again;
  - other programs;
  - escapes in strings;
  - `raw_text` by name;
  - `replied` as an attribute and as a string;
  - `_text_of`;
  - the alias;
  - the uid;
  - another program in the addon;
  - the semaphore;
  - a loop that never yields;
  - `use_threads` not true;
  - waiting on the model anywhere;
  - waiting that yields still flagged.

All 30 were caught. Two needed a vector added first:

- the Godot depth cap (Godot's parser refused 1100 by itself, so 40 deep
  was added);
- Python's depth counter ignoring escapes.

The first round's 30 validator mutants were rerun on the new code, and all
were caught. The pycache was cleared after both rounds.

After the rebase on 552527d, `make check-affected BASE=origin/main`, which
selected all of `make check`, exited 0. The reviewer ran
`make -k check-no-engine`, which also exited 0.

## Re-review

Re-reviewed at 66aa419 (rebased on 552527d) by the same reviewer: ready to
merge. Both blockers are fixed. Planted files that call a runtime's
`replied` (by attribute, `&"replied"` or `await`) or `_text_of` are
refused, and CLAUDE.md row 7 says half held. All 38 language-difference
inputs now get one answer in both languages, and every round-one mutant the
reviewer re-ran is now killed. A runtime removed mid-request answers F1 and
the conversation recovers. The gate runs in 0.33 s, with no false positive
in the repository. Left as small follow-ups: `extends LlmReply` /
`extends LlmValidator` outside the addon, and assigning to an `LlmReply`'s
fields, are neither caught nor listed among the known misses. Also, no
vector sits at depth 33, so the `MAX_DEPTH = 33` mutant survives.

All three follow-ups were applied, and their mutants were caught:

- V2 refuses `extends LlmReply` and `extends LlmValidator` (by name, or
  the validator by path) outside the addon, with three planted cases.
- `LlmReply`'s fields are read-only: properties over private fields whose
  setters `push_error` and keep the ruling, held by a test.
  `return LlmReply` and then `.new()` is listed among the gate's known
  misses.
- A vector at depth 33 must be R1, and `MAX_DEPTH = 33` now dies in both
  languages.
- The nit is applied too: `LlmConversation` and the page say a
  conversation dies with its runtime.
