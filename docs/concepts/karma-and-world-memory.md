# How games remember what the player did: karma and world memory

<!-- doc-meta
half_life: concept
verified_on: 2026-11-11
tier: 1
source: https://en.wikipedia.org/wiki/Ultima_IV:_Quest_of_the_Avatar
invalidated_if: ADR 0025 changes what may persist between sessions, or the valley (T164-T165) stops rebuilding its world and standing from the record of deeds
teaches: karma-and-world-memory
-->

> A game that remembers what the player did has to decide two things:
> what it keeps, and what it reads off what it kept. This page reads how
> nine shipped games answered, and one research system, and then says what
> the valley example takes (ADR 0025, T164-T165). Each game is cited for
> what its article was read to say on 2026-11-11, and no more; what could
> not be checked is listed at the end and not used.

## The short version {#short}

- **Most games keep a number about the player.** Good and evil points,
  light and dark, a reputation: one number, or a few, moved by what the
  player does, read by the people the player meets.
- **A few keep the world instead.** A burnt barn stays burnt; a history
  is written as sentences. The world itself is the memory, and the player
  reads it rather than a meter.
- **The valley does the second, and derives the first.** It keeps only
  the deeds, as `{day, verb, place}`. The world of any day and the
  player's standing are rebuilt from them every session, by rules and
  weights a designer wrote. Nothing derived is saved.
- **What is refused:** a number fitted to the player, a memory of a
  person, and anything that makes the game harder because of what the
  player did. The standing sets consequences -- a price, a door, a
  greeting -- never a challenge.

## A meter about the player {#meter}

- **Ultima IV** (1985) made the player's character its subject. The game
  opens with ethical dilemmas, and the player's answers rank the eight
  virtues. Afterwards actions raise and lower each virtue: underpaying a
  merchant marks the player as dishonest, fleeing a battle lowers valour,
  giving beggars alms "demonstrates Compassion"; and "virtue affects how NPCs interact
  with the player" [Ultima IV].
- **Fable** (2004) splits it into good and evil points. Saving villagers
  is good, killing innocents evil, and even food counts. Alignment changes
  how the hero looks -- a halo, or horns -- and "affects how non-player
  characters respond"; renown and clothing change whether townspeople
  praise or fear him [Fable].
- **Star Wars: Knights of the Old Republic** (2003) tracks "actions and
  speech, from small word choices to major plot decisions" towards the
  light or the dark side, and the side decides the ending [KOTOR].
- **Fallout** (1997) calls it reputation: "based on how they completed
  quests, the player can earn or lose reputation points, which determine
  how others treat them" [Fallout].
- **Elite** (1984) keeps the plainest record of all, a combat rating, and
  the game is named after its top rank [Elite].

Every one of these keeps a value *about the player*. The people the
player meets read the value; nobody can say, from the value alone, which
deed put it there.

## A memory that forgets on purpose {#forgets}

- **Grand Theft Auto III** (2001) keeps a wanted level, up to six stars,
  raised by crimes. It is a memory made to fade: out of the officers'
  sight the meter "gradually recedes", and a bribe removes a star [GTA
  III].
- **Hades** (2020) is the opposite case. The player dies and starts again,
  and the world remembers the attempt: "these bits of dialog are advanced
  with each run", and the player can "improve his standing with" the
  Underworld's characters across deaths [Hades].

Both show that what a game keeps is a design choice, not a consequence of
having a save file: GTA forgets what a save could keep; Hades remembers
across what looks like a fresh start.

## The world as the memory {#world}

- **Dwarf Fortress** (2006) keeps worlds. A world is generated with years
  of history, and it persists: "if you retire a fortress or your colony is
  wiped out, the world remains". Legends mode records what characters did
  as sentences -- kills, alliances, rivalries -- and the achievements of
  the player's fortresses are added to those records [Dwarf Fortress].
  This is the closest shipped relative of the valley: a record of deeds,
  readable as such.
- **RimWorld** (2018) shows what the valley refuses. Its storyteller
  "procedurally generates events and sets difficulty", picking them from
  its read of the player's situation [RimWorld]. That is a reading of the
  player turned into a challenge -- exactly what ADR 0025 forbids the
  standing to do, and why the valley has no difficulty at all.

## What research adds {#research}

- **Talk of the Town** (Ryan and colleagues, 2015) is the game a research
  framework was built for: non-player characters "who observe and form
  knowledge about the world, propagate knowledge to other characters,
  misremember and forget knowledge, and lie". It starts from a defect it
  names: characters "in one area of the game world appearing cognizant of
  the player's behavior in another area before word of it could have ever
  spread to them" [Ryan et al.]. The memory there belongs to the people,
  and it is allowed to be wrong.

The valley does not do this, on purpose: no villager keeps anything, and
none reads another. That is the line between this example and Talk of the
Town, and the case in "When not to use it" below.

## What the kit takes {#kit}

- **Keep the deeds, not the player** (ADR 0025). A deed is `{day, verb,
  place}`; the schema has no field for a person, so the record cannot
  become a log of what the player did to whom. The save is the record and
  nothing else: `ValleySave`, `user://valley/deeds.json`.
- **Rebuild the world, as Dwarf Fortress keeps it.** `ValleyRules` replays
  the record over authored overnight rules: a burnt barn leaves the market
  without bread the next day. Every fact keeps the reason that last
  changed it, so the screen can say which deed is behind it.
- **Derive the meter, as Ultima IV reads it.** `Standing` sums fixed
  weights over the deeds, into care and fear. Two players who did the same
  deeds stand the same, however they played.
- **Let a few people read it, never the villagers.** Three people with a
  fixed manner (`VillagerManner`) read the standing and set a price, a door
  and a greeting -- Fable's townspeople, written as data. The villagers
  plan their day from the world's facts alone (`ValleyVillager`): when the
  bridge is gone they bake their own bread because the market is out of
  reach, not because they know who pulled it down. A plan's cost is an
  approximation: each action is priced by the walk from where the villager
  stands when it plans, not from the step before, which keeps GOAP's costs
  fixed during one search and is close enough on a map this small.
- **A deed that changes nothing is not kept**, or a player could stand
  well by shutting a shut gate every day.
- **Erasing is a button.** The record is the only thing kept, so removing
  it returns the valley to its first day.

## When not to use it {#when-not}

- **When the memory is what people believe, not what happened.** A town
  where gossip spreads, is misremembered and lies -- Talk of the Town's
  subject -- needs memories that belong to the characters and can be
  wrong. A record of deeds is true by construction and belongs to nobody.
- **When the record would grow without end.** Rebuilding day n replays n
  nights. A game played for thousands of days needs a checkpoint of the
  world, which is derived state on disk -- the thing ADR 0025 refuses --
  so it needs another design.
- **When the point is that the game adapts to the player.** A storyteller
  that reads the player and sets the challenge is a different technique,
  and the kit keeps it apart (ADR 0016's rules N9, N13, N14: counted
  during one fight, never saved).

## Unchecked {#unchecked}

Named in the research brief and not used above, because the pages read on
2026-11-11 did not say it:

- Elite's legal status (clean, offender, fugitive) and the police's answer
  to it: the article read covers only the combat rating.
- Fallout's karma as a number separate from reputation: the article read
  speaks of reputation points only.
- RimWorld's colonists' memories of events: the article read describes
  moods and relations, not memories.

## Sources {#sources}

- [Ultima IV] https://en.wikipedia.org/wiki/Ultima_IV:_Quest_of_the_Avatar
- [Fable] https://en.wikipedia.org/wiki/Fable_(2004_video_game)
- [KOTOR] https://en.wikipedia.org/wiki/Star_Wars:_Knights_of_the_Old_Republic
- [Fallout] https://en.wikipedia.org/wiki/Fallout_(video_game)
- [Elite] https://en.wikipedia.org/wiki/Elite_(video_game)
- [GTA III] https://en.wikipedia.org/wiki/Grand_Theft_Auto_III
- [Hades] https://en.wikipedia.org/wiki/Hades_(video_game)
- [RimWorld] https://en.wikipedia.org/wiki/RimWorld
- [Dwarf Fortress] https://en.wikipedia.org/wiki/Dwarf_Fortress
- [Ryan et al.] J. O. Ryan, A. Summerville, M. Mateas, N. Wardrip-Fruin,
  "Toward Characters Who Observe, Tell, Misremember, and Lie",
  Experimental AI in Games, AIIDE 2015 Workshop:
  https://cdn.aaai.org/ojs/12825/12825-52-16341-1-2-20201228.pdf
- The example: [the valley](../godot/valley.md); the rule:
  [ADR 0025](../adr/0025-a-save-is-a-record-of-deeds.md).
