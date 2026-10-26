# T65 — A coordinated team that wins

Size: M · Prereqs: T51 · Files: `docs/concepts/`, `godot/game3d/botmatch/`, `godot/test/botmatch/`, `tasks/`

## Goal

T51 measured what its three techniques decide, and what the fighting
made of it on a fair mirror (`docs/godot/botmatch.md`):

- claims change nothing in the score that 20 matches can tell;
- the commander looks like it helps, but at 1.8 standard errors that is
  not shown;
- retreat costs the match: a team that never falls back won 20 to 0.

The owner chose, on 2026-10-21, to state that, and to give "a coordinated
team that wins" a task of its own. The owner also asked, the same day,
for a better map: covered capture points, flank routes, spawns behind
corridors, and high ground you can climb. That map is the likeliest place
for falling back to cover to pay.

Studied before anything is tuned ([research before tuning]): what in a
shipped bot match makes holding, spreading and falling back pay?

## Steps

1. **Read first.** For Unreal Tournament's domination and Killzone's
   warzone bots, find what rewards a defender: spawn placement and respawn
   waves, how contested capture works, how big a point is against how far
   a defender sits, ticket and score rules. For each, write down what the
   source says and where it was read, and open every source before citing
   it, as T49 did. Write it into `docs/concepts/shooter-ai.md`.
2. **Propose**, from that reading, the fewest rule changes that should
   make coordination pay. State each one's expected effect as a number
   before measuring it. The owner picks among them.
3. **Measure** with `botmatch_effects.gd`, and add the claim T51 dropped:
   a team with every technique on holds points longer than the same team
   with any one of them off, by a margin stated in standard errors in the
   header, and the mirror still fair.
4. If no change from the reading makes it true, say so, and stop.

## Acceptance

```bash
make test-botmatch-effects
python3 scripts/check_doc_freshness.py
```

## Manual check

Watch a match where blue has everything on and red has the commander off.
Can you see why blue holds more points, before the score says so?

## Where it stands (wave 96, 2026-10-26)

The owner chose option (a) on 2026-10-26: change retreat, rather than close
the task as measured. Wave 96 did steps 1 and 2 only; nothing below is
implemented or measured yet. A fresh-context review of the first cut
(`docs/reviews/96-a-team-that-wins-the-reading.md`) corrected the analysis
and the proposals; this is the corrected text.

**Step 1, read.** In `docs/concepts/shooter-ai.md`, "What makes holding,
spreading and falling back pay (T65)": Unreal Tournament's domination and
its bots (the Liandri Archives, Polge's level designers' guide, the Unreal
Wiki, Smith et al. 2007), Killzone 2's and 3's warzone commanders
(Straatman et al. 2009 slides, 2013 chapter), Halo's two-stage fallback
(Isla's Halo 3 slides, Butcher & Griesemer), F.E.A.R. (Orkin 2006), Days
Gone (Karlsson 2021), Team Fortress 2's respawn waves and Battlefield's
tickets. What could not be opened is listed there.

**Today's numbers, before any change.** `make test-botmatch-effects` on
main at 1b70831 (T68 and every wave since in), 0 failures, 657 s wall
clock (648 s of shards) on 12 cores shared with other work. Blue's margin a
match against red with everything, 20 matches each, all on the lanes --
`_arena_for` gives the yards only to the pairing named "the yards":

| blue plays | margin a match | wins | deaths | points lost |
|---|---|---|---|---|
| everything | +10.0 +- 22.7 s | 12-8 | 956 | 202 |
| no claims | -37.3 +- 23.3 s | 7-13 | 975 | 197 |
| no commander | -4.1 +- 13.5 s | 9-11 | 691 | 277 |
| no retreat | +186.7 +- 10.2 s | 20-0 | 958 | 186 |

T68's runs played the no-retreat pairing too, but nobody wrote its number
down; T67's was +241.6 +- 8.3. What moved it since is T68 as a whole --
health that comes back, and the weighing of when to heal -- not one of them
measured apart. Never falling back is still (186.7 - 10.0) / sqrt(10.2^2 +
22.7^2) = 7.1 combined errors ahead. And the retreat saves no lives -- 956
deaths with it, 958 without -- so what it costs is the points. Blue's
squads of two or more spent 9823 decisions retreating, 491 a match at one
every 0.2 s: about 98 squad-seconds of retreat a match, for 177 s of
margin, so each second of today's retreat costs about 1.8 s of margin --
a point given up is neutral in 4 s, the enemy's in 8, and takes as long to
win back.

**What the reading says about why.** A death here costs 7 to 13 s (each
bot respawns 4 s after its own death; every walk back is held within 3 to
9 s by `botmatch_test.gd`, measured at 4.8 to 6.7 s in T66) and refills
health and rifle; it feeds the killer's streak, five of which earn a power
weapon. Breaking off to heal costs 10 to 15 s and refills only health. So
healing alone seldom pays for falling back; the point is what today's
retreat loses, since it saves no deaths. And the retreat walks 8 m towards
the spawn when confidence falls to 0.5, without looking at the point:
every source that falls back on purpose does so at the objective, and only
to cover (F.E.A.R.: "run away if he can find a path to safety, or hunker
down"). One more fact of the match's own: a point is contested only by a
body within its 3 m capture radius, and its holders stand in cover within
4.5 m and weigh spots up to 8.5 m out, so a holder in cover often does not
contest its own point.

## Proposals, for the owner to pick

Each prediction is blue's margin a match against red with everything on,
over the gate's 20 matches on the lanes, as `botmatch_effects.gd` prints
it; "ahead" is the two-margin method the gate already uses. They are
estimates from the arithmetic given with each, written before any
measuring, and are to be compared with what is measured, not tuned to.

1. **Fall back to cover at the point, not towards the spawn** (where).
   A retreat's movers ask `TacticalPositions` for a hiding place, T68's
   query (covered from every enemy the team knows of), within
   `hide_metres` of the squad's point, instead of 8 m towards home; with
   none, they hold where they are (F.E.A.R.'s hunker down). The confidence
   threshold stays. Removes `fallback_metres`.
   *Predicted:* no retreat at about +100 +- 20 s, 17 to 20 wins of 20.
   *Arithmetic:* the threshold still fires as often, about 98
   squad-seconds a match, and still leaves the 3 m radius, so the point
   still turns. What changes is the way back -- within 15 m of the point,
   about 3 s at 4.5 m/s, against walking back the 8 m and more a wave
   compounds -- and a hidden bot's exposure falls to 0, so it heals. If
   that halves the 1.8 s of margin a retreat-second costs: 177 / 2, about
   90, over everything's +10: about +100.
   *Measured (wave 97):* not alone -- the owner picked 1 and 2 together,
   and 1 was built and measured with 2 (below).
2. **Falling back weighed, not switched** (when; the owner's rule for a
   bot), **to proposal 1's place** -- so it needs proposal 1, which gives
   it somewhere to go once `fallback_metres` is gone. Each member of a
   squad weighs falling back as an errand in `ErrandChoice`'s unit, from
   what it perceives: the gain is the health it would get back (missing
   share times exposure, as T68 prices hiding) plus the death it would
   avoid (a chance times what a death costs: the respawn plus the walk
   back, at the walk's weight a second); the cost is each second away,
   plus the point it gives up when it is the last of its team within the
   point's area radius (4.5 m) of a point held or being taken with an
   enemy known near -- the seconds until the enemy owns it, at the hold
   weight. Not the capture radius: a holder in cover is seldom within 3 m,
   and the term would read zero. The waves stay as the coordination: a
   member falls back only while another covers. Confidence stops being a
   switch; removes `retreat_at` and `recover_at`.
   **The chance of dying is not a number to choose.** Picking a curve
   from "the enemy's share of the strength near it" to a probability would
   be a tuning constant under another name. It is measured instead: a
   printed run of the gate counts, for each band of health (tenths) and of
   exposure (0, a half, 1), the share of bots in it that died within the
   next 5 s, and that table goes into `rules.json` with the commit of the
   run that produced it -- data measured offline, as invariant 6 allows,
   never learned during a match.
   Retreat off is the bot with T68's hiding alone, as "no retreat" plays
   today.
   *Predicted, with 1:* about the everything margin, +10 +- 30 s, 8 to 14
   wins of 20, within 1.5 errors of everything -- retreat stops costing
   and is not shown to help. *Arithmetic:* with the point priced, a
   fall-back that gives a point up costs about 8 s at the hold weight and
   more, against a death avoided worth 7 to 13 s only times its chance; so
   it falls back seldom (T68's weighing hides 5.3 s a match), and the 177 s
   today's retreat costs mostly goes.
   *Measured (wave 97, at 6523962):* no retreat **+223.1 +- 8.4 s, 20-0**,
   against everything's -38.7 +- 24.3 s, 8-12: never falling back 10.2
   combined errors ahead, not within 1.5. The prediction was wrong. It
   does not fall back seldom: 251 fall-backs a match.
   **What it can claim, and how a weighing that does nothing is caught**
   (T68's hole): (a) blue falls back at least once a match on average, and
   (b) of its fall-backs, the share after which a point it held was
   neutralised within 8 s is at most half today's share. Today's share is
   not measured; the gate prints it first, from today's retreat, and the
   threshold is written down from that run before proposal 2 is measured.
   Two planted cases: never falls back (fails a), and the point's cost set
   to 0 (fails b). The existing retreat claim (some retreating decisions,
   none uncovered) stays; if proposal 2 falls back too seldom to meet (a),
   that is the finding -- the weighing does nothing here -- and is written
   down, not tuned away.
   *Measured (wave 97, at 6523962):* the baseline first, at 581820e
   (today's retreat, its play unchanged: the same four margins as wave
   96): 130.3 fall-backs a match, and after 95 of the 298 from a held point
   it was lost within 8 s, a share of 0.319 -- so the threshold written
   before measuring is 0.159. Then (a) 251.2 a match, held, and its
   planted never-falls-back (0) rejected; (b) 9 of 334, 0.027, held -- but
   its planted case, the point's cost at 0, measured 0.026 and **was not
   rejected**: the point's cost is not what keeps the point here; falling
   back to cover near it is. The existing retreat claim held (33516
   decisions, none uncovered). Said as measured, not tuned away.
3. **A death costs what it does in TF2: respawn in waves** (a rule). Waves
   every 10 s, a dead bot joining the wave after next, so 10 to 20 s plus
   the walk back, against healing's 10 to 15 s (`rules.json`'s
   `respawn_time` becomes a wave time; `BotMatch` respawns by wave). TF2
   scales its wave down below 8 players, to 5 s at three or fewer, by a
   formula the page does not give; at six a side that would be between 5
   and 10 s. The proposal takes the unscaled 10 s, and says so. It changes
   every pairing, so the mirror and every claim are measured again.
   *Predicted:* with today's retreat, no retreat at about +150 +- 15 s, 18
   to 20 of 20. *Arithmetic:* deaths are equal with and without retreat,
   so dearer deaths cost both about the same; slightly less, because fewer
   bots alive means fewer squads of two to retreat. With 1 and 2: no
   retreat at -40 to -80 +- 25 s, 4 to 7 wins of 20 -- everything ahead by
   about 1.5 to 3 errors, so the T65 claim may or may not reach 2.5.
   *Arithmetic:* a death now costs 13 to 29 s, about 21, against 10 to 15 s
   hidden; each death avoided keeps a bot in the fight about 8 s longer.
   Blue dies about 48 times a match; if the weighing avoids a quarter, 12
   deaths times 8 s is about 100 bot-seconds, and at about half a
   point-second each, about 50 s of margin.
   *Measured (wave 97):* with today's retreat, not measured -- it was
   gone by then. With 1 and 2, at 8739ed5: no retreat **+200.5 +- 14.1 s,
   20-0**, against everything's +0.2 +- 23.8 s, 12-8 -- everything 7.2
   errors *behind*, not 1.5 to 3 ahead. Wrong, and step 4 applies.
4. **The team holding most points respawns sooner** -- TF2's other rule
   ("generally reduced for the team that controls the most control
   points"), with 3: a reward for holding, which is what coordination is
   for. *Predicted:* it amplifies whoever holds -- margins and their
   errors both about a third larger -- so it changes the number of errors
   little; it makes holding pay, not falling back. Listed as 3's variant,
   not recommended first.
5. **Not recommended, listed because the sources point at it: a 5 s
   regeneration delay** (Halo: Combat Evolved's and Halo 3's; Modern
   Warfare's is about 6 s, from an article that does not say whose figure
   it is), against the owner's 10 s. Healing costs 5 to 10 s, under a
   death's 7 to 13. With 1 and 2: no retreat at -10 to -40 +- 25 s, within
   2 errors. It changes a number the owner chose, so it is the owner's
   alone.

Not proposed:

- **Battlefield's majority capture** -- it would take the point from the
  covering half of a squad falling back in waves.
- **Ticket bleed** -- it changes the score, not who falls back.
- **Spawn placement** -- Killzone's tactical spawn points, nearer the
  objective, make a death cheaper, which is against what the reading says
  this match needs.
- **Holding inside the capture radius** -- a spot's score could count
  contesting the point; it changes every pairing's holding, so it is left
  until a measured proposal 2 shows whether it is wanted.
- **Map tuning** -- the owner's rule: the bot copes on any map.

**Recommended: 1 and 2, then 3.** Proposal 2 is the change the owner's
rules ask for -- the bot weighs what it perceives, no threshold -- and it
needs 1's place to fall back to. Measured alone they test the reading's
claim that healing alone seldom pays for falling back while dying is
about as cheap. Proposal 3 is the lever every shipped team game read here
has and this match lacks. If 1, 2 and 3 together leave everything less
than 2.5 errors ahead of no retreat, step 4 applies: say so, and stop.

**How each is measured.** `make test-botmatch-effects` as it stands --
everything and no retreat on the lanes, 20 seeds -- after each proposal,
with the mirror (lanes and yards) within 2.5 errors and every other claim
still held. A no-retreat pairing on the yards would be new, 20 more
matches and about a tenth more time; it is worth adding once a change is
chosen, so the T65 claim is held on two maps. Proposal 2 adds its decision
claims and planted cases above, and the T65 claim (everything ahead of
each one-off pairing by 2.5 errors) is added only once a measured run
supports it.

## Where it stands (wave 97, 2026-10-26): closed as measured

The owner picked "t65 segue o recomendado, 1+2 depois 3". Wave 97 built
proposals 1 and 2 together, measured them, then added 3 and measured
again; the outcomes are written beside each prediction above. **Step 4
applied: no change from the reading made the T65 claim true.** Nothing
was tuned to reach it. Shown the result, the owner chose on 2026-10-26 to
close T65 as measured (the owner's "close as measured" choice -- not the
option (a) above, which was to change retreat): **the three proposals were reverted,
and the match plays as it did before wave 97.**

**Where the code is.** Every hash this file cites -- `581820e` (the baseline run, and the source of the dying table), `6523962` (1 and 2, after a claims fault was fixed), `8739ed5` (with 3) and `c5a995a` (the reverted match) --
is a commit of PR #40's branch `wave/97-a-team-that-falls-back`, the first
three from before its rebase. None survives the squash merge, and the
branch is deleted after it, so this file and `docs/godot/botmatch.md` are
the record; GitHub's timeline of PR #40 shows the force-push from them. The
reverted state on main is the squash-merge commit of PR #40. What was
built, in short:

- *where*: T68's hiding query asked within `hide_metres` of the squad's
  point (`MatchHealth.hiding_place` with a centre), holding when none;
- *when*: `ErrandChoice.weigh_fall_back`, a fourth errand -- gain: the
  health missing times exposure, plus the chance of dying within 5 s
  where it stands less in cover, times the respawn wait and the walk back
  at 0.05 a second; costs: the seconds away at 0.02 and, for the last of
  its team within 4.5 m of its point with an enemy known within 20 m, the
  seconds until the enemy owns it at 0.3. Its facts were
  `FallBackFacts`; the chance came from a table measured at 581820e and
  kept in `rules.json` with that commit. The waves split a squad that all
  wanted to fall back; confidence chose only attack or hold, and
  `retreat_at`, `recover_at` and `fallback_metres` were removed;
- *a rule*: respawn waves every 10 s, a dead bot joining the wave after
  next (`respawn_wave`), unscaled;
- *watchable*: a panel line with the fall-back sum term by term in both
  languages, and each bot falling back ringed on the map.

`make test-botmatch-effects`, blue's margin a match against red with
everything, 20 matches each on the lanes; in brackets, how many combined
standard errors everything is ahead of that pairing:

| blue plays | before (581820e) | 1+2 (6523962) | 1+2+3 (8739ed5) |
|---|---|---|---|
| everything | +10.0 +- 22.7 s, 12-8 | -38.7 +- 24.3 s, 8-12 | +0.2 +- 23.8 s, 12-8 |
| no claims | -37.3 +- 23.3 s, 7-13 (+1.5) | -49.3 +- 24.5 s, 8-12 (+0.3) | -13.4 +- 33.5 s, 7-13 (+0.3) |
| no commander | -4.1 +- 13.5 s, 9-11 (+0.5) | -182.0 +- 7.7 s, 0-20 (+5.6) | -161.7 +- 10.0 s, 0-20 (+6.3) |
| no retreat | +186.7 +- 10.2 s, 20-0 (-7.1) | +223.1 +- 8.4 s, 20-0 (-10.2) | +200.5 +- 14.1 s, 20-0 (-7.2) |
| the yards' mirror | +47.6 +- 32.0 s, 13-7 | -8.4 +- 38.1 s, 8-12 | -0.7 +- 41.0 s, 11-9 |

| falling back (blue, everything) | before | 1+2 | 1+2+3 |
|---|---|---|---|
| fall-backs a match | 130.3 | 251.2 | 144.5 |
| from a held point, then lost within 8 s | 95 of 298, 0.319 | 9 of 334, 0.027 | 8 of 303, 0.026 |
| the same, the point's cost at 0 (planted) | -- | 0.026 | 0.034 |
| deaths, with it / never falling back | 956 / 958 | 850 / 645 | 439 / 339 |

The mirror stayed fair on both arenas. The T65 claim held only against no
commander -- and that is the swing to note: without the commander blue
went from -4.1 (9-11) to -182.0 (0-20) once falling back was weighed, a
change nobody predicted, not studied further.

**The gate's two findings, with the change in:**

- **portability regressed**: on the six random arenas 3 points (1+2), then
  2 (1+2+3), were never taken; before, none. Replayed with falling back
  off on both sides, the same arenas took every point 2 to 7 times; with
  it on, one arena never had a bot within 3 m of its point A;
- **claim (b)'s planted case passed**: pricing the point at nothing lost a
  held point after 0.026 of its fall-backs, the weighing 0.027 -- the
  point's cost was not what kept points; falling back near them was.

**The diagnosis, from the counts, not tested apart.** Falling back was
short and constant -- 251 a match, about 1.3 s each by the squad-decisions
spent on it -- and blue regenerated less health with it, 571 points a
match against 883 never falling back. The health a bot would regain was
priced by its exposure *where it stands*, as T68 prices hiding: once in
cover that reads 0, the reason to be there is gone, and it walked back out
before it healed.

**Possible future work, not tasks.** Price the health at the post the bot
left -- the exposure it would return to -- rather than where it stands;
and respawn waves alone, which were never measured without 2.

**What stayed.** The gate prints, for every pairing, the fall-backs a
match and the share of held-point fall-backs followed by a loss within
8 s, and for the mirror the dying table by band -- measurements of today's
retreat, never claimed (`MatchFallBacks`). And a bot no longer claims a
hiding place over a teammate: that stacked two bodies on one spot when
places were claimed by the weighed fall-back, 366 s bunched in its first
run. That guard moved the baseline a little, and the mirror stayed fair:
on the reverted code (c5a995a) everything is -5.7 +- 20.4 s, 11-9, and no
retreat +184.5 +- 10.1 s, 20-0; the pairings it cannot touch are
unchanged (`docs/godot/botmatch.md` has every number).
