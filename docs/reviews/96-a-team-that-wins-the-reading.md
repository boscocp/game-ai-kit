# Review: wave/96-a-team-that-wins-the-reading

T65, steps 1 and 2 only, after the owner chose option (a) on 2026-10-26:
change retreat rather than close it as measured. The wave covers the reading
(`docs/concepts/shooter-ai.md`, "What makes holding, spreading and falling
back pay (T65)"), a baseline run of the effects gate, and proposals for the
owner to pick (`tasks/T65-a-coordinated-team-that-wins.md`). Nothing is
implemented.

A fresh context reviewed PR #33 at head db5d9b9.

**Verdict: no blockers.** The analysis and the proposals needed fixing
before the owner picks, and every finding below was applied on the branch.

## What the reviewer found sound

- Every quote is in its source, checked against the source itself.
- The facts about the code are right:
  - each bot respawns 4 s after its own death;
  - a respawned bot is whole, with a full rifle;
  - health comes back after 10 s without a hit, at 20 a second;
  - retreat starts at a squad confidence of 0.5 and walks 8 m towards the
    spawn, in two waves;
  - capture pauses while both sides stand on a point.
- The arithmetic for 7.1 combined errors is right: (186.7 - 10.0) /
  sqrt(10.2^2 + 22.7^2).
- The baseline is recorded with its commit (1b70831), its time and its
  machine.
- The predictions are written before any measuring, and the task keeps a
  stop condition (step 4).

## Findings, and what was done

1. **"Both arenas" was wrong.** `_arena_for` gives the yards only to the
   pairing named "the yards". Every other pairing plays the lanes, no
   retreat included.
   *Done:* the task now says the lanes throughout. It names a yards
   no-retreat pairing as a later addition, with its cost: 20 matches,
   about a tenth more time.
2. **"Held by `botmatch_test.gd`" was wrong for 4.8 to 6.7 s.** The test
   holds each walk within 3 to 9 s, and the means per point within 1 s of
   each other. The 4.8 to 6.7 s is T66's measurement.
   *Done:* both documents now say this. A death costs 7 to 13 s, not 9 to
   11 s.
3. **A holder in cover often does not contest its own point.**
   - The area radius is 4.5 m, and spots are weighed up to 8.5 m out (with
     `AREA_MARGIN`).
   - `_present` counts only bodies within the 3 m capture radius.
   - So proposal 2's "last within the capture radius" would read zero.

   *Done:* this is stated as the match's own answer to the reading's "how
   big a point against how far its defender sits". Proposal 2's term now
   applies to the last bot within the area radius. Holding inside the
   capture radius is listed under "Not proposed", with the reason.
4. **"No weighing can make falling back pay" overreached.**
   - Deaths are equal with retreat and without (956 against 958), so what
     today's retreat costs is the point. A fall-back that keeps the point
     contested could pay.
   - A death is not free: it feeds the killer's streak, and a streak of
     five earns a power weapon.

   *Done:* the claim is weakened to "healing alone will seldom pay", and
   both documents mention the streak.
5. **Proposal 2 removed `fallback_metres` and gave no place to go.**
   *Done:* it falls back to proposal 1's place and says that it needs
   proposal 1. The recommendation is now "1 and 2, then 3".
6. **Proposal 2's chance of dying was uncalibrated, and its new claim had
   holes.**
   - The mapping from the enemy's share of strength to a probability was
     a tuning constant under another name. *Done:* the chance is to be
     measured from a printed run of the gate, by health and exposure band.
     The table goes into `rules.json` with the commit of the run that
     produced it.
   - The new claim had no threshold and no baseline, and a bot that never
     falls back would pass it: T68's hole, a weighing that does nothing.
     *Done:* it is paired with a minimum number of fall-backs. "Never
     falls back" is planted as a second case. The threshold is to be
     written from a printed baseline run before proposal 2 is measured.
   - The existing retreat claim needs retreats, and proposal 2 predicts
     few. *Done:* the task says that if there are too few, that is the
     finding, written down and not tuned away.
7. **Spawn placement was in neither list.** *Done:* it is under "Not
   proposed": a forward spawn makes a death cheaper, which is against what
   this match needs.
8. **Proposal 3 left out half of the TF2 page.**
   - The page scales the wave down below 8 players, to 5 s at three or
     fewer, and the match has six a side.
   - The team holding the most points respawns sooner.

   *Done:* both are stated. The reward for holding is added as proposal 4,
   a variant of 3.
9. **Killzone 3's page numbers were off by one.** *Done:* the "ahead in
   score" and spawn-point quotes are p. 387; "did not survive" and "Defend
   locations" are p. 388; "regroup markers" is p. 385.

Nits, all applied:

- Killzone 2's DefendMarker is on slide 41.
- RETALIATE's HTNBots plans with HTN; it is not a scripted opponent.
- The Liandri Archives are labelled a fan wiki.
- The Unreal Wiki sentence is quoted on to "possibly control point,
  although I'm not sure".
- A point is "neutral in 4 s, the enemy's in 8".
- The 5 s regeneration delay is Halo: Combat Evolved's and Halo 3's.
  Modern Warfare's is about 6 s, from an article that does not say whose
  figure it is.
- "Each bot 4 s after its own death", not "one at a time".
- "Not measured since T68" was wrong. T68's runs played the no-retreat
  pairing, but nobody wrote its number down, and what moved it is T68 as a
  whole, not health that comes back alone.
- Each prediction now shows the rough arithmetic it comes from:
  - 9823 retreating decisions are about 98 squad-seconds a match, for
    177 s of margin;
  - proposal 1 halves that;
  - proposal 3 changes what a death costs;
  - about 12 deaths avoided, times 8 s, at about half a point-second each.

## Checks run after the fixes

`check_doc_freshness.py`, `check_links.py`, `check_literature_table.py`,
and `make lint-tasks lint-status` all exit 0. No new matches were played:
the fixes change prose and predictions, not code.
