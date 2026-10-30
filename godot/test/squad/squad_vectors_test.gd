# The squad vectors (spec/vectors/squad) as a gdUnit suite: the same check
# `make test-squad-vectors` runs, so `make test-godot-some SUITES=test/squad`
# holds the shot to them too. And the check itself is held to fail on a
# vector that is wrong, so a runner that only knows how to agree is caught.
extends GdUnitTestSuite

const RUNNER: GDScript = preload("res://test/squad/squad_vectors_runner.gd")


func test_every_vector_is_the_games() -> void:
	var directory: String = _directory()
	var files: PackedStringArray = RUNNER.vector_files(directory)
	assert_int(files.size()).is_greater_equal(10)
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
