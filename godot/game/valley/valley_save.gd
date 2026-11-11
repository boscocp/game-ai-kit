## The valley's save (T164, ADR 0025): the one file the kit keeps between
## sessions, and the one class that writes or erases it.
##
## The file is a record of deeds and nothing else. Its first line is the
## header `{"version": 1}`, and every line after it is one deed, appended at
## the end and never rewritten. Nothing derived from the deeds is saved: the
## next session rebuilds it from them. A record with another version, or
## with none, is refused by name rather than misread.
##
## Appending a deed opens the file, writes one line at its end and closes
## it; loading reads every line once.
##
## When not to use it: to keep anything that is not a deed. If a number
## seems worth saving, it can be rebuilt from the record, and the record is
## where its cause already is.
class_name ValleySave
extends RefCounted

## Where the game keeps the record. A test hands `new()` a path of its own
## under `user://tmp/`, and never writes this one.
const PATH: String = "user://valley/deeds.json"
## The record's schema version, in its header line.
const VERSION: int = 1

## The file this save reads and writes.
var path: String = PATH


func _init(where: String = PATH) -> void:
	path = where


## Read the saved record into `record`, an empty `DeedLog`. Returns "" when
## every line was read, or why the file was refused. No file is the first
## day: an empty record, and nothing to refuse.
func load_into(record: DeedLog) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return read_lines(FileAccess.get_file_as_string(path).split("\n", false), record)


## Read a record's lines into `record`: the header first, then each deed,
## which `record` refuses or keeps. Returns "" or why the lines were
## refused, with the line at fault. Static, so the vectors can be read
## without a file.
static func read_lines(lines: PackedStringArray, record: DeedLog) -> String:
	if lines.is_empty():
		return "the record is empty; its first line must be the header {\"version\": %d}" % VERSION
	var why: String = header_refusal(lines[0])
	if why != "":
		return why
	for index: int in range(1, lines.size()):
		var deed: Variant = _parsed(lines[index])
		if not deed is Dictionary:
			return "line %d is not a deed" % (index + 1)
		why = record.append(deed)
		if why != "":
			return "line %d: %s" % [index + 1, why]
	return ""


## Why `line` is not the header of a record this game reads, or "" when it
## is. A record with no version and one with another are both refused.
static func header_refusal(line: String) -> String:
	var header: Variant = _parsed(line)
	if not header is Dictionary or not header.has("version"):
		return "the record has no version; its first line must be the header {\"version\": %d}" % VERSION
	if header.size() != 1:
		return "the record's header holds more than its version"
	var version: Variant = header["version"]
	if not (version is float or version is int) or float(version) != float(VERSION):
		return "the record is version %s, and this game reads version %d" % [version, VERSION]
	return ""


## Keep `deed` in `record` and append it to the file, or refuse it. Returns
## "" when both hold it, or why not. The record is asked first, so a refused
## deed never reaches the disk, and the file is written before the record
## keeps the deed, so a failed write leaves the two agreeing.
func append(record: DeedLog, deed: Dictionary) -> String:
	var why: String = record.refusal(deed)
	if why != "":
		return why
	var file: FileAccess = _open_at_the_end()
	if file == null:
		return "the record cannot be opened: %s" % error_string(FileAccess.get_open_error())
	var kept: Dictionary = DeedLog.make(int(deed["day"]), str(deed["verb"]), str(deed["place"]))
	var written: bool = file.store_line(JSON.stringify(kept))
	file.close()
	if not written:
		return "the deed could not be written to the record"
	return record.append(kept)


## Remove the saved record, so the next session starts from the first day.
## The erase button's one action; no file is nothing to erase.
func erase() -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(path)


# The file opened for one more line: a new one gets its header first, an
# old one is opened without truncating and read to its end.
func _open_at_the_end() -> FileAccess:
	if FileAccess.file_exists(path):
		var old: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
		if old != null:
			old.seek_end()
		return old
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var fresh: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if fresh != null:
		fresh.store_line(JSON.stringify({"version": VERSION}))
	return fresh


# `text` parsed as JSON, or null. `JSON.new().parse()` rather than
# `JSON.parse_string()`, which prints an engine error of its own on a
# malformed line.
static func _parsed(text: String) -> Variant:
	var reader := JSON.new()
	return reader.data if reader.parse(text) == OK else null
