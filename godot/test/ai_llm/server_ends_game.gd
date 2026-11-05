# A game holding a server it started, for `server_ends.py` (T130): it
# starts `fake_llm_server.py` through `LlmLocalServer`, prints
# "READY <pid>" once the server answers, and then ends the way it is told
# -- by `quit()`, by the window's close request, or by waiting for the
# runner to signal it. The owner asked, 2026-11-05: "Lembre de colocar
# mecanismo de quando fechar o jogo tbm fechar o servidor llm pra não
# ficar gastando vram".
#
#     ./scripts/godot --headless --path godot -s res://test/ai_llm/server_ends_game.gd -- ENDING PORT [--no-die]
#
# ENDING: quit, close, or wait (the runner sends SIGINT, SIGTERM or SIGKILL).
# --no-die: the fake is told to outlive its parent, the planted case.
extends SceneTree

const FAKE: String = "res://test/ai_llm/fake_llm_server.py"

var _server: LlmLocalServer = null
var _ending: String = ""
var _said: bool = false


func _initialize() -> void:
	var given: PackedStringArray = OS.get_cmdline_user_args()
	_ending = given[0]
	var arguments := PackedStringArray([given[1], "0.2"])
	if "--no-die" in given:
		arguments.append("--no-die")
	_server = LlmLocalServer.new(ProjectSettings.globalize_path(FAKE), arguments, int(given[1]))
	root.add_child(_server)


# Asked on the first frame: in `_initialize` the node is not ready yet.
func _process(_delta: float) -> bool:
	if _server.state == "":
		_server.begin()
	if _said or not _server.is_ready():
		return false
	_said = true
	# A server found on the port is not this run's: never name a pid for it.
	if not _server.started_here():
		print("FOUND a server this game did not start on port %d" % _server.port)
		quit(2)
		return true
	print("READY %d" % _server.pid)
	if _ending == "quit":
		quit()
	elif _ending == "close":
		root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		root.close_requested.emit()
	return false
