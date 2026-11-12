# Conformance vectors: story sifting

<!-- doc-meta
half_life: structure
verified_on: 2026-11-11
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: a pattern's keys, the order matches come in, what counts as the same value, or the rules P1-P5 change
teaches: none
-->

> One story sifter, two languages, and the files that say they found the
> same moments.

`ai_sifting`'s `StorySifter` (GDScript) and `gameaikit.sifting` (Python)
match the same patterns the same way. Each vector is one `.json` file: a
record of `events` (dictionaries, in the order they happened), a `pattern`,
and the claims -- `refused`, the rule a broken pattern breaks or `""`, and
the `matches` in order, each naming which event of the record each name
found (`events`, by index) and what each variable was bound to
(`bindings`, without its `?`). Both sides check every claim against the
file, never against each other: `make test-sifting-vectors` on the GDScript
side, `make test-python` on the Python side.

The rules the two follow, and that a third implementation must follow to
agree:

1. an event matches a `where` when it has every field named, a fixed value
   the same, a variable either unbound -- it is bound then -- or bound to
   the same value;
2. two values are the same when they are the same kind -- text, a number,
   true or false -- and equal: `1` and `1.0` are one number, `false` is not
   `0`;
3. the events found for one match are distinct events;
4. each `before` pair is found in that order in the record;
5. an `unless` event, matched with the match's bindings (a variable it
   binds alone matches anything), must not lie strictly between the events
   named `after` and `before` -- from the start, or to the end, when one is
   left out -- unless it is one of the events found;
6. matches come in lexicographic order of their events' indices, taken in
   the order the pattern names them.

A pattern is refused, matching nothing, by the first rule it breaks:

| rule | what is wrong |
|---|---|
| P1 | a key beyond `name`, `find`, `before`, `unless`; no name; nothing to find |
| P2 | an event to find that is not `{as, where}`, or two with one name |
| P3 | a `before` pair that is not two different names of events to find |
| P4 | an `unless` without `where`, with another key, or bounded by no event to find |
| P5 | a `where` that is not a dictionary, or a value that is not text, a number or true or false |

## Where the matches came from

From neither implementation: `derive.py`, importing nothing from this
repository, wrote them. The sifters search depth first, an event at a time;
`derive.py` tries every ordered choice of distinct events --
`itertools.permutations` -- and keeps the ones that fit, which come out in
the same lexicographic order. `python3 derive.py --check` fails when a file
would change.

One by hand, `unless-between-keeps-the-next-one`. The record's bridge comes
down at events 4, 7, 9 and 11 and is repaired at 5, 8 and 10. The pattern
finds `down` (pull_down ?place), then `up` (repair ?place), `down` before
`up`. Without the `unless` that is every repair after every pulling down:
(4, 5), (4, 8), (4, 10), (7, 8), (7, 10), (9, 10) -- six, the file
`every-later-repair`. The `unless` refuses a repair of the same place
strictly between the two: (4, 8) has 5 between, (4, 10) has 5 and 8,
(7, 10) has 8. Three stay, (4, 5), (7, 8) and (9, 10): each pulling down
and the repair that answered it.

## The files

- `one-event-every-match`, `nothing-matches-an-empty-list`: one event to
  find, and none found.
- `a-shared-variable-joins-two-events`, `without-before-both-orders`: a
  variable joins two events; without `before`, the reverse order matches
  too.
- `every-later-repair`, `unless-between-keeps-the-next-one`,
  `unless-after-never-again`, `the-third-time`, `a-deed-and-what-followed`:
  `unless` between two events, after one, before the first, and between
  three.
- `a-flag-is-not-a-number`, `a-whole-number-is-one-number`,
  `a-missing-field-does-not-match`, `two-events-are-two-events`: rules 1-3
  at their edges.
- `refused-*`: one pattern for each of P1 to P5.
