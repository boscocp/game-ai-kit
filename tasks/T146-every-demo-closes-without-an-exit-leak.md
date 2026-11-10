# T146 — Every demo closes without an exit leak

Size: S · Prereqs: T138 · Files: `scripts/check_exit_leaks.py`, `Makefile`, `godot/game/squad/`, `godot/test/squad/`, `godot/demos/behaviour/`, `modules/menu.json`, `modules/squad.json`, `docs/godot/exit-leaks.md`

## Goal

T138 (wave 146) found the RTS leaving 15 scripts alive at exit. It worked
round the trigger it observed in `rts.gd`, and added `make test-rts-exit`,
which runs `scripts/check_exit_leaks.py` on that one scene. The engine
mechanism was not identified, and the leak depends on which script
compiles first. So another demo can start leaking whenever its first
script changes, and nothing would say so.

The review of PR #100 measured two cases:

- Every scene under `godot/game/` and `godot/menu/` closes clean today.
- `game/squad/squad_ruleset.gd` and `game/squad/squad_map_words.gd`,
  loaded alone, each leak 18 objects and 17 resources. Neither names
  `GakRtsController`, and no scene loads either one first today.

`docs/godot/exit-leaks.md` holds what is known.

## Decisions written down first (the owner confirms in review)

- The exit check runs over every scene in `check_demos.py`'s list, not a
  second hand-kept list. Measured on 2026-11-06 (wave 146, a Ryzen 5 9600X,
  12 threads): `check_exit_leaks.py` on the RTS scene, the planted leak
  included, took 0.70 s in each of three runs.
- The gate is `make test-demos-exit`, named now so the acceptance below is
  a command. Step 3 may rename it, and then the acceptance changes with it.
- The planted leak runs once per gate run, not once per scene.
- The squad leak is measured with `--verbose`, and its trigger is found
  the way T138 found the RTS one: a scratch copy, bisected. It is fixed
  where it is made if the trigger is in the game. If it is not, it is
  written down, as T138's was.
- Each module keeps its own gate (M7): one `make` target per scene, or one
  target that the affected selector maps to the scenes changed. The
  decision is written down before the code.

## Steps

1. Run `check_exit_leaks.py` on every demo scene, and list what leaks.
2. Bisect the squad scripts' leak, and fix or record it. The case stays
   as `godot/test/squad/exit_ruleset_first.tscn`, a scene whose script
   loads `squad_ruleset.gd` before anything else, and is read by the
   acceptance below. If the leak stays recorded and not fixed, the
   acceptance says so, expecting exit 1.
3. The gate over every scene, with its module selection.

## Acceptance

```bash
python3 scripts/check_exit_leaks.py --self-test
make test-demos-exit
python3 scripts/check_exit_leaks.py res://test/squad/exit_ruleset_first.tscn
make test-rts-exit
make lint-modules
make lint-tasks lint-status
```

## Manual check

Open `make demo-tactical MODE=squad`, play a turn and close the window.
Do the last lines hold no `leaked` and no `still in use`?

## Notes

- Opened by the review of PR #100 (wave 146, finding 3), at the
  coordinator's word.
- Wave 166, step 1. Every scene in `check_demos.py`'s list closed clean
  but one: `demos/behaviour/behaviour_demo.tscn` leaked 36 objects and 27
  resources. The review of PR #100 had measured `game/` and `menu/` only.
  It is fixed by `GuardBrain.every()`, which names the four brains; in the
  scene that function alone is enough, even uncalled. A second change,
  `BrainPanel` reading `thinking()`'s keys, fixed only the script loaded
  alone, was held by no gate, and was reverted after the review of PR #124
  (finding 1). `docs/godot/exit-leaks.md` has the table.
- Step 2. The squad trigger was in the game, `is SearchingSquad` in
  `SquadRuleset.build_controller`, and is fixed where it was made
  (`SquadRoster.for_the_scene`). So the acceptance expects exit 0 from the
  case scene, and `make test-squad-exit` holds it. Against the old ruleset
  it exits 1 (measured). The engine mechanism is still not identified.
- Step 3, the module decision, a third option beside the two written down
  first (review of PR #124, finding 4). **The owner approved it on
  2026-11-10:** one `make test-demos-exit`, owned by `menu`, sweeping all
  17 scenes (and, since the review, the extra modes). `make test-demos-exit` is one target, owned
  by `menu`, the module that owns the list (`test/menu/demo_overlays.gd`)
  and already owns `test-demo-overlays` over the same scenes. `menu`
  depends on every example module, so a change to any example selects it.
  It runs all 17 scenes, not only the changed one: about 10 s (9.3 s on
  the machine of the decision above, one run). One target per scene would
  have meant 16 new targets and 16 manifests to edit, and a second list
  kept by hand, which the first decision rules out.
- `make test-rts-exit` stays, though the RTS is in the sweep: it is in the
  acceptance, and `rts` owns it.
- After the review of PR #124: the sweep also runs every extra mode that
  `test/menu/demo_overlays.gd`'s `MODE_REQUIRED` names, through the menu
  (today the squad mode, `--open=demo-tactical --mode=squad`), so the
  manual check's mode is swept too. A leak in one run wins over a kill in
  another (`sweep_code`, finding 2 and nit 7). Measured 15.3 s at load 18
  in the review, about 10 s quiet.
