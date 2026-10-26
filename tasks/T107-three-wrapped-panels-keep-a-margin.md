# T107 — Three wrapped panels keep clear of the window's bottom

Size: S · Prereqs: T102 · Files: `godot/demos/behaviour/`, `godot/game/main.tscn`, `godot/game/main.gd`, `godot/game/rts/`, `godot/test/locale/locale_screen.gd`

## Goal

T102 taught `test-locale-screen` to measure a Label that wraps: its
rectangle inside the window's width, and its words ending the gutter
(24 px) above the window's bottom. Three Labels fail it, in pt-BR, as the
check steps each example, and T102 named them in `NOT_YET_FITTED` rather
than hide them or fix three other modules' layouts in its own wave:

- the behaviour demo's `Interface/Status`, words to y=711 in both
  languages: a strip pinned to the bottom edge;
- the skirmish's (`game/main.tscn`) `Interface/Status`, to y=716 in pt-BR
  (658 in English);
- the RTS's `Interface/Card/Info`, to y=741 in pt-BR and 721 in English:
  past the window -- in pt-BR a whole line is cut off, in English the last
  line is 1 px out. This one is a visible fault, not a margin: do it soon.

Each is named in `NOT_YET_FITTED` with the y it was measured at, as a
ceiling: one that gets lower fails the check meanwhile.

## Steps

1. Lay each out so its words end the gutter above the bottom in both
   languages, without dropping what the decision overlay shows
   (invariant 13): a smaller font, a wider panel, or a line moved to where
   there is room, as T102 did for the tactical match.
2. Take each out of `NOT_YET_FITTED`; leave the list empty, and keep the
   planted cases.

## Acceptance

```bash
make test-locale-screen
make test-demo-overlays
make test-godot-some SUITES="test/demo_behaviour test/skirmish test/rts"
```

## Manual check

In English and in PT-BR, open the behaviour demo, the skirmish and the
RTS with a unit selected: does each panel's last line keep a margin from
the window's bottom edge?
