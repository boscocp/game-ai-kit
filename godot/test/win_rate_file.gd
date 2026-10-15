## Writes the win rates `clone_fights.gd` measured, and nothing else (T18).
##
## Apart from the script that fights because that script seats T17's learner,
## and a script holding a learner writes no file at all (ADR 0016, N9 in
## `check_no_training.py`). This one is handed numbers, never an opponent, so
## no table can reach it.
class_name WinRateFile
extends RefCounted


## Write `wins` -- mode to fights won of `fights` -- measured with the cloned
## player whose file hashes to `weights`, to `path`. False if it could not.
static func write(path: String, weights: String, fights: int, wins: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"weights_sha256": weights, "opponent": "medium", "fights": fights,
			"wins": wins}, " ") + "\n")
	return true
