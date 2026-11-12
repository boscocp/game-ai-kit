# Review: wave/189-story-sifting

Pull request #150 -- T166, a chronicle that only tells: story sifting (wave 189).
Reviewer: a fresh context that wrote none of it (invariant 12).

## What was reviewed

- `git diff origin/main...origin/wave/189-story-sifting` (75 files), read against
  `tasks/T166-a-chronicle-that-only-tells.md` and CLAUDE.md (invariants, traps,
  "Readable by a person").
- `godot/addons/ai_sifting/` (`story_sifter.gd`, `sift_pattern.gd`, LICENSE, NOTICE),
  `python/gameaikit/sifting/sifter.py`, `spec/vectors/sifting/derive.py` and its 19
  vectors, the Godot and Python tests, `godot/game/valley/valley_chronicle.gd`,
  `chronicle.json`, the `ValleyGame` / `ValleyPanel` / `ValleyShown` / `valley.gd`
  changes, `demo_overlays.gd`, both technique pages, the glossary, `valley.csv`, the
  module manifests and the Makefile rule.
- Run in a throwaway worktree of the branch head (then removed):
  `make test-sifting-vectors` (19 vectors, 0 failures),
  `make test-godot-some SUITES="test/ai_sifting test/valley"` (58 cases, green, no
  SCRIPT ERROR), `python3 spec/vectors/sifting/derive.py --check` (exit 0),
  `lint-readability`, `lint-addon-deps`, `lint-tiers`, `lint-license`,
  `lint-no-training`, `lint-modules`, `lint-demos`, `lint-self-naming` (all green).
- Mutations planted in the GDScript sifter (each restored): unless bounds made
  inclusive; unless allowed to take a found event; variables not joined; one event
  found twice; the sifter writes `seen` into each event; `before` ignored; `after`
  ignored; `before` bound ignored; and inclusive bounds together with unless taking
  found events. Mutations planted in the Python twin: unless ignored; one event
  twice; not joined; `bool` counted as a number; the sifter writes into the
  record; unless allowed to take a found event; `after` off by one.
- Measured on the pinned engine: `ValleyChronicle.tell` over a record of a bridge
  pulled down and repaired on alternate days, and a record where a deed on day 2
  falls between a burning and the bread lost.

Held: the sifter's semantics match Felt's shape (event clauses, shared
variables, order, negation between/before/after), lexicographic order of matches,
distinct events per name, strict kinds (`1` = `1.0`, `false` != `0`) on both sides;
`derive.py` imports nothing from the repository and searches differently
(permutations, collect-then-check), so it is an independent oracle; the addon
depends on nothing (invariant 2), carries LICENSE and NOTICE (9); the chronicle is
derived every time and never saved, `DeedLog.deeds()` deep-copies, nothing in the
world reads the chronicle (6, ADR 0025); nothing new written outside the checkout
(8); the overlay carries `chronicle` and `test-demo-overlays` requires it (13, the
seeing a person's); the addon header gives what, complexity and when not to use
it; functions, nesting and file sizes within limits. Caught: not joined (GD 4
vector failures, Py 5), one event twice (GD 1, Py 1), writing sifter in GDScript
(suites, via the const record), `before` ignored (5), `after` ignored (2), `before`
bound ignored (3), inclusive bounds plus unless taking found events (3), unless
ignored (Py 3), bool as number (Py 2), `after` off by one (Py 1).

## Findings

1. **blocker -- the Python read-only test does not hold.** `python/tests/test_sifting.py`
   compares the sifted copy with the module-level `RECORD`, and
   `test_a_match_names_its_events_and_bindings` (and others, which run first
   alphabetically) hand `RECORD` itself to the sifter. A real sifter mutated to
   write `event["seen"] = True` in `bindings_if_matches` pollutes `RECORD` first, so
   the deep copy already carries the mark and `test_the_sifter_leaves_the_record_as_it_was`
   passes: `python3 -m unittest tests.test_sifting tests.test_sifting_vectors` is
   OK with a writing sifter. Run alone, the same test fails. The PR claims
   "read-only, by test, in both languages"; in Python it is only by test order.
   Fix: compare against a snapshot taken from a fresh literal (or `json.dumps`
   before and after), never against a constant other tests hand to the sifter; or
   make `RECORD` a function returning a new list. (The Godot side holds: `RECORD`
   is a `const`, a write is a SCRIPT ERROR that fails the suite, and the helper
   compares with a duplicate of the const.)

2. **should-fix -- the chronicle can freeze the game for seconds, contrary to the
   header's own cost claim.** `unless` is checked only after every event is found,
   so `third-time` enumerates every ordered triple of the same deed before
   rejecting all but the first. Measured on 4.7.2, `tell` over a record of a bridge
   pulled down and repaired on alternate days: 30 days (59 events) 54 ms, 60 days
   (119) 381 ms, 120 days (239) 2841 ms -- on the main thread, once per deed kept
   and once per day ended, and the record is a save that only grows across
   sessions. The header says "hundreds of events, two to four to find -- are
   cheap"; 239 events and three to find is not. Fix options: check an `unless`
   as soon as its bounds are both found (an `unless before: first` prunes at the
   first level, which makes `third-time` near linear), and/or tell over a bounded
   window of days; and correct the header's claim with the measured numbers.

3. **should-fix -- "after the deed of day N" names an unrelated deed when the
   effect takes two nights.** The valley's rules chain: burning the mill sets
   `mill.turning` false the next night and `market.bread` false the night after.
   Measured: burn the mill on day 1, dig a well on day 2, tell day 4 -> "The market
   ran out of bread on day 3, after the deed of day 2: dig a well in the square."
   The docs say it is an order, not a cause, but the player sees only the line,
   and the manual check asks whether it names a moment a person would retell; this
   one would be retold as the well emptying the market. Fix options: word the line
   so it cannot read as a cause, drop the deed from it, or carry the cause into the
   night event from the world's own `because` (the `why` the panel's chain already
   shows) and join on it.

4. **should-fix -- that an `unless` never matches one of the found events is a
   semantic nobody pins.** `_found_between` (both twins and `derive.py`) skips the
   found events. With the strict bounds every current pattern and vector uses, it is
   invisible: the mutation that drops the exclusion survives all vectors and suites
   in both languages, and so does the one that makes the bounds inclusive (masked by
   the exclusion). It matters for a pattern of three or more finds with an `unless`
   spanning the middle one. Felt/Winnow's negation does not exclude found events by
   default, so this is a choice, and `SiftPattern`'s doc and the technique pages do
   not state it (only a private comment does). Add a vector that tells the two
   readings apart and one sentence where `unless` is defined.

5. **nit -- vectors missing for edge cases the brief names.** No vector has an
   empty record (`nothing-matches-an-empty-list` sifts the full VALLEY record for a
   pattern with no match -- the name reads as an empty event list), none uses a
   variable twice within one `where`, and none has an `unless` whose variable no
   find binds (the documented "the others match anything"). All three agree between
   the twins and `derive.py` today; a vector each would keep them agreeing.

6. **nit -- the night events are shown raw.** `event_words` prints
   `market.bread became false` / `market.bread passou a false`: the fact and the
   value are not worded or translated, unlike the rest of the panel's sentences.

7. **nit -- the vectors runner does not check read-only.** A sifter that writes
   into the events passes `make test-sifting-vectors` (0 failures); only the unit
   suites catch it. One comparison of the parsed events before and after would make
   the conformance run hold it too, in both languages.

8. **nit -- `derive.py --check` runs nowhere.** Consistent with the other vector
   families, but the vectors' "derived, not hand-edited" claim rests on someone
   running it; `test_sifting_vectors.py` could call `derive.vectors()` and compare.

9. **nit -- `rebuilt` matches every earlier burning.** Barn burnt on day 1 and day
   2, repaired on day 3, tells two lines ("burned on day 1 ... rebuilt on day 3" and
   "burned on day 2 ..."). An `unless` of a burning of `?place` between would keep
   only the burning the repair answered, as the docs describe it.

## What was done about them

All nine taken, on the same branch, after a rebase on main (#148, #149).

1. **Fixed.** `python/tests/test_sifting.py` keeps the record as JSON text
   and builds a fresh one per test (`record()`); the read-only check
   compares the sifted list's JSON with that text. Planted again as the
   review did -- `event["seen"] = True` in `bindings_if_matches` -- the
   full run `python3 -m unittest tests.test_sifting tests.test_sifting_vectors`
   fails (17 failures, the read-only test among them); each file alone
   and together pass on the real sifter.
2. **Fixed, and measured.** An `unless` is now looked for as soon as its
   bounds are found and its variables bound (`ready_at`): a partial match
   is dropped when more events lie in the window than the finds still to
   come could take -- exact, never a guess, the rest left to the end. When
   the `unless` that drops an event ends at it and reads nothing it binds,
   no later event can pass either, and the search for it stops
   (`closes_later`). The next event is tried only where `before` lets it
   be (`_span`), and fixed or already-bound fields are compared before
   anything is copied. `no-bread` and `no-travellers` find the night
   first. Measured on 4.7.2, `ValleyChronicle.tell` over the review's
   record (bridge pulled down and repaired on alternate days): 5 ms at 30
   days (59 events), 11 ms at 60, 26 ms at 120 (239 events), 76 ms at 240,
   where the review measured 2841 ms at 120. Of the 26 ms, `no-travellers`
   is 14 (60 matches, each joining its night to an earlier deed) and
   `third-time` 6.5. The header's claim is replaced by these numbers, and
   says sift when the record changes, not every frame: `ValleyGame`
   already tells it again only when a deed is kept or a day ends. 26 ms is
   above a 16 ms frame at 120 days of a deed every day; a hash join or
   Winnow's incremental matching would remove the rest and is left for a
   later task.
3. **Fixed the preferred way: the cause is carried and joined.**
   `ValleyChronicle.events` follows each fact back to the deed that set it
   (through the rules that fired each night) and gives a night event
   `cause_day`, `cause_verb`, `cause_place`. `no-bread` and
   `no-travellers` join on those three, with no `unless`. The review's
   case is a test: burn the mill on day 1, dig the well on day 2, and the
   line reads "The market ran out of bread on day 3, because of a deed on
   day 1: burn the mill." The sentences say "because of" now.
4. **Fixed.** Two vectors: `unless-never-takes-a-found-event` (three
   burnings, an `unless` spanning the middle one: one match here, none
   under Felt's default) and `unless-waits-for-the-finds-still-to-come`
   (the window is ready before the find that takes its event, so an early
   check that guessed would drop the match). Whether the bounds are strict
   cannot be told apart from the exclusion -- the bounds are found events
   -- and the vectors' README says so. One sentence where `unless` is
   defined (`SiftPattern`), on both technique pages and in the README:
   the kit always excludes found events, Felt and Winnow do not by
   default. Planted sifters for both (an `unless` taking found events; an
   early check that guesses) fail their vector in both languages.
5. **Fixed.** `an-empty-record`, `a-variable-twice-in-one-event`,
   `unless-with-a-variable-of-its-own`; `nothing-matches-an-empty-list`
   is renamed `no-match-is-an-empty-list`. 25 vectors.
6. **Fixed.** `ValleyPanel.NIGHT` words each change a night can make
   ("day 3, the market had no bread"), translated in `valley.csv`; a
   test holds that every rule's change has its words.
7. **Fixed.** Both runners' `wrong_claims` sift a copy of the events and
   compare it afterwards; a planted marking sifter fails
   `every-later-repair` in both languages.
8. **Left as is, as asked.** Like every other family, `derive.py --check`
   is run by hand; the README now says no gate runs it.
9. **Fixed.** `rebuilt` has a second `unless`, a burning of the same place
   between; a test burns the barn on days 1 and 2 and repairs it on day 3,
   and one line is told, for day 2.

Also: `make demo-valley`'s help line names C. `lint-translations-game`
reports L1 on `godot/game/tactical/tactical.gd:147`, a line from #149 on
main, not from this branch.
