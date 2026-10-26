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
implemented or measured yet.

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
match against red with everything, 20 matches each:

| blue plays | margin a match | wins | deaths | points lost |
|---|---|---|---|---|
| everything | +10.0 +- 22.7 s | 12-8 | 956 | 202 |
| no claims | -37.3 +- 23.3 s | 7-13 | 975 | 197 |
| no commander | -4.1 +- 13.5 s | 9-11 | 691 | 277 |
| no retreat | +186.7 +- 10.2 s | 20-0 | 958 | 186 |

Retreat was not measured after T68 until now. Health that comes back
narrowed the gap (T67: +241.6 +- 8.3) and did not close it: never falling
back is still 7.1 combined errors ahead. And the retreat saves no lives --
956 deaths with it, 958 without -- so what it costs is only the points.

**What the reading says about why.** A death here costs 9 to 11 s (a 4 s
respawn, one bot at a time, and a 4.8 to 6.7 s walk back) and refills
health and rifle; breaking off to heal costs 10 to 15 s and refills only
health. Dying is the cheaper way to heal, which is UT's rule ("no effect in
the score"), not TF2's (a 10 to 20 s wait) or Battlefield's (a ticket).
And the retreat walks 8 m towards the spawn when confidence falls to 0.5,
whatever the point: every source that falls back on purpose falls back at
the objective -- Halo's fallback point, UT's FallBackFort, Killzone's
regroup marker, Days Gone's short step to cover -- and only to cover
(F.E.A.R.: "run away if he can find a path to safety, or hunker down").

## Proposals, for the owner to pick

Each prediction is blue's margin a match against red with everything on,
over the gate's 20 matches, as `botmatch_effects.gd` prints it; "ahead" is
the two-margin method the gate already uses. They are estimates from the
arithmetic above, written before any measuring, and are to be compared
with what is measured, not tuned to.

1. **Fall back to cover at the point, not towards the spawn** (where).
   A retreat's movers ask `TacticalPositions` for a hiding place, T68's
   query (covered from every enemy the team knows of), within
   `hide_metres` of the squad's point, instead of 8 m towards home; with
   none, they hold where they are (F.E.A.R.'s hunker down). The confidence
   threshold stays. Removes `fallback_metres`.
   *Predicted:* no retreat goes from +186.7 to about +100 +- 20 s, still
   17 to 20 wins of 20: hidden bots heal and come back sooner, but a
   threshold that never looks at the point still gives it away. The T65
   claim stays false.
2. **Falling back weighed, not switched** (when; the owner's rule for a
   bot). Each member of a squad weighs falling back as
   an errand in `ErrandChoice`'s unit, from what it perceives: the gain is
   the health it would get back (missing share times exposure, as T68
   prices hiding) plus the death it would avoid (the chance of dying soon,
   read from the facts confidence already counts -- the enemy's share of
   the strength near it -- times what a death costs: the respawn plus the
   walk back, at the walk's weight a second); the cost is each second away,
   plus the point it gives up when it is the last of its team within the
   capture radius of a point held or being taken with an enemy known near
   (the seconds until the enemy owns it, at the hold weight). The waves
   stay as the coordination: a member falls back only while another
   covers. Confidence stops being a switch and becomes a percept; removes
   `retreat_at`, `recover_at` and `fallback_metres`. Retreat off is the bot
   with T68's hiding alone, as the "no retreat" pairing plays today.
   *Predicted:* retreat stops costing the match and is not shown to help:
   no retreat at 0 +- 30 s (between -30 and +30), 8 to 12 wins of 20, within
   1.5 errors of everything. Because a death costs about what healing does,
   the weighing will seldom fall back (T68's weighing hides 5.3 s a match).
   A new decision claim it can hold: held points neutralised within 8 s of
   their last defender falling back, near 0 with it (today's count is not
   measured; the gate would print it first); planted, the point's cost set
   to 0.
3. **A death costs what it does in TF2: respawn in waves** (a rule). Waves
   every 10 s, a dead bot joining the wave after next, so 10 to 20 s plus the
   walk back, against healing's 10 to 15 s (`rules.json`'s `respawn_time`
   becomes a wave time; `BotMatch` respawns by wave). It changes every
   pairing, so the mirror and every claim are measured again.
   *Predicted:* with today's retreat, no retreat still wins, about
   +150 +- 15 s, 18 to 20 of 20 (a death costs more for both teams; the
   threshold still gives the point away). With proposal 2: no retreat at
   -40 to -80 +- 25 s, 4 to 7 wins of 20 -- everything ahead by about 1.5 to
   3 errors, so the T65 claim may or may not reach 2.5.
4. **Not recommended, listed because the sources point at it: a 5 s
   regeneration delay** (Halo's and Modern Warfare's, against the owner's
   10 s). Healing costs 5 to 10 s, under a death's 9 to 11. With proposal 2:
   no retreat at -10 to -40 +- 25 s, within 2 errors. It changes a number
   the owner chose, so it is the owner's alone.

Not proposed: Battlefield's majority capture (it would take the point from
the covering half of a squad falling back in waves), ticket bleed (it
changes the score, not who falls back), and map tuning (the owner's rule:
the bot copes on any map).

**Recommended: 2, then 3.** Proposal 2 is the change the owner's rules ask
for -- the bot weighs what it perceives, no threshold -- and measured alone
it tests the reading's claim that no weighing can make falling back pay
while dying is the cheaper heal. Proposal 3 is the one lever every shipped
team game read here has and this match lacks. If 2 and 3 together leave
everything less than 2.5 errors ahead of no retreat, step 4 applies: say so,
and stop.

**How each is measured.** `make test-botmatch-effects` as it stands --
everything and no retreat, both arenas, 20 seeds -- after each proposal,
with the mirror within 2.5 errors and every other claim still held;
proposal 2 adds its decision claim and planted case above, and the T65
claim (everything ahead of each one-off pairing by 2.5 errors) is added
only once a measured run supports it.
