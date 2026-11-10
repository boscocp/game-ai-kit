# A cold import crashes on several threads, and not on one

<!-- doc-meta
half_life: practice
verified_on: 2026-11-10
tier: 1
source: https://github.com/godotengine/godot/issues/125245 ; https://docs.godotengine.org/en/stable/classes/class_projectsettings.html ; https://github.com/godotengine/godot/blob/4.7.2-stable/editor/file_system/editor_file_system.cpp
invalidated_if: the pin moves past 4.7.2, or #125245 is fixed
teaches: none
-->

> What T148 measured after `--import` on a cold cache crashed three times
> in reviews (waves 140, 142 and 147), each time passing on a rerun. Read
> in the documentation and the issue tracker first, then measured on 4.7.2.

## What the documentation and the tracker say

`editor/import/use_multiple_threads` is a project setting, `true` by
default: the import runs the files of one importer as a group of tasks on
the worker thread pool. The 4.7.2 source reads it with `GLOBAL_GET` in
`EditorFileSystem::reimport_files`, so it lives in `project.godot`, not in
the editor's own settings.

[godotengine/godot#125245](https://github.com/godotengine/godot/issues/125245),
open and filed on 2026-11-08 against 4.7.2, reports a crash with the same
symptom and the same workaround: in a C# project, a fresh `--headless
--import` exits 139 or 134 with the setting on (1 SIGSEGV in 27 runs), and
none in 54 with it off. It is not shown to be the same race. That project
has no CSV tables, and its core dumps put the fault on the main thread,
where this project's 139 is on a worker. A contributor asked for a minimal
reproduction tested on master or 4.8 beta 2. Whether to offer this
repository as one is the owner's decision. No fix was linked
on 2026-11-10. Older reports of a crash after a headless import (#123622,
#125063, both 4.7) were closed unresolved.

## What was measured

A copy of `godot/` from `git archive` plus the gdUnit4 addon, with no
`.godot/` -- what a new worktree has -- imported with
`./scripts/godot --headless --path <copy> --import`, a fresh copy each run,
on a 12-thread Linux machine:

| `use_multiple_threads` | runs | exit 139 | exit 134 | conditions |
|---|---|---|---|---|
| `true` (default) | 40 | 3 | 5 | `--verbose`, nothing else running |
| `true` | 50 | 1 | 0 | no `--verbose`, load 2-4 |
| `true` | 25 | 2 | 0 | `--verbose`, beside two other worktrees' `make check` |
| `false` | 60 | 0 | 0 | `--verbose`, nothing else running |
| `false` | 50 | 0 | 0 | no `--verbose`, interleaved with the 50 above |
| `false` | 50 | 0 | 0 | `--verbose`, two at once, beside the same two `make check` |

So 11 crashes in 115 runs with threads, none in 160 without (Fisher's
exact test, two-sided, p about 1e-4). The rate is not one number. It went
from 1 in 50 to 1 in 5 across the rows, and the review of wave 167, on the
same machine, saw none in 30 runs with the setting on, `--verbose`, load
3-4. `--verbose`
prints more from the worker threads and crashes more often, which is what
a race looks like.

**The signal 11** is on a worker thread, while the CSV translation tables
reimport as one threaded group (`res://locale/*.csv`, twenty of them).
Just before it the engine prints:

```text
ERROR: /root: The caller thread can't call the function `propagate_notification()` on this node. Use `call_deferred()` or `call_deferred_thread_group()` instead.
   at: propagate_notification (scene/main/node.cpp:2578)
handle_crash: Program crashed with signal 11
```

`project.godot` lists every `.pt_BR.translation`, so they are loaded when
the editor starts; a reimport that replaces one notifies the scene tree of
a changed translation, from the worker that imported it. The official
build has no symbols, so the frames are addresses only; that reading of
them is an inference, not a symbolised backtrace.

**The exit 134** is the main thread faulting after `EditorSettings: Save
OK!`, during shutdown, with nothing printed; the core dump shows the
crash handler calling `abort()` from inside the fault. It went away with
the setting too.

A cold import with one thread took 3.2 s against 2.3 s with several.
A warm one imports nothing and costs the same either way.

## What this project does about it

`project.godot` sets `import/use_multiple_threads=false` in `[editor]`, and
`make lint-import-threads` (`scripts/check_import_threads.py`) fails when
the line is missing, `true`, or in another section. The task's fallback, a
retry on exit 139, was not needed: the cause was a setting this project
can turn, and a retry would have hidden the 134s, which are not 139.

Take the line out when the pin moves to a release that fixes #125245, and
only after a loop of cold imports, as above, because a single green run
proves nothing about a crash this intermittent. First show that the loop
can still see the crash: run it at 4.7.2, with the setting on and
`--verbose`, until it crashes. A loop that shows nothing on the new pin
could mean a quiet machine, not a fix, unless it has caught the crash on
the old pin.
