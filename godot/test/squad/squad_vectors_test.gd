# The squad vectors (spec/vectors/squad) as a gdUnit suite: the same check
# `make test-squad-vectors` runs, so `make test-godot-some SUITES=test/squad`
# holds the shot to them too. And the check itself is held to fail on a
# vector that is wrong, so a runner that only knows how to agree is caught.
extends GdUnitTestSuite

const RUNNER: GDScript = preload("res://test/squad/squad_vectors_runner.gd")


func test_every_vector_is_the_games() -> void:
	var directory: String = _directory()
	var files: PackedStringArray = RUNNER.vector_files(directory)
	assert_int(files.size()).is_greater_equal(12)
	for name: String in files:
		var vector: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(name)))
		assert_array(RUNNER.check_vector(name, vector)).is_empty()


func test_a_wrong_vector_is_refused() -> void:
	var directory: String = _directory()
	var name: String = RUNNER.vector_files(directory)[0]
	var vector: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(name)))
	vector["expected"]["chance"] = int(vector["expected"]["chance"]) + 1
	assert_array(RUNNER.check_vector(name, vector)).is_not_empty()


func _directory() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../spec/vectors/squad")


# T121: the runner refuses a vector of the wrong types before it reads one.
# A map or a cell given as text, in a copy of a real file, was a SCRIPT
# ERROR that skipped the check and let the runner exit 0.
func test_a_vector_of_the_wrong_types_is_refused() -> void:
	var vector: Dictionary = VectorShape.read_spec("vectors/squad/a-chance-below-nothing-is-nothing.json")
	assert_str(VectorShape.why_not(vector, RUNNER.SHAPE)).is_empty()
	var paths: Array = [["map"], ["shooter", "cell"], ["target", "cell"], ["expected", "hit"]]
	for path: Array in paths:
		var why: String = VectorShape.why_not(VectorShape.planted(vector, path, "x"), RUNNER.SHAPE)
		assert_str(why).override_failure_message(str(path)).is_not_empty()