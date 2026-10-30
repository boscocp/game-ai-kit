# How stealth AI is made: guards that notice, doubt, search and call for help

<!-- doc-meta
half_life: concept
verified_on: 2026-10-30
tier: 1
source: https://www.gameaipro.com/
invalidated_if: T69 or T70 stops doing what the last section says, T67's selector stops being how a bot chooses, or T90's director stops pacing by the reserve as its section says
teaches: stealth-ai
-->

> Before writing the guards of T69 and T70 -- bots against the player, with an
> optional stealth in the manner of Assassin's Creed, Splinter Cell and
> Metal Gear Solid -- read how others have. This page goes one level deeper
> than the stealth section of [the shooter AI page](shooter-ai.md), and is
> about one question: what a guard must perceive, know and weigh to look
> like a person looking for you, on any level it is put in. Every reference
> was opened before it was cited. Where only an abstract, or an article
> *about* a talk, could be read, the reference says so and is cited for no
> more than that. What could not be opened is listed at the end and not
> used. The kit's own 2D guards are [the stealth page](stealth.md).

## The short version

- **Perceiving and being aware are two things.** Splinter Cell: Blacklist
  defines awareness as "a set of discreet mental states ... that can be
  reached progressively over time through sensory perception", and
  abstracts it into a timer that fills while the player is inside a vision
  shape, unobstructed and lit [Walsh 2015]. The Last of Us, Crysis and
  Thief do the same with a counter, an envelope and a filter [McIntosh
  2015; Welsh 2013; Leonard 2003].
- **The alert phases are thresholds on that number**, not a separate
  machine. Crysis stores them as fractions of a stimulus's peak -- a
  quarter "interesting", five-eighths "threatening", the peak "aggressive"
  -- in a configuration file [Welsh 2013]. Metal Gear made the phases the
  game's rhythm, as design -- nothing about its AI's code could be read:
  alert, then an evasion phase "that creates a cautious behavior for the
  enemies after Snake evades the alert" [Alexander 2009, an article on
  Kojima's GDC talk].
- **A guard knows only what it perceived or was told.** The Last of Us's
  enemies "did not cheat with regard to knowing the player's location in
  most circumstances": nobody updates it unless one of them perceives him
  [McIntosh 2015]; Crytek's reason is that once players see the AI cheat,
  "they naturally tend to feel cheated" [Welsh 2013]. The three admitted
  exceptions in these sources -- a few seconds of "knowing" after sight is
  lost, a search weight towards the player's real position [Welsh 2015],
  and The Last of Us sending an enemy at once when the player is more than
  5 m from where the enemies think [McIntosh 2015] -- are cheats, and the
  sources say so.
- **The search runs on a belief, shared.** A map of where the player could
  be, spreading while nobody looks and wiped where any guard can see [Isla
  2013; McIntosh 2015], or a flood from the last known position [Couvidou
  2021]; a coordinator hands out spots hidden from it, and every guard marks
  off the spots it sees on the way [Welsh 2015].
- **Calling for help is perceived too.** Mark of the Ninja picks roles from
  whoever noticed the stimulus -- a leader who calls it out, an
  investigator, bystanders [Miles 2013]; Blacklist's guards notice a
  partner gone quiet [Walsh 2015]; Metal Gear Solid 2's guards radio for a
  strike team, and the radio can be shot out [Wikipedia, MGS2, an
  overview].
- **The player must be able to read all of it.** Blacklist's detection HUD
  is the player's "window of opportunity to break LOS" [Walsh 2015];
  Conviction drew the AI's best guess of the player as a silhouette
  [Martin 2009, a press preview]; Metal Gear's radar showed nearby
  enemies and their field of vision [Wikipedia, MGS 1998, an overview]. Assassin's Creed
  Mirage's vision is "shaped like a coffin" so that players "feel as
  though they're in perfect control" [Reparaz 2024, Ubisoft's article on
  the developers' GDC talk].
- **Data, not code, is what makes it portable.** Crysis tunes each kind of
  agent's perception in a file [Welsh 2013]; Mark of the Ninja's sixty
  kinds of interest are declared by designers [Miles 2013]; Thief was
  "highly data-driven" [Leonard 2003]. A research guard driven only by
  fields over the level's graph, tuned by a handful of parameters, was
  evaluated on five maps [Xu & Verbrugge 2025].

## What a guard perceives

### Vision is a shape and a certainty, not a cone

A plain cone fails both ways: The Last of Us found that "players right next
to the NPC would be unseen, while NPCs too far away were noticed", and made
the angle of view "inversely proportional to distance" [McIntosh 2015].
Blacklist replaced Conviction's distant boxes with "coffin-shaped boxes ...
that expand up to a point like a cone and then start to contract", plus a
cone ahead and a peripheral shape; the most inclusive shape the player is
in sets the range of the detection timer [Walsh 2015]. Crysis has a primary
and a peripheral field, and gives the peripheral stimulus a lower peak and a
longer attack, so a target at the edge "will take longer to identify"
[Welsh 2013]. Assassin's Creed Mirage chose the same coffin, on purpose:
"in real life, you see roughly 180 degrees, but here it's shaped like a
coffin", and if a guard cannot see a player near him "he looks
incompetent", while being spotted from afar "feels super-unfair" [Reparaz
2024].

Rabin names the underlying move. Every hard edge -- seen at 10 m, unseen at
10.001 m -- "becomes part of the gameplay", and a probability is the wrong
fix, because a die rolled often enough eventually sees everything and the
player cannot model it. Read the zone's number instead as **identification
certainty**, from "I see something" to "that is the player", with movement
adding to it and camouflage or poor light taking from it [Rabin 2015].
Blacklist admits the edge never goes away: "If the player is 1 cm outside
of that threshold, then the NPC will stand there forever" [Walsh 2015].

### The body is a few points, and fewer is more readable

Blacklist casts rays to eight bones, and a stance sets how many must be
visible before detection starts -- more when the player is in cover
[Walsh 2015]. The Last of Us began with rays to nearly every joint,
weighted against a 60% threshold, and abandoned it because "players found
it difficult to anticipate whether a given cover point was safe or not";
it kept one point, the chest in stealth and the top of the head in combat
[McIntosh 2015].

### Light is the player's own measure

Thief weights the player's light to the floor beneath them, which "provides
the player with an objective, perceivable way to anticipate their own
safety" [Leonard 2003]. Mark of the Ninja's sight test asks whether the
target "is currently lit by a light source", unless the guard has night
vision [Miles 2013]. Assassin's Creed Shadows makes the rule absolute at
night -- "hiding in the shadows will make you invisible to enemies" -- and
lets the player make shadow by "destroying lanterns with a shuriken";
standing up increases "visibility", crouching quiets footsteps, and going
prone reduces visibility further [Ubisoft 2024]. Clint Hocking, a Splinter
Cell designer and Chaos Theory's creative director, puts the risk: with modern diffuse lighting it is "very
hard to tell what's light, what's shadow, what's dark, what's safe, what's
dangerous" [White 2026, an interview]. The article on Kojima's talk
credits Metal Gear Solid 2 with shadows enemies could cast and spot
[Alexander 2009].

### Sound goes round corners

Euclidean distance "would mean the player would be heard through walls".
Blacklist measures a sound along its graph of rooms and choke points, from
the source to the nearest choke into each next room [Walsh 2015]; Mark of
the Ninja runs A\* over a "sound mesh" of the level's empty space, so a
guard inside the radius with no path to the noise does not hear it [Miles
2013]; Thief propagates sound "through the 3D geometry of the world"
[Leonard 2003]. Metal Gear 2 is where hearing arrived: "not only the vision
you have to be careful, but the noises you make" [Alexander 2009].

### Everything else is a typed event

Mark of the Ninja's guards notice about sixty kinds of **interest source**
-- a gunshot, a footstep, a corpse, a "suspect" -- each a row with a sense,
a priority, a radius and a lifetime; a guard holds one interest at a time,
a higher priority replaces it, and corpses, noises and suspects share a
priority so "the last thing you notice is probably the most important
thing" [Miles 2013]. Blacklist's changed objects -- a door left open, a
light switched off -- are events with a lifetime that the first guard to
witness claims [Walsh 2015]. Crysis calls them stims: footsteps peak at 25,
weapon sounds at 50, the primary field of view at 100 [Welsh 2013].

## What a guard makes of it

### Awareness accumulates, and falls more slowly than it rose

- **The Last of Us**: a timer up each frame the player is seen, down each
  frame he is not; perceived at "around 1 or 2 seconds for the typical
  NPC", much lower in combat, much higher while the player has never been
  seen [McIntosh 2015].
- **Blacklist**: a timer whose range is set by the shape the player is in,
  scaled within it by distance, and by "lightness of the player, NPC state,
  etc." [Walsh 2015].
- **Crysis**: an attack-decay-sustain-release envelope per stimulus and
  target, a distance multiplier from 1 at the guard to 0 at 50 m, and a
  "pulse" that keeps the chased target first. Lengthening the visual attack
  "gives the player more time to lean out of cover" [Welsh 2013].
- **Thief**: awareness can jump to the goal state once a time threshold is
  passed, but it "decreases across some amount of time, passing through all
  the intermediate states", and the alertness feeds back into the senses
  [Leonard 2003].

### The phases

| source | the phases | what is in between |
|---|---|---|
| Blacklist [Walsh 2015] | nothing suspicious; investigate; detected | an intermediate state "at some percentage of the progress bar" |
| Crysis [Welsh 2013] | interesting 0.25; threatening 0.625; aggressive 1.0 | fractions of the envelope's peak, in data |
| Metal Gear 2 [Alexander 2009] | infiltration; alert; evasion | "the three alert modes created varying tension levels" |
| Metal Gear Solid [Wikipedia, MGS 1998] | alert; evasion, whose counter returns to infiltration | the radar is off in alert and evasion |
| Assassin's Creed, as a designer reads it [Costiuc 2016, a blog post] | unaware; aware; suspicious; alert | |
| Assassin's Creed Shadows [Ubisoft 2024] | after an escape, enemies "remain more suspicious going forward" | a lasting caution |

The common shape is a number, a few thresholds on it, and **a floor that
stays raised after an alert** -- Metal Gear's evasion and caution, Shadows'
lasting suspicion. Kojima's reason for the evasion phase is pacing: "I
thought I created more rhythm to the hide and seek" [Alexander 2009].

### Memory: the last known position, and what is done with it

When a guard loses sight it knows "the last position and direction"; a
cheap trick is to keep "knowing" the target for 2-3 s, which Welsh reports
in the Halo, Crysis and Crackdown series [Welsh 2015]. Extrapolating the
velocity fails: Dishonored 2's dead reckoning hit walls and gave up "when
there was still an obvious path to follow", and Dishonored's breadcrumbs
gave guards "essentially omniscience regarding players' whereabouts, which
can feel unfair" [Couvidou 2021]. Its replacement floods heat from the last
known cell over the level, with a barrier behind the player's last
direction, and chases the heat-weighted centre; the flood stops early in a
wide area, so the guard switches to a slow search, and runs on in a
corridor. Its step limit -- 20, 30, 40 -- was the difficulty setting
[Couvidou 2021].

Conviction showed the player that position, as "a ghostly silhouette of
the AI's best guess", and the enemy "will investigate or attack where they
think you are" -- which lets the player flank it [Martin 2009].

### Belief as a map

An occupancy map holds the target's position "as a discrete probability
distribution over space"; each unobserved step diffuses it, and locations
visible to the guards are zeroed. Third Eye Crime renders it "at all
times", and the fun "happens after, not before, the player is detected"
[Isla 2013, a demo paper]. The Last of Us's search map is the same: cells
"bleed into their neighbors over time" and any cell an enemy can see is
cleared each frame [McIntosh 2015]. Xu & Verbrugge write the whole guard as
three fields over the level's graph -- information spread by breadth-first
search from where the player was seen and decaying, a confidence each guard
deposits where it has looked, and the graph's own connectivity -- and
report it outperforming a state machine and a staleness patrol in capture
efficiency, on five maps, two of them named after Dishonored and The Last
of Us [Xu & Verbrugge 2025].

## What a guard does about it

### Investigating, and how many go

Welsh splits searches by what triggered them: a distraction (a thrown
bottle) starts a **cautious** search, hostile stimuli an **aggressive** one.
Phase 1 is the last known position: in a cautious search allowing "only a
single NPC" lets the player "peel targets away from a group"; in an
aggressive one "a limit of 2 or 3 characters searching simultaneously works
well", the others covering. Phase 2, aggressive only, is a coordinator's
list of spots [Welsh 2015]. Mark of the Ninja gets the same effect with no
group at all: the guards who detected one interest are the group, and roles
are dealt among them -- a leader who "plays audio dialog telling the other
agents nearby to go check out the interest and then hangs back", one or more
investigators, and bystanders -- after which "there is no 'group' to
manage" [Miles 2013]. Assassin's Creed Shadows' guards search "in pairs
(one watcher and one seeker)" [Ubisoft 2024]; The Last of Us hands out one
Investigator role through its combat coordinator [McIntosh 2015].

### Searching together

Welsh's coordinator generates spots from cover "obscured from the target's
estimated position", padded with hidden points on the navigation mesh;
gives each searcher the best free spot, marked "in progress"; and every
searcher ray-tests "all unsearched spots that they can potentially see",
every 1-2 s, so the area is swept once [Welsh 2015]. Two of his tricks are
choices this kit must not copy as they stand: the scoring adds a "subtle"
weight towards "the player's actual current position" to give "the
illusion of human intuition", and the first trick is to "cheat" for 2-3 s.
When the search ends, guards "filter back to their regular behaviors in
their own time", because stopping together looks like "one hive mind"
[Welsh 2015].

Blacklist's guards who cannot see the player cover the ways out of the room
he is in, from a hand-marked graph of areas and choke points, so that "NPCs
who couldn't get LOS on the player always had something intelligent to do"
[Walsh 2015].

### Calling for help, and noticing the silence

- **Radio and reinforcements.** In Metal Gear Solid 2, enemies "call on
  their radios for a strike team upon seeing the player", "often take cover
  to call for backup", and "players can shoot out the enemy's radio"; "even
  if the player escapes to a hiding place, a team will sweep in to check the
  area" [Wikipedia, MGS2, an overview]. The very first Metal Gear's design
  was already this: "when you get spotted you're going to get a lot of
  enemies chasing after you" [Alexander 2009].
- **Witnesses who are not guards.** Assassin's Creed Shadows' servants "will
  alert guards upon seeing you" [Ubisoft 2024]. Hitman's crowds become
  alert within a range of the player when he draws a gun, and a shared
  service holds "where in the world the player was last spotted" [Thompson
  2019, an article on IO Interactive's talks].
- **A body.** In Blacklist a searching guard who finds one for the first
  time "will get very agitated and call for help"; in a war zone he ignores
  it -- the same event, a different context [Walsh 2015]. Mark of the Ninja
  marks a corpse an interest each guard notices once [Miles 2013].
- **A partner gone quiet.** "If NPC A has been in earshot ... of NPC B for
  10 seconds and then for 5 more seconds after he stops making noise ...
  then we generate an investigation event", with a long cooldown [Walsh
  2015]. Welsh's version: an investigator who does not return becomes a new
  stimulus at his position [Welsh 2015]; Mark of the Ninja's, a "missing
  partner" interest [Miles 2013].
- **Constrained cascades.** Thief passes "sense links" between peers "with
  controls in place to constrain knowledge cascades across a level"
  [Leonard 2003].

### Social stealth: hiding among people

Assassin's Creed is the series this genre's "social stealth" is named
after, and the developer sources reachable here say little about its code.
A designer's blog post draws the useful line: traditional stealth "is based
on line of sight", social stealth "is based on behavior", and in the series
as shipped "crowds are just fancy bushes" -- hiding spots that block sight
[Costiuc 2016, a blog post]. Hitman's disguise service tells each character
"whether that outfit will look suspicious to them or not" [Thompson 2019].

## Fair, and readable

Walsh puts the rule in one sentence: "it really doesn't matter what the NPC
should see or hear; it's what the player thinks the NPC can see and hear".
His four requirements are fairness, consistency ("similar distances and
timing for reactions every time"), good feedback and plausibility; and his
fix for being heard by guards the player cannot see was to halve, for
certain events, the hearing of guards off screen and far enough away
[Walsh 2015]. He rejected the blunt fix, shorter hearing for everyone,
because a guard a sprinting player can see would then seem deaf; and he
kept the halving off for a guard just round a corner, where not hearing
would be "ridiculous" -- plausibility limits it [Walsh 2015]. Assassin's
Creed Mirage's team says the same of sight: "as fair as possible with
detection", so players "feel as though they're in perfect control"
[Reparaz 2024]. Crysis keeps its numbers in data so that designers can
tune without a programmer [Welsh 2013]. Kojima added the radar "to allow players
the opportunity to know where enemies off-screen were" [Alexander 2009].
And a user study found contextual dialogue let a simple guard match a
complex one in players' enjoyment [Al Enezi & Verbrugge 2023, abstract
only] -- the same lesson as Blacklist's tiered barks, which move from "I
think I heard footsteps" to "I think someone's over there" so the specific
line teaches once and does not repeat [Walsh 2015].

## Metal Gear: the design, not the AI

No developer source on how Metal Gear's guards are computed could be
found, so this page takes from Metal Gear only what a player can see of its
design, and makes no claim about its AI's internals:

- **The phases as pacing**: infiltration, alert, evasion -- "the three
  alert modes created varying tension levels" -- and, in the overview's
  account, a counter that returns the game to infiltration [Alexander 2009;
  Wikipedia, MGS 1998].
- **Radio and reinforcements**: guards who radio for a strike team, take
  cover to call for backup, a radio the player can shoot out, and a team
  that sweeps in to check where the player hid [Wikipedia, MGS2].
- **The radar**: where enemies off screen are, and nearby enemies' field
  of vision, switched off in alert and evasion [Alexander 2009; Wikipedia,
  MGS 1998].
- **The level**: objects to crawl under, boxes as cover, walls to duck
  behind, and 3D
  that "created additional hiding spaces when the player is pursued"
  [Wikipedia, MGS 1998; Alexander 2009].

How a guard reaches an alert, or how a strike team searches, the kit takes
from the sources above that describe their code.

## What this kit takes for T69 and T70, and what it leaves

The owner's rule for every example is that the AI is an agent -- it
perceives the world and its own actions and decides what to do to reach
its goal, with as little fixed if/else in the demo as possible, and it must
cope on another map with other models. T67 makes the bot match's bot that
agent: it perceives through
[`ai_perception`](../../godot/addons/ai_perception/), and a weighed
selector -- utility over actions, with a Python twin and vectors -- replaces
its priority list. The stealth guards (the owner's T52, split into T69 and
T70) are the same agent with other percepts and other actions. Nothing
below is a state machine the demo writes. T69 builds items 1-3 as
techniques with twins and vectors, T70 the level, items 4-8 and the player
on top of them.

Invariant 2 shapes where each piece lives: `ai_perception` depends only
on `ai_core`, and `ai_teamwork` on nothing. So the techniques take what
another addon computes as plain data -- a rate per step, path distances,
a neighbour list, which cells are seen -- and the guard's own module, the
example, wires `ai_fuzzy`, `ai_search` and them together, as T14 did.

**Taken**, mapped onto the kit's techniques:

1. **Percepts, in `ai_perception`.** A vision shape that widens and then
   narrows, read as certainty by zone [Walsh 2015; McIntosh 2015; Rabin
   2015]; rays to a few points on the body, the count a stance rule
   [Walsh 2015], and the overlay drawing which points were seen (the
   kit's addition); light sampled at the player's feet [Leonard 2003];
   hearing by path length along the level's walk graph, never through a
   wall [Walsh 2015; Miles 2013] -- the path lengths a flood the caller
   runs with `ai_search`, as today's straight-line `Hearing`'s header
   already says it should be. Typed events -- noise, body, open
   door, a guard's own call -- as data rows with a priority and a lifetime
   [Miles 2013; Welsh 2013].
2. **Awareness, in `ai_perception`; its rate from `ai_fuzzy`, in the
   example.** One number per guard and stimulus that rises with exposure
   and decays through every intermediate value [McIntosh 2015; Leonard
   2003]; the accumulator takes its rate per step as a number, which the
   example computes with a fuzzy controller of certainty, light, motion and
   distance, as T14's suspicion already is; thresholds as fractions in data [Welsh 2013], and
   a caution floor after an alert [Alexander 2009; Ubisoft 2024]. The
   phases are a *reading* of the number, which the selector takes as an
   input, not states with transitions in code.
3. **Knowledge, in `ai_perception`.** Each guard's memory of where and when
   it last perceived the player; and a shared belief -- an occupancy map
   over the walk graph, given as a neighbour list: collapsed to the seen
   cell while the player is perceived, and otherwise diffusing, with every
   cell a guard sees zeroed [Isla 2013; McIntosh 2015] -- written only from
   percepts and from reports a guard heard.
4. **Decisions, in T67's selector.** Hold the post, glance, investigate a
   point, search a spot, cover a way out, report, call for help, raise the
   alarm, engage, take cover, return: each a scored action whose
   considerations read the percepts, the awareness and the belief. "Cautious"
   and "aggressive" searches [Welsh 2015] are what the scores produce at low
   and high awareness, not two code paths.
5. **Cooperation, in `ai_teamwork`.** Welsh's search coordinator -- spots
   hidden from the belief's likely cells, claimed, marked off by sight --
   on T51's claims, the sight lines and the belief passed in as data; a cap
   on how many go to the last known position, from data [Welsh 2015; Miles
   2013]; and, once a fight starts, the role arbiter that T49 picked for
   this task [McIntosh 2015]. Calling for help is an action whose effect is a sound
   event, heard or not by the same hearing, so a guard out of earshot does
   not learn it, and a call cut short is never sent -- Metal Gear Solid 2's
   radio can be shot out [Wikipedia, MGS2].
6. **Search over the level, in `ai_search`.** Every route, the hearing
   flood and Dishonored 2's chase flood run over the same walk graph
   [Couvidou 2021], so a second level needs a graph, not code.
7. **Readable on screen** (invariant 13): each guard's detection bar with
   its thresholds [Walsh 2015], the last known position as a silhouette
   [Martin 2009], a radar map with the guards' shapes [Wikipedia, MGS
   1998], the belief as a heat map [Isla 2013], claimed and searched spots,
   and every action's score.
8. **Off-screen hearing halved, on by default** [Walsh 2015]: for footsteps
   and other minor events, a guard off screen and beyond a stated distance
   hears at half the radius; a guard near enough to be just round a corner
   hears in full. A rule about the camera, not the guard, so it is a named
   difficulty knob, shown on the overlay whenever it is on, and it only
   ever lowers what a guard hears. The default follows Walsh's finding that
   being detected by a guard the player cannot see feels unfair whatever the
   simulation says, and the Mirage team's aim of detection the player
   trusts [Reparaz 2024].

**Left:**

- **The 2-3 s of "knowing", and the search weight towards the player's
  real position** [Welsh 2015]: both read what the guard did not perceive.
  The kit's honesty claim forbids them; the belief map does the job
  instead. **The Last of Us's 5 m cheat** [McIntosh 2015] likewise.
- **Crowds and disguises** [Costiuc 2016; Thompson 2019]: no source here
  describes how Assassin's Creed or Hitman compute them, and hiding spots
  that block sight already teach what a crowd does in the shipped series.
  A later task, if the owner wants crowds.
- **Hand-marked areas and chokes** [Walsh 2015]: designer markup, which is
  exactly what a level made by a test does not have. Ways out of the
  belief's region are computed from the walk graph instead, or left.
- **Metal Gear's AI internals**: no source; only its design is taken, above.
- **Learned guards and learned patrols**: invariant 6, and no source above
  uses one. Xu & Verbrugge's fields are training-free and would fit a
  later patrol task [Xu & Verbrugge 2025].

## What T69 built (wave 79)

Items 1-3 above, as techniques with twins and vectors; nothing is on
screen yet, and nothing decides -- that is T70.

| piece | where | its sources |
|---|---|---|
| vision shape and body points | `ai_perception/vision_shape.gd`, `vision_percept.gd` | Walsh 2015; McIntosh 2015; Rabin 2015; Reparaz 2024 |
| light at the feet | `ai_perception/light_map.gd` | Leonard 2003 |
| hearing along a path | `ai_perception/path_hearing.gd`, `ai_search/cost_flood.gd` | Walsh 2015; Miles 2013 |
| typed events | `ai_perception/stimulus_table.gd`, `interest.gd` | Miles 2013; Welsh 2013 |
| awareness and its phases | `ai_perception/awareness.gd` | McIntosh 2015; Leonard 2003; Welsh 2013; Alexander 2009; Ubisoft 2024 |
| memory and the shared belief | `ai_perception/target_memory.gd`, `belief_map.gd` | Welsh 2015; Isla 2013; McIntosh 2015 |
| the belief as particles (T91) | `ai_perception/particle_belief.gd`, `particle_draws.gd` | Thrun 2002; AIMA 4th ed., ch. 14 |
| the guard types, the fuzzy rate, the wiring | `game3d/infiltration/` | Welsh 2013 (archetypes in data) |

Every number a guard is tuned by is a row of
`godot/game3d/infiltration/guard_types.json`: two types, a patrol and a
sentry. Three of its numbers are the sources' and the rest are the kit's,
chosen to be read and measured rather than taken from any game:

- **the phases' thresholds**, 0.25 and 0.625 of the peak for the patrol,
  are Crysis's "interesting" and "threatening" [Welsh 2013]; the sentry's
  0.3 and 0.65 are the kit's, to tell the two rows apart;
- **the rate at its fastest** is about 0.69 of the peak a second -- an
  unaware patrol sees a clear, lit body close by and is alert in about
  1.5 s, inside The Last of Us's "around 1 or 2 seconds for the typical
  NPC" [McIntosh 2015]; at its slowest, 0.10 a second, about ten;
- **the off-screen factor**, a half, is Walsh's [Walsh 2015].

The rest are the kit's own, and a sentence on each would be a guess about
some game: the zones' distances, openings and certainties; `dark_share`
(0.3 and 0.25) and `motion_bonus` (0.15 and 0.2); the decay; the caution
floor and its seconds; the stances' point counts; `heard_rate` (0.6 for
the patrol, 0.4 for the sentry); `off_screen_beyond` (8 m) and
`minor_priority` (1); the fuzzy sets' breakpoints; and the events' radii
and lifetimes.

A third limit, found by the owner playing T70 and fixed in wave 82 (T81):
a footstep is an event, but a player walking makes one every 0.4 s; a guard
that hears an event only in the step it arrives hears a walking player a
quarter of the time, and `Awareness` falls in between, because it rises
only while perceived. So a sound that goes on is held for as long as it
goes on -- delivered with its emitter's cadence -- and is not the event's
lifetime, which is how long it is remembered.

Two limits of what was built, for T70. Sound floods the walk graph, which
is 4-connected: a radius is a diamond, not a circle, ground slow to walk
is quieter to hear across, a door is only open or shut, and there is no
height -- an octile graph or a sound graph of its own would fix the first.
And in the properties a cell counts as seen when it is in a zone with a
clear line; in T70 it must mean that a target standing there would be
perceived, given its stance and the light, or the belief zeroes the cell
where a hidden player really is and loses them for good.

`make test-infiltration-properties` holds the claims T69 asks for on 150
generated levels and both types, each with a planted case it caught
(2026-10-22): a guard told the truth changed its memory with nothing
perceived; light inverted lowered awareness as the light rose; the other
row's thresholds read 0.25 as the wrong phase; Euclidean hearing let a cell
behind a wall hear; a factor above 1 made a far cell louder; diffusion
through a wall gave a node a share from no neighbour; and a guard posted
at a cell of one level found itself off the next.

## Pacing: a director over the guards (T90)

Everything above is about one guard, or a team of them, deciding well. A
**director** decides something else: how hard the *game* pushes, from how
the player is doing. Left 4 Dead's is the one everyone cites. Booth's
slides on it [Booth 2009, "Adaptive Dramatic Pacing"] say, nearly word for
word: estimate each survivor's "emotional intensity"; raise it in
proportion to the damage taken, and when an infected dies nearby,
inversely to its distance; let it decay "towards zero over time", but not
while infected are engaging the survivor; track the highest of the four;
and read four phases from it --

- **Build Up**: a full population of threats, until the intensity crosses
  the peak threshold;
- **Sustain Peak**: the same, three to five seconds more;
- **Peak Fade**: minimal threats, until the intensity falls out of the
  peak's range;
- **Relax**: minimal threats for thirty to forty-five seconds, or until
  the survivors have travelled far enough towards the next safe room;
  then Build Up again.

What it teaches is the separation: the enemies stay exactly as good as
they were, and the *population* -- how many, and when -- follows the
player. That is why it belongs beside stealth: a stealth level is all
build-up and release, and a level that never lets go is not tense, only
tiring.

**What this kit does with it** (T90, the infiltration level, key 6). One
player, so no maximum over four. The intensity rises when a guard's
awareness of you rises a phase -- more when it saw you than when it heard
you -- in proportion to the damage you take, and while a guard searches
near you, inversely to its distance; it decays at a fixed rate, and not
while a guard is chasing you (alert and seeing you, the closest thing here
to "engaging"). The threats are the level's **reserve guards**, patrols
that wait at posts out of the start's sight: in build up and the sustained
peak the director wants all of them walking their beats, in the fade and
the relax none, and it sends or calls back one at a time. The relax ends
after thirty seconds, or once you are fifteen metres nearer the exit.

Three rules keep it honest, and each is a test with a planted director it
must catch (`director_test.gd`):

- **it is the game, not a guard.** It knows where you are; no guard learns
  it through the director. Sending a guard gives it a route and nothing
  else -- the test compares every guard's belief and memory before and
  after the director acts, and catches a planted director that tells the
  guard where you are;
- **a new patrol never starts in view.** It only sends a guard you cannot
  see, and calls back only a calm one that sees nothing; nothing teleports;
- **it fits nothing** (invariant 6). Every weight and threshold is in
  `spec/director/director.json`; the director computes one number from
  what happened. Python's machine and Godot's are held to the same curves
  by `spec/vectors/director/`.

**What it does in practice is less than the cycle.** Measured over 39
seeded runs (`make measure-director`, [the infiltration page](../godot/infiltration.md#the-director-t90)):
seven tenths of the time is building up, a quarter fading, and the relax was
reached in one run of the 39. With nothing happening the director sends
both reserve patrols in its first seconds; most runs end, the player caught
or out, before a fade can finish; and where guards stay alert and see a
hidden player for minutes, Booth's "no decay while engaged" holds the
intensity at the top. So the four phases are the machine, held exactly by
its vectors; on this level the whole cycle is the exception, and the page
says so rather than tuning it into the rule.

When not to use one: as difficulty. A director that made the guards see
further when you are doing well would be a rubber band, and players feel
those. This one only changes how many there are, and when.

## Could not be checked

Not used above:

- No developer source on Metal Gear Solid's guard AI could be found or
  opened: no paper, slides or CEDEC report on MGS1-V. Kojima's GDC 2009
  talk is used only through Alexander's article on it, and the phases and
  radios through Wikipedia, both said as such.
- Assassin's Creed: the GDC Vault talks on Unity's crowds (Blondeau 2015;
  "Massive Crowd on Assassin's Creed Unity") and on Origins' meta AI are
  members-only; the Mirage talk is used only through Ubisoft's article. AWN's
  "Assassin's Creed: Redefining the Action Game" answered 403. PC Gamer's
  interview with Patrice Désilets on social stealth would not load past its
  headline.
- Splinter Cell: Conviction: no AI talk or slides found; the last known
  position is used through a press preview only.
- Hitman: Vehkala's GDC Europe 2013 talk, Fauerby's Game/AI Conference
  2012 talk and Büttner's paper there, and Schroder & Petersen's nucl.AI
  2016 talk -- used only through Thompson's article on them.
- Al Enezi & Verbrugge, "Evaluating Player Experience in Stealth Games"
  (AIIDE 2023): only a search summary seen, not used.
- Isla, "Probabilistic Target Tracking and Search Using Occupancy Maps", AI
  Game Programming Wisdom 3: still no copy found.
- Rabin & Delp, "Designing a Realistic and Unified Agent Sensing Model",
  Game Programming Gems 7: cited by Rabin 2015, no copy found.
- Booth's slides were not opened again for T90, though the task's first
  step asks for it -- a deviation: the director above is built from the
  passages T73 quoted from them (opened on 2026-10-26), and every phrase
  in quotation marks is one of those. Brewer's chapter on
  pacing (Game AI Pro Online Edition 2021, ch. 7), which T73 also cites,
  was not used.

## References

Shipped games -- talks, chapters and papers by their developers:

- Booth, M. "The AI Systems of Left 4 Dead." Valve, 2009 -- the
  "Adaptive Dramatic Pacing" slides.
  <https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf>
- Couvidou, L. "Flooding the Influence Map for Chase in Dishonored 2." Game
  AI Pro Online Edition 2021, ch. 6.
  <https://www.gameaipro.com/GameAIProOnlineEdition2021/GameAIProOnlineEdition2021_Chapter06_Flooding_the_Influence_Map_for_Chase_in_Dishonored_2.pdf>
- Isla, D. "Third Eye Crime: Building a Stealth Game Around Occupancy
  Maps." AIIDE 2013, demo paper.
  <https://ojs.aaai.org/index.php/AIIDE/article/view/12663>
- Leonard, T. "Building an AI Sensory System: Examining the Design of
  Thief: The Dark Project." GDC 2003; the reprint.
  <https://www.gamedeveloper.com/programming/building-an-ai-sensory-system-examining-the-design-of-i-thief-the-dark-project-i->
- McIntosh, T. "Human Enemy AI in The Last of Us." Game AI Pro 2, 2015,
  ch. 34.
  <https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter34_Human_Enemy_AI_in_The_Last_of_Us.pdf>
- Miles, B. "How to Catch a Ninja: NPC Awareness in a 2D Stealth
  Platformer." Game AI Pro, 2013, ch. 32.
  <https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter32_How_to_Catch_a_Ninja_NPC_Awareness_in_a_2D_Stealth_Platformer.pdf>
- Rabin, S. "Vision Zones and Object Identification Certainty." Game AI Pro
  2, 2015, ch. 4.
  <https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter04_Vision_Zones_and_Object_Identification_Certainty.pdf>
- Ubisoft. "Assassin's Creed Shadows -- Stealth Gameplay Overview." The
  publisher's own page, 21 November 2024.
  <https://www.ubisoft.com/en-sg/game/assassins-creed/news/1lmnk4XTnnqRh1foViGYPR/assassins-creed-shadows-stealth-gameplay-overview>
- Walsh, M. "Modeling Perception and Awareness in Tom Clancy's Splinter
  Cell Blacklist." Game AI Pro 2, 2015, ch. 28.
  <https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter28_Modeling_Perception_and_Awareness_in_Tom_Clancy's_Splinter_Cell_Blacklist.pdf>
- Welsh, R. "Crytek's Target Tracks Perception System." Game AI Pro, 2013,
  ch. 31.
  <https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter31_Crytek's_Target_Tracks_Perception_System.pdf>
- Welsh, R. "Looking for Trouble: Making NPCs Search Realistically." Game AI
  Pro 2, 2015, ch. 27; the game it describes is not named.
  <https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter27_Looking_for_Trouble_Making_NPCs_Search_Realistically.pdf>

About games and talks, not by their developers:

- Alexander, L. "GDC: How Kojima Defied The 'Impossible' Throughout Metal
  Gear's History." Game Developer, 26 March 2009; an article on Hideo
  Kojima's GDC talk.
  <https://www.gamedeveloper.com/game-platforms/gdc-how-kojima-defied-the-impossible-throughout-i-metal-gear-i-s-history>
- Costiuc, S. "Why Assassin's Creed series isn't social stealth, and what to
  do about that?" Game Developer, 29 August 2016; a featured blog post.
  <https://www.gamedeveloper.com/design/why-assassin-s-creed-series-isn-t-social-stealth-and-what-to-do-about-that->
- Martin, J. "Splinter Cell: Conviction hands-on preview." bit-tech, 3
  October 2009.
  <https://bit-tech.net/previews/gaming/splinter-cell-conviction-hands-on-preview/2/>
- Reparaz, M. "How Assassin's Creed Mirage Grew from DLC to Full Game."
  Ubisoft News, 22 March 2024; an article on Boudon and Salomon's GDC talk.
  <https://news.ubisoft.com/en-gb/article/7eOzoQpAyuvsN3U0kqJiyR/how-assassins-creed-mirage-grew-from-dlc-to-full-game>
- Thompson, T. "The AI of Hitman (2016)." Game Developer, 7 August 2019; an
  article on IO Interactive's talks.
  <https://www.gamedeveloper.com/design/the-ai-of-hitman-2016->
- White, L. "Splinter Cell designer says one of the difficulties with modern
  stealth games is realistic lighting." FRVR, 20 May 2026; an interview
  with Clint Hocking.
  <https://frvr.com/blog/news/splinter-cell-designer-says-one-of-the-difficulties-with-modern-stealth-games-is-realistic-lighting/>
- "Metal Gear Solid (1998 video game)." Wikipedia; the gameplay section.
  <https://en.wikipedia.org/wiki/Metal_Gear_Solid_(1998_video_game)>
- "Metal Gear Solid 2: Sons of Liberty." Wikipedia; the gameplay section.
  <https://en.wikipedia.org/wiki/Metal_Gear_Solid_2:_Sons_of_Liberty>

Research:

- Al Enezi, W., Verbrugge, C. "Investigating the Influence of Behaviors and
  Dialogs on Player Enjoyment in Stealth Games." AIIDE 2023, poster;
  abstract only. <https://ojs.aaai.org/index.php/AIIDE/article/view/27512>
- Xu, K., Verbrugge, C. "Generic Guard AI in Stealth Game with Composite
  Potential Fields." arXiv:2508.18527, 2025; the arXiv page names no
  venue. <https://arxiv.org/abs/2508.18527>
- Russell, S., Norvig, P. "Artificial Intelligence: A Modern Approach", 4th
  ed., ch. 14, section 14.5.3 "Approximate inference in DBNs" (the contents
  page, opened 2026-10-26). <https://aima.cs.berkeley.edu/contents.html>
- Thrun, S. "Particle Filters in Robotics." UAI 2002; the abstract, opened
  2026-10-26. <https://arxiv.org/abs/1301.0607>
