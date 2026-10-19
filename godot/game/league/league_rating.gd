## A rating from a table of results, with its uncertainty -- because a rating
## with no error bar ranks noise (T25).
##
## **The method** is the Bradley-Terry model: each team has a strength, and
## the chance that one beats another is its strength over the two added up.
## It is fitted by the minorise-maximise iteration in Hunter, "MM algorithms
## for generalized Bradley-Terry models", Annals of Statistics 32(1),
## 384-406, 2004 (doi:10.1214/aos/1079120141 -- its details checked through
## Crossref; the page holding the text would not load, so nothing here quotes
## it). The update climbs to the most likely strengths with no step size to
## tune: a team's new strength is its score over its games weighted by
## how strong each opponent is against it.
## Two choices of this kit's, said as choices:
##
## - **A draw is half a win to each side**, as chess scores it. The richer
##   models of draws (Rao-Kupper, Davidson) add a parameter a league this small
##   cannot pin down.
## - **Every pairing starts with one imaginary draw.** A team that won every
##   game has no finite most-likely strength -- the fit runs off to infinity --
##   and a league of a few games a pairing has such teams. One draw each is a
##   small, said, prior that keeps them on the scale and pulls every rating a
##   little towards the middle.
##
## The strengths are shown on the Elo scale -- 400 points is ten to one --
## with the first team at 0, so a rating reads "this much better than the
## rules". **The uncertainty** is a bootstrap: the games are drawn again with
## replacement, `RESAMPLES` times from a fixed seed, each draw fitted, and the
## middle 95% of each team's ratings is its interval. Each interval is a
## difference *from the first team*, so it says one thing: an interval clear
## of 0 is a team told apart from the first. Whether two other teams differ
## is not read off whether their intervals overlap -- that mixes in the
## first team's own uncertainty, and overlapping intervals are not a test --
## and this league does not claim it.
##
## Complexity: one fit is O(iterations x teams^2); the bootstrap repeats it
## `RESAMPLES` times over a resampled table, O(games) to build.
##
## When not to use it: to rank teams that never met. Bradley-Terry ranks
## through common opponents; the league plays every pairing, so here it can.
class_name LeagueRating
extends RefCounted

const ITERATIONS: int = 200
const RESAMPLES: int = 200
## The bootstrap's own seed: the same table always gives the same interval.
const BOOTSTRAP_SEED: int = 25
## Elo's scale: 400 points between two teams is odds of ten to one.
const ELO_SCALE: float = 400.0
## The imaginary draw each pairing starts with, as a score to each side.
const PRIOR_DRAWS: float = 1.0


## Each team's rating on the Elo scale, the first team at 0, from `games`:
## [red index, blue index, score to red] -- 1 a red win, 0.5 a draw, 0 a loss.
static func fit(games: Array[Array], teams: int) -> Array[float]:
	var won: Array[Array] = _scores(games, teams)
	var strength: Array[float] = []
	strength.resize(teams)
	strength.fill(1.0)
	for _round: int in range(ITERATIONS):
		strength = _one_step(won, strength)
	var ratings: Array[float] = []
	for team: int in range(teams):
		ratings.append(ELO_SCALE * log(strength[team] / strength[0]) / log(10.0))
	return ratings


## Each team's 95% interval as [low, high], by bootstrap over `games`.
static func intervals(games: Array[Array], teams: int) -> Array[Array]:
	var draws := RandomNumberGenerator.new()
	draws.seed = BOOTSTRAP_SEED
	var samples: Array[Array] = []
	for _team: int in range(teams):
		samples.append([])
	for _resample: int in range(RESAMPLES):
		var drawn: Array[Array] = []
		for _game: int in range(games.size()):
			drawn.append(games[draws.randi_range(0, games.size() - 1)])
		var ratings: Array[float] = fit(drawn, teams)
		for team: int in range(teams):
			samples[team].append(ratings[team])
	var found: Array[Array] = []
	for team: int in range(teams):
		var sorted: Array = samples[team].duplicate()
		sorted.sort()
		found.append([sorted[int(0.025 * RESAMPLES)], sorted[int(0.975 * RESAMPLES) - 1]])
	return found


# won[one][other]: what `one` scored against `other`, the prior draw included.
static func _scores(games: Array[Array], teams: int) -> Array[Array]:
	var won: Array[Array] = []
	for one: int in range(teams):
		var row: Array[float] = []
		for other: int in range(teams):
			row.append(0.0 if one == other else PRIOR_DRAWS / 2.0)
		won.append(row)
	for game: Array in games:
		won[game[0]][game[1]] += game[2]
		won[game[1]][game[0]] += 1.0 - game[2]
	return won


# Hunter's update: a team's new strength is what it scored, over the games
# it played weighted by how strong each opponent was against it; then the
# strengths are scaled to add up to the number of teams, which changes no
# chance and keeps the numbers in range.
static func _one_step(won: Array[Array], strength: Array[float]) -> Array[float]:
	var teams: int = strength.size()
	var next: Array[float] = []
	var total: float = 0.0
	for one: int in range(teams):
		var scored: float = 0.0
		var weighed: float = 0.0
		for other: int in range(teams):
			var met: float = 0.0 if other == one else won[one][other] + won[other][one]
			scored += won[one][other] if other != one else 0.0
			weighed += met / (strength[one] + strength[other])
		next.append(scored / weighed)
		total += scored / weighed
	for one: int in range(teams):
		next[one] *= teams / total
	return next
