## The valley's save (T164, ADR 0025): the one file the kit keeps between
## sessions, and the one class that writes or erases it.
##
## The file is a record of deeds and nothing else. Its first line is the
## header `{"version": 1}`, and every line after it is one deed, appended at
## the end and never rewritten. Nothing derived from the deeds is saved: the
## next session rebuilds it from them. A record with another version, or
## with none, is refused by name rather than misread.
##
## Appending a deed reads the file once to check it, then opens it, writes
## one line at its end and closes it; loading reads every line once.
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
	return read_text(FileAccess.get_file_as_string(path), record)


## Read a saved record's whole text into `record`. The writer ends every
## line with a newline and writes no blank line, so a file that does not
## end in one has a torn last line -- a write cut short -- and a blank line
## is not a deed. Both are refused, as an empty file is.
static func read_text(text: String, record: DeedLog) -> String:
	if text == "":
		return "the record file is empty; its first line must be the header {\"version\": %d}" % VERSION  # not shown: the record's own English, quoted where the save is refused
	if not text.ends_with("\n"):
		return "the record's last line is torn: the file does not end in a newline"  # not shown: the record's own English, quoted where the save is refused
	return read_lines(text.left(-1).split("\n"), record)


## Read a record's lines into `record`: the header first, then each deed,
## which `record` refuses or keeps. Returns "" or why the lines were
## refused, with the line at fault. Static, so the vectors can be read
## without a file. A line repeating the header's `version` is refused like
## any other key beyond the three: stricter than N20, which lets it pass,
## on purpose (ADR 0025).
static func read_lines(lines: PackedStringArray, record: DeedLog) -> String:
	if lines.is_empty():
		return "the record is empty; its first line must be the header {\"version\": %d}" % VERSION  # not shown: the record's own English, quoted where the save is refused
	var why: String = header_refusal(lines[0])
	if why != "":
		return why
	for index: int in range(1, lines.size()):
		var deed: Variant = _parsed(lines[index])
		if not deed is Dictionary:
			return "line %d is not a deed" % (index + 1)  # not shown: the record's own English, quoted where the save is refused
		why = record.append(deed)
		if why != "":
			return "line %d: %s" % [index + 1, why]  # not shown: the record's own English, quoted where the save is refused
	return ""


## Why `line` is not the header of a record this game reads, or "" when it
## is. A record with no version and one with another are both refused, and
## so is a header holding anything else -- a name in it would be a person.
static func header_refusal(line: String) -> String:
	var header: Variant = _parsed(line)
	if not header is Dictionary or not header.has("version"):
		return "the record has no version; its first line must be the header {\"version\": %d}" % VERSION  # not shown: the record's own English, quoted where the save is refused
	if header.size() != 1:
		return "the record's header holds more than its version"  # not shown: the record's own English, quoted where the save is refused
	var version: Variant = header["version"]
	if not (version is float or version is int):
		return "the record's version %s is not a number; this game reads version %d" % [DeedLog.shown(version), VERSION]  # not shown: the record's own English, quoted where the save is refused
	if float(version) != float(VERSION):
		return "the record is version %s, and this game reads version %d" % [DeedLog.shown(version), VERSION]  # not shown: the record's own English, quoted where the save is refused
	return ""


## Keep `deed` in `record` and append it to the file, or refuse it. Returns
## "" when both hold it, or why not. The file is read first, whole, and
## must be a record this game reads, the same as `record`, with room for
## the deed after its last one; a refused deed never reaches the disk. The
## file is written before the record keeps the deed, so a failed write
## leaves the two agreeing. Reading the file costs one pass over it.
func append(record: DeedLog, deed: Dictionary) -> String:
	var why: String = record.refusal(deed)
	if FileAccess.file_exists(path):
		why = append_refusal(FileAccess.get_file_as_string(path), record, deed)
	elif why == "" and record.size() != 0:
		why = "there is no record on disk, and the one in memory has deeds; nothing was appended"  # not shown: the record's own English, quoted where the save is refused
	if why != "":
		return why
	var file: FileAccess = _open_at_the_end()
	if file == null:
		return "the record cannot be opened: %s" % error_string(FileAccess.get_open_error())  # not shown: the record's own English, quoted where the save is refused
	var kept: Dictionary = DeedLog.make(int(deed["day"]), str(deed["verb"]), str(deed["place"]))
	var written: bool = file.store_line(JSON.stringify(kept))
	file.close()
	if not written:
		return "the deed could not be written to the record"  # not shown: the record's own English, quoted where the save is refused
	return record.append(kept)


## Why `deed` cannot be appended to a saved record whose text is `text`,
## kept in memory as `record`, or "". The file must read clean -- not
## empty, not torn, its version this game's -- `deed` must follow its last
## deed, and `record` must be what the file holds: a session that appends
## before loading would otherwise write a day out of order.
static func append_refusal(text: String, record: DeedLog, deed: Dictionary) -> String:
	var on_disk: DeedLog = record.cut(0)
	var why: String = read_text(text, on_disk)
	if why != "":
		return "the record on disk is refused, and nothing was appended: %s" % why  # not shown: the record's own English, quoted where the save is refused
	why = on_disk.refusal(deed)
	if why != "":
		return why
	if on_disk.deeds() != record.deeds():
		return "the record in memory is not the one on disk; load it before appending"  # not shown: the record's own English, quoted where the save is refused
	return ""


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
