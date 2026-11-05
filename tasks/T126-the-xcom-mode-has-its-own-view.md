# T126 — The XCOM mode's presentation moves into a mode view

Size: M · Prereqs: T85 · Files: `godot/game/tactical/`, `godot/test/tactical/`, `godot/game/squad/`, `godot/test/squad/`, `docs/godot/squad.md`

## Goal

The owner ratified on 2026-11-05 ("todas conforme recomendado") the
recommendation of STATUS's 2026-11-04 item B19: move the presentation
hooks to a mode-view object before T87 and T88. T87 has landed (wave
125), so this task comes before T88, and T88 now waits on it.

`TacticalRuleset` had about 25 answers and `tactical.gd` was 832 lines
when T85's review counted them (`docs/reviews/119-xcom-style-mode-you-can-play.md`,
finding 4). `tactical.gd` is 860 lines now: T87 added a six-line hook
(PR #69, decision 1), and noted this refactor was not done. The hooks the
review named are the presentation ones: `fog`, `dashes`, `odds`,
`tint_at`, the statuses and `legend`. They are about what the screen
shows, not what a walk or a shot does. Every mode added to the ruleset
adds its own.

## Decisions written down first

_The owner ratified only the item quoted above. The decisions below are this session's proposal, written on 2026-11-05; the wave that takes the task confirms them, or brings them back to the owner._

- **Two objects per mode.** The ruleset keeps the rules: start, walk,
  attack, the news, the winner. A mode view holds what the scene asks to
  draw and write. The scene is handed both by whoever opens it, as it is
  handed the ruleset today, so `tactical` still never names `squad`.
- **Behaviour does not change.** Every scene test passes unchanged, and
  so do the matches and vectors. A test that changes is a finding to
  explain, not to fix silently.
- **Measured, not promised.** The task writes down `tactical.gd`'s
  lines and the ruleset's answers before and after. If moving a hook
  makes the scene harder to read, it stays, and the page says why.

## Steps

1. List the ruleset's answers, and mark each one rule or presentation.
2. The mode view's interface, with the Advance Wars and XCOM views.
3. Move one hook at a time, the suites green after each.
4. The counts before and after, on the page.

## Acceptance

```bash
make test-godot-some SUITES="test/tactical test/squad"
make test-squad-match
make test-squad-vectors
make test-demo-overlays
make test-replay
python3 scripts/check_demos.py
python3 scripts/check_readability.py
make lint-modules
make lint-tasks lint-status
```

## Manual check

Play both modes, with V on and off: does anything on screen differ from
before? Then read `tactical.gd` top to bottom: is it easier to follow?

## Notes

- Shares `godot/game/squad/` and `godot/test/squad/` with T88 and T96.
  T88 now lists this task among its prereqs. T96 does not wait on it;
  they do not run side by side.
- T124 changes one of these hooks (V's default); run the two one after
  the other.
