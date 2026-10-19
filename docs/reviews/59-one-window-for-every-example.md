# Review: wave/59-one-window-for-every-example

One fresh context reviewed it at its first commit (4dfd283), in a worktree
of its own. It committed nothing; its probes, mutation drivers and a copy of
the repository for catalogue mutations lived in a scratch folder, every
mutated file was restored byte for byte, `__pycache__` purged, and the tree
was clean. gdUnit4 was copied in to run `make check` and removed after.

**Verdict: do not merge yet** -- two high findings and four medium. Both
high findings are in the menu's central promise, that an example opened from
it runs exactly as it does alone: after R in the skirmish Escape no longer
brings the menu back, and the tactical board opened from the menu never
rolls fresh dice for its first game. The menu walk was green on both.

## What was reviewed

- `CLAUDE.md`, T24, the whole diff; `menu.gd`, `example_catalogue.gd`,
  `menu_walk.gd`, the C1-C8 half of `check_demos.py`, `export.py`, the
  `release.py` and `bootstrap.sh` changes, line by line; both new concept
  pages against the code they cite.
- Run: `check_demos.py` (ok, 8) and its self-test (34/0); `export.py
  --self-test` (9/0); `release.py --self-test` (ok); `menu_walk.gd` (8/0, no
  `SCRIPT ERROR`); `export.py` twice (the `.pck` md5 equal both times);
  `release.py --build --executable` then `check_license.py` (exit 0); `make
  -k check` (exit 0; gdUnit 986 cases, 0 failures; overlays 8/0; walk 8/0).
  Invariant 8: `~/.local/share/godot`, `~/.config/godot`, `~/.cache/godot`
  absent before and after exporting, releasing and running the binary.
- Four probes -- the tactical dice from the menu, the skirmish reloaded then
  left, per-example object/node/orphan deltas over two rounds, the exported
  pack's directory -- and 21 mutations, of which 10 survived.

## Findings

1. *high* -- after R in the skirmish, Escape does nothing. R calls
   `reload_current_scene()`, which frees the node `menu.playing` points at;
   a freed object compares equal to null, so `_input`'s `playing != null`
   is false and Escape is ignored. The header names this case and guards
   `back()`, not the test before it. A probe pushing R, then Escape:
   `after Esc: current==menu false visible false`.
2. *high* -- the tactical board opened from the menu always starts on the
   scenario's dice (seed 0). `open()` adds the example and only then makes
   it current; `_ready` -> `new_game()` runs inside `add_child`, when the
   menu is still current, so `randi()` is skipped. Three plays from the
   menu: `dice_seed=0` each time; only R or C randomised. The walk checked
   "current scene" a frame after `_ready`, the wrong moment.
3. *medium* -- C7 holds "reachable by name", not "runs". Reading one
   constant pulls in a class's whole closure: `demo-behaviour` reads only
   `StealthWorld.SPRINT_NOISE` and so "reaches" `InfluenceMap`, and a card
   claiming an influence map passed. A type annotation alone passed, and so
   did a class named only in a `'''` string. Five cross-scene false claims
   and a `"""` string were rejected.
4. *medium* -- `make export`'s start check proves the menu starts, not that
   any example opens in the build. Excluding the tic-tac-toe beads and the
   skirmish's weights from the pack still exported "ok". The docstring says
   it refuses a build printing an engine error; only `SCRIPT ERROR` was
   read. A refused build's binary and pack stayed in dist/.
5. *medium* -- the menu's comment on input order was backwards: `_input`
   runs in reverse tree order and the example is added after the menu, so
   an example's `_input` sees Escape first -- which is why the planted
   "eats Escape" example failed. Moving the menu's handler to
   `_unhandled_input` survived.
6. *medium* -- the walk held less than its header: it never pressed an
   example's own keys (missing 1 and 2); the engine-error rule had no
   planted case (it does work); the menu left visible while playing, and
   focus not restored on return, both survived; leaks by node count only.
7. *low* -- C8 is a regex for `quit(`; `get_tree().call("quit")` survived;
   addons are skipped with no reason given.
8. *low* -- `ExampleCatalogue.problem` is never shown by the menu.
9. *low* -- the layout is fixed at the size read in `_ready`, and there is
   no stretch mode: a maximised window shows the menu small in a corner
   (from reading the code).
10. *low* -- stealth.md: "a cell in shade counts as further off than it
    is" is wrong; `VisionCone.sees` ignores light, which enters only as the
    fuzzy controller's input. The rest of both pages checked out against
    the code and the measurements.
11. *low* -- the `BUILD` stamp is not bound to the bytes: a `.pck`
    rewritten after `make export` ships under a clean-HEAD stamp.
12. *low* -- the executable's cards say "Read more: docs/... or make
    demo-x", neither of which someone with only the zip has. The zip's
    NOTICE points at `godot/assets/LICENCES.md`, which does not ship, and
    says every picture outside the generated examples is Kenney's, while
    LICENCES.md lists other CC0 sources; older than this wave, and this is
    the first wave to ship the pictures in a binary.
13. *nit* -- Python lines past 120 characters; `project_classes` computed
    per technique and each closure twice per scene.

Mutations rejected (11): `back()` not freeing, `open()` leaving the menu
current, `back()` leaving the example current, a typed-array error and a
`push_error` in `step_decision`; five false cross-scene claims and a `"""`
string. Survived (10): C7 through a constant, a type annotation, a `'''`
string; C8 by `call("quit")`; the export missing the weights; the menu
visible while playing; focus not restored; Escape in `_unhandled_input`;
and the two defects of findings 1 and 2, found by probe.

## What was done about it

- 1: whether an example is playing is read off the tree (`is_playing()`:
  the current scene is not the menu), never a kept reference. The walk
  reloads every example's scene, as R does, before pressing Escape.
- 2: the tactical board rolls fresh dice when it sits at the top of the
  tree -- its parent is the root -- which is true at `_ready` both alone and
  from the menu, and false under every test that mounts it in its own node.
  The walk opens it twice from the menu and refuses two equal seeds.
- 3: C7 no longer counts a class named only as a type, or only to read one
  of its constants, and `'''` strings are stripped like `"""` ones; each has
  a planted case, and the reviewer's behaviour -> influence map and
  tic-tac-toe -> minimax claims are both refused. The docstring and the
  catalogue's `about` now say what it holds: reachable by use, not "runs".
  The closure is worked out once per run.
- 4: the pack must hold every scene a card opens and every JSON committed
  under godot/ outside the tests; the reviewer's export without the beads
  and the weights is refused. Any `ERROR` line refuses the start, and a
  refused build is deleted. Opening each example inside the build is not
  possible -- the release template refuses a scene path -- and the module
  says so.
- 5: the menu keeps itself the root's last child while an example plays,
  so its `_input` runs first, and a reload is followed. The planted example
  that takes Escape in its own `_input` must now be left; moving the menu's
  handler to `_unhandled_input` turns the walk red.
- 6: the walk checks the menu is hidden while playing and holds the
  keyboard on return, and has planted cases for an engine error and for
  being at the top of the tree when ready. Planted again, each of: the
  kept reference, the current-scene dice rule, `_unhandled_input`, and no
  `grab_focus()` turned it red.
- 7: C8 reads strings too, so `call("quit")` is caught, and reads every
  script an example reaches, addons included, with the reason written.
- 8: an unreadable catalogue's problem is shown in the card.
- 10: stealth.md now says light changes the worry, not the sight.
- 11: `BUILD` records the SHA-256 of the binary and the pack, and
  `release.py` refuses files that no longer match; a planted changed pack
  is refused in its self-test.
- 12: a card's "read more" now says it is in the kit's repository.
- 13: the longest new lines were split; the rest pass the gate.

Not done, for the owner: **9**, a stretch mode, is a project-wide setting
that rescales every example, not only the menu -- the owner's call, with
the manual check. **12's NOTICE** -- the zip carries a NOTICE that names
only Kenney and points at a file that does not ship -- predates this wave
and is the owner's wording to change. The fixes were not reviewed again.
