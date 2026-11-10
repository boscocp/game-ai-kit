# T157 — The boss-fight example

Size: L · Prereqs: T155, T156 · Files: `godot/game3d/bossfight/`, `godot/test/bossfight/`, `godot/test/menu/demo_overlays.gd`, `godot/menu/catalogue.json`, `godot/game3d/assets.json`, `modules/bossfight.json`, `Makefile`, `docs/godot/bossfight.md`, `docs/techniques/catalogue*.md`, `godot/locale/`

## Goal

A single-player fight the person plays: one boss, a few melee minions and one
or two ranged ones, in a small arena. It is the example the Reddit request
asked for, and the kit's first action fight against a group. The fighting
example is one against one, and the bot match is team against team.

## Decisions written down first

_The owner asked for this task on 2026-11-10, from a request on Reddit: enemies "like Insomniac's Spider-Man: a group, but one attacks at a time, and a ranged attacker from far away". It cited the GDC 2019 "Marvel's Spider-Man AI Postmortem" and the Unreal plugin "Soulslike Enemy AI Combat System" (its video: "Soulslike Enemy Combat 3.2"). Decisions marked **(owner)** were answered on that date. The rest is this session's proposal; the wave that takes the task confirms it, or brings it back to the owner._

- **(owner) 3D, third person**, in `godot/game3d/bossfight/`, on the 3D tier
  (ADR 0018):
  - the infiltration example's player controller and camera are reused,
    copied into the example or shared through `game3d/floor/`, whichever
    the module manifests allow;
  - the models are Kenney packs referenced by URL and sha256 in
    `assets.json`, with a primitive for every missing model;
  - the controls are: move, light attack, dodge, lock-on.
- **The minions are game code** that use T154's tokens, T155's rings,
  `ai_steering` to circle and `ai_perception` for line of sight. Melee
  minions request `melee`. Ranged minions request `ranged`. When a melee
  minion starts on the player, the game revokes the ranged token (T154's
  fourth way back) and the reissue multiplier holds it back (Spider-Man's rule).
- **Shown, as invariant 13 requires:**
  - who holds each token and who is queued;
  - the reissue timer with its multipliers;
  - the three rings and each claim;
  - the boss's phase, its next attack and the telegraph bar;
  - the director's state (T158).
  A key toggles the overlay.
- **`modules/bossfight.json` exists from T156**; this task adds what it
  owns and depends on.
- **Registered in full**, following "Adding an example" in
  `docs/godot/examples.md`:
  - `make demo-bossfight`;
  - `step_decision()` and `decision_overlay()` on the root script;
  - a `Legend`;
  - the scene in `demo_overlays.gd`;
  - a card in `catalogue.json`;
  - `modules/bossfight.json`;
  - `make catalogue` rerun;
  - English and pt-BR strings.

## Acceptance

```bash
make lint-demos
make test-demo-overlays
make test-godot-some SUITES="test/bossfight"
make lint-modules
make lint-renderer
```

A headless, seeded run of 60 s with a scripted player checks four things:

- at most the pool's melee attackers at any step;
- every minion that waits gets a turn;
- a ranged minion never fires while melee pressure is on;
- the fight ends.

## Manual check

- Play it: a group surrounds the player, one strikes at a time, the ranged
  one fires from the edge, and the overlay says why at each moment.
- Record a clip for the video's next cut (T153).

## Sources

Sources marked [F] were opened and checked on 2026-11-10. Sources marked [S]
were seen only in search results; the wave reads them before citing them.

- Dawe, "Beyond the Kung-Fu Circle: A Flexible System for Managing NPC Attacks", *Game AI Pro* 1, ch. 28 (2013) [F, index only; the body is unread]. This is the main reference.
- Noonchester, "Marvel's Spider-Man AI Postmortem", GDC 2019, https://gdcvault.com/play/1025828 [F]. The video is https://www.youtube.com/watch?v=LxWq65CZBU8. Its account of the token "jobs", and of the ranged manager narrowing its windows when melee is close, comes from an unofficial summary [S] and needs checking against the talk.
- Thompson, "Cyber Demons: The AI of DOOM (2016)", Game Developer, 2018 [F]: a token pool per attack type, request and release, pool size by difficulty, HFSMs.
- Campbell, "Bringing Hell to Life", GDC 2017 [S]. Loudy and Campbell, push-forward combat, GDC 2018 [S].
- Rigbak / Erünsal, "Soulslike Enemy AI Combat System", Fab [F], video https://www.youtube.com/watch?v=Xy0CcT1pvvA. Its features: a token pool per target, circling and spacing, reacting to the attack's telegraph, and a second moveset below a health threshold.
- Ocio Barriales, 2017, already cited in `docs/concepts/shooter-ai.md`. Tokens there decide whose shots hit.
