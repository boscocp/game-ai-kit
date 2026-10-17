# Review: wave/44-what-the-owner-found-playing-the-boards

One fresh context reviewed it, in the main worktree, at 8e0152d.

What it read: CLAUDE.md, T41 in full (its "What each one was" included), the
wave 43 record, the diff, and the files around it: `main.gd`,
`skirmish_victory.gd`, `learned_policy.gd`, `learned_decision.gd`,
`board_features.gd`'s capture row, `plan_view.gd`, `decision_scenarios.gd`,
`rule_based_blue.gd`, `tactical_victory.gd`, `tactical_scenario.gd`,
`tactical_rules.gd`, `tactical_game_test.gd`, `expansion_view.gd`,
`search_demo.gd`, `stealth_view.gd`, the four new or changed tests,
`docs/concepts/learning.md` and `docs/godot/learning.md`.

What it ran: `make test-godot` (799 cases, 0 failures); `make
test-demo-overlays` (7 examples, 0 failures; the three script errors are
the planted crash); `make check` (exit 0, every gate ok). Probes, from the
scratchpad and not committed: rule-based blue against the random red of
`tactical_game_test.gd`, 40 seeds played to the end, with every decision
logged and timed, once on this commit and once with main's
`rule_based_blue.gd`; the skirmish opening with red's first move onto the
flag; a blue unit holding a node at 2 of 3 when red steps onto the other
one; red parked on both nodes for 30 rounds; `SkirmishVictory.progress` on
blue's turn after blue broke red's hold; the marker distances for every
old and new colour on grass and mud. Eleven mutations, listed where they
bear on a finding. Every mutation was undone and `git status` was clean
afterwards.

## What was reviewed

Commit 8e0152d: the search demo's status, legend and markers;
`marker_contrast_test.gd`; the stealth exit; `RuleBasedBlue`'s
red-pieces-as-walls and its build rule; `tactical_bridge_test.gd`;
`SkirmishVictory` and its wiring into `main.gd`; the `contest` rule in
`LearnedPolicy` and `LearnedDecision`; `skirmish_flag_test.gd`; T41 and
STATUS.

## Checked and true

- **The hold count.** A side's hold grows only at that side's own turn
  start. A broken hold is forgotten at that side's next start. The other
  side's entry is overwritten only when the side about to move is the one
  on the node, so the other side cannot be standing there. The win comes at
  the start of the third turn running, after the other side has had three
  whole turns. The first red turn is never counted, and nobody is on a node
  then. The lazy ternary in `_count` never reads a missing entry, because
  the first test's first call would crash if it did.
- **The wiring order.** `_hand_over` counts after `end_turn`, so the side
  counted is the one about to move. A blue win at blue's turn start skips
  blue's planning. A red win found in `_plan_the_next_unit` ends the turn
  cleanly. Clicks and space do nothing after a win.
- **The bridge games.** With main's `rule_based_blue.gd`,
  `tactical_bridge_test.gd` fails (a draw at round 40). Taking out the
  wader fallback (`best_count` always 0) fails it, and so does taking out
  the reach filter.
- **"Against a random red it still wins 40 of 40."** Reproduced exactly.
  Main's blue also wins 40 of 40 on the same seeds, so the number shows
  that nothing regressed. It does not show an improvement, and T41 does not
  claim one.
- **The contest rule's two failing cases.** With the rule switched off,
  `test_the_policy_walks_at_a_node_an_enemy_stands_on` fails. One run shows
  only that case, because a failing gdUnit4 suite hides the cases after it.
  With that case renamed, `test_standing_on_the_flag_makes_something_happen`
  also fails ("blue never came to the flag"). So T41's "two of its four"
  is true.
- **The marker numbers.** On grass (0.43, 0.72, 0.21): old start 0.28, new
  start 0.59, goal 0.78, ring 0.79, new exit 0.72, old exit 0.23. On mud:
  start 0.63, goal 0.52, ring 0.70, exit 0.77, frontier 0.66. These match
  the test's comments.
- **What the capture model sees.** `BoardFeatures.capture_row` holds four
  numbers (distance of the nearest own unit, own count, enemy count,
  terrain on the way), and none of them says who stands on the node. T41's
  diagnosis is right.
- **Invariant 2.** The contest rule uses only `BoardState`, `Unit` and the
  addon's own `BoardFeatures`, and `check_addon_deps` is green.
  `decision_scenarios` still plays 3 with 0 failures, because no red unit
  stands on a node in any of them.

## Findings

### Must fix

1. **The contest rule makes blue walk off a node it is about to win with,
   so blue can never win a hold against a player who touches a node.**
   `godot/addons/ai_learning/learned_policy.gd:86-89, 100-109`. The rule
   runs for every blue unit, including one that stands on a node itself.
   *Reproduced:* blue's unit 3 on (10, 1), its hold at 2 of 3, and red's
   unit on (2, 6). Unit 3 decides `contest`, path
   [(10, 2), (10, 3), (10, 4), (10, 5)], and walks away from a win due at
   its next turn start. With red off the node, the same unit decides
   `advance`, path [], and stays. A player who has learned this parks one
   unit on either node whenever blue is on the other, and blue's hold
   never reaches 3. The rule that was meant to give the flag a meaning
   makes holding a red-only way to win.
   *Fix:* a unit standing on a node does not contest. More generally, only
   a unit that is not itself holding contests. Add a case to
   `learned_policy_test.gd` with a blue holder and a red unit on the other
   node.

### Should fix

2. **The contest rule comes before the combat model, so the attack/retreat
   lesson disappears exactly when the owner stands on the flag.**
   `learned_policy.gd:86-93`. `contest` is checked before
   `_fight_within_reach`, so no unit asks the combat model while an enemy
   stands on any node. *Reproduced* on the owner's own play: red's unit 1
   walks (1, 5), (1, 6), (2, 6) on its first turn (3 points of 4). Blue's
   first turn is then "3 contest" and "4 contest". Unit 4 has 6 health and
   starts beside red's 14-health unit 2. It is not offered a retreat, and
   no p(win) is shown. `main.gd:321-324` says the opening "shows an attack
   and a retreat side by side", and it no longer does for this player. The
   rule replaces the part of the policy that is the lesson, when it only
   needed to replace the capture model's choice of node.
   The documentation also no longer matches:
   - `docs/godot/learning.md:58-60` still lists the actions as "attack,
     retreat, advance or hold", each with "a sentence carrying the number".
     A contest carries no number, and `PlanView` draws the word "contest".
   - `docs/concepts/learning.md:26-27` says "the game attacks when the
     probability clears a threshold".
   - `main.gd:4-7` says each unit asks the combat model, then the capture
     model.
   *Fix:* put the contest in place of `_advance_on_a_node` (nobody in
   reach, so walk at the held node rather than the predicted one), and
   keep fight-or-break-off first. Then update the three texts.

3. **No test holds that the skirmish can be won.** `godot/game/main.gd:229`.
   Replace `_victory.turn_started(_state)` with `pass` and all 799 cases
   pass, `skirmish_flag_test.gd` and `main_scene_test.gd` included.
   *Reproduced (mutation).* The two `SkirmishVictory` cases build the class
   by hand. The two scene cases never need a winner:
   `test_standing_on_the_flag_makes_something_happen` asserts
   `contested or winner == RED` and then `contested`, so its first assert
   adds nothing. The parts that are not held are: holding ends the game in
   the scene; nothing moves once someone has won; the status says "red
   wins" and "R starts again"; and R restarts.
   *Fix:* a scene case in which red stands on the flag and blue cannot
   reach it (an unusable policy, or a wall), with space pressed until
   `winner == RED`. It then asserts the status text and that a click
   changes nothing. Mirror `tactical_game_test.gd`'s
   `test_once_the_game_is_over_nothing_moves_until_r`.

4. **The screen shows a hold that is already broken, for a whole turn.**
   `godot/game/skirmish_victory.gd:352-358` and `main.gd:274-276`.
   `progress` prints `_held`, which changes only at a turn start, and only
   for the side about to move. *Reproduced:* red held (2, 6) at two turn
   starts, and it is blue's turn with a blue unit beside the node. Then
   `holder_of` returns `NOBODY`, but the screen says "red holds the node at
   (2, 6): 2 of 3 turns". The same thing happens after red walks its own
   unit off the node: the line stays until red's next turn start. So the
   player who breaks a hold is told it still stands, and the player who
   left a node is told they still hold it. That is the "show the decision"
   failure invariant 13 is about.
   *Fix:* build the line from the live board as well. Name a hold as
   broken when `holder_of` no longer agrees, or say "at its last turn
   start". Add a case that asserts the progress text on the other side's
   turn.

5. **Blue's new texts on the tactical board are false in ordinary play.**
   - `godot/game/tactical/rule_based_blue.gd:87-88`: "red's pieces stand on
     every way ... and until T26 nothing moves them". Red moves its own
     pieces. Against the random red over 40 games this hold was given 56
     times. In 39 of them, the same unit walked on blue's very next turn.
     The header (`:18-20`, "shuts it for good") has the same problem.
     *Reproduced.*
   - `rule_based_blue.gd:139`, `_why_nothing`: "nothing it can build and
     pay for beats any red piece". In the same 40 games the workshop built
     nothing 6 times, and each time this reason was false. A buildable type
     beat 1 to 5 red pieces and was turned away only by the new reach
     filter: seed 9 at turns 9, 11 and 19, and seed 13 at turn 5. In those
     cases the build cell was cut off by red pieces on blue's bank while a
     blue walker could still reach. Blue now skips a build because a red
     piece is passing its door, and gives a different reason. *Reproduced.*
   - `rule_based_blue.gd:171-172`: `_nearest_workshop` is "ignoring who
     stands in the way". It now counts red's pieces.
   - `rule_based_blue.gd:28-30`: "three floods" per walking unit is no
     longer true. `_remaining` copies the graph and re-blocks every red
     piece twice for each candidate cell. `decide_build` floods once per
     buildable type and once per blue walker. Blue's mean turn went from
     3.6 to 5.5 ms over the same 148 turns, which is harmless, but the
     header now states a cost that is wrong.
   - `rule_based_blue.gd:52-53`: the doc comment was not reflowed, and one
     line runs to 122 characters.
   *Fix:* "while red keeps them there". `_why_nothing` names the reach
   when that is the reason. `_remaining` takes the graph `decide_move`
   already built. Correct the two comments.

### Could fix

6. **The skirmish can get stuck with nothing left to happen and no rule to
   end it.** Red parks one unit on each node. Blue splits correctly (unit 3
   beside (10, 1), unit 4 beside (2, 6)), and from round 2 to round 29
   every decision is "contest", path []. *Reproduced.* There is no round
   limit, and `TacticalVictory.ROUND_LIMIT`'s own comment explains why a
   game needs one. The owner decided that holding wins, and this stalemate
   is the case that decision leaves open. Ask the owner, or add a limit and
   call the result a draw.
7. **The addon's new branch has a single case, and it runs through the
   game.** Two mutations each survive `skirmish_flag_test`,
   `learned_policy_test`, `main_scene_test` and `decision_scenarios`:
   - picking the farthest held node instead of the nearest
     (`apart > found["apart"]`);
   - contesting a node blue's own unit stands on (dropping the faction
     check), which produces "unit 3 contests ...: unit 3 stands on it".

   `learned_policy_test.gd` has no contest case. Two short ones there
   (nearest of two held nodes; an own unit on a node is not contested)
   would hold the rule where the addon is tested.
8. **The bridge wins come from the build rule alone.** With `decide_move`,
   `_nearest_workshop` and `_remaining` back on `state.graph_for(unit)`,
   both whole games in `tactical_bridge_test.gd` still win. Only
   `test_a_walker_the_bridge_is_shut_to_says_so_and_stays` fails, on its
   wording. That is acceptable, because the walkers' half is about telling
   the truth on screen. T41's "both of blue's rules count red's pieces as
   walls" reads as if both halves were needed to win, and it should say
   which half wins the game and which half only explains it.

## What is not proven

- T41's 400 boards painted at random through the demo's API are not a
  committed command. `search_properties.gd` holds A\* equal to Dijkstra on
  random grids, but this review did not check whether it covers mud up to
  9 after `-`/`=` repricing on the demo's own graph.
- That the markers can be seen. The test measures colour distance against
  a tile's average. The ring against the dark expansion squares, and the
  yellow start against the cream path, were not measured. Seeing them stays
  under T41's manual check.
- Whether red pieces as walls make blue oscillate around a red piece that
  moves every turn. Against the random red over 40 games blue still won
  every one, but a red that shadows a blue walker was not tried.
- The owner's three tactical games and the flag, under the manual check.

## Verdict

**Not as is.** Three of the four reports are well handled: the picture
fixes are right and measured, and the bridge fix wins games it used to
draw. The fourth is the skirmish, and its new rule undoes the point of
the new win condition. Blue leaves a node it is about to win with whenever
red touches the other one (finding 1). The same rule also skips the
combat model, so the attack/retreat lesson disappears for a player who
does what the owner did (finding 2). Both are fixed by moving the rule
one step down in `decide` and keeping holders out of it. Finding 3 is the
missing end-to-end test of the win. Findings 4 and 5 are screens that say
things that are false, which this repository treats as bugs. 6 to 8 are
small.
