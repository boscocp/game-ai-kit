# How action-game enemies take turns: tokens, rings and telegraphs

<!-- doc-meta
half_life: concept
verified_on: 2026-11-10
tier: 1
source: https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter28_Beyond_the_Kung-Fu_Circle_A_Flexible_System_for_Managing_NPC_Attacks.pdf
invalidated_if: T154's AttackTokens stops doing what "What the kit takes" says, or T155-T158 take something else from here
teaches: action-combat-ai
-->

> A group of enemies surrounds the player in an action game, and only one
> or two of them strike at once. This page reads how shipped games do it in
> the order Dawe's *Game AI Pro* chapter does -- the kung-fu circle, a
> capacity and weights, two rings, the behaviours that use them, difficulty,
> and what goes wrong in motion -- and then adds the telegraph, the warning
> before a blow. It ends with what T154 to T158 take. Every reference was
> opened before it was cited, and each is cited for no more than what was
> read; what could not be checked is listed at the end and not used.

## The short version {#short}

- **One at a time is the kung-fu circle**, named after the films where the
  hero faces dozens who attack one by one. It is simple, and too strict for
  quick combat [Dawe 2013].
- **A capacity and weights loosen it.** Kingdoms of Amalur gave the player
  a *grid capacity*, which limits how many creatures may close in, and an
  *attack capacity*, which limits how many attacks and which; each creature
  and each attack has a weight that must fit [Dawe 2013]. DOOM (2016) keeps
  a number of tokens per attack type; a demon requests one to attack and
  releases it after [Thompson 2018]. This kit calls it a pool of **attack
  tokens**.
- **Two rings make it readable**: those allowed to approach wait in an outer
  ring, only the one attacking steps into the inner, and the rest stand
  outside both [Dawe 2013].
- **Difficulty is the pool's size**, not each enemy's numbers [Dawe 2013;
  Thompson 2018].
- **A telegraph is the warning before a blow**, and the enemy's side of it
  is reading the player's: a Souls-like plugin makes enemies "read the
  telegraph on your attack" and parry, dodge or counter [Erunsal].

## The problem {#problem}

"Inexperienced players may become overwhelmed by the sheer number of
enemies attacking simultaneously, and so these games typically restrict
opponents to attacking one at a time" [Dawe 2013, 28.1]. Kingdoms of
Amalur wanted a large number of enemies on the player at once, inside an
RPG, so it needed a rule that changes how many attack, and with what, from
the attackers themselves and the difficulty the player chose.

## The kung-fu circle {#kung-fu-circle}

Requiring that opponents attack one at a time is "a simple algorithm to
write and employ", and it makes sense where focusing on one opponent is
what the game wants. For fast combat, and to give the player's area attacks
something to hit, it is too strict; and "simply allow two or three enemies
to attack simultaneously" does not account for different enemy types or
the strength of their attacks [Dawe 2013, 28.2].

## A capacity and weights {#capacity}

The chapter's "Belgian AI" -- named for the waffle-like sketches of a grid
-- gives every character a grid of eight slots round it, and two numbers:

- **grid capacity**, against each creature's **grid weight**: a soldier
  weighs 4, a troll 8, and a player of capacity 12 takes one of each before
  a second soldier must wait outside;
- **attack capacity**, against each attack's **attack weight**: with 10, the
  troll's charge (6) leaves 4, and the soldier must pick his sword swing (3)
  over his lunge (5).

A central *stage manager* takes the requests and assigns the slots, so no
creature reasons about space itself [Dawe 2013, 28.3]. The text says the
weights must total "less than" the capacity, but its own example fills the
grid exactly, 12 - 4 - 8 = 0: the rule the example follows is "no more
than", and it is the one this kit takes.

DOOM's version is per attack type: a limited number of tokens for each, a
request before the attack and a release after it [Thompson 2018]. Ocio
Barriales' tokens decide something else -- whose shots may *hit* -- and are
on [the shooter page](shooter-ai.md).

## Two rings {#rings}

The grid's slots are better thought of as points on a circle round the
player. Reckoning split it into an outer *approach* circle and an inner
*attack* circle, whose radius is the melee attacks' range. A creature
granted a slot moves into the approach circle; granted an attack, into the
attack circle; and one with neither stands outside both. "This helps the
player to determine which creatures are immediate melee threats" [Dawe
2013, 28.3.1].

## The behaviours that use it {#behaviours}

Three shared behaviours made the grid work [Dawe 2013, 28.4]:

- a creature inside the outer circle without permission leaves it as fast
  as it can -- so the player sees who attacks, and attackers do not block
  each other;
- a waiting creature is given a free slot to stand in front of, which made
  "natural flanking behavior without any creature explicitly needing to
  know about any other creature in combat";
- a creature gives its slot back "immediately after launching an attack",
  so the requests queue and the attackers rotate, and no one monopolises
  the player.

## Difficulty {#difficulty}

Raising the difficulty raised the player's two capacities, "all without
changing the carefully balanced individual grid and attack weight set for
each creature": more creatures round the player, more of them attacking at
once, with stronger attacks [Dawe 2013, 28.5]. DOOM sets "a different set
of token counts for each attack type" per difficulty [Thompson 2018].

## What goes wrong in motion {#in-motion}

- **The slots move with the player**, so an assigned slot stops being the
  nearest when the player rolls away. The stage manager reassigns every
  frame, may "steal" a slot from one creature for a better-placed one, and
  a creature launching an attack *locks* its assignment so it cannot lose
  it mid-swing [Dawe 2013, 28.6.1]. DOOM's demons steal tokens too, so the
  ones in front of the player attack rather than stand there [Thompson
  2018].
- **A capacity does not stop sameness**: many creatures may still launch
  the same attack at once. Reckoning added cooldowns, per creature and
  global, so the hardest setting did not fill with area attacks [Dawe 2013,
  28.6.2].

## Telegraphs {#telegraphs}

A blow the player cannot see coming is not a fair one. DOOM's designers
found it "unfair if the demons are attacking when the player cannot
respond" [Thompson 2018]. The telegraph is the visible wind-up that lets
the player respond. A Souls-like enemy plugin, Soulslike Enemy Combat,
lists both sides of it: enemies that "strafe, circle and hold the range
their moveset wants", that "read the telegraph on your attack and answer
with a parry, a dodge or a counter", a cap on "how many attack at once
with attack tokens", and a boss's "second moveset at a health threshold"
[Erunsal]. That is a product's feature list, not a design account,
and is cited for no more than that.

## When not to use it {#when-not}

- **A fight with one enemy.** There is no one to take turns with; a token
  pool of one is a timer with extra steps.
- **A stealth game.** The enemies should not be attacking at all while the
  player is hidden; what decides there is awareness
  ([stealth-ai.md](stealth-ai.md)), not a queue for the player's attention.
- **A shooter where hits, not attacks, are the problem.** Many may fire and
  only some hit: that is Ocio Barriales' accuracy tokens
  ([shooter-ai.md](shooter-ai.md)).

## What the kit takes {#kit}

- **T154, `AttackTokens` in `ai_teamwork`** -- the attack capacity and
  weights, per kind as DOOM keeps them: a pool per target and kind, a cost
  per request, and "no more than" the pool held at once. A cost above the
  whole pool is refused at once. What it adds, each a decision of the
  task: a serving order written down (the passed over first, then
  priority, waiting, distance, a seeded hash), no light attack overtaking a
  heavy one that does not fit yet, a timeout for a holder that forgot,
  revoking a whole kind in one call, and a timer between grants with a
  factor for the player's state. What it leaves: stealing, which Dawe and
  DOOM both use -- a holder keeps its token until it gives it back, which
  is Dawe's lock held for the whole attack; and cooldowns per attack.
- **T155, rings**: the approach and attack circles and the free slot a
  waiter stands at.
- **T156, telegraphs**: the warning before a blow, and an enemy that reads
  the player's.
- **T157, the boss fight** (`godot/game3d/bossfight/`): a boss and minions,
  melee and ranged, where the tokens can be watched.
- **T158, difficulty**: the table of pool sizes and delays T154 takes as
  input.

## Could not be checked {#unchecked}

- Noonchester, "Marvel's Spider-Man AI Postmortem", GDC 2019: only the
  session's page was read; it does not mention tokens, melee or ranged. The
  talk's account of token "jobs", and of the ranged attackers waiting
  longer under melee pressure, was seen only in an unofficial summary and
  is not used. T154's `revoke_kind` and its "busy" multiplier are the
  task's own design, not a claim about that game.
- Campbell, "Bringing Hell to Life", GDC 2017, and Loudy and Campbell on
  DOOM's push-forward combat, GDC 2018: seen only in search results.

## References {#references}

- Dawe, M. "Beyond the Kung-Fu Circle: A Flexible System for Managing NPC
  Attacks." In S. Rabin (ed.), *Game AI Pro*, ch. 28, CRC Press, 2013.
  https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter28_Beyond_the_Kung-Fu_Circle_A_Flexible_System_for_Managing_NPC_Attacks.pdf
  -- read in full, 2026-11-10.
- Thompson, T. "Cyber Demons: The AI of DOOM (2016)." Game Developer, 2018
  (the year as T154's sources give it; not re-read).
  https://www.gamedeveloper.com/design/cyber-demons-the-ai-of-doom-2016-
  -- read, 2026-11-10.
- Erunsal, H. "Soulslike Enemy Combat" 3.2, the author's post on the Unreal
  Engine forums. https://forums.unrealengine.com/t/hakan-erunsal-soulslike-enemy-combat/2686654
  -- read, 2026-11-10; a feature list, its date not shown.
- Noonchester, A. "'Marvel's Spider-Man' AI Postmortem." GDC 2019.
  https://gdcvault.com/play/1025828 -- the session page only.
