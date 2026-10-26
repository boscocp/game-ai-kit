# T80 — The real-time and 3D demos speak Portuguese

Size: M · Prereqs: T78 · Files: `godot/locale/`, `godot/demos/steering/`, `godot/demos/racing/`, `godot/game/rts/`, `godot/game/fighting/`, `godot/game3d/`, `godot/test/locale/`

## Goal

The owner, 2026-10-22: "localizar os jogos tbm pra deixar as demos com
opcao de mudar pra PT br." (the whole request is quoted in T74.)

T78 built the mechanism, the menu's switch and the gate. This task applies
it to the real-time and 3D demos: `demo-steering`, `demo-racing`,
`demo-racing3d`, `demo-botmatch` (and T70's infiltration level),
`demo-rts` and `demo-fighting`. Nothing new to decide: a rule T78 did not
foresee goes back to T78's decisions.

## Steps

1. **Each demo's strings** into its module's CSV: HUDs, status panels,
   legends, the overlays' labels, help lines, end-of-match messages. Text
   rebuilt every frame (the racer's status, the bot match's HUD) is
   formatted from `tr()`'d templates, not concatenated.
2. **Units and numbers**: km/h, m, s stay as they are; a decimal separator
   follows the language only where the reader sees a number as prose (a
   lap time), never in a value a gate or a log parses -- say which in the
   demo's page.
3. **Text in the world** -- the racer's overlay labels, the bot match's
   `Label3D`s and map -- goes through the same keys, and T78's static gate
   covers `Label3D`.
4. **Mark each module translated**; the headless gate adds these demos,
   stepped with `--fixed-fps 60` as their own gates are.
5. **The menu**: every demo it lists now opens in the chosen language.

## Acceptance

```bash
python3 scripts/check_translations_game.py
make test-locale-screen
python3 scripts/check_readability.py
make lint-modules
make lint-tasks lint-status
```

## Manual check

In PT-BR, race the 3D racer, take over a bot in the bot match (T), and play
a fighting round and an RTS match: is every word on screen Portuguese, and
does every panel still fit?

Code identifiers stay English by the owner's rule (2026-10-26) and are not
a finding: the RTS plan's steps and facts (`build_lab`, `mortars_ready`), a
fighting move's name (`jab`, `side_kick`), the characters, the clone's case
key and features. The pad's legend line is still English. Provoke an RTS
refusal (a worker asked for a lab before a barracks) and read it in
Portuguese; in the fighting game, read a frame's events while paused.
