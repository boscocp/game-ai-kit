# T30 — The tactical game, against the computer

Size: M · Prereqs: T10 · Files: `godot/game/tactical/`, `Makefile`

## Goal

The owner played `make play-tactical` and found three things wrong:
- two people at one mouse does not help;
- moving meant clicking pieces one at a time and felt stuck on one;
- nothing said what kind of game it was.

The reference is **Advance Wars**, and the scene should say so on screen and
play like it. Name the reference only; borrow no art, names or units.

## Steps

1. **Turns as Advance Wars plays them.**
   - Click any of your units, and everywhere it can reach lights up.
   - Click a destination, and the unit moves and is spent: drawn greyed
     out, and it cannot move again this turn.
   - The next unspent unit is selected for you.
   - You may pick your units in any order, and undo any move until the
     turn ends. There is nothing to "act" with before T26 brings combat;
     when it does, an attack ends the chance to undo.
   - End turn is a key and a button. It asks for confirmation while units
     are still unspent.
2. **The computer plays blue.** Until T11's planner exists, blue is a
   simple opponent written as rules:
   - it builds the type that beats the most enemy units it sees, by the
     counter table. That choice has no consequence until T26 brings combat,
     and the scene says so;
   - it walks each unit at the nearest enemy, or at the bridge.

     **Changed during the wave, pending the owner.** Measured, "the nearest
     enemy" never wins: it is a bolt tower, and after sixty rounds thirty blue
     shields stood round it. Blue walks every unit at red's workshop instead
     (over the bridge, said on screen). It is still a reflex. A 40-round draw
     was also added, so that a game always ends.

   It is labelled on screen as rules, not a plan.
3. **Blue is a controller chosen from several, not one fixed AI.** Blue is
   whichever `DecisionPolicy` the scene was given, and a key or a menu line
   names it:
   - the rules above (this task);
   - the planner (T11);
   - the learned policy, once T26 gives it a real combat to decide about.

   That is how three "blue"s share one board without one replacing another,
   and how T11 and T12 can play them against each other. T11 and T12 name
   the rule-based blue as their baseline.
4. **Its decisions are shown before they are played** (invariant 13): what
   it will build and why, and where each unit will walk. Then the scene
   becomes `make demo-tactical`, and an example under `check_demos.py`.
5. **One line on screen**: "tactics in the style of Advance Wars: build,
   cross the river, take the enemy workshop". Plus what the computer is
   using.
6. **A win condition**, so a game ends: take or destroy the enemy workshop.
   Destroying needs T26; until then, taking it is standing a unit on the
   cell beside it at the start of your turn, and that is written down as
   provisional.

## Acceptance

```bash
make test-godot
make lint-demos
make test-demo-overlays
```

The suite must include:
- a spent unit cannot move again this turn;
- selecting moves to the next unspent unit;
- an undone move restores the unit and its spent state;
- blue's rule-based turn is legal on every move it makes, over many seeded
  games;
- the game ends when the win condition is met.

## Manual check

Play a game against blue without reading anything but the screen. You should
never have to click a unit you have already moved, and you should be able to
say what blue is about to do before it does it.
