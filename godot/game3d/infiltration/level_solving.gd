## A level solved off the main thread (T122): `LevelConstraints.solve` run
## as one `WorkerThreadPool` task, so the window keeps drawing while the
## solver works -- 120-140 ms a level, 2.2-2.5 s on seed 144, measured.
##
## The solver touches no scene and shares nothing: it reads two JSON files
## and builds its own objects, so the level it makes on a worker is the one
## it makes inline, cell for cell. The main thread asks `poll` each frame
## and reads the result only once the task is done and waited for -- the
## pool's documentation says every task must be waited for, to free it.
##
## Complexity: the solve's own; a poll is constant time.
##
## When not to use it: in a test, or anywhere the level is needed in the
## same frame. `LevelConstraints.solve` is still the synchronous call.
class_name LevelSolving
extends RefCounted

## The seed being solved, or -1 while nothing is.
var seed_value: int = -1
var _task: int = -1
var _result: LevelConstraints


## Start solving `from_seed` on the pool, the solver's steps recorded for
## the generation view. One solve at a time: while one runs this does
## nothing, since a task cannot be stopped -- the caller asks again when
## `poll` hands the first one back.
func start(from_seed: int) -> void:
	if busy():
		return
	seed_value = from_seed
	_result = null
	_task = WorkerThreadPool.add_task(_solve.bind(from_seed), false, "infiltration level %d" % from_seed)  # not shown: the pool's debugging label


## Whether a solve is running.
func busy() -> bool:
	return _task != -1


## The level, once the solve has finished; null while it runs or when none
## was started. Never blocks.
func poll() -> LevelConstraints:
	if not busy() or not WorkerThreadPool.is_task_completed(_task):
		return null
	return wait()


## The level, waiting for the solve to finish: for a test, and for the scene
## leaving the tree with a task still running. Null when none was started.
func wait() -> LevelConstraints:
	if not busy():
		return null
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	seed_value = -1
	var found: LevelConstraints = _result
	_result = null
	return found


# On a worker thread. The only thing written that the main thread reads is
# `_result`, and the main thread reads it only after the task is waited for.
func _solve(from_seed: int) -> void:
	_result = LevelConstraints.solve(from_seed, true)
