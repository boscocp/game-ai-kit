# Review: wave/113-xcom-style-mode-the-rules

T84: the XCOM-style mode of the tactical game, the rules. The
`TacticalRuleset` seam in `tactical` with `AdvanceWarsRuleset` wrapping
the existing classes unchanged; module `squad` with `SquadRuleset`, the
shot, cover and flanking, sight, `SideView`, the end, the scenario and its
own roster; the Python twin of the shot, the hand-checked vectors, and the
property check over 300 seeded positions.

A fresh context reviewed PR #54 at head 5fb0247, reading only.

**Verdict: changes requested, one blocker.** One blocker, three
should-fix findings and three nits. Every one was applied on the branch.

## What was reviewed

The diff against main: `tactical_ruleset.gd`, `advance_wars_ruleset.gd`
and the scene, `BlueTurn` and `TacticalDecision` routed through them;
every file in `godot/game/squad/` and `godot/test/squad/`;
`spec/squad/rules.json` and its two copies; `gameaikit.squad.shot` and
its test; the vectors and their README; `modules/squad.json`; the
Makefile target; `docs/godot/squad.md`; the task file and the STATUS row.

## Findings

1. **Blocker -- a shot at an enemy the side cannot see.**
   `SquadCombat.why_refused` checked the range and the line, not the
   shooter's sight. A mortar reaches 7 and sees 6: a red mortar on (3, 4)
   and a blue runner on (10, 4), the row clear, was a legal shot listed by
   `SquadRuleset.actions`, though red's view did not hold the runner. Its
   refusal texts ("unit %d is %d away") also told a side how far an unseen
   enemy stood.
2. **Should-fix -- two scene paths bypassed the seam.**
   `TacticalStatus._targets` listed "you could attack" targets with
   `TacticalCombat.why_refused`, so the squad mode would offer Advance
   Wars targets. `mode_name()` was read nowhere, and a `--record` game
   under `SquadRuleset` would have been written to `data/tactical/`,
   replayed by `TacticalRecording` under Advance Wars rules and mixed into
   the cloned player's dataset.
3. **Should-fix -- cover facing pinned in one language only.** Python's
   `facing > 0` turned to `>=` survived all ten vectors; no vector put the
   shooter level with the cover.
4. **Should-fix -- "if one piece sees another, it is seen back."** Only
   the line is mutual; the reach is each piece's (a runner sees 6, a
   shield 5).
5. **Nit -- the shooter's own cell as the target's cover.** A shooter on
   the tree beside its target gave the target half cover against itself.
6. **Nit -- the Advance Wars default written three times** (`blue_turn.gd`,
   `tactical_decision.gd`, the scene).
7. **Nit -- T87's task file** should say that `SquadRuleset.actions` has no
   hold or end-turn entry.

## What was done about them

1. A shot needs the shooter itself to see the target (`SquadSight.sees`:
   within its own sight, the line clear), checked before the range. A
   target that is gone and one not seen get the same sentence
   (`SquadCombat.unseen`), naming no cell and no distance. The property
   check gained the claim "no listed shot names an enemy outside its
   side's view". The reviewer's exact case is planted as a test (refused,
   not listed, the view empty), and so is the refusal that says nothing.
   Dropping the sight rule again (back to the line alone) fails the
   property at position 10 -- measured, then restored. `rules.json` is
   unchanged, as asked.
2. `TacticalStatus.text` takes the ruleset and lists the targets its
   `why_attack_refused` allows; a test shows a seen target offered and an
   unseen one not. The scene records only when its ruleset is Advance Wars
   (`_records()`, `AdvanceWarsRuleset.MODE`); a test mounts the scene with
   the squad ruleset and `recording` on, and it does not record. Still
   outside the seam, and said in the PR and the STATUS row: the status's
   headline, funds and points, and the legend, which T85 makes the mode's.
3. Two vectors: the shooter straight below a target with rock to its east
   (flanked, cover 0), and the shooter on the trees beside its target (no
   cover). The `>=` mutant now fails in Python; the counts are twelve.
4. Reworded in `squad_sight.gd` and `docs/godot/squad.md`: the line is
   mutual, the reach is each piece's own.
5. The shooter's own cell is skipped when reading the target's cover, in
   both languages, with the second vector above.
6. `AdvanceWarsRuleset.or_default`, used by all four callers.
7. A line in T87's decisions.

The squad suites (29 cases), the vectors in both languages and
`make check-affected BASE=origin/main` were run again on the result; see
the PR.

## For the owner

Three decisions, each with the reviewer's opinion:

1. **The defence values.** The shield's 20 and the runner's and wader's 10
   sit on top of cover's 40: a shield behind rock is hit 0% by a shield
   and 5% by a runner. The reviewer finds rock near-invulnerable and
   suggests defence 0-10. Left as written; the numbers are the owner's.
2. **The menu's `modes` key** stays T85's, whose Files line holds
   `godot/menu/`. The reviewer agrees.
3. **`RandomSquad` as the squad roster's one row**, the floor T85's first
   enemy must beat. The reviewer agrees.
