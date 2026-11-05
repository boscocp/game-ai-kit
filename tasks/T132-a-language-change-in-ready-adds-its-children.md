# T132 — A language change in `_ready` adds its children

Size: S · Prereqs: T94, T78 · Files: `godot/game/talk/talk.gd`, `godot/test/talk/`, `docs/godot/localisation.md`

## Goal

The owner found it on 2026-11-05, running `make demo-talk` with pt-BR
saved, and answered "as 3" to the proposal below:

```
ERROR: Parent node is busy setting up children, `add_child()` failed.
       [0] restart (res://game/talk/talk.gd:125)
       [1] _notification (res://game/talk/talk.gd:65)
       [2] apply (res://game/language.gd:52)
       [3] apply_if_opened_alone (res://game/language.gd:63)
       [4] _ready (res://game/talk/talk.gd:58)
```

Opened alone, the talk scene's `_ready` changes the language; the
notification restarts the conversation, and the new guard is never added
to the tree. Neither the menu nor a test reaches that path, because
`apply_if_opened_alone` does nothing unless the scene is `current_scene`.

## Decisions written down first

- **Read the documentation, then measure** (CLAUDE.md): `add_child` while
  a notification runs, `call_deferred`, and how
  `NOTIFICATION_TRANSLATION_CHANGED` is delivered, on 4.7.
- **In each scene or once in `Language`** -- the task decides, and says
  why, against `language.gd`'s "call it last in `_ready`" contract.
- **The other scenes that rebuild on a change of language** are checked
  one by one; any that is affected gets the same test.

## Steps

1. A test that fails today: the talk scene opened as the engine opens a
   main scene, `current_scene` in its `_ready`, with pt-BR saved -- no
   "busy setting up children" error, and the guard inside the tree.
2. The fix, where step 1's measurement says it belongs.
3. Every scene that calls `apply_if_opened_alone`, and the menu, opened
   alone with pt-BR saved and switched while open.

## Acceptance

```bash
make test-godot-some SUITES="test/talk"
make test-talk-vectors
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

`make demo-talk` with pt-BR saved (switch it in `make menu`, or with L):
does the terminal stay free of "busy setting up children", and does Bram
answer the first recorded line in Portuguese? Then the same with English
saved.

## Notes

- Measured on 4.7.2 (`docs/godot/localisation.md`, "Measured on 4.7.2"):
  the cause is not `_ready`. `set_locale` notifies through
  `propagate_notification`, which holds each node busy while it and
  everything below it are notified, so the talk scene could not add its
  guard at *any* change of language while it was open. Deferring
  `Language.apply` would fix neither path: the deferred `set_locale`
  notifies the same way (the review's plant). The fault is any `add_child`
  from that notification, wherever the change comes from. So the fix is
  the scene's: a deferred restart, skipped if the scene has left the tree.
- The scene takes a `settings_path`, as the menu does, so the test saves
  its pt-BR in a file of its own and never the person's (the review).
- Reviewed: `docs/reviews/135-a-language-change-in-ready-adds-its-children.md`.
- Of the 15 other scenes that call `apply_if_opened_alone` -- the eight
  named in the proposal and seven more (`racing3d`, `botmatch`,
  `infiltration`, `racing_demo`, `behaviour_demo`, `steering_demo`,
  `search_demo`) -- and the menu, none
  adds a child to itself on that notification; each opened alone with pt-BR
  saved and switched twice gave no such error. Their legends draw, they
  hold no children.
- Done in wave 135.
