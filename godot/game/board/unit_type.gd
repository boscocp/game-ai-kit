## What kind of piece a unit is: how far it goes, how far it reaches, what it
## beats, and what it costs to make.
##
## Data, not behaviour. A type says "moves 3, reaches 2, strong against the
## shield line", and `BoardState` is what turns those numbers into a ruling.
## That keeps every type a row in a table a planner can read, rather than a
## subclass it has to understand -- rock-paper-scissors is only a lesson if
## the rock and the paper are written down where the AI can see them.
##
## A tower or a building is a type with `mobile` false, not a class of its
## own: a unit that cannot move is still a unit, standing on a cell, owned by
## a faction, and everything else in the board already knows how to hold one.
##
## When not to use it: per-unit variation (veterancy, damage taken). A type is
## shared by every unit of that kind and never changes during a game.
class_name UnitType
extends RefCounted

## The cost map a type walks on when it has no other: the board's own.
const GROUND: String = ""

## The name a person reads, and the key every table in the game uses.
var type_name: String

## Movement points at the start of each of its side's turns.
var movement: int

## How many cells away it can strike, by steps (no diagonals). 0 for a type
## that never strikes.
var attack_range: int

## How many cells away it can see. Watchtowers exist for this number.
var sight: int

## What it costs to produce. 0 for anything that is placed, not built.
var cost: int

## False for towers and buildings. `BoardState` refuses a walk by an immobile
## unit, which is the whole of what makes a tower a tower.
var mobile: bool

## Which cost map it walks on: `GROUND` for the board's own, or a name the
## scenario gave another one (see `BoardState.movement_graphs`). This is how
## one type crosses water the rest cannot, without the board knowing what
## water is.
var mover: String

## The type names this one is strong against.
var strong_against: Array[String]

## The types a producer of this kind can build. Empty for everything else.
var produces: Array[String]

## The upgrade a faction must own before this type can be produced, or "".
var requires: String


func _init(name: String, points: int, reach: int, seeing: int, price: int,
		moves: bool = true) -> void:
	type_name = name
	movement = points
	attack_range = reach
	sight = seeing
	cost = price
	mobile = moves
	mover = GROUND
	strong_against = []
	produces = []
	requires = ""


## True when this type is written down as beating `other`.
func beats(other: UnitType) -> bool:
	return other != null and strong_against.has(other.type_name)
