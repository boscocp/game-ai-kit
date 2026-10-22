## The effects gate's matches split across several Godot processes, and put
## back together in the order one process would have played them (T72).
##
## Each match is a function of its pairing and its seed, with its own random
## generator, so the matches are independent: N processes can each play a
## share and write down each match's own counts, and one more process can
## read them back and add them up. It adds them one match at a time, in
## seed order, so every float sum is the same sum the serial run makes, bit
## for bit, and the claims are asked of the same numbers.
##
## Three modes, from the command line after `--`:
##
##   * none: serial, as before -- every match is played here;
##   * `--shard K/N --out DIR`: play the matches whose place in the gate's
##     own order is K modulo N, and write their counts to DIR;
##   * `--merge DIR`: play nothing, read every shard's counts instead.
##
## The job list is the gate's own: a shard walks the same pairings and seeds
## and skips the ones that are not its share, so nothing here repeats which
## matches there are. Constant time a match, but for the copies.
##
## When not to use it: matches that read each other's state -- a shared
## cache, a global random generator. Then the shards would not play what the
## serial run plays, and only the bit-for-bit comparison would show it.
class_name EffectShards
extends RefCounted

enum Mode { SERIAL, SHARD, MERGE }

var mode: Mode = Mode.SERIAL
var shard: int = 0
var count: int = 1
var folder: String = ""
## What went wrong putting the shards together, for the gate's failures.
var problems: Array[String] = []
var _job: int = 0
## The counts of each match, by `"pairing|seed"`: kept in a shard, read
## back in a merge.
var _records: Dictionary = {}
var _used: int = 0


## The mode the gate's command line asks for; serial when it names none.
## A malformed `--shard` becomes a problem, so the run fails rather than
## silently playing everything.
static func from_arguments(arguments: PackedStringArray) -> EffectShards:
	var shards := EffectShards.new()
	var at: int = arguments.find("--shard")
	if at != -1 and at + 1 < arguments.size():
		shards.mode = Mode.SHARD
		var parts: PackedStringArray = arguments[at + 1].split("/")
		shards.shard = int(parts[0])
		shards.count = int(parts[1]) if parts.size() == 2 else 0
		shards.folder = _value_after(arguments, "--out")
		if shards.count < 1 or shards.shard < 0 or shards.shard >= shards.count or shards.folder == "":
			shards.problems.append("shards: '--shard %s --out %s' is not K/N with 0 <= K < N and a folder" % [arguments[at + 1], shards.folder])
	elif arguments.has("--merge"):
		shards.mode = Mode.MERGE
		shards.folder = _value_after(arguments, "--merge")
		shards.read_folder()
	return shards


static func _value_after(arguments: PackedStringArray, flag: String) -> String:
	var at: int = arguments.find(flag)
	return arguments[at + 1] if at != -1 and at + 1 < arguments.size() else ""


## Whether this process plays the match `seed_value` of `pairing`. Every
## match of the gate passes here in the gate's order, so a shard counts its
## place: the same order in every shard, so each match is one shard's.
func plays(pairing: String, seed_value: int) -> bool:
	if mode == Mode.MERGE:
		return false
	var place: int = _job
	_job += 1
	return mode == Mode.SERIAL or place % count == shard


## Where one match's counts go: the pairing's own sums when serial; in a
## shard, a fresh copy of the empty sums, so each match is kept alone.
func sums_for(sums: Dictionary) -> Dictionary:
	return sums if mode == Mode.SERIAL else sums.duplicate(true)


## In a shard, keep one match's counts to write; otherwise nothing.
func keep(pairing: String, seed_value: int, match_sums: Dictionary) -> void:
	if mode == Mode.SHARD:
		_records[_key(pairing, seed_value)] = match_sums


## In a merge, add the counts a shard kept for this match to `sums`; a
## match no shard kept is a problem, never a silent zero.
func merge_into(sums: Dictionary, pairing: String, seed_value: int) -> void:
	var key: String = _key(pairing, seed_value)
	if not _records.has(key):
		problems.append("shards: no shard played '%s', seed %d" % [pairing, seed_value])
		return
	add(sums, _records[key])
	_used += 1


## `record` added into `sums` key by key: numbers summed, arrays of margins
## appended. Starting from the same empty sums, adding the matches in seed
## order makes the same floats the serial run makes.
static func add(sums: Dictionary, record: Dictionary) -> void:
	for key: String in record:
		if record[key] is PackedFloat64Array:
			var values: PackedFloat64Array = sums[key]
			values.append_array(record[key])
			sums[key] = values
		else:
			sums[key] += record[key]


## The problems, and in a merge any match a shard played that the gate never
## asked for -- a shard that ran another gate's list.
func findings() -> Array[String]:
	var found: Array[String] = problems.duplicate()
	if mode == Mode.MERGE and _used != _records.size():
		found.append("shards: %d match(es) played that the gate did not ask for" % (_records.size() - _used))
	return found


## Write this shard's matches to `folder`; the exit code for the shard: 0
## written, 1 a problem or no match played (a shard that found nothing must
## not pass), 2 the file could not be written.
func write() -> int:
	if not problems.is_empty() or _records.is_empty():
		for problem: String in problems:
			printerr(problem)
		if _records.is_empty():
			printerr("shards: shard %d of %d played no match" % [shard, count])
		return 1
	var file := FileAccess.open(folder.path_join("shard-%d.bin" % shard), FileAccess.WRITE)
	if file == null:
		printerr("shards: cannot write to %s: %s" % [folder, error_string(FileAccess.get_open_error())])
		return 2
	file.store_var({"shard": shard, "of": count, "records": _records})
	return 0


## Read every `shard-K.bin` in `folder`: all N of them, of one N, each with
## at least one match. Anything else is a problem.
func read_folder() -> void:
	var names: PackedStringArray = DirAccess.get_files_at(folder)
	var seen: Dictionary = {}
	var of: int = -1
	for name: String in names:
		if not (name.begins_with("shard-") and name.ends_with(".bin")):
			continue
		# `store_var` writes a length before the value, so it is read back with
		# `get_var`, not `bytes_to_var` on the file's bytes.
		var file := FileAccess.open(folder.path_join(name), FileAccess.READ)
		var data: Variant = file.get_var() if file != null else null
		if not data is Dictionary or not (data as Dictionary).has("records"):
			problems.append("shards: %s is not a shard's counts" % name)
			continue
		of = data["of"] if of == -1 else of
		_read_one(name, data, of, seen)
	if seen.size() != of or of < 1:
		problems.append("shards: %d shard file(s) in %s, expected %d" % [seen.size(), folder, of])


func _read_one(name: String, data: Dictionary, of: int, seen: Dictionary) -> void:
	if data["of"] != of:
		problems.append("shards: %s is one of %d shards, the others of %d" % [name, data["of"], of])
	if (data["records"] as Dictionary).is_empty():
		problems.append("shards: %s played no match" % name)
	seen[data["shard"]] = true
	_records.merge(data["records"])


static func _key(pairing: String, seed_value: int) -> String:
	return "%s|%d" % [pairing, seed_value]
