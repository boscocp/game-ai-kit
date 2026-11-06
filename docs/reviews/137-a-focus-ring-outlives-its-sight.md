# Review: wave/137, T128 -- a focus ring outlives its sight

T128: a fighting squad's focus ring was drawn only where the computer's
*current* snapshot showed its target, so when the target walked out of
sight the ring vanished while the squad still held that focus (found by
T118's review, `docs/reviews/130-...`, decision 7). The PR adds a
fallback in `RtsThinking` (`_focus_place`, `_last_told_at`): the clock's
handed view first, then the side's memory through a new
`RtsInfluence.last_seen_at`. A stale ring is drawn thin, in the late
enemy's white, with a dashed line to the squad. `RtsThinking.drawn_focus`
records each ring, `godot/test/rts/rts_focus_ring_test.gd` holds four
cases, and one sentence goes on `docs/concepts/rts-ai.md`.

A fresh context reviewed PR #84 at head 2dbe1d7 (base 1d94bb6). It read
the diff, the task, `rts_influence.gd`, `rts_side.gd`, `squad.gd`'s focus
choice, `rts.gd`'s `_refresh`, the clock's header and T118's review, and
ran narrow checks in a throwaway worktree. It made no commit, push or PR
comment.

**Verdict: changes requested, one blocker.** The code does what the task
asks, nothing the squad decides reads the new state, and the gates are
green. The blocker is not in the code: PR #84's body is T133's (the
ai_llm threads wave), not T128's, so the PR carries none of this wave's
description or decisions. Two should-fixes: a stale *rival* ring looks
the same as a fresh one, and no test holds "in current sight beats the
handed place" under the clock -- a plant that re-breaks T118's decision 7
survives.

## What was run (green at 2dbe1d7 unless stated)

- `make worktree-setup`, then `./scripts/godot --headless --path godot --import`.
- `make test-godot-some SUITES="test/rts"`: 59 cases, 0 failures, no
  `SCRIPT ERROR`.
- `make test-rts-clock-limits`: "rts league: 0 failure(s)".
- `make test-demo-overlays`: exit 0, 0 failures in en and pt_BR. The
  `SCRIPT ERROR`s in its output are the planted crashing step
  (`step_decision` called from `demo_overlays.gd:224`), as on main.
- `python3 scripts/check_readability.py`: exit 0.
  `make lint-tasks lint-status`: exit 0. `python3 scripts/check_modules.py`: exit 0.
- Who reads the new state: `grep` over `godot/**/*.gd` for `drawn_focus`,
  `last_seen_at`, `_focus_place` and `_last_told_at` finds only
  `rts_thinking.gd` and the new test. **Drawing only holds**: no squad,
  commander, clock or match code reads any of it, and `last_seen_at`
  reads `_seen` without writing it.

## Mutation round

Each plant on a fresh copy of `rts_thinking.gd`, run against
`rts_focus_ring_test.gd` and `rts_human_clock_test.gd`, file restored
after (`git status` clean).

| plant | result |
|---|---|
| no fallback (`told` always INF) | caught, 1 failure |
| a fallback ring never marked stale | caught, 1 failure |
| memory before the handed view | caught, 1 failure |
| handed view before the **current** view, under the clock | **survives**, 0 failures |
| `drawn_focus.clear()` removed | survives, 0 failures |

The first three are the PR's own claims and they hold. The fourth is
finding 2. The fifth is a nit (finding 5).

## Findings

1. **blocker -- PR #84's body is another wave's.** `gh pr view 84
   --json body` starts "T133, from the second review of T130 (PR #82): a
   chat request to a server that accepts and then says nothing..." and
   describes `http_runtime.gd`, `check_llm_validated.py` V3 and three
   decisions about threads. None of it is in this branch. The PR was
   created with that body (GitHub shows no edit), at 21:49 local, the
   same minute the session's shared scratchpad file `pr-body.md` -- which
   now holds T133's text -- was last written. Two waves wrote their body
   to the same path, and #84 picked up the other one. The merged commit
   is not affected (the repo squashes with the commit messages, and
   2dbe1d7's message is T128's), but the PR is what the owner reads, and
   T128's decisions for the owner are not on it. **Fix:** `gh pr edit 84
   --body-file <T128's own body>` with this wave's description, checks
   and decisions; and tell T133's wave its body text has leaked into #84
   so its own PR is opened from its own file. For the batch routine
   (`docs/howto/parallel-batch.md`): name the body file per wave
   (`pr-body-137.md`), never one shared name.

2. **should-fix -- nothing holds "current sight beats the handed place"
   under the clock.** `godot/game/rts/rts_thinking.gd:225-232` checks
   `view.units` first, which is right: it keeps T118's decision 7 (the
   focus ring is where the strike lands, because the order names a unit).
   But `test_under_the_clock_...` (`godot/test/rts/rts_focus_ring_test.gd:41`)
   only covers a target absent from the current view, and
   `test_a_focus_in_sight_...` (`:20`) has no clock. A plant that reads
   `believed_enemy()` before `view.units` passes every test, and it would
   silently move every clocked focus ring back onto the late place -- the
   opposite of what T118's review recommended and the concept page says.
   **Fix:** one more case: clock on, handed at (4.5, 1.5), current view
   with the target at (6.5, 1.5); expect `_ring(Vector2(6.5, 1.5), false)`.

3. **should-fix -- a stale rival ring is not marked stale.**
   `rts_thinking.gd:214-217`: a fresh rival is `Color(1, 1, 1, 0.35)`,
   width 1.0; a stale rival is `THREAD_COLOUR`, `Color(1, 1, 1, 0.4)`,
   also width 1.0, and neither has a line. The two are the same picture
   (the stale one is in fact a shade *brighter*), so a rival out of sight
   is drawn as if seen, which is the exact thing the task forbids ("so it
   never claims a current place the side cannot see"). STATUS's row says
   the rivals fall back "fainter"; they do not. No test holds rivals at
   all (the fixture has one `focus_scores` entry). **Fix:** either draw a
   stale rival visibly differently (a lower alpha such as 0.15, or a
   dotted arc), or keep the pre-T128 behaviour for rivals and skip them
   when out of sight -- the simpler choice, since the task is about the
   squad's *focus*; then add a rival to the fixture and assert which rings
   `drawn_focus` holds.

4. **nit -- the header calls the stale ring "hollow like the late
   enemy".** `rts_thinking.gd:16-18`. Every focus ring is an arc, so
   "hollow" names nothing that changed; what changes is colour, width and
   a dashed line, as the concept page and `_draw_focus`'s comment say.
   **Fix:** "...keeps its ring where the side was last told of it, thin
   and white like the late enemy, its line dashed: stale, never a claim
   to where it stands now."

5. **nit -- `drawn_focus.clear()` is not held, and sits apart from its
   twin.** `rts_thinking.gd:146` clears it at the top of `_draw`, while
   `drawn_believed` is cleared inside `_draw_believed` (`:250`). Each
   test draws once, so removing the clear passes, and in the game the
   array would then grow every frame. **Fix:** in one existing test,
   draw twice and assert the size is still one.

6. **nit -- "the last sighting" is the last *decision's* sighting.**
   `docs/concepts/rts-ai.md:377-379`. Without the clock, `RtsSide.decide`
   is the only caller of `belief.update` (`rts_side.gd:59`), twice a
   second, so `last_seen_at` is where the target stood at the last
   decision that saw it, not where it slipped out of sight. In play the
   ring jumps back by up to half a second of the target's movement when
   it goes stale. That is honest (it is what the side was told), but the
   manual check will see the jump and should know it is meant. **Fix:**
   "...the last place a decision saw it otherwise".

7. **nit -- a killed target also leaves a stale ring.** When the focus
   dies it leaves the current view, `_seen` keeps a unit for
   `MEMORY_SECONDS`, and the squad keeps the focus until its next
   decision (`squad.gd:180-188`), so a white stale ring sits on the dead
   unit's last place for up to half a second -- longer under the clock,
   whose handed view still holds it. Before T128 the ring vanished. It
   is the side's honest belief and the window is short, so no change is
   asked; worth one line under the task's `## Manual check` so the person
   doing it is not surprised.

## The PR's decisions

The body on #84 lists T133's three decisions, not this wave's. These are
the decisions this branch makes, read from the code, commit message and
STATUS row; the lead should match them to the five the wave meant to
list.

1. **Fallback order: the clock's handed view, then the side's memory.**
   Agree. In play the two agree whenever the handed view holds the
   target, because under the clock the inner side updates its belief
   from that same handed view; handed-first only matters in a case the
   test builds by hand, and it names the view the side decided on.
2. **The stale style: the late enemy's white, thinner, the line
   dashed.** Agree for the chosen ring: it reads as a belief and stays
   distinct from the red sighting. Disagree for rivals as built (finding 3).
3. **Rivals fall back too.** Disagree as built: either mark them or skip
   them; recommend skipping (finding 3).
4. **No ring when never told or forgotten.** Agree: drawing a guess the
   side was never given would be the leak T55 closed, in pictures.
5. **A new public `RtsInfluence.last_seen_at`, read only.** Agree. It is
   the narrowest door to `_seen`, typed, documented, and only the
   thinking view calls it. The alternative, reaching into `_seen` from
   the view, would be worse.

## For the owner

1. Finding 1 must be fixed before the merge: the PR needs its own body
   and its own decisions. Nothing in the code depends on it.
2. Findings 2 and 3 are small: one test case, and one choice about
   rivals (recommendation: skip them out of sight, as before).
3. Findings 4-7 are wording and one assertion; apply on the branch.
4. The manual check (`make demo-rts`, V on, chase a focus out of sight)
   is still a person's. With findings 6 and 7 in it, the person knows
   the ring jumps back to the last decision's place, and that a kill
   leaves a short-lived stale ring.

## What was done about them

All applied on the branch, in one commit after 2dbe1d7.

1. **Applied.** T128's body was rewritten in a file of its own
   (`<scratchpad>/wave137/pr-body.md`), checked by `check_pr_message.py`
   and put on #84 with `gh pr edit 84 --body-file`. The coordinator was
   told that T133's text had leaked into it.
2. **Applied.** `test_under_the_clock_a_focus_in_sight_is_ringed_where_it_stands_now`:
   the target is handed at (4.5, 1.5) and seen now at (6.5, 1.5), and its
   ring is fresh at (6.5, 1.5). The plant "the handed view before the
   current one" now fails this test.
3. **Applied, by skipping.** A rival out of sight gets no ring, as before
   T128. Only the chosen focus falls back. `_ring_colour` returns the
   late enemy's white only for that ring.
   `test_a_rival_out_of_sight_gets_no_ring` puts one rival in sight and
   one out of sight but remembered, and expects the focus (stale) and
   the rival in sight, nothing else. The plant "rivals fall back" fails
   it. Decision 2 in the PR (decision 3 here) now reads "rivals out of
   sight are not drawn".
4. **Applied (nit).** The header now says "thin and white like the late
   enemy, its line dashed".
5. **Applied (nit).** The test of a focus in sight draws twice and
   expects one ring. The plant "no clear" now fails it.
6. **Applied (nit).** `docs/concepts/rts-ai.md` now says "the last place
   a decision saw it otherwise, so it may jump back by up to half a
   second of the target's walk". The task's manual check says the same.
7. **Applied (nit).** No change to the code. The task's manual check now
   has a line saying that a killed focus leaves a short-lived stale ring,
   and that this is meant.
