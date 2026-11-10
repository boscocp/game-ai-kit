# T158 — A director for the minions, and three difficulties

Size: M · Prereqs: T157 · Files: `godot/game3d/bossfight/`, `godot/test/bossfight/`, `docs/godot/bossfight.md`, `godot/menu/catalogue.json`, `godot/locale/`

## Goal

Minions that keep coming at one pace make a boss fight a grind. Left 4
Dead's AI Director alternates build-up, peak and relief from how hard the
fight is [Booth 2009]. The infiltration example already paces its reserve
guards with a director (`godot/game3d/infiltration/director*.gd`, T90). The
boss fight needs the same idea for its waves. It also needs difficulty a
person can choose.

## Decisions written down first

_The owner asked for this task on 2026-11-10, from a request on Reddit: enemies "like Insomniac's Spider-Man: a group, but one attacks at a time, and a ranged attacker from far away". It cited the GDC 2019 "Marvel's Spider-Man AI Postmortem" and the Unreal plugin "Soulslike Enemy AI Combat System" (its video: "Soulslike Enemy Combat 3.2"). Decisions marked **(owner)** were answered on that date. The rest is this session's proposal; the wave that takes the task confirms it, or brings it back to the owner._

- **(owner) Three difficulty levels, chosen by the person, with no adaptation
  to the player**:
  - a table in `bossfight/difficulty.json` with easy, normal and hard;
  - each level sets the token pools and reissue delays (T154), the minimum
    telegraph (T156), the minions per wave and the wave cap;
  - chosen in the example's menu and by a command-line flag;
  - a level that does not exist is refused by name;
  - nothing about the player is counted, so ADR 0016 is not extended;
  - `ai_planning/difficulty.gd` is **not** reused, and the reason is written
    on the page. It teaches that a level changes only how much a searching
    AI thinks. It calls giving the AI more "a lie told to the player", and
    `test-difficulty-knobs` holds that. These levels do give the boss's side
    more: more tokens, shorter delays, bigger waves. So they are a
    different, honest thing. The table is on screen with its numbers, so
    nothing is hidden from the player. `difficulty.gd` and its test stay as
    they are. If the wave thinks this contradicts the kit's teaching, it
    brings it to the owner before writing code.
- **The director reads events, not the player's skill.** The events are the
  boss's phase change, minions alive and the time since the last wave. It
  uses them to move through build-up, peak and relief, and it never spawns
  during a heavy boss attack. Its state and its next wave are shown.
- **Hard is faster, never unreadable**: no level's telegraph goes below the
  minimum set in T156. That rule holds across the whole table.

## Acceptance

```bash
make test-godot-some SUITES="test/bossfight"
make test-demo-overlays
```

For each level, a seeded headless run respects the table:

- pool sizes;
- telegraph minimum;
- wave cap.

Planted cases the tests must reject: a level whose telegraph is below the
minimum, and an unknown level name.

## Manual check

- Easy can be won by a newcomer, and hard is harder without being unfair.
- The director's relief is visible as a pause.

## Sources

Sources marked [F] were opened and checked on 2026-11-10. Sources marked [S]
were seen only in search results; the wave reads them before citing them.

- Dawe, "Beyond the Kung-Fu Circle: A Flexible System for Managing NPC Attacks", *Game AI Pro* 1, ch. 28 (2013) [F, index only; the body is unread]. This is the main reference.
- Noonchester, "Marvel's Spider-Man AI Postmortem", GDC 2019, https://gdcvault.com/play/1025828 [F]. The video is https://www.youtube.com/watch?v=LxWq65CZBU8. Its account of the token "jobs", and of the ranged manager narrowing its windows when melee is close, comes from an unofficial summary [S] and needs checking against the talk.
- Thompson, "Cyber Demons: The AI of DOOM (2016)", Game Developer, 2018 [F]: a token pool per attack type, request and release, pool size by difficulty, HFSMs.
- Campbell, "Bringing Hell to Life", GDC 2017 [S]. Loudy and Campbell, push-forward combat, GDC 2018 [S].
- Rigbak / Erünsal, "Soulslike Enemy AI Combat System", Fab [F], video https://www.youtube.com/watch?v=Xy0CcT1pvvA. Its features: a token pool per target, circling and spacing, reacting to the attack's telegraph, and a second moveset below a health threshold.
- Ocio Barriales, 2017, already cited in `docs/concepts/shooter-ai.md`. Tokens there decide whose shots hit.
- Booth, "The AI Systems of Left 4 Dead", 2009 [S]. Brewer, "Managing Pacing in Procedural Levels in Warframe", *Game AI Pro Online* 2021, ch. 7 [F].
- Hunicke, "The Case for Dynamic Difficulty Adjustment in Games", ACE 2005 [S]: the adaptive alternative the owner chose not to use.
