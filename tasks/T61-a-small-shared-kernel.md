# T61 — A small shared kernel: the board leaves `ai_core`

Size: M · Prereqs: T60 · Files: `godot/addons/ai_core/`, a new board module, `godot/game/`, `godot/demos/behaviour/`, `modules/`, `CLAUDE.md`, `README.md`

## Goal

T58's D4: `ai_core` is described as "types and interfaces, no logic" and
holds the tactical board's whole domain. Because it is the kernel, a change to
`BoardState` selects every module that uses anything in `ai_core` -- 19 of
them, measured, among them `ai_rts_core`, `rts`, `ai_search` and
`demo_racing`, none of which uses the board. This task leaves in `ai_core` only what more than one technique truly
shares, and gives the board a kernel of its own -- DDD's shared kernel kept
small, which is what makes the selector cheap.

## Diagnosis (measured 2026-10-20 on `5129bfc`)

What each `ai_core` class is used by, in code (comments excluded), after T60:

| class | used by |
|---|---|
| `BoardState`, `Unit`, `UnitType`, `Attack`, `Upgrade`, `ProductionOrder` | `game/tactical`, `game/league`, the shared `game/*.gd`, `demos/behaviour`; `game/stealth` uses `Unit` |
| `DecisionPolicy` | `game/tactical`, `demos/behaviour` (the league only in comments) -- its one method is `choose(state: BoardState, unit_id: int) -> Move`, so it is the board's port, not a shared one |
| `Move` | the board's callers (`main.gd:141`, `game/tactical`); in the views and in `ai_search`, `ai_steering`, `ai_rts_core` only in comments |
| `GridGraph` | `ai_search`, `ai_perception`, `ai_rts_core`, every grid game |
| `Pathfinder` | `ai_search` (and `learned_policy.gd`, the tactical adapter after T60) |

So the shared kernel is `GridGraph` and `Pathfinder`. This overrides T58's
sketch, which kept `Move` and `DecisionPolicy` in `ai_core`: measured, both
are typed on the board and used only by its games. Everything else is one
game's -- the tactical board, which the league and the behaviour demo play.

## Steps

1. **Measure first**: what `affected.py --paths` selects for a change to
   `board_state.gd` today. Recorded here beside step 5's.
2. **Decide the board's home**, a short ADR: a module of kind `kernel` at
   `godot/game/board/` (it is the examples' kernel, not a technique's), or an
   addon `ai_board`. Recommended: `game/board/` -- an addon is something a
   reader copies into their own game, and nobody wants this board without
   these examples. **Decided by the owner, 2026-10-20: `game/board/`**; the
   ADR records why. `check_addon_deps.py` and M5 decide which one the gates
   accept without a new rule.
3. **Move**, `git mv` with the `.uid` files and no content change, then the
   import: the six board types, `DecisionPolicy`, `Move`. The `res://`
   paths that follow, the manifests (`ai_core`'s `about` stops saying
   "and today the tactical board's state"), `make lint-modules`.
4. **Comments in addons that name a game's class go** (D4 counted five:
   `ai_planning` names `BoardState`, `PlannedBlue`, `LeveledBlue`;
   `ai_rts_core` compares itself with `BoardState`). An addon's header may
   say what it is *not* for, without naming a class the reader does not
   have. T58's other line for `ai_planning` -- "plans over its own
   `WorldState`, and the bridges in `game/` are its adapters" -- is already
   true in code (D4: it reaches nothing in `ai_core`); these comments are
   all that is left of it.
5. **Measure again.** The README's addon table and `CLAUDE.md`'s invariant 2
   ("only on `ai_core` (types and interfaces, no logic)") are re-read
   against what `ai_core` now holds.

## What was done (wave 67)

- Steps 1-5 as written; ADR 0021 records the decision. `ai_core` is now
  `grid_graph.gd` and `pathfinder.gd`. `interfaces_test.gd` was split, and
  the `DecisionPolicy` cases went to `godot/test/board/`.
- Measured, a change to `board_state.gd` selected **19 modules before, 10
  after**: `board`, `tactical`, `skirmish`, `league`, `demo_behaviour`,
  `stealth`, `menu`, and the tests of `ai_planning`, `ai_rts_core` and
  `game_shared`.
- **Found while measuring:** the first cut still selected 17, through
  `game_shared`, which every example depends on. Of its files only
  `unit_view.gd` uses the board, and only the tactical board and the
  skirmish draw with it. It is now owned by `tactical` (by path, the file
  stays where it is), and `game_shared` depends on `ai_core` alone.

## Acceptance

```bash
make check
```

```bash
ls godot/addons/ai_core/*.gd | xargs -n1 basename | sort | tr '\n' ' ' | grep -qx 'grid_graph.gd pathfinder.gd '
```

A change to the board no longer reaches the techniques it does not touch, the
RTS game, racing, steering, checkers or tic-tac-toe. (`ai_rts_core`'s *tests*
stay selected: T19's benchmark measures `BoardState`, on purpose.)

```bash
! printf 'godot/game/board/board_state.gd\n' | python3 scripts/affected.py --paths - | grep -qE '^selected:.*\b(rts|ai_search|demo_racing|demo_steering|checkers|tictactoe)\b'
```

```bash
python3 scripts/check_modules.py && python3 scripts/check_addon_deps.py
```

## Manual check

Open `godot/addons/ai_core/` and say whether two files are a kernel a reader
can hold in their head.

## Out of scope

- A* over a port that is not a grid (T62).
- Any change to the board's rules: the files move, nothing in them does.
