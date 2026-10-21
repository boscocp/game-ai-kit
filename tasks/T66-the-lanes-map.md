# T66 — The bot match on a map made for tactics, with a body to aim at

Size: L · Prereqs: T51 · Files: `godot/game3d/botmatch/`, `godot/game3d/assets.json`, `godot/addons/ai_teamwork/`, `python/gameaikit/teamwork/`, `spec/vectors/teamwork/`, `godot/test/botmatch/`, `docs/godot/botmatch.md`, `docs/concepts/shooter-ai.md`

## Goal

The owner played T51's bot match on 2026-10-21 and asked for six changes,
in their words:

1. a better map: "a parte de captura ta mt exposta, nao permite estratégia
   de flaquear", the spawn "mais protegido, ter algum corredor", like
   Counter-Strike or Unreal, "com parte em cima tbm, dando pra subir";
2. "shift pra correr", and "ao correr n pode atirar";
3. "a cada 30 tiros tem que recarregar a arma";
4. "um modelo mais humanoide";
5. "3 areas de dano com multiplicadores, cabeça 2x corpo 1x e membros .5x";
6. and that the AI takes all of it into its decisions: "mais dificil acertar
   cabeca com mais recompensa", "ajustar a IA com esses novos parametros".

This task also carries T65's question: on a map that rewards holding,
does the coordinated team win? T65 stays open until this task has
measured that.

## Decided (2026-10-21)

- **The map is option 1, three lanes** -- the owner's pick from three
  sketched from the research below. Each point has its own lane and one
  doorway choke. The spawn rooms open into a rear rotation corridor
  through doors offset from the lanes, so no lane sees into a spawn. Two
  bridges flank B, with stairs from both sides, to take B from above.
  Every point has cover. Spawn-to-point time is equal for every point and
  both teams. The sketch, 1 character = 2 m:

  ```
      000000000011111111112222
      012345678901234567890123
   0  ########################
   1  ####..#....AA....#..####
   2  ####..+..=.##.=..+..####
   3  ####..#....AA....#..####
   4  ####..##^HHHHHH^##..####
   5  #rr+..#..HHHHHH..#..+bb#
   6  #rr#..#....BB....#..#bb#
   7  #rr#..+..=.oo.=..+..#bb#
   8  #rr#..+..=.oo.=..+..#bb#
   9  #rr#..#....BB....#..#bb#
  10  #rr+..#..HHHHHH..#..+bb#
  11  ####..##^HHHHHH^##..####
  12  ####..#....CC....#..####
  13  ####..+..=.CC....#..####
  14  ####..#....CC....#..####
  15  ########################
  ```

  `#` wall, `+` door, `=` low cover, `o` pillar, `H` platform 2-3 m up,
  `^` stairs, `r`/`b` spawns. **The sketch is not exactly mirrored** (row
  13 has cover on one side only, and row 1-3 and 12-14 differ). The built
  map must be: the fair mirror is claim 0 of `botmatch_effects.gd`.
- **Research, done in wave 70** (a subagent; each source opened, two
  failed and are not used): three main paths with one choke each and no
  more than three divergent paths [World of Level Design, CS layouts];
  spawns equidistant from points, 3-9 s from a start to a point, no start
  in sight of a point [Unreal Wiki, Mapping For DDOM, Placing PlayerStart];
  a domination map wants two or three height levels, linked by ramps
  [Unreal Wiki, Z-Axis]; point entrances are not chokes, each point has
  cover; one choke per lane, and none coverable all from one spot [Level
  Design Book, balance]; low cover 1.0-1.25 m, high 1.75 m and up [Level
  Design Book, cover]; a perch must be contestable from several sides
  [Game Developer, Halo 5 Plaza]. No source gave sightline lengths in
  metres. Write this into `docs/concepts/shooter-ai.md` with the URLs,
  re-opening each.

## Steps

1. **Height in the simulation.** Every walk cell has a floor height. A
   bot stands on it, its eyes 1.5 m above it, and sight lines run from
   there. The walk graph allows a step between neighbours only within a
   stair's rise. It is a `SearchGraph` (T62's port), and A* runs over it.
   Keep red's paths searched in the mirror, as T51 found it must be.
   `botmatch_test.gd`'s slab-against-physics check gains platforms and
   stairs.
2. **The map** in `arena.json`: walls, doors, low cover, pillars,
   platforms and stairs. Then two tests: one that it is mirrored exactly,
   and one that the walk time from each spawn to each point is equal
   within a stated tolerance and inside 3-9 s.
3. **Sprint** (Shift, for the person and the bots alike): faster, and no
   firing while sprinting. It is a rule in `rules.json`. A bot sprints
   when no enemy is in its sight row and its goal is far, and never when
   it is shooting.
4. **Reload you can see and hear**: the magazine stays 30. Show the rifle
   lowered and "reloading" in the HUD, and play a sound. A bot reloads
   when empty, and early -- by the rules' threshold -- only when no enemy
   is in sight, preferably at its cover spot.
5. **A humanoid body.** Look in Kenney's Animated Characters (CC0, direct
   archive link) first, through `assets.json` and `make assets-3d`. List
   the archive, and confirm the format, rig and animations (idle, run,
   aim, shoot) before writing the row. The primitive fallback becomes a
   humanoid too (head, torso, arms, legs), so the zones are visible with
   nothing downloaded.
6. **Three hit zones**: head 2x, torso 1x, limbs 0.5x, in `rules.json`
   with their heights and widths. The person's 3D ray picks the zone it
   crosses. Add a headshot marker to the HUD.
7. **Where to aim is a decision** (a technique in `ai_teamwork` or its
   own file, with a Python twin and vectors). For each zone, the chance to
   hit it given distance, aim error and exposure, times its multiplier;
   aim where that is highest. A bot's hit then lands by that chance on the
   aimed zone, spilling to a neighbour zone otherwise. Draw the choice in
   the overlay: each zone's chance and expected damage.
8. **Re-measure** with `botmatch_effects.gd` on the new map and rules,
   mirror fair, every existing claim with its planted case. Add:
   - aiming by expected damage does more damage a shot than always
     aiming at the head, at range; a planted always-head bot is the case
     it must reject;
   - T65's claim, if the numbers hold it: a team with every technique on
     holds points longer than the same team with any one off, by a margin
     in standard errors. If they do not, say so, as T51 did.
9. `docs/godot/botmatch.md`: the new map, rules and numbers.

## Acceptance

```bash
make test-botmatch-effects
make test-teamwork-vectors
make test-godot-some SUITES="test/botmatch test/ai_teamwork"
python3 scripts/check_no_assets.py
python3 scripts/check_readability.py
python3 scripts/check_modules.py
python3 scripts/check_doc_freshness.py
```

## Manual check

Play `make demo-botmatch` and take a bot over (T).

- Can you flank B by a bridge, and hold a point from its cover?
- Is your spawn safe until you leave it?
- Does sprinting feel right, and does the reload read as a reload?
- Does a headshot feel like one?
- Watching a bot (V), does its aim choice match the numbers drawn?
