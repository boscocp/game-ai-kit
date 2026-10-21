## What a person playing a bot sees on top of the 3D view, as in any
## first-person shooter: a crosshair where the shot goes, a hit marker when
## it struck someone -- larger, with HEADSHOT, when it struck a head -- the
## screen's edge flashing red when they are hit,
## their health, weapon, rounds and kill streak in a corner, and a reload's
## progress under the crosshair while it lasts.
##
## Drawn only while a bot is played; watching, the panel and map say more.
class_name BotMatchHud
extends Control

const CROSSHAIR: Color = Color(1, 1, 1, 0.9)
const HIT_MARKER: Color = Color(1, 0.3, 0.25)
const HEADSHOT: Color = Color(1, 0.85, 0.2)
const HURT: Color = Color(0.9, 0.05, 0.05)
## How long, in match seconds, a hit marker and a hurt flash last.
const MARKER_SECONDS: float = 0.15
const HURT_SECONDS: float = 0.3
const GAP: float = 4.0
const ARM: float = 9.0

var world: BotMatch
## The bot a person plays, or -1: then nothing is drawn.
var played: int = -1


func _draw() -> void:
	if world == null or played == -1:
		return
	var bot: MatchBot = world.bots[played]
	var middle: Vector2 = size / 2.0
	_draw_hurt(bot)
	if not bot.alive():
		var waiting: String = "down -- back in %.1f s" % bot.respawn_left
		draw_string(ThemeDB.fallback_font, middle + Vector2(-90, 0), waiting, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, HURT)
		return
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(middle + direction * GAP, middle + direction * (GAP + ARM), CROSSHAIR, 2.0)
	var struck: String = _hit_lately(bot)
	if struck != "":
		var head: bool = struck == MatchRules.HEAD
		var reach: float = 22.0 if head else 14.0
		for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(middle + corner * 6.0, middle + corner * reach, HEADSHOT if head else HIT_MARKER, 3.0 if head else 2.5)
		if head:
			draw_string(ThemeDB.fallback_font, middle + Vector2(-48, -34), "HEADSHOT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, HEADSHOT)
	if bot.reload_left > 0.0:
		_draw_reload(middle, 1.0 - bot.reload_left / world.rules.reload_time)
	var reloading: String = "  reloading" if bot.reload_left > 0.0 else ("  sprinting" if bot.sprinting else "")
	var weapon: String = "POWER" if bot.weapon == MatchSupply.POWER else "rifle"
	var streak: String = "    streak %d/%d" % [bot.streak, world.rules.streak_for_power]
	var dry: String = "  -- back to your base for rounds" if bot.ammo + bot.reserve <= 0 else ""
	var status: String = "%d health    %s %d / %d%s%s%s" % [bot.health, weapon, bot.ammo, bot.reserve, reloading, streak, dry]
	# Bottom left: the bottom right is where the rifle is.
	var at := Vector2(30.0, size.y - 30.0)
	draw_string(ThemeDB.fallback_font, at, status, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, CROSSHAIR)


# "RELOADING" and a bar filling as it goes, under the crosshair.
func _draw_reload(middle: Vector2, done: float) -> void:
	var at: Vector2 = middle + Vector2(-60.0, 40.0)
	draw_string(ThemeDB.fallback_font, at, "RELOADING", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, CROSSHAIR)
	draw_rect(Rect2(at + Vector2(0, 8), Vector2(120, 6)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(at + Vector2(0, 8), Vector2(120 * clampf(done, 0.0, 1.0), 6)), CROSSHAIR)


# A red frame round the screen, fading, after the played bot was hit.
func _draw_hurt(bot: MatchBot) -> void:
	var since: float = world.time - bot.hurt_at
	if since > HURT_SECONDS:
		return
	var fade: Color = Color(HURT, 0.45 * (1.0 - since / HURT_SECONDS))
	var edge: float = 40.0
	draw_rect(Rect2(0, 0, size.x, edge), fade)
	draw_rect(Rect2(0, size.y - edge, size.x, edge), fade)
	draw_rect(Rect2(0, 0, edge, size.y), fade)
	draw_rect(Rect2(size.x - edge, 0, edge, size.y), fade)


# The zone the played bot's latest hit within MARKER_SECONDS struck, or "".
func _hit_lately(bot: MatchBot) -> String:
	var struck: String = ""
	for shot: Array in world.recent_shots:
		if int(shot[1]) == bot.id and bool(shot[3]) and world.time - float(shot[0]) <= MARKER_SECONDS:
			struck = str(shot[6])
	return struck
