# T108 — The pad's legend keeps its height

Size: M · Prereqs: T103 · Files: `godot/game/legend.gd`, `godot/game/pad_as_keys.gd`, `godot/game3d/botmatch/`, `godot/demos/racing/`, `godot/game3d/racing/`, `godot/game/maze/`, `godot/test/menu/demo_overlays.gd`, `godot/test/game_shared/`, `docs/godot/localisation.md`

## Goal

T103 gave the pad's line words in both languages and broke it at the
legend's width, and measured what it did not fit: with a pad connected,
a legend's lines run past the window or over the panel beside them. No
gate measures how far down a legend goes. Measured with the pad planted
(`PadAsKeys.planted`), as written in `docs/godot/localisation.md`'s T103
section and `docs/reviews/109-the-pad-legend-speaks-portuguese.md`:

- the bot match's legend ends at y=740, in a 720-pixel window;
- the 2D racer's at 254 in English and 274 in pt-BR, over its status,
  which starts at 200;
- the 3D racer's at 212, over its status at 164;
- the maze's at 220, touching its `Decision` label at 220.

It was so before T103, with a real pad. The owner decided on 2026-10-29
that it is a task of its own, with a gate (the review's recommendation).

## Decisions written down first

- **The gate measures, the eye does not.** For every example with a pad,
  in English and in pt-BR, with the pad planted: the legend's last line
  ends the gutter (24 px, `BoardLayout.GUTTER`, as `locale_screen.gd`'s
  `BOTTOM_MARGIN`) above the window's bottom, and at least 8 px above the
  top of any visible Label or panel below it in the same column -- a
  margin, not mere non-overlap, so a legend ending exactly where its
  neighbour starts (the maze's, 220 against 220) fails. 8 px is chosen,
  not measured: about half a 13-16 px line, enough to read two blocks
  as two; the task may change it with a reason written down. It lives where
  the pad is already planted in both languages, `demo_overlays.gd`
  (`make test-demo-overlays`), or in a target of its own if the reading
  finds that clearer -- either way a command with an exit code.
- **Planted cases**: a legend whose last line ends past the window, and
  one that ends over its neighbour's rectangle while inside the window.
  Both must fail the gate; without the second, a gate that measures only
  the window passes the racers.
- **The fix keeps every line** (invariant 13: the legend is how a person
  learns the keys): a legend moved to where there is room, two columns, a
  smaller font, or the status moved -- per example, as T102 and T107 did,
  measured, never by hiding the pad's line.

## Steps

1. Read `legend.gd`, `pad_as_keys.gd` (`add_to`, `legend_lines`,
   `planted`), `demo_overlays.gd` and the four scenes' layouts.
2. Write the gate and its two planted cases; see it fail on today's four
   examples with the numbers above (the maze's by the 8 px margin).
3. Lay out each of the four so the gate passes in both languages.
4. `docs/godot/localisation.md`: the T103 section's "Not fitted" becomes
   what was done, with the measured ends.

## Acceptance

```bash
make test-demo-overlays
make test-locale-screen
make test-pad
make test-godot-some SUITES="test/botmatch test/demo_racing test/racing3d test/maze"
python3 scripts/check_readability.py
```

## Manual check

With a real pad connected, in English and in pt-BR, open the bot match,
the 2D racer, the 3D racer and the maze: does each legend end inside the
window, clear of the panel beside it, every pad line still there?
