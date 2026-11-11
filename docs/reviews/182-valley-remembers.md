# Review: wave/182-valley-remembers

PR #142, task T165. The valley example on T164's record of deeds (ADR
0025): `make demo-valley`, six villagers who plan from the world's facts
with A\*, GOAP and `ActionChoice`, three people whose fixed manner reads
the standing, one deed a day and only one that changes a fact, both
chains on screen, an erase button, en and pt-BR, and the concept page
`karma-and-world-memory` with its pt-BR twin.

A fresh context reviewed head 5e32734, as the coordinator relayed it.
**Verdict: changes requested, with one must-fix.** A deed in the middle
of the day can abort a villager's decision with a SCRIPT ERROR. Besides
that, the walk cost that the plans rest on had no test of its own, and
there were three documentation points and two nits.

## What was reviewed

- The diff against T165's decisions, ADR 0025 (especially N20 and "What
  N20 cannot see": a villager reads only the standing), CLAUDE.md
  invariants 1, 3, 4, 6 and 13, and the traps about `-s` scripts and
  typed arrays.
- **Probes in play.** The reviewer pulled the bridge down while Bento,
  an east villager, stood on it at turn 4. He was stranded, his plan was
  `rest`, his home was unreachable, and the untyped ternary in
  `_set_off` aborted with `Trying to assign an array of type "Array" to
  a variable of type "Array[Vector2i]"`.
- **Mutants.** `var walk: int = 0` in `_goap_actions`, and `plan_cost`
  returning 0, both left every valley case green.
- **Sources.** Ultima IV's article was checked against the concept
  page's claim that alms raise Sacrifice.

## Findings

1. **Must fix.** `valley_villager.gd`, `_set_off` and `_head_for`:
   `route = search.path.duplicate() if search.reached else [] as
   Array[Vector2i]` is untyped. Its else branch aborts the function with
   a SCRIPT ERROR, and that branch is reached in play whenever a deed
   strands a villager. A stale route could also walk the villager over
   the bridge that is gone.
2. **Test gap.** Nothing held that the walk changes a plan: both
   mutants above survived.
3. **Minor.** Plan costs use the walk from where the villager stands
   when it plans, not from the step before. That is an approximation,
   and the docs did not say so.
4. **Open point 7, decided.** T164's refusals stay English, quoted
   verbatim in a translated frame, and the precedent is written down.
   The game's own two refusals in `ValleyGame.act` get the marker
   `# not shown: reached only through the API; the UI acts on offered
   deeds`.
5. **Note.** The one-deed-a-day rule lives in the game, not in the
   record, and `valley.md` should say so.
6. **Nit.** There are nine number keys, and `offered()` was capped with
   `mini()` and nothing held that the data stays under nine.
7. **Nit.** The concept page said Ultima IV's alms raise Sacrifice. The
   article says alms demonstrate Compassion.
8. **Optional.** The three-sessions suite could also compare the
   villagers' plans across reloads.

## What was done about them

1. `_set_off` and `_head_for` now go through `_follow`, which clears the
   route and assigns the path only when it was reached. New case
   `test_the_bridge_pulled_down_under_a_villager_strands_it_where_it_stands`
   plays day 1 until an east villager is west of the bridge, then pulls
   the bridge down. It checks that, every turn to the day's end, no
   villager stands on a shut cell or keeps the gone bridge in its route.
   It also checks that the stranded villager stays west with no route
   home. Planted by checking out the old file: the case errors, and the
   suite prints that exact SCRIPT ERROR. With the fix, the whole valley
   folder prints none.
2. New case `test_the_walk_decides_who_bakes_and_who_buys`, on the
   reviewer's scenario: footbridge built, bridge down, day 3. Ana bakes
   and Clara buys, and each one's chosen plan costs less than the other
   plan. New case `test_the_dearer_plan_scores_less`: with the bridge
   down, Ana's bread plan is dearer than Davi's and scores lower. Both
   mutants, `walk = 0` and a `plan_cost` that adds nothing, now turn
   `test_the_walk_decides_who_bakes_and_who_buys` red (two failures in
   the suite each time). The file was restored and compared byte for
   byte afterwards.
3. One sentence on the approximation, and why GOAP needs it, in
   `valley.gd`'s header, `docs/godot/valley.md` and both concept pages.
4. The two game refusals carry the new marker, and so does the
   saved-refused one beside them, which the screen cannot reach either:
   `offered()` is empty then. `valley.md` records the precedent for the
   record's refusals and calls the marker imprecise. A marker for "shown,
   untranslated by design" is left for a later wave.
5. `valley.md` says the rule is `ValleyGame.act`'s, with today as the
   last deed's day plus one, and that `DeedLog` reads two deeds on one
   day by T164's design.
6. New case `test_the_keys_can_do_every_deed_the_valley_can_offer`. Any
   two verbs on one place set one of its facts to opposite values, so at
   most one deed per place can change anything. The places, nine of
   them, do not outnumber `ValleyDemo.DEED_KEYS`.
7. Re-read Ultima IV's article: "a player can give beggars alms; doing
   so demonstrates Compassion". Both languages now quote that.
8. `three_sessions_test.gd` loads the save a second time, and every
   villager's plans match.

Re-run after the fixes, on the head rebased on d5bdc90a:
- `make test-godot-some SUITES=test/valley`: 35 cases, no SCRIPT ERROR.
- `make test-demo-overlays`, `make test-locale-screen`.
- `make lint-readability lint-translations-game lint-glossary lint-links lint-tasks lint-status lint-godot-checked lint-self-naming lint-demos lint-catalogue`.
