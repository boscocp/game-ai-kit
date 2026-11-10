# T156 — A boss with phases and telegraphed attacks

Size: M · Prereqs: T154 · Files: `godot/game3d/bossfight/`, `godot/test/bossfight/`, `docs/concepts/action-combat-ai.md`

## Goal

A boss fight is a test of what the player has learned [Keren 2018], and it is
fair only if every attack can be read before it lands. Every attack has
three windows:

- a **telegraph**, the wind-up the player sees;
- an **active** window that hurts;
- a **recovery**, the opening to punish.

The boss changes **phase** at health thresholds: a new moveset, a summon of
minions, faster tells. DOOM (2016) uses hierarchical state machines, and the
Souls-like plugin adds a second moveset below a threshold.

## Decisions written down first

_The owner asked for this task on 2026-11-10, from a request on Reddit: enemies "like Insomniac's Spider-Man: a group, but one attacks at a time, and a ranged attacker from far away". It cited the GDC 2019 "Marvel's Spider-Man AI Postmortem" and the Unreal plugin "Soulslike Enemy Combat 3.2". Decisions marked **(owner)** were answered on that date. The rest is this session's proposal; the wave that takes the task confirms it, or brings it back to the owner._

- **The phases are the top of a behaviour tree** built with `ai_behaviour`'s
  `behaviour_tree.gd`. A selector checks each phase's health condition,
  and below it sits that phase's attack choice. The kit has no HFSM class,
  and this task does not add one. If the wave finds the tree reads worse
  than nested `state_machine.gd`s, it writes that down and asks.
- **The next attack is a utility choice** (`ai_utility/action_choice.gd`).
  Its considerations are distance, the player's facing, and how long since
  this attack was last used (a repetition penalty). The attacks and the
  three windows' lengths are data, in `bossfight/boss_attacks.json`.
- **The boss uses the target's token pool, with a cost.** A heavy attack
  takes the melee kind's whole pool, so minions do not strike during it.
  This is why T154 has costs.
- **A phase change is an event the minions' director (T158) reads.** The
  boss does not spawn anything itself.
- **No adaptation to the player (owner)**: nothing is counted about the
  player, so ADR 0016 is not extended. Difficulty comes from T158's table.
- **Shown:** the phase, the attack chosen and why (its considerations), and
  a bar for the telegraph window.

## Acceptance

```bash
make test-godot-some SUITES="test/bossfight"
```

Properties, headless and seeded:

- every attack has a telegraph no shorter than the table's minimum;
- no attack runs three times in a row within a phase;
- the phases are entered in order, each once;
- the same seed gives the same sequence.

Planted cases the tests must reject: an attack with a zero telegraph, and a
phase whose health condition is never met.

## Manual check

- Each attack can be dodged on reaction by a person who watches the
  telegraph.

## Sources

Sources marked [F] were opened and checked on 2026-11-10. Sources marked [S]
were seen only in search results; the wave reads them before citing them.

- Dawe, "Beyond the Kung-Fu Circle: A Flexible System for Managing NPC Attacks", *Game AI Pro* 1, ch. 28 (2013) [F, index only; the body is unread]. This is the main reference.
- Noonchester, "Marvel's Spider-Man AI Postmortem", GDC 2019, https://gdcvault.com/play/1025828 [F]. The video is https://www.youtube.com/watch?v=LxWq65CZBU8. Its account of the token "jobs", and of the ranged manager narrowing its windows when melee is close, comes from an unofficial summary [S] and needs checking against the talk.
- Thompson, "Cyber Demons: The AI of DOOM (2016)", Game Developer, 2018 [F]: a token pool per attack type, request and release, pool size by difficulty, HFSMs.
- Campbell, "Bringing Hell to Life", GDC 2017 [S]. Loudy and Campbell, push-forward combat, GDC 2018 [S].
- Rigbak / Erünsal, "Soulslike Enemy AI Combat System", Fab [F], video https://www.youtube.com/watch?v=Xy0CcT1pvvA. Its features: a token pool per target, circling and spacing, reacting to the attack's telegraph, and a second moveset below a health threshold.
- Ocio Barriales, 2017, already cited in `docs/concepts/shooter-ai.md`. Tokens there decide whose shots hit.
- Keren, "Boss Up: Boss Battle Design Fundamentals and Retrospective", GDC 2018 [F]. "Designing for Difficulty: Readability in ARPGs" [S].
- Isla, "Handling Complexity in the Halo 2 AI", GDC 2005 [S].
