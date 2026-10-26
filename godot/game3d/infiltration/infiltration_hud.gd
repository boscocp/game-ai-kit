## What a person playing the infiltration level sees on top of the 3D view:
## over each guard, its detection bar -- the awareness, the phases'
## thresholds as ticks, the phase's name -- and what it is doing; who is
## calling for help and who heard one; and in a corner the player's health,
## stance, and whether off-screen hearing is halved.
##
## Blacklist's detection bar is the model: the player sees the timer fill
## and where it changes the guard's mind [Walsh 2015]. The bar is drawn
## where the guard stands on screen, so it reads as that guard's.
##
## When not to use it: for the reasoning in full. The scores of every
## action are the panel's, for the guard under watch.
class_name InfiltrationHud
extends Control

const BAR: Vector2 = Vector2(70, 7)
const BACK: Color = Color(0, 0, 0, 0.55)
const TICK: Color = Color(1, 1, 1, 0.9)
const CALLING: Color = Color(1.0, 0.3, 0.3)
const HEARD: Color = Color(0.4, 0.85, 1.0)

## The end of a try, by `InfiltrationWorld.outcome`: one sentence each.
const OUTCOMES: Dictionary = {
	"escaped": "ESCAPED -- N for another try, L for another level",  # shown through tr()
	"caught": "CAUGHT -- N for another try, L for another level",  # shown through tr()
}

var world: InfiltrationWorld
var camera: Camera3D
var watched: int = 0


func _draw() -> void:
	if world == null or camera == null:
		return
	for guard: InfiltrationGuard in world.guards:
		var head: Vector3 = world.level.arena.above(guard.position, 2.2)
		if guard.alive() and not camera.is_position_behind(head):
			_draw_guard(guard, camera.unproject_position(head))
	_draw_corner()


func _draw_guard(guard: InfiltrationGuard, at: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var corner: Vector2 = at - Vector2(BAR.x / 2.0, 0)
	draw_rect(Rect2(corner, BAR), BACK)
	var phase: int = guard.mind.phase()
	var colour: Color = InfiltrationDrawing.PHASES[mini(phase, InfiltrationDrawing.PHASES.size() - 1)]
	draw_rect(Rect2(corner, Vector2(BAR.x * clampf(guard.aware(), 0.0, 1.0), BAR.y)), colour)
	for row: Dictionary in guard.type.awareness["phases"]:
		var tick: float = corner.x + BAR.x * float(row["at"])
		draw_line(Vector2(tick, corner.y - 2), Vector2(tick, corner.y + BAR.y + 2), TICK)
	var label: String = "%s%s: %s" % ["> " if guard.id == watched else "", InfiltrationWords.word(guard.mind.phase_name()),
		InfiltrationWords.word(guard.action)]
	if guard.role != RoleArbiter.NONE:
		label += " (%s)" % InfiltrationWords.word(guard.role)
	draw_string(font, corner + Vector2(0, -4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, colour)
	if guard.calling_until >= 0.0:
		draw_string(font, corner + Vector2(0, BAR.y + 14), tr("CALLING FOR HELP"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, CALLING)
	elif world.time - guard.help_heard_at <= 3.0:
		var heard: String = tr("heard: {source}").format({source = InfiltrationWords.word(guard.mind.memory.source)})
		draw_string(font, corner + Vector2(0, BAR.y + 14), heard, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HEARD)


func _draw_corner() -> void:
	var font: Font = ThemeDB.fallback_font
	var player: InfiltrationPlayer = world.player
	var body: String = "health {health}   {stance} sprinting" if player.sprinting else "health {health}   {stance}"  # shown through tr()
	var lines: Array[String] = [
		tr(body).format({health = player.health, stance = InfiltrationWords.word(player.stance)}),
		tr("off-screen hearing halved: {halving}").format({halving = InfiltrationText.on(world.rules.off_screen_halving)}),
	]
	if PlayerActions.takedown_target(world) != null:
		lines.append(tr("E: take the guard down"))
	if world.outcome != "":
		lines.append(tr(OUTCOMES.get(world.outcome, world.outcome)))
	for index: int in range(lines.size()):
		draw_string(font, Vector2(16, size.y - 20 - 18 * (lines.size() - 1 - index)), lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	var middle: Vector2 = size / 2.0
	draw_line(middle - Vector2(8, 0), middle + Vector2(8, 0), Color(1, 1, 1, 0.8))
	draw_line(middle - Vector2(0, 8), middle + Vector2(0, 8), Color(1, 1, 1, 0.8))
