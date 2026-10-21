# T51 — A bot match: two teams of bots, cover, and a commander

Size: L · Prereqs: T49, T50 · Files: `godot/game3d/botmatch/`, `godot/addons/`, `python/gameaikit/`, `spec/vectors/`, `godot/test/`

## Goal

The owner's "multiplayer" shooter with no network: a capture-and-hold
match -- as in an Unreal Tournament or Killzone bot match -- played by two
teams of bots, autonomous and cooperating, using the level's cover. The
player watches, pauses, and switches techniques on and off on either team,
and sees the difference.

T49's survey picked what this teaches. Each technique is drawn, because a
team decision nobody can see is a number nobody trusts (invariant 13):

1. **Positions scored on screen, with claims** (Killzone, CryEngine's
   tactical position system, The Last of Us). Each bot generates candidate
   points near it, drops those that fail a condition, weighs the rest --
   cover from known threats, line of fire, range, travel -- and takes the
   best one nobody on its team has claimed. Every candidate is drawn,
   coloured by status, with its score. **Toggle: claims off**, and bots
   bunch on the same cover.
2. **A commander over a shared influence map** (Killzone 3, Halo 3,
   Paragon). Per team, weighted objectives -- each capture point to take or
   hold -- with an ideal number of bots; squads assigned by weight and
   distance; squad paths that avoid enemy-held areas and each other's
   routes. **Toggle: commander off**, and each bot heads for its own
   nearest point.
3. **Squad confidence**, attack/hold/retreat, and **retreat in waves** with
   cover fire (Days Gone). Drawn as a bar per squad and the frontline.
   **Toggle: off**, and squads never fall back.

The single bot underneath is the plainest selector that holds: a priority
list (take cover, shoot, reload, move to the squad's area), interrupted
when the world changes. T15 is where the other ways to decide are
compared; this task does not wait for it.

**Decided by the owner, 2026-10-21 (wave 70):** both ways to see it --
watch, as above, and one key to take the place of any bot of either team
at any moment, played in third person with the same body and rules as a
bot (WASD, the mouse aims, a click fires). The player's teammates respect
its claim, and its squad's commander counts it. The measurements below
stay bots-only.

## Steps

1. **The snapshot** (ADR 0018): positions, health, ammunition, the cover
   points, and a sight table between them, built by the 3D scene from ray
   casts. Every decision above is a function of it.
2. **The rules**: health, one hitscan weapon, reload, respawn, capture by
   standing on a point, a score to a limit. Written once as data, read by
   both languages (ADR 0007).
3. **The three techniques**, each in its own addon or file with its header
   saying when not to use it; each with a Python twin and conformance
   vectors fixing its answer on stated snapshots.
4. **Honest bots**: every bot acts through the same controls a person would
   have; reaction, turn rate and aim error are named knobs (T49's
   difficulty section), the same for both teams unless the viewer changes
   them.
5. **The arena**: a blocky level from an open pack (KayKit Prototype Bits
   is the candidate) in `assets.json`, with box fallbacks. Characters from
   Quaternius's Toon Shooter kit or KayKit's animations, likewise.
6. **The views**: a free camera, a camera on any bot, and a 2D map of the
   whole match with positions, claims, the influence map, squads and their
   objectives.
7. **Take over a bot**: a key puts the player in the watched bot's body,
   either team, and gives it back to its priority list on the same key.
8. **A match runner** headless: N matches on fixed seeds, each technique on
   or off per team, printing the score and the counts that show what each
   technique does.

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
./scripts/godot --headless --path godot -s res://test/botmatch/botmatch_effects.gd
make test-botmatch-effects
make test-teamwork-vectors
```

`botmatch_effects.gd` runs 20 seeded matches per pairing and must hold, with
each margin stated as a number in its header:

- with claims on, two bots of one team stand within one metre of each other
  in cover less often than with claims off;
- a team with the commander on orders its bots over more points at once
  than the same team with it off. **Changed by the owner, 2026-10-21:** the task said
  "holds points longer", and measured, it does not -- a team with every
  technique on loses to the same team with any one of them off. The owner
  chose to state that (`docs/godot/botmatch.md`) rather than tune until it
  passed; making the coordinated team win is T65;
- a team whose squads retreat in waves loses fewer bots per point lost than
  the same team that never retreats;
- every bot fires only at an enemy in its own sight table -- no bot shoots
  through a wall or at what it has not seen.

T50 measured that 3D physics runs headless. These run on the snapshot-level
simulation anyway, which is faster: about four minutes for 80 matches.
`botmatch_test.gd` holds the simulation's sight lines to Godot's own rays.

## Done (wave 70)

- `ai_teamwork`: tactical positions with claims, a team's additive
  influence, the commander, squad confidence and the waves. Each has a
  Python twin, and 17 vectors are derived from a third copy of the rules.
- The match in `godot/game3d/botmatch/`, a simulation with no physics
  engine, six a side in three squads of two, mirrored. Rules and arena are
  data (`rules.json`, `arena.json`). Step 5's arena is primitives plus
  Kenney's Mini Characters from T50's manifest. KayKit's itch.io page was
  not used.
- The views: free camera, follow camera, and the 2D map with influence,
  orders, confidence and the frontline. The owner's takeover of any bot.
- The four claims, measured with the rifle's rules: bunched 0.1 s against
  500; orders over 2.44 points against 1.94; 34 bots lost a point lost
  against 700; 0 unseen shots, and 455 from the planted cheat.
- First person, after the owner played the third-person cut and found it
  "mt esquisito". The shot is a 3D ray with tracers, a muzzle flash, hit
  markers, a hurt flash, a rifle in view and a generated sound. The rifle's
  rules are ten shots a second, a magazine of thirty, and a damage of 12.
- Steps 2 and 3's "read by both languages": the techniques are, through
  their vectors. The match's rules are read only by GDScript, because no
  Python side plays the match.

## Manual check

Watch a match with everything on, then switch each technique off on one
team. Can you say, before the score does, which team is coordinating and
why? Is every bot's chosen cover the one the drawn scores say it is?
