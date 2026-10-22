## The bot match's rules, read from `rules.json` (ADR 0007): what a bot can
## do and how fast, and how a match is won. Nothing here is a decision.
##
## A team's knobs -- reaction, turn rate, aim error -- start from the file's
## and are the team's to change (T49's honest difficulty): the same body for
## every bot, and only how quickly and how well it is driven differs.
class_name MatchRules
extends RefCounted

const RULES: String = "res://game3d/botmatch/rules.json"
## The hit zones' names, and NONE for a point of the body's box that is air.
const HEAD: String = "head"
const TORSO: String = "torso"
const LIMB: String = "limb"
const NONE: String = ""

var health: int = 100
## A rifle's: ten shots a second, a magazine of thirty, nine hits to kill --
## what a person expects of a shooter (the owner, playing the first cut at
## four a second).
var damage: int = 12
var fire_interval: float = 0.1
var magazine: int = 30
var reload_time: float = 2.0
## Ammunition (the owner's asks): a rifle starts with a magazine of 30 and
## three reloads of 30 more, 120 in all, and only the base gives more.
var reserve: int = 90
## Standing this near its team's resupply, a bot is filled back up.
var resupply_radius: float = 1.5
## What going back is weighed by (`MatchSupply`): the share of its rounds
## spent, less each second of the walk, less what leaving its post costs --
## more when it is attacking a point than holding one.
var resupply_walk_weight: float = 0.05
var resupply_hold_weight: float = 0.3
var resupply_attack_weight: float = 0.5
## What a whole bar of health is worth to an errand, as all of a bot's
## rounds are 1: the base heals a bot whole (T68), so going back is worth
## the health it is missing as well as the rounds.
var health_worth: float = 1.0
## What hiding to heal is weighed by (T68): each second away from its post
## -- the walk to cover and the wait for its health -- and how far a bot
## looks for cover from every enemy its team knows of. A second away costs
## less than a second's walk back to the base, 0.05, which counts only the
## way there of a walk both ways.
var hide_second_weight: float = 0.02
var hide_metres: float = 15.0
## The power weapon: three times the rifle's damage, 20 rounds and no
## more, back 60 s after it is taken, picked up within a metre.
var power_damage_multiplier: float = 3.0
var power_rounds: int = 20
var power_respawn: float = 60.0
var power_pickup_radius: float = 1.0
## What fetching it is weighed by: what it is worth, less each second of
## the walk, less each enemy the team remembers near it.
var power_worth: float = 1.0
var power_walk_weight: float = 0.08
var power_danger_weight: float = 0.3
var power_danger_radius: float = 12.0
## Kills since its last death that earn a bot the power weapon at its base.
var streak_for_power: int = 5
## Getting past a body (`PassageChoice`): blocked this long, a bot weighs its
## ways on; bodies this near close cells for the way round; asking costs
## this many seconds; a spot's score point is worth this many a second; a
## refusal is remembered this long; a teammate steps this far aside.
var passage_patience: float = 0.3
var passage_body_reach: float = 4.0
var passage_ask_seconds: float = 1.0
var passage_points_a_second: float = 10.0
var passage_refusal_memory: float = 3.0
var passage_step_aside: float = 0.6
## What stepping aside costs a teammate asked, in seconds, by what it does.
var make_way_step_seconds: float = 0.5
var make_way_per_enemy: float = 2.0
var make_way_shooting: float = 1.5
var make_way_reloading: float = 0.5
var make_way_covering: float = 3.0
var respawn_time: float = 4.0
## Health that comes back (T68, the owner's ask): after
## `regeneration_delay` seconds without a hit -- the owner's ten -- health
## comes back `regeneration_rate` points a second, up to `regeneration_to`
## and never past the rules' `health`. Twenty a second fills an empty bar in
## five seconds, a little slower than Halo's shields (four, Halo: Combat
## Evolved) -- "aos poucos", gradually, as the owner asked; the sources are
## in `docs/concepts/shooter-ai.md`.
var regeneration_delay: float = 10.0
var regeneration_rate: float = 20.0
var regeneration_to: int = 100
var speed: float = 4.5
## Sprinting (Shift, the owner's ask): faster, and no shot while it lasts
## -- the game's rule. When a bot sprints is its own weighing (`paces` in
## `actions.json`).
var sprint_speed: float = 6.5
var eye_height: float = 1.5
var chest_height: float = 1.2
var crouched_height: float = 0.7
## How tall a body is, standing and crouched: what a person's aim must
## cross, in height as well as across.
var body_height: float = 1.8
var crouched_body_height: float = 1.1
var body_half_width: float = 0.3
## The three hit zones (the owner's ask), standing, in metres above the
## feet and across from the middle: the head from head_from up and
## head_half_width across; the torso from torso_from to the head and
## torso_half_width across; the limbs, the rest of the body's box -- the
## legs below the torso, the arms beside it. Crouched, every height shrinks
## with the body. Each zone's damage is the rifle's times its multiplier.
var head_from: float = 1.5
var head_half_width: float = 0.12
var torso_from: float = 0.85
var torso_half_width: float = 0.2
var head_multiplier: float = 2.0
var torso_multiplier: float = 1.0
var limb_multiplier: float = 0.5
var body_radius: float = 0.4
var max_range: float = 40.0
## A shot is heard by the enemy within this, loudest beside it (`Hearing`).
var shot_heard_metres: float = 30.0
var capture_radius: float = 3.0
var capture_time: float = 4.0
var score_limit: int = 300
var time_limit: float = 240.0
## The simulation's step, and how often bots look and decide.
var step: float = 0.05
var decision_interval: float = 0.2
## How often a bot reconsiders where to stand, and by how much a new spot
## must beat its own to make it move.
var position_interval: float = 1.0
var stay_margin: float = 10.0
## A squad sent to hold a point stands within area_radius of it; one sent to
## attack, within attack_radius, which is on the point.
var area_radius: float = 4.5
var attack_radius: float = 2.5
## How long a team remembers an enemy it saw, and a kill or loss counts.
var remembered_for: float = 10.0
## Enemies this near a squad's centre, seen within confidence_memory
## seconds, count against its confidence: a squad is afraid of what it is
## seeing, not of everything it remembers.
var squad_sight_radius: float = 20.0
var confidence_memory: float = 2.0
## A squad's confidence thresholds, by SquadConfidence's names; the rest
## are its defaults. Later than the technique's defaults: measured, a squad
## that fell back at 0.7 gave up every point to a side that never did.
var retreat_at: float = 0.5
var recover_at: float = 0.9
## How far back a retreating squad falls, and how long a wave may take.
var fallback_metres: float = 8.0
var wave_timeout: float = 3.0
## The default knobs, per team.
var reaction: float = 0.3
var turn_rate_degrees: float = 270.0
var aim_error_degrees: float = 3.0


## The zone a point of a body is in: `height` above its feet and `across`
## from its middle, for a body crouched or not. HEAD, TORSO, LIMB, or NONE
## for the air round the head, above the shoulders.
func zone_at(height: float, across: float, crouched: bool) -> String:
	var shrink: float = crouched_body_height / body_height if crouched else 1.0
	var top: float = body_height * shrink
	if height < 0.0 or height > top or absf(across) > body_half_width:
		return NONE
	if height >= head_from * shrink:
		return HEAD if absf(across) <= head_half_width else NONE
	if height >= torso_from * shrink and absf(across) <= torso_half_width:
		return TORSO
	return LIMB


## What a hit in `zone` takes off, the rifle's damage times the zone's
## multiplier.
func damage_in(zone: String) -> int:
	return roundi(damage * float({HEAD: head_multiplier, TORSO: torso_multiplier, LIMB: limb_multiplier}.get(zone, 0.0)))


func _init(path: String = RULES) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for key: String in data:
		if key != "about" and key != "knobs":
			set(key, data[key])
	for key: String in data["knobs"]:
		set(key, data["knobs"][key])
