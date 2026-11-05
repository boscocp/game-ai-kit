# Review: wave/130 -- T118, the RTS shows the enemy a clocked side believes

T118 adds invariant 13 to T55's human clock. `RtsHumanClock` gains three
read-only accessors: `last_handed()`, `enemy_age_ms()` and `waiting()`.
It also keeps a parallel `_held_at`. `RtsThinking.clock` is wired in
`RtsGame.restart()`. With K on, the thinking view draws each enemy unit
the clocked computer was handed as a hollow ring, with a dashed thread
to where it stands now and one "{ms} ms ago" label. The panel gains a
line for the late view and one for commands waiting under the cap, in
en and pt-BR.

A fresh context reviewed PR #75 at head ca24620 in a throwaway worktree.
It planted faults one at a time and ran only the narrow suite: the clock
suite, or `test/rts` when the draw path was planted. Each plant was
restored. Nothing was pushed, committed or commented.

**Verdict: approve, with no blocker. Apply should-fix 1 and 2 on the
branch before the merge.** The code does what the PR says. The
accessors are read-only and nothing new runs per frame beyond a filter
over the handed snapshot. With K off, nothing is drawn or computed. But
the test written to hold "the drawn enemy is the handed one" does not
tell the handed enemy from a recomputed one. In the mounted scene it
compares two empty arrays. That is invariant 4's green that nobody
investigates, on the one claim this task exists to make.

## What was reviewed

- The diff against main: `rts_human_clock.gd`, `rts_thinking.gd`, the
  `rts.gd` hunks, `rts.csv`, `rts_human_clock_test.gd`, `rts-ai.md`, and
  STATUS.
- Also read: `RtsHumanClock.decide`, `_late` and `_let_through`;
  `RtsThinking._draw`, `_draw_focus` and `_seen_at`; `RtsGame._refresh`,
  `_physics_process` and the K key; `RtsSide.overlay`; `RtsWorld.unit`;
  `RtsSnapshot.enemies`.

What holds, read and measured:

- **The accessors are read-only.** `last_handed()` returns the field
  `decide` set, and `enemy_age_ms()` and `waiting()` only do arithmetic
  on stored ticks. None of them calls `inner`, the measurer
  (`knob_values`, `from_file`) or `_late`. Drawing cannot change what the
  side is handed: `_handed` is written only in `decide`, before
  `inner.decide(handed)`, and is the same object the inner side got. The
  handed units are read-only (`late.units.make_read_only()`).
- **The per-frame cost is small.** It is `enemies()`, a filter over the
  handed snapshot, in `_draw_believed` and once more in `clock_lines`.
  The rest is `RtsWorld.unit(id)`, a dictionary lookup, once per ring.
  There is no replay and no snapshot is built. T55's blocker does not
  come back.
- **K off.** `sides[EAST] as RtsHumanClock` is null without the clock.
  `believed_enemy()` and `clock_lines()` then return at once, and
  `_draw_believed` loops over nothing. A second K calls `restart()`,
  which clears `clock`. The scene test holds this.
- **The `_held_at` bookkeeping** is popped on every path that pops
  `_held`: the uncapped clear, the given loop and the drop loop.
- `check_readability.py` and `check_translations_game.py` exit 0. The new
  functions are short: `_draw_believed` is 13 lines and `clock_lines` is
  16, with nesting of 2 at most. Each public function has a doc comment
  that says why, for example "so it cannot show a view the side did not
  get".
- Baseline: `make test-godot-some SUITES=test/rts/rts_human_clock_test.gd`
  ran 21 cases with 0 failures and no `SCRIPT ERROR`.

## Mutation round

| plant | where | caught by |
|---|---|---|
| `believed_enemy()` recomputes from the side's current view (`view.enemies() if view != null else clock.last_handed().enemies()`) | `rts_thinking.gd:61` | **nothing**: 21/21 green |
| the same, unconditionally (`return view.enemies()`) | `rts_thinking.gd:61` | only by accident: `SCRIPT ERROR` on a null `view` in the unit case, which never sets `thinking.view` |
| `_draw_believed` draws `view.enemies()` (only when the clock is set) instead of `believed_enemy()` | `rts_thinking.gd:206` | **nothing**: 54/54 in `test/rts` green |
| the same, unconditionally | `rts_thinking.gd:206` | `SCRIPT ERROR` on a null `clock` with K off: caught, but by a crash, not an assertion |
| the drop loop stops popping `_held_at` | `rts_human_clock.gd:254` | **nothing**: 54/54 in `test/rts` green |

A probe in the scene case printed `handed=0 now=0 age=500.0`. After K
and three decisions, the computer has not yet seen one enemy unit, so
`believed_enemy().is_equal(clock.last_handed().enemies())` is `[] == []`.

## Findings

1. **Should-fix: the test does not tell the handed enemy from a
   recomputed one** (`test/rts/rts_human_clock_test.gd:234-250` and
   `:276-290`). This is step 3 of the task and the PR's main claim.
   - The unit case never sets `thinking.view`.
   - Its only enemy is a barracks that stands at the same place in the
     views of 30 and 60. So the late view and the current view agree on
     it, and a recompute from the current view matches as well.
   - The scene case compares two empty arrays (probe above).

   Plants 1 and 3 stay green. The PR's own plant, the clock reporting
   the current view, was caught only because the barracks is *absent* at
   tick 0.

   *Fix:*
   - In the unit case, use a moving enemy: a soldier whose position at
     30 differs from its position at 60.
   - Set `thinking.view` to the current view.
   - Assert that `believed_enemy()` holds the tick-30 position, and that
     it is not equal to `thinking.view.enemies()`.
   - In the scene case, step until `last_handed().enemies()` is not empty
     (or place a west unit in east's sight), and assert `is_not_empty()`
     before the equality.
2. **Should-fix: the drawing itself is not tied to `believed_enemy()`**
   (`rts_thinking.gd:205-217`). This is plant 3. `_draw` does run
   headless (plant 4 crashed in it), so it can be checked. *Fix:* have
   `_draw_believed` record the ring centres it drew, for example in an
   `Array[Vector2]` field like `RtsMeter`'s figures. Then let the scene
   case assert that they are the screen positions of `believed_enemy()`.
   If the owner prefers to keep the drawing a person's job, say so under
   T118's `## Manual check` and in decision 3.
3. **Nit: the drop path of `_held_at` has no case** (plant 5). Today the
   code pops it correctly. If a later edit drops the pop, `waiting()`
   overstates the oldest wait with no test noticing, because the parallel
   arrays drift apart silently. Possible fixes:
   - one case with a cap that drops, asserting `oldest_ms`;
   - or keep `[command, tick]` pairs in one array, so that the two
     cannot drift.
4. **Nit: the header rewrap leaves a 121-character line** (`rts.gd:23`,
   "...the frame beside its base (`RtsMeter`), hidden until asked. Opened
   with..."). Rewrap the paragraph.
5. **Nit: `clock_lines()` is computed before `lines()`'s "not thought
   yet" early return** (`rts_thinking.gd:87-90`). It is then thrown away.
   This is harmless and costs almost nothing. Moving it below the return
   reads more honestly.
6. **Nit: the concept page says "with V and K on"** (`rts-ai.md`). The PR
   body says V, K and F. Name the same keys in both.

## Decision 7: the focus ring at the target's current place

Here is the reviewer's view. `_seen_at` reads `thinking.view`, the side's
*current* snapshot. It is used only for drawing. It is not an input to
any decision, so no state flows back into the clocked side, and T55's
leak 3 (own units' targets naming hidden enemies) does not come back
through it.

Is the drawing misleading? Less than it first looks. The squad chose its
focus from the late view, but the order it gives is "attack id", and the
world carries that order out against the unit where it stands now. So
the ring at the current place marks where the strike will land, and the
hollow ring marks where the side chose it. The thread between them is
the reaction gap. That is the lesson, and moving the focus ring onto the
believed place would hide where the shots go.

**Recommendation: keep it, as the PR proposes.** Add one sentence to the
concept page: "the focus ring is where the strike lands (the order names
a unit, not a place); the hollow ring is where the side chose it."

One side effect is worth knowing. When the focused target has left the
computer's *current* sight, `_seen_at` returns INF, and the focus ring
disappears while the squad still holds that focus. It is a corner case,
and it predates this PR. The fix would be to fall back to the handed
position when the target is not in the current view.

## For the owner

1. **Decision 7**: keep it, with the sentence above (see the section
   above).
2. **Decisions 1, 2, 4, 5 and 6**: agree, keep. On decision 3, whether
   the legend needs a row for the rings: the "ms ago" label and the
   panel line name the rings well enough. Let the manual check decide.
3. **Finding 2** is a choice. Either the drawing is held by a test, which
   needs a small recorded field, or it is named as a person's job. The
   reviewer recommends the field: it costs one array and turns plant 3
   red.
4. **The manual check is still open**: `make demo-rts`, K on, during a
   raid. The PR does not claim it.

## What was run

- `make worktree-setup`, then a detached checkout of
  `ca24620955574c14506224b03e4888384d0fecb2`.
- `make test-godot-some SUITES=test/rts/rts_human_clock_test.gd`: 21
  cases, green with no plant, and green under plant 1. Under plant 2 it
  stops at `test_the_drawn_enemy_is_the_view_the_clock_handed` with
  `SCRIPT ERROR`.
- `make test-godot-some SUITES=test/rts`: 54 cases, green under plants 3
  and 5. Under plant 4 it fails with `SCRIPT ERROR` on a null clock.
- One temporary `print` in the scene case gave the probe
  `handed=0 now=0`. It was reverted.
- `python3 scripts/check_readability.py` and
  `python3 scripts/check_translations_game.py` both exit 0.
- Each plant was restored with `git checkout -- godot`. The worktree is
  clean at ca24620.

## What was done about them

Both should-fix findings and all four nits were applied on the branch.
Plants 1, 3 and 5 were rerun one at a time against the clock suite, and
each was restored from git.

1. **Should-fix 1, applied.**
   - The unit case now walks an enemy runner a cell every half second
     (`_raided_at`), and sets `thinking.view` to the current view. It
     asserts that the drawn enemy is the view of 30, and that it is not
     the current one.
   - In the scene case, a west worker is put in east's sight with a walk
     order. Before the equality, the case asserts that the handed enemy
     is not empty and is not the current enemy.
   - Plant 1 (`believed_enemy()` recomputing from `view`) now fails
     `test_the_drawn_enemy_is_the_view_the_clock_handed`.
2. **Should-fix 2, applied as recommended.**
   `RtsThinking.drawn_believed` records the cell of each hollow ring the
   last drawing put down. Both cases await a frame and assert that it
   holds the handed positions. The scene case also asserts that it does
   not hold the current ones. Plant 3 (`_draw_believed` drawing
   `view.enemies()` while the clock is set) now fails the unit case.
3. **Nit 3, applied.**
   `test_a_dropped_command_takes_its_wait_with_it` drops commands under
   a cap of 2 and asserts that `oldest_ms` is 0. Plant 5 (the drop loop
   not popping `_held_at`) fails it.
4. **Nit 4, applied.** `rts.gd`'s header paragraph is rewrapped.
5. **Nit 5, applied.** `clock_lines()` now runs after the "not thought
   yet" return.
6. **Nit 6, applied.** The concept page and the PR body both say V, K
   and F.

Decision 7 is kept, as the reviewer recommends. The concept page now
says that the focus ring marks where the strike lands, because the order
names a unit and not a place, and that the hollow ring marks where the
side chose it. The corner case predates this PR and was not changed: a
focused target that has left the computer's current sight loses its
focus ring. The PR body notes it.
