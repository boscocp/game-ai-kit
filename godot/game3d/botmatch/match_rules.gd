## The bot match's rules, read from `rules.json` (ADR 0007): what a bot can
## do and how fast, and how a match is won. Nothing here is a decision.
##
## A team's knobs -- reaction, turn rate, aim error -- start from the file's
## and are the team's to change (T49's honest difficulty): the same body for
## every bot, and only how quickly and how well it is driven differs.
class_name MatchRules
extends RefCounted

const RULES: String = "res://game3d/botmatch/rules.json"

var health: int = 100
## A rifle's: ten shots a second, a magazine of thirty, nine hits to kill --
## what a person expects of a shooter (the owner, playing the first cut at
## four a second).
var damage: int = 12
var fire_interval: float = 0.1
var magazine: int = 30
var reload_time: float = 2.0
## A bot reloads early, with rounds still in the magazine, when it has
## fewer than this, no enemy in sight, and it stands where it was going.
var reload_below: int = 10
var respawn_time: float = 4.0
var speed: float = 4.5
## Sprinting (Shift, the owner's ask): faster, and no shot while it lasts.
## A bot sprints only with no enemy in sight and its goal sprint_from
## metres away or more.
var sprint_speed: float = 6.5
var sprint_from: float = 8.0
var eye_height: float = 1.5
var chest_height: float = 1.2
var crouched_height: float = 0.7
## How tall a body is, standing and crouched: what a person's aim must
## cross, in height as well as across.
var body_height: float = 1.8
var crouched_body_height: float = 1.1
var body_half_width: float = 0.3
var body_radius: float = 0.4
var max_range: float = 40.0
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


func _init(path: String = RULES) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for key: String in data:
		if key != "about" and key != "knobs":
			set(key, data[key])
	for key: String in data["knobs"]:
		set(key, data["knobs"][key])
