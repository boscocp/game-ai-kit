# Review: wave/119-xcom-style-mode-you-can-play

T85: the XCOM-style mode played from the tactical card and scene. The
card's `modes` and the menu's mode button and `--open`/`--mode`; the
seam's new answers (`title`, `what_this_is`, `fog`/`TacticalFog`,
`dashes`, `odds`, `tint_at`, `reveals`, the two statuses, `legend`);
`SquadStatus`, `SquadLegend`, `IntentView`'s fog, dash, odds and weighing;
`WeighedSquad` and `weighing.json`; `make test-squad-match`; C9 for modes
in `check_demos.py`; `squad.csv`.

A fresh context reviewed PR #63 at head 10c7956. It only read the code
and ran gates in a throwaway worktree. The probes it planted are
described below so that anyone can rerun them. Nothing was committed.

**Verdict: changes requested, two blockers.** There are two blockers,
five should-fix findings, six nits and five items for the owner.

## What was run (head 10c7956, throwaway worktree)

- `make test-godot-some SUITES="test/squad test/tactical test/menu"`:
  418 cases, 0 failures, and no `SCRIPT ERROR` from them. The tactical
  digests and the Advance Wars tests are unchanged.
- `make test-squad-match`: 100/100 as red and 100/100 as blue. It also
  prints **13 and 17 decisions refused**, which the gate does not hold
  (see S2).
- `make test-decisions`, `make test-locale-screen` and
  `make test-demo-overlays` (en and pt_BR) all pass. The three
  `free` on Nil errors in test-demo-overlays come from the existing
  planted case "a crashing step".
- `python3 scripts/check_demos.py` and `--self-test` (58 cases, 0
  failures), `check_translations_game.py`, `check_readability.py`,
  `check_modules.py` (36 modules), `make lint-tasks` and
  `make lint-status` all pass.
- In Advance Wars, every new hook's default is equivalent to the old
  code:
  - `legend()` gives `TacticalLegend.entries(TacticalRules.unit_types())`,
    and the scene's `_types` is the same table.
  - `tint_at` falls back to `tint(state, other side)`, which is `threat()`.
  - `fog` is null, so `_persons_board()` is `state`.
  - `odds` and `dashes` are empty, and `reveals` is false.
  - `what_this_is` is `tr(WHAT_THIS_IS)`.

## Findings

### Blockers

1. **A fog hole: a walk's refusal names the hidden enemy's cell and id.**
   The scene plans the person's walk on the side's view
   (`tactical.gd:558`, `walks_for(_persons_board(), …)`). It then judges
   the walk on the full board and shows the board's words
   (`tactical.gd:564`, `ruleset.why_walk_refused(state, move)`).
   `SquadRuleset.why_walk_refused` (`squad_ruleset.gd:56`) is
   `state.why_refused(move)`, which says "(x, y) is occupied by unit N"
   (`board_state.gd:363`). A click on a hidden cell, or on a walk whose
   route crosses one, therefore tells the person that an enemy stands
   there and which one. Any cell in reach can be probed this way, for
   free, and Z is not involved at all. T84's blocker was the same hole
   in the shot ("a refusal that names an unseen enemy"), and the shot's
   refusal was fixed then. The walk's refusal was not.
   *Reproduce:* mount the scene with `play_in_modes([AW, Squad], 1)`.
   Set `state` to a red runner on (0, 0) and a blue shield on (2, 2),
   a cell in its reach that red does not see. Select unit 1 and call
   `click_cell(Vector2i(2, 2))`. The status ends with
   `refused: (2, 2) is occupied by unit 2`. The computer has the same
   root cause: `WeighedSquad` plans its walks on its view, so its walks
   through unseen pieces are refused. Those are the 13 and 17 refusals
   in the match run.
   *Fix:* the squad ruleset words a walk that is blocked by a piece the
   walker's side does not see as one sentence that names nothing, as
   `SquadCombat.unseen` does for the shot. A rule change is the
   alternative: the walk stops at the last free cell and reveals the
   piece. That choice is the owner's (O1). Either way, add a planted test
   in `squad_scene_test.gd` that asserts the status names no hidden cell
   and no hidden id.

2. **The person's status is blank whenever nothing is in hand or the
   piece in hand has shot.** At `squad_status.gd:36`,
   `var shots: Array[String] = shot_lines(…) if can_attack else [] as Array[String]`
   raises `SCRIPT ERROR: Trying to assign an array of type "Array" to a
   variable of type "Array[String]"` on the `else` branch. A ternary
   does not keep the typed literal's type. `text()` aborts and the
   status becomes "". This happens after every last walk of a turn
   (`_select_next_unspent` leaves nothing in hand), after a revealing
   walk, and on Z when nothing is in hand. These are the moments when
   the status should say "every unit has moved: space ends the turn" or
   give the refusal. No suite reaches this branch: the three suites run
   with no `SCRIPT ERROR`, so this is exactly the CLAUDE.md trap.
   *Reproduce:* in the scene in XCOM mode, set red runner (1, 4) and
   blue shield (8, 4), select 1, call `click_cell(Vector2i(3, 5))`,
   then `_press(KEY_Z)`. The log shows the error at `squad_status.gd:36`
   and `_status.text` is empty.
   *Fix:* use an `if` block or `var shots: Array[String] = []`. Add a
   scene test that reads the status with nothing in hand.

### Should-fix

1. **The does-not-cheat property sees only where unseen pieces stand.**
   `weighed_squad_test.gd:127` (`_unseen_moved`) moves unseen enemies
   and re-seeds the dice. It never changes an unseen enemy's health,
   kind or presence. Each decision is also asked of a fresh controller,
   so the memory path (`_memory`, `last_seen`) is never under the
   check. Measured on the same 60 positions:
   - 57 are non-trivial;
   - the planted `SeesEverything` is caught on 45;
   - a planted `ReadsUnseenHealth`, which holds when the enemy's total
     health read off the full board is odd, is caught on **0**.

   The planted assertion is only `caught > 0` (`:55`).
   *Fix:* also vary an unseen enemy's health, and remove one unseen
   piece. Ask a second decision after a first look, so the memory is
   under the check. Pin the caught count, or a floor on it.

2. **Refused decisions are printed and not held.** `squad_match_runner.gd:44`
   prints 13 and 17 refusals per seat. A walk the enemy cannot make is
   a lost action, and it is invisible to the bar. The PR body and
   `docs/godot/squad.md` do not mention it. Fixing B1 changes this
   number. Either gate it (for example "refused ≤ N", or 0 once the
   walk rule is decided) or write it down as measured.

3. **With V off, the computer's turn still leaks what the person cannot
   see.**
   - `tactical.gd:698-700` drops the decision of a piece the person
     cannot see. A *seen* piece walking into the fog, however, has its
     whole pink path drawn to a hidden destination.
   - `SquadStatus.computer_text` (`squad_status.gd:57-61`) ignores V and
     the fog. It prints "next (drawn in pink): unit N …" with the
     reason even for a piece the person cannot see. That reason
     includes "{steps} to the nearest enemy it knows of" and the danger
     at the cell it walks to. It also says "on the board, every option
     it weighed … V hides them" while V has hidden them.

   *Reproduce:* XCOM, S, V. Step until a blue piece out of red's sight
   is next, then read `_status.text`.
   *Fix:* hand `computer_status` the fog on screen. Word an unseen
   piece's turn as "a piece you cannot see acts". Clip a drawn walk to
   the cells the person sees.

4. **"It can still attack" after a dash** (`tactical.gd:534`, `_moved_already`).
   `can_attack` is `not _turn.has_attacked(unit.id)`. A piece that
   dashed is spent and has not attacked, so clicking it again says
   "this runner has moved this turn; it can still attack an enemy in
   reach". In this mode it cannot (`SquadCombat.can_shoot` is false).
   *Reproduce:* in XCOM, walk a piece to an amber cell, then click it
   again.
   *Fix:* ask the ruleset, for example
   `ruleset.why_attack_refused`-based or a `can_still_act(state, unit)`
   hook defaulting to today's answer. While there, "attack" reads as
   "shoot" in this mode.

5. **The undo rule is tested only below the scene.**
   `squad_scene_test.gd` ("a walk that shows an enemy cannot be taken
   back") asserts `SquadRuleset.reveals`, not that Z in the scene
   refuses. My probe confirms the scene does refuse. Two more things:
   - The refusal reads "nothing to take back this turn" while the walk
     is right there. Use the sentence `_last_event` already has.
   - `seal()` clears the whole turn's history, so earlier walks that
     revealed nothing can no longer be undone either. That is
     consistent with a shot. The docs say only "not after a walk that
     brought an enemy into sight", so say all of it.

   Add the scene-level test.

### Nits

1. `intent_view.gd:28`: "When not to use it: red's turn. A person's own
   intentions need no drawing." The view now draws the person's dash
   and odds.
2. `weighing.json`: the curves saturate. `0.25 + 0.25x` is 1 from an
   expected damage of 3, so every shot worth 3 or more scores the same.
   The danger curve is 0 from 10, which vetoes every walk including
   holding, and the tie then goes to holding (`weighed_squad.gd:83`,
   first of equal). Say it in the about lines or the doc's table.
3. `weighed_squad.gd:146`: `nearest.get(cell, 0)` scores a cell with no
   route to a known enemy as standing next to one. Use a large number,
   or the walk's own route length.
4. `menu.gd:115` (`_choose_mode_named`): an unknown `--mode` falls back
   silently to the first mode. `make demo-tactical MODE=xcom` (the
   title, not the key) opens Advance Wars with no word. Print it, or
   refuse it.
5. `check_demos.py` `mode_findings` does not check that a mode's
   `roster` is the roster its `ruleset` builds from. A squad mode
   listing `tactical_roster.gd` with Advance Wars controllers passes C9,
   and the scene then cycles `SquadRoster`. A planted case would show
   it.
6. `docs/godot/squad.md` and the `WeighedSquad` header say it "never
   reads the state it is handed". `begin_turn` reads `turn_number` and
   `decide_build` reads its own piece, both public. "Never reads the
   state except through `_look`" would be exact.

### For the owner

1. **The walk rule under fog** (B1): either refuse with words that name
   nothing, or stop the walk at the last free cell and reveal the piece
   (XCOM's own behaviour is closer to the second).
2. **V on by default lifts the person's fog once a round.** On every
   computer turn the board shows the computer's view, which is all of
   its own pieces. A person playing with the default sees the whole
   enemy squad every round. That serves invariant 13, but it makes the
   fog a formality for the person and the manual check's "does it ever
   seem to know" one-sided. Consider V off by default in play, and V
   on for the teaching view.
3. **The match bar.** 100/100 against a random mover shows the agent is
   not broken. It does not separate weighings: the doc itself says the
   bar cannot tell shield 20 from 10. A second floor (for example a
   greedy shooter with no movement weighing) would give T87/T88 a bar
   that measures something. The planted case is sound for what it
   tests: random against random over 20 games a seat must stay under
   16, and it goes through the same `_seats`/`_count` path.
4. **The seam's size.** `TacticalRuleset` now has about 25 answers, and
   `tactical.gd` is 832 lines. That is within the gates, because the
   400-line limit is the addons', but every new mode will add more.
   `intent_view.gd` is 242 lines and fine. Consider whether the
   presentation hooks (`fog`, `dashes`, `odds`, `tint_at`, statuses,
   `legend`) belong on a second object, a "mode view", before T87/T88
   add their own.
5. Items 1-9 in the PR body. Nothing found here contradicts them, apart
   from item 5 (the decision view), which O2 qualifies.

## What was done about them

Every blocker, should-fix and nit was applied on the branch. None of the
owner's items was decided.

**B1, the fog hole in the walk's refusal.** `SquadRuleset.why_walk_refused`
now refuses, in one sentence that names nothing, any walk that would step
on a piece the walker's side cannot see: "unit 1 cannot walk there". It
names no cell, no id, and not that the cell is taken. The board's own "is
blocked" gets the same words, so a hidden piece cannot be told from
ground. The sentence is a key of `SquadStatus.SHAPES`, in both languages.
For the computer, `BlueTurn` now tells a controller its walk was refused
(`BlueController.after_refusal`, default: nothing, so Advance Wars is as
it was). `WeighedSquad` answers with its next best walk, avoiding every
cell of the refused route. Holding is never refused, so the asking ends.
The reviewer's case is planted in `squad_scene_test.gd`: a red runner on
(0, 0), a hidden blue shield on (2, 2), click (2, 2). The test asserts
that the status holds none of "(2, 2)", "unit 2", "occupied" or "shield".
The match gate now holds the refusals: none of the weighed enemy's
actions is lost to one (`BlueTurn.lost`), and it has at most 15 refused
walks for each 100 games. Measured: 4 as red and 4 as blue. The 13 and 17
printed before counted both sides. The choice between a neutral refusal
and stopping at the last free cell to reveal the piece is listed for the
owner (O1).

**B2, the blank status.** The ternary in `SquadStatus.text` is now an
`if`. The same pattern in `weighed_squad_test.gd` was rewritten, and a
grep of the wave's files finds no other. A scene test reads the status
with nothing in hand, after a shot, after Z, and after Z on a revealing
walk. The suites run with no `SCRIPT ERROR`.

**S1, the does-not-cheat property.** What the side cannot see is now
changed four ways: every unseen enemy moved to another unseen cell, its
health changed by one, one of them removed (one the side did not see at
its last look either), and the dice re-seeded. Each decision is asked of a
controller that has already looked at the same side's turn before, so its
memory is under the check. Two planted controllers are pinned to floors:
`SeesEverything` is caught on 42 of 60 positions (floor 30), and the
reviewer's `ReadsUnseenHealth` on 40 of 60 (floor 30).

**S2, refusals held.** See B1. They are in the gate, in
`docs/godot/squad.md` and in the PR body.

**S3, V off.** `TacticalFog.clipped` draws the computer's decision through
the fog on screen. A piece the person cannot see draws nothing, and a seen
piece walking into the dark is cut at the last cell the person sees.
`computer_status` is handed that fog. With the person's fog on screen,
`SquadStatus` says "next: a piece you cannot see acts", or "unit N walks
where you cannot see" with no reason. The weighing line shows only with
the computer's view on screen, and it now ends "V shows your own view
instead". Scene tests cover the unseen piece and the clipped walk.

**S4, "can still attack" after a dash.** The ruleset now answers
`can_still_attack` (squad: `SquadCombat.can_shoot`) and `moved_already`,
which defaults to `TacticalStatus.moved_already`, the old words moved out
of the scene. The squad's words say "shoot", in both languages. A scene
test dashes a runner, picks it up again, and finds no "can still".

**S5, Z after a revealing walk.** A scene test walks into sight and
presses Z: the runner stays, and the status says "a walk that showed an
enemy cannot be taken back, nor anything before it this turn". That
sentence covers `seal()` taking the turn's earlier walks with it, and so
does the page.

**Nits.**
1. The `IntentView` header now says what it draws on the person's turn.
2. A cell with no route to a known enemy counts `NO_ROUTE` (40) steps,
   past the end of the curve.
3. An unknown `--mode` is printed with the card's modes, and the card is
   not played.
4. C9 now checks that a mode's ruleset uses its roster's class, with a
   planted case ("a mode whose ruleset builds from another roster"). The
   self-test has 59 cases.
5. The header and the page say what `WeighedSquad` reads besides `_look`:
   the turn's number and its own piece when asked to build.
6. The saturating curves are written down, in `weighing.json`'s about
   lines and in the page, and listed for the owner (O6).

The split of `TacticalRuleset` and `tactical.gd` (O4) was not attempted
here, as the coordinator asked. It is the owner's, for a later task.

## For the owner, after the fixes

- **O1.** The walk rule under fog: a neutral refusal (done here), or stop
  at the last free cell and reveal the piece.
- **O2.** V is on by default, which lifts the person's fog on every
  computer turn.
- **O3.** A second floor for the match bar, such as a greedy shooter.
- **O4.** The seam's size: a separate "mode view" object.
- **O5.** The PR's items 1-9.
- **O6.** The saturating curves. Holding wins when every option is
  vetoed.

## Checked and found sound

- `WeighedSquad` reads the board only through `_look`, that is
  `SideView.seen_by` with its memory. The view's `movement_graphs` are
  terrain only, and `next_id` is constant in this mode. A memory from
  the other side, after S swaps sides, carries only the new side's own
  pieces and is erased, so no leak. `tint_at` and `odds` use the
  person's view or the shooter's sight. The ghosts' kind is what was
  seen.
- `UnitView.walk` of an unseen piece is dropped by the next
  `show_state(shown)`, so an unseen walk is not animated.
- Locale: every new string I traced (`XCOM`, `Mode: {mode}  (M)`,
  `mode: {mode}  ·  M plays {other}`, the V line, the reveal line, the
  weighing sentences, the shot's lines and outcome, `SquadStatus.SHAPES`,
  the health line) is a key in `squad.csv`, `tactical.csv` or
  `menu.csv`, with pt-BR. `check_translations_game.py` passes.
- `menu` → `squad` in `modules/menu.json` matches the catalogue's
  `res://game/squad/squad_ruleset.gd`, and `tactical` still names no
  `squad` class. `check_modules.py` passes. `squad` now declares
  `ai_utility` and owns its locale files.
- C9's twelve planted cases cover each branch of `mode_findings` and of
  the MODE recipe form (wrong card D3, scene inside the MODE branch D3),
  and two sound cases. All 58 behave as expected.
