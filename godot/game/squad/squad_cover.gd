## The cover a target has against one shooter, read from the terrain beside
## it -- and whether that shooter flanked it.
##
## XCOM's rules, as UFOpaedia states them for Enemy Unknown (2012): half
## cover "conveys a -20% hit chance penalty", full cover -40%; "cover only
## grants a defence bonus if a unit is standing directly next to it", and from
## a flanking position "there will be no cover defence bonus applied". On
## the tactical map rock is full cover and trees half; nothing new is drawn.
##
## A cell of cover one step `d` from the target protects it against a shooter
## on that side: one whose offset from the target has a positive part along
## `d`. A shooter level with the cover, or behind it, is not stopped by it.
## The best cover facing the shooter counts. A target with cover beside it
## and none facing the shooter is **flanked**; one in the open is simply
## uncovered. The same function as Python's `gameaikit.squad.shot.cover_of`,
## line for line, and the vectors in `spec/vectors/squad/` hold the two.
##
## When not to use it: cover that is part of a wall, or higher ground. XCOM
## has both; this map has neither, and the rule says only what the map can.
class_name SquadCover
extends RefCounted


## `{"cover": 0, 20 or 40, "flanked": bool}` for a target on `target`
## against a shooter on `shooter`, on the map written in `rows`.
static func of(rows: Array[String], shooter: Vector2i, target: Vector2i) -> Dictionary:
	var best: int = 0
	var beside_any: bool = false
	for step: Vector2i in GakGridGraph.DIRECTIONS:
		var worth: int = worth_at(rows, target + step)
		if worth == 0:
			continue
		beside_any = true
		var facing: int = (shooter - target).x * step.x + (shooter - target).y * step.y
		if facing > 0:
			best = maxi(best, worth)
	return {"cover": best, "flanked": beside_any and best == 0}


## What standing next to `cell` is worth as cover: full for rock, half for
## trees, nothing for anything else or for a cell off the map.
static func worth_at(rows: Array[String], cell: Vector2i) -> int:
	if cell.y < 0 or cell.y >= rows.size() or cell.x < 0 or cell.x >= rows[cell.y].length():
		return 0
	match rows[cell.y][cell.x]:
		SquadSight.ROCK:
			return SquadTable.cover_worth("full")
		SquadSight.TREES:
			return SquadTable.cover_worth("half")
	return 0
