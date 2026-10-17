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
