## The person's fighter: walks, swings a light attack, dodges through a blow,
## and locks on to an enemy so it keeps facing it.
##
## A dodge is a short dash with no damage taken -- the "invincibility frames"
## an action game gives a dodge -- and a cooldown after it. A swing lands
## once, part way through, on what is in reach in front. No AI here: this is
## the body the minions and the boss fight.
class_name BossFightPlayer
extends RefCounted

const SPEED: float = 5.0
const DODGE_SPEED: float = 11.0
const DODGE_SECONDS: float = 0.35
const DODGE_COOLDOWN: float = 0.6
const SWING_SECONDS: float = 0.4
## How far into a swing it lands.
const SWING_LANDS_AT: float = 0.18
const REACH: float = 2.2
## The cosine of half the swing's arc: about 140 degrees wide.
const ARC_COSINE: float = 0.35

var position: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.UP
## 1 full, 0 down.
var health: float = 1.0
## The enemy locked on to, by its token id ("boss", "melee-1"), or "".
var locked: String = ""
var _dodge_left: float = 0.0
var _dodge_cooldown: float = 0.0
var _dodge_direction: Vector2 = Vector2.ZERO
var _swing_left: float = 0.0
var _swing_landed: bool = true


## True while dodging: nothing hurts it.
func dodging() -> bool:
	return _dodge_left > 0.0


## True while a swing is underway.
func swinging() -> bool:
	return _swing_left > 0.0


## Start a dodge along `direction`, or straight back without one; false
## while dodging or cooling down.
func dodge(direction: Vector2) -> bool:
	if dodging() or _dodge_cooldown > 0.0:
		return false
	_dodge_direction = direction.normalized() if direction != Vector2.ZERO else -facing
	_dodge_left = DODGE_SECONDS
	_dodge_cooldown = DODGE_SECONDS + DODGE_COOLDOWN
	return true


## Start a swing; false while one is underway or while dodging.
func swing() -> bool:
	if swinging() or dodging():
		return false
	_swing_left = SWING_SECONDS
	_swing_landed = false
	return true


## Walk `direction` for `step` seconds, or dash if dodging; face `toward`
## when locked on, else the way it walks. True on the step a swing lands.
func move(direction: Vector2, toward: Vector2, step: float) -> bool:
	_dodge_cooldown = maxf(0.0, _dodge_cooldown - step)
	if dodging():
		_dodge_left -= step
		position += _dodge_direction * DODGE_SPEED * step
	elif not swinging():
		position += direction.limit_length(1.0) * SPEED * step
	if toward != Vector2.ZERO:
		facing = toward.normalized()
	elif direction != Vector2.ZERO and not swinging():
		facing = direction.normalized()
	if not swinging():
		return false
	_swing_left -= step
	if not _swing_landed and SWING_SECONDS - _swing_left >= SWING_LANDS_AT:
		_swing_landed = true
		return true
	return false


## True when `point` is in the swing's reach and arc.
func reaches(point: Vector2, radius: float) -> bool:
	var offset: Vector2 = point - position
	if offset.length() > REACH + radius:
		return false
	return offset.length() < radius or offset.normalized().dot(facing) >= ARC_COSINE


## Lose `amount` of health unless dodging; true when it was taken.
func take(amount: float) -> bool:
	if dodging() or health <= 0.0:
		return false
	health = maxf(0.0, health - amount)
	return true
