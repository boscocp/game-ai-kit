# Work off the main thread: WorkerThreadPool

<!-- doc-meta
half_life: practice
verified_on: 2026-11-05
tier: 1
source: https://docs.godotengine.org/en/4.7/classes/class_workerthreadpool.html ; https://docs.godotengine.org/en/4.7/tutorials/performance/thread_safe_apis.html
invalidated_if: WorkerThreadPool's add_task, is_task_completed or wait_for_task_completion change, or the thread-safe APIs page changes what it says of containers, the scene tree or resources
teaches: none
-->

> What T122 had to know before the infiltration's level solver could run
> beside the game. Read in the documentation for 4.7 first, then measured
> on 4.7.2.

## What the documentation says

`WorkerThreadPool`'s page:

- `add_task(action: Callable, high_priority := false, description := "")`
  runs the Callable once on a worker thread and answers a task ID.
- `is_task_completed(task_id)` says whether it is done. It is meant to be
  called between adding the task and waiting for it.
- `wait_for_task_completion(task_id)` blocks the calling thread until the
  task ends. It answers `OK`; `ERR_INVALID_PARAMETER` for an ID that
  does not exist, for example one already waited for; or `ERR_BUSY` when
  called from inside another task where waiting could deadlock, such as a
  task waiting on an older one.
- **Every task must be waited for** at some point, by
  `wait_for_task_completion` or its group form, so that what the pool
  allocated for it is freed. Being completed is not enough.

The thread-safe APIs page:

- The active scene tree is **not** thread-safe. A thread may build nodes
  outside it and hand them over, or use `call_deferred`.
- An Array or Dictionary may be read and written from several threads
  element by element. Anything that changes its size needs a mutex.
- Resources may be loaded on a thread. One resource modified from several
  threads is not supported.

## What was measured

On 4.7.2, headless, with `godot/test/infiltration/level_solving_measure.gd`
and `level_solving_test.gd`:

- A task added from the main thread, polled each physics frame with
  `is_task_completed`, then waited for, gives back what it built. The
  wait costs nothing visible once the task is done.
- `LevelConstraints.solve` makes the same level on a worker as inline,
  cell for cell and step for step. Seeds 3, 54 and 144 were compared on
  their data, assignment, counts and trace.
- The longest frame while seed 144 solves on the pool was 21 ms. The same
  solve inline froze one frame for 2281 ms.

## What it means here

- **Give the task something that shares nothing.** The level solver reads
  two JSON files and builds only its own objects: no node, no singleton
  written, no static state. So the worker needs no lock. The one value
  both threads touch is the result. The worker writes it, and the main
  thread reads it only after the wait.
- **Poll, then wait.** `is_task_completed` keeps the frame from blocking.
  The wait that follows frees the task and makes the result safe to read.
  A scene leaving the tree with a task still running waits for it in
  `_exit_tree`, since a task never waited for is never freed -- so the
  stall moves to leaving the scene, for whatever is left of the solve.
- **A task cannot be stopped.** The pool has no cancel. `LevelSolving`
  runs one solve at a time and ignores a second start. The scene asks
  again when the first ends.
- **Keep a synchronous path for tests.** A seeded test that waits on a
  thread waits on the machine's load. The scene solves inline when the
  display server is `headless`, and `LevelConstraints.solve` is still the
  call a test makes.
