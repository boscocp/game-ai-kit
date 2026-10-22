# T78 — The real-time and 3D demos speak Portuguese

Size: M · Prereqs: T77 · Files: `godot/locale/`, `godot/demos/steering/`, `godot/demos/racing/`, `godot/game/rts/`, `godot/game/fighting/`, `godot/game3d/`, `godot/test/locale/`

## Goal

The owner, 2026-10-22: "localizar os jogos tbm pra deixar as demos com
opcao de mudar pra PT br." (the whole request is quoted in T74.)

T77 built the mechanism, the menu's switch and the gate, and translated
the turn-based games. This task applies the same mechanism to the rest:
`demo-steering`, `demo-racing`, `demo-racing3d`, `demo-botmatch`
(and the infiltration level of T70), `demo-rts` and `demo-fighting`.
There is nothing new to decide: a demo here that needs a rule T77 did not
foresee goes back to T77's decisions and changes them there.

## Steps

1. **Each demo's strings** into its module's CSV: HUDs, status panels,
   legends, the overlays' labels, help lines, end-of-match messages.
   Text rebuilt every frame (the racer's status, the bot match's HUD) is
   formatted from `tr()`'d templates, not concatenated.
2. **Units and numbers**: km/h, m, s stay as they are; decimal separators
   follow the language only where the reader sees a number as prose (a
   lap time), never in a value a gate or a log parses -- say which in
   the demo's page.
3. **The 3D demos' text on the road or in the world** (the racer's
   overlay labels, the bot match's map) goes through the same keys.
4. **The gate's Godot half** (T77) adds these demos. The bot match and the
   racers are stepped headless with `--fixed-fps 60`, as their own gates
   are.
5. **The menu**: every demo it lists now opens in the chosen language.

## Acceptance

```bash
python3 scripts/check_translations_game.py
make test-godot-some SUITES="test/locale"
python3 scripts/check_readability.py
make lint-modules
make lint-tasks lint-status
```

## Manual check

In PT-BR, race the 3D racer, take over a bot in the bot match (T), and
play a fighting round and an RTS match: is every word on screen
Portuguese, and does every panel still fit?
