# T44 — The learned policy plays the tactical board

Size: L · Prereqs: T26 · Files: `godot/game/`, `godot/game/tactical/`, `godot/addons/ai_learning/`, `python/gameaikit/`, `godot/test/`, `Makefile`, `scripts/check_demos.py`, `README.md`, `docs/`

## Goal

The owner, choosing from T42's fun review: of all the examples, only the
skirmish and the tactical board do not feel like games, and the skirmish
should be folded into the tactical one. Two thin games become one real one.

This was always where it was headed. `BlueController` names "the learned
policy T26 makes possible" as one of blue's controllers, and `make
demo-skirmish` says "where the policy finally plays is T30's question: blue
on the tactical board". After T26 the tactical board has combat, and the
learned policy's attack-or-retreat question finally has an answer there.

**Decided with the owner (2026-10-17):** the tactical map gains **control
points** -- the skirmish's nodes, moved to the board where they matter. The
capture model, the kit's one linear regression (README), answers its own
question there: which point falls first. Kept, not dropped.

## Steps

1. **Control points.** Two or three on the tactical map -- for instance the
   bridge and one on each bank -- each paying its holder income at the start
   of its turn, as cities do in Advance Wars. Holding is T41's rule: a unit
   on the point and no enemy beside it. Where they go and what they pay is
   decided here and written down with why; the map stays the same turned
   half round.
2. **A `LearnedBlue` controller.** The combat model decides attack or
   retreat against red's pieces (T26 gives the attack); the capture model
   ranks the points; walking otherwise goes at red's workshop as the rules
   do. T41's contest rule -- a unit with no fight to weigh walks at a point
   an enemy holds -- moves with it, said as a rule, not the model.
3. **The models.** The combat dataset is the one T26 rebuilt from the
   game's rules (its step 8 names the features); this task does not retrain
   it again unless the features change, and says so if they do. The capture
   dataset is regenerated from the tactical map with points. Nothing trains
   at game time (invariant 6). Known on the way: `ai_learning` routes on
   `state.graph`, which is wrong for a wader (T11's STATUS row) -- fixed
   here, or the learned blue builds no waders and says why.
4. The tactical scene can be given either controller, rules or learned, and
   the screen says which. A key switches between them between games.
5. **The skirmish leaves.** `make demo-skirmish`, `main.tscn` and
   `SkirmishVictory` go; `check_demos.py`, the README and the docs that name
   the skirmish follow. What it taught -- a probability against a threshold,
   on screen -- is the learned controller's overlay on the tactical board.
6. Learned against rules, many seeded games: the win rates are written in
   this file, measured, not guessed.

## Acceptance

```bash
test -f godot/test/tactical/tactical_learned_blue_test.gd
make test-godot
make test-demo-overlays
make test-python
```

`tactical_learned_blue_test.gd` must hold: a point pays its holder and not
a contested one; the learned blue attacks when the combat model clears the
threshold and retreats when it does not; it walks at the point the capture
model ranks first; and learned-against-rules games, seeded, all end -- a
win or the round limit.

## Manual check

The owner plays the tactical board against the learned blue three times and
says whether it is a game now.

## What was done so far (2026-10-17, wave 47) -- wip

Steps 1-3 in part, and then stopped, on the owner's call: the first
measurements said the board's problems are game design, not the controller,
and the owner asked for a study of similar games before more tuning by
trial and error. That study is
[docs/design/tactical-references.md](../docs/design/tactical-references.md),
and the adjustments it led to are their own tasks (T45-T48).

- **Step 1, control points.** Two, `TacticalScenario.POINTS`, (5, 0) and
  (8, 8): one on each bank by the river's ends, one step from water. Two and
  not three because the map is the same turned half round and on a board
  fourteen wide no cell is its own mirror; not on the bridge because a flag
  there hides the only dry crossing. Each pays `TacticalRules.POINT_INCOME`
  (2) at the start of its holder's turn, held by T41's rule
  (`ControlPoints`). Every turn now opens in one place, `TurnStart.open`:
  income, points, towers -- the scene and the measurements play the same
  rule.
- **Step 2, `LearnedBlue`**, in `godot/game/tactical/`: a fight the combat
  model clears at 0.5 is walked to and attacked, from the cell it likes best;
  one it does not is retreated from to the edge of the threat's reach; a
  piece on a point stays; a point red holds is contested (T41's rule); else
  the point the capture model ranks first; else red's workshop by the rules'
  route. Builds and sieges are the rules'. The numbers come from the addon's
  `LearnedPolicy`, which gained `chance_to_win` and `rank_nodes`. Not yet a
  key in the scene: that is step 4.
- **Step 3, the models, in part.** The combat model has its fifth feature,
  `counter`, and a typed dataset: `spec/combat/rules.json` gained the counter
  table (`strong_against`), each dataset unit is one of the five walkers,
  and a test holds the table equal to `TacticalRules`. Retrained: right about
  86.0% of held-back fights against 57.7% for the majority answer and 70.5%
  for the lookup table; the counter's weight is +1.42 per unit, the sign the
  table claims. `BoardFeatures` reads the defender's own ground (a wader in
  the river is on water, not a wall) and counts only walkers as friends, as
  the board's fight does. `LearnedPolicy` routes on `graph_for(unit)`. **Not
  done:** the capture dataset is still the simulator's, not cut from the
  tactical map with points.
- **Not started:** step 4 (the key), step 5 (the skirmish leaves), step 6's
  written win rates beyond the first measurement below.

**Measured** (`make tactical-win-rates`, 20 seeded games each, each side
counted on its own -- the first version of this table added both sides
together, and wave 47's review caught it):

| pairing | red | blue | draws | rounds | stuck: red's walkers | stuck: blue's walkers |
|---|---|---|---|---|---|---|
| rules v rules | 20 | 0 | 0 | 15.7 | 290 of 1931 | 437 of 1869 |
| rules v learned | 0 | 3 | 17 | 39.4 | 495 of 5636 | 5540 of 10559 (52.5%) |
| learned v rules | 2 | 0 | 18 | 39.6 | 4653 of 10599 (43.9%) | 532 of 5708 |

"Stuck" is a walker that stayed because no walk brought it nearer its goal.
The learned side holds both points and ends with 161-172 funds unspent. As
blue its workshop built on 409 of 787 turns, and 377 of the misses were its
own pieces boxing the workshop in -- which the board reports as "(12, 1) is
not next to unit 6", a misleading sentence; as red, 132 of 159. The other
large refusal, "what would beat red's pieces cannot get past them" (503 and
303 times), is the **rules** controller's, playing against the learned one. Retreating as far as it could made a
unit go back and forth every turn; it now stops at the edge of the threat's
reach, which did not change the draws. The side moving first wins every rules
mirror, as T26 found (58 of 60 then).

`tactical_learned_blue_test.gd` holds what is built: the counter table equal
in both places, the counter from the attacker's side, a tower not a friend,
the wader's own ground, a point paid and a contested one not, points paid at
the holder's turn start and mirrored, the learned blue attacking above the
threshold and retreating below it, walking at the point the capture model
ranks first, and learned-against-rules games ending with nothing refused.
