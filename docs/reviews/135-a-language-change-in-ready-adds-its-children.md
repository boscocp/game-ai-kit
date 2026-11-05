# Review: wave/135, T132 -- a language change gives the talk scene its guard

T132: `make demo-talk` with pt-BR saved logged "Parent node is busy
setting up children, `add_child()` failed", and the new guard never
reached the tree. The PR changes one line of `talk.gd`
(`restart.call_deferred()` in `_notification`), adds
`godot/test/talk/talk_language_test.gd` (two tests), a row in
`docs/godot/localisation.md`, the task file and a STATUS row.

A fresh context reviewed PR #80 at head f143451. It read the code and the
engine source, and ran narrow checks in a throwaway worktree. It made no
commit, push or PR comment.

**Verdict: changes requested, no blocker.** The fix is right and the
mechanism is right. One should-fix is about the test: it writes the
person's own `user://settings.cfg`, which the repository's own convention
forbids, and a test killed mid-run leaves the person's language changed.
One should-fix is about the reasoning written down: the task file,
STATUS and the PR body say a deferred `Language.apply` "would fix only
`_ready`". A plant shows it fixes nothing at all. The conclusion holds,
but the reason is wrong.

## What was reviewed

- The whole diff: `talk.gd`, the new test file, the `localisation.md`
  rows and doc-meta, the task file and the STATUS row.
- `language.gd` (`apply`, `apply_if_opened_alone`, `choose`), `menu.gd`'s
  `settings_path`, `language_test.gd`'s header, `pad_as_keys.gd`'s
  `add_to`, `rts_command_card.gd`, and the `_notification` of all 17
  scripts that handle `NOTIFICATION_TRANSLATION_CHANGED`.
- The engine source at `4.7.2-stable`: `scene/main/node.cpp`
  (`propagate_notification`, `add_child`, `NOTIFICATION_POST_ENTER_TREE`)
  and `scene/main/scene_tree.cpp` (`notification`, `set_current_scene`).

## What was run (green at f143451 unless stated)

- `make test-godot-some SUITES="test/talk/talk_language_test.gd"`: 2
  cases, 0 failures, no `SCRIPT ERROR`.
- `python3 scripts/check_readability.py`: exit 0.
- `make lint-tasks lint-status`: ok.
- The real engine opening the scene as its main scene, with pt-BR saved in
  this worktree's `user://`:
  `./scripts/godot --headless --path godot <scene> --quit-after 20`. On
  `origin/main`'s `talk.gd` it prints the busy error; on the PR it does
  not. `rts`, `botmatch` and `fighting` print none either way.
- A probe suite (`review_probe_test.gd`, kept in this folder, not
  committed): two changes in one frame, the scene freed or removed before
  the deferred call, a line chosen between the change and the restart,
  and `rts` and `botmatch` switched twice while open.

## The mechanism (focus 1)

The claim holds, and the source says it more precisely than the doc row
does. At `4.7.2-stable`:

```cpp
// scene/main/node.cpp
void Node::propagate_notification(int p_notification) {
	data.blocked++;
	notification(p_notification);
	for (KeyValue<StringName, Node *> &K : data.children) {
		K.value->propagate_notification(p_notification);
	}
	data.blocked--;
}
// add_child: ERR_FAIL_COND_MSG(data.blocked > 0, "Parent node is busy setting up children, ...")
// scene/main/scene_tree.cpp, SceneTree::notification:
//   case NOTIFICATION_TRANSLATION_CHANGED: get_root()->propagate_notification(p_notification);
```

So a node is held busy while it **and its whole subtree** are notified,
not only "while its own notification runs". Every ancestor of the node
being notified is busy too. "A descendant is not busy yet when its
ancestor is notified" is right. The class reference says none of this,
as the PR says. The source is the only written evidence, and the doc row
does not cite it (nit 4).

## Mutation round

Each was one line, run against the narrow test, then restored.

| | plant | where | caught by |
|---|---|---|---|
| P1 | the original synchronous `restart()` | `talk.gd:68` | `test_opened_alone_...` (3 failures); with that test switched off, `test_a_change_of_language_...` (5 failures); the probe's two-changes test (3 busy errors, 0 guards) |
| P2 | P1, plus `apply.call_deferred(path)` in `apply_if_opened_alone` (the alternative decision 1 rejects) | `language.gd:63` | `test_opened_alone_...` fails: the busy error, backtrace `apply` -> `_notification`, no `_ready` frame. A deferred apply still goes through `propagate_notification`, so it fixes **neither** path (finding 2) |
| P3 | `OS.crash()` right after the test saves pt_BR, with `locale="en"` saved first | `talk_language_test.gd:85` | **nothing restores it**: `settings.cfg` read `locale="pt_BR"` afterwards (finding 1) |
| P4 | live mode, the scene removed from the tree in the same frame as the change | probe only | the deferred `restart` runs out of the tree: two `!is_inside_tree()` errors (nit 3) |

## The deferred restart (focus 2)

Probed, all green on the PR:

- **Two or three changes in one frame:** three deferred restarts, each
  `queue_free`s the guard before it. After two frames there is one
  `TalkGuard` child, in the tree, speaking the last locale, and no error.
- **Input between the change and the restart:** `choose(0)` in that
  window reaches the old guard (still valid, not freed). The restart then
  frees it and empties `said`. No error. This is the same thing R does
  mid-answer today.
- **Scene freed (`free()`) before the deferred call:** the call is
  dropped, no error.
- **Scene removed and `queue_free`d (a scene change):** recorded mode, no
  error. Live mode logs two `!is_inside_tree()` errors (P4, nit 3). No
  path in the game changes the language and the scene in one frame, so
  this cannot be reached today.

## Findings

1. **Should-fix: the test writes the person's own `user://settings.cfg`**
   (`talk_language_test.gd:43-54, 85`; decision 2). The repository
   already settled this. `menu.gd:60-63` gives the menu a `settings_path`
   "so a person's choice never leaks into a test, nor a test's into the
   person's game". `language_test.gd:6-9` says a test that read or left
   the real `settings.cfg` "would depend on whoever ran last". This test
   saves and restores in `before_test`/`after_test`. That holds only if
   the run reaches `after_test`. *Proved by P3:* with `en` saved, a crash
   after the save left `pt_BR`. A killed run, a Godot crash, a Ctrl-C, or
   a timeout in CI would do the same. ADR 0022 does not make it safe. It
   keeps worktrees apart, but the main checkout's `.user-data/` is the one
   the owner plays from (`make menu`, `make demo-talk`), and `make check`
   runs this suite there. *Fix:* the menu's pattern. Add
   `var settings_path: String = Language.SETTINGS` to `TalkDemo`, pass it
   in `Language.apply_if_opened_alone(self, settings_path)`, and point it
   at `user://talk_language_test_settings.cfg` before `add_child`. The
   test then removes its own file, as `language_test.gd` does. That is
   two lines of `talk.gd`. The T130 merge it was meant to avoid touches
   other lines (`_ready` line 58 at most), and can take it.
2. **Should-fix: "a deferred `Language.apply` would fix only `_ready`" is
   wrong** (task file Notes; the STATUS row; PR decision 1). *Proved by
   P2:* deferred, `set_locale` still notifies through
   `propagate_notification`, the talk node is still busy, and the guard
   still never reaches the tree. The decision stands, for a stronger
   reason: the fault is any `add_child` from that notification, wherever
   `set_locale` is called. *Fix:* say that in the task note and the
   STATUS row.
3. **Nit: a deferred restart can run after the scene left the tree**
   (`talk.gd:68`, P4). Live mode then calls `grab_focus` out of the tree.
   It cannot be reached today. If wanted, a one-line guard in a deferred
   wrapper would close it (`if is_inside_tree(): restart()`). Otherwise,
   say it in the comment.
4. **Nit: the doc row says less than the source** (`localisation.md:469`
   and `talk.gd:62-64`). "Holds each node busy while its own notification
   runs" should read "while it and everything below it are notified".
   That also covers `add_sibling` or adding to an ancestor, which fail the
   same way. The row's `source:` should add `node.cpp` and
   `scene_tree.cpp` at `4.7.2-stable`, because the class reference is
   silent.

Readability: `check_readability.py` passes. `talk.gd` is 268 lines and
the test 111. Every function is under 25 lines, with nesting at most 2.
The new comments say why, not what. The test's header and helpers read
well. `BusyParentCounter` is a neat way to turn an engine error into an
assertion.

## The "only talk" claim (focus 4)

Believable. Statically, none of the 16 other `_notification` handlers
calls `add_child`. They set legend entries, `_refresh`, `queue_redraw`
or `forget_buttons`. `PadAsKeys.add_to`, which several call, appends
entries and adds no node, so a connected pad would not change this. The
RTS card rebuilds its buttons as children of the card, a descendant,
which is not busy yet. Runtime spot-checks: `rts` and `botmatch` (plus
`fighting`), opened as the main scene with pt-BR saved, and `rts` and
`botmatch` switched twice while open. No busy error anywhere. The PR's
decision 5 (no cross-scene gate yet) is reasonable.

## The PR's decisions

1. Fix in the scene, not in `Language`: **sound**, for the stronger
   reason in finding 2.
2. The test uses the person's `settings.cfg`: **not sound** (finding 1).
3. `current_scene` from `tree_entered`: **sound**. `set_current_scene`
   requires the root as parent (`scene_tree.cpp:1665`), which holds at
   `tree_entered`, and the runner's scene is put back right away.
4. `language.gd`'s comment unchanged: acceptable. It does need the
   stronger wording when it is written, because the rule applies wherever
   the change comes from, not only in `_ready`.
5. No cross-scene gate: sound for now.

## For the owner

1. Finding 1 is the main question: a `settings_path` on `TalkDemo` (two
   lines, the menu's pattern) instead of a test that writes your saved
   language. Recommended: yes, in this PR.
2. Whether a future wave should add the "never `add_child` to yourself
   from `NOTIFICATION_TRANSLATION_CHANGED`" rule to `language.gd`'s doc
   comment (decision 4), worded as finding 2 says.
3. The manual check (`make demo-talk` with pt-BR, then English) stays
   yours. The headless main-scene run above already shows no busy error.

## What was done about them

All applied on the branch, in one commit after f143451.

1. **Applied.** `TalkDemo` has a `settings_path`, as `ExampleMenu` does,
   passed to `Language.apply_if_opened_alone`. The test points it at
   `user://talk_language_test_settings.cfg` before the scene enters the
   tree, and removes that file afterwards. It never reads or writes the
   person's `settings.cfg`. Decision 2 is dropped.
2. **Applied.** The task's Notes, the STATUS row, the PR body and the
   `localisation.md` row now say that a deferred `Language.apply` fixes
   neither path, because the deferred `set_locale` notifies the same way.
   Decision 1 stands, for that reason.
3. **Applied (nit).** The notification defers `_restart_if_in_tree`,
   which restarts only while the scene is in the tree. A scene that left
   in the same frame is skipped, and live mode no longer focuses a text
   box out of the tree.
4. **Applied (nit).** `talk.gd`'s comment, the test's header and the
   `localisation.md` row say "while it and everything below it are
   notified". The row now names `SceneTree::notification`,
   `propagate_notification` and `add_child` at 4.7.2-stable, and its
   `source:` cites `node.cpp` and `scene_tree.cpp` at that tag.

Decision 4, for the wave that next touches `language.gd`: the doc
comment of `apply_if_opened_alone` and `choose` should say "a node must
not add a child to itself, or to anything above it, from
`NOTIFICATION_TRANSLATION_CHANGED`, wherever the change of language comes
from: the engine holds it busy while it and everything below it are
notified. Defer it."
