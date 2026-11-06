## What the XCOM-style mode says about its map (T96): the first line of the
## status, and the map build's part of the decision overlay.
##
## The line says where the map came from -- the tactical map, or a seed of
## wave function collapse with its contradictions and the maps the rules
## refused -- and, while B shows a build, what this step is: the cell about
## to collapse with its tiles left and its entropy, or the contradiction
## that ended a seed. The overlay says the same in English, as every reason
## in it is (T104), for `test/menu/demo_overlays.gd` to read.
##
## When not to use it: to decide anything about the map. This only words
## `SquadMapBuild`'s answers.
class_name SquadMapWords
extends RefCounted


## The status's first line about the map, in the language on screen.
static func line(rules: SquadRuleset) -> String:
	var build: SquadMapBuild = rules.map_build
	if build != null and rules.watching_the_build:
		return _step(build)
	if build == null:
		return TranslationServer.translate("map: the tactical one -- N builds a new one by wave function collapse, B a cell at a time")
	if build.rows.is_empty():
		return TranslationServer.translate("no map from seed {first} to {last}: the last one stays -- N tries the next seeds").format({
			first = build.first_seed, last = build.last_seed()})
	return TranslationServer.translate("map: seed {seed}, by wave function collapse -- {contradictions} contradiction(s), {refused} refused as unplayable -- N a new one, B a cell at a time").format({
		seed = build.seed_used, contradictions = build.contradictions.size(), refused = build.unplayable.size()})


# The step B is showing.
static func _step(build: SquadMapBuild) -> String:
	var seed_shown: int = int(build.shown().get("seed", build.first_seed))
	if build.stuck() != Vector2i(-1, -1):
		return TranslationServer.translate("seed {seed}: a contradiction at {cell}, where no tile fits -- B starts again from seed {next}").format({
			seed = seed_shown, cell = _cell(build.stuck()), next = seed_shown + 1})
	if build.choosing() != Vector2i(-1, -1):
		return TranslationServer.translate("building, seed {seed}: next {cell}, {left} tile(s) left, entropy {entropy} -- B collapses it, N finishes the map").format({
			seed = seed_shown, cell = _cell(build.choosing()), left = build.tiles_left(build.choosing()).size(),
			entropy = "%.2f" % build.choosing_entropy()})
	if build.shown().get("outcome", "") == "refused":
		return TranslationServer.translate("seed {seed}: built, but the rules cannot play it -- B tries seed {next}").format({
			seed = seed_shown, next = seed_shown + 1})
	return TranslationServer.translate("building, seed {seed}").format({seed = seed_shown})


## The build as the overlay keeps it, in English: the seed shown and what
## became of it, the open cells, the cell about to collapse with its
## entropy, and where a contradiction emptied a cell.
static func overlay(build: SquadMapBuild) -> Dictionary:
	var kept: Dictionary = {"seed": build.shown().get("seed", build.first_seed), "outcome": build.shown().get("outcome", ""),
			"open cells": build.counts().size()}
	if build.choosing() != Vector2i(-1, -1):
		kept["next cell"] = build.choosing()
		kept["entropy"] = snappedf(build.choosing_entropy(), 0.001)
	if build.stuck() != Vector2i(-1, -1):
		kept["contradiction"] = build.stuck()
	if build.shown().get("outcome", "") == "refused":
		kept["refused"] = build.shown()["why"]
	return kept


static func _cell(cell: Vector2i) -> String:
	return "(%d, %d)" % [cell.x, cell.y]
