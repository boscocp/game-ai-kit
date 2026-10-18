# T52 — Bots against the player, with an optional stealth

Size: L · Prereqs: T49, T50, T14 · Files: `godot/game3d/infiltration/`, `godot/addons/`, `python/gameaikit/`, `spec/vectors/`, `godot/test/`

## Goal

The owner's single-player shooter: a third-person level in the manner of
Splinter Cell or The Last of Us, where enemy bots cooperate against the
player. The player can go in shooting, or -- optionally -- stay unseen: the
same bots then have a stealth version, perceiving, growing suspicious,
searching and calling each other.

T49's survey picked what this teaches, one technique per question the
player asks of an enemy, each drawn and each switchable:

1. **A role arbiter** (The Last of Us's combat coordinator). At least one
   enemy is always shooting, a single one is chosen to flank by the best
   flank route, the rest take cover and move up; requests granted and
   refused are shown. **Toggle: off**, and every enemy that can shoot does,
   and nobody flanks. (A cap on how many may shoot is tokens, step 5 -- not
   the arbiter.)
2. **Awareness that accumulates, and three alert levels** (The Last of Us,
   Splinter Cell: Blacklist, Crysis). Each guard's awareness rises while it
   sees the player -- faster near, in light, when the player moves -- and
   falls while it does not; thresholds for suspicious and alert. Drawn as a
   bar over each guard with its thresholds; the kit's fuzzy suspicion (T14)
   grown from a grid to rays at the body. **Toggle: a plain yes-or-no sight
   test**, and the player sees why the accumulator is fairer.
3. **A shared belief map for the search** (Third Eye Crime, The Last of
   Us), with **a search coordinator** handing out spots (Welsh). Where the
   player might be, spreading while nobody looks and wiped wherever any
   guard can see, drawn as a heat map; spots claimed and searched shown as
   dots. **Toggle: off**, and guards walk to the last known position, look,
   and give up.

## Steps

1. **The snapshot** (ADR 0018), as T51's, plus light at the player's feet,
   stance and noise events with a radius measured along the navigation
   graph, not through walls.
2. **Perception**: a vision shape that is not a plain cone (wider near,
   narrower far), rays to a small number of points on the body, light and
   movement as modifiers. Its Python twin and vectors fix the awareness a
   guard reaches from a stated snapshot sequence.
3. **The alert levels and their decay**, the last known position shared by
   whoever saw the player, and an alarm when a guard finds a body or a
   partner goes quiet.
4. **The three techniques**, as above, each with a header saying when not
   to use it.
5. **Honest difficulty**: reaction, turn rate, aim error and time to notice
   as named knobs. If attack tokens are used to pace the fight (Ocio
   Barriales), the overlay shows who holds one -- a rule about which shots
   may land, said as such.
6. **The level and the player**: a third-person controller, crouch, a
   distraction to throw; the level from an open pack in `assets.json`,
   with fallbacks.
7. **The overlay** (invariant 13): every guard's shape, awareness bar and
   state, the shared last known position, the belief map, the roles; and a
   2D map of the level with all of it.

## Acceptance

```bash
make test-godot
make test-python
make test-vectors
python3 scripts/check_addon_deps.py
python3 scripts/check_readability.py
python3 scripts/check_no_assets.py
python3 scripts/check_demos.py
```

```bash
./scripts/godot --headless --path godot -s res://test/infiltration_properties.gd
```

`infiltration_properties.gd` drives a scripted player over seeded levels
and must hold:

- no guard's awareness rises on a frame when no ray reaches the player and
  no noise reaches it along the graph -- nothing is known that was not
  perceived;
- a guard that loses sight of the player goes to the shared last known
  position, not to where the player now is;
- with the belief map on, guards reach the player's hiding place in fewer
  steps on average than with it off, by a margin stated in the header;
- with the arbiter on, at most one enemy holds the flanker role, and on
  every frame where any enemy can see the player at least one is shooting;
- a player who stays in shadow, crouched and out of the shapes, finishes
  the level on a seeded route without any guard reaching alert.

## Manual check

Play the level twice, loud and quiet, with each technique on and off. When
a guard spots you, can you tell why? When they search, can you see where
they think you are, and does hiding somewhere they have just looked feel
like a choice you made?
