# T102 — The tactical match's header and status fit the window

Size: S · Prereqs: T80 · Files: `godot/game/tactical/`, `godot/test/locale/locale_screen.gd`, `godot/test/tactical/`

## Goal

T80's width check in `test-locale-screen` found the tactical match's
header running off the 1280-pixel window, to x=2029 in English and
x=2432 in pt-BR: one long line, centred, that does not wrap. It is a
layout fault, not a translation one, so T80 named it in
`locale_screen.gd`'s `NOT_YET_FITTED` rather than hide it. T80's review
found the status panel at zero margin in pt-BR as well.

## Steps

1. Lay the header out so it fits in both languages: wrap it inside its
   rectangle, or split what it says between the header and the status,
   without covering the End turn and Undo buttons.
2. Give the status panel a margin in pt-BR, measured by the same check.
3. Remove the header from `NOT_YET_FITTED`; leave the list empty, and
   keep its planted case.

## Acceptance

```bash
make test-locale-screen
make test-demo-overlays
make test-godot-some SUITES="test/tactical"
```

## Manual check

In English and in PT-BR, open the tactical match: is the whole header
readable, and does the status keep a margin from the window's edge?
