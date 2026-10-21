## What a person playing a bot sees on top of the 3D view, as in any
## first-person shooter: a crosshair where the shot goes, a hit marker when
## it struck someone, the screen's edge flashing red when they are hit, and
## their health and ammunition in a corner.
##
## Drawn only while a bot is played; watching, the panel and map say more.
class_name BotMatchHud
extends Control

const CROSSHAIR: Color = Color(1, 1, 1, 0.9)
const HIT_MARKER: Color = Color(1, 0.3, 0.25)
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
	if _hit_lately(bot):
		for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(middle + corner * 6.0, middle + corner * 14.0, HIT_MARKER, 2.5)
	var reloading: String = "  reloading" if bot.reload_left > 0.0 else ("  sprinting" if bot.sprinting else "")
	var status: String = "%d health    %d / %d%s" % [bot.health, bot.ammo, world.rules.magazine, reloading]
	# Bottom left: the bottom right is where the rifle is.
	var at := Vector2(30.0, size.y - 30.0)
	draw_string(ThemeDB.fallback_font, at, status, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, CROSSHAIR)


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


# Whether one of the played bot's own shots hit within MARKER_SECONDS.
func _hit_lately(bot: MatchBot) -> bool:
	for shot: Array in world.recent_shots:
		if int(shot[1]) == bot.id and bool(shot[3]) and world.time - float(shot[0]) <= MARKER_SECONDS:
			return true
	return false
