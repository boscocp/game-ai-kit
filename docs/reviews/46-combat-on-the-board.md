# Review: wave/46-combat-on-the-board

One fresh context reviewed it, in the main worktree, at 91f3e7e.

What it read: CLAUDE.md, T26 in full ("What was done" included), ADR 0007
and 0008 (the amendment included), the wave 44 record for the format, the
whole diff, and the files around it: `tactical_combat.gd`, `tactical.gd`,
`blue_turn.gd`, `rule_based_blue.gd`, `tactical_turn.gd`,
`tactical_victory.gd`, `tactical_status.gd`, `tactical_decision.gd`,
`intent_view.gd`, `tactical_rules.gd`, `tactical_scenario.gd`,
`unit_view.gd`, `main.gd`'s legend, `board_state.gd`, the combat vectors
and both runners, `combat.py`, `simulate.py`, `rows.py`, `train.py`,
`evaluate.py`, `tactical_combat_test.gd` and the changed tactical suites.

What it ran: `make test-godot` (824 cases, 0 failures); `make test-python`
(286 tests, OK); `make test-vectors` (combat: 5 vectors, 0 failures, the
planted one caught); `make check`, which **fails** (finding 1), then
`make -k check` to see every other gate (all green but
`lint-selftests`); `check_no_training.py`, `check_addon_deps.py` and
`check_readability.py` directly (exit 0 each); `release.py --self-test` in
a throwaway worktree of `main` (ok). Probes, from the scratchpad and not
committed: rules against rules for 60 dice seeds with towers firing at
every turn start, each game played twice; the odds of five pairings over
400 seeds; a bolt tower firing at a ram, shield, runner and mortar over 400
seeds; the same attack with and without another attack played first, 400
seeds; the scene loaded with `change_scene_to_file`, `new_game()` again and
`reload_current_scene()`; blue's turn played on the scene with its runner
beside red's workshop; `train.run()`'s fields. Eleven mutations, listed
where they bear on a finding. Every mutation was undone and `git status`
was clean afterwards, but for this file.

## What was reviewed

Commit 91f3e7e: `spec/combat/rules.json` and its Godot copy; `combat.py`'s
`fight` and `Outcome`; `simulate.py`'s winner-keeps-its-health;
`spec/vectors/combat/` and both runners; `Attack` and
`BoardState.dice_seed` in `ai_core`; `TacticalCombat`;
`BlueController.decide_attack`, `BlueTurn`'s attack question and
`RuleBasedBlue.decide_attack`; `TacticalVictory`'s new win;
`TacticalTurn`'s attacked-once; `tactical.gd`'s click-to-attack, towers and
dice seed; the health number in `UnitView`; the retrained weights; T26,
STATUS, README, ADR 0008 and `docs/concepts/learning.md`.

## Checked and true

- **The two fights are the same code.** `TacticalCombat.fight`,
  `_attacker_blow` and `_defender_blow` match `combat.fight` and its two
  helpers line for line: the same order of blows, the same `<= 0` tests,
  the same bonuses with the same guards, and the defender rolls only when it
  hits back. The vectors do not hold all of it, though (finding 2).
- **All five vectors, by hand.** *An even fight*: 10-4=6, 10-2=8; 6-3=3,
  8-4=4; 3-1=2, 4-1=3; 2-4 is dead. Won, 3 left, 7 rolls. *The defender's
  counter*: each round the defender loses 2 and the attacker 4. 8/6, 6/2,
  4/-2. Lost, the defender has 4, 6 rolls. *A counter and a friend
  arriving*: 3, 3, then 4 from round 3 kill a defender of 10. The attacker
  takes 4 twice and keeps 2, 5 rolls. *Cover and numbers*: the defender
  returns roll + 1 + 2. 8-3=5, 10-4=6; 5-4=1, 6-5=1; 1-2 is dead. Won, 1 left, 5
  rolls. *A workshop does not hit back*: 1+2+3+4 = 10, 4 rolls. Every
  expected number is right. One `about` line is wrong (finding 5).
- **The same state and attack give the same fight.** `_resolve` seeds a
  fresh generator from `state.dice_seed` and writes the next seed into the
  new state. Every way of making a state (`apply`, `produce`, `buy`,
  `end_turn`) goes through `duplicate_state`, which copies the seed. In the
  rules-against-rules probe, every one of 60 games played twice gave the
  same decisions, the same winner and the same length, towers included.
- **No unit is left at 0 health, and a siege cannot loop.** A siege is one
  exchange with no loop, and `maxi(..., 0)` plus the rebuild in
  `duplicate_state` drops whoever reached 0. Over the 60 games (1358
  attacks, 169 tower shots) no state held a unit at 0 or less.
- **Blue is never refused.** 0 refused decisions in those 60 games, with
  towers firing. `decide_attack` asks `why_refused` on the very state it is
  played on.
- **Untyped units cannot reach the new code.** `TacticalCombat`,
  `TacticalVictory` and `TacticalStatus._targets` are reached only from
  `game/tactical/`. `UnitView._draw_health` reads `health` and nothing
  else, so the skirmish's units with no type draw without error. They do
  draw a number the skirmish legend does not explain (finding 10).
- **`new_game`'s dice.** Loaded with `change_scene_to_file`, the scene got
  seed 3332762736, then 4260658335 from a second `new_game()` (R), then
  4278362653 after `reload_current_scene()`. A test that mounts the scene
  as a child keeps seed 0.
- **Invariants 2 and 6.** `Attack` is data and `dice_seed` is a field.
  `ai_core` names `TacticalCombat` only in a doc comment, and
  `check_addon_deps.py` exits 0. `check_no_training.py` exits 0: the
  committed weights are the pipeline's output.
- **The numbers.** `train.run()`: 2874 + 933 = 3807 combat rows. Score
  0.8585, majority 0.5681, table 0.7878, twinned share 0.838 (84%), 1083
  distinct rows. That is 7.1 points over the table and 29.0 over the
  majority. The capture error is 0.66. Every combat and capture weight kept
  its sign. Rules against rules: red wins 60 of 60 (dice seeds 0 to 59),
  ending at turn 24 to 36, which is rounds 13 to 19. With the siege
  switched off and buildings at 10 health (my reconstruction of the old
  rule), all 60 end in round 3. Over 400 seeds, runner against mortar is
  400, against shield 41, against runner 257. The test's thresholds hold.
- **The acceptance lines that do have teeth.** Seeding the dice with
  `randomize()` fails `test_the_same_seed_gives_the_same_fight`. The
  out-of-reach, workshop-win, counter-odds and blue-attacks cases each
  test what they name.

## Findings

### Must fix

1. **`make check` is red: the published wheel cannot import
   `gameaikit.dataset`.** `python/gameaikit/dataset/combat.py:36-37` reads
   `parents[3] / "spec" / "combat" / "rules.json"`. That is a path into the
   source tree, and the wheel does not ship it. `lint-selftests` fails on
   `release.py`'s "the wheel imports" check:
   `FileNotFoundError: .../check_the_wheel/spec/combat/rules.json`.
   *Reproduced* twice. The same self-test passes on `main`. So CI fails, and
   anyone who installs the wheel gets a crash on
   `import gameaikit.dataset.simulate` or `gameaikit.training`. This
   follows from T26's design, which reads a shared file from outside the
   package.
   *Fix:* ship the rules inside the package, as a third copy held
   byte-equal by a test (as the Godot copy is), or as package data read
   with `importlib.resources`. Then run `make check`, not just the three
   acceptance commands.

2. **The vectors do not hold two of the fight's five modifiers, so the
   game's fight can diverge from the dataset's with every suite green.**
   No vector has `numeric_advantage > 0`. No vector puts a decisive blow on
   the round where `round_number == reinforcement_distance`. *Reproduced
   (mutation):*
   - In `tactical_combat.gd:220`, `if inputs["numeric_advantage"] > 0` was
     replaced by `if false`, so the attacker's numbers count for nothing.
   - In `tactical_combat.gd:222`, `>` became `>=`, so a friend arrives a
     round early.

   Both pass `make test-combat-vectors`, `tactical_combat_test`,
   `tactical_game_test` and `tactical_bridge_test`. The same two mutations
   in `combat.py` pass `test_combat_vectors.py`. Only the weights check
   would notice them in Python, and nothing notices them in GDScript. So
   the acceptance line "the dataset's fights and the game's fights agree on
   a shared vector" holds for three modifiers out of five.
   *Fix:* add a vector with the attacker outnumbering the defender, and one
   where the friend's arrival round decides the fight, so that `>=` changes
   `rolls_used` or the winner. Then run both mutations again.

### Should fix

3. **Undo turns every attack into a free look at the dice.**
   `tactical.gd:115-129` and `tactical_turn.gd`. An attack can be taken
   back, and the state it returns to holds the same seed. A player can
   attack, read the result, press Z, and attack something else or nothing.
   Because each fight passes a new seed to the next one, the order of
   attacks also picks the dice. *Reproduced:* runner against runner, 400
   seeds. Attacked directly, the attacker wins 258. Played as the better
   of two orders (another attack first, or not), it wins 348. The order
   changes the result in 175 of 400. T26's "undo cannot re-roll one" is
   true word for word, but the player gets the same advantage by looking.
   *Fix:* make an attack final: the history is cleared when an attack is
   played, as in Advance Wars, and the status says so. Or state the peek in
   T26 as a decision the owner took.

4. **A bolt tower's own shot is a fight to the death, and it can destroy the
   tower.** `tactical_combat.gd:127-128`. A siege is chosen only when the
   **target** is a building. When a tower fires, the full fight is played,
   and the walker hits back if it reaches. *Reproduced*, a red tower of 20
   health firing at the start of its turn, 400 seeds: at a ram beside it,
   the tower is destroyed 81 times; at a shield beside it, 2; at a mortar
   two cells off, 2. The same ram attacking the same tower is one blow. A
   player cannot decline the shot (`why_refused` says "fires by itself"),
   so parking a ram beside an enemy tower is a 1-in-5 chance at killing it
   for free. No text says a building fights to the death when it attacks.
   The header says the opposite ("a building is not fought to the death").
   The line it prints is also unclear: "...attacked the blue ram ... and
   was destroyed; it has N health left", where "it" is the ram.
   *Fix:* a tower's shot is one blow, the siege the other way round. Or
   write the asymmetry down where the siege is explained. Either way, add a
   case.

5. **Texts the measurements contradict.**
   - `tactical_victory.gd:8-10`: "A workshop cannot hit back, so any attack
     that reaches it destroys it". It has 20 health, and an attack is one
     blow of 1 to 4 (6 for a ram).
   - `tactical_combat.gd:29-32`: "every attack kills somebody ... a
     building ... falls to any attack that reaches it". This contradicts
     the same header's siege paragraph.
   - `combat.py` `COUNTER_WORTH`: "the counter table moving the dice rather
     than deciding the fight". README.md:106 says the table "tilts" a fight.
     Measured over 400 seeds: runner→mortar 400, shield→runner 400,
     mortar→shield 400. A +2 on a 1-4 die decides every counter pairing at
     equal health. T26's "more than three times in four" is true, but the
     real figure is 400 of 400, and the owner should know that before the
     manual check, which expects "usually".
   - `spec/vectors/combat/cover-and-numbers-for-the-defender.json`, the
     `about` line: "two more on every blow it returns". It is three: 2 for
     trees and 1 for numbers. The expected numbers use three.
   - `a-workshop-does-not-hit-back.json`: a workshop is never fought to the
     death in the game. This path is the mortar at three cells, and the
     `about` line should name that.
   - `rule_based_blue.gd`, `_past_red`'s comment: "winning is standing
     beside it".
   - `rows.py:76-80`: after the edit, "The second of those" no longer points
     at anything, and "976 answers" is stale (1083). `train.py:54` also
     says 976.
   - `intent_view.gd:1-6`: the header lists walk, build and hold, but not
     attack (see finding 6).

6. **An attack is drawn exactly like a hold.** `intent_view.gd:39-40`. The
   `_` branch draws a pink ring round `decision.target`, which for an
   attack is the red piece. Nothing joins it to the attacker. The picture
   cannot tell "blue's shield attacks this runner" from "this piece
   stays". T26 says the attack is "drawn in pink before it is played". It
   is drawn, but only the text says what it is, and invariant 13 asks for
   the picture to show the decision. No test looks at it:
   `test_blue_s_turn_shows_the_attack_before_it_plays_it` checks
   `next.kind()`.
   *Fix:* a line from the attacker to the target, with the ring on the
   target, and an entry in the header and the legend.

7. **Two rules the game depends on have no failing test.** *Reproduced
   (mutation):*
   - The towers never firing in the game: in `tactical.gd:384`,
     `towers_fire(state)` was replaced by `[state, []]`. All three tactical
     suites and `demo_overlays` pass. The tower cases call
     `TacticalCombat.towers_fire` by hand, so the wiring at turn start is
     not held. `tactical_game_test`'s 25 seeded games call `end_turn`
     directly, so blue's legality there is also measured with no tower ever
     firing.
   - "Once a turn": `TacticalTurn.has_attacked` returning `false` passes
     everything. In
     `test_a_red_unit_attacks_once_a_turn_and_undo_replays_the_same_fight`
     the runner kills the mortar, so the second click finds an empty cell
     and `second_try` is a "moved this turn" refusal, which is not empty
     either way. The rule matters most against a building: without it, one
     runner can besiege a workshop as many times as the player clicks.
   *Fix:* a scene case where a turn is handed over and a tower's shot is in
   the status and on the board. A second attack on a **workshop** must be
   refused.

8. **What blue's attacks did is gone by red's turn, and with Enter it is
   never on screen.** `tactical.gd:370` clears `_last_event` when red's
   turn opens, and `_open_turn` fills it only with tower shots.
   *Reproduced:* blue's runner struck red's workshop (20 → 16). The line
   showed while blue's turn was being stepped, but red's status at its own
   turn says nothing of it. `play_rest_of_blue_turn` plays every decision
   with no frame drawn in between, so a player who presses Enter never sees
   either blue's attack or what it did. Each attack also replaces the
   previous line, so a turn with two attacks shows only the second.
   *Fix:* keep blue's turn's attack lines and show them at the top of red's
   turn, as the tower shots are shown.

### Could fix

9. **The Python half has no planted vector.** T26 says "a planted wrong
   vector must be caught first", and only `combat_vectors_runner.gd` has
   one. `test_combat_vectors.py` would pass over a `fight` that ignored its
   rolls, provided the five vectors still matched. Invariant 4.
10. **The skirmish now draws a second number on every unit, and its legend
    still says "numbers are ids".** `unit_view.gd:177` draws for every
    scene, and only `tactical_legend.gd` gained the "yellow number: health"
    entry. `main.gd:68-69` does not have it.
11. **Two status lines disagree with the attack rule.** A walked unit picked
    up again gets `_last_refusal` "this runner has moved this turn"
    (`tactical.gd:306-309`), while the status offers it targets. And
    `TacticalStatus._targets` lists targets for a unit that has already
    attacked, with "click an enemy to attack it", because it does not ask
    `has_attacked`.
12. **The sentinel differs at the edge.** `NOBODY_COMING` (1 << 20) means
    "nobody arrives" in the game. In the dataset a lone attacker reports
    `WIDTH` (15), and its units reach 18 health, so a fight that lasts to
    round 16 gives the lone attacker +1 in Python and never in Godot. It is
    rare, and it is not "rule for rule". The comment at
    `tactical_combat.gd:38-39` ("further than any fight lasts") is true only
    of the game's 10-health walkers.

## What is not proven

- That launching the tactical scene as the main scene (`make
  demo-tactical`) rolls new dice. It was checked through
  `change_scene_to_file` and `reload_current_scene`. The engine's
  main-scene path sets `current_scene` before `_ready` as far as this review
  knows, but that was not measured.
- T26's explanation that red wins 60 of 60 because "moving first is
  everything". In my reconstruction of the rule before the siege, **blue**,
  the side that moves second, won all 60 in round 3. Moving first does not
  explain both results. An asymmetry in the map or in `RuleBasedBlue` was
  not looked for.
- Whether a +2 counter on a 1-4 die makes the game worth playing, and the
  three turns of the manual check. Those belong to the owner.
- Red's random games in `tactical_game_test.gd` never attack, so blue has
  never been measured against a red that fights back, except by blue's own
  rules in this review's probe.

## Verdict

**Not as is.** The fight itself is right: the two languages' code is the
same, every vector checks out by hand, the dice are a pure function of the
state, and the retrained numbers are all reproduced. But `make check` is
red, because the wheel can no longer import the dataset (finding 1). The
shared vectors leave two of the five modifiers free to drift, so the
acceptance line they exist for is only partly held (finding 2). Undo lets
a player look at the dice before committing (3). A tower can destroy
itself with a shot nobody chose (4). Several texts describe a game this
wave did not build: a workshop that falls to one attack, a counter that
only tilts a fight (5). Findings 6 to 8 are about the picture and two
rules with no test. 9 to 12 are small.
