# T154 — Attack tokens: one attacks at a time

Size: M · Prereqs: T160 · Files: `godot/addons/ai_teamwork/`, `godot/test/ai_teamwork/`, `python/gameaikit/teamwork/`, `python/tests/`, `spec/vectors/teamwork/`, `modules/ai_teamwork.json`, `docs/techniques/ai_teamwork*.md`, `docs/concepts/`

## Goal

In an action game a group surrounds the player, but only one or two of them
strike at a time. The rest circle and wait, and a ranged enemy fires from a
distance at its own pace. The player feels outnumbered without being
swarmed. Spider-Man (Insomniac), DOOM (2016) and the Souls-likes do this
with **attack tokens**. An enemy must hold a token to attack, and it gives
the token back when the attack ends. Dawe's chapter calls the naive version
the "kung-fu circle" and generalises it.

The kit has no such thing. `GakRoleArbiter` (`ai_teamwork/role_arbiter.gd`)
caps how many may *take a role*. `docs/concepts/shooter-ai.md` describes
tokens for whose shots hit, but nothing implements them. T52 planned them
and was split without them.

## Decisions written down first

_The owner asked for this task on 2026-11-10, from a request on Reddit: enemies "like Insomniac's Spider-Man: a group, but one attacks at a time, and a ranged attacker from far away". It cited the GDC 2019 "Marvel's Spider-Man AI Postmortem" and the Unreal plugin "Soulslike Enemy Combat 3.2". Decisions marked **(owner)** were answered on that date. The rest is this session's proposal; the wave that takes the task confirms it, or brings it back to the owner._

- **(owner) It lives in `ai_teamwork`**, as `GakAttackTokens`, next to the
  role arbiter. It depends only on `ai_core` (invariant 2), and has a
  Python twin with shared vectors like the rest of the addon.
- **The pool belongs to a target and has one count per attack kind**, for
  example `melee: 1` and `ranged: 1`. A kind may have a cost, so a heavy
  attack takes two. Requests are answered by a rule written down in data:
  - the one already waiting longest;
  - then the nearest;
  - then a seeded tie-break.
  There is no starvation: a requester that waits is served within K
  reissues, and that bound is a test.
- **A token is given back in three ways:** the attack ends, the holder is
  interrupted or dies, or it times out. The timeout is the safety net for a
  holder that forgot. The test that holds it is a planted holder that never
  releases.
- **Reissue is a timer with multipliers**, as in Ocio Barriales and the
  Spider-Man talk:
  - a base delay;
  - longer when the player is already busy (for example, under melee
    pressure, the ranged kind waits longer);
  - shorter when the player is idle.
  The multipliers are data and are shown on screen, not hidden.
- **Difficulty sets the pool sizes and delays**, from a table T158 fills.
  This task takes the table as input and does not choose it.
- **Taught:** a technique page in English and pt-BR (`ai_teamwork.md` and
  its twin get a section; the glossary gets "attack token"). A concept page
  `docs/concepts/action-combat-ai.md` opens the batch: tokens, rings
  (T155) and telegraphs (T156), each with its source, plus "when not to use
  it": a fight with one enemy, or a stealth game.

## Acceptance

```bash
make test-godot-some SUITES="test/ai_teamwork"
make test-teamwork-vectors
make test-python
make lint-tiers
```

The properties tested:

- never more holders than the pool allows, for each kind;
- every requester is served within K reissues;
- a holder that dies frees its token on the same step;
- the same seed gives the same grants.

Planted cases the tests must reject:

- a pool that leaks (grants without counting);
- a token never released;
- a tie broken by dictionary order.

## Manual check

- The concept page reads top to bottom as the tokens chapter reads, and its
  "when not to use it" names a case.

## Sources

Sources marked [F] were opened and checked on 2026-11-10. Sources marked [S]
were seen only in search results; the wave reads them before citing them.

- Dawe, "Beyond the Kung-Fu Circle: A Flexible System for Managing NPC Attacks", *Game AI Pro* 1, ch. 28 (2013) [F, index only; the body is unread]. This is the main reference.
- Noonchester, "Marvel's Spider-Man AI Postmortem", GDC 2019, https://gdcvault.com/play/1025828 [F]. The video is https://www.youtube.com/watch?v=LxWq65CZBU8. Its account of the token "jobs", and of the ranged manager narrowing its windows when melee is close, comes from an unofficial summary [S] and needs checking against the talk.
- Thompson, "Cyber Demons: The AI of DOOM (2016)", Game Developer, 2018 [F]: a token pool per attack type, request and release, pool size by difficulty, HFSMs.
- Campbell, "Bringing Hell to Life", GDC 2017 [S]. Loudy and Campbell, push-forward combat, GDC 2018 [S].
- Rigbak / Erünsal, "Soulslike Enemy AI Combat System", Fab [F], video https://www.youtube.com/watch?v=Xy0CcT1pvvA. Its features: a token pool per target, circling and spacing, reacting to the attack's telegraph, and a second moveset below a health threshold.
- Ocio Barriales, 2017, already cited in `docs/concepts/shooter-ai.md`. Tokens there decide whose shots hit.
