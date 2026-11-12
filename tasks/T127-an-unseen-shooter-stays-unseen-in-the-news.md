# T127 — An unseen shooter stays unseen in the news

Size: S · Prereqs: T110 · Files: `godot/game/squad/`, `godot/test/squad/`, `godot/game/tactical/`, `godot/test/tactical/`, `godot/locale/squad.csv`, `docs/godot/squad.md`

## Goal

The owner ratified on 2026-11-05 ("todas conforme recomendado") the
recommendation of STATUS's 2026-11-04 item B24: a follow-up task for a fog
hole older than T110, found by its review.

In the XCOM mode, an unseen blue mortar (sight 6, reach 7) can shoot a
red piece. The news names the mortar and its cell, though red cannot see
it: "blue mortar at (7, 4) shot red shield at (1, 4): 10% (cover 40),
missed" (`docs/reviews/124-the-tactical-news-keeps-its-words-as-keys.md`,
"For the owner", item 1). `_with_computer_news` and `computer_status` in
`tactical.gd` pass the news through with no fog. T85 already words "next"
as "a piece you cannot see acts" (`squad_status.gd`); the shot that
follows then says what that piece was and where it stood.

## Decisions written down first

**Decided by the owner, 2026-11-11: word the news from the person's
fog.** A shooter the person cannot see is worded as "a piece you cannot
see shot ...", with no type and no cell; the rules and the recording keep
the full line. The rules do not change, so the squad's measured strength
(the vectors, the search game, the duel) stays valid. Built in wave 190:
the chance and the cover are left out too, since a mortar's 10% and the
side its cover faces would name it and place it. XCOM (2012) does not
settle it -- its designer called enemies shooting "from behind the fog of
war" a fault of the 1994 original he set out to remove -- so the mode
words the situation it has honestly (`docs/godot/squad.md`, "Playing it").

_Before that, the owner had ratified only the item quoted above, and left
the choice between the two answers below to the task._

The recommendation offered two answers. The task chooses one, with its
reasons, and brings it back to the owner if the reading of XCOM is
unclear:

- **Word the news from the person's fog.** A shooter the person cannot
  see is worded as "a piece you cannot see shot ...", with no type and no
  cell. The `Sentence` T110 made is worded where it is shown, so the
  person's fog can choose the words there. The rules and the recording
  keep the full line.
- **A shot reveals its shooter.** The shooter's cell is seen by the side
  it shot, from that shot on, under the mode's own sight rules. Then the
  line is honest as it stands. This changes the rules, so the squad's
  vectors, the search game (T87) and `SquadUnseenCheck` are read again.

Either way:

- **A test that fails today**: the mortar case above, built as the review
  built it, asserting that red's news names no unseen piece (the first
  answer) or that red sees the mortar after the shot (the second).
- **Both languages**, since the line is a `Sentence`.

## Steps

1. Read how XCOM (2012) treats a shot from an unseen enemy, and write
   the answer, with its source, on the page.
2. Choose, as above, and write the failing test first.
3. The change, and the news test in pt-BR and English, both ways, as
   T110's tests do.

## Acceptance

```bash
make test-godot-some SUITES="test/squad test/tactical"
make test-squad-vectors
make test-squad-search-vectors
make test-squad-match
python3 scripts/check_translations_game.py
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Play the XCOM mode as red until an unseen mortar shoots: does the news
tell you only what red could know?

## Notes

- Shares `godot/game/squad/` and `godot/test/squad/` with T88, T96,
  T117, T124, T125 and T126. It does not run beside any of them.
- Shares `godot/game/tactical/` with T126 and T124; run one after the
  other.
- The second answer changes the rules T88 compares the searches on. If
  it is chosen, T88's positions are read again after it.
