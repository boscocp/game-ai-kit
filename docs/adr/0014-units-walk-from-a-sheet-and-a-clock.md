# 0014 — Units walk from a sheet and a clock, in the one view that draws them

Status: accepted · 2026-10-14 (decided in T33)

## Context

Until T33 every piece on the tactical board was one still picture, and a
move made it vanish from one cell and appear on another. The owner wants to
see units move and judge it in the game. T33 asks for frames from a sheet,
movement along the route, a bob for machines, and a `walk` kind in the
generator -- packs first, the generator second, as T9 and T31 did.

Three things had to be decided: where the frames come from, how the game
draws them, and what a generated sheet may be.

## Decision

**The frames come from Puny Characters** (Shade, OpenGameArt, CC0): the
first pack found that has, for small figures, a walk cycle in every
direction *and* a red and a blue copy of the same figure. Its `Soldier` is
the skirmish board's soldier, its `Warrior` the tactical shield. Each sheet
is committed byte for byte and listed in `LICENCES.md` with its sha256, as
T9's were. Ninja Adventure (CC0) was looked at first; its download page
could not be fetched by a script, and the author's own repository holds a
blue and a green figure but no red one.

**Only figures on legs walk.** The truck, the gun, the boat and the ram keep
their still pictures and bob as they roll, two frames, in code: drawing
four machines a walk cycle would be drawing legs on a truck. Buildings
neither walk nor bob.

**One view, one clock.** `UnitView` keeps drawing every unit in one `_draw`.
It holds a clock that only `advance` moves, a `UnitWalk` for each unit on
its way somewhere, and the facing each last walked in. The scenes tell it
which unit walked where -- red's click, and blue's decision once played,
along the route the pink line showed. A walk whose unit is no longer bound
for its end (undo, a new game) is dropped. The rules are untouched: the
state still changes at once; only the picture of it takes 0.12 s a cell.

The alternative was a node per unit with `AnimatedSprite2D` and a tween.
That is how a real game would do it, and it moves the timing into the
engine, where a headless test cannot stop it halfway to look. Here the
clock is a number, so the acceptance -- "drawn between cells partway
through its move" -- is an assertion, not a screenshot.

**Advance Wars' conventions, kept.** Figures march on the spot at rest,
faster on the move, and stand still, greyed, once spent. Before its first
walk a figure faces the other side.

**A sheet's table travels with where it came from.** The pack's sheet is 24
frames by 8 facings; the generator's is the walk LoRA's 4 by 4. `UnitSheet`
holds the table, with a constructor for each layout, and `Art.table_for`
picks by whether the file drawn is the committed one or a person's own.
Reading one through the other's table draws slices of the wrong frames.

**Generated sheets are never committed.** The walk LoRA is Apache-2.0, but
its card credits its training sheets to a CC BY 4.0 template. Whether a
sheet it makes owes that attribution is not settled here, so its sheets stay
in the gitignored folder, a person's own, and no example is committed. The
model is FLUX.2 klein *base* (the card: the distilled model "ruins the
quality of the pixels"), borrowing the distilled model's text encoder,
which is the same file.

## Consequences

- `pictures()` now names a sheet for a figure on legs, not its still
  picture; the still picture stays the fallback, and the legend still shows
  it.
- The decision overlay is unchanged: blue's route is drawn before it is
  played, and the walk then follows that route.
- What a headless run holds is the frame and the point `_draw` is handed,
  never the picture. Whether walking units read better than still ones is
  the manual check, and the owner's.
- A generated sheet that comes out wrong is a person's to regenerate with
  another seed; the game does not judge it beyond `fits`, which checks only
  that its size divides into its table.
