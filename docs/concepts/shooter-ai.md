# How shooter AI is made: one bot, bots that cooperate, and bots that search

<!-- doc-meta
half_life: concept
verified_on: 2026-10-22
tier: 1
source: https://www.gameaipro.com/
invalidated_if: T51, T52, T66, T67 or T68 stop doing what the sections on what the kit takes say they take from here
teaches: shooter-ai
-->

> Before writing a bot for a shooter -- first or third person -- read how
> others have. This page surveys it from two sides, research and shipped
> games, in three parts: what one bot decides, how bots cooperate, and how
> the same bots behave when the player can hide from them. It ends with what
> T51 (a match played by bots alone) and T52 (bots against the player, with
> optional stealth) take from each. Every reference was opened before it was
> cited. Where only an abstract, a record, slides or an article *about* the
> work could be read, the reference says so and is cited for no more than
> that. What could not be opened is listed at the end and not used.

## The short version

- **Shipped shooters build one bot from three layers**: something that
  picks the current activity by priority (a state machine in Quake III
  [van Waveren 2001] and The Last of Us [McIntosh 2015], a behaviour tree
  in Halo 2 [Isla 2005], a planner in F.E.A.R. [Orkin 2006] and Killzone
  [Straatman et al. 2013]); a **score over candidate positions** that
  chooses where to stand; and a perception and aim model with deliberate,
  named limits. The position score is in every shipped source on where
  a bot stands in a fight.
- **Bots cooperate in four ways**, cheapest first: emerging from good
  individuals reading the same world (much of F.E.A.R.'s "flanking" is a
  soldier moving to the only cover he knows [Orkin 2006]); an **arbiter**
  that hands out roles and claims (The Last of Us makes sure at least one
  enemy is shooting and picks a single flanker [McIntosh 2015]); an explicit squad
  [Karlsson 2021]; and a **commander** above the squads [Straatman et al.
  2013; Isla, Halo 3 slides]. In every shipped case an order is a
  suggestion the bot may refuse to stay alive.
- **The stealth version adds four things to the same bots**: an awareness
  that *accumulates* rather than a yes-or-no sight test; a remembered last
  known position, shared; a search after the target is lost, often over a
  belief map that spreads while nobody looks and is wiped where a guard can
  see [Isla 2013; McIntosh 2015]; and readable feedback, because "it's what
  the player thinks the NPC can see and hear" [Walsh 2015].
- **Research optimises a number; studios optimise the fight a player
  reads.** Learned agents reached human level in Quake III's capture the
  flag, partly by reacting in 258 ms against a person's 559 [Jaderberg et
  al. 2018]; learned Doom bots aimed well and planned poorly [Wydmuch et
  al. 2018]. No shipped source read here uses a learned policy. Days Gone
  wants "good-looking combat" rather than "the most effective behavior"
  [Karlsson 2021].
- **Honest difficulty has named knobs**: reaction time, turn rate, aim
  error that grows with distance and speed, field of view, time to notice
  [van Waveren 2001; Rabin, reaction time 2015]. The pacing tools that
  shipped games add -- tokens for who may attack and whose shots may hit
  [Ocio Barriales 2017] -- decide which shots land, and say so.

## One bot

### The academic side

**Quake III Arena's bot** is a master's thesis that shipped
[van Waveren 2001]. Its decisions are "very much like a finite state
machine modeled as a network of nodes with conditional links" -- seek a
goal, fight, chase, retreat -- with fuzzy logic for weapon and item
preference and an area-based map for routes. Two of its sentences are the
thesis of this whole page: human limits "will have to be explicitly
implemented in the bot AI to make the bot appear more human-like", and "a
perfect bot would not be any fun to play with". Its difficulty is a set of
named parameters per character: reaction time in seconds, how fast the view
may turn, aim accuracy and aim skill per weapon. Skill bands switch on
behaviours: leading a moving target linearly, then exactly, then aiming
splash damage at the floor.

**A bot that predicts** [Laird, "It knows what you're going to do"; the
venue is not printed on the paper read]: the Soar Quakebot "uses its own
knowledge of what it would do in the enemy's state to predict the enemy's
actions", from little more than the enemy's position, health, armour and
weapon, and uses the prediction to hunt, ambush and take the power-ups
first. It predicts only when it sees the enemy far away and facing elsewhere,
and gives up when several choices are equally good.

**Human-likeness as the goal.** The BotPrize ran a Turing test for bots in
Unreal Tournament 2004 [Hingston 2009 -- abstract and record only]. Its
entries were not learned end to end. UT^2 evolved its combat for damage
dealt and taken, then filtered it so it stayed human-like, and made its aim
worse "with respect to how much it and its target are moving, as well as
the distance" [Schrum et al. 2011]. Being stuck was its top priority, being
"a very bot-like behavior". MirrorBot won in 2012 with 52.2% humanness by
copying an observed player's movement and aim [Polceanu 2013], and notes
that "glitches in navigation ... can quickly destroy the illusion".

**Learning from pixels.** ViZDoom is a Doom-based platform where bots learn
from the screen [Kempka et al. 2016 -- abstract only]. Its competitions'
report is frank [Wydmuch et al. 2018]: the bots "were decent at tactical
decisions (aiming and shooting) but poor on a strategic level", "no agent
has been capable of vertical aiming", none dodged a missile, and none
chased an enemy out of view. One entry that hard-coded crouching had an
exceptional kill-to-death ratio.

**Learning a team game.** DeepMind's agents for Quake III capture the flag
[Jaderberg et al. 2018, the arXiv version] reached strong human level.
Part of the gap was not strategy: they responded to a new opponent in 258
ms against humans' 559, and hit 80% of tags against 48%. With accuracy
lowered to a human's they still won more than humans; with reaction up to
375 ms, no change.

**A teaching precedent.** Pogamut put Unreal Tournament bots in front of
students: a decision module, a path planner and obstacle avoidance, where
"two of the most widespread techniques ... are finite state machines (FSM)
and reactive rules" [Kadlec et al. -- the venue is not printed].

### The shipped side

**Where to stand is the decision.** "Picking a good position is half the
battle in 'fire & maneuver' combat" [Beij & Straatman 2005, slides]. Killzone
scores waypoints by a weighted sum -- the slides' worked example: proximity
20, line of fire to the main threat 40 if partial cover and 20 otherwise,
cover from other
threats 20, preferred range 10 -- and adds to the path's A\* costs for
crossing a friend's line of fire. CryEngine's tactical position system
writes it as a query: generate candidates, drop those failing conditions,
weigh the rest, take the best, with fallbacks [Jack 2013]. Its test of a
good result is the one a person watching asks: "Why did he move here, when
it's just common sense that he should move there instead?" -- and its
answer is drawing every candidate in the world, coloured by status, with its
score above it. Halo asked the same question in the same words before
("This is my goal. Where should I be standing?") and answered it with firing
points [Butcher & Griesemer, slides, year not printed]. The Last of Us takes
about 20 cover spots near each enemy, casts 4 rays at each, and rejects a
cover whose path runs towards the player [McIntosh 2015].

**What picks the activity.** Halo 2's tree of about fifty behaviours
chooses a child by relevance, lets a higher-priority sibling interrupt on a
later tick, and keeps memory outside the tree [Isla 2005 -- read through an
extraction of the article, so paraphrased here, not quoted]. F.E.A.R. has
"only three states" -- go to, animate, use an object -- and plans the
sequence between them with A\* over STRIPS-like actions, so soldiers and
rats share goals and differ in action sets [Orkin 2006]. Killzone 2's
multiplayer bots replan with a hierarchical task network at 5 Hz and keep
the current branch unless a higher one wins, to "prevent twitchy behavior"
[Straatman et al. 2009, partial text of image slides]. Whatever the form,
the requirement is the same: priorities, and an interruption when the
world changes [Jakatdar 2017].

**The bot is no better informed than the player.** Halo's knowledge model:
"'Real' Perception -- No cheating", and the enemy "can be fooled" [Butcher
& Griesemer]. Killzone 3's bots act through a virtual controller that
"ensures that the bots' capabilities are identical to those of the player",
and with view cones and range "the bot's idea of the world may be believably
wrong" [Straatman et al. 2013]. Crytek's reason: once players realise the AI
cheats, "they naturally tend to feel cheated" [Welsh, Target Tracks 2013].

**And a tougher enemy reads as a smarter one.** Halo's playtests: with weak
enemies 20% of players rated them "Not Intelligent"; with tough ones nobody
did, and 43% rated them "Very Intelligent" [Butcher & Griesemer].

## Bots that cooperate

### The shipped side

**Emergence, finished by dialogue.** F.E.A.R. re-clusters soldiers into
squads by proximity and runs at most one squad behaviour each -- get to
cover, advance, orderly advance, search -- by filling slots, sending orders
and watching progress [Orkin 2006]. An order is a goal the soldier ranks
against his own: "fleeing from danger may trump following an order to
advance". And: "It appears that the A.I. is flanking, but in fact this is
just a side effect" of moving to valid cover. What sells it is two-line
dialogue -- "Vocalizing intentions can sometimes even be enough, without any
actual implementation" [Orkin 2006; Orkin, Combat Dialogue 2015]. Orkin's
lesson is architectural: "the separation between planning for individuals
and planning for squads".

**An arbiter.** The Last of Us's Combat Coordinator is "simply a global
object that managed each NPC's role": flanker, approacher, investigator,
the one who stays up and aims, the opportunistic shooter, each requested and
acknowledged [McIntosh 2015]. An enemy that can shoot the player does, but
"it was only necessary for one NPC to be shooting the player at any given
time", so the opportunistic-shooter role exists to make sure there is at
least one, and the others are free to take cover and flank. Every enemy
computes a flank route; the coordinator picks the best one and rejects the
others' requests. A cap on how many may shoot is a different tool -- tokens
[Ocio Barriales 2017] -- and that chapter itself calls a hard cap of one
"potentially unbelievable". CryEngine's version of the arbiter is a claim: Far Cry and Crysis
were "never picking a hidespot that another agent had already claimed", and
a penalty for distance from the squad's centre gives "a loose leapfrogging
behavior" with no leapfrog code [Jack 2013].

**A squad of its own.** In Days Gone, "squads are themselves full AI
entities whose primary purpose is coordination" [Karlsson 2021]. A squad's
**confidence** -- friendly strength over enemy strength, plus kills, minus
losses -- picks attack, hold or retreat, and a panicked member's strength
counts for the enemy, so panic spreads. A **frontline** runs from one side's
centre to the other's, with a neutral strip between and one lane per
member, so they do not bunch or block each other's fire. They "retreat in
waves, with half of them moving back to a new cover, while the other half
provides cover fire"; flankers "always leave an opening at the rear". The
point is legibility, not efficiency.

**A commander.** Killzone 3's multiplayer bots have three layers per team --
commander, squad, individual -- with "orders moving downward and
information moving up" [Straatman et al. 2013; the design began as
Verweij's 2007 thesis, abstract and conclusion read]. The commander weighs
objectives (advance, defend, attack, escort), each with an ideal number of
bots, and assigns squads to them. Squads path over a coarse graph of areas
with an influence map of friends, enemies and recent deaths, and pay "a
penalty ... to areas chosen by any friendly squad", which spreads
simultaneous attacks. The squad's path is a corridor inside which each bot
still picks its own position. Halo 3 writes the commander as a designer's
tree of tasks with priorities and capacities: "Pour squads in at the top /
Allow them to filter down", assigned greedily by a cost [Isla, Halo 3
objectives slides, venue not printed]. Its warning: "AI can look really
stupid with wrong H(f)". Paragon, a MOBA, adds the simplest argument for any
of it: "The simplest form of cooperation is 'going together'" [Zieliński
2017].

**A shared map instead of messages.** An influence map computed once and
read by every agent lets them keep spacing, avoid piling on one target, and
ask "where is this not" [Mark 2015]. Killzone's suppression fire is the same
scoring run from the enemy's side: score where the hidden enemy would attack
from, and fire at those places [Beij & Straatman 2005].

**And a director, which coordinates the encounter, not the bots.** Left 4
Dead estimates each survivor's "emotional intensity" and, when it is too
high, removes major threats for a while; it builds up, holds a peak of
3-5 s, then relaxes for 30-45 s [Booth, slides, venue not printed]. Its
allied bots cheat to keep trust -- no friendly fire -- and teleport back to
the team when nobody is looking.

### The academic side

Learned teams cooperate without a channel. DeepMind's capture-the-flag
agents "act and learn independently, resulting in decentralised control",
and still learned to defend the base, camp the enemy's and follow a
teammate -- one behaviour found and dropped mid-training [Jaderberg et al.
2018], after some 450,000 games. OpenAI's hide-and-seek teams, trained with
a team reward, built forts and divided labour [Baker et al. 2020]; fort
building took about 25 million episodes. RETALIATE learned only the team's
layer over scripted bots in Unreal Tournament's domination -- 27 states,
the owner of each of three points -- with online Q-learning [Smith et al.
2007]. Plan-space planning for many units [van der Sterren 2013] works at
wargame scale, which is more than a shooter needs.

## The stealth version of the same bots

### What a guard notices

**No shipped source keeps a plain cone.** Thief uses several cones, each
with its own sensitivity, and one behind the guard tuned to motion
[Leonard 2003]; Crysis a primary and a peripheral field [Welsh, Target
Tracks 2013]; Splinter Cell: Blacklist "coffin-shaped boxes" that widen and
then narrow [Walsh 2015]; The Last of Us an angle "inversely proportional
to distance" [McIntosh 2015]. Rabin's zones give each region a certainty
from 0 to 1 instead of a dice roll, because a hard edge -- 10 m seen,
10.001 m not -- "becomes part of the gameplay" [Rabin, vision zones 2015].

**Awareness accumulates.** The Last of Us raises a timer every frame the
player is seen and lowers it every frame they are not; about 1-2 s to
perceive, less once in combat [McIntosh 2015]. Blacklist starts a detection
timer scaled by distance, light and the guard's state, and shows it, which
gives the player a window to break line of sight [Walsh 2015]. Crysis uses
attack-decay-sustain-release envelopes per stimulus, with thresholds at a
quarter of the peak (interesting), five-eighths (threatening) and the peak
(aggressive) [Welsh, Target Tracks 2013]. Thief's awareness rises through a
filter with a reaction delay, and falls "across some amount of time,
passing through all the intermediate states" [Leonard 2003].

**Light, sound and the body.** Thief weighs light, movement and exposure,
and weights the player's light to the floor under them -- "an objective,
perceivable way to anticipate their own safety" [Leonard 2003]. In 3D,
seeing a body is rays to points on it: eight bones in Blacklist, more needed
when the player is in cover [Walsh 2015]. The Last of Us went the other way,
to one point -- the chest in stealth -- because players could not anticipate
the many-ray version [McIntosh 2015]. Sound is measured along the level,
not through walls: a graph of rooms and doorways [Walsh 2015], A\* over a
"sound mesh" [Miles 2013], propagation through the geometry [Leonard 2003].
The kit's own `ai_perception` hears in a straight line and says so in its
header.

**Typed events.** Mark of the Ninja has about sixty kinds of "interest
source" -- gunshot, footstep, body, suspect -- each with a sense, a
priority, a radius and a lifetime; equal priority, newest wins [Miles 2013].
Blacklist adds a changed world: a door left open or a light switched off is
an event, and the first guard to see it claims it [Walsh 2015].

### What a guard does about it

**Alert levels are few.** Usually three -- unaware, suspicious, alert --
drawn so that "if a guard's behavior ever changes, the player will
immediately understand what set it off" [Kumar 2012, reporting Mark of the
Ninja's lead designer]. Metal Gear Solid adds an evasion phase between alert
and normal [Wikipedia, an overview, not a developer source].

**The last known position.** A guard keeps "knowing" where the target is for
2-3 s after losing sight, which works better than extrapolating its
velocity into a wall [Welsh, Looking for Trouble 2015]. Splinter Cell:
Conviction showed it to the player as a ghost silhouette [Martin 2009, a
press preview].

**The search.** Welsh's is in two phases: go to the last known position --
in a cautious search, one guard only, which lets the player "peel targets
away from a group"; in an aggressive one at most two or three, the rest
covering -- then a **search coordinator** hands out spots hidden from that
position, marks each "in progress", and every searcher marks searched the
spots it can see on the way [Welsh, Looking for Trouble 2015]. Guards then
"filter back" to their routines one at a time, not as "one hive mind".

**Belief as a map.** Third Eye Crime treats the target's position as a
distribution over the floor that diffuses while unobserved and is zeroed
wherever a guard can see -- and draws it, "rendered at all times", as a red
heat map [Isla 2013, a one-page demo paper]. The Last of Us's search map
does the same: cells "bleed into their neighbors over time", and cells any
enemy can see are cleared each frame [McIntosh 2015]. Dishonored 2 floods
heat from the last known cell with a barrier behind the player's last
direction, and chases the heat-weighted centre; its step limit was its
difficulty setting [Couvidou 2021]. The first Dishonored had used
breadcrumbs, which made guards near-omniscient and "can feel unfair"; the
flood replaced a dead-reckoning prototype that hit walls and gave up too
early.

### How guards search together

- **One belief, shared.** The enemy who perceives the player writes a
  position and a time, and tells the others; if nobody perceives the player,
  nobody's position is updated [McIntosh 2015]. Thief passes "sense links"
  between peers, "with controls in place to constrain knowledge cascades"
  [Leonard 2003].
- **Roles, not a group.** In Mark of the Ninja, detection is run from the
  stimulus, so the guards who noticed it are the group: one leader who
  barks an order, one or more who investigate, the rest bystanders -- and
  after that, "there is no 'group' to manage" [Miles 2013]. The Last of Us
  has one Investigator role [McIntosh 2015].
- **The area divided.** Welsh's coordinator's claimed spots; the shared
  belief map cleared by every guard's view.
- **Alarms.** A body, or a comrade who has gone quiet: in Blacklist, if
  guard A was within earshot of B for 10 s and B has been silent for 5, A
  investigates [Walsh 2015].

### The academic side

Research on stealth is mostly about levels, on 2D grids. McGill's tools
search space-time for a path no guard sees [Tremblay et al. 2013], extend it
to combat [Tremblay et al. 2014], and to distractions that branch the guards'
paths [Borodovski & Verbrugge 2016] -- design-time analysis, not guard AI.
Two papers are guard AI. Al Enezi & Verbrugge give each region a
"staleness" that grows until a guard sees it, and patrol to reduce it
[2020, a poster]. Xu & Verbrugge combine three fields -- information since
the last sighting, coverage that decays, and the level's connectivity --
and move each guard downhill, with no state machine; in their grid
environment their guards capture in 80% of trials against 56% for
staleness and 12% for a plain state machine [2025]. Both leave explicit coordination between guards as future
work: the guards coordinate only through the shared field.

### Fair, and readable

Every shipped stealth source says the same thing in its own way: the player
must be able to tell why they were seen. Blacklist halves, for certain
events, the hearing of guards off screen and far away, because "it's what the player thinks the
NPC can see and hear", and keeps reaction timings consistent while varying
the lines [Walsh 2015]. Mark of the Ninja draws the cones and the sound
rings [Kumar 2012]. F.E.A.R.: "If the AI didn't say it, it didn't happen"
[Orkin, Combat Dialogue 2015]. Alien: Isolation's director gives the
creature only a general area -- "the alien has to figure it out for
itself" [Thompson 2017, an article on the developers' talk].

## Difficulty, and how a bot cheats

**Reaction.** "Somewhere between 0.2 and 0.4 seconds, possibly longer
depending on context" -- simple reaction 0.19-0.22 s, friend-or-foe 0.38 s,
more for a far target and for aiming after noticing [Rabin, reaction time
2015]. The learned capture-the-flag agents, at 258 ms, were slower than a
laboratory's simple reaction, faster than its friend-or-foe one, and far
faster than the humans in the same matches, at 559 ms [Jaderberg et al.
2018].

**Aim.** Error that grows with distance and with how fast both move [Schrum
et al. 2011]; per-weapon accuracy and skill [van Waveren 2001].

**Who may shoot, and whose shots hit.** Tokens: "shots can only actually
hit the player if the shooter has a token; any other shot will deliberately
miss" [Ocio Barriales 2017]. One timer sets when the next token is given --
a base delay times multipliers for distance, the player crouching or in
cover, facing away, running at the enemy -- and the misses are placed where
the player sees them: over half cover, past the face. This is not a weaker
bot; it is a rule about the player's damage, and the page that teaches it
should call it that.

**Admitted cheats.** Killzone 2's bots had ammunition they should not have
("Remove cheat (ammo)", on the future-work slide) [Straatman et al. 2009].
The Last of Us sends an enemy straight at a player more than 5 m from where
it believes them to be -- "Our solution to this problem was to cheat" --
which cut a fight's combat cycle from about two minutes to thirty seconds
[McIntosh 2015].

**And a player can rarely tell.** In a turn-based study, players were "bad
at determining AI's strategies and detecting randomness and cheating", and
accused an honest AI of cheating [Wetzel & Anderson 2017]. That is a reason
for this kit to show the knobs, not to hide them.

## What this kit takes, and what it leaves

The kit already has pieces of this in 2D: `ai_perception` (a cone, line of
sight, hearing, an influence map), fuzzy suspicion and three guard states
(T14), STRIPS planning (T4, T11), and a behaviour addon still to come
(T15). The shooters are where they meet, and ADR 0018 (proposed) is how
they would be 3D without the lesson needing 3D: every decision below is a
function of a snapshot -- positions, sight lines, costs -- with a Python
twin.

**T51, a match played by bots alone** (a team match the player watches, as
in an Unreal Tournament or Killzone bot match, on a capture-and-hold map):

1. **Positions scored on screen, with claims** [Beij & Straatman 2005; Jack
   2013; McIntosh 2015]. Every candidate point drawn and coloured, its score
   above it, a claimed point marked as taken. The toggle: claims off, and
   the bots bunch on the same cover.
2. **A commander assigning squads to objectives by weight and distance,
   over a shared influence map** [Straatman et al. 2013; Mark 2015]. The
   toggle: commander off, and each bot goes to its own nearest objective --
   "going together" against going alone [Zieliński 2017].
3. **Confidence that decides attack, hold or retreat, and retreat in
   waves** [Karlsson 2021], drawn as a bar per squad and the frontline.

**T52, bots against the player, with an optional stealth** (a level in the
manner of Splinter Cell or The Last of Us, third person):

1. **A role arbiter**: always at least one shooter, a single chosen
   flanker, requests granted and refused on screen [McIntosh 2015]. The
   toggle: arbiter off, and every enemy that can shoot does, and nobody
   flanks.
2. **Awareness that accumulates, and three alert levels**, drawn per guard
   as a bar with its thresholds [McIntosh 2015; Walsh 2015; Welsh, Target
   Tracks 2013] -- the kit's fuzzy suspicion, grown from a grid to rays at
   the body and light.
3. **A shared belief map for the search**, diffusing and wiped by every
   guard's view, drawn as a heat map, with a search coordinator handing out
   spots [Isla 2013; McIntosh 2015; Welsh, Looking for Trouble 2015]. The
   toggle: belief map off, and guards walk to the last known position and
   give up.

Difficulty in both is the named knobs -- reaction, turn rate, aim error,
time to notice -- and T52's attack tokens are shown as what they are, a rule
about which shots may land.

**Left:**

- **Learned bots.** Tier 1 cannot train them, and the sources show them
  winning partly on reaction a person does not have; no shipped source uses
  one. Invariant 6 forbids learning at game time in any case. A learned
  commander's *weights*, fitted offline as RETALIATE's layer is small enough
  to be, would be a later task, not a first.
- **GOAP and HTN for the single bot.** F.E.A.R.'s and Killzone's choice, and
  a good one; but the kit's planner is T4/T11's, and T15 is where the four
  ways to decide are compared. T51 used the plainest selector that holds
  (a priority list); T67 replaced it with a utility choice, below.
- **Opponent prediction** [Laird] and **a director** [Booth]: each worth a
  task of its own once the bots exist.
- **Hitman's disguises and crowds**, the **Metal Gear** caution phase after
  MGS1, and **Far Cry's** outposts: no developer source could be opened.

## A map made for the bots: what the level design sources say (T66)

T51's arena was an open floor with boxes on it, and the owner found the
capture points "mt exposta", with no way to flank. T66 rebuilt it as three
lanes, and these are the rules it was built to, each from a page opened
twice -- once in wave 70 to choose the layout, and again in wave 71 to cite
it. Two pages tried in wave 70 could not be opened and are not used.

- **Two or three main paths, a choke point on each, no more than three.**
  "Develop 2 or 3 main paths leading from spawn point to bombsite ...
  Don't do any more then 3", and "if you have 3 main paths, you should have
  3 choke points; one for each main path" [World of Level Design, CS
  layouts]. The same page keeps connecting paths out of the chokes.
- **One choke per lane, and none that covers the rest.** "distribute 3-4
  chokepoints across the map, one chokepoint per lane", and "It should be
  impossible to cover all chokepoints from a single point" [Level Design
  Book, balance].
- **Spawns as far from every point, and no point as a choke.** "PlayerStarts
  should be of an equal distance to DomPoints"; "Entrances to DomPoint areas
  should not be choke points"; "Some obvious cover ... of the DomPoints
  should be present" [Unreal Wiki, Mapping For DDOM].
- **Three to nine seconds from a start to a point, and no point in sight of
  a start.** "a minimum of 3 seconds to reach a control point from a player
  start, and a maximum of 9 seconds"; "avoid placing a start point within
  direct sight of a Control Point" [Unreal Wiki, Placing PlayerStart].
- **Two or three heights.** "A good Domination map should at least have
  two, but preferably three, different height levels", linked by ramps or
  stairs [Unreal Wiki, Z-Axis].
- **Low cover at the waist, high cover over the head.** "Standing waist
  height object, 1.0-1.25 meters" and "Standing head height object, 1.75 or
  more meters", the page citing Naughty Dog's Uncharted 4 [Level Design
  Book, cover].
- **A perch that changes hands.** Halo 5's Plaza sniper nest can be
  approached "from the ramp and bridge side, or from the gravity lift and
  bottom level side", and "Players under heavy fire are forced to abandon
  the spot or die, which allows for the area to change control frequently"
  [Bean, Halo 5 Plaza]. A blogger's analysis, not the studio's; that the
  high ground should be contestable from several sides is this page's
  reading of it.

No source gave a sightline's length in metres, so the lanes' lengths are
the arena's own. What T66 built from these: a lane and one door for each
point, spawn rooms opening into a rear corridor through doors offset from
the lanes, two bridges over B with a stair at each end, low cover of 1.1 m
and pillars of 2.5 m. `botmatch_test.gd` holds two of the rules as
commands: every walk from a spawn to a point takes 4.8 to 6.7 s, the means
per point within one second; and no point sees into a spawn.

## The bot as an agent: percepts, and a weighed choice (T67)

The owner's ask: the bot is AIMA's agent, which perceives the world and
its own state and decides what to do to reach its goal -- a function from
percepts to actions [Russell & Norvig, ch. 2] -- so that on another map,
in another context, it copes. T67 made that literal in three places.

- **One record of percepts.** Each bot's eyes are `ai_perception`'s
  `VisionCone`, asked in the open: its reach and angle, a radius all round
  for a body beside it, and the line answered by the world -- here the
  arena's boxes, exactly and with heights, which the addon's grid line of
  sight cannot be. Its ears are `Hearing`: every shot is a noise, heard
  through walls, louder nearer. What they give, with its body and its
  orders, is `MatchPercepts`, and the decision reads nothing else.
- **A utility choice, not a priority list.** `ActionChoice`: every action
  scored at once, each consideration one percept through a response curve
  into [0, 1], the answers multiplied, so any one at zero vetoes the
  action. It is Guild Wars 2: Heart of Thorns' form, after the Infinite
  Axis Utility System, which is also data-driven: "any consideration can
  disqualify an entire decision from being selected simply by scoring
  zero" [Lewis 2017]. The bot's six actions and their numbers are a data
  file (`actions.json`). A behaviour tree's selector is the priority list
  it replaced, and GOAP, a search for a chain of actions, has no chain to
  find when one action is chosen each decision.
- **The errands a technique.** Going back for rounds and fetching the
  power weapon, each a gain less its costs, moved from the demo into
  `ErrandChoice`.

`ai_steering` was asked for the last metres and does not serve here: its
avoid swerves from round obstacles and, head-on, always to the vehicle's
left -- a fixed side, which on a mirrored map is the fault that bent the
yards' mirror in T66. The measured results are in
[`docs/godot/botmatch.md`](../godot/botmatch.md).

## Health that comes back, and when to break off to heal (T68)

The owner's ask: after ten seconds without taking damage, health comes back
a little at a time, as in the shooters on the market; at the base, where
the rounds are, it comes back whole at once; and the AI weighs whether it
is worth running to recover.

**What shipped shooters do, as opened.**

- **Halo's shields** wait, then fill fast. Halo: Combat Evolved's "begin
  regenerating 5 seconds after last being hit and take four seconds to
  fully recharge from a total drain"; Halo 2's, 4.25 s and 1.75 s; Halo
  3's, 5 s and 2 s [Halopedia, Energy shielding]. The pattern is a delay of
  a few seconds and a refill shorter than the delay.
- **Call of Duty: Modern Warfare (2019)**, as an article reported it:
  "around 6 seconds to start regenerating health", then "another 1.4
  seconds to get back to full health"; the Quickfix perk cuts it while
  getting kills [Upcomer]. The piece is built on a video creator's tests
  (TheXclusiveAce) but does not say whose these two figures are, and does
  not present them as the developer's.
- **Black Ops 4 took it out**: "health regeneration is not automatic
  anymore"; a player presses a button to heal, with a cooldown, so that
  "every decision a player makes is important" [CharlieIntel]. The
  counterexample: healing as a choice the player makes, which is what this
  kit asks the bot to do.
- **What regeneration does to how people fight.** "Regenerating health is
  most commonly associated with the run and hide cover system"; and where
  regeneration "doesn't occur during combat, it doesn't encourage this sort
  of behavior" [Vanden Bossche 2009]. That is why the delay matters: health
  that came back mid-fight would never make leaving the fight worth
  anything; a delay makes breaking line of sight the price of healing.

No developer's own statement of *why* a delay of five seconds, rather than
two or ten, was found open; the numbers above are what the games do, not
the reasons for them.

**What the kit takes.** The owner's delay, 10 s -- longer than every
delay above, so breaking off to heal costs a bot real time off its post,
which is what makes it a decision. A rate of 20 points a second, an empty
bar in 5 s: slower than every refill above (Halo: Combat Evolved's 4 s is
the slowest), because the owner asked for it to come back gradually. Both
are in `rules.json`. Healing at the base is the owner's own rule; none of
the sources has a resupply room.

And the choice to break off is weighed, never a threshold: hiding to wait
out the delay, going home to be healed whole, or staying in the fight are
each a gain less its costs in one unit, in `ErrandChoice`, beside going
back for rounds and fetching the power weapon. Health comes back while a
bot stays too, unless it is hit, so the health either errand gains is
priced by how exposed the bot is where it stands -- the delay's point,
turned round: what breaking off buys is the hit it avoids. What a bot
hides behind is asked of `TacticalPositions` with a condition of its own:
covered from every enemy its team knows of, not only the nearest. The
measured results are in [`docs/godot/botmatch.md`](../godot/botmatch.md).

## Could not be checked

Not used above:

- Isla, "Probabilistic Target Tracking and Search Using Occupancy Maps", AI
  Game Programming Wisdom 3: no copy found. Cited by several pages that were
  read; the idea is cited here only through Isla 2013 and McIntosh 2015.
- Booth, "The Making of the Official Counter-Strike Bot", GDC 2004: only the
  session description opened.
- The Doom (2016) GDC talks: login-walled; only a secondary article was
  found, and it is not cited.
- van der Sterren, "Squad Tactics: Team AI and Emergent Maneuvers": no copy;
  his site's certificate had expired.
- Straatman, van der Sterren & Beij's 2005 proceedings paper: opened, but
  its text could not be extracted; only the slides are used.
- Champandard, Jack & Dunstan, "Believable Tactics for Squad AI", GDC 2011;
  Dyckhoff on Halo 3; Isla's GDC 2009 and 2013 talks; Martel's GDC 2017
  sensory talk (abstract only); Hitman: Absolution's AI talk (an
  announcement only); Andy Bray's Alien: Isolation talk (known only through
  Thompson 2017).
- The *Science* version of Jaderberg et al. (blocked); the arXiv version is
  cited.
- For T68: the Halo fandom wiki's Health page and the Call of Duty
  fandom wiki's Health page (both refused the fetch; their numbers were
  seen only in a search engine's summary, and are not used); the Valve
  Developer Community's "Regenerating Health" page and the GameDev.net
  round table on regenerating health (both refused); the Wireframe
  article on Halo's shields (refused after a redirect).
- Brothers in Arms, Rainbow Six, ArmA, The Division, Ghost Recon,
  Battlefield and Half-Life's squads: no readable primary source looked at.

## References

Level design, for T66's map:

- Bean, A. "Level Design in Halo 5 Multiplayer: Plaza." Game Developer, a
  blogger's analysis.
  <https://gamedeveloper.com/design/level-design-in-halo-5-multiplayer-plaza>
- The Level Design Book. "Balance" and "Cover", Book 1, Combat.
  <https://book.leveldesignbook.com/process/combat/balance>,
  <https://book.leveldesignbook.com/process/combat/cover>
- Unreal Wiki (legacy, archived). "Mapping For DDOM", "Placing
  PlayerStart", "Z-Axis".
  <https://unrealarchive.org/wikis/unreal-wiki/Legacy:Mapping_For_DDOM.html>,
  <https://unrealarchive.org/wikis/unreal-wiki/Legacy:Placing_PlayerStart.html>,
  <https://unrealarchive.org/wikis/unreal-wiki/Legacy:Z-Axis.html>
- World of Level Design. "How to create competitive Counter-Strike gameplay
  map layouts?"
  <https://worldofleveldesign.com/categories/csgo-tutorials/csgo-how-to-design-gameplay-map-layouts.php>

Shipped games -- talks, chapters and papers by their developers:

- Beij, A., Straatman, R. "Killzone's AI: Dynamic Procedural Tactics." GDC
  Europe, 2005. Slides.
  <https://www.guerrilla-games.com/media/News/Files/gdce05_killzone_ai.pdf>
- Booth, M. "The AI Systems of Left 4 Dead." Valve, slides; the venue is not
  printed on them.
  <https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf>
- Butcher, C., Griesemer, J. "The Illusion of Intelligence: The Integration
  of AI and Level Design in Halo." Bungie, slides; year and venue not
  printed. <https://www.jmeiners.com/shamans/papers/ai/the_illusion_of_intelligence.pdf>
- Couvidou, L. "Flooding the Influence Map for Chase in Dishonored 2." Game
  AI Pro Online Edition 2021, ch. 6.
  <https://www.gameaipro.com/GameAIProOnlineEdition2021/GameAIProOnlineEdition2021_Chapter06_Flooding_the_Influence_Map_for_Chase_in_Dishonored_2.pdf>
- Isla, D. "Handling Complexity in the Halo 2 AI." GDC 2005; the
  proceedings article, read through an extraction and paraphrased.
  <https://www.gamedeveloper.com/programming/gdc-2005-proceeding-handling-complexity-in-the-i-halo-2-i-ai>
- Isla, D. "Building a Better Battle: The Halo 3 AI Objectives System."
  Bungie, slides; a course copy, venue not printed.
  <https://web.cs.wpi.edu/~rich/courses/imgd4000-d10/lectures/halo3.pdf>
- Isla, D. "Third Eye Crime: Building a Stealth Game Around Occupancy
  Maps." AIIDE 2013, demo paper.
  <https://ojs.aaai.org/index.php/AIIDE/article/view/12663>
- Jack, M. "Tactical Position Selection: An Architecture and Query
  Language." Game AI Pro, 2013, ch. 26.
  <https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter26_Tactical_Position_Selection.pdf>
- Jakatdar, S. "From Behavior to Animation: A Reactive AI Architecture for
  Networked First-Person Shooter Games." Game AI Pro 3, 2017, ch. 10.
  <https://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter10_A_Reactive_AI_Architecture_for_Networked_First-Person_Shooter_Games.pdf>
- Karlsson, T. "Squad Coordination in Days Gone." Game AI Pro Online
  Edition 2021, ch. 12.
  <https://www.gameaipro.com/GameAIProOnlineEdition2021/GameAIProOnlineEdition2021_Chapter12_Squad_Coordination_in_Days_Gone.pdf>
- Leonard, T. "Building an AI Sensory System: Examining the Design of
  Thief: The Dark Project." GDC 2003; the reprint.
  <https://www.gamedeveloper.com/programming/building-an-ai-sensory-system-examining-the-design-of-i-thief-the-dark-project-i->
- Lewis, M. "Choosing Effective Utility-Based Considerations." Game AI
  Pro 3, 2017, ch. 13.
  <https://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter13_Choosing_Effective_Utility-Based_Considerations.pdf>
- Mark, D. "Modular Tactical Influence Maps." Game AI Pro 2, 2015, ch. 30.
  <https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter30_Modular_Tactical_Influence_Maps.pdf>
- McIntosh, T. "Human Enemy AI in The Last of Us." Game AI Pro 2, 2015,
  ch. 34.
  <https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter34_Human_Enemy_AI_in_The_Last_of_Us.pdf>
- Miles, B. "How to Catch a Ninja: NPC Awareness in a 2D Stealth
  Platformer." Game AI Pro, 2013, ch. 32.
  <https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter32_How_to_Catch_a_Ninja_NPC_Awareness_in_a_2D_Stealth_Platformer.pdf>
- Ocio Barriales, S. "Using Your Combat AI Accuracy to Balance Difficulty."
  Game AI Pro 3, 2017, ch. 33.
  <https://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter33_Using_Your_Combat_AI_Accuracy_to_Balance_Difficulty.pdf>
- Orkin, J. "Three States and a Plan: The A.I. of F.E.A.R." GDC 2006.
  <https://www.gamedevs.org/uploads/three-states-plan-ai-of-fear.pdf>
- Orkin, J. "Combat Dialogue in FEAR: The Illusion of Communication." Game
  AI Pro 2, 2015, ch. 2.
  <https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter02_Combat_Dialogue_in_FEAR_The_Illusion_of_Communication.pdf>
- Rabin, S. "Agent Reaction Time: How Fast Should an AI React?" Game AI Pro
  2, 2015, ch. 5.
  <https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter05_Agent_Reaction_Time_How_Fast_Should_An_AI_React.pdf>
- Rabin, S. "Vision Zones and Object Identification Certainty." Game AI Pro
  2, 2015, ch. 4.
  <https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter04_Vision_Zones_and_Object_Identification_Certainty.pdf>
- Straatman, R., Verweij, T., Champandard, A. "Killzone 2 Multiplayer
  Bots." Paris Game AI Conference, 2009. Slides, mostly images; partial text.
  <https://www.guerrilla-games.com/read/killzone-2-multiplayer-bots>
- Straatman, R., Verweij, T., Champandard, A., Morcus, R., Kleve, H.
  "Hierarchical AI for Multiplayer Bots in Killzone 3." Game AI Pro, 2013,
  ch. 29.
  <https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter29_Hierarchical_AI_for_Multiplayer_Bots_in_Killzone_3.pdf>
- van der Sterren, W. "Hierarchical Plan-Space Planning for Multi-unit
  Combat Maneuvers." Game AI Pro, 2013, ch. 13; introduction and conclusion
  read.
  <https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter13_Hierarchical_Plan-Space_Planning_for_Multi-unit_Combat_Maneuvers.pdf>
- van Waveren, J.M.P. "The Quake III Arena Bot." MSc thesis, TU Delft,
  2001. <https://fabiensanglard.net/fd_proxy/quake3/The-Quake-III-Arena-Bot.pdf>
- Verweij, T. "A Hierarchically-Layered Multiplayer Bot System for a
  First-Person Shooter." MSc thesis, Vrije Universiteit Amsterdam, 2007;
  abstract and conclusion read.
  <https://www.guerrilla-games.com/media/News/Files/VUA07_Verweij_Hierarchically-Layered-MP-Bot_System.pdf>
- Walsh, M. "Modeling Perception and Awareness in Tom Clancy's Splinter
  Cell Blacklist." Game AI Pro 2, 2015, ch. 28.
  <https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter28_Modeling_Perception_and_Awareness_in_Tom_Clancy's_Splinter_Cell_Blacklist.pdf>
- Welsh, R. "Crytek's Target Tracks Perception System." Game AI Pro, 2013,
  ch. 31.
  <https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter31_Crytek's_Target_Tracks_Perception_System.pdf>
- Welsh, R. "Looking for Trouble: Making NPCs Search Realistically." Game AI
  Pro 2, 2015, ch. 27.
  <https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter27_Looking_for_Trouble_Making_NPCs_Search_Realistically.pdf>
- Zieliński, M. "Being Where It Counts: Telling Paragon Bots Where to Go."
  Game AI Pro 3, 2017, ch. 24.
  <https://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter24_Being_Where_It_Counts_Telling_Paragon_Bots_Where_to_Go.pdf>

About games, not by their developers:

- Kumar, M. "Mark of the Ninja's five stealth design rules." Game Developer,
  2012; a report of the lead designer's talk.
  <https://www.gamedeveloper.com/design/-i-mark-of-the-ninja-i-s-five-stealth-design-rules>
- Martin, J. "Splinter Cell: Conviction hands-on preview." bit-tech, 2009.
  <https://bit-tech.net/previews/gaming/splinter-cell-conviction-hands-on-preview/2/>
- Thompson, T. "The Perfect Organism: The AI of Alien: Isolation." Game
  Developer, 2017.
  <https://www.gamedeveloper.com/design/the-perfect-organism-the-ai-of-alien-isolation>
- Wetzel, B., Anderson, K. "What You See Is Not What You Get: Player
  Perception of AI Opponents." Game AI Pro 3, 2017, ch. 4; a turn-based
  study. <https://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter04_Player_Perception_of_AI_Opponents.pdf>
- "Metal Gear Solid (1998 video game)." Wikipedia; the gameplay section.
  <https://en.wikipedia.org/wiki/Metal_Gear_Solid_(1998_video_game)>

Research:

- Al Enezi, W., Verbrugge, C. "Dynamic Guard Patrol in Stealth Games."
  AIIDE 2020, poster.
  <https://ojs.aaai.org/index.php/AIIDE/article/download/7425/7308/10903>
- Baker, B., Kanitscheider, I., Markov, T., Wu, Y., Powell, G., McGrew, B.,
  Mordatch, I. "Emergent Tool Use From Multi-Agent Autocurricula." ICLR
  2020. <https://arxiv.org/abs/1909.07528>
- Borodovski, A., Verbrugge, C. "Analyzing Stealth Games with
  Distractions." AAAI, 2016.
  <https://www.sable.mcgill.ca/~clump/papers/borodovski-16-analyzing.pdf>
- CharlieIntel. "Big changes to health system in Call of Duty: Black Ops
  4." Before the game's release in 2018; the page's own date was not
  read. <https://www.charlieintel.com/call-of-duty/big-changes-to-health-system-in-call-of-duty-black-ops-4-46147/>
- Halopedia. "Energy shielding." Wiki article, read 2026-10-22.
  <https://www.halopedia.org/Energy_shielding>
- Hingston, P. "A Turing Test for Computer Game Bots." IEEE Transactions on
  Computational Intelligence and AI in Games 1(3), 2009; record and abstract
  only. <https://ro.ecu.edu.au/ecuworks/594>
- Jaderberg, M., et al. "Human-level performance in first-person
  multiplayer games with population-based deep reinforcement learning."
  arXiv:1807.01281, 2018. <https://arxiv.org/abs/1807.01281>
- Kadlec, R., Burkert, O., Brom, C. "Creating game bots in a few easy
  steps." Pogamut tutorial paper; venue not printed.
  <https://artemis.ms.mff.cuni.cz/main/papers/MindTrek_Pogamut_tutorial.pdf>
- Kempka, M., Wydmuch, M., Runc, G., Toczek, J., Jaśkowski, W. "ViZDoom: A
  Doom-based AI Research Platform for Visual Reinforcement Learning." IEEE
  CIG 2016; abstract only. <https://arxiv.org/abs/1605.02097>
- Laird, J.E. "It Knows What You're Going To Do: Adding Anticipation to a
  Quakebot." University of Michigan; venue not printed.
  <https://www.cs.ubc.ca/~krasic/cpsc538a/papers/Agents01.pdf>
- Polceanu, M. "MirrorBot: Using Human-inspired Mirroring Behavior To Pass
  A Turing Test." IEEE CIG 2013. <https://hal.science/hal-00864153/document>
- Russell, S., Norvig, P. *Artificial Intelligence: A Modern Approach*, 4th
  edition, 2020, ch. 2, "Intelligent Agents". A book.
- Schrum, J., Karpov, I.V., Miikkulainen, R. "UT^2: Human-like Behavior via
  Neuroevolution of Combat Behavior and Replay of Human Traces." IEEE CIG
  2011. <https://nn.cs.utexas.edu/downloads/papers/schrum.cig11competition.pdf>
- Smith, M., Lee-Urban, S., Muñoz-Avila, H. "RETALIATE: Learning Winning
  Policies in First-Person Shooter Games." AAAI/IAAI 2007.
  <https://faculty.cc.gatech.edu/~surban6/publs/IAAI02SmithM_errata.pdf>
- Tremblay, J., Torres, P.A., Rikovitch, N., Verbrugge, C. "An Exploration
  Tool for Predicting Stealthy Behaviour." AIIDE 2013.
  <https://www.sable.mcgill.ca/~clump/papers/tremblay-13-exploration.pdf>
- Tremblay, J., Torres, P.A., Verbrugge, C. "An Algorithmic Approach to
  Analyzing Combat and Stealth Games." IEEE CIG 2014.
  <https://www.cs.mcgill.ca/~jtremb59/Papers/CIG-2014-JTremblay.pdf>
- Upcomer. "Is the Quickfix perk worth running in Modern Warfare?"
  The page's date was not read; it calls itself over six years old.
  Figures reported, not attributed to the developer. <https://upcomer.com/is-the-quickfix-perk-worth-running-in-modern-warfare/>
- Vanden Bossche, A. "Analysis: Video Games' Regeneration Station." Game
  Developer, 2009-10-22.
  <https://www.gamedeveloper.com/game-platforms/analysis-video-games-regeneration-station>
- Wydmuch, M., Kempka, M., Jaśkowski, W. "ViZDoom Competitions: Playing
  Doom from Pixels." arXiv:1809.03470, 2018.
  <https://arxiv.org/abs/1809.03470>
- Xu, K., Verbrugge, C. "Generic Guard AI in Stealth Game with Composite
  Potential Fields." AIIDE 2025. <https://arxiv.org/abs/2508.18527>
