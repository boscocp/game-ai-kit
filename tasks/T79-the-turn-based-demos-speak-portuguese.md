# T79 — The turn-based demos speak Portuguese

Size: M · Prereqs: T78 · Files: `godot/locale/`, `godot/game/`, `godot/demos/behaviour/`, `godot/test/locale/`

## Goal

The owner, 2026-10-22: "localizar os jogos tbm pra deixar as demos com
opcao de mudar pra PT br." (the whole request is quoted in T74.)

T78 built the mechanism, the menu's switch and the gate, and translated
checkers and the search demo. This task applies the same mechanism to the
other turn-based games: `demo-skirmish`, `demo-tictactoe`,
`demo-tactical`, `demo-stealth` and `demo-behaviour`. There is nothing new
to decide: a demo here that needs a rule T78 did not foresee goes back to
T78's decisions and changes them there.

## Steps

1. **Each demo's strings** into its module's CSV: status panels, legends,
   buttons, help lines, end-of-game messages. The decision overlays
   (invariant 13) first -- they are the lesson.
2. **Mark each module translated**, so T78's static gate scans its files.
3. **The headless gate** (`make test-locale-screen`) adds these demos.

## Acceptance

```bash
python3 scripts/check_translations_game.py
make test-locale-screen
python3 scripts/check_readability.py
make lint-modules
make lint-tasks lint-status
```

## Manual check

In PT-BR, play a skirmish, noughts and crosses against MENACE, a tactical
match, the stealth hall and the four-brained guard: is every word on
screen Portuguese, and does every panel still fit? Code identifiers stay
English by the owner's rule (2026-10-26) and are not a finding: a planner's
step names (`cross_the_river_ram`, `build_ram`), facts (`point_free`), the
guide `h_max`, GOAP's goal `pressure`. Provoke a refusal too -- in the
tactical match, ask the workshop for a ram before the forge is bought -- and
read it in Portuguese. The tactical header ran off the window in English
before this task; it still does.
