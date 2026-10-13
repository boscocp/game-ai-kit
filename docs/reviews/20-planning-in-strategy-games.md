# Review: wave/20-planning-in-strategy-games

A mini wave with no code in it: research, a concept page, an ADR and task
files. That made it easier to review, not less necessary to. Three fresh
contexts reviewed it in turn, none of which wrote it, and the first found that
the page's headline claim was contradicted by the sources it cited.

## What was reviewed

- `docs/concepts/planning-in-strategy-games.md`: twenty-four sources, from
  shipped games and from the research literature, with every quotation checked
  against the source's text.
- `docs/adr/0010-the-rts-enemy-plans-at-the-top.md`, proposed rather than
  accepted.
- Tasks T24 (one window for every example) and T25 (one team per technique, a
  league scored twice), both new, and changes to T11, T12, T15, T18, T19 and
  T20 that follow the research and the owner's requests: a cost and
  efficiency meter, and a minimum RTS built backwards from the AIs.

## Findings

### The thesis the sources contradicted

The page said strategy games "plan only at the top". Killzone 3's HTN planner
is the individual bot's, and its squads plan with HTN too; the shipped
commander assigns objectives by weight, and the HTN commander is future work.
F.E.A.R. planned per soldier. What the sources support is narrower: nobody
plans the whole game in one search. Planning only at the strategic layer is
now presented as this kit's choice for an RTS, with its reasons, and T25's
league is where a team that plans lower down can show it was wrong.

### Sources quoted beyond what they say

- Total War: Rome II's search was bounded, one turn ahead with an anytime
  property. The page had called it unbounded, and the article gives no cause
  for the slow launch.
- Chan et al.'s comparison with general temporal planners is quoted from their
  own earlier paper, the list had two more planners, and 0.1 s was the time
  limit they set, not a measured time.
- The AoE II 20 ms line was cited to the wrong page. Dill's "timeslice" was
  about recomputing regions on changeable terrain, not about attack scoring.
- Humphreys' "backward search" clashed with this kit's own forward
  `StripsPlanner`, and Horizon was cited for per-agent planning that was never
  checked; it is no longer.

### Tasks that contradicted each other

- T20 used T15 and T25 without naming them as prerequisites.
- T25 depended on T19's frame budget and measured actions per minute on a
  turn-based board, where neither exists. It now runs on the turn-based board
  with the measures that board has, and the clock's half moved to T20.
- T25 claimed T5's rows would serve behaviour cloning (they are one per
  combat), and then that T18 would read T25's recordings, although T18 clones
  a fighting game. The two share the shape of a row, not the data.
- T25's "human" noise was close to T12's strength noise. The difference is now
  written down in both files.
- T11 asserted that a heuristic never visits more worlds than breadth-first
  "on any problem", which no theorem promises, and spoke of a partial plan
  that breadth-first does not have.

### An acceptance command that passed on nothing, three times

T12's never-cheat check was `grep -qv`, which succeeds whenever any one line
fails to match, so it passed on a file full of cheats. That predates this
wave. The first fix, `! grep -q`, passed on a missing file and failed on a
comment saying "never cheats". The second fix passed on a missing file when
the block ran as one script, passed on `BONUS_RESOURCES`, and failed on a
trailing comment. It is now an allowlist, run as a headless script that
asserts every preset sets only the documented knobs, beside a one-line
tripwire checked on six planted files. **A denylist of names catches only the
cheats somebody thought to name.**

### Acceptance a script could not hold

T19 asked a script to assert that "an AI's action that bypasses the command
interface is refused", in a language with no access control. That became
three checks a script can run: a replay with no AI attached must reach the
live run's digest; the view an AI receives holds no reference to the world;
and illegal commands must leave the digest unchanged. Its fog check would
have passed on an empty view, and now plants an enemy on each side of sight.

## What was done about them

Everything above was fixed on this branch, in 31771f2, e5fd52f and 7ac65cf.
The first two rounds of fixes each went to a fresh reviewer.
**The third round's fixes were not reviewed again.** They were checked with
the gates and with the six planted files for T12, and that is all.

Every quotation in the concept page was checked against its source by the
author and again by the reviewers. Some sources could not be opened: the
StarCraft II built-in AI, Company of Heroes, Planetary Annihilation, Ashes of
the Singularity, the Mark and Dill utility talk at GDC 2010, Orkin's GOAP page
and the gamedev.net forum threads. The page lists them as not verified, and
nothing it says rests on them.

Recorded rather than fixed:

- ADR 0010 is **proposed**. T11 and T20 measure it, and it is accepted or
  amended on their numbers.
- T12's tripwire can still be tripped by a string literal; the allowlist is
  the real check.
- The order of the task table is unchanged. `make wave` still picks T13 ahead
  of T21 and T24, which is the owner's decision.
