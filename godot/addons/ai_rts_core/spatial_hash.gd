## Who is near a point, without asking everybody.
##
## Looking a unit up by walking the whole unit list for every question is
## O(n) a lookup; an RTS asks thousands a frame -- every soldier looking for
## the nearest enemy, every command checking a cell is free. Here the plane is
## cut into square buckets and each id is filed under the bucket its position
## falls in, so a question about a circle only reads the buckets the circle
## touches: about (2r / bucket + 1)² of them, whatever the army's size.
##
## Answers come back sorted by id. Two runs of one match must agree on every
## tie, and "whichever was filed first" is not a rule anybody can read.
##
## When not to use it: units of wildly different sizes, or a world where most
## questions cover most of the map. Then a quadtree, or a plain scan.
class_name SpatialHash
extends RefCounted

## The side of a bucket, in the same units as positions (cells, here). About
## the radius most questions ask: smaller, and a question reads many buckets;
## larger, and each bucket holds many ids the question then turns away.
var bucket_size: float

# Bucket -> the ids filed in it, and id -> where it was filed.
var _buckets: Dictionary = {}
var _positions: Dictionary = {}

## How many ids questions have looked at since this hash was made: the
## work this structure saves is the difference from n per question.
var looked_at: int = 0


func _init(size: float = 4.0) -> void:
	bucket_size = size


## File `id` at `position`, moving it from wherever it was filed before.
func place(id: int, position: Vector2) -> void:
	if _positions.has(id):
		var old: Vector2i = _bucket_of(_positions[id])
		var new: Vector2i = _bucket_of(position)
		_positions[id] = position
		if old == new:
			return
		_unfile(id, old)
	_positions[id] = position
	var bucket: Vector2i = _bucket_of(position)
	if not _buckets.has(bucket):
		_buckets[bucket] = []
	(_buckets[bucket] as Array).append(id)


## Forget `id`. Forgetting one never filed is not an error.
func remove(id: int) -> void:
	if _positions.has(id):
		_unfile(id, _bucket_of(_positions[id]))
		_positions.erase(id)


## Every id within `radius` of `centre`, edge included, sorted by id.
func near(centre: Vector2, radius: float) -> Array[int]:
	var found: Array[int] = []
	var low: Vector2i = _bucket_of(centre - Vector2(radius, radius))
	var high: Vector2i = _bucket_of(centre + Vector2(radius, radius))
	for row: int in range(low.y, high.y + 1):
		for column: int in range(low.x, high.x + 1):
			found.append_array(_within(Vector2i(column, row), centre, radius))
	found.sort()
	return found


## How many ids are filed.
func size() -> int:
	return _positions.size()


func _within(bucket: Vector2i, centre: Vector2, radius: float) -> Array[int]:
	var found: Array[int] = []
	for id: int in _buckets.get(bucket, []):
		looked_at += 1
		if (_positions[id] as Vector2).distance_to(centre) <= radius:
			found.append(id)
	return found


func _unfile(id: int, bucket: Vector2i) -> void:
	var filed: Array = _buckets[bucket]
	filed.erase(id)
	if filed.is_empty():
		_buckets.erase(bucket)


func _bucket_of(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / bucket_size), floori(position.y / bucket_size))
