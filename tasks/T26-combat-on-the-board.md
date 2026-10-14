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
3. The counter table changes the dice. Being strong against a type must
   move the odds, by an amount written down once and shared.
4. The rules live in one file both languages read (ADR 0007), with vectors.
   The dataset in `python/gameaikit/dataset/combat.py` is rebuilt from them,
   and the model is retrained.
5. The bolt tower shoots, at the start of its side's turn or when something
   walks into reach. Decide which, and write down why.

## Acceptance

```bash
make test-godot
make test-vectors
make train
```

The suite must include:
- an attack out of reach is refused;
- the same seed gives the same fight;
- strong-against moves the odds in the direction the table claims, over many
  seeds;
- the dataset's fights and the game's fights agree on a shared vector.

## Manual check

Play three turns of `make demo-tactical`. A runner sent at a mortar should
usually win, and the same runner sent at a shield should usually lose.
