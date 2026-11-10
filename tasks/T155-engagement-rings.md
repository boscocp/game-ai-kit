# T155 — Engagement rings: where the others wait

Size: M · Prereqs: T154 · Files: `godot/addons/ai_teamwork/`, `godot/test/ai_teamwork/`, `python/gameaikit/teamwork/`, `python/tests/`, `spec/vectors/teamwork/`, `docs/techniques/ai_teamwork*.md`, `docs/concepts/action-combat-ai.md`

## Goal

A token says *who* attacks. It does not say where the others stand. Without
that, the waiting enemies bunch up, stand behind the player where they cannot
be seen, or block the ranged attacker's line. The industry answer is a set
of rings round the target:

- an inner ring for the token holder;
- a waiting ring where the rest strafe and face the player, ready to step in;
- an outer ranged band with a clear line of sight.

The Souls-like plugin and God of War's "location manager" [S] both do this.
As a query it is Jack's tactical position selection, the precursor of
Unreal's EQS.

## Decisions written down first

_The owner asked for this task on 2026-11-10, from a request on Reddit: enemies "like Insomniac's Spider-Man: a group, but one attacks at a time, and a ranged attacker from far away". It cited the GDC 2019 "Marvel's Spider-Man AI Postmortem" and the Unreal plugin "Soulslike Enemy AI Combat System" (its video: "Soulslike Enemy Combat 3.2"). Decisions marked **(owner)** were answered on that date. The rest is this session's proposal; the wave that takes the task confirms it, or brings it back to the owner._

- **A ring generator for the existing `TacticalPositions`**
  (`ai_teamwork/tactical_positions.gd`), not a second spatial system.
  `TacticalPositions` filters, weighs and claims points from facts the
  caller gives it; it casts no rays. The ring generator keeps that split.
  It only places candidate points, with a radius and a count per ring.
  The example (T157) fills in each point's facts, including the line of
  sight, which it casts with physics. Then `TacticalPositions` weighs
  them:
  - in front of the player's camera;
  - away from the other claims;
  - the line-of-sight fact for the ranged band.
  So `ai_teamwork` and its Python twin stay free of physics (invariant 2).
- **Holding a token moves an enemy to the inner ring**, and giving it back
  sends it out again. The rings never grant attacks; T154 does.
- **Circling is steering**, done by the example (T157) with `ai_steering`'s
  arrive and separation on the claimed point. The addon only says where.
- **Shown:** the three rings, each claim and who holds it.

## Acceptance

```bash
make test-godot-some SUITES="test/ai_teamwork"
make test-teamwork-vectors
```

Properties, on a seeded scene with cover:

- no two claims closer than the spacing;
- every ranged claim is a point whose line-of-sight fact is true;
- no waiting claim in the half-plane behind the camera when a free one is
  in front.

Planted case the tests must reject: a generator that ignores the claims.

## Manual check

- Rings drawn in the example (T157) look like a circle of enemies, not a
  queue.

## Sources

Sources marked [F] were opened and checked on 2026-11-10. Sources marked [S]
were seen only in search results; the wave reads them before citing them.

- Dawe, "Beyond the Kung-Fu Circle: A Flexible System for Managing NPC Attacks", *Game AI Pro* 1, ch. 28 (2013) [F, index only; the body is unread]. This is the main reference.
- Noonchester, "Marvel's Spider-Man AI Postmortem", GDC 2019, https://gdcvault.com/play/1025828 [F]. The video is https://www.youtube.com/watch?v=LxWq65CZBU8. Its account of the token "jobs", and of the ranged manager narrowing its windows when melee is close, comes from an unofficial summary [S] and needs checking against the talk.
- Thompson, "Cyber Demons: The AI of DOOM (2016)", Game Developer, 2018 [F]: a token pool per attack type, request and release, pool size by difficulty, HFSMs.
- Campbell, "Bringing Hell to Life", GDC 2017 [S]. Loudy and Campbell, push-forward combat, GDC 2018 [S].
- Rigbak / Erünsal, "Soulslike Enemy AI Combat System", Fab [F], video https://www.youtube.com/watch?v=Xy0CcT1pvvA. Its features: a token pool per target, circling and spacing, reacting to the attack's telegraph, and a second moveset below a health threshold.
- Ocio Barriales, 2017, already cited in `docs/concepts/shooter-ai.md`. Tokens there decide whose shots hit.
- Jack, "Tactical Position Selection", *Game AI Pro* 1, ch. 26 [F]. Johnson, *Game AI Pro* 3, ch. 26, and *Game AI Pro Online* 2021, ch. 5 [F].
