# The effects gate's shards, without a match played: that every match is
# one shard's, that the merge adds the counts back to the serial sums bit
# for bit, and that a merge with a match missing, a match too many, or a
# shard that played nothing is refused rather than passed (T72).
extends GdUnitTestSuite

## Margins with long binary fractions: added in a different order, these
## sum to a different float, so an order slip would show.
const MARGINS: Array[float] = [118.10000000002682, -85.10000000001932, 183.6000000000384, 0.1, 0.2, 0.3]
const SHARDS: int = 4


func test_every_match_is_exactly_one_shards() -> void:
	var played: Array[int] = []
	for shard: int in range(SHARDS):
		played.append_array(_share(_shard(shard, SHARDS)))
	played.sort()
	assert_array(played).is_equal([1, 2, 3, 4, 5, 6])


func test_the_merge_adds_back_the_serial_sums_bit_for_bit() -> void:
	var serial: Dictionary = _empty()
	for margin: float in MARGINS:
		EffectShards.add(serial, _one_match(margin))
	var merged: Dictionary = _merge(_write_shards(SHARDS)).sums
	assert_float(merged["held"]).is_equal(serial["held"])
	assert_bool(merged["held"] == serial["held"]).is_true()
	assert_array(Array(merged["margins"])).is_equal(Array(serial["margins"]))
	assert_int(merged["deaths"]).is_equal(MARGINS.size())


func test_a_merge_missing_a_match_is_refused() -> void:
	var folder: String = _write_shards(SHARDS)
	var merge: Dictionary = _merge(folder, MARGINS.size() + 1)
	assert_str("\n".join(merge.findings)).contains("no shard played 'everything', seed %d" % (MARGINS.size() + 1))


func test_a_merge_with_a_match_nobody_asked_for_is_refused() -> void:
	var merge: Dictionary = _merge(_write_shards(SHARDS), MARGINS.size() - 1)
	assert_str("\n".join(merge.findings)).contains("1 match(es) played that the gate did not ask for")


func test_a_shard_that_played_nothing_is_refused() -> void:
	var shards: EffectShards = _shard(0, 2)
	shards.folder = _folder()
	assert_int(shards.write()).is_equal(1)


func test_a_malformed_shard_argument_is_a_problem() -> void:
	var shards := EffectShards.from_arguments(PackedStringArray(["--shard", "3/3", "--out", "/tmp"]))
	assert_array(shards.problems).is_not_empty()


# The seeds of MARGINS' matches that `shards` plays, asked in the gate's order.
static func _share(shards: EffectShards) -> Array[int]:
	var mine: Array[int] = []
	for seed_value: int in range(1, MARGINS.size() + 1):
		if shards.plays("everything", seed_value):
			mine.append(seed_value)
	return mine


func _shard(shard: int, count: int) -> EffectShards:
	return EffectShards.from_arguments(PackedStringArray(["--shard", "%d/%d" % [shard, count], "--out", "unset"]))


# Each shard plays its share of MARGINS as matches of "everything", and
# writes them; the folder they were written to.
func _write_shards(count: int) -> String:
	var folder: String = _folder()
	for shard: int in range(count):
		var shards: EffectShards = _shard(shard, count)
		shards.folder = folder
		for seed_value: int in _share(shards):
			var into: Dictionary = shards.sums_for(_empty())
			EffectShards.add(into, _one_match(MARGINS[seed_value - 1]))
			shards.keep("everything", seed_value, into)
		assert_int(shards.write()).is_equal(0)
	return folder


# The gate's merge of `folder` over `matches` seeds of "everything".
func _merge(folder: String, matches: int = MARGINS.size()) -> Dictionary:
	var shards := EffectShards.from_arguments(PackedStringArray(["--merge", folder]))
	var sums: Dictionary = _empty()
	for seed_value: int in range(1, matches + 1):
		shards.merge_into(sums, "everything", seed_value)
	return {"sums": sums, "findings": shards.findings()}


func _folder() -> String:
	var folder: String = create_temp_dir("effect_shards_%d" % Time.get_ticks_usec())
	return folder


static func _empty() -> Dictionary:
	return {"held": 0.0, "deaths": 0, "margins": PackedFloat64Array()}


static func _one_match(margin: float) -> Dictionary:
	return {"held": margin, "deaths": 1, "margins": PackedFloat64Array([margin])}
