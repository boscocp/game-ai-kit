# Status

The index. One row per task; the task file holds everything needed to do it.
The topmost `## Resuming after` section is the next session's prompt.

## Resuming after 2026-11-06, the owner's manual checks and list

**Where it stopped -- read first.** No wave ran. The owner played the
manual checks the section below lists, and answered its numbered list.
Main is 3854667.

**The list, all twelve as recommended** ("das 12 decisões pode seguir o
recomendado"). Three open work: item 7 is T139, item 8 is T140, and item
12 is T141, with the trap already added to CLAUDE.md's traps. Item 4
(no `PROCESS_MODE_ALWAYS` while no game pauses) and item 9 (the 0.1.0
promise covers ten `Gak` names; ADR 0024 can record it as decided) need
no task.

**Manual checks.** Passed, in the owner's words "fora isso tudo ok": T88,
T96, T128, T130, T131 and T132. Each demo's log was also read for engine
errors, and `pgrep llama-server` was empty after both talk sessions.
Found, each now a task:

- **T136.** Bram's newest line was cut mid-sentence; the label clipped
  it, not the model.
- **T137.** In the XCOM mode, the hit chance on a hovered enemy sits on
  the piece's number.
- **T138.** `make demo-rts` closed with 21 leaked objects and 15
  resources in use; no other demo did.

And one ruled not a fault: in `make demo-rts`, a squad stops chasing a
target that walks into the fog. `Squad` scores only what its side sees
now (`squad.gd`, `FocusFire.scores`), so an empty view clears the focus.
The owner: "parece realmente comportamento correto". T128's stale ring is
drawing only, as it said.

**Still waiting:** T133's check (SIGSTOP the server during a turn).

**Next.** Unchanged: T112, alone. Then the squad tasks one at a time
(T117, T124, T125, T127, T134, and now T137, which also writes
`godot/game/squad/`); T135 beside any of them. T136, T138, T139 and T140
share no folder with the squad tasks or with each other, except T140
after T139. T141 and T121 each run alone.

## Resuming after 2026-11-06 (waves 136 to 142 merged)

**Where it stopped -- read first.** Two batches ran one after the other,
as the owner asked ("pode rodar o lote T88, T128, T133 e T119", then "Pode
seguir com as 3 recomendadas em paralelo"). Each wave was reviewed by a
fresh context before its merge, and the findings were applied on its
branch:

- **136 T88**, expectiminimax faces MCTS in the XCOM mode (#87). Reviewed
  twice. The first review found a blocker: the duel runner exited 0 with
  "0 failure(s)" after a SCRIPT ERROR, having played nothing. The second
  review found the same in 5 of 12 plants: an aborted typed function
  returns an empty Array, so a broken validator reads like one that found
  nothing. `scripts/godot_checked.py` now fails a `-s` gate on any engine
  error in its output; the coordinator then had its output sent to a file
  (a pipe deadlocked past 64 KiB). The duel is split: `test-squad-duel`
  (counted budgets, about 22 s) in `check`, `measure-squad-duel` outside.
  A crash in T87's `MctsSquad` under the clock is guarded, not explained:
  T134.
- **137 T128**, a focus ring outlives its sight (#84). The blocker was the
  PR body: it held T133's text (see below).
- **138 T133**, a silent server never holds the frame (#85).
  `HTTPRequest` runs with `use_threads = false`; V3 refuses the setter
  and the conditional spelling too.
- **139 T119**, a gate for the pt-BR glossary (#86): `lint-glossary`.
- **140 T120**, `Xorshift` becomes `GakXorshift` (#89). Approved with
  nits.
- **141 T129**, line separators are refused in a speech (#88).
- **142 T96**, wave function collapse builds maps for the XCOM mode (#90).
  Reviewed twice, the second time because the fixes changed
  `scripts/catalogue.py`. `ConstraintDraws` stays for now: T135.

Main is c41cc99.

**Batch routine, what went wrong and was fixed.**

- The coordinator's first briefs gave no scratch folder per wave. Two
  waves wrote one `pr-body.md` and one `check.log` in the shared
  scratchpad root: #84 went up with T133's body, and a wave read another's
  log. Every brief since names `<scratchpad>/waveNN/`, and each wave
  confirms its body with `gh pr view N --json body`.
- T120's Notes said not to run it beside T96; the coordinator's first
  proposal missed that. T120 and T129 ran together, and T96 after T120.
- Typing a ` ` escape through the editing tools can write the raw
  character instead. T129's docs and vectors held raw U+2028/U+2029 until
  review; they were rewritten from a script and checked with
  `grep -P '[\x{2028}\x{2029}\x{80}-\x{9F}]'`.
- Five Godot duel runners from T88's measurements (a scratch
  `run_duel.sh`) were left asleep for 8 h. The coordinator was not allowed
  to signal them; the shutdown at the end of the session ended them.

**How it was checked.**

- Each wave ran its own `check-affected`.
- The coordinator ran the whole `make check` once, alone (load under 1),
  in a clean worktree on #90's head cada6b7 before it merged: exit 0,
  1828 gdUnit cases and 0 failures, the five LLM-server endings all
  "server gone", and the 9 `SCRIPT ERROR` lines all from in-memory
  planted scripts (`gdscript://`).
- The first run of that check stopped at `import`: Godot crashed with
  signal 11 importing a cold cache, as T120's reviewer also saw once
  (exit 139). The rerun passed. It is not filed as a task; if it comes
  back, it is one.

**Waiting on the owner -- one numbered list, each with a recommendation.**
Each PR body holds the reasoning.

1. T88 (#87), decisions 1-10, among them: the duel stays in `check` only
   on counted budgets (decision 10, rewritten after the review); the `SearchingSquad` refactor; follow-up T134.
   *Recommended:* keep.
2. T128 (#84), decisions 1-4: handed view before memory; rivals out of
   sight get no ring; the stale ring white and dashed; no panel text.
   *Recommended:* keep.
3. T133 (#85), decisions 1-2: threads off rather than a hand-written
   client; `use_threads = false` written out. *Recommended:* keep.
4. T133: with threads off, a paused tree pauses the request and its
   timeout. Set `PROCESS_MODE_ALWAYS`? *Recommended:* no, while no game
   pauses; the header says so.
5. T119 (#86), decisions 1-5, and keying `EMPHASIS` by page.
   *Recommended:* keep; not by page yet.
6. T129 (#88), decisions 1, 4 and 5. *Recommended:* keep.
7. T129 (#88), decision 2: format controls (Cf: zero-width, bidi) still
   pass R9. *Recommended:* a task of their own.
8. T129 (#88), decision 3: `HttpRuntime` cleans a refusal reason of C0
   and DEL only. *Recommended:* a small follow-up that reuses R9's test.
9. T120 (#89): does the 0.1.0 promise cover ten `Gak` names?
   *Recommended:* ten. ADR 0024 records it as open.
10. T120 (#89), decisions 2-3: Python keeps `Xorshift`; history keeps
    the old name. *Recommended:* keep.
11. T96 (#90), its decisions, among them: the task's three first
    decisions confirmed; `ConstraintDraws` until T135; maps not
    mirrored; the catalogue now walks each mode's ruleset.
    *Recommended:* keep.
12. A trap for CLAUDE.md: a SCRIPT ERROR in a typed function returns the
    type's default, so an empty Array reads as "nothing wrong", and
    `godot_checked.py` exists for it. *Recommended:* add it to the
    traps, and move the other `-s` gates onto `godot_checked.py` in a
    task.

**Manual checks waiting:**

- **T88:** `make demo-tactical MODE=squad`, the expectiminimax enemy: do
  the overlay's expected values and the status's depth read well?
- **T128:** `make demo-rts`, V on, chase a squad's target out of sight:
  the ring turns thin, white and dashed, and may jump back up to 0.5 s.
- **T133:** in the talk game, stop `llama-server` with SIGSTOP during a
  turn: the frame never holds, and the timeout says so.
- **T96:** `make demo-tactical MODE=squad`, N twenty times, play two; B a
  few steps. Do the maps look like places, and does the longer legend fit?
- Still waiting from the last section: T130, T131, T132.

**What is left:**

- todo: T89 (its condition not met), T112, T113-T115 (after the
  repository opens), T117, T121, T124, T125, T127, T134 and T135;
- six older tasks still wip: T25, T40, T44, T45, T46 and T48;
- T43, blocked.

**Next, as proposed by this session.** T112, the review before the
repository opens, has every prerequisite merged (T87, T88, T94, T96,
T110, T111, T120). It reads the whole repository, so it runs alone.
After it, the squad tasks (T117, T124, T125, T127, T134) one at a time,
since they all write `godot/game/squad/`; T135 beside any of them; T121
last.

## Resuming after 2026-11-05, third batch (waves 133 to 135 merged)

**Where it stopped -- read first.** The owner played the talk game and the
menu, and three waves came out of what they found. Each was reviewed by a
fresh context before its merge, and the findings were applied on its
branch:

- **135 T132**, a language change keeps the talk guard in the tree (#80).
  Changes requested: the test wrote the person's own saved language, and
  the PR gave a wrong reason for keeping the fix in the scene.
- **134 T131**, the menu's cards speak Portuguese (#81). Changes
  requested: the PR used two terms the demos do not ("lance", "casa"), and
  twelve sentences were reworded.
- **133 T130**, the talk game starts its own model (#82). It was reviewed
  twice: the coordinator asked for a second review of the new code only,
  since the first review's fixes added a process signal, a key and a gate:
  - The first review asked for four things: the server dies with the game
    on Ctrl+C, leaving while the model loads is tested, a server that has
    gone is found again, and the timeout's `OS.kill` falls under the gate.
    It also raised, for the owner, that a server the game starts ran with
    no API key; each such server now gets a random key.
  - The second review found a blocker: the new endings gate could run
    `os.kill(-1, SIGKILL)` and kill every process the user owns. That
    happened when anything already answered on its fixed ports. The fix
    gives each run a free port, signals only a pid whose parent is the
    run's Godot, and has a planted case.

Main is 4f6a02b.

**The owner said on 2026-11-05:**

- "nao fiz o make llm-serve, n tem como deixar isso parte de executar o
  jogo?" They then answered "as 3" to three proposals:
  - the game starts the server on Tab;
  - the menu cards in pt-BR;
  - the `add_child` fix.
- "Lembre de colocar mecanismo de quando fechar o jogo tbm fechar o
  servidor llm pra não ficar gastando vram". This is held by
  `make test-llm-server-ends` (five ways the game can end), in
  `make check`.
- After running `make llm-serve` and playing the talk game in pt-BR from
  the menu: "agora foi, ficou mt obm". The coordinator reads this as
  T94's and T116's manual check passed in live mode; the owner did not
  say so, and the other questions on those checks were not answered one
  by one.

**How it was checked.**

- Each wave ran its own `check-affected`. T131 and T130 selected
  everything (a script under `scripts/`); T132 selected `menu` and `talk`.
- The coordinator ran the whole `make check` once, in a clean worktree, on
  #82's head (8c6e771): exit 0, 1755 gdUnit cases, 0 failures, and the
  five endings all "server gone". No `llama-server` or test process was
  left running.
- An earlier full run, on #82's previous head, was stopped by the
  coordinator once the blocker was known. It had included the dangerous
  gate.

**Waiting on the owner -- one numbered list, each with a recommendation.**
Each PR body holds the reasoning.

1. T132, decisions 1-3 and 5. The fix stays in the scene, the test uses
   its own settings file, `current_scene` is set from `tree_entered`, and
   there is no cross-scene gate. *Recommended:* accept.
2. T132, decision 4. `language.gd`'s rule, in the PR's words, is written
   by the next wave that touches that file. *Recommended:* accept.
3. T131, decisions 1, 2, 4-6. *Recommended:* keep.
4. T131, decision 3: "Furtividade" or "Stealth" for the 2D card.
   *Recommended:* "Furtividade".
5. T131: 10 of 16 pt-BR list titles are wider than the list and get cut
   with an ellipsis (9 of 16 in English). *Recommended:* decide by eye,
   between shorter titles and two lines per item.
6. T130, decisions 1-10:
   - the starter in `ai_llm`;
   - no model in a headless run;
   - no warm-up, and the status line says the first answer is slowest;
   - `OS.kill` only on leaving;
   - any `/health` but 503 counts as ready;
   - typing open when the server runs by hand or has stopped;
   - a found server gone after four unanswered asks;
   - the server stops however the game ends;
   - the key in the environment;
   - POSIX-only fake-server tests.

   *Recommended:* keep.
7. T130 (a): the ~90 ms frame when leaving the scene. *Recommended:*
   keep.
8. T130 (b): the hitch of up to ~101 ms after Tab, windowed, while the
   weights load onto the GPU. *Recommended:* accept.
9. T130 (c): off Linux, Ctrl+C leaves the server running, and
   `pkill llama-server` stops it. *Recommended:* accept until a Windows
   or macOS wave.
10. T130: `make llm-serve` still runs without a key. *Recommended:* leave
    it so. A key for it is a small follow-up if wanted.

**Manual checks waiting:**

- **T130:** `make demo-talk`, press Tab without `make llm-serve`. Does
  it load and answer? Close the window: is `llama-server` gone
  (`pgrep llama-server`)?
- **T131:** `make menu` in Português. Do the cards read well, and are the
  cut titles acceptable?
- **T132:** `make demo-talk` with pt-BR saved, then English. Is there no
  error?

**What is left:**

- todo: T88, T89 (its condition not met), T96, T112 (after T88, T96 and
  T120), T113-T115, T117, T119-T121, T124, T125, T127-T129 and T133;
- six older tasks still wip: T25, T40, T44, T45, T46 and T48;
- T43, blocked.

**Next, as proposed by this session from the task rows:** T88 (squad),
T128 (RTS) and T133 (`ai_llm`'s chat request) share no file (T88 and
T128 both write under `docs/concepts/`, in different pages), so they can
run together. T129 also writes `ai_llm`, so it runs after T133.

## Resuming after 2026-11-05, second batch (waves 128 to 132 merged)

**Where it stopped -- read first.** Five waves ran in parallel worktrees.
Each was reviewed by a fresh context before its merge, and the findings
were applied on its branch:

- **129 T116**, the guard's speech without markup (#76). Changes
  requested, both documentation. The README and `json_schema()` now say
  the pattern is stricter than the validator. The quote evidence now
  counts 180 replies, not 360.
- **131 T122**, levels solved off the main thread (#73). Changes
  requested. The panel named a solve that would no longer replace the
  level. Nothing tested the scene's lifecycle around the task: three
  planted faults passed.
- **128 T126**, the XCOM mode's view moves out of its rules (#74).
  Changes requested. Nothing tested which view draws after M. Two moved
  defaults and three older answers were untested too.
- **130 T118**, the RTS shows the enemy a clocked side believes (#75).
  Approved with two should-fix findings. The tests could not tell the
  handed enemy from one recomputed from the world, and nothing tied the
  drawing to it.
- **132 T123**, the bot match reads the team's share (#77). Changes
  requested. Two things had no test: a seat on a reading's step, and
  `mate_` events from the other team. The page claimed the band was
  smallest "on all three", which its own table contradicts.

Main is 580ec92.

**The owner decided on 2026-11-05:**

- "roda as 5", for T126, T116, T118, T122 and T123. That includes the two
  follow-ups deferred earlier the same day.

**How it was checked.**

- Each wave ran its own `check-affected`, and none selected everything.
  T126's PR body lists its suites by name; its `check-affected` (7
  modules, exit 0) is in the implementer's report to the coordinator.
- All five merged at the head that carries the review's applied
  findings, with main merged in where it had moved. The fixes were not
  reviewed again.
- The coordinator ran the whole `make check` once, in a clean worktree,
  on #77's head (e680a6d): exit 0, 1732 gdUnit cases, 0 failures. The
  log is not committed. Its nine `SCRIPT ERROR` lines are the same
  in-memory planted ones as in the batch before.
- One `test-rts-match` run failed its timing claims at load average 14,
  and passed when rerun at 3.6.
- T126's row is marked done here; its wave left it `todo`.

**The owner answered on 2026-11-05, after the list below:** "nao li mas 1
a 12 conforme recomendado" -- not read, but items 1-12 as recommended. So:

- items 1, 3, 4 (accepted; the manual check still judges `tactical.gd`),
  5, 7, 10 and 11: ratified as recommended;
- items 2 and 12: no task. Each is a follow-up only if wanted (a demo
  seed for 144) or seen in play (the knob alternating);
- item 6: task T128, this session's proposal, not the PR's;
- item 8: T116's raw probe outputs are committed in
  `docs/local-llm/markup/`, 24 files, one per candidate, language and
  round;
- item 9: task T129.

**The owner played the XCOM mode on 2026-11-05:** "gostei do Xcom, nada
pra mudar" -- liked it, nothing to change. That is taken as asking for
no art, so T89's condition (only if T85's manual check asks for art) is
not met and it is not run. It stays `todo` until the owner closes it.
The other questions of T85's, T87's and T126's manual checks (the hit
chance, MCTS's bars, the two modes side by side) were not answered one
by one.

**Waiting on the owner -- one numbered list, each with a recommendation.**
Each PR body holds the reasoning.

1. T122, decisions 1-7 and 9:
   - the scene polls the pool;
   - one solve at a time;
   - headless solves inline;
   - the first world solved inline;
   - one panel line;
   - a new page, `worker-thread-pool.md`;
   - a script, not a make target;
   - leaving the scene mid-solve waits up to about 2.5 s.

   *Recommended:* keep all.
2. T122, decision 8: the demo reaches only seeds 3-5, not the slow 144.
   *Recommended:* do the manual check on 3-5. A command-line seed for the
   demo is a follow-up only if you want 144 on screen.
3. T126, decisions 1-4:
   - the ruleset hands its view through `mode_view()`;
   - `rule`, `announcement`, `tint` and `points` moved too;
   - `reveals` moved and `can_still_attack` stayed;
   - four answers stay on `SquadRuleset`.

   *Recommended:* keep.
4. T126, decision 5: `tactical.gd` grew by 12 or 13 lines (860 to 872
   in the PR, 873 at the reviewed head). The reviewer reads
   it as slightly easier. *Recommended:* accept, and judge it in the
   manual check.
5. T118, decisions 1-7:
   - hollow rings with a thread;
   - the age written once;
   - no legend row;
   - waiting commands in the panel only;
   - the wait measured at the last decision;
   - only east shown;
   - the focus ring at the target's current place.

   *Recommended:* keep. Add a legend row only if the manual check finds
   the rings unclear.
6. T118: a corner case older than this PR. A focus ring disappears when
   its target leaves the computer's current sight, while the squad still
   holds that focus. *Recommended (this session's proposal, not the
   PR's):* a small follow-up that falls back to the handed position.
7. T116, decisions 1-6 and (a):
   - the pattern, not the prompt line;
   - T93's prompt kept;
   - no straight quote or backslash;
   - the pattern in `reply.schema.json`;
   - no new vector family;
   - the recordings not made again;
   - the pattern always on until a second game needs otherwise.

   *Recommended:* ratify.
8. T116, decision 7: commit the raw probe outputs under `docs/local-llm/`,
   so a later reviewer can recount. *Recommended:* yes. They are in a
   session scratch folder, which does not outlive the session, so this
   needs doing soon or the probe needs running again.
9. T116, (c): U+2028, U+2029 and C1 controls such as U+0085 pass both R9
   and the pattern. *Recommended:* a small task: a validator change with
   vectors in both twins.
10. T123, decisions 1, 2 and 4-6:
    - the band at 0.45-0.55, best by the sum of the leads, not in the
      worst case;
    - the same prior of 100;
    - a seat stamped with the last step;
    - the row back to the middle at once;
    - only seats of a bot logged.

    *Recommended:* keep.
11. T123, decision 3: `PlayerModel.team` is an int label beside the
    counts. *Recommended:* accept it as within N14's "counts and sums".
12. T123: with the band equal to the middle row's range, the knob returns
    to the middle row only on a change of team. *Recommended:* step one
    row at a time as a follow-up, only if the alternation shows in play.

**Manual checks waiting:**

- **T122:** `make demo-infiltration`, K to solved, then L across seeds
  3-5. Does the window keep drawing?
- **T126:** play both tactical modes with V on and off. Is `tactical.gd`
  easier to read?
- **T118:** `make demo-rts` with K on during a raid. Does the computer's
  answer follow the late rings?
- **T116:** read the new table rows on the technique page.
- **T123:** play the bot match poorly and then well with V open, then
  take a bot on the other team. Does the match settle?

**What is left:**

- todo: T88, T89 (only if T85's manual check asks for art), T96, T112
  (after T88, T96 and T120), T113-T115, T117, T119, T120, T121, T124,
  T125, T127, T128 and T129;
- six older tasks still wip: T25, T40, T44, T45, T46 and T48;
- T43, blocked.

**Next, as proposed by this session from the task rows:**

- T88 is ready now that T126 is done.
- The squad folder takes one wave at a time: T88, then T96, T117, T124,
  T125 and T127.
- T119 (a gate under `scripts/`, which selects everything) runs before
  or after T88 and T96, not beside them: it shares `docs/techniques/`
  and the Makefile with T88.
- T120 and T121 share folders with T88 and T96 (T120 also
  `docs/techniques/`), so each runs before or after them, not beside.
- So the next batch has no second task beside T88 in the open rows.

## Resuming after 2026-11-05 (waves 125 to 127 merged)

**Where it stopped -- read first.** Three waves ran in parallel worktrees.
Each was reviewed by a fresh context before its merge, and the findings
were applied on the branch:

- 126 T94, talk your way past the guard (#68). Changes requested, one
  blocker: an act the validator admits with an empty argument had no
  rule. Python raised KeyError and GDScript ruled it under "".
- 125 T87, MCTS plays the XCOM-style mode (#69). Approved, with three
  should-fix findings: `principal_line` untested on chance, Enter played
  after four iterations, and the page's times.
- 127 T55, the RTS's human side (#70). Changes requested, one blocker: K
  replayed every recording in `data/rts/` on every frame. Two leaks the
  gate could not see were also found: the delayed side was handed
  current enemy fields, and its own units' targets were current.

Main is 1910534.

**The owner decided on 2026-11-05:**

- "deixa os followup pra depois rode as 3 que dao pra seguir em paralelo
  entao". The three were T87, T94 and T55. T96 shares `godot/game/squad/`
  with T87, and T89 waits on T85's manual check. The follow-ups left for
  later are 2026-11-04's items 12-13 (the bot match) and 10 (levels on
  `WorkerThreadPool`). This session had proposed them to make five.

**How it was checked.**

- Each wave passed its own `check-affected`, which selected everything
  in all three.
- #68 and #69 merged on their reviewed heads.
- The coordinator ran the whole `make check` once, in a clean worktree, on
  #70's head after it merged main (25c8fa5): exit 0, 1708 gdUnit cases,
  0 failures. The log is not committed. Its nine `SCRIPT ERROR` lines come
  from in-memory scripts (`gdscript://`). Six are `free` on Nil in a
  `step_decision`, which only the planted overlay cases in
  `godot/test/menu/demo_overlays.gd` define. The other three are
  abstract-class parse errors.

The auto-mode classifier refused a force-push, so the branches were
brought up to date by merging main into them, not by rebasing. The squash
merge drops the merge commits.

**Answered by the owner on 2026-11-05 -- do not ask again.** What each
item now means is in "The owner decided on 2026-11-05 (second answer)",
after the list. It was: one numbered list, each with a recommendation.
The 24 items of 2026-11-04 below were then still open; they were answered
the same day. Each PR body holds the reasoning.

1. T94, decisions 1-11:
   - the scene's numbers and the rule shape;
   - the anyOf schema and `RecordingRuntime` in `ai_llm`;
   - the recordings kept as one take, and T93's prompt kept;
   - the 100-character line;
   - the first file name answering a shared prefix;
   - the vectors from the Python replay;
   - keys, and exported builds.

   *Recommended:* ratify 1-11. Decision 12 has no recommendation: two T93
   labels for you to skim.
2. T94, decision 13: the schema now offers the empty argument, matching
   T92's validator and prompt. *Recommended:* keep it. Tighten all three
   only if the manual check shows bare acts misused.
3. T94: R10 (markup in the speech) is the main refusal left.
   *Recommended (this session's proposal, not the PR's):* a small
   follow-up that measures a schema or prompt forbidding it.
4. T87, decisions 1-10 (the six-line hook in `tactical.gd`, Enter
   finishing each search, the search's own walks held to
   `TacticalReach`, the evaluation, the constants, the fog guess,
   `principal_line` in the addon, no strength gate, the vectors from one
   run, the files outside the task's line). *Recommended:* ratify all ten.
5. T87, decision 11: on a walk question the visit bars are nearly flat
   (22-26 visits over 41 answers). *Recommended:* keep it, and revisit
   with a less noisy playout, measured by `make measure-squad-mcts`.
6. T87, decision 12: a fixed 4 iterations a frame leaves about 11 ms of
   the frame unused. *Recommended:* a follow-up that searches a time share
   of the frame in play and keeps the count for matches and tests.
7. T55, decisions 2, 3, 5, 7 and 8 (only the enemy delayed,
   whole-decision delays, "never sees, earns or orders more" held as three
   exact checks, the reaction proxy, the meter's place). *Recommended:*
   ratify.
8. T55, decisions 1 and 4: the knobs stand at AlphaStar's 350 ms and 22
   in 5 s. At 22 the cap never binds, so the checks hold it at 2 in 5 s.
   *Recommended:* play `make record-rts` a few times. Then run
   `make measure-rts-clock`, commit what it writes, and take the cap from
   the recordings' busiest window. The alternative is to count a command
   as two actions.
9. T55, decision 6: M7 keeps the 10-minute league out of `make check`.
   `make check` holds the hands-nothing-over half
   (`test-rts-clock-limits`). The strength half is `make test-rts-league`.
   *Recommended:* ratify. The other answer is a "slow gate" kind in the
   manifests, a selector change.
10. T55, decision 9: commit the `data/rts/` recordings, as ADR 0017 says.
    *Recommended:* commit them.
11. T55, decision 10: nothing shows the stale enemy a clocked side
    believes in (invariant 13). *Recommended:* a follow-up task.

**The owner decided on 2026-11-05 (second answer):** "todas conforme
recomendado". It answers both numbered lists: the 11 items above (A1-A11
below) and the 24 of 2026-11-04 (B1-B24). Each item is settled as its own
recommendation says, and no further: where that was "decide after
playing" or an owner action, it stays one. The answer is read as covering
these two lists only: the 13 items of 2026-10-30 stay as that section
leaves them.

- **A1** ratified: T94's decisions 1-11. Decision 12 had no
  recommendation, so it stays the owner's: two T93 labels to skim.
- **A2** ratified: the empty argument stays. It is tightened only if
  T94's manual check shows bare acts misused.
- **A3** task opened: T116, the guard's speech without markup, measured.
- **A4** ratified: T87's decisions 1-10.
- **A5** kept as it is: the nearly flat visit bars. Revisit with a less
  noisy playout, measured by `make measure-squad-mcts`. No task yet.
- **A6** task opened: T117, the squad's MCTS searches a share of the
  frame.
- **A7** ratified: T55's decisions 2, 3, 5, 7 and 8.
- **A8** an owner action, pending: play `make record-rts` a few times, run
  `make measure-rts-clock`, commit what it writes, and take the cap from
  the busiest window.
- **A9** ratified: the 10-minute league stays out of `make check`.
- **A10** ratified: commit the `data/rts/` recordings once they exist.
  None exists yet; they come from A8.
- **A11** task opened: T118, the stale enemy a clocked side believes in.
- **B1** ratified: the guide keeps `release.py --build`.
- **B2** ratified: 0.1.0 promises only ADR 0024's nine `Gak` names, and
  any other name may change below 1.0. Written into ADR 0024 (amended
  2026-11-05).
- **B3** ratified.
- **B4** task opened: T119, a gate for the pt-BR glossary.
- **B5** ratified: `BanditDraws` folded in.
- **B6** task opened: T120, `Xorshift` becomes `GakXorshift`. It is a
  prereq of T112, so it lands before anything is published.
- **B7** ratified: the wheel ships `gameaikit.core`. Written into ADR
  0024, amending "technique packages only".
- **B8** ratified: the next wave updates CLAUDE.md's invariant 2 (the
  generator) and its `library-check` line. This PR does not edit
  CLAUDE.md.
- **B9** task opened: T121, every vectors runner checks its types.
- **B10** task opened: T122, levels solved on `WorkerThreadPool`. A
  follow-up the owner deferred ("deixa os followup pra depois"): it waits
  for the owner's word on when.
- **B11** ratified: T95's eight decisions. Tuning the numbers in
  `level_constraints.json` is the owner's, in T95's manual check.
- **B12, B13** one task opened: T123, the team's share with a band, and
  the counts starting empty on a change of team. Deferred like B10.
- **B14** ratified: the bot match's log stays in `user://`.
- **B15** ratified, both: N14 names `MatchDifficulty`; the table stays in
  `rules.json`.
- **B16** still open, by its own terms: decide after playing.
- **B17** task opened: T124, V off in play and on in the teaching view.
- **B18** task opened: T125, a second, stronger floor.
- **B19** task opened: T126, the XCOM mode's mode view. T87 has landed,
  so T88 now waits on T126 (its file and row say so).
- **B20** ratified: T85's nine items. The squad's defence (0-10) is
  still measured in play, in T85's manual check.
- **B21** ratified: T111's rule 6 and what went beyond its decisions.
- **B22** ratified: `packages` stays committed and sorted; revisit only
  if it still conflicts.
- **B23** ratified: the timing gates run alone in the coordinator's last
  gate. Written into `docs/howto/parallel-batch.md`.
- **B24** task opened: T127, an unseen shooter stays unseen in the news.
  Which of the two answers is the task's to choose.

After this answer, todo adds T116-T127. T88 waits on T126. T112 waits
on T120 as well. T122 and T123 wait on the owner's word, besides their
prereqs.

**Manual checks waiting:**

- T94: play `make demo-talk` live (Tab) in a window, in both languages.
  The live path has run only headless.
- T87: in the XCOM mode, give the enemy to MCTS (C) with V on. Watch
  whether the bars grow, and press space early.
- T55: play the RTS with K on and off, and watch M during a replan.

**What is left:** todo T88 (after T126), T89 (only if T85's manual
check asks for art), T96, T112 (after T120), T113-T115, T116-T127 (T122
and T123 wait on the owner). The older wip and blocked tasks are as in
2026-11-04.

**Next, as proposed by this session from the task rows:** T126 first (T88
waits on it) and T96. Both write `godot/game/squad/`, so they do not run
together. T112 waits on T88, T96 and T120.

The owner asked on 2026-11-05 which next waves run in parallel. This
session proposed T126, T116, T118, T122 and T123 (optionally T119), with
T120 and T121 each run alone. Not yet chosen.

## Resuming after 2026-11-04 (waves 118 to 122 merged)

**Where it stopped -- read first.** Five waves ran in parallel worktrees,
each reviewed by a fresh context before its merge, with the findings
applied on the branch: 118 T77 the library in two languages (#59), 122 T109
one seeded generator in `ai_core` (#60), 120 T95 levels by constraints
(#61), 121 T100 the bot match reads the player (#62), 119 T85 the XCOM-style
mode you can play (#63). Every review asked for changes. Three had
blockers, all fixed before the merge:

- T77: the page's first step could not run for a stranger.
- T95: an unlabelled constraint was never enforced.
- T85: a walk refusal leaked the fog, and a typed-array ternary blanked the
  status.

Main is dd8d41a.

**How it was checked.** The owner said on 2026-11-04 to run the gate only
at the last merge. So #60 to #62 merged on their reviewed heads, rebased
the coordinator rebased #61 to #63. #61 conflicted in the Makefile's
`test-vectors:` and in `pyproject.toml`'s `packages`, #62 in
`test-vectors:` only, and #63 had no conflict. Each was resolved as a
union. #60's implementer rebased it. The whole
`make check` ran once, on #63's rebased head, before it merged: exit 0,
1641 gdUnit cases, every gate including the timing ones. #59 had its own
full run.

By the coordinator's account, the batch hit the account's 5-hour usage
limit while rebasing, and the coordinator finished the rebases and merges
by shell.

**The owner decided on 2026-11-04:**

- these five waves in parallel, with T77 in place of T110 (T110 shares
  `godot/game/tactical/` with T85);
- run the gate only at the last merge;
- after the main tasks, a review of the repository before it opens to
  the community (T112). Which tasks count as "the main ones" (T112's
  prereqs) is this session's reading;
- after it opens, a decision tree, a random forest and a Bayesian network,
  fitted into existing demos (T113-T115). Which demo each one goes in is
  this session's proposal, not ratified;
- to make parallel batches cost less time and fewer tokens, and redo
  less. The owner accepted the recommendation that followed: T111 next,
  in parallel with T110 only.

Publishing to PyPI and the Asset Library was recommended to wait until the
repository is public. That is not decided.

**Answered by the owner on 2026-11-05 (items 1-20, and 21-24 below) --
do not ask again.** What each item now means (B1-B24) is in the 2026-11-05
section above, "The owner decided on 2026-11-05 (second answer)". It was:
one numbered list, each with a recommendation. The 13 items of 2026-10-30
below are still open. The review records hold the reasoning.

1. T77: the page builds the archives with `release.py --build` (Python and
   git only); `make release` is named as the full release. *Recommended:*
   keep.
2. T77: the page says 0.1.0 promises only ADR 0024's nine `Gak` names, and
   any other name may change below 1.0. That is new policy.
   *Recommended:* ratify, and write it into ADR 0024.
3. T77: the second example runs only under `make library-check`, and
   `GUIDE_PAGES` is a third kind of page in the translations gate.
   *Recommended:* ratify.
4. T77: a gate for the glossary rule (an italicised English term in a
   pt-BR page must be in the glossary). *Recommended:* a small task later.
5. T109: `BanditDraws`, a fourth copy the task did not list, folded in.
   *Recommended:* ratify.
6. T109: `Xorshift` or `GakXorshift`. The reviewer leans to the prefix
   (ADR 0024 prefixes the kernel; the name may collide in a user's
   project). *Recommended:* `GakXorshift`, before anything is published.
7. T109: the wheel ships `gameaikit.core`, which the shipped techniques
   import. *Recommended:* ratify, and amend ADR 0024's "technique packages
   only".
8. CLAUDE.md is stale in two places: invariant 2 ("the grid and the
   pathfinder interface") does not name the generator, and the
   `library-check` line still says two addons. *Recommended:* let the
   next wave update both.
9. T109: a follow-up task to give every `*_vectors_runner.gd` the type
   checks the core runner gained (`mcts_vectors_runner.gd` has the same
   hole). *Recommended:* open it.
10. T95: solving stalls the window for 120-140 ms a level, 2.5 s on the
    slowest seed. Today that is cached by seed and documented.
    *Recommended:* solve on `WorkerThreadPool`, as a small follow-up.
11. T95: the eight listed decisions -- GDScript only, 16 candidates a
    variable, restarts instead of backjumping, K's three-way cycle with
    the fallback, the untuned numbers in `level_constraints.json`, what
    "in sight" covers, K on the switch line, the counts beside the map.
    *Recommended:* ratify; tune the numbers in the manual check.
12. T100: the difficulty overshoots. One bot's share sets six bots' aim,
    and the match flips both ways (`make measure-player-model`).
    *Recommended:* a follow-up reading the team's share, with a band of no
    change around the middle, measured the same way.
13. T100: when the person takes a bot of the other team, the counts carry
    on. *Recommended:* start them empty on a change of team.
14. T100: the log stays in the checkout's `user://`, not `data/`.
    *Recommended:* ratify -- it is the person's play, not a fixture.
15. T100: N14 names `MatchDifficulty` as well as `PlayerModel`, as N13
    names its wrapper. Its tunable table lives in `rules.json`, while
    T99's constants stay in the class. *Recommended:* ratify both.
16. T85: under fog, a walk onto a hidden piece is refused in words that
    name nothing; the other answer is to stop at the last free cell and
    reveal the piece, as XCOM does. *Recommended:* decide after playing it.
17. T85: V is on by default, so the person sees every enemy piece once a
    round. *Recommended:* V off in play, on in the teaching view.
18. T85: 100 of 100 against `RandomSquad` cannot tell weighings apart.
    *Recommended:* a second, stronger floor with T87.
19. T85: `TacticalRuleset` has about 25 answers and `tactical.gd` is 832
    lines. *Recommended:* move the presentation hooks to a mode-view
    object before T87 and T88.
20. T85: the PR's nine items, the squad's defence included (0-10, to be
    measured in play). *Recommended:* ratify.

**Manual checks waiting:**

- T77: follow the pt-BR guide on a machine that never cloned the
  repository.
- T109: read the ADR 0021 amendment cold, then play the maze and the MCTS
  example.
- T95: play the drawn and the solved levels, and watch K.
- T100: play the bot match with V open, poorly and then well.
- T85: play the XCOM mode on both sides, with V on and off.
- The older checks in the sections below.

**Then, the same day: waves 123 and 124.** Two more pull requests landed in
parallel. Each was reviewed by a fresh context before its merge, with the
findings applied on the branch:

- 124 T110, the tactical news keeps its words as keys (#65). The review
  approved it with two should-fix findings: the switch test read in only
  one direction, and the XCOM shot's side had no test.
- 123 T111, a new gate selects its module and merges clean (#66). Its
  review found a blocker, fixed before the merge: a new manifest could
  claim global paths (CI, `godot/override.cfg`, another module's vectors),
  so their tests would never run.

The whole `make check` ran on #66's rebased head, the round's last merge:
exit 0, 1652 gdUnit cases. Main is dc1eb83. T111's replay of wave 120 now
selects three modules instead of everything. Waves that touch `scripts/`,
`project.godot` or the manifests still select everything, by design.

**Added to the owner's list above** (answered with it on 2026-11-05):

21. T111: rule 6 (a new technique module selects itself), new targets
    that are not gates selecting nothing, and the sort refusals on
    `packages` and `KIT_MODULES`. These go beyond the task's decisions.
    *Recommended:* ratify (PR #66's body has each).
22. T111: generate the wheel's `packages` from the manifests at build
    time, so the list never conflicts. PR #66 recommends keeping it committed
    and sorted, because a build-time list needs a setup step that
    `pip install ./python` lacks. *Recommended:* keep it sorted, and revisit
    only if it still conflicts.
23. The timing gates (RTS, MCTS) still fail under the load of parallel
    worktrees whenever their module is selected. *Recommended:* run them
    alone in the coordinator's last gate.
24. A fog hole older than T110, found by its review. In the XCOM mode, an
    unseen mortar (sight 6, reach 7) shoots a red piece, and the news names
    the mortar and its cell, though red cannot see it. *Recommended:* a
    follow-up task, either wording the news from the person's fog or making
    a shot reveal its shooter.

**What is left:** todo T55, T87, T88, T89 (only if T85's manual check asks
for art), T94, T96, T112, T113, T114, T115. Six older tasks are still wip
(T25, T40, T44, T45, T46, T48), and T43 is blocked.

**Next, as proposed by this session from the task rows:** T87 first,
since it needs T85 and T86, both done.

- T96 also writes `godot/game/squad/`, so it runs after T87, not beside
  it. T88's prereq is T87.
- T94 can run beside T87, because they share no folder. It waits on the
  owner's T93 choices (the default model, ADR 0023), which are listed in
  the 2026-10-29 section below.
- Follow `docs/howto/parallel-batch.md`.
- T112 comes after the main tasks.
- T113 to T115 come after the repository opens, which is the owner's step
  after T112, not T112 itself.

## Resuming after 2026-10-30 (waves 112 to 117 merged)

**Where it stopped -- read first.** Six pull requests landed in one session,
each reviewed by a fresh context before merging, its findings applied on the
branch, the gates re-run on the reviewed head before `gh pr merge` (CI stays
off): 112 T64 the library (#52), then five in parallel worktrees -- 117 T108
the pad legend's height (#53), 116 T57 the RTS seat bias (#57), 115 T99 a
bandit chooses the fighting opponent's answers (#56), 114 T90 a director
paces the infiltration (#55), 113 T84 the XCOM-style mode's rules (#54).
Every review asked for changes; one blocker (T84: a shot at an enemy the
shooter could not see) was fixed before its merge. Main is cf22b8d. Each wave's
`make check-affected` selected all of `make check` and passed on its final
base; timing gates (RTS and MCTS, by the implementers' reports) flaked
under the load of five worktrees and passed rerun alone. **Run `make check` again first.**

**The owner decided on 2026-10-30, before T64's code:** the prefix `Gak`, on
the nine names a user's code types (ADR 0024); `AimChoice` moves to
`ai_utility`; then the five waves above, in parallel.

**Waiting on the owner -- one numbered list, each with a recommendation**
(the review records hold the reasoning):

1. T64 manual check: read one addon's zip and the wheel as a stranger
   (`make release`, then `dist/`). *Recommended:* do it before publishing.
2. T64: how an addon reaches the Asset Library -- a repository per addon,
   or one entry for the kit (it downloads a repository's archive; see
   `docs/godot/addon-anatomy.md`). *Recommended:* decide on the day of
   publishing; the README links a repository that is private today.
3. T84: the squad's defence values. The reviewer: 10-20 defence on top of
   rock's 40 makes a target behind rock nearly unhittable (0-5%); suggests
   0-10. *Recommended:* 0-10, measured in T85's playtest.
4. T84: the menu's `modes` key stays with T85 (its Files line owns the
   menu). *Recommended:* ratify.
5. T84: `RandomSquad` as the squad roster's one row, the floor T85's first
   enemy must beat. *Recommended:* ratify.
6. T90: the decay pause. "No decay while engaged" read as "alert and seeing
   the player" pins stand-offs in the fade for minutes. The reviewer: define
   chasing as alert, seeing and closing in, then a spec cap such as
   `chase_pause_most: 10` with its own vector; and a separate task for the
   stand-off itself, which looks like a T70 guard issue. *Recommended:* as
   the reviewer says, as a new task.
7. T90: the director stays off by default until the manual check.
   *Recommended:* ratify.
8. T90: the whole cycle is held on one chosen level (generated 10).
   *Recommended:* accept; revisit after 6.
9. T99: the opponent's UCB1 constant 0.5, not sqrt(2) (tables on the
   fighting page, one seed; chosen against the same stand-ins it is
   measured on). *Recommended:* ratify.
10. T99: the payoff constants (30-frame window, range 100) live in
    `FightBanditOpponent`, not the fighting data, and the window starts when
    the option lands -- departures from the task's wording.
    *Recommended:* ratify.
11. T57: the gate is now an exact two-sided binomial test, p < 0.05, on six
    seeds played both ways; the paired statistic was not added; open:
    whether six seeds is enough, since twelve matches cannot see a 60/40
    seat. *Recommended:* keep it as it is.
12. T57: a follow-up task, "the RTS regions as mirror images", for the two
    opposite biases left (base falls favour west, time-outs favour east):
    claim 1 checks `REGIONS` as well as `MAP` (the bridge at (24,15) is the
    only neutral region not its own mirror, and east's home is ~1.4 cells
    nearer it), regions scored at the cell's centre, each change measured
    alone. *Recommended:* open it.
13. T108 (from PR #53's body; its review record has no owner section):
    the RTS legend ends 6 px above `Thinking`, and the racers' maps moved
    into the view's corner. *Recommended:* ratify the maps; extend the
    legend gate to the RTS in a later wave.

**Manual checks waiting:** T99 in `make demo-fighting` (a bandit mode,
answer one situation the same way: does it switch, after how many
exchanges, has it forgotten after a restart, is `>` on the highest bound);
T90 in the infiltration demo (key 6); T108 with a real pad in both
languages; and the older ones in the section below.

**Follow-ups noted, no task yet:** the 2D racer's `Speedo` ends at y=708,
past the gutter (before T108); a pad plugged in mid-game never adds its
legend lines (no `joy_connection_changed`). About forty stale agent
worktrees sit under `.claude/worktrees/`; nothing was deleted.

**What is left:** 12 tasks todo (T55, T77, T85, T87, T88, T89 -- only if
T85's manual check asks for art --, T94, T95, T96, T100, T109, T110), 6
older ones still wip (T25, T40, T44, T45, T46, T48) and T43 blocked.

**Next:** T77 (the library in two languages, docs only); then, in
parallel: T85 (after T84), T100 (after T99), T95 (infiltration is free
again), T109, T110 (no longer clashes with T84 once T84 is in); T94 waits
on T93's choices in the section below.

## Resuming after 2026-10-29 (waves 101 to 111 merged)

**Where it stopped -- read first.** Eleven pull requests (#41 to #51)
landed in one session, each reviewed by a fresh context before merging,
its findings applied on the branch, the module gates re-run locally by the
coordinator before `gh pr merge` (CI stays off): 101 T86 MCTS (#41), 102
T92 `ai_llm` and invariant 7's gate (#42, re-reviewed after two
blockers), 103 T101 `ai_utility` (#43), 104 T97 the Pac-Man maze (#45),
105 T107 the wrapped panels (#44), 106 T98 value iteration plays the maze
(#48), 107 T91 the particle filter (#49), 108 T104 the tactical reasons as
keys (#47), 109 T103 the pad legend in pt-BR (#46), 110 the owner's
decisions of 2026-10-29 (#50), 111 T93 a local LLM runtime (#51). Waves
ran three or four at a time in separate worktrees.

`make check` was green on main at the start (4d73707); every wave's
`make check-affected` selected all of `make check` and passed on its base;
the last, T93's, ran on d0661a7 plus T93 (= 4390b60). **Run `make check`
again first.**

**The owner decided on 2026-10-29** (wave 110): T84's XCOM design
confirmed; ADR 0016's amendment confirmed (T99 and T100 make the
`CLAUDE.md` change with N13 and N14); invariant 6's row names N15; T98's
MDP solves "chase for ever" (option b) and its policy lives in
`godot/game/maze/`; T93 now; T64 next, alone; new tasks T108 (the pad
legend's height), T109 (one seeded generator in `ai_core`), T110 (the
tactical news as a `Sentence`); no maze generator warm-up; the rest
ratified as listed in each review record. The owner played
`make demo-maze` (T97, T98): nothing to adjust.

**Waiting on the owner:**

- T93's choices: Ministral 3 8B as the default model (best in pt-BR;
  Gemma 4 E4B edges it in English), Vulkan as the default with CUDA
  documented, accepting ADR 0023, skimming the 30 bake-off labels;
- what each review record leaves open: T86's dice-race scoring; T101's
  `PassageChoice`, the pages' tier, `squad_example.gd`; T103's width break
  and `demo_overlays.gd` plant;
- manual checks: T107's panels windowed in both languages, T103 with a
  real Xbox pad on the seven demos, T91's particle overlay, T104 switching
  language mid-turn, and the older ones below (the localised demos, the
  technique pages, T83 on Windows, deleting `$toolchain/xdg`).

**Known gaps:** while CI is off, a merge has no message gate in code --
always run `python3 scripts/check_pr_message.py && python3
scripts/check_commit_msg.py` before `gh pr merge`. The session scratchpad
is shared between parallel agents: keep each agent's scripts in its own
folder (an agent once ran another's `mutate.py`).

**Next:** T64 (the library), alone; then T77. After that, in parallel:
T90 or T95 (one infiltration wave at a time), T57, T108, T109, T110; T94
after T93 (it measures `anyOf` per intent and the history limit); the
XCOM chain T84, T85, T87, T88; T99 then T100.

## Resuming after 2026-10-26 (waves 87 to 100 merged)

**Where it stopped -- read first.** Fifteen pull requests (#26 to #40) landed in one
session, each reviewed by a fresh context before merging, its findings
applied on the branch and checked locally (CI stays off while the repo is
private): 87 T74 (#26), 88 T78 (#27), 89 T56 (#28), 90 T75 (#29), 91 T79
(#30), 92 T76 (#31), 93 T83 (#32), 94 T80 (#35), 96 the T65 reading (#33),
the roadmap after T73 as tasks T84-T101 (#34), the lint-commits exception
(#38), 98 T105 (#36), 100 T102 (#37), 99 T106 (#39), and 97 T65 (#40).
T65 is closed as measured by the owner's choice: falling back weighed and
respawn waves were built, lost to never falling back (20-0, 7.2 errors),
and were reverted; the record is in `docs/godot/botmatch.md`.

`make check` was green on main at f5ec5d5. **Run it again first**: waves
97 to 100 landed after it.

**Waiting on the owner:**

- the manual checks of the localised demos and the technique pages;
- T84's XCOM-mode design, and the other decisions T84-T101 leave for the
  owner to confirm in review;
- the proposed invariant-6 wording in ADR 0016's amendment;
- deleting `$toolchain/xdg` once no pre-T83 branch remains;
- T83's check on Windows.

**Known gap:** while CI is off, a merge has no message gate in code
(`docs/reviews/fix-a-long-subject-on-main.md`). Always run
`python3 scripts/check_pr_message.py && python3 scripts/check_commit_msg.py`
before `gh pr merge`.

**Next:** in parallel, T84, T86, T92, T97, T101, T103, T104, T107; T64
alone; T77 after it.

## Resuming after 2026-10-25 (waves 83 and 84, on Windows)

**Where it stopped -- read first.** The owner develops on Linux and uses a
Windows desk to play the examples with colleagues. Wave 83 (PR #22) made
the Makefile run there from Git Bash (`docs/howto/windows.md`); wave 84
(T82) made an Xbox controller play the menu and the real-time demos
(`docs/godot/a-controller.md`). Both were reviewed by a fresh context
before merging (`docs/reviews/83-windows.md`, `84-xbox-controller.md`).
Both merged on the owner's word, with the full check left for Linux.

**Next, on Linux:** `make check` on main. On Windows, `test-rts-budget` and
`test-rts-match` fail their frame shares (the same code about twice as
slow), and the botmatch effects, the 3D racer's gates and infiltration's
were not run there.

**Waiting on the owner:** T82's manual check, with a pad.

## Resuming after 2026-10-22 (waves 75 to 82 merged)

**Where it stopped -- read first.** Eight waves landed in one session,
each by pull request after a fresh-context review whose findings were
applied on the branch, checked locally (CI stays off while the repo is
private): 75 (the 3D racer starts on your car, PR #13), 76 (T68, health
that comes back, weighed by exposure, #15), 77 (T71, a new gate selects
its module, #14), 78 (T72, the botmatch effects gate in parallel shards,
six times faster, #16), the task files T73-T80 (#17), 79 (T69, what a
guard perceives and knows, #18), 80 (T70, the infiltration level,
`make demo-infiltration`, #19), 81 (T73, the literature and a roadmap,
#20) and 82 (T81, guards hear a player walking behind them, #21). Their
reviews are in `docs/reviews/7[5-9]-*`, `8[0-2]-*` and
`teaching-docs-and-roadmap.md`.

**Waiting on the owner:**
- T73's seven questions, at the end of
  `docs/concepts/the-literature-and-the-kit.md` (pt-BR and en): which
  roadmap entries and in what order, the board game for MCTS, whether
  ADR 0016's exception extends to bandits or player modelling, `ai_llm`
  now or after T64. Follow-up tasks are written only after the answers.
- The decisions written at the top of T74 and T78 (pages side by side,
  `docs/concepts/` and `docs/godot/` stay English, CSV keyed by English,
  the system language by default).
- The manual checks: `make demo-racing3d`, `make demo-botmatch` (T, then
  watch health come back), `make demo-infiltration` (walk straight behind a
  guard facing along a corridor: it should notice within about two
  seconds; a guard facing diagonally can take about 4.6 s, because sound
  is 4-connected), and T65 (retreat).

**Next:** T74 and T78 (teaching pages, localisation) are unblocked now
that T70 is in; T64 (the library) before T77.

**A defect found** (T83 since, wave 93): every worktree shares one `user://`
(`scripts/godot` sets `XDG_DATA_HOME` to `$toolchain/xdg`), so two waves
running Godot tests at once can collide -- it failed wave 78's
`effect_shards_test.gd` during wave 80's check. Give each checkout its own.

## Resuming after 2026-10-22 (waves 71 to 74 merged)

**Where it stopped -- read first.** Four waves landed in one session,
each by pull request after a fresh-context review and green CI: 71 (T66,
the lanes, the yards and bots that weigh, PR #9), 73 (T54, the 3D racer,
PR #10), 74 (stealth research; T52 became T69 and T70, PR #11) and 72
(T67, the bot as an agent). Their reviews are in `docs/reviews/7[1-4]-*`.

**Waiting on the owner:** the manual checks -- `make demo-botmatch` (T to
play, L for the yards, V for the AI's scores) and `make demo-racing3d` --
and the owner's comments on them; and T65 (change retreat, or close it as
measured).

**Next, in the owner's order:** T68 (health that comes back, weighed by
the bot; needs T67, now merged), then T69 and T70 (the stealth example).
The owner's standing rule, for every example: a bot is an AIMA agent that
weighs what it perceives -- as few fixed if/else in a demo as can be --
and copes on another map.

## Resuming after 2026-10-21 (wave 73)

**Where it stopped -- read first.** Wave 73 did T54, the 3D racer, in
parallel with waves 71 and 72; nothing of the bot match was touched, and
`ai_steering` only gained two files. Its page is `docs/godot/racing3d.md`.

**What landed.** A car on four ray-cast wheels, a driver that is an agent
on its own view, `PidController` and `HeatLine` in `ai_steering` with
Python twins, fourteen vectors, five gates (`make test-racing3d-car`,
`-vectors`, `-effects`, `-ladder`, `-does-not-cheat`, all with
`--fixed-fps 60`), and `make demo-racing3d`.

**For the owner.** The manual check. The heat line's claim did not hold
(75 changes of side against 22), and P only swings rather than settling;
both are said as measured. Kenney's Racing Kit gives the scenery, not the
road: tiles on a grid could not make a second track of any shape.

## Resuming after 2026-10-21 (wave 71, T66 written, review next)

**Where it stopped -- read first.** T66 is written on
`wave/71-the-lanes-map`, one commit a step: height, the lanes, sprint,
the reload, the body, the zones, the aim, ammunition and the power
weapon, solid bodies, `PassageChoice` (a request the teammate weighs),
the yards and its mirror, and the review's fixes. The numbers are
in `docs/godot/botmatch.md`.

**Next: the PR.** The review is in `docs/reviews/71-the-lanes-map.md`,
its findings applied on the branch; push, PR, CI green, `make wave-merge`.
Then rebase `wave/72-the-bot-as-an-agent` (T67, being written in its own
worktree from this branch) onto main. `wave/73-racing-in-3d` (T54) and
`wave/74-the-stealth-research` (T52's research; the owner answered its
four questions, and T52 is now T69 and T70) are in worktrees of their own. The owner's manual check (`make demo-botmatch`, T to play,
L for the yards) is in T66.

**Then T67** (`tasks/T67-the-bot-as-an-agent.md`), the owner's choice:
the bot as AIMA's agent -- the priority list a weighed selector,
perception from `ai_perception`, the errands a technique. The owner's rule
behind it is now standing for every example: autonomy, as few fixed
if/else in a demo as can be.


## Milestone 1 — the vertical slice

A playable minimum where three techniques actually decide something.

| # | Task | State | Notes |
|---|---|---|---|
| T0 | Bootstrap: pinned Godot on the large disk | done | 4.7.2-stable, SHA-512 verified |
| T1 | Gates before the code | done | 14 gates, all in `make check` |
| T2 | `ai_core` and the board | done | reviewed three times; see the wave 07 record |
| T3 | `ai_search`: A\*, BFS, DFS, Dijkstra | done | 3 vectors and a 300-board property check |
| T4 | `ai_planning`: STRIPS, and a PDDL reader in Python | done | 8 steps, 14 states; 3 vectors read from both languages |
| T5 | Dataset and training (Python) | done | 87.8% against a 69.0% baseline, and 81.8% for a lookup table |
| T6 | `ai_learning`: inference, and the attack/retreat decision | done | 4 vectors read from both languages; invariant 6 finally has a gate |
| T7 | Close the slice: docs, ADRs, `make release` | done | 6 doc pages, 4 ADRs; a release the gate opens and checks |

## Milestone 2 — three games, three families of technique

Each game is chosen for the technique it makes obvious. The order is not
arbitrary: strategy finishes what T4 starts, stealth is the cheapest to build
and teaches the most per hour, and the fighting game is last of the three
because hitboxes and frame timing are a great deal of work that is not AI.

| # | Task | State | Notes |
|---|---|---|---|
| T8 | A board you can read | done | 48 px, centred, costs written, the highlight an overlay; manual check still a person's |
| T27 | Checkers, and minimax | done | `make run` is checkers against `ai_adversarial`; depth 4 by default (~50 ms); depth 6 stalls the frame up to ~730 ms with kings; the old board is `demo-skirmish`; manual check still a person's |
| T28 | Tic-tac-toe, and a machine that learns it | done | MENACE in Python, 304 boxes, four ages; `make demo-tictactoe`; N5/N6 in `check_no_training.py`; strength criterion changed to vs-perfect by the owner: Michie's rewards lock in a move that wins three in four, and the published machine still loses 10 in 1,000 to a random player |
| T29 | A search board you can edit | done | paint, erase, drag the dots, price mud; four named boards each with a checked promise; manual check still a person's |
| T30 | The tactical game, against the computer | done | `make demo-tactical`: spent units, undo, a confirmed end of turn; blue is a `BlueController`, rules today; blue walks at the workshop, not the nearest enemy (changed, pending the owner); 40-round draw; manual check still a person's |
| T9 | Art that is not a coloured square | done | 30 CC0 pictures from four Kenney packs, each listed with its sha256; `art.gd` the one path table; `make import` before any scene; manual check still a person's |
| T31 | Generate your own art, locally | done | `make artgen`: Z-Image-Turbo (owner's pick after a bake-off against FLUX.2 klein), fp8 + offload in 8.3 GB; gitignored output the game prefers, CC0 the default; 3 committed examples; ADR 0013 |
| T33 | Units that walk | done | Puny Characters (CC0) sheets for the shield and the soldier; units walk their route at 0.12 s a cell, march at rest, machines bob; `walk` kind in the generator on klein base + the svntax LoRA, sheets never committed; ADR 0014; manual check still a person's |
| T32 | Checkers with a learned evaluation | done | after Samuel (1959 paper, checked): Python rules and search held to Godot's by two vectors; logistic fit on self-play; learned loses 0.125 at two plies, 0.53 without its advancement weight; controls cannot be told from it (alpha-beta ignores scale); E toggles it in `make run`; manual check still a person's |
| T10 | The tactical scenario | done | five types, two towers, a workshop, funds, a forge, a river with one bridge; manual check: terrain yes, type feel waits on T26 |
| T11 | The planner plays | done | `PlannedBlue`, C in `make demo-tactical`: STRIPS over `spec/pddl/tactics-domain.pddl`, A\* with h_max over bits (383 worlds against breadth-first's 11102 on 60 boards); replans every 3 turns or when the plan stops running; plan listed and numbered on the board; against the rules 7-13 as blue, 0-20 as red; manual check still a person's |
| T12 | Three difficulties, honestly | done | `LeveledBlue`: the rules' walk, staying, or an attack cell, weighed at 1 or 2 plies with exact odds (`FightOdds`, never the board's dice) and Wesnoth's aggression; easy 1 ply noise 0.5, normal 1 ply, hard 2 plies; normal beat easy 70-29, hard normal 59-40, each level the rules 25 of 25 per seat; plan horizon 0 at every level -- a plan measured weaker (23-77); three, not five; S swaps sides; manual check still a person's |
| T13 | `ai_fuzzy`, from a library that already exists | done | rewritten, not ported: the library was C# and its core was missing (ADR 0011); 3 vectors read from both languages |
| T14 | The stealth scenario | done | `ai_perception`, fuzzy suspicion, three guard states; 4 properties over 300 maps |
| T15 | `ai_behaviour`: the four ways to decide | done | state machine, tree, GOAP (backwards, cheapest), HTN (forwards), and `WaysToDecide`, the table with STRIPS; one guard four ways in `make demo-behaviour`, 1-4 swap mid-round, a panel draws the state, the path, the plan; machine and HTN commit -- look, chase, catch -- tree and GOAP reconsider and never chase, GOAP doing the tree's deed every turn; HTN faster per plan (6-8 against 6-16 us); manual check still a person's |
| T16 | The fighting scenario | done | mostly not AI, and says so: frame data in `spec/frames/`, one axis, whole numbers, the resolution order written and tested rule by rule; a recorded log replays to committed per-frame digests; `make demo-fighting` is a training mode; manual check still a person's |
| T34 | High, low and the throw | done | four attack buttons, light quick and heavy slow; mid, low and overhead against standing and crouching guard; a throw that beats guard and loses to a strike; manual check still a person's |
| T35 | Fighters you can see | done | Puffolotti's CC0 karate template, two costumes; 30 strips of whole cells committed, the sheets only referenced (ADR 0015); a move's cels by phase, so the picture follows the frame data; manual check still a person's |
| T36 | How fighting-game AI is made | done | `docs/concepts/fighting-game-ai.md`: 26 sources, each opened, six as abstracts only and said so; most games script their opponents, the ones that copy a player record situations and answers, the arena hands every AI the fight 15 frames late; T37, T17 and T18 rewritten from it |
| T37 | A fixed opponent, at three honest levels | done | five situations, weighted options; reaction 30/22/15, tactics, execution; `FightDelay` hands it a copy of the past and refuses under 15; each level beats the one below 93-99 in 100 mirror fights; not a `DecisionPolicy` (board-typed); manual check still a person's |
| T38 | The jump | done | take-off, an arc in whole frames, landing; boxes are two intervals and the pass-over rule is geometry; four air moves, all overheads, one a jump; an uppercut anti-air; jumps cross over, guarded back from the strike; manual check still a person's |
| T39 | High punches pass over a crouch | done | the owner's finding from playing T34: standing punches and the dancer's roundhouse are high and miss a crouching fighter; the light kicks recut as side kicks to the waist; manual check still a person's |
| T17 | The opponent model | done | `ai_opponent`: an n-gram with additive smoothing and decay, held to Python by 4 vectors; the learner is T37's opponent leaning towards answers; 20/20 within 40 actions and after a switch; ADR 0016, the owner's exception to invariant 6, held by N9; manual check still a person's |
| T18 | Behaviour cloning, and what a learned model buys | done | the owner's nine fights, cut 15 frames late; every recording held out once: nothing fitted beats "always step in" (28.0%), the n-gram does by four points; ghosts beat medium 78-86 in 100, the clone 64; 0.04-0.12 ms a decision; a person could not tell them apart (ADR 0017, N10-N12) |
| T40 | An evade, and levels that are hard enough | wip | merged in wave 43: a backdash on its own button (O), 20-24 frames, invulnerable for the first quarter, after Strive; old logs replay unchanged; every level evades; hard holds 150/200 against a frozen copy of the owner's ghost (T37's hard: 109-133) and 130/200 against the turtle; not done: an answer that punishes over-evading (none reaches at a 15-frame reaction), step 5 and the manual check, which wait for the owner's new fights; wave 86: the owner, 2026-10-25, back tapped twice evades too -- `FightDoubleTap` turns it into the evade bit before the frame is logged, so logs replay unchanged; a key held through a cross-over is not a first tap (the review) |
| T41 | What the owner found playing the boards | done | the mud route was breadth-first's, read as Dijkstra's: the status now says what each search minimises; markers measured against their terrain; blue builds a wader when red shuts the bridge; holding a skirmish node 3 turns wins, and the policy contests a held one |
| T42 | Examples that are fun to play | done | `docs/design/fun-review.md`; the owner: the board games already feel like games, the skirmish and the tactical board do not; picked T26 first, the skirmish folded into the tactical board (T44), and a fighting ladder (T43) |
| T25 | One team per technique: a league, scored twice | wip | wave 58, the strength half: T15's four as tactical teams on shared facts and deeds (GOAP priced in turns); `make league`, 8 teams, 280 games twice, Bradley-Terry with bootstrap intervals; learned +311, lookahead +263, the planner -177, none of the four T15 teams told apart from the rules (HTN +92, -4 to +199); every mean decision under 1.3 ms; `make record-tactical` keeps games in `data/tactical/`; not done: human-likeness (steps 4-6), the clone, the on-screen meter -- they wait for the owner's 20 recordings |
| T26 | Combat on the board | done | one rules file for Python and Godot, fights held by 5 hand-checked vectors; 7 hand-checked vectors; red and blue attack, towers fire at their turn start (one exchange), an attack cannot be undone; a workshop is besieged (20 health, a blow an attack) and destroying it wins; the counter tilts an even fight to ~94/28%; retrained: 85.9% against 56.8% and 78.8%; manual check still the owner's |
| T44 | The learned policy plays the tactical board | wip | wave 47: two control points paying 2 a turn, every turn opened by `TurnStart`; `LearnedBlue` (attack or retreat by the combat model, the point by the capture model); the combat model sees the counter, fitted on a typed dataset, 86.0% against 57.7%; measured: rules mirror red 20/20, learned against rules 17-18 draws in 20 -- stopped there for a study of similar games (`docs/design/tactical-references.md`), which became T45-T48; not done: the capture rows from the tactical map, the controller key, the skirmish's removal |
| T45 | The AI spends its money and keeps its pieces moving | wip | wave 49: spend first (build what beats most even when it cannot get there; a boxed workshop says so and is asked again), never idle (a fallback at the nearest red piece), one walker per point and per fallback target; win-rate limits for stuck walkers and funds left; acceptance fails -- learned stuck 44%/42%, 99 funds left: half the stuck walkers could move (staging waits for T48's threat map), the rest are boxed in behind one bridge, and income beats one build a turn; rules mirror 12-7-1 (was 20-0), planner 13-3 as blue, 0-20 as red |
| T46 | The learned blue commits to a fight | wip | wave 50: sets out at p(win) 0.5, gives the same fight up at 0.3 or below (no measurable effect: the way to a fight is one walk), joins another's fight within 3 cells, retreats only when red's strength near it outweighs blue's by Wesnoth's caution -- that one rule is the gain: learned as red 11-0-9 (was 4-0-16), as blue 0-5-15 (was 0-1-19); flips counted by distance 26%, as the rules; C cycles rules, planner, learned |
| T47 | The side moving second, and a last round that decides | done | blue starts with one more shield; at round 40 the higher score wins (workshop health, point-turns, what is left) and only equal scores draw; rules mirror 51-49-0 over 100 on wave 52's board; manual check still the owner's |
| T48 | The board itself: a second crossing, a threat map, shorter fights | wip | wave 52: two fords at rows 1 and 7 (cost 3; at the ends the first mover won every game, mid-board the second), the planner's crossing_open, a threat map by path drawn on the board (T) that nothing decides by yet; learned stuck about 29% -> 17-20%, 35 of 40 rules games decided before round 40; one blow and one back not started |
| T43 | A fighting ladder | blocked | set aside by the owner on 2026-10-19: the fighting game has had enough; next are T24 and the RTS (T19, T20). easy, medium, the clone, "ghost: nearest", hard, best of three each, with a clock and an ending; every opponent exists; picked in T42 |
| T21 | Every example can be watched | done | `check_demos.py` and `demo_overlays.gd`; blue's decision now drawn before it is played |
| T24 | One window for every example | done | wave 59: `make menu` is the main scene, eight cards from `godot/menu/catalogue.json`, Esc frees the example and comes back; `check_demos.py` C1-C8 hold every card to its target, its page and the classes its scene runs; `menu_walk.gd` plays and leaves every card; `make export` (templates pinned in bootstrap, the pack's directory read, the binary started headless) and the executable zipped by `make release` from a clean HEAD only; manual check still the owner's |

## Milestone 3 — real time, last

Deliberately last. It needs the content of T10, the difficulty knobs of T12, a
second state core, and everything the three earlier games taught about making
an AI legible. Built first it would have been a large pile of code with no
lesson in it.

| # | Task | State | Notes |
|---|---|---|---|
| T19 | The real-time core | done | `BoardState` at 200 units: ~50 ms a step, three frames, so `ai_rts_core` exists (ADR 0019); its simulation 0.7 ms, flow fields 0.34 ms (p95 1.29 of a 1.5 share); a scripted match at ~65x real time, replayed to its digest |
| T20 | The RTS demo | done | wave 62: the minimum game on T19's core (two resources, supply, a lab, a tower that sees, T10's counter circle, half-turn map); the commander plans the build order over a level 1 PDDL domain by STRIPS or HTN, timed by Churchill and Buro's jump, over a priority-queue economy; squads by a state machine, utility over an influence map with fog and memory, and FocusFire on whom to strike; commander 19 - 1 against the queues alone, normal 17 - 3 against easy, hard cut; Bos Wars sheets by sha256 (ADR 0020); split on 2026-10-20, the human side moved to T55; manual check still the owner's |
| T55 | The RTS's human side: a clock's knobs, the league in real time | done | wave 127: `RtsHumanClock` wraps any side with a reaction delay (the enemy shown as it stood that long ago, own state current) and a cap on commands in a window; values from `godot/game/rts/clock_reference.json`, which `make measure-rts-clock` writes from the owner's recordings in `data/rts/` (`make record-rts`); the game never measures; until there are any, AlphaStar's 350 ms and 22 in 5 s, labelled a stand-in; `make test-rts-clock-limits` (the gate) holds a late and a capped side, one match each, to being handed nothing; `make test-rts-league` (~10 min, not in `check`) plays seven teams against the queues from both seats, prints strength (Bradley-Terry) and human-likeness (reaction, commands a minute, busiest 5 s) with bootstrap intervals, and holds every knob to costing strength and handing nothing over (the enemy handed on equal to the world's view the delay before, own targets included; no command the side did not give; no burst over the cap); `make rts-league` is the round robin; the reference cap never binds here, so the gate holds a tight one; M draws the meter in the demo, K the clock; review (`docs/reviews/127-the-rts-human-side.md`, changes requested, one blocker, all applied); manual check the owner's |
| T56 | The armed tower: an upgrade the commander must choose to pay for | done | wave 89: `RtsKinds.ARM`, bought at a complete tower like training, strikes the nearest enemy the side sees within 6 cells with line of fire; `arm_tower`/`tower_armed` in the build-order domain (PDDL and both JSON equal), used by `BuildSchedule` to time the gun, asked by no goal; `TowerWorth` weighs the enemy worth the gun would kill in its reach before help comes against its price, and the commander wishes the tower or arm at 85, above the plan; STRIPS stays on h_max, gated on worlds visited at normal's horizon (69); the queues' rule under the fighters; `rts-measure` ablates arming -- whole matches never reach the moment, and in a staged raid arming won no more than fighters (record in `docs/concepts/rts-ai.md`); manual check the owner's |
| T57 | The RTS seat bias: a gate on the mirror match | done | wave 116: claim 6 of `test-rts-match` -- the queues against themselves over six seeds, each twice with the dice swapped between the seats, fail when an exact two-sided binomial test puts the split at p < 0.05 (trips at 10 - 2 of 12), or when fewer than six were decided (planted 10 - 2, 2 - 10 and twelve draws refused); `rts-measure` plays the same mirror over ten seeds through the same `mirror_record` and `seat_bias`; each named suspect tested alone over 80 matches -- none moved the record beyond chance (35 - 45 to 45 - 34, 43 - 37 untouched); three ties made mirror images anyway, each held by a test the old order fails: `RtsScenario.as_seen_by` for the economy's building ring and the squads' open cell, `FlowField._wins_tie` (north or south first, then the goal's side; straight-at-the-goal was measured and refused, 78 of 80 matches ran out the clock); ids, the strike within a tick and the deciding order left alone; found and left open: the even record hides a split -- base kills west 158 - 77, time-outs on worth east 201 - 122, still 30 - 9 and 25 - 55 with the fixes (`docs/concepts/rts-ai.md`; the bridge region's off-mirror cell is the review's lead); review (`docs/reviews/116-the-rts-seat-bias.md`, changes requested, no blockers, all applied) |

## Milestone 4 — driving, which is the first thing not on a grid

A fourth game, after the three strategy ones and after the RTS, because that is
the order the owner wants to build them in. It earns its place by teaching a
family nothing before it does: every decision in this kit so far picks a cell
or an action, and a car picks *how hard to turn, right now*.

It is also the genre where difficulty most often cheats, which makes it the
best place to show the T12 rule holding under pressure: the hard car is hard
because it is driven better, and a command proves every car runs one physics.

| # | Task | State | Notes |
|---|---|---|---|
| T22 | `ai_steering`: not on a grid | done | seek, arrive, pursue, avoid, in GDScript and Python; 6 trajectories held to 1e-3 (9.4e-6 measured; Vector2 is 32-bit); over 100 starts arrive rests every time and seek never; `make demo-steering` draws each force |
| T23 | The racing demo, three honest difficulties | done | `make demo-racing`: pure pursuit on seek, a speed limit carried back from the corners; laps 39.6 / 36.6 / 35.1 s; `racing_does_not_cheat.gd` steps an honest twin race alongside and every car, decision and lap record must match it; seventeen planted cheats refused |
| T59 | Race the AI: a car you drive | done | wave 65: you against one AI level in the same car; a 24 m track, collisions that push, AIs that follow and pass; brake lights, tyre marks, a speedometer, your own braking bar; Kenney Racing Pack (CC0); laps 32.5 / 31.3 / 29.9 s alone; in traffic 5 seeds of 6 in order; owner raced it: "melhorou bastante" |
| T53 | How racing AI is made | done | `docs/concepts/racing-ai.md`: 30 references, each opened, those read in part said so; rubber-banding for and against; T23 and T54 rewritten from it |
| T54 | Racing in 3D, with physics the driver does not own | done | wave 73: a `RigidBody3D` on four ray-cast wheels (springs, tyres that slide past a peak, weight transfer nobody wrote); a driver that sees only its own view, finds its line by an elastic band, and measures its car on a test pad (grip 9.44 against the sheet's 10.29); PID and Melder's heat line in `ai_steering`; ladder 50.6 / 48.4 / 47.2 s on the loop and 43.9 / 41.9 / 40.4 on the untuned kidney; the no-cheat race matches an honest twin bit for bit, ten planted cheats refused; the heat line's claim (fewer changes of side) did not hold, printed not gated; `make demo-racing3d`; wave 75: the camera starts on your car and the panel says the keys wait for the grid (the owner could not drive, 2026-10-22), held by `make test-racing3d-you-drive`; manual check still the owner's |

## Milestone 5 — shooters, in 3D

The owner's request of 2026-10-15, asked again 2026-10-18: shooters, first
and third person, with bots that act alone and cooperate, and a stealth
version of them. 3D enters through ADR 0018, proposed in wave 53 and
**accepted by the owner on 2026-10-21** (option A): a `godot/game3d/` folder, a tier of its own, every
decision on a snapshot with a Python twin, and assets referenced by URL and
sha256 and never committed.

| # | Task | State | Notes |
|---|---|---|---|
| T49 | How shooter AI is made | done | `docs/concepts/shooter-ai.md`: 48 references, each opened, a third only in part and said so; one bot, bots that cooperate, the stealth version; T51 and T52 written from it |
| T50 | The 3D tier, measured before anything is built | done | wave 69, ADR 0018 accepted (option A): physics, rays and a navmesh from collision shapes run headless; a run replays bit-identically on one binary; a navmesh set on a region's second frame never reaches the map (set it before the tree); about 1,000 fps for the 16-bot arena on a Radeon 610M; a body moved through its node is in the physics space a frame late; Kenney Mini Characters by URL and sha256, `make assets-3d`, primitives when missing; `check_no_assets.py`, R6 in `check_renderer.py`; Jolt explicit; `docs/godot/3d-headless.md`; manual check still the owner's |
| T51 | A bot match: two teams of bots, cover, and a commander | done | wave 70: `ai_teamwork` (tactical positions with claims, team influence, a commander, squad confidence and waves), Python twins, 17 vectors; a 6-a-side match as a physics-free simulation held to Godot's rays, mirrored; first-person takeover of any bot (owner's choice), tracers, hit markers, a rifle; measured on a fair mirror (9-11; A*'s tie order had bent it 18-2): claims cut bunching 0 s against 79, the commander spreads orders over 2.34 points against 1.81, retreat always leaves someone covering, no shot at an unseen enemy; in the score, retreat costs the match (20-0 without it), the commander suggests help (1.8 errors), claims nothing -- said as measured, as the owner chose (`docs/godot/botmatch.md`), T65 split off; manual check still the owner's |
| T69 | What a guard perceives, how aware it is, and what it knows | done | wave 79: in `ai_perception` a vision shape read as certainty with body points, light at the feet, hearing along a path (`PathHearing`, from `ai_search`'s new `CostFlood`), typed events, `Awareness` (rises only while perceived, falls a phase at a time, a caution floor after an alert), `TargetMemory` and `BeliefMap`; the `infiltration` module reads two guard types from JSON and wires the fuzzy rate (fastest 0.69 of the peak a second, alert in about 1.5 s; slowest 0.10) and the flood; Python twins, 10 perception and 4 flood vectors, the rate as a fuzzy vector; `make test-infiltration-properties` holds seven claims on 150 generated levels, each planted case caught; nothing on screen yet, which is T70 |
| T70 | The infiltration level: guards that search together and call for help | done | wave 80: third person, two hand-made levels and generated ones; each guard T67's agent weighing 13 actions from `guard_actions.json`, its own belief cleared only where a hidden body would be perceived (T69 finding 10), a search shared only among guards who heard the same thing; `SearchCoordinator` and `RoleArbiter` in `ai_teamwork` with twins and vectors; help heard along the level, a call cut short never sent; a phase may set its own decay; `make demo-infiltration`, `make test-infiltration`: every claim holds and every planted case is caught; a hidden player found in 6.9 s with the belief, 20.8 s without (21.0 before its review's fixes), 18.4 s with one that never spreads; the quiet route held on the hand-made levels, printed on generated ones (caught on generated 1), and it does not show the light term; manual check the owner's |
| T65 | A coordinated team that wins | done | wave 97, closed as measured by the owner's choice (step 4): proposals 1+2 then 3 -- falling back weighed to cover near the squad's point, its dying table measured by the gate, respawn waves -- were built and measured; never falling back still won 20-0 (+200.5 +- 14.1 s against everything's +0.2 +- 23.8, 7.2 errors), every prediction that was measured was wrong, portability regressed and claim (b)'s plant passed; all three reverted, the gate's counts of today's falling back kept, printed; the record and two untried options in `docs/godot/botmatch.md` |
| T66 | The bot match on a map made for tactics, with a body to aim at | done | wave 71 (PR #9): height in the simulation (`ArenaWalk`), the three lanes and the yards, sprint, a seen and heard reload, 120 rounds and a base resupply, a power weapon and the five-kill reward, a humanoid body, head/torso/limb zones, solid bodies; `AimChoice` and `PassageChoice` with twins and vectors; reviewed (13 findings applied); both mirrors fair; manual check the owner's |
| T67 | The bot as an agent: it perceives, weighs and decides, on any map | done | wave 72: percepts through `ai_perception` into one record (shots heard), `ActionChoice` in `ai_teamwork` for the action, the posture and the pace, `ErrandChoice` for the errands, twins and vectors; reviewed (8 findings applied, among them perceiving and deciding in one loop, which bent the yards' mirror); both mirrors fair at 20 matches; random arenas played; manual check the owner's |
| T68 | Health that comes back, and a bot that weighs falling back to heal | done | wave 76: 10 s delay, 20 a second to 100 (sources: Halopedia, Upcomer, CharlieIntel, Game Developer); the base heals whole; ErrandChoice weighs hiding (TacticalPositions asked for cover from every known enemy) beside going home, the health priced by the bot's exposure (the review); effects after the review: weighing +10.0 +- 22.7 s, never healing +25.4 +- 23.7, below half -53.1 +- 20.8 -- the weak claim holds, the strong one does not, said so; manual check waits for the owner |
| T72 | The bot match's effects gate, in parallel | done | wave 78: `scripts/godot_shards.py` runs it in one Godot process a core and merges the counts in seed order; on the gate with T68 (187 matches), every pairing's exact sums equal the serial run's; 2748 s serial against 455 s sharded on 12 cores, both running at once; planted: a missing shard, a match too many, none or twice, a stat that is not a sum, a SCRIPT ERROR, a shard that wrote nothing or hung |
| T81 | Guards hear a player walking behind them | done | wave 82: the owner, 2026-10-22, playing T70, walking behind a guard it did not seem to hear -- a footstep counted only in the step it arrived; a sound now held for its emitter's cadence (`noise_every`), not the event's lifetime; the glance turns to what was heard; standing behind a guard, noticed in 0.5-0.9 s at 1 m and 0.9-1.8 s at 3 m (was 5.8 s or never, and never), crouched 0.9-1.5 s at 1 m, crouched at 3 m and prone never; a later sound replaces a held one, so a footstep never hides a throw; the eighth claim of `make test-infiltration`, its plant (one step heard, wave 80) caught; calls cut short 8 -> 12, the search and quiet route unchanged; manual check the owner's |
| T82 | An Xbox controller plays the real-time demos | done | wave 84: the owner, 2026-10-25; `PadAsKeys` turns a pad into the keys each example already reads, from a `PAD_BUTTONS` table it declares; the menu (D-pad, A, LB/RB, View back) and six demos -- both racers, infiltration, the bot match, the fighting game, stealth; Godot 4.7's `ui_*` actions name no pad button, measured; a key held by two inputs goes up with the last (the review's finding: the racers lost their throttle while steering); `make test-pad`, seventeen claims, two planted pads refused; the owner played the fighting game with the stick; wave 85: the D-pad walks it too, with the stick or alone, nineteen claims; manual check the owner's, with a pad |

## The kit as modules

The owner's request of 2026-10-20, after wave 62: every AI a module that can
be configured into any game, a wave that tests and gates only what it
touches, and later a library others can install.

| # | Task | State | Notes |
|---|---|---|---|
| T58 | Modules, and gates that run for what a wave touches | done | wave 63: 23 manifests in `modules/`, held to the code by `lint-modules` (M0-M10); tests filed in `godot/test/<module>/`; `make check-affected` runs the lints and the modules a change reaches (code uses followed on, test-only uses not): 25-64 s for a change that evolves one module, against 550 s; a wave lands by pull request, as desk-panel's do; CI ran for the first time and found four defects in bootstrap and the runner rules; mk fragments dropped (measured, no gain); ports, kernel, registry and the library are later tasks; manual check the owner's |
| T60 | `ai_learning` without the board | done | wave 67: the adapter (`BoardFeatures`, `LearnedPolicy`, `LearnedDecision`) and the weights to `game/tactical`, the clone's weights to `game/fighting`; no default paths in the technique; `gameaikit.training` generic and in `ai_learning`, the tactical fit is `gameaikit.tactical`; checkers depends on `ai_learning`, not tactical; the skirmish found inside `game_shared` and made its own module; retrained, same numbers |
| T61 | A small shared kernel: the board leaves `ai_core` | done | wave 67: `ai_core` is `GridGraph` and `Pathfinder`; the board's eight classes are module `board` in `game/board/` (ADR 0021); addon comments name no board class; `unit_view.gd` owned by tactical, so `game_shared` depends on `ai_core` alone; a board change selects 10 modules, 19 before |
| T62 | Search over a port, not over a grid | done | wave 68: `SearchGraph` (contains, neighbours, cost_at, estimate) in `ai_search`, `GridSearchGraph` the grid's adapter with Manhattan moved there; the estimate promises consistency, not only admissibility; `Search` stops being a `Pathfinder` and `GridPathfinder` holds one as such; `Pathfinder` stays in `ai_core` (it keeps `tactical` free of `ai_search`); vectors replay unchanged; a waypoint test where hops and cost disagree, a hop-counting Dijkstra planted and caught; the adapter costs ~5% on 200 A\* searches |
| T63 | The controller registry | done | wave 68: `TacticalRoster`, ten rows in C's old order, read by `next_controller`, the league and the sentence on screen (the list lived three times); the four T15 teams and `TeamFacts` moved to `game/tactical/` with their tests; `tactical` drops `league`; the tactical card lists its controllers and `check_demos.py` C9 holds them to the table both ways; RTS, racing, fighting and the behaviour demo measured: each already one table, no chain |
| T64 | The library | done | wave 112: ADR 0024 -- the prefix `Gak` on the nine names a user's code types (`GakGridGraph`, `GakPathfinder`, `GakSearchGraph`, `GakSearch`, `GakAdversarialGame`, `GakGameDomain`, `GakLlmRuntime`, `GakSteeringBehaviour`, `GakRtsController`), the algorithms keep their names, one commit per addon; `AimChoice` moved to `ai_utility` with its seven vectors, its derive rules and its Python half (owner, 2026-10-30); `release.py` reads `modules/*.json` -- an addon no technique or kernel manifest owns, a gdUnit4 suite inside an addon, a manifest with no `summary` are refused, each zip gains a README from that summary; `python/pyproject.toml` (PEP 621, flat, no dependencies, setuptools pinned for `pip install ./python`), the wheel still written by hand from its metadata and refused when it disagrees with VERSION or the manifests, and holding only the technique packages; `python/LICENSE`/`NOTICE` held by `check_license.py` L25-L26; `gameaikit.techniques`, a registry filled by a decorator on 16 entry points and joined by the entry-point group `gameaikit.techniques`; `make library-check` installs the wheel in a fresh venv and runs two addons in a blank Godot project, outside the repo, planted cases a zip missing `grid_graph.gd` and a wheel missing `aim.py` after a positive control; `Game` a Protocol, `MctsResult` and `aim.Choice` frozen; ADR 0009 revisited (publishing is the owner's act); the Asset Library page re-read in `docs/godot/addon-anatomy.md`; review (`docs/reviews/112-the-library.md`, changes requested, no blockers, all applied) |
| T71 | A new gate selects its module, not everything | done | wave 77: `affected.py` rule 5, the diff read by `added_gates.py`: only new `test-` targets of one module, their names in `check:` and in that module's `gates`, select the module; any other change to the Makefile or a manifest stays global; wave 75's diff went from everything to `menu, racing3d` (137 s against `make check`); 21 planted cases, 16 mutations caught, each by its own case (after the review) |
| T83 | Each checkout its own Godot `user://`, and a worktree its ignored files | done | wave 93: the owner, 2026-10-26, after wave 78's `effect_shards_test.gd` failed during wave 80's check -- every worktree shared `$toolchain/xdg`; `scripts/godot` points it at the checkout's own `.user-data/` (ADR 0022) and prints it with `--gak-print-redirect`; the cause measured: gdUnit4 deletes `user://tmp` after every suite, so any suite in one checkout wiped another's temp files (shown with a marker, both ways); two checkouts ran 63 cases at once, clean; `check_disk_layout.py` D6-D8 over every checkout git lists, each deleted alone caught by name; `make worktree-setup` copies gdUnit4 and the term list from the main checkout; E0 stays a note (proposed, not changed); the old `$toolchain/xdg` deleted by hand once no branch predates this; Windows untested, manual check (`docs/godot/user-data.md`) |

## Teaching, in two languages, and what the field has that the kit does not

The owner's request of 2026-10-22: bilingual teaching docs (pt-BR and
English) -- each technique briefly, how to use it in another repository,
a catalogue of every demo and its techniques, how to use the library --
the demos localised with a switch to pt-BR, and, in parallel, a survey of
AIMA and the game-AI literature against the kit, for a roadmap of new
techniques and of second games that test the library's generality.

| # | Task | State | Notes |
|---|---|---|---|
| T73 | The game-AI literature against this kit, and a roadmap | done | wave 81: `docs/concepts/the-literature-and-the-kit.md` -- 48 techniques in nine tables against the kit (module, demo, tier), from AIMA 4th ed.'s contents, Y&T 2nd ed.'s contents, Millington's chapter titles, the Game AI Pro index and 15 chapters and papers opened in part; Buckland and AI Game Programming Wisdom could not be opened and are listed so; three addons shown in one game only (`ai_opponent`, `ai_adversarial`, `ai_rts_core`; `ai_teamwork` and `ai_fuzzy` gained a second with T69 and T70); a roadmap of eight new techniques and six second games, each naming invariants 6 and 7; seven questions for the owner in pt-BR and en; `make lint-literature` holds every module, path and demo the table names, nine planted cases; the follow-up tasks wait for the owner's answers |
| T74 | Technique pages in two languages: the shape, the gate, the first three | done | wave 87: `docs/techniques/` -- `ai_search`, `ai_steering`, `ai_behaviour` and `ai_core`, each `.md` beside `.pt-BR.md`, a pt-BR glossary, `non_module_techniques.json` (MENACE, the learned evaluation, cloning, the racing driver); `make lint-translations-docs` (`check_translations_docs.py`, D1-D13): every technique paged or declared still to write, the translation pinned by the English body's sha256, (level, anchor) and code blocks equal, the shape's six sections, an example block equal to its file; 23 self-test cases; each page's minimal example runs in its addon's test folder; freshness knows `techniques: practice`; the decisions await the owner's review |
| T75 | Technique pages in two languages: every other technique | done | wave 90: `docs/techniques/` -- `ai_adversarial`, `ai_fuzzy`, `ai_learning`, `ai_opponent`, `ai_perception`, `ai_planning`, `ai_rts_core`, `ai_teamwork`, and the four non-module pages (`menace`, `learned_evaluation`, `behaviour_cloning`, `racing_driver`), each `.md` beside `.pt-BR.md`; `STILL_TO_WRITE` empty, so the gate now requires both languages for every technique; twelve minimal examples, each a file run by a gdUnit case -- the eight in `godot/test/ai_*/` (`ai_adversarial` gained the folder in its manifest), the four non-module ones in the test folder of the module that owns their Godot half (tictactoe, checkers, fighting, demo_racing); the glossary gained 28 terms and says code and doc comments stay English (the owner, 2026-10-26), and D14 holds that every translation opens with the line linking the glossary; the README's table links each row's page in both languages. **Follow-ups found (step 3), no task yet:** `RtsWorld`, `RtsRules`, `RtsOrders` and `RtsKinds` carry the kit's own RTS and cannot be wired elsewhere in a few lines (`FlowField`, `SpatialHash`, `FrameBudget` can); `RacingDriver` reads the demo's fixed `RacingTrack` and drives `RacingCar`, so its page's example is the two ideas alone; `ai_fuzzy`, `ai_perception` and `ai_teamwork` have no row in the README's table (T76 generates it) |
| T76 | A catalogue of the games and the techniques in each | done | wave 92: `scripts/catalogue.py` writes `docs/techniques/catalogue.md` and `catalogue.pt-BR.md` -- a matrix of the fourteen demos by fifteen techniques, a line per demo (command, the known game from `docs/techniques/games.json`, the keys that show the decision) and a line per technique (the demos it appears in), each technique with its algorithms by name, filed from the menu cards' evidence classes (tic-tac-toe's perfect play and the 3D racer's measured grip show as written inside the example) -- and a short summary of both between `catalogue:summary` markers in `README.md` and the new `README.pt-BR.md`; `make catalogue` writes, `make lint-catalogue` (`--check`, C0-C8, 32 planted checks; 31 mutations of its branches and of the reach rule it borrows from `check_demos.py`, each caught) fails on drift. A mark is measured: the candidates are a demo's `depends_on` (directly or through another example), classified by what its scene's code reaches -- own code, through another example (`demo-behaviour` reaches `ai_fuzzy` through `stealth`), or declared and never reached (checkers' `ai_learning`, used only by its Python, shown hollow and left out of the README); a non-module technique's declared demo must reach its Godot code. `check_translations_docs.py` gained the generated pair (no `translation_of`) and D15-D16, README.pt-BR.md's declared mirror of three README.md parts (12 more planted cases, 9 mutations caught); `README.pt-BR.md` is prose for the selector; the README's hand table and `docs/godot/examples.md`'s partial list became the summary and a link; manual check the owner's |
| T77 | How to use the library, in two languages | done | wave 118: `docs/techniques/using-the-library.md` and its pt-BR -- what the library is (the kernel, the techniques, the nine `Gak` names, what is left out), the archives, unzip, the import that registers `class_name`, a first decision (the `ai_search` example), the wheel, training in Python for Godot to read (invariant 6), versions and the licence; eight steps marked `<!-- library-step: … -->`, and `make library-check` takes exactly those, in order, in a folder laid out as the page assumes -- every printed command run as printed (`release.py --build`, the unzips, the imports, the venv and pip, the training run), the Python block and both examples saved where the page says, `stranger.gd -- route|infer` bounded by a timeout; a page step it does not take, or one it takes the page does not say, is refused; self-test plants a missing class, a missing installed module, a zip without `NOTICE`, a runner printing no marker, a misprinted unzip; the second example is `scripts/library/chance_from_python.gd`; the guide page is accounted for in `check_translations_docs.py` (`GUIDE_PAGES`, two self-test cases); every technique page's `{#copy}` section names the release zip first and keeps the copy as the alternative; README links the page; the glossary gains *release*, *wheel*, *cache*, *tile*, *template*; review (`docs/reviews/118-how-to-use-the-library.md`, changes requested, one blocker -- the page's `make release` needs `make bootstrap` and the check ran something else -- all applied) |
| T78 | The demos speak Portuguese: the mechanism, the gate, the switch | done | wave 88: `godot/locale/<module>.csv` (checkers, demo_search, menu), header `en,pt_BR`, the English text the key, the imported `.translation` committed (the engine reads project.godot's list before importing, measured); `Language` -- saved choice, else `pt` means pt-BR; the menu's EN / PT-BR button (L, Y), and a demo opened alone applies it too; a Label keeps its key and shows `atr(text)`, the engine starts in the system's locale, a compressed table ignores context -- all measured, `docs/godot/localisation.md`; `make lint-translations-game` (L1-L7, L1 inverted after the review found it blind to words built in helpers) and `make test-locale-screen` (planted: auto-translate off, a formatted line, an empty scene); `test-demo-overlays` runs in en and pt-BR -- a pt-BR legend line ran off the window; the catalogue's card text is still English; manual check the owner's |
| T79 | The turn-based demos speak Portuguese | done | wave 91: tables for skirmish, tictactoe, tactical, stealth, demo_behaviour; English grammar glued in code (MENACE's plural by trimming an s, "the " before a square, articles before a piece) became a key per case; the stealth guard's reason is worded when read; the behaviour panel translates each name in the addon's notation, and the addon's English it translates is copied and held to the addon by a test; L8 (one key, one translation across tables -- "investigate" said two things); `test-locale-screen` opens all eight and now counts errors from before the scene loads (a parse error passed it); new pt-BR fit tests found the MENACE panel, the guard's status and five legend lines too long; the tactical header ran off the window in English already; English says "learned policy" where it said "learned"; manual check the owner's |
| T80 | The real-time and 3D demos speak Portuguese | done | wave 94: tables for demo_steering, demo_racing, racing3d, botmatch, infiltration, rts, fighting; the identifiers each demo draws (actions, states, kinds, phases, zones) are listed in `BotMatchWords`, `InfiltrationWords`, `RtsWords`, `FightWords` and translated where drawn, a test per demo holding the list to the data; English that is data is matched by shape where shown -- the RTS rules' refusals (`RtsRefusal`, held to `rts_rules.gd`), the fighting rules' events (in every digest; held by replaying every recorded fight, which found "trade"), the eye's reasons; `Language.decimal` gives a lap time or a margin the language's decimal comma, measurements keep the point; per-frame panels are one lookup and one format a sentence (a lookup 0.56 us); `test-locale-screen` opens the seven demos, reads `Label3D`, provokes an RTS refusal and fails a line past the window -- it found the bot match's errand line and four search-demo lines too long in pt-BR (fixed); `check_translations_game.py` counted a `\n` escape as a line and named every later finding a line too far (fixed, planted); the tactical header runs off the window in English too (`NOT_YET_FITTED`, no task yet); the pad legend line (`game_shared`) is still English; manual check the owner's |

## The roadmap after T73: the owner's answers of 2026-10-26

T73's seven questions, answered by the owner on 2026-10-26 (recorded in
`docs/concepts/the-literature-and-the-kit.md`, both languages): every
entry of part A ("todos"), MCTS, the director and the particle filter
first; MCTS in an XCOM-style **mode** of the tactical game ("será que pode
ser estilo X-com?") -- a second ruleset on its own state, map, pieces and
scene, not a new game -- with alpha-beta facing it as expectiminimax
(B.2); bandits and the difficulty model under ADR 0016, extended by name
on its three conditions (its amendment of 2026-10-26); B.6, utility choice
as its own addon; a small Pac-Man maze for the MDP; and `ai_llm` now, with
a text game where you talk to a character run by a local LLM. Proposed
order: T84-T89, T90, T91, T92-T94, T95-T96, T97-T98, T99, T100; T86, T92
and T97 can start at once; T101 at any point, best before T64. Every
decision in these files is written down for the owner to confirm in
review.

| # | Task | State | Notes |
|---|---|---|---|
| T84 | An XCOM-style mode of the tactical game: a second ruleset on the same state | done | wave 113: `TacticalRuleset` in `tactical` -- the start, the walk and the attack and why each is refused, what an attack is told as, the turn's opening, the winner, the rule and the announcement, the tint, the points, the roster -- and `AdvanceWarsRuleset` wrapping the existing classes unchanged, the scene's default; the scene, `BlueTurn`, `TacticalDecision.played_on` and the status's targets ask it, and only an Advance Wars game is recorded; the status's headline, funds and points and the legend stay Advance Wars's until T85; every tactical gate unchanged; `board` unchanged; module `squad` (depends on `tactical`, `board`, `ai_core`, `game_shared`): `SquadRuleset` (two actions as twice one action's movement, a dash spends the piece, a shot spends it), `SquadCombat` (aim - defence - cover clamped, one d100; a shot needs the shooter's own sight, and a refusal at an unseen enemy names nothing), `SquadCover` (rock 40, trees 20, beside the target, facing the shooter, else flanked; UFOpaedia EU2012), `SquadSight` (Bresenham, mutual, trees and rock block except beside either end), `SideView` (own pieces, seen enemies, last seen, no dice seed), `SquadVictory` (a squad gone, or health at 20 rounds), `SquadScenario` (four a side on the tactical map, mirrored), `SquadRoster` with one row, `RandomSquad` on its side's view; numbers in `spec/squad/rules.json`, only cover and the two actions borrowed; `gameaikit.squad.shot` the Python twin; twelve hand-checked vectors (`make test-squad-vectors`, gdUnit and Python); the property check over 300 seeded positions, each claim caught on a planted mutation, and a seeded game pinned to its digest; overwatch and hunker down left out; the menu's `modes` are T85's (its Files line); `docs/godot/squad.md`; review (`docs/reviews/113-xcom-style-mode-the-rules.md`, changes requested, one blocker -- a mortar shot at what it could not see -- all applied) |
| T85 | The XCOM-style mode in the tactical scene, against an enemy that weighs | done | wave 119: one card, one scene -- the tactical card's `modes` (Advance Wars, XCOM), each its ruleset script, controllers and roster, chosen on the menu with M or a button and handed to the scene (`play_in_modes`), M in the scene the other mode, `make demo-tactical MODE=squad` the menu straight into it; the seam answers more, Advance Wars unchanged: title, fog (`TacticalFog`: dark cells, last-seen ghosts, only the seen pieces drawn), dash cells in a second tint, the hit chance on each target and its sum in the status (`SquadStatus`), T's chance under the cursor, the legend (`SquadLegend`), a walk that reveals cannot be undone; `WeighedSquad` (perceives `SideView` with memory, weighs every walk and shot of the piece about to act with `ai_utility`'s `ActionChoice`, data in `weighing.json`), first row of `SquadRoster`; every option it weighed drawn with score and chance before it acts, V hides it; gates: does-not-cheat over 60 positions with a planted see-everything controller caught, seeded self-play pinned to its digest, `make test-squad-match` 100 of 100 a seat against `RandomSquad` (bar 80, planted random case rejected); `check_demos.py` C9 holds each mode to its roster, with planted cases, and a MODE recipe form; the mode stepped by `test-demo-overlays` and read in pt-BR by `test-locale-screen`; `squad.csv` both languages; defence values unchanged, owner's item 3 still open; `docs/godot/squad.md`; review (`docs/reviews/119-xcom-style-mode-you-can-play.md`, changes requested, two blockers -- a walk's refusal named a hidden piece, a blank status -- all applied: neutral refusal, `after_refusal` fallback, refusals held by the match gate, the does-not-cheat check over health, removal and memory) |
| T86 | Monte Carlo tree search in `ai_adversarial`, on a game it does not know | done | wave 101: `MonteCarloSearch` (UCT, AIMA 5.4's SELECT/EXPAND/SIMULATE/BACK-PROPAGATE, one child per outcome drawn) and `MctsResult` (each root move's visits, mean, bound; the most visited, of equals the first) in the addon, beside alpha-beta; `step(iterations)` is the frame budget, counted in work, the tree carried over; `AdversarialGame` drops "players alternate" -- minimax and alpha-beta pick max or min by `to_move` at every node, checkers' suites and vectors unchanged -- and gains a concrete `outcomes` (default `result`, certain); every draw from `Xorshift` (Marsaglia's 32-bit, seed 1 starts 270369), a draw spent only on a real choice; Python twin `gameaikit.adversarial` with Nim and a dice race (a four plays again), importing no example; `spec/vectors/adversarial/` (4 draw cases, 12 search cases) written by a third MCTS, `derive.py`, and held by `make test-adversarial-vectors` and `make test-python`; two planted twins fail both games in both languages -- one with a spare draw, one with the same draws read differently (a twin reordering only the move and the outcome cannot be written: whether an outcome is drawn depends on the move); measured over 40 seeds, 1000 iterations find Nim's winning take up to 11 sticks, 13 needs about 2000; 100 iterations of the dice race ~2.5 ms, held under half a frame by `make test-mcts-budget`, apart from the suites; `docs/concepts/minimax.md` gains MCTS; the page's example asks both searches; mutation round: 22 GDScript rules (minimax and alpha-beta by `to_move`, the default `outcomes`, the generator, each MCTS rule, the vector checker) and 18 Python ones disabled one at a time, each caught -- two Python survivors (a tie in the answer, an unchecked mean) gained tests first; the review (`docs/reviews/101-mcts-in-the-adversarial-addon.md`) found the reported bound, the per-chooser value on a game that is not zero-sum and the outcome boundary unpinned, now held by tests in both languages, 8 more mutants each caught; manual check still a person's; T87 draws it |
| T87 | MCTS plays the XCOM-style mode | done | wave 125: `SquadSearchGame`, the squad's `GakAdversarialGame` (one piece's question: hold, a walk by cell, a shot by target; a shot a hit and a miss at the shown chance; one-answer questions passed over; health over a full squad's), its Python twin, `spec/squad/positions.json` held equal in both languages by `make test-squad-search-vectors`; `MctsSquad`, a `SquadRoster` row, searching the board its side believes in (one determinization: last seen, as hurt as then; never seen, where the scenario starts it), 4 iterations a frame in the scene through `BlueController.keep_thinking`, root visits, means and bounds drawn growing, then `MonteCarloSearch.principal_line` (new, both languages); T85's does-not-cheat check shared as `SquadUnseenCheck`, two planted searchers caught 20 of 24 each; measured against `WeighedSquad`: 34/37 of 100 at 200 iterations, 56/63 of 100 at 1,000, 12/12 of 20 at 5,000 (`make measure-squad-mcts`); worst frame 22 ms on a quieter machine; manual check still a person's |
| T88 | Expectiminimax faces MCTS on the same positions | done | wave 136: `ExpectiminimaxSearch` in `ai_adversarial` (chance nodes summed by probability, no pruning; iterative deepening on an explicit stack, `step(positions)` anytime, the deepest finished depth's `AdversarialResult` with each move's outcomes), equal to minimax on Nim value for value and position for position, AIMA 5.5.1's rescaled-leaves example in both languages; Python twin (the book's recursion) and `expectiminimax-dice-race.json`, depths 2 and 3, written by `derive.py` in exact fractions, a planted no-dice search and a one-ply-short one failing both languages; `AdversarialGame` needed no change (B.2: an interface); `SearchingSquad` holds what MCTS and expectiminimax share (MCTS's digest unchanged); `ExpectiSquad` (roster `expecti`) on `SquadEvaluatedGame`, a hand-written evaluation (health 0.6, cover 0.2, flanked 0.2, `rules.json`), 20 positions a frame to 5,000, the depth finished and a shot's hit and miss in the status; `spec/squad/duel.json`, 30 positions from seeded matches (`squad_duel_draw.gd`), their depth-2 expected values equal in both languages; `make test-squad-duel` (in `check`, counted budgets, a short run fails) and `make measure-squad-duel` (the clock, not in `check`): agreement 16, 16, 15 of 30 at 50, 200, 1,000 ms; at depth 2 the enemy chooses in 5 of 30 positions and in no walk, so on walks it is expectimax -- the shots agree, the walks do not; at 50 ms, 100 matches a seat, expectiminimax against MCTS 62 won, 48 lost, 90 drawn, and both lose about 97 in 100 to the weighed enemy; at 200 ms, 20 a seat, MCTS beats it 33 to 7 and takes 17 of 40 from the weighed enemy, expectiminimax 1; T87's `MctsSquad` crashed on a board it believed finished (a SCRIPT ERROR in `_chosen`, met under the clock), now guarded and tested, cause in T134; reviewed (`docs/reviews/136-expectiminimax-faces-mcts.md`); manual check still a person's |
| T89 | Art for the XCOM mode, if the tactical pieces are not enough: open packs, referenced | todo | only if T85's manual check asks for it -- the mode already draws the Kenney pieces; the owner, 2026-10-26: "se precisar veja assets open ou free pra demo x-com"; a survey (URL, licence, fit); ADR 0020's rule, never committed; `check_no_assets.py` A2 learns `art_sources.json` |
| T90 | A director paces the infiltration level | done | wave 114: `Director` (godot/game3d/infiltration) and its Python twin `gameaikit.director.pacing` -- intensity raised by `seen` 0.25 / `heard` 0.2 a phase, `hurt` 0.01 a point, `search_near` 0.02/s inversely to distance, decaying 0.04/s and not while a guard is alert and sees you; build up -> sustain 4 s -> fade below 0.35 -> relax 30 s or 15 m nearer the exit (spec/director/director.json, invariant 6: fixed numbers); seven vectors from a third copy (`derive.py`), `make test-director-vectors` and `test_director*.py`; `DirectorEvents` reads the world, `DirectorOrders` sends a calm unseen reserve guard on its beat (build up, peak) or calls a calm one back (fade, relax), a route and nothing else; reserves in both hand-made levels and the generator (own seed, levels unchanged); key 6, off = T70's level; HUD strip (intensity, peak and fade lines, phase, marks) and map lines; `director_test.gd`: off is T70's, reserves unseen and walkable, a seen reserve not sent, no belief changes when it acts (planted cheat caught), no patrol sent in view, the whole cycle on generated 10; `make measure-director`, 39 runs: 33 peaks, 3 relaxes -- most runs end in capture, and stand-offs never fade, written down in docs/godot/infiltration.md; new scripted player `distract`; catalogue card and `games.json` name the director; review (`docs/reviews/114-a-director-paces-the-infiltration.md`, changes requested, no blockers, all applied): every route the director gives is the guard's beat or none (a director routing a guard to the player caught), a planted nearest-reserve picker caught by the run-level sight claim, the generator's levels fingerprinted against main for seeds 1-11, reserve cells distinct, a `heard` vector, the measurement on the concepts page; the decay-pause cap and what "engaging" means are the owner's |
| T91 | A particle filter tracks the unseen player | done | wave 107: `ParticleBelief` in `ai_perception` beside `BeliefMap`, over the same neighbour list -- walk on (0.7, "not back where it came from"), turn (0.2), else stay; weight 0 where a guard sees, 0.3 where it would have heard the player creep and heard nothing; systematic resampling every step, an even reseed over the unseen when every weight is 0 (`reseeded`); `shares` the same shape as `BeliefMap`'s; its own seeded xorshift `ParticleDraws` (a copy of T86's, invariant 2); Python twin `gameaikit.perception.particles`, four `particles-*` vectors written by a third copy in `derive.py`, held by `make test-perception-vectors` and the Python tests; invariant 6 said on the page (constants only, weights rebuilt each step, N3 agrees); infiltration: both beliefs stepped, key 1 cycles off / grid / particles, the search reads the one on through `InfiltrationWorld.believed` (a seam), the grid stays default so every T70 number is unchanged; overlay: dots sized by share, a white square on each cell sight just emptied, the purple cross the spot chosen; `make test-infiltration-tracking` (about 40 s, a measurement, not in `make check`; the wiring is held by `belief_switch_test.gd`): two particles a walk cell, the sensor the creep's 2 m; a reported player that creeps to a hiding place, 26 paired runs -- 4.7 against 4.8 s, 2 sooner, 1 later, 23 the same -- and T70's static staged search 7.1 against 6.9 s (0 sooner, 3 later, 12 the same): no difference worth the name, and little power to show one, written down in `docs/godot/infiltration.md` with a step's cost (1.5 ms a guard on the largest level); review (`docs/reviews/107-a-particle-filter-tracks-the-player.md`, changes requested, no blockers, all applied): 256 particles striped the start and the reseeds -- now two a cell; the claim "later when it has not moved" rested on one capped run -- withdrawn, every run printed paired; the scenario's low power said; `would_hear` and the spot/way-out wiring tested (four mutants caught); the menu card and the legend name the particles; particles stay non-default, and one generator into `ai_core` is the owner's (ADR 0021) |
| T92 | `ai_llm`: the addon, its validator, and invariant 7's gate | done | wave 102: the reply is one shape, `{speech, intent, argument}` (`spec/llm/reply.schema.json`), against the intents the game declares (Façade's discourse acts); `LlmValidator` and its Python twin `gameaikit.llm.validator` refuse by the first rule broken, R1-R11, and a refusal becomes the game's fallback (`unclear`, the game's line, the reason) -- never a retry; `spec/vectors/llm/` (57 cases after review) holds both to one code per reply, run by `make test-llm-vectors`; making them agree measured Godot 4.7.2's JSON parser taking a trailing comma, `01` and `1.`, and Python's taking a lone surrogate and `NaN`, each refused on the side that took it; `LlmRuntime` the port, `RecordedRuntime` answering a frame or more later and never inside `send`, `HttpRuntime` (OpenAI-compatible chat completions, `use_threads` on, a fixed timeout; a failure is `F1`, the fallback), `LlmConversation` (history of what the game accepted only, one request in flight, the thinking state, no secret in the instructions); `HTTPRequest` measured with threads on and off against a stub server (`make measure-llm-requests`, `docs/godot/llm-requests.md`): no frame stalled either way on this machine, threads stay on because the docs do not promise it; `check_llm_validated.py` V0-V3, static, vendored and dot folders skipped, 31 planted cases after review and a vendored copy of all of them; CLAUDE.md's row 7 names it, half held -- a net for the common spellings, its misses listed in its docstring; the technique page in both languages (its example a recorded gatekeeper), `docs/concepts/language-models.md` (tier 1, the replay), the literature row names `ai_llm`; mutation round: 15 GDScript, 12 Python and 17 gate rules disabled one at a time, plus 6 runtime and conversation ones, each caught; review (`docs/reviews/102-ai-llm-the-addon-and-its-validator.md`) found two blockers -- the runtime's `replied` and `text_of` went round the door, and CLAUDE.md called a net a gate -- and the rest: a conversation left thinking forever when its runtime left the tree, V0 passing on an empty addon, V1's exemption a whole folder, bypasses through `OS.execute`, UDP, a uid preload, an alias, `"raw_text"`, a spinning `is_thinking()` loop, an escaped quote, an 11 s gate, and three parser and lowercasing disagreements (`\u0000`, deep nesting, `İ`) now one answer each (NUL refused before parsing, depth capped at 32, secrets folded A to Z only); all applied, a second mutation round of 30 caught; T93's task file now asks it to measure `response_format` and keep a server's refusal apart from the model's; re-reviewed: ready to merge; its three follow-ups (subclassing the door, writing a reply's fields, depth 33) applied |
| T93 | A local LLM runtime on the large disk, pinned and measured | done | wave 111: llama.cpp's `llama-server` from its prebuilt archives, pinned at `b11960` (the build `v0.8.0` names; since then every build is a pre-release) by size and sha256 in `tools/llm/runtime.json` -- Vulkan default, CPU fallback, CUDA 13.4 one word away; MIT; `scripts/llm` points llama.cpp's cache and the drivers' (NVIDIA, CUDA, Mesa) at `$toolchain/llm/`, keeps the server offline, and its self-test plants a toolchain under `$HOME`, `LLAMA_CACHE` at home, the server online, and a file whose sha256 differs (refused and deleted); `make llm-bootstrap`, `llm-serve`, `llm-smoke` (starts the server, one line through `HttpRuntime` and `LlmConversation` in Godot, `godot/test/ai_llm/live_probe.gd`, stops it whatever happened; 2 when nothing is installed), `llm-bakeoff`; the port written once, `HttpRuntime.PORT` = 9931, read by the wrapper and `check_acceptance.py`, which now refuses `llm-smoke`, `llm-serve`, `scripts/llm` or `tools/llm/llm.py` commands and the port (on localhost, 127.0.0.1, 0.0.0.0, [::1]) without `Requires: a local model` (planted cases); `check_disk_layout.py` refuses `~/.cache/llama.cpp` and `%LOCALAPPDATA%/llama.cpp` (planted); measured at the pin (`docs/local-llm/server.md`): HttpRuntime's `response_format` (`json_schema.schema`) is honoured and the server README's own form silently ignored, a bad `response_format` is a 400, an unreadable schema a 500, loading a 503; so `LlmRuntime.refused` and `F2` -- any HTTP error but 503 is the request refused, with the server's reason, cleaned of line breaks, control characters and markup and cut to 160 -- held apart from F1 and the validator's codes by a test from the recorded answers (`spec/llm/server-answers.json`); nothing new under `$HOME`, by mtime; bake-off (`docs/local-llm/bakeoff.md`): Gemma 4 E4B, Granite 4.2 8B, Ministral 3 8B, all Apache-2.0 from their makers' repositories, 30 lines of the guard in English and pt-BR, three rounds, Vulkan and CUDA, raw turns committed -- all but 8 of 1,080 replies under a second, all 8 on Vulkan in a first round (each model's first long prompt 3-10 s, five more of Ministral's 1-2 s), CUDA none; no frame over 11.1 ms; Granite 4-10 of 30 valid in pt-BR on Vulkan; scored on accepted replies only, act and argument right on Vulkan: Ministral 15.3 in pt-BR and 11.0 in English, Gemma 13.3 and 12.3 -- Ministral recommended for pt-BR, Gemma edges English, the owner picks; most refusals R7, an argument the schema cannot tie to its act; ADR 0023 (proposed); review (`docs/reviews/111-a-local-llm-runtime.md`, changes requested, no blockers): the first table scored a refusal on an `unclear` line as right and claimed every reply under a second, both corrected from the raw files; F2's server text now cleaned; R4, R6 and R7 no longer quote the model's key, intent or argument (both languages, three vector cases, a property in both suites); `refused`/`failed` listed as not caught by V2, with why; the acceptance pattern's other spellings; `fetch` refuses a failed download by name; T94 told about the unbounded history against `--ctx-size 4096`, `anyOf` per intent to measure, and the labels to skim |
| T94 | Talk your way past the guard: a text game with a local LLM | done | wave 126: `make demo-talk` and a menu card naming Suck Up!; Bram at the research station's door; the model reads each line as one of `spec/talk/gate.json`'s acts and voices him, `TalkRules` / `gameaikit.talk` move trust (6 opens) and suspicion (5 alarms, wins a tie) by a first-match rule list against the guard's facts; three ways in (the right name, a work order, asking who is expected and becoming them) and the ways out held by tests in both languages; the ending line is the scene's, never the model's; recorded (dialogue menu branching where recordings share lines), live (Tab, `make llm-serve`) and record (`make record-talk-live`) modes; `RecordingRuntime` added to `ai_llm` so a game records without reading raw text; `LlmValidator.json_schema()` narrowed to an `anyOf` per intent in both languages, measured on the 30 bake-off lines: R7 gone, valid replies 15-18 to 25-28 (en), 22 to 29-30 (pt-BR); context bounded by 8 turns and 100-character lines, worst case 3,338 tokens of 4,096 measured at the pin; 16 recordings (8 conversations x 2 languages, Ministral 3 8B, Apache-2.0, README beside them), 6 refused replies; `spec/vectors/talk/` held by `make test-talk-vectors` (Python and the Godot game's own path); mutation round: 10 rules disabled one at a time, each caught; `docs/godot/talk.md` |
| T95 | Levels declared, not drawn: a constraint solver places the infiltration level | done | wave 120: `ai_constraints`, a new technique addon -- `ConstraintProblem` (variables, finite domains, binary constraints as Callables, global ones as tests of a partial assignment that say no only when no completion could save it) and `ConstraintSolver` (AIMA fig. 6.5 top to bottom: AC-3 once, then backtracking with MRV and the degree heuristic, LCV, maintaining arc consistency; `mrv`, `lcv`, `propagate` switchable; `record` keeps a trace; `limit` and `gave_up`), ties ordered by one seeded shuffle with `ConstraintDraws` (a copy of T86's xorshift, invariant 2); Python twin `gameaikit.constraints` (`@technique("constraints")`, `KIT_MODULES`, `pyproject.toml`), Australia, the Wikipedia Sudoku (AC-3 alone, 0 backtracks), eight queens in `test_constraints.py`; nine vectors from a third copy (`spec/vectors/constraints/derive.py`, a worked one in the README), `make test-constraints-vectors` and `test_constraints_vectors.py`, two planted solvers caught in both languages (ties to the last, LCV backwards); the level: `LevelConstraints` declares each box, lamp, hiding place, patrol point and the sentry's post a variable over 16 candidates drawn from the seed, `level_constraints.json` beside `guard_types.json`, binary rules as tables (`LevelConstraintRules`), the five global ones on `LevelSketch` (the arena's walk rule, held cell for cell to `BotArena`), restarts with fresh ties when the 400-assignment limit runs out; `LevelAudit` checks every solved level on the real arena (planted: a lamp over every way, a post in the open, a route far from hiding, a walled exit); `LevelGenerator.make` unchanged, `make_by`, `with_reserve`; K cycles drawn / solved / solved with the generation view (`GenerationView`: the chosen variable's 16 places, white or crossed out, every unplaced thing's count, undone values in red, the last refusal and its rule), the overlay's `generator`, pt-BR rows in `infiltration.csv`; `make measure-level-constraints`, 200 seeds: both 200 found; drawn levels 107 with no hiding place near a route, 71 with no dark way, 90 with a post in sight; solved 0, 7,090 assignments, 2,304 backtracks, 6 restarts, 136 ms a level -- on `docs/godot/infiltration.md`; technique page both languages (example `rooms_example.gd` run by its suite), `docs/concepts/constraint-satisfaction.md`, glossary, literature row and catalogue; departures and the owner's decisions in the task file |
| T96 | Wave function collapse builds maps for the tactical game's XCOM mode | done | wave 142: `WaveCollapse` in `ai_constraints` is `ConstraintSolver` with three choices changed -- the cell of least Shannon entropy, one tile drawn by weight, no backtracking (a contradiction ends the attempt and the next seed starts, counted) -- and AC-3 unchanged; `TileGrid` declares a map from a hand-written tile set (`left_right`, `up_down`, said from both sides or refused); Python twin; seven vectors in `spec/vectors/constraints/collapse/` from an independent `derive.py` (checkers, weights, pins that cannot stand, three colours with one and two restarts, the squad's tiles from seeds 1 and 2), run by `make test-constraints-vectors`; three planted collapses (most entropy, no propagation, blind to a contradiction) fail in both languages; `spec/squad/tiles.json` (plain, trees, rock, water, bridge, ford) and its game copy; `SquadMapBuild` pins the eight starts to open ground and refuses a map `SquadMapCheck` finds unplayable (starts connected on foot, cover within one action); twenty maps from seed 1: no contradiction, 3 refused, about 28 ms a map; N builds a map and plays on it, B replays the build a cell a press (counts of tiles left, the least-entropy cell in amber with its entropy, a red 0 at a contradiction), through three new `TacticalModeView` answers (`rows`, `pressed`, `building`); the technique page in both languages, the squad page; reviewed (`docs/reviews/142-wave-function-collapse-for-the-squad-maps.md`): the map belongs to the ruleset, the playability check and the scene seam are tested against plants, the menu card and the catalogue name N, B and the technique (the catalogue now walks from a mode's ruleset), a contradiction before any collapse stops the build, and the generator's fold is T135; manual check still a person's |
| T97 | A small Pac-Man maze, with ghosts that follow the arcade's rules | done | wave 104: `make demo-maze` and a menu card naming Pac-Man; 52 cells, no dead end, four pellets, Blinky and Pinky (G); the Dossier's rules as written in `spec/maze/rules.json` -- scatter/chase on level one's schedule (each second two steps), forced reversal on a mode change, no reversing otherwise, the shortest straight line from the cell beyond each way to the target tile, ties up-left-down-right, Blinky's target Pac-Man's cell, Pinky's four ahead with the up-means-left bug -- plus the kit's imprecise ghost (in chase, at a fork, the Dossier's way with probability 0.8, else any way evenly; `gameaikit.maze.rules.chances` for T98); departures named: one cell a step for all, the choice on the cell itself at the end of a step, no energizer or frightened mode, no house or tunnel, one catch ends it, a swap cannot happen (Pac-Man moves first); Python twin `gameaikit.maze` and the game read byte-for-byte copies of `spec/maze/`, draw from the same xorshift (copied as `MazeDice`, so the maze does not list `ai_adversarial`); `spec/vectors/maze/` (8 games, 239 snapshots, targets included) written by a third copy, `derive.py`, and held by `make test-maze-vectors` and the Python tests; properties over seeded games in both languages (no reversing outside a mode change, every change reverses, no wall, replays); V draws each ghost's target, every way's distance and the chosen way before it moves, orange with a die when the dice chose; pt-BR table `godot/locale/maze.csv`; `docs/godot/maze.md`; mutation round: 11 Python and 10 GDScript rules disabled one at a time, each caught; frightened mode, the generator's home and the schedule's scale left to the owner; review (`docs/reviews/104-a-small-pac-man-maze.md`, approve after two should-fixes): two tie vectors (up before left, down before right) and `nearest` asks the tie order itself; "exact" qualified -- the timed schedule makes T98's state as written not Markov, and T98 now solves the stationary regime, chase for ever (the owner's choice, 2026-10-29); Cruise Elroy and the red zones named, the generator's 2^-32 bias stated, the roll in three decimals, no pending decision on the panel after a catch, a stream-of-draws test in each language |
| T98 | Value iteration plays the maze: an MDP solved in Python, its policy shipped | done | wave 106: `gameaikit.mdp` -- a finite MDP as a table (`model`), AIMA 17.2.1's value iteration and 17.2.2's policy iteration (`solve`), both held to two grids solved by hand (a corridor, and a two-by-two Frozen Lake whose best moves are into the walls); the maze as an MDP from T97's own rules (`maze`) in the owner's stationary regime -- Blinky alone, chasing for ever, `spec/maze/mdp.json` and its two copies -- 82,160 reachable states (not 160,000: a heading must leave a floor cell behind, Pac-Man never stands on an uneaten pellet), every step of 400 seeded games in the Python game one of the model's outcomes with its reward; measured on a Ryzen 5 9600X: build 1.0 s, value iteration 60 sweeps 3.4 s, peak 117 MB; policy iteration 22 improvements but 1,233 sweeps, 21.6 s, same values within 0.0001, 2,109 exact ties chosen differently; `make solve-maze` publishes `values.json` (thousandths, whole numbers) and `policy.json`, beside the game in `godot/game/maze/` (the owner's decision over the task's `data/maze/`, so an export carries them), (a letter a state, the greedy move over the published values), laid out by arithmetic; N15 in `check_no_training.py` solves again and refuses a GDScript writing them or any file from the maze game, planted cases for each, `modules/maze.json` retrains N15; `MdpPacMan` reads and looks up; C in `make demo-maze` restarts in that regime with the MDP playing, V draws every cell's value red to green with the policy's arrow and each move's Q beside Pac-Man, the panel the same in words, pt-BR in `maze.csv`; 1,000 seeded games: the MDP won 1,000, caught 0; a greedy A\* controller ignoring Blinky won 826, caught 174 (`gameaikit.mdp.measure`); `spec/vectors/mdp/` (ten states, value, four Q-values, move) from `derive.py`, a second value iteration importing nothing, held by `make test-mdp-vectors` and the Python tests; `docs/concepts/mdp.md`, the maze page's section, the literature table's row; mutation round: 9 Python and 7 GDScript rules disabled one at a time, each caught -- one GDScript survivor first (the lookahead without the catch by Blinky's move gave NaN, which no tolerance check refused), now refused by the runner and the suite; review (`docs/reviews/106-value-iteration-plays-the-maze.md`, approve after two should-fixes): the model measured against the game over 20,000 games; never caught is certain, not the MDP's doing -- every state has a safe move, 0 of the 684 states the policy reaches can end in a catch (`catch_from_start`, tested) -- and a safe-greedy baseline also wins 1,000, in 31.9 steps against 30.5, now on both pages; N15 refuses a write into `MdpPacMan`'s tables outside `_load_tables` and a read-back in the maze game or any script holding the reader, the reviewer's three update plants now red; C without published tables keeps your game and says why; 82,160 states the rules allow, 80,288 reachable; the 20 rounded moves stated; policy iteration's count fixed; N15 for `CLAUDE.md`'s row proposed to the owner |
| T99 | A bandit chooses the fighting opponent's answers, during one fight | done | wave 115: `ai_bandit` -- `Bandit` (UCB1, and epsilon-greedy for the comparison) over pulls and payoff sums per arm, the mean computed on read and never kept, ties to the first arm, its own seeded xorshift `BanditDraws` (a copy of T86's, invariant 2); Python twin `gameaikit.bandit` (`@technique("bandit")`, in `KIT_MODULES` and `pyproject.toml`), seven vectors written by an independent `derive.py` (one worked by hand in the README), `make test-bandit-vectors`, two planted bandits (tie to the last, a spare draw) failing in both languages; `test_bandit.py`: over 10,000 pulls of a 0.7/0.3 problem, five seeds, UCB1's regret 24 to 41 against epsilon-greedy's 192 to 206, and growing about twice from 1,000 pulls against about ten times; `FightBanditOpponent` in `godot/game/fighting/`: T37's situations, options, reaction and execution, one UCB1 bandit a situation, an option paid the health lead's change from when it lands to 30 frames after its last input, scaled by 100 into [0, 1], read off the late fight -- a choice counted as a pull when made (`Bandit.pull`) and paid when its window closes (`Bandit.pay`), so an option waiting for its payoff is not chosen again as untried; modes `bandit: easy|medium|hard`; the panel shows, for the situation just named, each option's pulls, mean and bound as they stood when it chose, with a `#`/`+` bar and the chosen one marked `>`, then the last option paid; ADR 0016's conditions held by `fight_bandit_opponent_test.gd` (no mean field, `new_fight` and a restart empty it, the recorded fight rebuilds the same counts twice); N13 in `check_no_training.py` (no file, `ConfigFile` or resource written in `ai_bandit` or any script naming `Bandit`/`FightBanditOpponent`, no `+=`/`-=` multiplying or dividing a difference, no written-out step reading its left side back, no `lerp`, and inside the addon no scaled `+=`; eleven planted cases, two sound ones), N9's docstring one of the exceptions, `CLAUDE.md` row 6 "N9 and N13" and invariant 6's text naming the bandit, as confirmed on 2026-10-29; the opponent's UCB1 constant is 0.5, not the square root of two, measured (`make measure-bandit`, the fighting page): its payoffs sit near 0.5, and at the textbook's constant the busiest bandit is still changing its mind 70 to 90 % of the way through a fight and it loses to T37 in most rows; at 0.5 it does at least as well in every row, gains clearly on the medium rushdown (86 against 68), the medium ghost (45 against 30) and the hard turtle (95 against 73), is level or behind within the noise elsewhere (medium turtle 15 against 20, hard ghost 77 against 84), and settles after 35 to 60 of its busiest situation's 50 to 89 pulls -- 100 fights a row, one seed, and 0.5 chosen against the same opponents; page pair `docs/techniques/ai_bandit*.md` with `opening_example.gd`, the glossary gains *bandit* and *epsilon-greedy*, the menu card and the catalogue name it, the literature table's bandit row names `ai_bandit`; review (`docs/reviews/115-a-bandit-chooses-the-opponents-answers.md`, changes requested, no blockers, all applied): delayed payoffs repeated the untried arm -- now `pull` then `pay`, tested without paying at once, the tables remeasured; the panel drew bounds recomputed each frame -- now the numbers it chose from; N13 widened to three more spellings |
| T100 | The bot match reads how well you play, during one match | done | wave 121: `PlayerModel` in `godot/game3d/botmatch/player_model.gd` counts the played bot's shots, hits, kills, deaths, damage dealt and taken during one match; its estimate is the share of the damage dealt, a Beta mean with a prior of one bar each way, (dealt + 100) / (dealt + taken + 200), the hit rate (hits + 1) / (shots + 2) shown beside it and setting nothing; `MatchDifficulty` reads it every 10 s (200 steps, before that step's events) through a fixed five-row table in `rules.json` (`difficulty`: from 0 / 0.40 / 0.45 / 0.55 / 0.60, aim 6 / 4.5 / 3 / 2 / 1.5 degrees, the middle the knobs' own) and sets the other team's `aim_error` only, bounded by the first and last rows, nobody's when nobody plays; Python twin `gameaikit.botmatch.player_model` (an example's, not shipped), seven vectors in `spec/vectors/player_model/` from an independent `derive.py`, one worked by hand in the README, `make test-player-model-vectors`, planted models failing in both languages (a boundary to the row below and a prior of 1 in Python, a prior of 1 in Godot); the person's events kept in `BotMatch.person_events` (each with its step), written only under `-- --record` (`make record-botmatch`) by `MatchEventLog` to the checkout's `user://botmatch-logs/`, and said so on screen; ADR 0016's conditions held by `player_model_test.gd` (int counts only, the events replayed twice give the live readings, and so does the log read back from disk, which carries the table and the last step), `botmatch_restart_test.gd` (N seats an empty model in the middle) and `event_log_test.gd`; N14 in `check_no_training.py` (the model's two files and any script naming `PlayerModel` or `MatchDifficulty`: no file written or read -- `FileAccess`, `JSON`, `load(`, `preload(`, `user://`, the loaders --, no step, no value read back through a product, and in the model's two files no scaled `+=`; a net, not a proof; planted cases from the review's script included, two sound ones -- counting, and the event log), N9's docstring names N14, `CLAUDE.md` row 6 "N9, N13 and N14" and invariant 6's text the difficulty model; V while playing shows the counts, the share worked out, the hit rate, and the other team's aim with its row, marked when the latest reading changed it; the overlay gains `difficulty`; measured (`make measure-player-model`, `docs/godot/botmatch.md`), stand-ins in bot 0's place at 8, 3 and 1 degrees, five seeds: the knob settles right (poor on easy, sharp on hard, even round the middle) and overshoots the match -- the score lead goes -121 to +259 for the poor, +224 to -218 for the sharp, and a narrower table (4 to 2 degrees) still flips both (+200, -118); the even stand-in's row chatters about five changes a match, turning back most times; the table was not tuned against the stand-ins, and what the model should read is left to the owner; review (`docs/reviews/121-the-bot-match-reads-the-player.md`, changes requested, no blocker, all applied): N14 now reads the holders of `MatchDifficulty` and every file read, the knob moves at once when the person changes (`BotMatch.seat_person`), the page calls N14 a net, the log rebuilds the readings by itself |
| T101 | Utility choice as its own addon, out of `ai_teamwork` | done | wave 103: `ActionChoice` and `ErrandChoice` moved to `godot/addons/ai_utility/` (contents and `.uid`s unchanged), their Python twins to `gameaikit.utility`, their 21 vectors to `spec/vectors/utility/` byte for byte -- `derive.py` split in two, each half rewriting its directory identical to what is committed; `make test-utility-vectors` beside `test-teamwork-vectors`; `modules/ai_utility.json`, `botmatch` and `infiltration` depend on it, and `ai_teamwork` names nothing of it (`lint-modules`, `check_addon_deps.py`); the fighter example moved with `ActionChoice`, and `ai_teamwork`'s page gained `squad_example.gd` (one flank granted by `RoleArbiter`); a new page pair `docs/techniques/ai_utility*.md`, `ai_teamwork`'s shortened, the catalogue regenerated, the literature table's utility row names `ai_utility`; no number moved -- the bot match's and infiltration's gates unchanged, one test path (`botmatch_test.gd` reads `spec/vectors/utility/`); `AimChoice` and `PassageChoice` stay, the reasons in the task file -- `AimChoice` has no team word either, so where it belongs is left to the owner, recorded in T64; review (`docs/reviews/103-utility-choice-as-its-own-addon.md`, approve after two should-fixes): the bot match's card gained `weighed-actions`, the `ai_utility` pages teach `shooter-ai` (ways-to-decide never mentions utility), the teamwork README lists all 39 vectors, and four nits |
| T102 | The tactical match's header and status fit the window | done | wave 100: the header wraps at 12 px over the board and the legend (x=304..1256), its last line at y=125 at worst, 19 px above the board; the status takes the whole left column from y=8 at 13 px; the line naming the controllers C cycles through moved to `Interface/Keys` under the board; on the computer's turn one blank line is kept, before the decision; `tactical_layout_test.gd` plays ten rounds of a seeded game per controller and language, the person waiting and striking, and holds the lowest status word over the game (worst y=656, planner, pt-BR; the review's probe had found 834 with the first layout, which measured the opening screen only), the header's width as its words' width, and the keys line; `test-locale-screen` measures a wrapped Label whole (width, and words a gutter above the bottom; two planted cases), the header left `NOT_YET_FITTED`, which now holds three panels with a ceiling each, for T107; the difficulty levels' `Difficulty.describe()` English is worded by `DifficultyWords` in the tactical game (the addon stays English, no addon calls `tr()`), held to the addon and to `Difficulty`'s fields; review in `docs/reviews/100-the-tactical-header-fits.md`; manual check the owner's |
| T103 | The pad's legend line speaks Portuguese | done | wave 109: `game_shared` has a table, `godot/locale/game_shared.csv` -- "pad" is "controle", "stick" "analógico" ("analógico esquerdo" where the right one looks too), the D-pad's directions words ("D-pad cima"), four bound together one binding ("D-pad setas"), the right stick looking and RT clicking two keys; keys that print no word are translated as the kit's other tables say them ("espaço", "setas", "cima", "."), and the names a key or the pad prints stay (Shift, A, LT); `PadAsKeys.planted` writes the line with no pad, for the checks, and nothing in a game sets it; `test-locale-screen` plants it and fails an example whose legend lacks the pad's lines as written now, or shows one in English, whole, binding by binding or by key name (planted: a pad line written in English and not rebuilt); `test-demo-overlays` plants it too and fails an example with a pad none of whose lines reached its legend; it found the English line running off the window at three bindings a line in both racers and the stealth hall -- the line now breaks at the legend's width; `make test-pad` holds the line in both languages, English words in any case, its width and that nothing is dropped (24 claims); glossary rows for D-pad, the pad's printed names and the stick; not fitted, left to the owner: a legend's height with a pad -- the bot match's ends at y=740, the racers' run over their status, the maze's touches its decision -- as before this wave; review in `docs/reviews/109-the-pad-legend-speaks-portuguese.md` |
| T104 | The tactical AI keeps its reasons as keys, translated where shown | done | wave 108: every tactical team's reason (rules, planner, levels, learned, the four techniques) and the skirmish's is a `Sentence` -- `TacticalDecision.reason`, `LearnedDecision.reason`, `why_planned`, `thinking()`, `why_unusable_sentence()`, `error_sentence()`; pieces with their articles and lists of pieces or deeds as nested sentences; worded by `TacticalStatus.said` in the status, the plan's lines (`plan_lines(say)`) and the skirmish's panel and `PlanView`; overlays and tests read `english()`; `tactical_reasons_test.gd` (every controller, six seeded rounds, the same overlay in en and pt-BR; a language switched mid-turn rewords the reason) and `skirmish_reasons_test.gd`; `make test-decisions` plays its scenarios in both languages; five suites drop their English pin and pass with the engine started in pt-BR; the news of what was played is still worded when it happens (not a reason, left out); `docs/godot/localisation.md`; review (`docs/reviews/108-the-tactical-ai-keeps-its-reasons-as-keys.md`, approve after three should-fixes): every controller also plays whole seeded games against the rules in both languages, reaching fall-back, defence, retreat and a broken HTN plan (a planted `tr()` there had survived), lint rule L9 refuses a translation inside `Sentence.of(...)`, `learning.md`'s example and the planner suite's pin fixed |
| T105 | Seek is given a time to reach its velocity | done | wave 98: the follow-up from T75's review -- seek closed the velocity gap at an implicit gain of one a second, and the racing example multiplied its force by `RESPONSE = 10`; seek and pursue gain arrive's `time_to_target` (Millington's form, read in `aicore`; Reynolds' per-step mass weighed and not taken), through `Steering.towards_velocity`, in both languages; default 1 s, today's behaviour: every steering gate the same to the digit before and after, while a default of 0.1 moved the 2D ladder (32.46 / 31.17 / 29.67 s) and 36 vector samples; the example at 0.1, and 1019 failed assertions at 1, 963 at 0.75, none from 0.5; two new vectors; `docs/concepts/steering.md` |
| T106 | A model file any game can load | done | wave 99: `ModelFile` checks only what every model file has (`models`, each `kind`, `features`, `weights`, `bias`; M1-M8, M10) and hands every other top-level field over unread in `extra`, with `from_text` beside `load_from`; the tactical game's four conventions moved to its own `TacticalWeights` (W6, W7 -- the codes `gameaikit.tactical.report` gives them; W7, the reversed terrain range, is new on the Python side, and the GDScript side now also refuses a convention with a fraction), which every tactical and skirmish reader takes; the Python twin `gameaikit.training.model_file` writes the file `report.py` publishes and refuses on the same codes, held together by `spec/vectors/model_file/` (26 cases); `weights.json` regenerated byte for byte, no field added -- so no format version, which would have meant republishing it (N4); the page's example loads a model file of its own; `checkers.json` keeps `ai_learning` -- `lint-modules` measured it, the checkers *trainer* fits with `gameaikit.training`, so the catalogue's ○ is right and the page now says why; `skirmish.json` dropped it instead, reaching it through `tactical` (◐); mutation round: 21 GDScript and 16 Python rules disabled one at a time, each caught; review (`docs/reviews/99-a-model-file-for-any-game.md`) made the two readers agree where they did not: Python refuses `NaN`/`Infinity` as M2 and a too-big integer as M8 instead of crashing, a parse error's line counts from 1 in both, M6 walks the names once in the same order, W6 accepts a whole-valued float and walks the conventions in declared order on both sides, held by a second shared vector, `spec/vectors/tactical_conventions/` (13 cases); the example answers NAN with no model. **Follow-up found, no task yet:** `ClonedPlayer`'s C1 sentence (`cloned_player.gd:33`) tells the reader to `run make train-clone`, the same tie to this kit that M1 had -- for T64 |
| T107 | Three wrapped panels keep clear of the window's bottom | done | wave 105: each measured over played states, not the opening screen -- a layout test per module, both languages; the behaviour demo's status at 13 px (16 before), its three lines ending at y=696, the gutter, under all four brains over 300 turns; the skirmish's status at 16 px (18 before) and given the whole left column from the top gutter (the legend stays level with the board; `BoardLayout.lay_out` takes the column's top, shared with the tactical match), worst y=671 in pt-BR -- red walking onto a node, a refused click and blue's reasons -- where the old layout reached 861; the RTS card's info takes the whole card when there are no buttons (how to play, with nothing selected), y=661 in both languages, and its `Why` beside the buttons measured too (695 at worst); `NOT_YET_FITTED` empty and kept, its planted cases sharper (4 px past the gutter) and one more under a ceiling; Control's combined minimum size lags a resize or a font change by a frame, a text change not (measured, `docs/godot/localisation.md`); review in `docs/reviews/105-three-wrapped-panels-keep-a-margin.md` |
| T108 | The pad's legend keeps its height | done | wave 117: `test-demo-overlays` fails, for every example with a pad, in both languages, a legend whose last line (`Legend.drawn_height()`, its descent counted) ends below the gutter (y=696) or less than 8 px above a visible Control below it in its column; planted: past the window, over the Label below, touching it, and 8 px clear (must pass); it found the four T103 named and the infiltration's (y=742); every pad line kept: the bot match's legend starts at 480, the infiltration's at 440, the maze's at 8; `HAS_PAD` names the seven examples with a pad; in both racers the status follows the legend 12 px under its last line, and the map moved to the view's bottom-left corner; `racing_layout_test.gd` and `racing3d_layout_test.gd` hold where the status's words end in every panel state, both languages (planted: a status too long) -- the 2D racer's ran over its minimap and ends at 684 at worst now, the 3D racer's racing panel, never measured, ran over its trace, which moved to 568; not measured: the RTS (no pad), whose legend ends 6 px above `Thinking`; `docs/godot/localisation.md`; review in `docs/reviews/117-the-pad-legend-keeps-its-height.md` |
| T109 | One seeded generator in `ai_core` | done | wave 122: `Xorshift` in `ai_core` and `gameaikit.core.Xorshift`, the one generator; the four copies deleted with their `.uid`s -- `Xorshift` (T86), `MazeDice` (T97), `ParticleDraws` (T91) and a fourth the task did not list, `BanditDraws` (T99, wave 115), each with its Python twin; `ai_adversarial` and `ai_bandit` now depend on `ai_core`, the maze lists it; ADR 0021 amended (why a generator is not logic, and that no other helper follows without the same argument); `spec/vectors/core/` (six seeds: draws, uniforms, picks; `derive.py` imports nothing) held by `make test-core-vectors` and `make test-python`, planted twins failing it in both languages (a pick of one that spends a draw; no mask, or a draw ahead); `spec/vectors/adversarial`, `bandit`, `perception`, `maze` unchanged against main and green through the shared generator; the wheel ships `gameaikit.core` (`release.py` accepts the kernel's package); the copies' pages say two folders; the unprefixed name and the wheel's kernel package are pending the owner (they contradict ADR 0024; written so in ADR 0021, pointed at from 0024); the acceptance's diff narrowed to the vectors' `*.json`; review (`docs/reviews/122-one-seeded-generator-in-ai-core.md`, changes requested, no blocker -- a core runner green on a mistyped vector -- all applied; the same weakness in `mcts_vectors_runner.gd` left for a follow-up) |
| T110 | The tactical game's news keeps its words as keys | done | wave 124: the news of what was played is a `Sentence`, worded where shown -- `TacticalCombat.told`, `SquadCombat.told` (T85's shot, outside the file list), `TacticalRuleset.told`, `TurnStart.open` and `ControlPoints.pay` (one a line), and `tactical.gd`'s `_last_event` (a list, one a line) and `_computer_news`: build, wait, forge, taken back, an enemy come into sight, "{side}'s attacks:"; `TacticalStatus.side_word` a side's key, `news_in_english()` for the suites; no key changed; `tactical_news_test.gd` switches language after an attack, a build, a wait, a purchase and a tower's shot, both ways (a news line worded when kept fails it); `docs/godot/localisation.md` |
| T111 | A new gate selects its module, and merges clean | done | wave 123: rule 5 read no Makefile since wave 83 (its Windows conditional) and no vector folder (no slash); both fixed, planted; `test-vectors:` read like `check:`, and split, each family `test-vectors: test-x-vectors` beside its rule (`check_workflow.py` reads every rule); a new non-gate target selects nothing; rule 6, `added_module.py`: a new module's manifest, its user's `depends_on`, `KIT_MODULES` and `packages` select it, with `test_techniques` on every Python selection; `packages` sorted, `release.py` refuses it unsorted; timing gates named on `check-affected`; wave 120's replay selects ai_constraints, infiltration, menu; `docs/howto/parallel-batch.md`; rule 6, the non-gate targets and the sort refusal are not in the decisions, pending the owner |
| T112 | A review before the repository opens | todo | the owner, 2026-11-04: after the main tasks, and after T120 (2026-11-05, item B6); a stranger's read, a report and follow-up tasks; opening, CI and publishing stay the owner's |
| T113 | A decision tree reads the fighting opponent | todo | after T112; the owner, 2026-11-04; CART fitted in Python, `LearnedTree` reads it; the path shown |
| T114 | A random forest votes on the same question | todo | after T113; held-out accuracy of one tree against forests of 5, 25 and 100; the votes shown |
| T115 | A Bayesian network for the guard | todo | after T112; `ai_bayes`, exact enumeration, hand-written tables; is someone there, and which evidence says so |
| T116 | The guard's speech without markup: a schema or a prompt, measured | done | wave 129: read at `b11960` (`docs/local-llm/server.md`, "A pattern on a string"): a pattern must be anchored, an unsupported one is dropped with a warning, and `json-schema-to-grammar.cpp` matches it against the string's JSON text and drops `maxLength` beside it, so `LlmValidator.SPEECH_PATTERN` (and its Python twin, and `spec/llm/reply.schema.json`) is `` ^[^"\\<>\[\]*`\x00-\x1F\x7F]{1,280}$ `` -- no markup, control character, quote or backslash, the length inside; measured on the 30 lines, Ministral 3 8B, Vulkan, three rounds a language, against the shipped schema measured again (R10 15 in en, 8 in pt-BR): the pattern 30/30 valid every round and no refusal, act and argument right 17,17,17 en and 16,15,21 pt-BR; a prompt line R10 2 and 0, fewer English acts right; both together no better than the pattern; the pattern ships, the prompt stays T93's, R10 stays in the validator; tests hold both twins to the committed schema and the pattern to every R8-R10 vector case; review (`docs/reviews/129-the-guards-speech-without-markup.md`, changes requested, no blocker, all applied): `spec/llm/README.md` said the schema could not say what the pattern now says, and neither it nor `json_schema()` said the pattern is stricter than the validator (no straight quote or backslash) and always on; the quote's evidence is 180 replies, not 360 |
| T117 | The squad's MCTS searches a share of the frame, in play | todo | the owner, 2026-11-05, item A6: a time share in the scene, the iteration count kept for matches and tests |
| T118 | The RTS shows the stale enemy a clocked side believes in | done | wave 130: with K on, `RtsThinking` draws the enemy the clocked computer was last handed, read from `RtsHumanClock.last_handed()` and never recomputed: a hollow ring where it believes each unit stands, a dashed thread to where it stands now, and the view's age in ms (`enemy_age_ms()`); the panel says it in a line, and what waits under the cap (`waiting()`: how many, the oldest's wait), in both languages; `test/rts/rts_human_clock_test.gd` holds the drawn enemy equal to the handed one, in the unit and in the mounted scene, and nothing drawn without the clock; the drawing held too (`drawn_believed`, the rings' cells); five plants caught; seen in a windowed screenshot; review (`docs/reviews/130-the-rts-shows-the-enemy-a-clocked-side-believes.md`, approved, two should-fix and four nits, all applied); manual check the owner's |
| T119 | A gate for the pt-BR glossary: an English term in italics is defined | done | wave 139: the owner, 2026-11-05, item B4: `check_glossary.py` (`make lint-glossary`, in `check-no-engine`) reads every italic span outside code on every pt-BR page but the glossary, a span running onto the next line included, and asks the glossary's first column, without case and with one plural rule (a final `s`); measured first: 14 titles and 14 Portuguese spans, held in an allowlist declared in the gate, an entry no page uses a finding (G4); it found 9 undefined terms on the pages, fixed with 4 glossary rows and 2 spellings on existing rows (*arm*, *epsilon*, *exploration*/*exploitation*, *rush*, *backjumping*, *min-conflicts*), *stand-ins* written in Portuguese in `ai_bandit` and *hash* written *spatial hash* in `ai_rts_core`; planted: an undefined term, its plural, a span over two lines, an underscore italic, *zergling*s, *arrived*, *seekss*, ***x***, an escaped star in a span, a link target, the comma split, the README, no page at all, an empty glossary table; review (`docs/reviews/139-a-gate-for-the-pt-br-glossary.md`, changes requested, no blocker, all applied; the per-page allowlist key left as a note) |
| T120 | `Xorshift` becomes `GakXorshift`, before anything is published | done | wave 140: the GDScript `class_name` is `GakXorshift` in `ai_core`, its file still `xorshift.gd` (no `.uid` moved), every use renamed in `ai_adversarial`, `ai_bandit`, `ai_perception`, the maze and their tests; the Python twin keeps `gameaikit.core.Xorshift` (ADR 0024); the pages in both languages, the guide's table of `Gak` names, `modules/ai_core.json`'s summary, the README and the vector notes; no draw moved -- the core, adversarial, bandit, perception, maze and squad search vectors pass unchanged; ADR 0024's table gains the tenth row, and whether 0.1.0 promises ten names, not nine, is open, asked of the owner in the pull request (recommended: ten); ADR 0021's history and T109's record keep the old name, which was the name then |
| T121 | Every vectors runner refuses a vector of the wrong type | todo | the owner, 2026-11-05, item B9: the core runner's type checks, in all 25 runners; `mcts_vectors_runner.gd` exits 0 on a mangled file today |
| T122 | The infiltration's levels are solved off the main thread | done | wave 131: `LevelSolving` runs `LevelConstraints.solve` as one `WorkerThreadPool` task, polled each physics frame and waited for once done (and in `_exit_tree`); the old level plays on and the panel's first line says "solving level N"; one solve at a time, L or K pressed meanwhile answered when it ends; headless the scene solves inline (`solve_in_background`); `level_solving_test.gd`: the pool equals inline on seeds 3, 54 and 144 (data, assignment, counts, trace), one solve at a time, the scene keeps the old world until the new one; `level_solving_measure.gd`: the longest frame on L, seed 144, 2281 ms inline, 21 ms on the pool (a drawn level's world build is 24-37 ms); `docs/godot/worker-thread-pool.md` (the pool and thread-safety pages for 4.7, and the measurement); the infiltration page's stall paragraph is now what happens; decisions in the PR; review (`docs/reviews/131-levels-solved-off-the-main-thread.md`, changes requested, no blocker -- the panel named a solve that would replace nothing -- all applied) |
| T123 | The bot match reads the team's share, holds the middle, and starts over on a new team | done | wave 132: `PlayerModel` also counts the person's team-mates' hits and hurts (`mate_hit`, `mate_hurt`, noted by `BotMatch.note`) into `team_dealt` and `team_taken`, and the share the knob reads is the team's, (team_dealt + 100) / (team_dealt + team_taken + 200); a band in `rules.json`'s `difficulty` (`band`: from 0.45 short of 0.55, the middle row's own range) holds the row read last (`PlayerModel.next_row`, `held` in each reading); a `seat` event, logged by `BotMatch.seat_person` with its team and stamped with the last step taken, empties the counts on a change of team (`restarts` counts it) and `MatchDifficulty` puts the row back to the middle at once, live and in `PlayerModel.replay`; a seat on the same team and a give-back keep them; Python twin and `derive.py` likewise, eleven vectors (four new: the band, a team-mate's damage, a change of team, a seat on the same team; the boundary case now crosses the band's two edges), planted models failing (no band in both languages, counts kept across a change of team in Python); V shows the team's share, "started over" and the band holding the row (pt-BR rows added); measured (`make measure-player-model`, `band=FROM-TO` to try another, `docs/godot/botmatch.md`): the score lead with the model on goes from +259 / -5 / -218 (T100) to -12 / +7 / -47 for the poor / even / sharp stand-ins, bands none, 0.47-0.53 and 0.40-0.60 measured beside it; the knob alternates between the rows either side of the middle rather than settling, said on the page |
| T124 | The XCOM mode plays with V off, and teaches with it on | todo | the owner, 2026-11-05, item B17: what "the teaching view" is, is the task's first decision |
| T125 | A second, stronger floor for the squad mode's strength | todo | the owner, 2026-11-05, item B18: a greedy shooter; the bar from measurement, a worse weighing planted |
| T126 | The XCOM mode's presentation moves into a mode view | done | wave 128 (#74): `TacticalModeView`, answered by `AdvanceWarsView` and `SquadView`; `TacticalRuleset` from 28 answers to 14, the scene asks `view()`; behaviour unchanged, held by the tactical and squad suites and new tests of each view's answers and of which view draws after M; the owner, 2026-11-05, item B19 |
| T127 | An unseen shooter stays unseen in the news | todo | the owner, 2026-11-05, item B24: word the news from the person's fog, or a shot reveals its shooter -- the task chooses |
| T128 | A focus ring outlives its sight | done | wave 137: the owner, 2026-11-05, second list item 6 (this session's proposal); a fighting squad's focus ring whose target is out of the computer's current sight is drawn at the last place the side was told of -- the clock's handed view first, then the side's own memory (`RtsInfluence.last_seen_at`, new) -- in the late enemy's thin white, its line to the squad dashed; a target in sight is ringed where it stands now, clock or no clock (T118's decision 7); a rival out of sight gets no ring, as before; none when the side was never told of the target or has forgotten it; drawing only, nothing the squad decides reads it; `RtsThinking.drawn_focus` records each ring as T118 records its own; `test/rts/rts_focus_ring_test.gd` (6 cases; planted: no fallback, memory before the handed view, the handed view before the current one, rivals falling back, and no clear between drawings, each fails one); one sentence in `docs/concepts/rts-ai.md`; the manual check says the ring jumps back to the last decision's sighting, and that a kill leaves a short stale ring; review (`docs/reviews/137-a-focus-ring-outlives-its-sight.md`, changes requested, one blocker -- the PR's body was another wave's -- all applied) |
| T129 | Line separators are refused in a speech | done | wave 141: the owner, 2026-11-05, second list item 9, from T116's review; R9 in both twins refuses Unicode's every control (C0, DEL, C1: U+0080 to U+009F, NEXT LINE among them) and U+2028 and U+2029; `SPEECH_PATTERN` and `reply.schema.json` leave out `\x7F-\x9F` and the two separators, written as the characters themselves because Godot's `RegEx` refuses `\u2028` (measured on 4.7.2); seven vectors (six R9, NO-BREAK SPACE accepted), red in both languages before the fix; a Python sweep over every code point holds R9 to Unicode's Cc, Zl and Zp, and a gdUnit sweep below U+3000 holds the pattern to R9; the converter's reading read at `b11960` (`json-schema-to-grammar.cpp`, `llama-grammar.cpp`), not measured on a model, in `docs/local-llm/server.md`; review (`docs/reviews/141-line-separators-are-refused-in-a-speech.md`, changes requested, no blocker, all applied: raw separators in the docs and two vectors written as escapes) |
| T130 | The talk game starts its own model | done | wave 133: the owner, 2026-11-05, "as 3" (ADR 0023 amended): Tab into live mode asks `/health`; nothing answering, in a checkout, `LlmLocalServer` (ai_llm, the one file `check_llm_validated.py` allows `OS.create_process`) starts `scripts/llm serve`, typing waits while it loads, and leaving the scene stops only what it started; an exported game, a headless run or no `scripts/llm` says to run it by hand; recorded mode starts nothing; tests against `fake_llm_server.py`, a fault planted per case; measured: Tab to ready 2.5 s, longest frame while loading 9.3 ms headless and up to 101 ms windowed (the card), about 90 ms on leaving (`OS.kill` waits) |
| T131 | The menu's cards speak Portuguese | done | wave 134: the owner, 2026-11-05, "as 3": every card's title, what its AI decides, each technique's name and part, what to watch and the keys are rows of `menu.csv` (187, keyed by the catalogue's English, which stays the one list), worded where the card is drawn (`ExampleCatalogue.said`, the list and the heading in the menu); mode titles, docs paths and make targets stay; MDP added to the glossary; L10 in `check_translations_game.py` fails a shown catalogue field with no row (planted: the Checkers row removed), and `test-locale-screen` reads every card in pt-BR (planted: a card and a list in English) |
| T132 | A language change in `_ready` adds its children | done | wave 135: the owner, 2026-11-05 ("as 3"), from `make demo-talk` with pt-BR saved; measured on 4.7.2, `set_locale` notifies through `propagate_notification`, which holds the node busy, so the talk scene's new guard never reached the tree, in `_ready` or at any later change; a deferred restart in the scene, skipped out of the tree; not a deferred `Language.apply`, which notifies the same way and fixes neither path; the scene takes a `settings_path`, as the menu, so the test never writes the person's language; `talk_language_test.gd` opens it as the main scene and switches it while open; the other 15 scenes that call `apply_if_opened_alone`, and the menu, measured unaffected; `docs/godot/localisation.md`; review (`docs/reviews/135-a-language-change-in-ready-adds-its-children.md`, changes requested, no blocker, all applied) |
| T133 | A silent server never holds the frame | done | wave 138: from the second review of T130 (PR #82); read in the 4.7.2 source, a threaded `HTTPRequest` reads in blocking mode and `cancel_request` joins its thread, from the timeout and from leaving the tree; `HttpRuntime` now runs its `HTTPRequest` with threads off, which reads without blocking; measured against `fake_llm_server.py --silent`, 1 s timeout: threads off, worst frame 7 ms and `failed` at 1 s; threads on, 38.6 s; threads on never cancelled, 59.0 s when its node was freed, so "let it end and ignore it" was dropped; V3 in `check_llm_validated.py` now asks for `use_threads = false` (planted: threads on, false then true, none set); `test_a_chat_request_to_a_server_that_never_answers_never_holds_the_frame` (red at 58.5 s before the fix); `docs/godot/llm-requests.md`; review (`docs/reviews/138-a-silent-server-never-holds-the-frame.md`, changes requested, no blocker, all applied: V3 refuses `set_use_threads` and a conditional) |
| T134 | A belief that ends a game still going on | todo | from T88's duel and its review (wave 136, finding 6): `MctsSquad._chosen` crashed 4 times in 40 timed matches on a board its side believed won or lost while the game went on; guarded and tested in `SearchingSquad._begin`, cause not found; find where the belief is made wrong, or fall back to every known enemy at its last cell |
| T135 | ConstraintDraws draws from GakXorshift | todo | from wave 142's review (T96, finding 4 and decision 5): `ai_constraints` keeps T95's copy of the xorshift that T109 moved to `ai_core`; fold it in, keep `shuffle`, declare `ai_core`; the draws agree, so no vector moves |
| T136 | The guard's last line is shown whole | todo | the owner's manual check, 2026-11-06: in `make demo-talk` the `History` label (150 px, `clip_text`) cut Bram's newest line at a seventh wrapped line; drop old turns from the top until the newest fits |
| T137 | A hit chance does not cover the piece's number | todo | the owner's manual check, 2026-11-06: in the XCOM mode the hover's hit chance and the piece's number share the bottom-right corner; drawing only |
| T138 | The RTS frees what it made, at exit | todo | the owner's manual check, 2026-11-06: closing `make demo-rts` printed 21 leaked ObjectDB instances and 15 resources in use; measure with `--verbose` first |
| T139 | Format controls are refused in a speech | todo | the owner, 2026-11-06, list item 7 (T129's decision 2): R9 refuses Unicode category Cf (zero-width, bidi, soft hyphen) in both twins |
| T140 | A server's refusal is cleaned as a speech is | todo | the owner, 2026-11-06, list item 8 (T129's decision 3): `HttpRuntime._error_of` asks R9's test instead of cleaning C0 and DEL only |
| T141 | Every `-s` gate fails on an engine error | todo | the owner, 2026-11-06, list item 12: every `-s` line in the `Makefile` through `godot_checked.py`, a lint with a planted bypass; runs alone |

---

## Resuming after 2026-10-21 (wave 70 merged, wave 71 opened)

**Where it stopped -- read first.** Wave 70 (T51, the bot match) merged as
PR #8 (`d98060a`). The owner asked for it to be merged before the CI had
finished: the full `make check-affected` was green locally on the merged
commit, and the gates job had failed only on the PR title's length. Read
`docs/godot/botmatch.md` for what T51 measured.

**Now: wave 71, T66** (`tasks/T66-the-lanes-map.md`), on branch
`wave/71-the-lanes-map`. It holds the owner's six asks after playing the
match, all written in the task:
1. a three-lane map with protected spawns, flanks and high ground (option
   1 chosen, research done);
2. sprint with Shift, no firing while sprinting;
3. a reload you can see and hear;
4. a humanoid body;
5. hit zones: head 2x, torso 1x, limbs 0.5x;
6. bots that aim where the expected damage is highest.

It also carries T65's question: does the coordinated team win on this map?

**Start at T66 step 1**, height in the simulation: a floor height per walk
cell, and a height-aware `SearchGraph` for A*. Two things T51 learned
must hold throughout. Red's paths stay searched in the mirror. The built
map must be mirrored exactly; the sketch is not quite. The fair mirror is
claim 0 of `botmatch_effects.gd`.

## Resuming after 2026-10-21 (wave 70)

**Where it stopped -- read first.** Wave 70 did T51, the bot match, as the
owner asked after wave 69 merged ("a proxima onda do fps"). The review
record is `docs/reviews/70-the-bot-match.md`.

**What landed.** `ai_teamwork` holds four techniques: tactical positions
with claims, a team's additive influence, a commander over weighed
objectives, and squad confidence with the retreat in waves. Each has a
Python twin and vectors from a third copy of the rules. The match runs as
a simulation with no physics engine, held to Godot's own rays. The 3D
scene draws the decisions, and `make demo-botmatch` opens it.

**The owner decided, mid-wave, three times.**
1. Both modes: watch, and T to take over any bot of either team.
2. First person, like Counter-Strike or Unreal, after playing the
   third-person cut. So the shot is a 3D ray, every shot leaves a tracer,
   there are hit markers and a rifle in view, and the rifle's rules are ten
   shots a second.
3. "Dizer a verdade": the score does not show the techniques winning.
   On a fair mirror, retreat costs the match and the commander's help is
   1.8 standard errors. T51 closes on the claims about what each technique
   decides; the page has the rest (`docs/godot/botmatch.md`), and T65 is
   "a coordinated team that wins".
4. After playing it: a better map -- covered points, flank routes, spawns
   behind corridors, high ground you can climb, like Counter-Strike's or
   Unreal's. That is the next wave, with T65.

**Measured, worth knowing.** Four things bent the mirror or the match:

- shots resolved in id order gave blue the first shot of every step;
- spawns on cell edges cost red a metre on the walk grid;
- a point inside a box left its bots without a path;
- and A*'s fixed order of neighbours made a path east unlike a path west,
  so blue won 18 to 2. Red's paths are now searched in the mirror.

The mirror's fairness is a claim of the effects test now.

**Next.** The owner's map, with T65 (`botmatch-map-like-cs` in memory):
read CS and UT layouts first. Then T52 or T64, as the owner says.

## Resuming after 2026-10-21 (wave 69)

**Where it stopped -- read first.** The owner accepted ADR 0018 on
2026-10-21, option A: the 3D lives in `godot/game3d/` inside the one
project, and its assets are out of git, referenced by their links. That
reordered the plan: milestone 5 opened before T64. Wave 69 did T50. The
review record is `docs/reviews/69-the-3d-tier.md`.

**What landed.** Jolt is set explicitly. `godot/game3d/assets.json` names
Kenney's Mini Characters (CC0) by page, archive URL and sha256.
`make assets-3d` fetches them into `godot/game3d/downloaded/` (gitignored).
`AssetShelf` hands back a primitive when a model is missing. A test arena
of T51's size has a legend and a sight-line overlay. `make test-game3d-floor`
holds what was measured. `check_no_assets.py` refuses a pack's file
committed under any name. `check_renderer.py` gains the missing 3D types and
R6: nothing in `game/` or `demos/` loads from `game3d/`.

**Measured, worth knowing** (`docs/godot/3d-headless.md`). Headless 3D
works, and a run replays bit-identically on one binary. A navmesh set on a
region's second physics frame never reaches the map. Every node under
`root` shares one navigation map, so a test makes its own. A body moved
through its node is in the physics space only a physics frame later; told
to the server, at once. On this machine
Godot used the integrated GPU only under X11, with three environment
variables set.

**Still the owner's.** The tier's name: the README writes "2, in 3D"
provisionally. Whether the tier-1 rule for a 3D example gets a gate.
Whether the assets rule reaches back to the 2D art. T50's manual check: open
the arena with and without the models (`make measure-3d` opens it).

**Next.** T51, the bot match, or T64, the library, which was next before
the owner opened milestone 5. Ask which.

## Resuming after 2026-10-21 (wave 68)

**Where it stopped -- read first.** Wave 68 did T62 and T63 together, as
the owner asked: one branch, each task in its own commits, one review. The
review record is `docs/reviews/68-search-port-and-registry.md`.

**What landed.** The four searches run on any `SearchGraph`, and the grid
is one adapter. A waypoint test shows the port, and shows why the estimate
must be consistent and not only admissible. The tactical board's
controllers are one table, `TacticalRoster`, read by the C key, the league
and the sentence on screen, and the menu's card is held to it (C9).
`tactical` no longer depends on `league`.

**Measured, worth knowing.** The extra layer costs about 5% on 200 A\*
searches. The league reads the table in C's order and seats teams by
place, so its table moved inside its intervals: same games, different
dice, the same verdicts. The old order put back reproduces `main` exactly.

**Next.** T64, the library (it needs T60-T63, all done now). Then milestone
5, after the owner decides ADR 0018, and T55-T57 last. Open by hand, since
`make wave` picks by table order: `make wave-start BRANCH=wave/69-the-library`.

## Resuming after 2026-10-20 (wave 67)

**Where it stopped -- read first.** Wave 67 did T60 and T61 together, as
the owner asked: one branch, each task in its own commits, one review. The
review record is `docs/reviews/67-learning-and-the-small-kernel.md`.

**What landed.** `ai_learning` reads no board, and `ai_core` holds only the
grid and the pathfinder interface; the tactical board is the examples'
kernel, `game/board/` (ADR 0021). Measured with `affected.py`: a change to
the learned model selects 9 modules (15 before), and a change to the board
selects 10 (19 before). Two couplings the plan did not know about were found
by measuring: the skirmish lived inside `game_shared`, and so did the one
view that draws board units.

**Next.** T62 (search over a port; it needs T61, now done) and T63 (the
controller registry), in either order, then T64. Then milestone 5, after
the owner decides ADR 0018. Open by hand, since `make wave` picks by table
order: `make wave-start BRANCH=wave/68-search-over-a-port`.

## Resuming after 2026-10-20 (wave 66)

**Where it stopped -- read first.** `make wave` picked T56; the standing
next step was to write the modularity tasks first, so the owner chose that
and the T56 branch was dropped unused. Wave 66 writes T60-T64 from T58's
plan, each with its diagnosis measured on `5129bfc`; no code moved. The
review record is `docs/reviews/66-the-modules-tasks.md`.

**The owner decided** (2026-10-20), both as recommended: T64 prefixes only
the ports and the kernel; T61's board kernel goes to `game/board/`. And the
order, said twice the same day: first these five, **T60-T64, before the next
milestone**; then milestone 5; the RTS improvements T55-T57 at the end.

**Next.** T60, T61 (it needs T60), then T62 (it needs T61) and T63 in
either order, T64 last. Then milestone 5, shooters in 3D: every task in it waits on ADR 0018
(*proposed*, wave 53), which the owner accepts, amends or rejects first.
`make wave` picks by table order and would offer T56; open T60 by hand:
`make wave-start BRANCH=wave/67-ai-learning-without-the-board`.

## Resuming after 2026-10-20 (wave 65)

**Where it stopped -- read first.** Wave 65 was T59, opened the same day
after the owner played T23's demo and asked whether they were meant to
drive. Mid-wave they asked for a wider track, collision, contrast and open
art. The review record is `docs/reviews/65-race-the-ai.md`.

**What landed.** You drive (`RacingHumanDriver`, a plain `RacingCar` on the
race's physics) against one AI level; Tab keeps T23's three-AI view. The
track is 24 m wide; cars start on a grid, bump instead of overlapping, and
every AI follows and sidesteps to pass a slower car -- a rule in
`RacingRace`, which a test holds never names a level. Art is Kenney's
Racing Pack (CC0), in `godot/assets/racing/`; a follow camera and a
minimap. The review found that following without passing let the leader
win every race and turned the ladder upside down in watch mode -- which
the honest twin could not see, since it runs the same race rules. Fixed
and measured: watch mode finishes hard, normal, easy on five seeds of
six. The owner then raced it and asked for real collisions, brake
feedback, easier corners and then a stronger brake: done in the same
wave, the car made kinder for everyone; they called it much better, the
collision good, and still hard to drive -- the aim here is the AI.

**For the owner.** T59's manual check: `make demo-racing`, race easy, then
hard. The AI starts on the inside of the front row; alone that slot is
worth nothing, measured, but whoever is behind into the first corner has
to pass.

**Next.** The same as after wave 63: write the ports and kernel, registry
and library tasks before starting one; then T56 or T57 as the owner
prefers.

## Resuming after 2026-10-20 (wave 64)

**Where it stopped -- read first.** Wave 64 was T23, the racing demo, the
owner's pick when `make wave` offered T56 (the owner chose it over writing
the ports, registry and library tasks first, which are still unwritten).
The review record is `docs/reviews/64-the-racing-demo.md`.

**What landed.** `godot/demos/racing/` (module `demo_racing`): a track as
nodes and a racing line as an offset at each, a car crude on purpose
(`RacingCar`, one shared `RacingPhysics`), and `RacingDriver` -- a point
`lookahead` metres down the line, drifted by `wander`, steered at with
`ai_steering`'s seek and pure pursuit's formula; a speed from the track's
limit, carried back from the slowest corner, times sqrt(grip margin). Two
gates: `make test-racing-ladder` (easy 39.6 s, normal 36.6 s, hard 35.1 s
a lap; at least a second apart) and `make test-racing-does-not-cheat` (one
physics field for field, no frame past grip or top speed, the knobs used
as reported, and the whole race equal, frame by frame, to an honest twin
the script builds itself -- after two reviews found eight cheats that got
through versions that trusted something a driver can reach).
The task file's last section says where the build differs from its steps.

**For the owner.** T23's manual check: `make demo-racing`, follow easy
(1) then hard (3), and say whether you can see why hard is faster -- the
cyan bar closer to each corner, the line greener through the bend. Still
yours from before: T58's and T20's manual checks, and `data/tactical/`.

**Next.** The same as after wave 63: write the ports and kernel, registry
and library tasks before starting one; then T56 or T57 as the owner
prefers.

## Resuming after 2026-10-20 (wave 63)

**Where it stopped -- read first.** Wave 63 was T58, the owner's
modularity request: done, merged by pull request #1. The review record is
`docs/reviews/63-modules-and-selective-gates.md` (two fresh reviews and
what CI's first ever runs found).

**How a wave runs now.** `make wave-start BRANCH=wave/NN-slug`, work,
`make check-affected BASE=origin/main` (not `make check`), push, `gh pr
create`, a review by a fresh context, apply what it found on the branch,
write the record, `make wave-merge` -- which waits for CI and squash-merges.
The owner authorised merging a reviewed, green pull request without asking
(2026-10-20). A new file needs a module: `make lint-modules` says which
rule it breaks. `make affected BASE=origin/main` says what a change selects
and why.

**What it measured.** `make check` 550 s; `check-affected` 25 s for a
steering force, 26 s for wave 57's demo change, 64 s for an RTS squad.
A wave that adds a module still runs everything (its manifest is global).

**For the owner.** T58's manual check: read `scripts/affected.py` top to
bottom, and the step 7 table in T58, and say whether the saving is worth
the selector. Still yours from before: T20's manual check, and
`data/tactical/`.

**Next.** The plan's later tasks, not yet numbered or written: the ports
and the small kernel (one addon a wave, `ai_learning` first; T58's D4 --
the measuring found `gameaikit.training` imports the tactical dataset, so
checkers' fit depends on the tactical game today), the controller registry
(D5), and the library (the naming decision first). Write them as tasks
before starting one; then T56, T57 or T23 as the owner prefers.

## Resuming after 2026-10-20 (wave 62)

**Where it stopped -- read first.** Wave 62 was T20, the RTS demo, opened
by hand as the owner chose (not `make wave`, which picks T23) and split
first: the human-likeness half and the RTS league became T55, which waits
on T25's recordings. The review is `docs/reviews/62-the-rts-demo.md`.

**What landed.** `godot/game/rts/` on `ai_rts_core`, whose table became
the minimum game and whose rules grew from the owner's play: separation,
a line of fire, strike-back at what a side sees, repair (a sixth order,
which also takes up a site left half-built), and three fog leaks closed.
The commander (`RtsCommander`) plans over
`spec/pddl/rts-build-order-domain.pddl` with STRIPS or the HTN (`H`),
`BuildSchedule` times the plan, `EconomyQueue` is the economy under it and
`QueueSide` the baseline; squads (`Squad`, `SquadTactics`, `FocusFire`,
`RtsInfluence`). The screen is StarCraft's: a camera, a minimap, a command
card with prices and reasons, a placing preview, half speed, paused at the
start. `make demo-rts`, `make rts-art` (Bos Wars, ADR 0020), `make
test-rts-match` (check and CI), `make rts-measure` (slow, by hand),
`docs/concepts/rts-ai.md`, ADR 0010 and 0019 amended.

**What the measurements said** (`make rts-measure`, ten seeds from both
seats): commander 19 - 1 against the queues alone; STRIPS and the HTN not
told apart (12 - 8); normal 17 - 3 against easy, and hard cut after 11 - 9
and 10 - 10 against normal; the queues' mirror 9 - 11 after the review's
fixes, 15 - 5 to west before them (T57 makes it a gate).

**For the owner.** T20's manual check: `make demo-rts` against normal --
it should lose to a good player and beat a careless one, and when it
loses you should be able to say what it got wrong. `make rts-art` once
for the sprites. New tasks from your play: T56 (the armed tower) and T57
(the seat bias gate). `data/tactical/` (your 2 T25 recordings) is still
untracked and untouched.

**Next: the modularity review you asked for on 2026-10-20**, after this
merge and before any new example: every AI a module configurable in any
game, gates that run only for what a wave touches, the design pattern that
fits, and a plan for a Python and Godot library -- written as a plan for
wave 63, for you to approve before it starts.

## Resuming after 2026-10-19 (wave 61)

**Where it stopped -- read first.** Wave 61 was T22, `ai_steering`, which
`make wave` picked after T19: T20 waits on T25, and T25 on the owner's
recordings. The review is `docs/reviews/61-ai-steering.md`.

**What landed.** `godot/addons/ai_steering/`: `SteeringVehicle` (Reynolds'
point with two limits, explicit Euler), `Steering` (clamping, a direction
to infinity that survives -- Godot's `normalized()` answers it with zero --
and the weighted sum), and seek, arrive (Millington's time-to-target),
pursue and avoid, a file each. `gameaikit.steering`, the same in Python.
`spec/vectors/steering/`: six trajectories from an independent
`derive.py`, at 1e-3 because `Vector2` is 32-bit
(`docs/godot/vector2-is-single-precision.md`). The review found avoid
pushing straight back and stalling in front of an obstacle on the line;
it now pushes only sideways, and `seek-and-avoid-head-on` pins it. `make
test-steering-properties` (check and CI): over 100 seeded starts arrive
rests inside its radius and stays, seek never rests, no force breaks its
limit -- each first shown a case it must refuse. `make demo-steering`,
with a card in the menu, and `docs/concepts/steering.md`.

**For the owner.** T22's manual check: `make demo-steering`, watch each
vehicle with its force drawn, and say what it is about to do before it
does. `data/tactical/` (your 2 T25 recordings) is still untracked and
untouched.

**Next (done in wave 62): T20, the RTS demo -- the owner's choice, on
2026-10-19, for a later day.** Not through `make wave`, which skips T20 while T25 waits on
the recordings: open its branch by hand (`make wave-start
BRANCH=wave/62-the-rts-demo`) and split T20 first -- the game, the map,
the economy, the units, fog, the Bos Wars art and the commander now; the
human-likeness half and the league, which need T25's twenty recordings,
later. The owner asked why wave 61 was T22 and not T20: `make wave`
picked it, and that should have been asked, not announced.

## Resuming after 2026-10-19 (wave 60)

**Where it stopped -- read first.** Wave 60 was T19, the real-time core,
the first of the RTS line the owner asked for. The review is
`docs/reviews/60-the-real-time-core.md`.

**What landed.** The task tried to prove itself unnecessary and could not:
`BoardState` moving 200 units one cell costs ~50 ms a step, against a
4 ms share. So `godot/addons/ai_rts_core/`: `RtsWorld` (mutates, a fixed
tick, a seeded dice, `digest()`), `SpatialHash`, `FlowField` (Dial's
Dijkstra, settled in slices), `RtsCommand` and `RtsRules` (the one door,
refusing before doing), `RtsSnapshot` (one side's fogged, read-only view,
all a controller ever sees), `RtsController`, `RtsMatch` (decisions,
counters, recording, replay) and `FrameBudget` (shares in ms; work, not the
clock, inside them). ADR 0019 says why there are two cores.
`make test-rts-budget` (in `check`, not CI: a timing on a shared runner)
and `make test-rts-simulation` (both): determinism by digest with a
planted second seed and a nudged unit, an economy that must carry income
home and raise a building, replay with a planted meddling, three cheats
refused, ~65x real time, fog planted in and out, counters equal to their
log and a clock that varies. The review found the snapshot's board leaking
the enemy's buildings through the fog, units walled in by a building, a
straight walk cutting corners, a site healing its damage and refusals
that leaked fog; all fixed on the branch.

**For the owner.** T20's art is decided and written into its task: Bos
Wars' sheets, referenced by URL and sha256 and downloaded on demand, never
committed. `data/tactical/` (your 2 T25 recordings) is still untracked and
untouched.

**Next:** T20, the RTS demo, on this core.

## Resuming after 2026-10-19 (wave 59)

**Where it stopped -- read first.** The owner set T43, the fighting ladder,
aside ("the fighting game has had enough"), asked for T24 and then the RTS
milestone. T43 is `blocked` with that note. Wave 59 was T24. The review is
`docs/reviews/59-one-window-for-every-example.md`.

**What landed.** `make menu`, now the project's main scene: every example
on one list, a card each -- what the AI decides, the techniques with the
part each plays, what to watch, the keys, the page -- read from
`godot/menu/catalogue.json`, which `check_demos.py` also reads (C1-C8: one
card per target, the page exists, every technique backed by a class the
scene really reaches, no example calls `quit()`). An example opens as the
current scene, so it runs as it does alone; Esc frees it. `make run` names
the checkers scene now. `make bootstrap` installs the Linux export
templates (archive SHA-512 pinned; CI skips them with
`GAK_SKIP_TEMPLATES=1`); `make export` refuses a template that does not
match, reads the `.pck`'s directory for what must and must not ship, and
starts the binary headless; `make release` zips it with LICENSE and NOTICE,
only from a `BUILD` stamp of a clean HEAD. Two new concept pages, so every
card has one: `docs/concepts/stealth.md` and `ways-to-decide.md`.

**For the owner.** T24's manual check: hand the executable to someone new,
three examples, can they say what decides from the card alone. Seen while
checking the menu by movie frames: the tactical board's three header lines
run off the right edge -- the same with `make demo-tactical` alone, so it
predates the menu. The 20 tactical recordings for T25 are still 2.

**Next:** T19, the real-time core -- the owner asked for the RTS line next.
It starts by trying to prove itself unnecessary: benchmark `BoardState` at
200 units x 60 steps first.

## Resuming after 2026-10-19 (wave 58)

**Where it stopped -- read first.** Wave 58 was T25's strength half, with
T15's four techniques written as tactical teams -- the owner's choice of
scope at the start. The review is `docs/reviews/58-one-team-per-technique.md`.

**What landed.** `godot/game/league/`: the state machine, the tree, GOAP and
the HTN on shared facts and five deeds, production left to the rules; the
roster of eight; `LeagueRating` (Bradley-Terry, bootstrap intervals);
`MeteredTeam`, the counters a meter will read. `make league` (~10 min, not
in `check`) and `make record-tactical`. C in the demo reaches the four.

**What the measurements said.** The learned policy and T12's hard level beat
the rules; the planner loses to them; none of the four T15 teams is told
apart from the rules, the HTN only just (+92, -4 to +199). On this board, with the same deeds, *how*
a deed is chosen moves the result less than five seeds of noise
(`docs/concepts/the-league.md`).

**For the owner.** T25's other half needs you: `make record-tactical`, and
twenty games against the rules (the computer's default). Then steps 4-6
and the clone. Still open from before: ADR 0018 (T50-T52, T54 blocked);
T48's third change; T45's and T46's bars; T11's plan and its horizon.

**Next:** `make wave` picks by table order; T25 is `wip` and will not be
picked again until the recordings exist.

## Resuming after 2026-10-19 (wave 57)

**Where it stopped -- read first.** Wave 57 was a fix the owner asked for
by looking: in `make demo-behaviour` the status and the brain's panel were
drawn over the board, white on green, and could not be read. The demo now
lays itself out -- board left, status under it, legend and panel in a
column -- and the owner read it and said it is fine. The review is
`docs/reviews/57-a-readable-behaviour-demo.md`.

**What the owner saw** in T15's manual check: the four brains looked
"slightly different", one smarter and one less -- which is what was
measured: the state machine and the HTN commit and chase, the tree and GOAP
turn back, and GOAP chooses the tree's deed every turn on this guard. For
the owner: a guard with two ways to a goal, at two costs, is what would let
GOAP stand apart from the tree; that would be a change to T15.

**Next:** unchanged from wave 56.

## Resuming after 2026-10-19 (wave 56)

**Where it stopped -- read first.** Wave 56 was T15, taken right after wave
55 on the owner's "do the next wave too". The review is
`docs/reviews/56-ai-behaviour.md`.

**What landed.** `ai_behaviour`: a state machine, a behaviour tree, GOAP
(A\* backwards from the goal) and an HTN (forwards by methods), and
`WaysToDecide`, the table of when each -- and STRIPS -- is right. The guard
is T14's room and perception written four ways in `demos/behaviour/`, each
a `DecisionPolicy`; `make demo-behaviour`, 1-4 swap mid-round.

**What the measurements said.** Left to run, the two brains that commit --
the state machine and the HTN -- look, chase and catch; the two that
reconsider -- tree and GOAP -- turn back each time suspicion dips and never
chase, and GOAP chooses the tree's deed every turn, since this guard has one
way to each goal. The HTN plans faster than GOAP (6-8 against 6-16 us, `make
test-behaviour-benchmark`) over 2-3 worlds or tasks -- true of these two
implementations, not proven of the two directions of search; the counts
are worlds for GOAP and tasks for the HTN, the nearest each has. The manual
check -- do the four look different while you swap them -- is the owner's.

**Next:** `make wave` picks by table order. Still the owner's: ADR 0018
(T50-T52, T54 blocked); T48's third change; T45's and T46's bars; whether
T11's plan should be made worth its horizon (wave 55).

## Resuming after 2026-10-19 (wave 55)

**Where it stopped -- read first.** Wave 55 was T12, taken as written on
the owner's word, though STATUS had said to ask first: the planner then
lost to the rules 2-18 as red, so "every level beats the rules" could not
hold with the planner as the base. It holds now. The review is
`docs/reviews/55-three-difficulties-honestly.md`.

**What landed.** `Difficulty` in `ai_planning` -- three knobs, an allowlist,
the presets; a horizon on `HeuristicPlanner`; `FightOdds`, a fight's odds
worked out from the rules and the die; `LeveledBlue`, which weighs the
rules' walk, staying and every attack cell at 1 or 2 plies. The scene's
computer is any controller on either side: C cycles rules, planner, learned,
easy, normal, hard; S swaps sides. `make test-difficulty-knobs` is in
`check`; `make test-difficulty-matches` (~15 min) is not, and says so --
CI does not hold the ladder.

**What the measurements said** (T12's record has every pairing, and the
command that plays any two points on the knobs). Three things were wrong
before the levels were ordered, each found by watching a game rather than
by tuning: a route to the goal round enemy pieces, which two sides ringing
their workshops left nobody with (everything froze); standing still valued
above the rules' fallback walk, so noise *helped*; and an answer counted in
full, so 2 plies stayed home -- Wesnoth's aggression (0.4) is from the
reference, not fitted. Hard over normal is the thinnest step, 59-40 against
a margin of 15 in 100. **The plan horizon is a knob that weakens**: no plan
beat T11's plan 77-23 at every horizon tried, so every level plans 0 actions
ahead -- for the owner: T11's plan is a worse strategy than buying by the
rules on today's board.

**Next:** `make wave` picks by table order. The owner's still open:
ADR 0018 (T50-T52, T54 blocked); T48's third change; T45's and T46's bars;
and whether T11's plan should be made worth its horizon.

## Resuming after 2026-10-18 (wave 54)

**Where it stopped -- read first.** Wave 54 was T53, documents only, taken
on the owner's "one more wave" after wave 53 (`make wave` would have picked
T12; T53 was chosen because it is the racing work asked for that day, needs
nothing, and unblocks T23 and T54). Reviewed and merged.

**What landed.** `docs/concepts/racing-ai.md`: how AI drivers are made,
research and shipped games, and rubber-banding for and against with
sources. T23 now names its three knobs from it (lookahead, grip margin,
wander) and its cheat check also refuses a knob that moves during a race
-- the skill-based rubber band shipped games hide. T54 takes PID control,
the heat line for overtaking, and grip measured in a lap.

**Next:** unchanged from wave 53 -- the owner decides ADR 0018; until then
T50-T52 and T54 stay `blocked`. T23 is now ready to build (it needs T21 and
T22; T22 is todo). `make wave` still picks T12 first by table order.

## Resuming after 2026-10-18 (wave 53)

**Where it stopped -- read first.** Wave 53 was documents only, as the owner
asked, and is reviewed and merged. Nothing in it is code. **The owner's
next decision is ADR 0018** (`docs/adr/0018-3d-enters-as-its-own-tier.md`,
*proposed*): where 3D lives (proposed: `godot/game3d/` in the one project),
which tier, how invariant 5 holds, and the assets rule the owner set
(referenced by URL and sha256, never committed, primitives when absent).
Until it is accepted, T50-T52 and T54 are marked `blocked` in the tables
(`next_wave.py` reads only task prerequisites, not an ADR's status, so the
state is what keeps them from being picked); set them back to `todo` when
the owner decides.

**What wave 53 landed.**
- **T49, done**: `docs/concepts/shooter-ai.md`, the survey of shooter AI --
  one bot, bots that cooperate, and the stealth version of the same bots,
  research and shipped games, every reference opened.
- **ADR 0018**, proposed.
- **Tasks**: T50 (the 3D tier, measured first), T51 (a bot-only match),
  T52 (bots against the player, optional stealth) in a new milestone 5;
  T53 (racing survey) and T54 (racing in 3D with physics) in milestone 4.

**Next, once the owner decides ADR 0018:** T50, then T51 or T52 in the
owner's order; T53 (needs nothing) before T23 and T54. If the owner wants
the assets rule applied to the committed 2D art too, that is its own task
(ADR 0018 lists it as a question). If the owner picks another option in the
ADR, T50 is rewritten first.

**Still the owner's, from wave 52:** T48's third change (one blow and one
back); whether T45's and T46's limits are still the right bars.

## Resuming after 2026-10-18 (wave 52)

**Where it stopped -- read first.** Wave 52 is reviewed and merged. The
owner asked for the next wave to start from a cleared context, and for it to
be **wave 53, documents only**, for the owner to review before any code:

1. `make wave-start BRANCH=wave/53-shooters-and-3d` (cut by hand).
2. **An ADR on 3D**, numbered 0018, status *proposed*: ADR 0001 says "no 3D
   lessons; if the kit ever grows them, they are a separate tier with their
   own ADR", and `scripts/check_renderer.py` fails on any 3D node under
   `game/` or `demos/`. Propose how 3D enters -- a separate folder outside
   those two (so the gate still holds for the 2D kit), a hardware tier of
   its own in the README's table, the renderer it needs, and that 3D assets
   are downloaded open packs referenced by URL and sha256, never committed
   (as ADR 0015 does for sprites). The owner decides; write the options.
3. **Tasks**, in `tasks/` and as rows in this file, following T36's pattern
   (survey first, then the example, the player toggling 1-3 techniques the
   survey found worth it):
   - a survey of shooter AI, FPS and third-person, market and academic
     (every source opened before it is cited, as T36 did);
   - a bot-only "multiplayer" shooter: bots autonomous and cooperating, using
     cover, no networking;
   - a single-player shooter with optional stealth for the player, bots
     cooperating against the player;
   - racing in 3D with more complex physics, beside the 2D T22/T23.
   Each task with a command for acceptance and a `## Manual check`.
4. Reviewed and merged like any wave. The owner's memory note
   `next-examples-racing-shooters` has the original request (2026-10-15).

**What wave 52 landed.** T48 in part: two fords at rows 1 and 7; the
planner's domain says `crossing_open`; a threat map by path, drawn and
toggled with T (nothing decides by it yet). T47 holds again: rules' mirror
51-49. The learned side's stuck walkers fell from about 29% to 17-20%.

**Still the owner's:** T48's third change (one blow and one back, retraining
the combat model); and whether T45's 5% stuck limit and T46's limits are
still the right bars.

## Resuming after 2026-10-18 (wave 51)

**What landed.** T47. Blue, moving second, starts with one more shield beside
its workshop; at round 40 the higher score wins (workshop health, then turns
holding points, then what is left standing) and only an equal score is a
draw. `make tactical-win-rates` takes `--pairings` and counts games settled
at the round limit.

**What the measurements said.** The rules' mirror is 59-41 with no draws over
100 games. The learned side now beats the rules 100-0 from both seats, but 61
of those are won on score at the limit -- the reference's caveat, and why the
count is printed.

**Next:** T48, as the owner asked -- a ford and a threat map, with staging on
it. T45's stuck walkers and T46's blue-seat draws are what it is for; the
third option (one blow and one back) waits for the owner, since it retrains
the combat model.

## Resuming after 2026-10-18 (wave 50)

**What landed.** T46, two limits short. The learned blue sets out for a fight
at p(win) 0.5 and gives that same fight up only at 0.3 or below, joins a
fight another walker of its side started within three cells, and retreats
only when red's strength near it outweighs blue's (Wesnoth's caution, this
board's version). C in `make demo-tactical` now cycles blue through the
rules, the planner and the learned policy.

**What the measurements said.** The strength rule is the gain: the learned
side wins 11 of 20 as red (was 4) and 5 as blue (was 1). The commitment makes
no difference on this board, where the way to a fight is one walk. Counted
by distance -- wave 50's review showed reading reasons missed most of them
-- the learned blue reverses direction on 26% of its walks, about as often as
the rules. As blue it still draws 15 of 20, behind the bridge (T45).

**Next:** T47 (the side moving second, and a last round that decides), then
T48 (the ford and the threat map, with staging), as the owner asked.

## Resuming after 2026-10-18 (wave 49)

**What landed.** T45, in part, taken out of table order on the owner's
choice (it is what the planner's idle workshop needed). The rules and the
learned blue spend first, never idle (a fallback at the nearest red piece),
and give each point to one walker a turn; a boxed-in workshop says so and is
asked again after its walkers move. `make tactical-win-rates` takes limits
on stuck walkers and funds left.

**What the measurements said.** The rules' mirror is no longer a first-mover
sweep (12-7-1), and the planner wins 13 of 20 as blue (wave 48: 7); as red
it still loses all 20. T45's own acceptance fails: the learned side's walkers
are stuck 44% and 42% of the time and blue ends with 99 funds. The review
showed half the stuck walkers could move -- a staging rule is the
controller's answer, and the reference wants it built on T48's threat map --
and the rest are boxed in behind the one bridge, while income beats one build
a turn. The numbers and the options are in T45's record.

**Next:** the owner asked to carry on with the design study's proposals
(`docs/design/tactical-references.md` §4) in its order: T46 (the learned
blue commits), T47 (the second player and the last round), then T48 -- a
ford and a threat map, with staging on it, which is where T45's acceptance
can be met.

## Resuming after 2026-10-18 (wave 48)

**What landed.** T11: the planner plays the tactical board. `ai_planning`
gained bits (`PackedDomain`), h_max and h_add (`RelaxedCost`) and A\* with a
budget and partial plans (`HeuristicPlanner`); the tactical domain is PDDL in
`spec/pddl/`, with a JSON twin held equal by `make test-python`;
`TacticalPlanBridge` turns the board into facts and steps into decisions;
`PlannedBlue` decides the purchases -- the forge, then the ram -- and its
walkers take the rules' routes, each naming the step it carries out. C swaps to it in `make demo-tactical`. ADR 0010 amended with the
numbers.

**What the measurements said.** The guesses cut worlds 29-fold and tie each
other (h_max is exact here), so the game uses h_max. The plan decides
purchases only; walkers take the rules' routes. Against the rules, the planner wins 7 of 20 as
blue (rules: 0) and 0 of 20 as red (rules: 20). Its mistakes are legible: it
saves its first turn while the rules build, and after the ram its workshop
idles on a rules refusal (T45's).

**Next:** T44's rest and T45-T48 are still waiting, and T45 is also what the
planner's idle workshop needs. `make wave` picks the first unblocked `todo` in
table order, which is now T12 -- check with the owner before taking it.

## Resuming after 2026-10-17 (wave 47)

**What landed.** T44 in part, then stopped on purpose. The tactical board
has two control points paying their holder, every turn opens in one place
(`TurnStart`), the combat model sees the counter table and was retrained on
a typed dataset, and `LearnedBlue` exists and is tested -- but is not yet a
key in the scene. `make tactical-win-rates` measures the controllers
against each other, with `--at-most` limits a task can use as acceptance.

**What the measurements said.** The rules' mirror: the side moving first
wins 20 of 20. The learned blue: 17-18 draws in 20 against the rules, 160+
funds banked, half its walkers' decisions stuck in a queue at the bridge. The
owner asked for a study of similar games before any more tuning:
[docs/design/tactical-references.md](../docs/design/tactical-references.md)
(Advance Wars, Wargroove, Wesnoth's AI read in its source, influence maps,
Into the Breach), and its ranked adjustments are T45-T48, each with a
measured acceptance.

**Next:** the owner asked for **T11**, the planner, to move the RTS line
forward. Know before starting it: T11's baseline is the rules blue, and in
the rules' mirror the side moving first wins every game -- measure the
planner from both seats. T44's rest and T45-T48 wait behind it.

## Resuming after 2026-10-17 (wave 46)

**What landed.** T26: combat on the tactical board. A fight is dice, the
same rule in Python's dataset and on the board (`spec/combat/rules.json`,
seven hand-checked vectors). Red attacks with a click, blue's rules attack
what they beat, bolt towers fire at their turn's start, and destroying the
enemy workshop wins -- a siege, because a workshop that fell to one attack
ended every game in round 3. The combat model was retrained on the new
rows.

**Not proven.** That the game is now worth playing: T26's manual check.
Rules against rules, red wins 58 of 60, for a reason not yet known.

**Next:** the owner plays three turns of `make demo-tactical` (T26's manual
check), then T44 -- which needs a fifth feature, the counter, and a typed
dataset (T26's step 8) -- then T43.

## Resuming after 2026-10-17 (wave 45)

**What landed.** T42, the fun review (`docs/design/fun-review.md`). The
owner: MENACE, checkers, the search demo and stealth already feel like
games; the skirmish and the tactical board do not. Picked: T26 (combat)
first, then T44 -- the skirmish folded into the tactical board, the learned
policy as one of blue's controllers -- and T43, a fighting ladder.

**Not proven.** That any of the three makes an example one a person wants
to play twice: that is each task's manual check.

**Next:** T26, then T44 (which needs it), then T43. Wave 45's review
reshaped all three -- blue attacks in T26, control points in T44 (the
owner's call), the ladder's order and clock in T43; see its record.

## Resuming after 2026-10-17 (wave 44)

**What landed.** T41, the owner's four reports, each reproduced first. The
"A\* through the mud" was breadth-first's route (the owner's screenshot
said so), and the screen now names what each search's route is the least
of. The start dot is yellow, the goal red, both ringed; the stealth exit is
cyan; `marker_contrast_test.gd` holds them to their tiles. Blue on the
tactical board stopped piling shields behind a bridge red has shut: it
counts red's pieces as walls and builds a wader. The skirmish has a win:
hold a node for 3 of your turns (a draw after 30 rounds), and a blue unit
with no fight to weigh walks at a node red stands on -- a rule beside the
models, said as one. The review's eight findings were all acted on; see
T41's "After the review".

**Not proven.** That the skirmish is now worth playing: the owner's three
games under T41's manual check.

**Next:** the owner plays T41's manual check, then T42.

## Resuming after 2026-10-16 (wave 43)

**What landed.** T40: the backdash -- `FightBackdash`, the O key, bit 512,
`backdash` in the frame data. It is invulnerable for its first quarter,
then cannot guard and can be thrown. Every level of the fixed opponent
backdashes. Hard was retuned by what each option won against the owner's
ghost. `make test-opponent-levels` holds it to 150 of 200 against a frozen
copy of that ghost, and to 130 of 200 against the turtle stand-in it was
not tuned on (as the lancer). The rows, the clone and the win rates were
redone, and no recording has an evade.

**The review's worst finding.** The opponent's answer to a backdash,
"long", could not reach one: seen 15 frames late, the backdash is over
first. It was removed, and step 3's "answer to a player who evades too
often" is **not done** -- T40 says so. See
[docs/reviews/43-an-evade-and-harder-levels.md](../docs/reviews/43-an-evade-and-harder-levels.md)
and T40's "After the review".

**Not proven.** That hard is hard for a person: its bar is a ghost it was
tuned against. That the opponents are now easier to tell apart: it needs
the owner's new fights.

**Next:** the owner plays hard (`make demo-fighting`, M to "opponent:
hard"), records fights with the evade in them (`make record-fights`, `make
train-clone`), and says whether the clone, the ghosts and the learner can
now be told apart (T40's step 5 and its manual check). Then what wave 42
listed: `make check-changed`, the racing and shooter surveys, T41, T42.

## Resuming after 2026-10-15 (wave 42)

**What landed.** T18: behaviour cloning. `make record-fights` keeps each
fight as its input log in `data/fights/` (ADR 0017); Godot replays them
and cuts one row per decision, the situation as six words as of 15 frames
before (`FightSituation`, `FightRecording`); `gameaikit.cloning` splits by
recording, fits a softmax and counts a ghost, and publishes
`ai_learning/clone_weights.json`, read by `ClonedPlayer`, `SoftmaxModel`
and `CaseTable`. The fighting demo has *ghost: exact*, *ghost: nearest* and
*clone* modes. `compare.py --report` is the comparison. Trained on the
owner's nine fights; the stand-ins stay as the contrast.

**The answer.** Over every recording held out once, nothing fitted
beforehand guesses the owner better than "always step in"; T17's n-gram
does, by four points. The ghosts make the better opponents. The owner could
not tell any of them apart, and suspects the moveset -- T40.

**The review's worst finding.** The clone was asked with the option it drew
as its `last`, where the rows hold what its fighter was seen doing: 28% of
its decisions. Fixed, tested over a whole fight, and the n-gram is now
scored as late as the models; the numbers changed and the page says the
first reading was wrong. See
[docs/reviews/42-behaviour-cloning.md](../docs/reviews/42-behaviour-cloning.md).

**Not proven.** Anything about people beyond one owner and nine fights. The
clone still decides more often than the player did.

**Next:** the owner asked for, after T18: `make check-changed` (only the
gates a change can reach); T40, an evade; then survey-first tasks for
racing (2D, and 3D with richer physics) and two shooters with bots -- a
bot-only match and a single-player one with optional stealth; 3D needs an
ADR against ADR 0001's no-3D rule first, and 3D assets are
referenced, never committed.

**Also noted, 2026-10-15:** the owner played the board demos and found
four problems (T41) and asked for more playful examples (T42). Not
scheduled yet; the owner said "for later".

## Resuming after 2026-10-15 (wave 41)

**What landed.** T17: the opponent model. `ai_opponent`, a new addon,
holds `NGramPredictor` -- what the player did after the last `order - 1`
actions, smoothed and decaying -- and `gameaikit.ngram` is its Python copy,
four vectors from `derive.py` holding both. The learner is T37's opponent
with the table behind it, watching the late fight `FightDelay` hands it and
leaning its level's options towards the answer to what it expects. ADR 0016
is the owner's exception to invariant 6: the table counts during one fight,
starts empty, and is never written down (N9). The training mode has three
learner modes, the table on the panel.

**The review's worst findings.** The lean was measured against certainty,
which a decaying table never reaches, so it never passed 2 of its 8; now
against the predictor's ceiling. "Starts empty every fight" had no test;
now `new_fight`, tested. Easy and medium often have no answer to lean
towards, and say so. All fixed; see
[docs/reviews/41-the-opponent-model.md](../docs/reviews/41-the-opponent-model.md).

**Not proven.** T17's manual check -- feel it punish a habit, then adapt --
with T34's, T35's, T37's, T38's and T39's. Whether the rescaled lean makes
the learner beat the fixed opponent more often was not measured again.

**Next:** T18, behaviour cloning, and what a learned model buys -- the n-gram, a ghost and a trained model, compared.

## Resuming after 2026-10-15 (wave 40)

**What landed.** T38: the jump. Up takes off over `takeoff` frames on the
ground, flies an arc of whole units, and lands; in the air a fighter cannot
guard or be thrown, and has one air move a jump -- an attack on every
button, all overheads. A box is two intervals now, and a high passes over a
crouch because it is above it: the special rule went, and the recorded
fight did not change. An uppercut per character is the anti-air. From the
owner playing it: air attacks on every button, and jumps that cross over --
a guard is held back from the way the strike travels, so a cross-up is
guarded the other way.

**The review's worst findings.** Two passes. Up on the frame a throw
arrived escaped it, and landing could not be thrown: take-off frames now,
and landing is throwable. A fighter knocked out of the air could kick again.
Two fighters on one spot blocked whichever way they held. All fixed; see
[docs/reviews/40-the-jump.md](../docs/reviews/40-the-jump.md).

**Not proven.** T38's manual check, with T34's, T35's, T37's and T39's.

**Next:** T17, the opponent model, with ADR 0016.

## Resuming after 2026-10-15 (wave 39)

**What landed.** T37: `FightOpponent`, a fixed opponent with five situations
and three levels, written as knobs -- reaction (30, 22, 15 frames), tactics,
execution. `FightDelay` seats it and hands it a copy of the fight its
reaction time old, never sooner than 15 frames. `make test-opponent-levels`
plays 600 mirror fights: each level beats the one below it 93 to 99 times
in 100, and a level against itself stays under 60. The training mode opens
on the medium opponent; the panel shows what it saw, on which frame, and
what it drew.

**The review's worst findings.** The header said hard "sees the same fight";
it sees it sooner, and now says so, with how much of its edge is the deciding.
The manual check promised something no level could pass. The seat copied
only at hand-over, so a caller stepping one state in place could show the
opponent the present. All fixed, with four untested paths; see
[docs/reviews/39-a-fixed-opponent-three-honest-levels.md](../docs/reviews/39-a-fixed-opponent-three-honest-levels.md).

**Not proven.** T37's manual check, with T34's, T35's and T39's.

**Next:** T38, the jump.

## Resuming after 2026-10-15 (wave 38)

**What landed.** T36: `docs/concepts/fighting-game-ai.md`, a survey of
fighting-game AI from the research arena and from shipped games, with what
could not be checked listed apart. T37, T17 and T18 rewritten from it.

**The review's worst findings.** Three claims stronger than their sources:
the ghost papers do exact lookup, not nearest neighbour; Tekken's method is
unpublished; an opponent model came second in 2019, not first. All fixed,
with ten more; see
[docs/reviews/38-how-fighting-game-ai-is-made.md](../docs/reviews/38-how-fighting-game-ai-is-made.md).

**Next:** T37, a fixed opponent at three honest levels: hand-written
reactions by situation, reaction of at least 15 frames, tactics and
execution as knobs, handed only the past.

## Resuming after 2026-10-15 (wave 37)

**What landed.** T39, from the owner playing T34: standing punches and the
dancer's roundhouse are high and pass over a crouch; the light kicks were
recut as side kicks to the waist and stay mid; the axe kick stays an
overhead. Hitstun is taken standing, so a combo cannot be ducked halfway.
A pass-over is an event the panel shows.

**The review's worst finding.** A fighter in hitstun could duck the second
hit of a combo by holding down. Fixed; see
[docs/reviews/37-high-punches-pass-over-a-crouch.md](../docs/reviews/37-high-punches-pass-over-a-crouch.md).

**Not proven.** T39's manual check, with T34's and T35's.

**Next:** T36, the survey of fighting-game AI. Its draft, from the references
opened in wave 36, is ready to go in as `docs/concepts/fighting-game-ai.md`.

## Resuming after 2026-10-15 (wave 36)

**What landed.** T35: the fighters have faces.
- Puffolotti's CC0 karate template, two costumes: the lancer orange at full
  size, the dancer blue at 80%, each move its own cels.
- Only the cuts are committed -- 30 strips of whole grid cells -- and the
  sheets are referenced by URL and sha256 (ADR 0015). `make fighter-sheets`
  and `make fighter-strips` repeat the cut, byte for byte.
- `FighterSprites.pose` picks a cel from the fight alone: a move's cels by
  phase, the walk from the fighter's own input, the hit from its stun.

**The review's worst findings.** The ADR quoted the author from the wrong
page and paraphrased him; it now quotes him exactly, from the page he wrote
it on. The walk read the view's redraws, not the fight, so the frame step
showed a walking fighter standing. Both fixed, with the rest; see
[docs/reviews/36-fighters-you-can-see.md](../docs/reviews/36-fighters-you-can-see.md).

**Not proven.** T34's and T35's manual checks: play it. The walk speed and
the hit animation want a person's eye.

**Next:** T36, the survey of fighting-game AI. A draft written from 28
references opened during wave 36 is the starting point.

## Resuming after 2026-10-15 (wave 35)

**What landed.** T34: high, low and the throw.
- Four attack buttons -- U/I punch, J/K kick, light quick and heavy slow --
  a throw on L, and S to crouch.
- Every move has a stance and a height. Standing guard stops mid and
  overhead, crouching guard mid and low, and nothing stops a throw. A
  strike beats a throw on the same frame, two throws break each other, and
  a throw never catches a fighter in stun.
- The recorded log must now cause a low and an overhead through the wrong
  guard, and a throw.
- Tasks written: T35 sprites, T36 the fighting-AI survey, T37 a fixed
  opponent at three honest levels, T38 the jump. T17 now waits on T37.

**The review's worst findings.** Six of the new rules had no test that
would notice them breaking (throws into stun, the clash, a cancel into a
crouching move, validation, the dummy), and the strike-beats-throw event
ran off the panel. All fixed; the ten surviving mutations are killed. See
[docs/reviews/35-high-low-and-the-throw.md](../docs/reviews/35-high-low-and-the-throw.md).

**Not proven.** T34's manual check: each guard against the dummy, by hand.

**Next:** T35, fighters you can see. The owner's rule: commit only the
cropped frames, never the downloaded sheets; the ADR keeps the URLs and
sha256s. The candidate found is Puffolotti's CC0 karate template
(OpenGameArt node 97941), two palettes of the same 997 cels.

## Resuming after 2026-10-14 (wave 34)

**What landed.** T16: the fighting scenario, with no AI yet.
- Two characters on one axis: the lancer has reach and starts slowly; the
  dancer is quick and short.
- Every number is in `spec/frames/characters.json`. The game reads a copy,
  held byte for byte. The order a frame resolves in is written there and
  followed step by step in `FightRules`: the buffer, acting, separation,
  every box tested at once, block or hit, counter-hit, trade, pushback,
  knockout.
- The engine uses whole numbers and an immutable state per frame. A
  recorded log (`godot/test/fighting/fight_log.json`) must replay to the per-frame
  digests committed beside it, and to the same digests twice. `make
  record-replay` rewrites them after a deliberate change.
- `make demo-fighting` is a training mode: you against a dummy that stands,
  blocks or jabs, every box drawn, and space steps one frame.

**The review's worst findings.**
- The determinism check could not see player two, or anything fixed for the
  life of a process.
- Half the resolution order had no test.
- The separation favoured the right-hand side.

All are fixed, and the 17 surviving mutations re-run are now killed. See
[docs/reviews/34-the-fighting-scenario.md](../docs/reviews/34-the-fighting-scenario.md).

**Not proven.** T16's manual check: play both characters against the dummy.
Moves should come out when asked, and a trade should resolve as the table
says.

**Next:** `make wave` cuts the next ready row. T17, the opponent model,
starts by reading `spec/frames/` from Python.

## Resuming after 2026-10-14 (wave 33)

**What landed.** T32: checkers with a learned evaluation, after Samuel.
- The rules and alpha-beta are in Python too. `spec/vectors/checkers/`
  holds the two languages to the same legal moves, crowns, captures and
  draws, and to the same counts and scores. A review cross-checked them on
  20,259 positions.
- Self-play: 400 games from seeded random openings, one ply deep, 394 of
  them distinct. A logistic fit on the decisive games used T5's trainer. The
  match, four shuffled-label controls and an ablation are all published in
  `godot/game/checkers/checkers_weights.json`. N7 retrains them all, which
  takes about two minutes; N8 refuses a write.
- In `make run`, E switches white's evaluation. The panel breaks the chosen
  value down by count under both sets of weights.

**The result is negative, and the page says why as far as it is measured.**
- The learned weights score 0.52 at one ply and 0.125 at two.
- With their advancement weight set to zero they score 0.53: under the
  fit, a man three rows up is worth less than nothing.
- The controls cannot be told apart from the learned weights. Alpha-beta
  ignores the scale of the weights, so a fit to noise is a random direction.
  The review found this; the concept page now says it.
- See [docs/concepts/learned-evaluation.md](../docs/concepts/learned-evaluation.md)
  and [the review](../docs/reviews/33-checkers-with-a-learned-evaluation.md).

**Not proven.** T32's manual check: toggle E on one position and name the
count the two evaluations weigh differently.

**Next:** `make wave` cuts T16, the fighting scenario.

## Resuming after 2026-10-14 (wave 32)

**What landed.** T33: the units on the tactical and skirmish boards walk.
- The shield and the soldier are Puny Characters figures (Shade,
  OpenGameArt, CC0). They march on the spot, walk their route at 0.12 s a
  cell facing each step, and stand still, greyed, once spent.
- The machines keep their pictures and bob as they roll. The buildings stay
  still.
- Blue's unit walks the route its pink line showed. Undo and a new game
  drop the walks.
- `UnitSheet` is the frame table, `UnitWalk` one trip along a route, and
  `UnitView` one clock that only `advance` moves. ADR 0014.
- The generator gained a `walk` kind on FLUX.2 klein base with the svntax
  LoRA. Its sheets stay in the gitignored folder and are never committed:
  the LoRA's training data is CC BY 4.0. A plain `make artgen` leaves them
  out; the how-to says how to make them. Four were made and look right.

**The review's worst findings.**
- The legends still showed the old silhouettes.
- A plain `make artgen` broke for anyone without the walk model.
- A new game kept the old game's facings.
- 9 of 30 mutations survived.

All are fixed. 12 mutations were re-run and every one is now killed; one,
a swap of Puny's left and right rows, is checked only by eye. See
[docs/reviews/32-units-that-walk.md](../docs/reviews/32-units-that-walk.md).

**Not proven.** T33's manual check: the owner plays `make demo-tactical`
and says whether walking units read better than still ones.

**Next:** `make wave` cuts T32, checkers with a learned evaluation.

## Resuming after 2026-10-14 (wave 30)

**What landed.** T9: the games draw pictures, not coloured squares.
- Thirty CC0 pictures from four Kenney packs:
  - the tactical game: five silhouettes for the kinds that walk, three
    buildings, a red and a blue copy of each;
  - checkers: chips, and a crown on a king;
  - noughts and crosses: an X and an O.
- Each file is the pack's own, byte for byte. `godot/assets/LICENCES.md`
  lists it by path, with its pack, CC0 1.0 and its sha256.
- `godot/game/art.gd` is the only code that names a path. Trees are a tile
  of their own now, and the legends show the pictures.
- ADR 0012 records the reversal of "no binary art", and the tier argument.

**Measured on the way**, in
[docs/godot/importing-art.md](../docs/godot/importing-art.md):
- a run imports nothing, so `make import` precedes every target that starts
  the engine, CI included;
- a texture loaded in `_draw` and let go draws as a white square, so `Art`
  keeps what it loads;
- a picture that fails to import poisons its committed `.import`, so
  `make import` fails on it and says how to recover.

**The review's worst findings.**
- T31's plan, "same paths, gitignored", could not work, and the gate would
  have credited generated art to Kenney. Rows now carry sha256s, and T31
  writes to a gitignored folder of its own.
- Nothing tested which picture a unit was drawn with.
- The licence rule took any licence and a row with a cell missing.

All are fixed. 29 of the 42 engine mutations had survived; every one that
is not visual is now caught. See
[docs/reviews/30-art-that-is-not-a-coloured-square.md](../docs/reviews/30-art-that-is-not-a-coloured-square.md).

**Not proven.** T9's manual check: someone who does not know which is
which looks at screenshots. The tactical sides differ by colour only, as in
the pack, and the checkers board is still two flat colours.

**Next:** `make wave` cuts T31. The owner added a test to its bake-off: a
12-frame walk cycle of one unit.

## Resuming after 2026-10-14 (wave 29)

**What landed.** T30: `make demo-tactical` replaces `play-tactical`. You play
red against the computer, with turns in the style of Advance Wars:
- click a unit and its reach lights up; click a lit cell and it walks and
  greys out. The next unit that can still move is put in your hand;
- W waits, Z (or the button) takes back anything done this turn, and ending
  the turn asks first while units are unspent;
- blue is whichever `BlueController` the scene is given. Today that is
  `RuleBasedBlue`: it builds what beats the most red pieces and walks every
  unit at red's workshop;
- each decision is drawn in pink with its reason before space plays it, and
  enter plays the rest of the turn;
- a unit beside the enemy workshop at the start of its side's turn wins
  (provisional until T26). After 40 rounds the game is a draw.

**For the owner: one rule differs from the task file.** T30 says blue
"walks each unit at the nearest enemy". The review measured that it never
wins: the nearest enemy is a bolt tower, and after 60 rounds blue had thirty
shields round it. Blue now walks at red's workshop, and beats a red that
only waits in round 5. The draw is also new. Both are noted in the task
file. Change them back if the original rule was the point.

**The review's worst findings.**
- Blue could not win.
- Nothing held that red's units come fresh at red's next turn.
- After the game ended, blue's next move was still drawn.
- The first click on the unit already in hand spent it.

All are fixed, and the 15 mutations behind them re-run red but one. That
one is a guard made redundant, so it was removed. See
[docs/reviews/29-the-tactical-game-against-the-computer.md](../docs/reviews/29-the-tactical-game-against-the-computer.md).

**Not proven.** T30's manual check: play a game reading only the screen.

**Next:** `make wave` cuts the next ready row.

## Resuming after 2026-10-14 (wave 28)

**What landed.** T29: `make demo-search` is a board you can paint.
- Left-drag paints wall, mud or open ground (W, M, G), right-drag erases,
  the two dots drag, and - and = price the mud.
- Every change searches again, all four, from nothing. A goal walled off is
  "no route", with the region each search explored still on screen.
- B steps through four boards, drawn as text in `search_board.gd`: wall and
  mud, a perfect maze, an open field, and a trap for depth-first. Each
  carries its lesson as a sentence and a check. Once edited, the screen says
  whether the lesson still holds.

**The review's worst finding.** The mouse, which is what the task was for,
had no test. Four mutations to it survived. It is `pointer(event, cell)` now,
driven by constructed events, and a fast drag no longer leaves gaps. See
[docs/reviews/28-a-search-board-you-can-edit.md](../docs/reviews/28-a-search-board-you-can-edit.md).

**Not proven.** T29's manual check: somebody who has not read the code
builds a maze in under a minute and says why depth-first wandered.

**Next:** `make wave` cuts T30, the tactical game against the computer.

## Resuming after 2026-10-14 (wave 27)

**What landed.** T28: `make demo-tictactoe`, noughts and crosses against
MENACE, Donald Michie's 1961 matchbox machine.
- MENACE trains in Python with the standard library only:
  - 304 boxes, 1 + 12 + 108 + 183, with Michie's beads and rewards;
  - 5,000 games against a random player, then 5,000 against a perfect one;
  - four ages published in `godot/game/tictactoe/menace_beads.json`.
- The game only draws. Each empty square shows its beads and their chance,
  the panel numbers every bead, and M shows what perfect play makes of each
  square.
- Invariant 6 now covers beads:
  - N5 is a net for bead writes in GDScript;
  - N6 trains again and compares with the published file;
  - the store is read-only in the engine, which is the actual guarantee.
- `spec/vectors/menace/` carries the uniform draw itself, because the two
  languages' random generators differ.

**The criterion changed, by the owner's choice.** Michie's rules never stop
losing to a random player: they lock in a move that wins three in four over
one that wins every time. The tests hold the published seed against the
perfect player instead. Over ten seeds, the vs-perfect claim holds on nine;
on the tenth a box drains and MENACE resigns. `python3 -m
gameaikit.menace.report --seeds 10` prints the table, and the concept page
quotes it.

**The review's worst findings.**
- N5 missed the real bead store, which the engine's read-only store now
  closes.
- The new criterion had been measured on one seed.
- The panel's draw could not be checked against its own list.

All are fixed; see
[docs/reviews/27-tic-tac-toe-and-menace.md](../docs/reviews/27-tic-tac-toe-and-menace.md).

**Not proven.** T28's manual check: play the 10-game machine and then the
10,000-game one, and feel the difference.

**Next:** `make wave` cuts T29, a search board you can edit.

## Resuming after 2026-10-14 (wave 26)

**What landed.** T27: `make run` is checkers, red against the computer.
- `ai_adversarial` holds minimax and alpha-beta, after Russell & Norvig
  chapter 5. A root move that alpha-beta cut short is marked a bound
  ("≤ x"), and only when something below it was actually cut.
- `godot/game/checkers/` holds the English draughts rules with their source,
  the hand-written evaluation T32 will replace, and the scene.
- White draws every move it considered with its value, a pink arrow on the
  one it will play, and the line of play it expects. Space plays it; 1-6 set
  the depth.
- A multi-jump is played one hop per click, which is also how a person picks
  between two jumps to the same square.
- The old board is `make demo-skirmish`.

**The review's worst findings.** A king's capture back to its own square
locked the game, a bound read as "wins", and eleven of nineteen mutations
survived the suite. All are fixed and re-run; see
[docs/reviews/26-checkers-and-minimax.md](../docs/reviews/26-checkers-and-minimax.md).

**Left open, on purpose.**
- The search runs in the frame: depth 6 measured up to ~730 ms with kings.
- Wins are not depth-adjusted, and with a big lead white can shuffle into
  the 40-move draw. The status counts down to it, and the concept page
  calls it the horizon.

**Not proven.** T27's manual check, by somebody who knows checkers and has
not read the code.

**Next:** `make wave` cuts T28, tic-tac-toe with MENACE.

## Resuming after 2026-10-13 (tasks: games people already know)

**Why the plan changed.** The owner played `make run`, `make demo-search` and
`make play-tactical`. They could not tell what game each one was, or what
the AI was doing in it. They also found clicking pieces one step at a time,
and two people at one mouse, painful. That is the manual check doing its
job. The answer is to build every example on a game people already know,
against the computer, and to say the technique on screen.

**New tasks, in order:**
- T27: checkers with minimax and alpha-beta, as the new `make run`.
- T28: tic-tac-toe with MENACE.
- T29: a search board you can edit.
- T30: the tactical game against a rule-based computer, with Advance Wars
  style turns.
- T9: CC0 art for those games.
- T31: generate your own art with a local model, downloaded separately and
  fenced off from every lesson. Each user generates their own art, which
  git ignores; the repository keeps CC0 art as the default and a few
  generated examples.
- T32: a learned checkers evaluation, after Samuel.

**What is not lost.** The logistic-regression policy in today's `make run`
becomes `demo-skirmish` in T27. T30 makes blue on the tactical board a
controller chosen among several (rules, planner, learned), which is where
that policy can play once T26 gives it a real combat.

**Next:** `make wave` cuts T27.

## Resuming after 2026-10-13 (wave 25)

**The order changed.** T9 (art) was next, and it asks for five unit types
to be five silhouettes, but there were no unit types. The owner chose to do
T10 first. T9 now depends on T10, and `make wave` agrees.

**What landed.** T10, the tactical scenario, played with
`make play-tactical`:
- `ai_core` has `UnitType`, `Upgrade` and `ProductionOrder`, and
  `BoardState` holds funds, upgrades and a cost map per kind of mover.
- Five types in a counter cycle, a bolt tower, a watchtower, a workshop and
  a forge.
- A river with one bridge. Only the wader crosses water.
- The highlight shows everywhere a piece can walk this turn
  (`TacticalReach`).

It is not `demo-*`, because nothing in it decides yet. T11 gives one side to
the planner and renames it.

**Combat is not in it.** ADR 0008 says the dataset must be rebuilt from the
game's combat once it exists. That is T26, a new task, and T11 now depends
on it.

**The review's worst finding.** Out of funds, a build said the workshop had
no room. Three tests did not hold what they were named for: the cycle, the
"only" bridge, and what a wader pays. They do now. See
[docs/reviews/25-the-tactical-scenario.md](../docs/reviews/25-the-tactical-scenario.md).

**Not proven.** T10's manual check, by a person. The play review passed it
for terrain and said type feel waits on T26. The fixes were not re-reviewed.

## Resuming after 2026-10-13 (wave 24)

**What landed.** T8, the five measured defects on the board:
- 48 px tiles, and the board centred in the window the project asks for;
- a palette that separates by brightness as well as hue, and grid lines;
- the cost written on any dear cell;
- the reachable highlight drawn *over* the terrain;
- the status beside the board, saying what is in hand and what to do.

On top of that, column and row numbers, so every `(column, row)` in a
refusal can be found. The search demo shows cells expanded and route cost
for all four algorithms at once.

**Measured on the way.** A `TileMapLayer` paints its tiles over its own
`_draw`, and the headless root viewport is 100x100. Both are in
[docs/godot/drawing-over-tiles.md](../docs/godot/drawing-over-tiles.md),
with how to take a screenshot when a display exists.

**The review's worst finding.** On blue's turn the board ringed one unit
while the status named another. Blue now has nothing in hand. The overlay
could also be deleted with every test green; it is data now, and held. See
[docs/reviews/24-a-board-you-can-read.md](../docs/reviews/24-a-board-you-can-read.md).

**Left for later, on purpose.**
- "attacks" with no combat model belongs to T10.
- The typed positions of the search and stealth scenes, and stealth's 32 px
  guard markers, belong to T24.

**Not proven.** T8's manual check: hand `make run` and `make demo-search` to
somebody who has not read the code. The fixes were not re-reviewed.

## Resuming after 2026-10-13 (wave 23)

**What landed.** T21. Invariant 13 has a gate in two halves:
- `make lint-demos` holds the structure: a target that opens a window, a
  legend, and `step_decision()` and `decision_overlay()`.
- `make test-demo-overlays` steps every example headless. It fails on an
  engine error, on an overlay that does not change, on an empty field or a
  missing required field, and on a legend that says nothing or runs off the
  screen.

Every rule in both halves first rejects a planted case. The convention is in
[docs/godot/examples.md](../docs/godot/examples.md).

**The board itself failed the task.** Blue decided and played its whole
turn on one press, so the decision was never on screen before it happened.
It now plays one decision per press, drawn first. The gate had passed it,
because it accepted a full overlay without asking whether it ever changed.
See [docs/reviews/23-every-example-can-be-watched.md](../docs/reviews/23-every-example-can-be-watched.md).

**For the owner.** `CLAUDE.md`'s invariant table still says invariant 13 has
no gate. That file is yours, so it was left alone.

**Not proven.** Whether a person can read each example is the manual check.
The fixes were not re-reviewed.

## Resuming after 2026-10-13 (wave 22)

**What landed.** T14.
- `godot/addons/ai_perception/` sees, hears and keeps an influence map. Its
  line of sight is Bresenham's, drawn from one fixed end, which makes it
  symmetric. It does not slip between walls meeting at a corner, and trees
  block sight as well as costing movement.
- `godot/game/stealth/` puts it to work. Suspicion is a fuzzy controller on
  `ai_fuzzy` that never falls while the player is in sight. Guards have
  three states with hysteresis, and walk A* routes around each other.
- `make demo-stealth` draws each guard's cone, its suspicion bar chasing the
  controller's target, its next steps and where it thinks you are. It also
  writes out every input and term.
- The acceptance, `make test-perception-properties`, checks four properties
  over 300 maps, plus the line against geometry.

**Playing it found what mutating could not.** A guard that reached the
player turned its back. The cone on screen was not the cone that decided.
Two guards head on spun forever. All three were legal moves and wrong
behaviour, and each now has a test. **A reviewer driving the game turn by
turn is worth asking for again.** See
[docs/reviews/22-the-stealth-scenario.md](../docs/reviews/22-the-stealth-scenario.md).

**Not proven.** Whether the suspicion bar reads as a decision is the manual
check, and a person's. The default room is honest but not hard. The fixes
were not re-reviewed by a fresh context.

**Next.** `make wave` picks the next ready row. Two reviewers in one checkout
interfered with each other this wave, so give each its own worktree.

## Resuming after 2026-10-13 (wave 21)

**What landed.** T13: `godot/addons/ai_fuzzy/` holds membership (one
trapezoid, of which a triangle and a shoulder are special cases), a rule base
(AND is min, OR is max, and each term takes its strongest rule), and the
centroid, sampled at points the controller itself declares.
`python/gameaikit/fuzzy/` holds the same three steps, a reader for the old
library's text format, and `python -m gameaikit.fuzzy.plot`, which draws a
controller's curve in the terminal for the manual check.
`spec/vectors/fuzzy/` holds three vectors, computed in exact fractions by a
script that imports nothing from the repository. They include the case T13
asks for: two overlapping rules land strictly between what each gives alone.

**The task's premise was wrong, and the code was written rather than
ported.** The "Python library" is C#, and the class doing fuzzification,
inference and defuzzification is not in its repository. ADR 0011 records
what carried over (the shapes, AND/OR rules, the centroid, the `FLC.txt`
format) and what did not. Review then found that the ADR itself had three
claims about the old code wrong. **A description of someone else's code
needs checking against the code**, the same lesson wave 20 learned about
sources.

**Twenty-two review findings**, in
[docs/reviews/21-ai-fuzzy.md](../docs/reviews/21-ai-fuzzy.md). The worst:
- a malformed vector made the runner skip the strictly-between claim and
  still exit 0;
- GDScript answered a NaN input with a confident 50.0, where Python divided
  by zero.

Both are fixed. Every survivor both reviewers reported was re-run as a
mutation against its fix: 19 in GDScript, 24 in Python. **The fixes were
not reviewed by a fresh context.**

**Not proven.** The manual check is a person's: plot the guard and look at
the curve (the command is in the review record). A slope test holds the half
a command can. Nothing is profiled.

**Still open, and carried forward.** Everything wave 20 listed, including the
sequencing question. `make wave` will pick the next ready row; T14, the
stealth scenario, is the one that consumes `ai_fuzzy`, and T21 (every
example can be watched) is still listed after it.

Read the task file `make wave` names, then: make check, write the review
record, make wave-merge.

## Resuming after 2026-10-13 (wave 20)

**What landed.** A mini wave of research and planning, with no code.
[How strategy games plan](../docs/concepts/planning-in-strategy-games.md)
gathers twenty-four sources, shipped games and research, with every
quotation checked against its text. ADR 0010 is **proposed**: the RTS enemy
plans at the strategic layer only, with a heuristic, a budget per call and a
cadence, over a priority-queue economy. T11 and T20 are to measure it. New
tasks: **T24**, one window that opens every example, with a card naming each
one's techniques, and an exported executable; and **T25**, a league of one team
per technique, scored separately on strength and on how human it plays,
with a live cost and efficiency meter. T20 now opens with **the minimum RTS**,
built backwards from what each AI needs to decide, and T19 with the
simulation the league depends on.

**The research corrected its own first reading.** The page first said
strategy games "plan only at the top". Killzone 3's bots and squads plan with
HTN, and F.E.A.R. planned per soldier. What the sources support is that
nobody plans the whole game in one search. Planning at the top only is this
kit's choice for an RTS, and is now said as one. **A summary of sources
needs reviewing against the sources as much as code does against its
tests.**

**The answer to "PDDL or STRIPS, which is faster" is that the question is
wrong.** PDDL is the language and STRIPS the model it describes. Speed comes
from which layer plans, over how small a problem, with what search, and how
often.

**Not proven.** Everything in ADR 0010 is a reading of other people's games
until T11's benchmark and T20's match produce numbers. The third round of
this wave's fixes was not reviewed again.

**Still open, and carried forward.** Everything wave 19 listed. Also the
sequencing question, now bigger: `make wave` picks **T13**, while T21 says it
comes before T8, and T24 (which needs T21) and T25 are where the owner's
latest requests live. If they should come sooner, move their rows up.

Read the task file `make wave` names, then: make check, write the review
record, make wave-merge.

## Resuming after 2026-10-13 (wave 19)

**What landed.** T7, and with it milestone 1. Planning and learning have a
concept page at tier 1 and a Godot page at tier 2 each, search has both too,
and `check_tiers.py` sees all three lessons now and goes red when a tier-1 page
is removed. Every snippet on the Godot pages was run on 4.7.2 and shows what
it printed. ADRs 0006-0009 record four decisions that had lived only in task
files and comments. The README says which addons `make run` uses, and no
longer lists `ai_llm`, which has no code and no task, as if it shipped.
`make release` builds one zip per addon and a wheel written by hand, from
HEAD, byte-for-byte reproducible. `check_license.py` opens every one of them
and compares the attribution with what HEAD holds.

**The release took three review rounds, and each found that the last fix had
been tested in one place.** The first draft shipped the working tree: it
listed tracked paths and read the bytes off disk. The fix's self-test planted
strays in one addon and opened one zip, so reading the wheel or the
attribution off disk still passed it. The content check written next built its
expectation with the build's own helpers, so a defect one function down agreed
with itself. **A check is only as independent as the code it does not
share.** It reads HEAD through `git archive` now. Every mutation a reviewer
reported surviving was re-run against its fix, in sweeps of 26, 22 and 10
mutations that also cover each new rule. Two survive, and neither is a hole. See
[the review](../docs/reviews/19-close-the-slice.md).

**The third round's fixes were not reviewed by a fourth context.** They were
checked by planting each mutation the reviewer described and watching it go
red. Worth a fresh pair of eyes before the release is used for real.

**A header two reviews had passed was teaching the wrong cause.** `dijkstra.gd`
said it never improves a cell because its frontier is a linear scan, and that
a binary heap would bring the improvements back. The real reason is that a
cost belongs to the cell *entered*. A heap on these costs makes 0
improvements over 300 boards, and 1674 once the cost is charged per edge.
`docs/concepts/cost_models.py` prints both. The wave 08 section below still
carries the old claim, as a dated record should.

**Two numbers had no command behind them**, and one moved when it got one:
1533 became 1674 because the draw order changed. **A sentence copied from a
docstring is only as true as the docstring.** The terrain rule went from
`combat.py`'s docstring, which contradicts its own code, into a concept page
and an ADR.

**Not proven.** The manual check is a person's: hand the README to someone who
has never opened Godot, and record the game and the search demo. No command
can, because `--headless` rasterises nothing, and the README has a marked
place for both recordings.

**Still open, and carried forward.** The eleven over-long addon headers from
wave 07 still wait on the owner. The `doc-meta` blocks in
`spec/vectors/*/README.md` still declare a `half_life` the docs gate does not
know. Nothing enforces a line width, and `check_readability.py` does not
measure `scripts/` at all, where `check_license.py`'s `self_test` is over 300
lines. The search and planning vector runners still use the noisy JSON parser.
The Godot pages cite `/en/stable/` docs rather than the pinned version's, as
every page here does.

**A sequencing question for the owner.** `make wave` now picks **T13**,
because it takes the first ready row in the table and T21 is listed last in
milestone 2, although its note says it comes **before T8**. If T21 should come
next, move its row up. This session did not reorder the plan.

Read the task file `make wave` names, then: make check, write the review
record, make wave-merge.

## Resuming after 2026-10-13 (wave 18)

**What landed.** T6: `godot/addons/ai_learning/` loads the weights Python
published and does nothing but infer. `LearnedModel` is `w·x + b` and a
sigmoid; `ModelFile` refuses a malformed file in one sentence with a code and
hands back *no* models rather than half of one; `BoardFeatures` reads the four
combat and four capture features off a live `BoardState`; `LearnedPolicy`
compares one probability against one threshold and takes the lower of two
predicted capture times. Blue in `make run` is played by it and says on screen
what it decided and the number it decided on. `check_no_training.py` gives
invariant 6 the gate it has never had, and `spec/vectors/learning/` holds the
two languages to the same rows and the same arithmetic.

**Two of the four combat features cannot be computed from a board.** How near
counts as near, and what a unit with no living friends reports -- and the
second is the *training* board's width, so a game helpfully reporting its own
would say "far" where the data said "nobody is coming". They are published in
`weights.json` now, with the range of terrain the data covered, and the game
reads them rather than keeping a copy. A number two languages must agree on,
living in two files, is a number that will one day differ.

**The bug worth remembering is the one no vector could have caught.**
`_nearest_friend` seeded its search with the sentinel instead of falling back
on it, so "I am alone" and "my nearest friend is seventeen away" were the same
number. The two board-carrying vectors are 5x4 and 6x4 -- longest distance 8,
sentinel 15 -- and the board `make run` ships is 12x8, where it reaches 18.
**A conformance vector only tests the range its board can reach.** There is a
fourth vector now, on a board twenty wide, and it goes red against the old
code.

**The sentinel is clean by luck, not by design.** Over the 2937 training rows
the real distances run 1 to 11 and none reaches 15 -- but the simulator's
geometry permits 16. Worth knowing before T18 leans on that feature.

**Twenty-one rules were deletable with every gate green**, found by two
reviews deleting them one at a time: the whole of `_affordable` (the only
thing making every returned move legal -- no test had ever produced a route
the unit could not pay for), four tie-breaks and boundaries, four board rules
in the vector loader, two of `ModelFile`'s refusals, three of the four ways
the gate recognises a file being written, eight of its ten forbidden words,
and its vendored-code exclusion.

Each has a case now, and **each case was then run against the mutation that
motivated it** rather than assumed to work. That caught three failures in the
fixes themselves: one case was hidden behind an earlier failure in the same
suite (the gdUnit4 trap `CLAUDE.md` warns about); two were passing through a
*different* rule, because eleven board rules all answer the code `V7` and
`contains("V7")` cannot tell them apart; and the planted case for
`open_encrypted` contained `FileAccess.WRITE`, so the alternative next door
was catching it.

**A planted case written as a loop over the rule list cannot notice the list
shrinking.** Planting one case per forbidden word by iterating the vocabulary
proves every word fires and goes green the moment a word is deleted, because
the loop shrinks with it. Both are needed: the literal list catches the
deletion, the loop catches an entry that does not work -- and the loop earned
its place immediately, catching a planted `gradient_value` that
`\bgradient\b` never matched.

**T6's headline acceptance command proves less than it reads like.** The three
decision scenarios stayed green under all five mutations of the feature
extraction. They are about nerve; the arithmetic is the vectors' job, and the
file says so now.

**The fixes needed reviewing as much as the code did.** Both reviewers were
sent back over the repairs, and found four more defects in them -- including a
rule whose three planted cases all reached the helper and none reached the
*call site*, so deleting the call left the self-test green. Seven of this
wave's fixes were themselves wrong on first writing. Budget for that.

**Thirty-four lines of real gradient descent got past the new gate**, inside
the inference addon, by calling its accumulator `_numbers`. The docstring
admits that hole and is right to refuse a longer list of verbs, which would
fire on good code -- but the one directory that is read-only by construction
can be held to a stricter rule, so any compound arithmetic assignment into an
indexed value is now a finding **there and nowhere else**.

**A measurement that belongs in anyone's Godot notes:** the static
`JSON.parse_string` prints an engine error of its own before returning null,
where `JSON.new().parse()` returns the code quietly and hands over the
message. Found because a *passing* test printed a stack trace. Written up in
[docs/godot/reading-json-in-godot.md](../docs/godot/reading-json-in-godot.md).

**Not proven.** The manual check is a person's job: whether the retreat reads
as a decision rather than a bug, and whether the overlay makes the probability
legible. Nothing is profiled. `enemy_units` has no three-faction meaning in
either language -- documented and pinned, not solved.

**Still open, and carried forward.** The eleven over-long addon headers from
wave 07 still wait on the owner -- this wave added four and then cut them, so
the count is unchanged. Planning and learning still have no pages under
`docs/`, so `check_tiers.py` sees neither lesson until T7. The `doc-meta`
blocks in `spec/vectors/*/README.md` still declare a `half_life` the docs gate
does not know. Nothing enforces a line width. And the search and planning
vector runners still use the noisy JSON parser.

**Next: T7** -- close the slice: the docs pages that make `check_tiers.py` see
planning and learning at tier 1, the ADRs, and `make release`. It is the last
task in milestone 1.

Read tasks/T7-close-the-slice.md next, then: make check, write the review
record, make wave-merge.

## Resuming after 2026-10-13 (wave 15)

**What landed.** T5: `python/gameaikit/dataset/` simulates games with a fixed
policy and writes down every fight and every captured node -- 1500 games give
2937 combats and 1029 captures -- and `python/gameaikit/training/` fits a
logistic regression to *will this attack work* and a linear one to *how long
will this node take*, by gradient descent, standard library only. `make train`
writes `dist/weights.json` and a readable `weights.txt`; `make test-models`
runs the five acceptance commands and is part of `make check`.

**Combat is dice rather than a formula, on purpose.** If the chance of winning
were a logistic function of the features, a logistic regression would recover
the line somebody wrote three files away and the lesson would be circular. The
model is right about 87.8% of held-back fights against 69.0% for always saying
the attacker loses, and every weight has the sign the simulator's rules imply.

**The two models share one update rule.** Log loss through a sigmoid and
squared error through a linear prediction have the same gradient with respect
to the weights -- exactly for the first, up to a factor of two for the second,
which disappears into the learning rate. That is why there is one `fit` and not
two, and the factor is now written down because the file exists to be rederived.

**The majority baseline was flattering the model by fifteen points.** The
features are small integers, so 2937 rows cover 976 distinct vectors and 83% of
held-back rows have an **exact twin** among the rows trained on. A lookup table
of training rows scores 0.8177 where the majority class scores 0.6900 and the
model scores 0.8780. The report publishes all three now. Four weights cannot
memorise 976 answers so this score is honest -- but **T18's behaviour cloning
has capacity, and must be read against the table rather than the majority**.

**The control does not catch what T5 said it catches.** The task file claimed a
shuffled-label run catches a leak in the features. Both leaks were planted and
measured: the label appended to every row scores 1.0000 honestly and exactly
the baseline shuffled, and a contaminated split scores 0.8794 honestly and
exactly the baseline shuffled. The control **passes both**, because shuffling
destroys the leaked relationship along with the honest ones. It is still worth
running -- it tests that the score is measured against labels the fitting never
saw -- and the leaks themselves now need `--assert-no-leak`, which asks the two
questions directly.

**Thirteen findings from two reviews**, in
[docs/reviews/15-dataset-and-training.md](../docs/reviews/15-dataset-and-training.md).
The two worst were in the two places this wave is about: nothing had ever built
a board and looked at the feature row it produced, so eight mutations changed
the data in silence; and the leak check's "suspiciously perfect" rule was gated
on the model being logistic, so planting the label into the *capture* features
gave a model wrong by 0.0000 turns and nothing objected. Both are pinned now,
with twenty-two mutations run red across the two halves.

**Two numbers that were about the measuring rather than the thing.** A
published 0.8808 came from a 500-step probe where the pipeline fits 2000 and
gives 0.8794. And an earlier convergence measurement was five runs of the same
step count, because `steps: int = STEPS` in a signature captures the constant at
import. Both corrected; both worth remembering before quoting a number from a
scratch script.

**Not proven.** The manual check is still a person's job: whether the weight
dump explains, from those numbers alone, what the model learned. Nothing is
profiled. The "no friends left" sentinel on a fifth of combat rows is
documented rather than fixed -- capping it instead scores 0.885 against 0.878,
five rows in seven hundred, and every alternative is arbitrary in its own way.

**Still open, and carried forward.** The eleven over-long addon headers from
wave 07 still wait on the owner. Planning and learning have no pages under
`docs/`, so `check_tiers.py` sees neither lesson until T7. The `doc-meta`
blocks in `spec/vectors/*/README.md` still declare a `half_life` the docs gate
does not know. And a new one: **nothing enforces a line width**, the tree
breaks 88 columns in both directions, and mechanical wrapping made it worse --
either it becomes a rule with a gate or it stops being raised in review.

**A trap worth adding to CLAUDE.md, which is the owner's file:** mutating a
Python file in place can alias a `.pyc` written in the same second and **fake a
green**. Run mutation sweeps with `PYTHONDONTWRITEBYTECODE=1` or in a clone.

**Next: T6** -- `ai_learning`: the addon loads `weights.json` and does nothing
but infer, the decision gets wired into the game's AI turn, and
`check_no_training.py` finally gives invariant 6 the gate it has never had. The
conformance vector there is the one that matters: the GDScript inference and
the Python training have to agree on the same arithmetic, and the weights are
published rounded to six decimals so that they can.

Read tasks/T6-ai-learning-and-the-decision.md next, then: make check, write the
review record, make wave-merge.

## Resuming after 2026-10-12 (wave 14)

**What landed.** T4: `ai_planning` -- `WorldState`, `StripsAction`,
`StripsPlanner` and `PlanResult`, with the game's domain written out in full in
`game_domain.gd`. Forward state-space search over worlds rather than cells: a
queue, so the first plan found has the fewest actions; a visited set, because
several routes reach the same world; and a budget, so "no plan" can say whether
the **space** was exhausted or the **search** was. `python/gameaikit/pddl/`
reads a domain somebody else wrote, in propositional STRIPS only. Three vectors
in `spec/vectors/planning/`, each a JSON file beside two PDDL files: GDScript
plans over the JSON, Python asserts the PDDL says the same thing, and the
runner replays every plan rather than reading the planner's own `solved`.

**The domain is the lesson.** The barracks and the unit are paid for out of one
bank, so the node has to be mined twice: eight steps, 14 states. A reactive rule
that trains a unit whenever it can afford one never builds the barracks and
never attacks. Checked against an exhaustive enumeration written from the JSON
with no repo code in it -- 8 is the shortest, and the same sequence.

**The review found the claim the whole addon rests on was pinned by nothing.**
Turning the frontier into a stack -- `pop_front` to `pop_back`, one word -- left
118 unit tests, 400 property trials and 3 conformance vectors green. A stack
returns four actions where three exist, so it is a wrong answer and not an
equivalent mutant. The test named for the shortest-plan claim forked at the
*start*, where the goal is generated during the first expansion whichever end
of the frontier is read.

**And the property written to fix that could not see it either.** The first
generator -- eight predicates over six actions -- produced chains: 66 of 400
solvable and no two routes of different lengths to the same world. Six
predicates over twelve actions forks: 218 solvable, 156 plans measured against
an exhaustive search that shares no code with the planner, 19 of them failing
under a stack. **A property is only as good as the inputs that reach it**, and
that is the sentence this wave cost most to learn.

**Fifteen findings in all**, in
[docs/reviews/14-ai-planning.md](../docs/reviews/14-ai-planning.md). Five more
in the PDDL reader that it accepted after promising to refuse: a section written
twice silently kept the second, `:effect (and)` walked past the refusal written
for an action that does nothing, a bare word was read as a predicate, a
duplicate action name was accepted where the cross-language comparison is keyed
by name, and `:parameters` could be missing entirely. Nine rules in
`PlanningVector` and seven in the reader had **no planted case at all** --
deleting them left every gate green, under headers claiming the opposite.

**Two things T3 left behind, found by the re-read the wave 08 note asked for.**
The search conformance runner never checked that a path **ends at the goal** --
every rule it had was about the steps, so a legal stroll to the wrong cell
conformed, in work two reviews had passed. And `check_readability.py` matched
neither of its patterns against `static func`, so it had been reading
`search_vector.gd` -- a file that is nothing but static functions -- as empty.
Fixing the pattern produced no cascade: the existing tree was clean, and the
only two findings were in this wave's own new files.

**Not proven.** T4's manual check is still a person's job: whether someone who
has never seen STRIPS can read `game_domain.gd` and tell what the AI is
reasoning about. Nothing has been profiled; `WorldState.key()` sorts and joins
on every generated state, which is the obvious cost and has not been measured
against anything.

**Still open, and carried forward.** The eleven over-long addon headers from the
wave 07 review are still waiting on the owner. Planning has no page under
`docs/`, so `check_tiers.py` cannot see the lesson at either tier until T7. The
`doc-meta` blocks in `spec/vectors/*/README.md` declare a `half_life` the docs
gate does not know, and no gate looks outside `docs/` to say so.

**Next: T5** -- the dataset and the training, which is the first task whose
output is a *file* rather than code: Python trains and emits weights, GDScript
only infers, and `check_no_training.py` is the gate invariant 6 still does not
have.

Read tasks/T5-dataset-and-training.md next, then: make check, write the review
record, make wave-merge.

## Resuming after 2026-10-12 (wave 8)

**What landed.** T3: `ai_search` with breadth-first, depth-first, Dijkstra and
A\* over `GridGraph`, each implementing `Pathfinder`. A `SearchResult` that
carries what was expanded and what was still waiting. Three conformance vectors
in `spec/vectors/search/` with a runner, a property check over 300 random
boards, and a demo that draws the expansion in the order it happened. `make
check` is green and now includes `make test-vectors` and
`make test-search-properties`, both wired into CI as well.

Also here, because T3 could not be trusted without it: the fixes from **two**
independent reviews of `ai_core`, which was merged in wave 7 with a review that
arrived truncated. Mixing them into this branch rather than cutting a separate
wave is a deliberate exception -- A\* is wrong on a board with a negative cost,
and that board was buildable.

**The property check found a defect instead of confirming the code.** The claim
T3 asks for is that A\* expands no more cells than Dijkstra. Over 300 random
boards the costs agreed everywhere -- the heuristic is admissible -- and A\*
expanded **more** on 14 of them, which is the reverse of the reason it exists.
Neither costed search had a closed set, so a cell improved after being queued
was taken off the frontier twice and `expanded` was counting pops rather than
cells. That is also what the demo would have drawn. With the guard: 0 of 300.

**Three things the reviews found that were defects rather than gaps.** A
negative terrain cost was legal and *refunded* movement -- a unit with three
points finished a move with eight -- and it broke the one guarantee A\* offers,
since Manhattan distance is admissible exactly because no step costs less than
one. A cost is now `BLOCKED` or at least one, so the condition `astar.gd`
carried in prose is a rule. Two units sharing an id walked through each other
and **stacked on one cell**, because the occupancy rule compared ids rather than
identity. And `end_turn(0)` was a modulo-by-zero engine error returning null, on
the one type whose `apply` argues against exactly that.

**A test whose expected value is also the broken value measures nothing.** Two
of this session's own tests were that: one asserted a copy keeps whose turn it
is while ending on faction 0, so a copy hardcoding 0 passed; one asserted a
closed set on a board where no cell is ever re-queued. Both were found by
mutation and both are rewritten -- the second against a 4x4 board that was
*searched for* rather than invented.

**One mutation is recorded rather than closed.** Deleting the lower bound in
`GridGraph.contains` does not fail the suite, it **hangs** it: `neighbours`
hands back cells below the board and the searches walk downwards forever. On CI
that reads as a slow job rather than a broken one. The sentence is in the doc
comment of the rule that prevents it.

**Not proven.** The demo's legibility is still a person's job -- five tests hold
that it loads, that stepping replays rather than re-runs, and that its board
actually makes the four disagree, which is the demo's own premise. Nothing has
been profiled: `_cheapest` and the closed set are both linear scans, documented
as such, and the benchmark that would justify a heap has not been run because
the answer to needing one is `AStarGrid2D`.

**What its own review then found, after all of that.** Twelve findings, in
[docs/reviews/08-ai-search.md](../docs/reviews/08-ai-search.md), and the first
is the one worth reading: `dijkstra.gd` carried the textbook improvement branch
and its header called that branch "the line worth reading them for". Measured
with a counter, it fires **0 times in 250 boards** -- against 165 for A\* on the
same boards -- because `_cheapest` reads `g` as it is now, so the cell taken off
is already final. The duplicate guard beside it was dead for the same reason and
its comment was a byte-for-byte copy of A\*'s, citing A\*'s measurement as its
own. Both are gone and the header says what is actually true, including that a
binary heap keyed at insertion brings both straight back.

Next to it, a retraction: `astar.gd` claimed a stale `f` "would send the search
the wrong way". Freezing `f` across 241 boards changed neither the cost nor the
expansion count, not once. The line stays, for a different and honest reason.

Three more worth knowing before touching this code: **no search validated its
start** (`from = (-1, 2)` came back `reached`, with a path walking in from
nowhere, and the vector runner accepted it because every *step* was legal); the
runner was **a gate with no planted case for any of its rules**, which
`lint-selftests` cannot help with because it only ever looks inside `scripts/`
and the runner is GDScript; and the demo **hid the thing it exists to show** --
the
expansion rectangles buried the mud band exactly when the picture completed.

**Next: T4** -- `ai_planning`: STRIPS, and a PDDL reader in Python. It is the
first task with a Python half, so `make test-python` stops being a placeholder,
and the first addon that must not reach into `ai_search` -- the gate for that
has been inspecting a real addon only since wave 7.

**Start T4 by reviewing T3.** Three reviews in this project have now each found
real defects in work the previous one had passed over or never reached. That is
the argument for the rule, not against it.

**Milestones 2 and 3 are written and queued**, thirteen task files from a
board you can read through to an RTS. Three decisions are already taken and are
in the task files rather than left to be rediscovered: the strategy game is
**turn-based first**, because `BoardState.apply` copies the units into a new
state and that is right for search and wrong for two hundred units at sixty
frames a second; art is **CC0 now and generated later**, because hours spent
fighting a diffusion model are hours not spent on the AI; and the **RTS is
last**, after all three games.

**T8 is first, and it exists because the manual check worked.** The owner ran
`make run` and could not tell what he was looking at. That is T2's
`## Manual check` doing exactly what it is for, and the task file carries the
five measured reasons rather than "make it nicer".

**One finding is open and waiting on the owner**, recorded at the end of
[the wave 07 review](../docs/reviews/07-ai-core-and-the-board.md): eleven of the
twelve addon files have headers longer than the 5-10 lines `CLAUDE.md` asks
for, several by two or three times, and the longest are long because they carry
measurements this project asked for. Either the headers get cut or the rule
gets rewritten, and a session failing a rule should not be the one to quietly
change it.

---

## Resuming after 2026-10-12 (wave 7)

**What landed.** T2: `ai_core` and a board you can play with a mouse.
`GridGraph`, `Unit`, `Move` and `BoardState` under
`godot/addons/ai_core/`, two interfaces (`Pathfinder`, `DecisionPolicy`) that
say what an implementation must guarantee, a `TileMapLayer` view under
`godot/game/`, and 21 tests. `make check` is green, engine included.

**The gates stopped inspecting nothing.** Before this wave `check_addon_deps.py`
and `check_renderer.py` printed that they had found no addons and no scenes;
both now read real files and say nothing, which is the first time either has
actually held its invariant. The licence gate fired the moment `ai_core`
appeared, exactly as designed: an addon that would ship without LICENSE and
NOTICE. Both are in the folder now, as copies rather than symlinks, because the
promise is that you copy the folder and it works.

**Three design decisions worth knowing before T3.**

- **A `Move` carries its own path.** The board rules on whether a walk is
  legal; it never works one out. That is what lets `ai_core` hold no
  algorithms: A\*, a planner and a human clicking a tile all produce the same
  type. `ai_search` fills in the route and nothing else changes.
- **`apply` returns a new state**, and `why_refused` returns a sentence rather
  than a code. A search tries illegal moves constantly, so refusing must be
  cheap and must not fill the log with engine errors.
- **The path excludes the starting cell.** Cost is paid on entering a cell. The
  first version included the start and every cost calculation grew an "except
  the first one" clause, which is where off-by-one bugs live.

**Measured, not assumed: a failing gdUnit4 suite hides the tests after it.** A
suite of ten whose third test fails reports three cases and stops; the other
seven are not run and are not counted as skipped. Found by hitting it three
times while writing the board tests. It is in `docs/godot/addon-anatomy.md`,
because a red run that lists one defect is not a red run that lists them all.

**Two of this wave's own tests were wrong in the same way**, and the board
caught them: both walked a unit straight through the square the *other* unit was
standing on, so they passed or failed for a reason that had nothing to do with
what they claimed to test. The movement-points test now turns north, and the
terrain test rounds the top of the board.

**What the review changed, and what it could not.** A fresh context found three
things, the worst of them in the interfaces: they claimed GDScript has no
`abstract` keyword and used `push_error` with a default return instead. It has
`@abstract`, enforced at load time -- measured twice -- and the defaults those
files returned were values their own contracts define as legitimate answers, so
a forgotten override looked exactly like an implementation that had decided to
do nothing. `ai_search` is the next task and the first caller. See
[the review](../docs/reviews/07-ai-core-and-the-board.md) for the other two and
for the five this session found afterwards.

**That review is incomplete and the record says so.** The reviewer's report was
truncated in transport partway through its third finding, and three requests for
the rest went unanswered. It said 13 of its 35 mutations survived; which 13 was
in the part that was lost. This wave therefore merges knowing a context that did
not write the code found things nobody has read. The 21-mutation sweep run
afterwards does not replace it: it was written by the session that wrote the
code, which is the symmetry invariant 12 exists to break.

**Not proven.** Nothing has pathfound anything: the scene moves a unit one cell
per click, which is honest -- a route is a search and the search is T3. The view
is checked by four tests for the half that is mechanical (the tile set builds,
a cost chooses a tile, a repaint forgets the old board); whether the board is
*legible* is still the manual check in T2 and still needs a person.

**Next: T3** -- `ai_search`: A\*, BFS, DFS and Dijkstra over `GridGraph`,
implementing `Pathfinder`. It is the first addon that must not depend on
another, so `check_addon_deps.py` gets its first real question, and the click
that moves one cell becomes a click that moves along a route. Three things it
needs that do not exist yet: a `make test-vectors` target (and therefore a CI
step, or `check_workflow.py` refuses it), `godot/demos/search/`, and
`godot/test/ai_search/search_properties.gd`, which T3's acceptance runs directly with
`-s` rather than through gdUnit4.

**Start T3 by reviewing T2.** Not as a formality: the review that should have
covered it is missing its tail, and `ai_core` is what every later lesson is
built on.

---

## Resuming after 2026-10-12 (wave 6)

**What landed.** The last four gates and T1's close (`check_addon_deps.py`,
`check_tiers.py`, `check_links.py`, `check_workflow.py`), two rounds of fixes,
ADR 0005, and the review of all of it in
[docs/reviews/06-the-last-gates.md](../docs/reviews/06-the-last-gates.md). Nine
confirmed findings, all fixed on the branch. `make check` is green, engine
included.

**The session that wrote this wave ended before it could finish**, and what it
left behind was enough to resume from: the branch, the task files, and a last
commit message that named the open decision instead of leaving it to be
rediscovered. That is the resuming log doing its job, and it is worth saying
once -- the cost of writing the paragraph was far below the cost of the session
that would have had to reconstruct it.

**Wave 5 has no section here**, and that is not an omission being hidden: its
record went to `docs/reviews/05-the-wave-flow.md` when the review flow landed,
and nobody wrote the STATUS entry. The reviews directory is now where a wave's
findings live; this log is for what the next session needs to pick up.

**The gate for invariant 10 was violating invariant 10.** Three of the nine
findings are that, in three places: it exempted its own file from its own scan,
so the one spot where a match gets quoted while being documented was the one
spot nothing watched; the same quote had reached two commit messages, which is
what turned `make check` red; and its line-break planted case never reached the
rule it was filed under. The two unmerged commits were rebuilt to remove the
term from the message *and* the file content, and the backup branch was deleted
-- a ref holding the old blobs is the term still being in the repository.

**A question about Godot was settled by measuring it.** `check_addon_deps.py`
only knew the `res://addons/other/` spelling of a cross-addon dependency. On the
pinned 4.7.2, `preload("../ai_b/x.gd")` from inside `addons/ai_a/` parses,
resolves and runs. The gate catches both now, and the measurement is in
`docs/godot/addon-anatomy.md` with the engine version, where the six-month
half-life rule can reach it.

**Still open, and it is the owner's call, not a defect.** Rebuilding those two
commits left the old objects unreachable but still in `.git`. `git gc
--prune=now` removes them; this session did not have permission to run it.

**Not proven.** Four of the gates have still never seen the thing they are
about: there are no addons, no scenes and no lessons above tier 1, and three of
them say so on every run rather than passing in silence. The only thing standing
behind this wave's fixes is a mutation sweep written by the same session that
wrote the fixes.

**Next: T2** -- `ai_core` and the board. The first real GDScript in the
repository, and the first time `check_readability.py` and `check_addon_deps.py`
look at something instead of printing that they found nothing.

---

## Resuming after 2026-10-12 (wave 4)

**What landed.** `check_acceptance.py` and `check_status.py`, and the eight task
files T0–T7 they check. `make check` runs ten gate self-tests plus both suites,
green. T0 and T1 were written retroactively rather than excused as bootstrap
rows: their Acceptance blocks record the commands that were actually run,
including the two negative controls.

**The acceptance gate caught two bugs in itself, and then one in me.**

1. Its first non-terminating rule used a lookahead for `--headless` after the
   word `godot`. In `--path godot` the word appears twice, and the second
   occurrence has no `--headless` after it, so a correct criterion was reported
   as broken. Replaced with a per-line check that only matches Godot in command
   position, which is also easier to read.
2. Its "the assertion sits in the comment" rule required a pipe before `grep`,
   so the same mistake written without a pipe passed. Broadened.
3. Then it rejected this repository's own T3, because the Acceptance prose used
   the word "plausible". That was the rule working: Acceptance prose is exactly
   where a human verdict hides. The sentence was rewritten, not the rule.

**Two dangling references, deliberately.** T2's acceptance calls
`check_addon_deps.py` and T7's calls `check_tiers.py` and `scripts/release.py`.
None exists yet. They are named now so that writing them is part of finishing
T1, rather than something remembered later; running those tasks' acceptance
today fails on a missing file, which is the correct state for a `todo` task.

**Next, to finish T1:** `check_addon_deps.py` (invariant 2: no addon imports
another), `check_tiers.py` (invariant 5: no lesson above tier 1), then
`check_links.py` and `check_workflow.py` ported from `desk-panel`,
`CONTRIBUTING.md`, and `.github/workflows/ci.yml` running the same strings the
Makefile does. Then T2, which is the first real GDScript.

Correction to the line that was here: it predicted the link gate would flag
`github.com/boscocp/game-ai-kit`. It does not, and the prediction was wrong --
that URL appears only in `NOTICE`, which is not markdown, and inside backticks
in this file. There is no markdown link to it, so there is nothing for the gate
to follow. No exception is needed.

---

## Resuming after 2026-10-12 (wave 3)

**What landed.** Three gates: `check_readability.py` (invariant 1, mechanical
half), `check_doc_freshness.py` (the three half-life layers), and
`check_no_employer_refs.py` (tree and history). `make check` runs eight gate
self-tests plus both test suites, and is green.

**What reading the documentation first changed.** Four Godot facts were checked
against the 4.7 docs rather than assumed, and one of them was a live bug:

- a `plugin.cfg` requires an `@tool` script extending `EditorPlugin`. The
  library addons here need none, because `class_name` registers a class
  project-wide with no plugin. `check_license.py` had been using `plugin.cfg` as
  the marker for "shippable addon", so a library addon was **skipped in
  silence** -- a gate failing open. Fixed, and the self-test case inverted.
- the Asset Library does not require `plugin.cfg`, does require `LICENSE` at the
  repository root, and **does** offer Apache-2.0. The tutorial page lists a few
  licences as examples and briefly looked like it ruled Apache out; the live
  filter has it.
- `TileMapLayer`, not `TileMap` -- the latter is deprecated in 4.x.
- `AStarGrid2D` is engine core in C++ with four heuristics, which is what the
  README's "when not to use this" should point at.

All four are in `docs/godot/addon-anatomy.md` with source URLs and a
`verified_on` date. `CLAUDE.md` gained the rule: read the documentation for the
pinned version first, then measure to confirm.

**How the employer gate avoids the obvious contradiction.** A gate searching for
a company name must contain that name, and a file saying "never mention X" is a
mention of X. The repository stores **salted SHA-256 hashes** instead, with a
prefix rule so one stored term also catches its compounds. `--add-term` reads
from a hidden prompt, so adding one never puts it in a file or a shell history.
The list is seeded with a single term derived from the work email domain;
**internal repository, client and project names are not on it yet** and should
be added with `--add-term`.

**Not proven.** The readability gate has only ever seen `smoke_test.gd`, which
is exempt from its doc-comment rule. It was confirmed to find real files by
planting an untyped function there (five findings, exit 1), but it has never
run against an addon, because none exists. The employer gate's history scan
walks every blob ever committed, which is fast on four commits and has not been
timed on a real history.

**Next:** `check_acceptance.py` and `check_status.py` (port from `desk-panel`,
and note that the former has **no** `--self-test` there -- the port must gain
one, and its non-terminating-command rules are about `adb` and a Python server,
which here means a Godot invocation without `--headless`). Then
`check_addon_deps.py`, `check_tiers.py`, `check_links.py`, `check_workflow.py`,
CONTRIBUTING.md and the CI workflow. After that, T2.

---

## Resuming after 2026-10-12 (wave 2)

**What landed.** gdUnit4 v6.2.2 installed by `make bootstrap`, pinned by tag and
verified by SHA-256. Two tests in `godot/test/smoke_test.gd`, and
`make test-godot` is now part of `make check`. The licence gate learned to tell
a third-party addon from one of ours.

**A decision reversed before it became history.** gdUnit4 was first vendored
into the repository. Staging it showed **509 files** of someone else's code
about to enter a repository whose premise is that you can read it. Switched to
install-at-bootstrap and gitignored; `docs/adr/0004` records why, including the
alternatives (submodule, writing a small runner) and what it costs: a fresh
clone must bootstrap before it can test.

**Three things the previous section got wrong, found by running them.**

1. `make test-godot` did not work. It ran `--path godot --quit` on a project
   with no main scene, which exits 1 -- and, despite `--headless`, popped a
   **zenity dialog** on the desktop. Replaced with a script entry point.
2. A rule was about to be written claiming Godot's exit code carries no
   information. Measured instead, and it is false: a parse error exits 1 and
   `quit(3)` exits 3. Godot propagates. The rule was not written.
3. gdUnit4 **refuses headless mode** unless given `--ignoreHeadlessMode`,
   because Godot does not deliver `InputEvent` there. That is now a standing
   constraint: a test in this repo must never depend on simulated input.

**What the licence gate found.** Vendoring gdUnit4 made `check_license.py` fire:
it would have required this project's NOTICE inside someone else's addon. The
gate now has a declared `VENDORED` table -- a vendored addon must carry its own
licence and must **not** carry ours, since our NOTICE in their folder claims
authorship we do not have. Declared one by one, never inferred.

**Still not proven.** The test suite has two tests and neither touches a line of
this project's own code, because none exists yet. What proves the runner can
fail is the planted failure: changing `2 + 2 == 4` to `== 5` gives exit 100, and
restoring it gives 0. Re-run that before trusting any future green.

**Known dangling reference.** `NOTICE` and `README.md` point at
`https://github.com/boscocp/game-ai-kit`, which returns 404 -- the repository is
local only, with no remote and nothing published. When `check_links.py` lands it
will flag this; the URL is the intended home, so it belongs in the link
exceptions file with that reason, not removed.

**Next:** the gates still missing -- `check_acceptance.py`, `check_status.py`,
`check_readability.py`, `check_no_employer_refs.py`, `check_tiers.py`,
`check_doc_freshness.py`, `check_addon_deps.py`, `check_links.py`,
`check_workflow.py` -- then CONTRIBUTING.md and the CI workflow. Note that
`desk-panel`'s `check_acceptance.py` has no `--self-test`; the port must gain
one, and its non-terminating-command rules need replacing (they are about `adb`
and a Python server; here the equivalent is a Godot invocation without
`--headless`).

---

## Resuming after 2026-10-12 (wave 1)

**What landed.** The repository exists at `/mnt/games/gamedev/game-ai-kit`, on
the large disk. Godot 4.7.2-stable is installed under
`/mnt/games/gamedev/toolchain/`, downloaded and verified by SHA-512. `make check`
is green with four gates: `check_disk_layout.py`, `check_renderer.py`,
`check_license.py` and the `bootstrap.sh` usage self-test. Three ADRs are
written (engine, toolchain layout, licence). LICENSE, NOTICE, README and
CLAUDE.md are in place.

**What the bootstrap found.** Enabling Godot's self-contained mode was assumed
to be enough to keep the toolchain off the small disk. It is not: with `._sc_`
in place, a bare `--headless --import` still recreated
`~/.local/share/godot/app_userdata/`. `XDG_DATA_HOME` covers the gap. Both
mechanisms now live in `scripts/godot`, and `check_disk_layout.py` asserts both.
Recorded in `docs/adr/0002`.

**What is not proven.** No Godot test has ever run — `make test-godot` only
opens and quits the project, because gdUnit4 is not installed yet. No GDScript
exists at all, so `check_renderer.py` has found nothing because there is nothing
to find; its self-test is what proves it can fail. `make` collapses every recipe
failure to exit 2, so a gate's own exit codes must be read by calling the script
directly.

**Next:** finish T1. `check_commit_msg.py` is done and the hook is live
(`make hooks`); it blocks assistant attribution in both forms, so overriding the
machine's global hook costs nothing. The gates still missing are
`check_acceptance.py`, `check_status.py`, `check_readability.py`,
`check_no_employer_refs.py`, `check_tiers.py`, `check_doc_freshness.py`,
`check_addon_deps.py`, `check_links.py`, `check_workflow.py`. Port the first
few from `desk-panel`, which is the only repository code is ported from here.

### What is still only true on this desk

- The toolchain path `/mnt/games/gamedev/toolchain` is this machine's layout.
  `GAK_TOOLCHAIN` overrides it, but nobody has run the gate with that override.
- `gdtoolkit` (gdformat/gdlint) has not been tried. Python here is 3.14.7 and
  `pip` is absent; if gdtoolkit cannot be installed, the GDScript formatting
  gate is deliberately left out of M1 and recorded in an ADR, rather than
  becoming a `continue-on-error`.
