# T26 — Combat on the board

Size: L · Prereqs: T10 · Files: `godot/addons/ai_core/`, `godot/game/`, `python/gameaikit/dataset/`

## Goal

T10 wrote down what each type reaches and what it beats, and nothing on the
board uses either number yet. "Unit 3 attacks unit 2" has been on the screen
since T6, and nothing happens. This task makes an attack an attack.

It is its own task because of ADR 0008. The combat model the learned opponent
uses was fitted to dice rolled in Python. Once the game has combat, the
dataset has to be regenerated from the game's rules. Otherwise the model is
fitted to a fight the player never sees.

## Steps

1. An `Attack` type beside `Move` and `ProductionOrder`, judged by its own
   rules: whether the target is in reach (`UnitType.attack_range`), and
   whose turn it is.
2. Dice, as ADR 0008 says, with the seed in the state, so `apply` stays a
   pure function and a search can replay a fight.
   The two languages' generators differ (PCG32 and Mersenne Twister, the
   same wall T28 hit), so "the same fight" across them is a fight written as
   a pure function of a list of rolls: each language draws its own rolls,
   and the shared vector hands both the same list.
3. The counter table changes the dice. Being strong against a type must
   move the odds, by an amount written down once and shared.
4. The rules live in one file both languages read (ADR 0007), with vectors.
   The dataset in `python/gameaikit/dataset/combat.py` is rebuilt from them,
   and the model is retrained.
5. The bolt tower shoots, at the start of its side's turn or when something
   walks into reach. Decide which, and write down why.
6. **Blue attacks too.** `BlueController` has only `decide_build` and
   `decide_move`; it gains an attack decision, drawn before it is played like
   the others (invariant 13). `RuleBasedBlue` attacks what the counter table
   says it beats when it is in reach, and stops "walking into anything".
   Without this step only the player can attack, and the game is no harder
   than before (wave 45's review).
7. **The win.** `TacticalVictory`'s "stand beside the workshop" is a
   stand-in that says it lasts until this task. Destroying the workshop
   replaces it, or the stand-in stays and this file says why.
8. The dataset rebuilt in step 4 is the one T44's learned blue is fitted on
   later; its features are written down here so T44 does not retrain twice.

## Acceptance

```bash
make test-godot
make test-vectors
make train
```

The suite must include:
- an attack out of reach is refused;
- rule-based blue attacks a piece it beats that is in reach, and the attack
  is shown before it is played;
- a workshop that is destroyed ends the game (or the stand-in, if step 7
  kept it);
- the same seed gives the same fight;
- strong-against moves the odds in the direction the table claims, over many
  seeds;
- the dataset's fights and the game's fights agree on a shared vector.

## Manual check

Play three turns of `make demo-tactical`. A runner sent at a mortar should
usually win, and the same runner sent at a shield should usually lose.

## What was done (2026-10-17, wave 46)

- **The rules are one file**, `spec/combat/rules.json`: the die (1-4), what
  cover, numbers and the counter table are worth, and how near is near.
  Python's `gameaikit.dataset.combat` reads it; the tactical board reads a
  byte-for-byte copy, `godot/game/tactical/combat_rules.json`, and a test
  holds the two equal.
- **A fight is a pure function of its rolls** (`combat.fight`,
  `TacticalCombat.fight`), so the two generators never have to agree.
  `spec/vectors/combat/` holds five fights, each checked by hand blow by
  blow; `make test-combat-vectors` and `make test-python` run them, and a
  planted wrong vector must be caught first. The dice live in the state
  (`BoardState.dice_seed`), so the same state and attack give the same
  fight, and undo cannot re-roll one.
- **The fight** is the dataset's, rule for rule: rounds to the death, the
  attacker first, cover and numbers and a friend arriving. Two things are
  new and both are in Python too: the counter table adds `counter_worth` (2)
  to every blow of the side strong against the other, and the winner keeps
  what it has left. A side hits back only from within its own reach, so a
  mortar at three cells takes nothing from a shield.
- **`Attack`** sits in `ai_core` beside `Move`, data only; `TacticalCombat`
  judges and plays it. Red attacks by clicking an enemy with a unit in hand,
  once a turn, before or after its walk; the status lists who is in reach
  and which way the table leans.
- **Step 5, the bolt tower**: it fires by itself at the start of its own
  side's turn, at the weakest enemy walker in reach. At the start of the
  turn, not when something walks into reach, because then the other side
  walked past it knowing it would fire, and the shot is the first line the
  tower's side reads -- a rule a person can predict. A player cannot fire it
  by hand.
- **Step 6, blue attacks**: `BlueController.decide_attack`, asked once a
  turn for each walker after its walk is played, drawn in pink before it is
  played. `RuleBasedBlue` attacks red's workshop when it reaches it, and
  otherwise the weakest red piece in reach it beats by the counter table --
  nothing it does not beat.
- **Step 7, the win**: destroying the enemy workshop. The stand-in is gone.
  A workshop that fell to the first attack made every game a race: rules
  against rules, both sides, ended in round 3 in 60 games of 60. So an
  attack on a **building is a siege** -- one blow, one back if it can reach
  -- and buildings start with 20 health (`TacticalRules.BUILDING_HEALTH`).
  The same games now end in rounds 13 to 19. The siege is the game's alone:
  the dataset has no buildings.
- **Step 8, the features for T44**: the combat model still sees the same
  four -- `health_difference`, `numeric_advantage`, `defender_terrain`,
  `reinforcement_distance`. The dataset's units have no type, so it never
  sees the counter table; T44, which puts the model on typed pieces, needs a
  fifth feature for it (+1, 0, -1, as `TacticalCombat.counter`) and a typed
  dataset.
- **Retrained.** The winner keeping its leftover health changed the rows:
  3807 of them now, the model right about 85.9% of held-back fights against
  56.8% for the majority answer and 78.8% for the lookup table (87.8%, 69.0%
  and 81.8% before). Every weight kept its sign. ADR 0008 is amended.

**Measured, not proven good.** Over 400 seeds, a runner attacking a mortar
wins more than three times in four and attacking a shield less than one in
four (`tactical_combat_test.gd`). Rules against rules, red -- which moves
first -- wins all 60 games: a mirror of two reflexes, where moving first is
everything. Whether the game is now worth playing against blue is the manual
check, and the owner's.

Checks: `tactical_combat_test.gd` (each acceptance line above, the siege,
the tower, the counter), `combat_vectors_runner.gd` and
`test_combat_vectors.py`; the tactical suites were updated for the new win.
