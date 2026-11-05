# Review: wave/128, T126 -- the XCOM mode has its own view

T126 moves the screen-side answers out of `TacticalRuleset` into a new
`TacticalModeView`. That takes the ruleset from 28 answers to 14 (13 rules
plus `mode_view`). `AdvanceWarsView` and `SquadView` answer the new
interface, and their bodies are the ones the rulesets had, moved unchanged.
`tactical.gd` reaches the view through a cached `view()`, and grew from 860
to 873 lines. One test changed, only in which object it asks:
`squad_scene_test.gd` now asks the view for `fog`, `dashes`, `tint_at` and
`reveals`.

A fresh context reviewed PR #74 at head b098826. It read the code and
planted faults in a throwaway worktree. It made no commit, push or PR
comment, and left the worktree clean.

**Verdict: changes requested, no blocker.** The move is faithful. Every
moved body matches its old one, no caller of a removed ruleset method is
left in `godot/`, and the counts on the page are right. Two should-fix
findings, both about tests: the new code in `view()` has none, and two of
the defaults that moved into the new base class are held by nothing. Four
nits, and four items for the owner.

## What was reviewed

- The task file, T88's task file and the PR body.
- The whole diff: `tactical_mode_view.gd`, `advance_wars_view.gd`,
  `squad_view.gd`, the three rulesets, `tactical.gd`, the test and
  `docs/godot/squad.md`.
- Every moved body was compared line by line with its old version on
  `origin/main`. Every default in `TacticalModeView` matches the old
  `TacticalRuleset` default.
- A grep across `godot/` found no call left to `ruleset.fog/dashes/odds/
  tint/tint_at/legend/status/...`, and no stale mention in `docs/`.

## What was run (green at b098826 unless stated)

- `make test-godot-some SUITES="test/squad/squad_scene_test.gd"`: 18 cases,
  0 failures, no `SCRIPT ERROR`.
- `python3 scripts/check_readability.py`: exit 0.
  `python3 scripts/check_modules.py`: ok, 38 modules.
- The counts were recounted: the public answers in `tactical_ruleset.gd`
  are 28 on main and 14 here, `tactical_mode_view.gd` has 15, and
  `tactical.gd` is 860 lines on main and 873 here. All match the PR.
- Twelve planted faults. Each was run against `squad_scene_test`,
  `squad_rules_test`, `tactical_game_test`, `threat_map_test` and
  `unit_view_test` (120 cases), then restored with `git checkout`:

| plant | where | result |
|---|---|---|
| m1 `view()` never rebuilds (`if _view == null:`) | tactical.gd:193 | **survives**, 42/42 green (squad files) |
| m2 base `tint_at` returns `{}` instead of `tint(...)` | tactical_mode_view.gd:87-88 | **survives**, 120/120 |
| m3 `AdvanceWarsView.points()` returns `[]` | advance_wars_view.gd:43 | **survives**, 120/120 |
| m4 `SquadView.legend()` returns the Advance Wars legend | squad_view.gd:150 | **survives**, 120/120 |
| m5 `SquadView.computer_status` passes a null fog | squad_view.gd:140 | caught, 2 failures |
| m6 `SquadView.moved_already` says "attack" (TacticalStatus) | squad_view.gd:145 | **survives**, 120/120 |
| m7 `SquadView.odds` always empty | squad_view.gd:114-115 | caught, 1 failure, 1 error |
| m8 `SquadView.fog` draws no ghosts | squad_view.gd:96 | **survives**, 120/120 |
| m9 `SquadView.tint_at` ignores the piece in hand | squad_view.gd:68 | caught, 1 failure |
| m10 `AdvanceWarsView.rule()` gives the squad's rule | advance_wars_view.gd:28 | caught, `test_the_win_rule_is_on_screen_before_anyone_has_won` |
| m11 `AdvanceWarsView.what_this_is()` returns `""` | advance_wars_view.gd:23 | caught, `test_the_screen_says_what_game_this_is_and_who_plays_blue` |
| (in the test) `reveals` false | squad_view.gd:123 | held directly by `test_a_walk_that_shows_an_enemy_cannot_be_taken_back` |

## Findings

1. **Should-fix -- nothing holds `view()`'s rebuild, the PR's only new
   logic.**
   - Where: `godot/game/tactical/tactical.gd:192-195`.
   - Plant m1: change the condition to `if _view == null:`, so the view
     is never rebuilt after a mode change. `squad_scene_test` and
     `squad_rules_test` stay green (42 cases), with no `SCRIPT ERROR`.
     After M, the Advance Wars game is then drawn by `SquadView`. The
     header reads "mode: XCOM · M plays XCOM", there is no threat tint,
     the points are not marked, and the status and legend are the
     squad's.
   - That is exactly the "a mode gets the other's view" case. The page
     says the opposite ("so the two cannot drift apart",
     `docs/godot/squad.md`), and no test holds that sentence.
   - `test_opened_in_both_modes_it_starts_in_the_one_chosen_and_m_moves_between_them`
     presses M twice, but checks only `mode_name()` and the controller.
   - Fix: after each M press in that test, assert `scene.view() is
     AdvanceWarsView` / `is SquadView`, and/or
     `scene._header.text.contains("M plays XCOM")`. Two lines.

2. **Should-fix -- two defaults that moved into the new base class are
   held by no test.**
   - m2: the base `tint_at` returning `{}` instead of `tint(state, side)`
     (`tactical_mode_view.gd:87-88`) passes 120 cases. That would remove
     Advance Wars' T tint from the screen. `threat_map_test` tests
     `ThreatMap` directly, and nothing tests the scene's `_tint()` in
     Advance Wars.
   - m3: `AdvanceWarsView.points()` returning `[]`
     (`advance_wars_view.gd:43`) also passes. The two control points
     would then not be drawn.
   - These are the answers whose default changed home in this PR, which
     is where "a default changed in the move" would happen. They are not
     regressions: the bodies are verbatim, and the same plants would
     survive on main.
   - The task's measure is "every scene test passes unchanged", which is
     only as strong as what the scene tests ask.
   - Fix: one Advance Wars case asserting `AdvanceWarsView.new(rules)`
     gives `points() == TacticalScenario.POINTS` and `tint_at(...) ==
     tint(...)`.
   - m4, m6 and m8 (the squad legend, the "shoot" wording and the fog
     ghosts) are older gaps of the same kind. One squad case could hold
     all three, but that can wait for its own task.

3. **Nit -- two comments in `tactical.gd` still say "the ruleset's"
   tint.** `tactical.gd:469` reads "the ruleset's tint (`ThreatMap` in
   Advance Wars)". `tactical.gd:795` reads "What T tints: the ruleset's".
   Both are now the view's. Line 469-470 also has a broken wrap.

4. **Nit -- `tactical_ruleset.gd:4` is 123 characters.** The header's
   wrap was lost when `ThreatMap` was dropped from the list.

5. **Nit -- `_header_lines` builds a fresh view every refresh**
   (`tactical.gd:770`, `other.mode_view().title()`). It is harmless, but
   the cache's own comment says "so a frame does not build a new one".
   `TacticalModeView.title()` could be static per class, or the title
   could stay a ruleset string. Either one also answers item 2 for the
   owner.

6. **Nit -- presentation left in the scene.**
   - `TacticalGame.WHAT_THIS_IS` (`tactical.gd:58`) is Advance Wars'
     header line, and only `AdvanceWarsView` reads it. It belongs in the
     view, together with its `# shown through tr()` marker.
   - `_terrain()` (`tactical.gd:864`) always draws `TacticalScenario.MAP`.
     That is correct today, because `SquadScenario.rows()` returns that
     same map. It is the next hook a mode with its own map would need on
     the view. It is worth one line on the page, not a change now.

## Checked and found sound

- **No mode gets the other's view through the opener.** `play_in_modes`
  runs before `add_child`, so the first `view()` already sees the chosen
  ruleset. `swap_mode` sets `ruleset` and then calls `_set_words()`,
  which calls `view()`, which rebuilds. Correct, but held only by reading
  (finding 1).
- **No hook goes uncalled.** Every call that went to `ruleset.<hook>`
  before now goes to `view().<hook>` (16 sites). `can_still_attack` and
  `controllers_to_come` still go to the ruleset, as they should.
- **The base `status` hands `rules` to `TacticalStatus.text`.** So the
  status still asks the rules which targets a piece may take, as before
  (the old code passed `self`, which was the ruleset).
- **`SquadView._init(shown: SquadRuleset)` narrows the parent's
  parameter type.** It parses, and the suite runs clean, with no
  `SCRIPT ERROR`.
- **Function length and nesting:** no changed function is near 40 lines.
  `check_readability.py` passes. Every public function has a doc comment
  that says what and why.

## On the decisions in the PR body

1. **`mode_view()` on the ruleset.** Accept. The cost is real but small.
   Rules now name their view class, so anything that loads
   `SquadRuleset` (the matches, the search) also loads `SquadView`,
   `SquadStatus` and `SquadLegend`. The scene, the menu and the tests
   stay untouched, which is worth more.
2. **`rule`, `announcement`, `tint` and `points` moved.** Accept. They
   are words and marks. `TacticalVictory` reads `POINTS` directly for
   the win, so the view only draws them.
3. **`reveals` moved, `can_still_attack` stayed.** Accept, with a note
   for the owner. `reveals` changes what a key does: it seals Z. That is
   a rule of the person's turn, not of the game. Only the scene undoes,
   and no controller or search asks it, so it passes the view's own
   "when not to use it" test. If a mode ever lets a controller undo, it
   goes back to the rules.
4. **`view`, `every_cell`, `leaves_a_shot` and `shots_of` stay on the
   ruleset.** Accept. They are perception and rules, and the view
   reaches them through `squad`.
5. **`tactical.gd` grew by 13 lines.** Accept. Read top to bottom, each
   call now says whether it asks for a rule or a picture. That is a real
   gain for the reader, though a small one. Nits 3, 5 and 6 are what is
   left to tidy.

## Does it serve T88?

Partly. T88's own screen work goes in two places, and T126 moves neither:

- the weighed overlay, which the scene draws from `computer.weighed()`
  for any controller;
- `SquadStatus.computer_text`, whose `controller is MctsSquad` branch
  ExpectiSquad will extend.

What T126 buys T88 is a place for the one new on-board picture T88
describes, the hit and miss branches with their probabilities. It goes on
`TacticalModeView`/`SquadView`, not on the ruleset that ExpectiSquad's
adapter reads thousands of times. T88's diff does not get smaller in
lines. It gets one file narrower in what it has to touch, and the rules
it searches stay free of screen answers.

## Items for the owner

1. Decision 3: is "Z is sealed after a reveal" a picture or a rule? I
   recommend keeping it on the view, for the reason above.
2. Decision 5 / the task's manual check: is `tactical.gd` easier to read?
   This review's reading says yes, slightly.
3. Finding 2's older gaps (m4, m6, m8: the squad legend, "shoot", the fog
   ghosts). Fold them into this wave's test, or give them their own task?
4. The manual check is still owed: play both modes with V on and off,
   and compare with main.

## How to reproduce

The plants are in `mutate.py` beside this record (not committed):
`python3 mutate.py <name>`. It applies one plant, runs the five suites
through `make test-godot-some` and restores the file with
`git checkout`. m1 was planted by hand with
`sed -i 's/if _view == null or _view.rules != ruleset:/if _view == null:/'`
on `tactical.gd`.

## Applied, on the same branch

1. Applied. The M test in `squad_scene_test.gd` now asserts `scene.view()
   is SquadView` before M, `is AdvanceWarsView` and "M plays XCOM" after
   the first M, and `is SquadView` after the second. m1 now fails it.
2. Applied, together with the older gaps. `test/tactical/mode_view_test.gd`
   holds Advance Wars' `tint_at` to `ThreatMap.of` whatever the cursor,
   `points()` to `TacticalScenario.POINTS`, and that a view shows the
   ruleset that handed it. `squad_scene_test.gd` adds the fog's ghost
   where an enemy was last seen, and the legend and the "shoot" wording.
   The eleven code plants (m1-m11) were rerun through a copy of
   `mutate.py`, with `mode_view_test.gd` added to the suites: each now
   fails at least one case.
3. Applied: both comments name the mode view, and the wrap is mended.
4. Applied: rewrapped.
5. Applied by fixing the comment: the cache's comment now says the many
   calls of one refresh share one view, and that the header builds the
   next mode's view for its title only.
6. Applied: `WHAT_THIS_IS` moved to `AdvanceWarsView`, with its
   `# shown through tr()` marker. `_terrain()` has a comment that every
   mode plays on `TacticalScenario.MAP`, and the page says that a mode
   with its own map would add it to the view.
