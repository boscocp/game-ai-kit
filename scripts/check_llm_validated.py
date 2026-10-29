#!/usr/bin/env python3
"""Half-hold invariant 7: the LLM never blocks a frame, and nothing it returns
becomes an action without passing a validator.

What it holds
-------------
T92. `ai_llm` is the one door between a language model and a game: a
runtime sends the request and signals the text back, `LlmValidator` rules
on it, and only the `LlmReply` it builds reaches the game's rules. That is
true only while nothing goes round the door. This gate reads every GDScript
file under `godot/` as text -- comments blanked, and strings blanked where a
rule is about code -- and refuses the plain ways round it:

  V0  `godot/addons/ai_llm/` is missing, or has no `llm_validator.gd` or
      `llm_reply.gd`: rules about a door that is not there pass on nothing,
      and "found nothing" is never a pass
  V1  a script outside `ai_llm` reaches a model itself: `HTTPRequest`,
      `HTTPClient`, a raw stream or socket (`StreamPeerTCP`, `StreamPeerTLS`,
      `TCPServer`, `WebSocketPeer`, `WebSocketMultiplayerPeer`,
      `PacketPeerUDP`, `UDPServer`), `JavaScriptBridge`, or another program
      (`OS.execute`, `OS.execute_with_pipe`, `OS.create_process`) -- in code,
      or as a node in a scene or resource. The one file outside the addon
      allowed `HTTPRequest` (and `HTTPClient`'s constants) is
      `godot/test/ai_llm/http_frame_probe.gd`, which measures it with threads
      off as well as on -- by its path, not its folder.
  V2  a model's text read, or a reply made, outside the door:
      `LlmReply.new`, an alias of `LlmReply` (`const Made := LlmReply`), or a
      load of `llm_reply.gd` by path or by its uid, anywhere but
      `llm_validator.gd`; and outside `godot/addons/ai_llm/`, `raw_text`
      (as `.raw_text` or as the string `"raw_text"`), a runtime's `replied`
      signal (`.replied`, or the string `"replied"`), or `HttpRuntime`'s
      `_text_of(`. Each is text the model sent before anybody ruled on it.
      Nor may a script there extend `LlmReply` (a forged reply) or
      `LlmValidator` (a rule overridden to let anything in).
  V3  something waits on the frame. In the addon: `OS.delay_msec` or
      `OS.delay_usec`; another program run (`OS.execute`...); a `Semaphore`;
      `wait_to_finish` outside `_exit_tree` or `_notification` (teardown,
      when the frame is over anyway); a `while` loop that polls (`poll()`,
      `get_status()`, `Time.get_ticks_*`) or never `await`s; `use_threads`
      set to anything but `true`; an `HTTPRequest` made without setting
      `use_threads = true` on the variable it was assigned to, or made where
      that cannot be read -- in a scene, or not assigned to a name.
      Anywhere: a `while` loop on `is_thinking()` or `is_busy()` that never
      `await`s, which is a game spinning the frame until the model answers.

What it deliberately does not do
--------------------------------
Run anything. It is static: no engine, no model, no validator. Whether
the validator refuses what it must is held by running it, which is
`make test-llm-vectors` -- both languages against spec/vectors/llm/.

And it is a net for the spellings a person writes on a normal day, not a
proof, which is why CLAUDE.md calls invariant 7 half held. Not caught,
known: a class or a method named in a string built at run time
(`ClassDB.instantiate("HTTP" + "Request")`, `Callable(runtime, name)`,
`Expression`); `set("use_threads", false)`; a node made in a `.tres` or a
scene by a script it instances; a `Thread` the addon starts and a game
joins; and a game that reads `LlmReply.speech` and acts on what it says
rather than on `intent` -- the speech is validated, but a rule that parses
it has made the model decide again; and `LlmReply` reached through a
function (`return LlmReply`, then `.new()`). Writing to a reply's fields
is not this gate's business: `LlmReply` refuses it at run time, its fields
read-only.

Vendored code (`gdUnit4`) and dot folders (`godot/.godot/`) are skipped, as
`check_readability.py` and `check_no_training.py` skip them.

Exit codes
----------
0   every rule holds
1   a finding
2   wrong usage, or a file that cannot be read

Usage
-----
    check_llm_validated.py [--root PATH]
    check_llm_validated.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import dataclasses
import io
import pathlib
import re
import subprocess
import sys
import tempfile

GODOT = pathlib.Path("godot")
ADDON = pathlib.Path("godot/addons/ai_llm")
VALIDATOR = ADDON / "llm_validator.gd"
REPLY = ADDON / "llm_reply.gd"
PROBE = pathlib.Path("godot/test/ai_llm/http_frame_probe.gd")
# What the probe measures, and the constant it sends with.
PROBE_MAY_USE = {"HTTPRequest", "HTTPClient"}

# Third-party GDScript this project does not author.
VENDORED_DIRS = {"gdUnit4"}

NETWORK_CLASSES = ("HTTPRequest", "HTTPClient", "StreamPeerTCP", "StreamPeerTLS",
                   "TCPServer", "WebSocketPeer", "WebSocketMultiplayerPeer",
                   "PacketPeerUDP", "UDPServer", "JavaScriptBridge")
NETWORK_RE = re.compile(r"\b(" + "|".join(NETWORK_CLASSES) + r")\b")
NODE_TYPE_RE = re.compile(r'type="(' + "|".join(NETWORK_CLASSES) + r')"')
PROCESS_RE = re.compile(r"\bOS\s*\.\s*(execute|execute_with_pipe|create_process)\s*\(")

REPLY_NEW_RE = re.compile(r"\bLlmReply\s*\.\s*new\b")
REPLY_ALIAS_RE = re.compile(r"(?<![=!<>])=\s*LlmReply\b(?!\s*\.)")
REPLY_PATH_RE = re.compile(r"llm_reply\.gd")
SUBCLASS_RE = re.compile(r"^\s*extends\s+(LlmReply|LlmValidator)\b")
VALIDATOR_PATH_RE = re.compile(r"^\s*extends\s+[\"'][^\"']*llm_validator\.gd")
RAW_TEXT_RE = re.compile(r"\.\s*raw_text\b")
RAW_TEXT_NAMED_RE = re.compile(r"[\"']raw_text[\"']")
REPLIED_RE = re.compile(r"\.\s*replied\b")
REPLIED_NAMED_RE = re.compile(r"[\"']replied[\"']")
TEXT_OF_RE = re.compile(r"\b_text_of\s*\(")

DELAY_RE = re.compile(r"\bOS\s*\.\s*delay_(?:msec|usec)\b")
SEMAPHORE_RE = re.compile(r"\bSemaphore\b")
WAIT_RE = re.compile(r"\.\s*wait_to_finish\s*\(")
TEARDOWN = {"_exit_tree", "_notification"}
FUNC_RE = re.compile(r"^\s*(?:static\s+)?func\s+(\w+)")
WHILE_RE = re.compile(r"^(\s*)while\b")
POLL_RE = re.compile(r"\.\s*(?:poll|get_status)\s*\(|\bTime\s*\.\s*get_ticks_\w+")
AWAIT_RE = re.compile(r"\bawait\b")
WAITING_ON_MODEL_RE = re.compile(r"\b(?:is_thinking|is_busy)\s*\(")
REQUEST_NEW_RE = re.compile(r"\bHTTPRequest\s*\.\s*new\s*\(")
ASSIGNED_RE = re.compile(
    r"(?:var\s+)?([A-Za-z_][\w.]*)\s*(?::\s*[\w.]+\s*)?:?=\s*HTTPRequest\s*\.\s*new\s*\(")
THREADS_NOT_TRUE_RE = re.compile(r"\.\s*use_threads\s*=\s*(?!=)(?!true\b)\S")


@dataclasses.dataclass
class Source:
    """One GDScript file, read once: where it is and its lines two ways."""

    label: str
    in_addon: bool
    is_validator: bool
    is_probe: bool
    code: list[str]          # comments and strings blanked
    uncommented: list[str]   # comments removed, strings kept


def gdscript_files(godot: pathlib.Path) -> list[pathlib.Path]:
    """Every .gd file this project authors, vendored code excluded."""
    return [path for path in sorted(godot.rglob("*.gd")) if not is_skipped(path, godot)]


def scene_files(godot: pathlib.Path) -> list[pathlib.Path]:
    """Every scene and text resource this project authors."""
    found = list(godot.rglob("*.tscn")) + list(godot.rglob("*.tres"))
    return [path for path in sorted(found) if not is_skipped(path, godot)]


def is_skipped(path: pathlib.Path, godot: pathlib.Path) -> bool:
    """Vendored code, or anything under a dot folder below `godot/`."""
    folders = path.relative_to(godot).parts[:-1]
    return any(part in VENDORED_DIRS or part.startswith(".") for part in folders)


def strip_line(line: str, blank_strings: bool) -> str:
    """One line with its comment removed and, if asked, its strings blanked.

    A backslash inside a string escapes the next character, so `"a\\"b"` is
    one string: without that, the quote after the backslash ended it, and
    everything after it on the line was blanked as if it were a string.
    """
    kept = []
    quote = ""
    escaped = False
    for character in line:
        if quote:
            kept.append(" " if blank_strings else character)
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == quote:
                quote = ""
            continue
        if character in "\"'":
            quote = character
            kept.append(" " if blank_strings else character)
            continue
        if character == "#":
            break
        kept.append(character)
    return "".join(kept)


def read_source(path: pathlib.Path, root: pathlib.Path) -> Source:
    """The file at `path`, with where it stands relative to the door."""
    relative = path.relative_to(root)
    lines = path.read_text(encoding="utf-8").splitlines()
    return Source(
        label=relative.as_posix(),
        in_addon=relative.parts[:len(ADDON.parts)] == ADDON.parts,
        is_validator=relative == VALIDATOR,
        is_probe=relative == PROBE,
        code=[strip_line(line, blank_strings=True) for line in lines],
        uncommented=[strip_line(line, blank_strings=False) for line in lines],
    )


def check_file(source: Source, reply_uid: str) -> list[str]:
    """V1 and V2 on one file; V3 on the addon's, and the waiting loops anywhere."""
    findings = []
    for number, (code, text) in enumerate(zip(source.code, source.uncommented), start=1):
        place = f"{source.label}:{number}"
        if not source.in_addon:
            findings += reaching_a_model(place, code, source.is_probe)
            findings += reading_the_model(place, code, text)
        if not source.is_validator:
            findings += making_a_reply(place, code, text, reply_uid)
    if source.in_addon:
        findings += waits_in_the_addon(source)
    findings += waiting_loops(source)
    return findings


def reaching_a_model(place: str, code: str, is_probe: bool) -> list[str]:
    """V1, on one line outside the addon."""
    findings = [f"V1 {place} uses {found} outside ai_llm; "
                "a model's text must arrive through an LlmRuntime"
                for found in NETWORK_RE.findall(code)
                if not (is_probe and found in PROBE_MAY_USE)]
    if PROCESS_RE.search(code):
        findings.append(f"V1 {place} runs another program outside ai_llm; "
                        "a model's text must arrive through an LlmRuntime")
    return findings


def reading_the_model(place: str, code: str, text: str) -> list[str]:
    """V2's reads, on one line outside the addon."""
    findings = []
    if RAW_TEXT_RE.search(code) or RAW_TEXT_NAMED_RE.search(text):
        findings.append(f"V2 {place} reads a reply's raw_text; show `refusal`, "
                        "act on `intent` and `argument`")
    if REPLIED_RE.search(code) or REPLIED_NAMED_RE.search(text):
        findings.append(f"V2 {place} listens to a runtime's `replied`, the text no "
                        "validator saw; listen to LlmConversation.answered")
    if TEXT_OF_RE.search(code):
        findings.append(f"V2 {place} takes a model's text out of a server's answer itself")
    if SUBCLASS_RE.search(code) or VALIDATOR_PATH_RE.search(text):
        findings.append(f"V2 {place} extends the door itself: a subclass of LlmReply "
                        "forges a reply, one of LlmValidator can rule anything in")
    return findings


def making_a_reply(place: str, code: str, text: str, reply_uid: str) -> list[str]:
    """V2's construction, on one line anywhere but the validator."""
    loads = REPLY_PATH_RE.search(text) or (reply_uid and reply_uid in text)
    if REPLY_NEW_RE.search(code) or REPLY_ALIAS_RE.search(code) or loads:
        return [f"V2 {place} builds an LlmReply, or reaches for its class to; "
                "only LlmValidator may"]
    return []


def waits_in_the_addon(source: Source) -> list[str]:
    """V3, on one file of the addon."""
    findings = []
    function = ""
    for number, line in enumerate(source.code, start=1):
        place = f"{source.label}:{number}"
        declared = FUNC_RE.match(line)
        if declared:
            function = declared.group(1)
        if DELAY_RE.search(line) or PROCESS_RE.search(line) or SEMAPHORE_RE.search(line):
            findings.append(f"V3 {place} stops the thread the frame runs on")
        if WAIT_RE.search(line) and function not in TEARDOWN:
            findings.append(f"V3 {place} waits for a thread in {function or 'the file'}, "
                            "not in teardown; that wait is a frame")
        if THREADS_NOT_TRUE_RE.search(line):
            findings.append(f"V3 {place} sets use_threads to something other than true")
        if WHILE_RE.match(line):
            body = " ".join(loop_of(source.code, number - 1))
            if POLL_RE.search(body) or not AWAIT_RE.search(body):
                findings.append(f"V3 {place} is a loop that polls or never yields; "
                                "let a signal say when")
    findings += requests_without_threads(source)
    return findings


def waiting_loops(source: Source) -> list[str]:
    """V3, anywhere: a loop spinning the frame until the model has answered."""
    findings = []
    for number, line in enumerate(source.code, start=1):
        if not WHILE_RE.match(line):
            continue
        body = " ".join(loop_of(source.code, number - 1))
        if WAITING_ON_MODEL_RE.search(body) and not AWAIT_RE.search(body):
            findings.append(f"V3 {source.label}:{number} spins until the model answers; "
                            "draw it thinking and wait for `answered`")
    return findings


def loop_of(code: list[str], start: int) -> list[str]:
    """The `while` line at `start` and the lines indented under it."""
    indent = len(code[start]) - len(code[start].lstrip())
    body = [code[start]]
    for line in code[start + 1:]:
        if line.strip() and len(line) - len(line.lstrip()) <= indent:
            break
        body.append(line)
    return body


def requests_without_threads(source: Source) -> list[str]:
    """V3: every HTTPRequest made here is assigned, and that name gets threads."""
    whole = "\n".join(source.code)
    findings = []
    for number, line in enumerate(source.code, start=1):
        if not REQUEST_NEW_RE.search(line):
            continue
        assigned = ASSIGNED_RE.search(line)
        if not assigned:
            findings.append(f"V3 {source.label}:{number} makes an HTTPRequest without a "
                            "name to set use_threads on")
            continue
        name = assigned.group(1).split(".")[-1]
        if not re.search(rf"\b{re.escape(name)}\s*\.\s*use_threads\s*=\s*true\b", whole):
            findings.append(f"V3 {source.label}:{number} makes an HTTPRequest, `{name}`, "
                            "and never sets use_threads = true on it")
    return findings


def check_scene(path: pathlib.Path, root: pathlib.Path) -> list[str]:
    """V1 and V3 for a network node declared in a scene or resource."""
    relative = path.relative_to(root)
    text = path.read_text(encoding="utf-8")
    if relative.parts[:len(ADDON.parts)] == ADDON.parts:
        if 'type="HTTPRequest"' in text:
            return [f"V3 {relative.as_posix()} declares an HTTPRequest in a scene; make "
                    "it in code, where use_threads can be read"]
        return []
    return [f"V1 {relative.as_posix()} declares a {found} node outside ai_llm"
            for found in NODE_TYPE_RE.findall(text)]


def missing_door(root: pathlib.Path) -> list[str]:
    """V0: the addon, and the two files every rule here is about."""
    if not (root / ADDON).is_dir():
        return [f"V0 no {ADDON.as_posix()}/ -- invariant 7's rules have nothing to hold"]
    return [f"V0 no {path.as_posix()} -- the door these rules guard is not there"
            for path in (VALIDATOR, REPLY) if not (root / path).is_file()]


def reply_uid(root: pathlib.Path) -> str:
    """The uid Godot gave llm_reply.gd, which a preload can name instead of its path."""
    uid_file = root / (REPLY.as_posix() + ".uid")
    return uid_file.read_text(encoding="utf-8").strip() if uid_file.is_file() else ""


def check(root: pathlib.Path) -> list[str]:
    """Every finding in the repository at `root`."""
    findings = missing_door(root)
    if findings:
        return findings
    uid = reply_uid(root)
    for path in gdscript_files(root / GODOT):
        findings += check_file(read_source(path, root), uid)
    for path in scene_files(root / GODOT):
        findings += check_scene(path, root)
    return findings


def run(root: pathlib.Path) -> int:
    findings = check(root)
    for finding in findings:
        print(finding)
    return 1 if findings else 0


# --- self-test -------------------------------------------------------------


SOUND_ADDON = {
    "godot/addons/ai_llm/llm_reply.gd": "class_name LlmReply\nextends RefCounted\n",
    "godot/addons/ai_llm/llm_reply.gd.uid": "uid://d3ya824nxkc2x\n",
    "godot/addons/ai_llm/llm_validator.gd": (
        "class_name LlmValidator\nextends RefCounted\n\n\n"
        "func validate(raw_text: String) -> LlmReply:\n"
        "\treturn LlmReply.new(raw_text, \"greet\", \"\", \"\", raw_text)\n"),
    "godot/addons/ai_llm/http_runtime.gd": (
        "class_name HttpRuntime\nextends Node\n\nsignal replied(raw_text: String)\n\n"
        "var _request: HTTPRequest = null\n\n\n"
        "func _ready() -> void:\n\t_request = HTTPRequest.new()\n"
        "\t_request.use_threads = true\n\tadd_child(_request)\n\n\n"
        "func log_of(reply: LlmReply) -> String:\n\treturn reply.raw_text\n\n\n"
        "func _answer_later() -> void:\n\tvar frames: int = 2\n"
        "\twhile frames > 0:\n\t\tawait get_tree().process_frame\n\t\tframes -= 1\n"
        "\treplied.emit(\"\")\n\n\n"
        "func _exit_tree() -> void:\n\t_worker.wait_to_finish()\n"),
    "godot/game/talk/guard.gd": (
        "extends Node\n\n# Never an HTTPRequest here: the conversation asks.\n"
        "var label: String = \"HTTPRequest is the addon's\"\n"
        "var quoted: String = \"say \\\"hi\\\"\"\n"
        "var reply_type: LlmReply = null\n\n\n"
        "func show(reply: LlmReply) -> String:\n\treturn reply.speech\n\n\n"
        "func wait(conversation: LlmConversation) -> void:\n"
        "\twhile conversation.is_thinking():\n\t\tawait get_tree().process_frame\n"),
    "godot/test/ai_llm/http_frame_probe.gd": (
        "extends SceneTree\n\n\nfunc _init() -> void:\n"
        "\tvar request := HTTPRequest.new()\n\trequest.use_threads = false\n"),
}

GAME = "godot/game/talk/sneaky.gd"
ADDON_FILE = "godot/addons/ai_llm/extra.gd"


def _game(body: str) -> dict[str, str]:
    """A game script whose `_ready` holds `body`."""
    return {GAME: "extends Node\n\n\nfunc _ready() -> void:\n" + body}


def _in_addon(body: str) -> dict[str, str]:
    """An addon script whose `act` holds `body`."""
    return {ADDON_FILE: "extends Node\n\nvar _done: bool = false\n\n\nfunc act() -> void:\n" + body}


# Each planted case: (label, files added to the sound tree, the finding code).
PLANTED = [
    ("a game script that opens its own HTTPRequest", _game("\tadd_child(HTTPRequest.new())\n"), "V1"),
    ("a game script with a raw TCP stream", _game("\tvar peer := StreamPeerTCP.new()\n"), "V1"),
    ("a game script with a UDP socket", _game("\tvar peer := PacketPeerUDP.new()\n"), "V1"),
    ("a game script that runs a model's program",
     _game("\tOS.execute(\"llama-cli\", [\"-p\", \"hello\"], [])\n"), "V1"),
    ("an HTTPRequest after an escaped quote on the same line",
     _game("\tvar said := \"a\\\"b\"; add_child(HTTPRequest.new())\n"), "V1"),
    ("an HTTPRequest in the example readers copy, beside the probe",
     {"godot/test/ai_llm/gatekeeper_example.gd": "extends Node\n\n\nfunc _ready() -> void:\n"
                                                 "\tadd_child(HTTPRequest.new())\n"}, "V1"),
    ("a game scene with an HTTPRequest node",
     {"godot/game/talk/talk.tscn": '[node name="Ask" type="HTTPRequest" parent="."]\n'}, "V1"),
    ("a game script that builds an LlmReply by hand",
     _game("\tvar made := LlmReply.new(\"Go in.\", \"open\", \"\", \"\", \"\")\n"), "V2"),
    ("a game script that aliases LlmReply to build one",
     {GAME: "extends Node\n\nconst Made := LlmReply\n"}, "V2"),
    ("a game script that loads llm_reply.gd by path",
     {GAME: "extends Node\n\nconst Reply := preload(\"res://addons/ai_llm/llm_reply.gd\")\n"}, "V2"),
    ("a game script that loads llm_reply.gd by uid",
     {GAME: "extends Node\n\nconst Reply := preload(\"uid://d3ya824nxkc2x\")\n"}, "V2"),
    ("an addon file other than the validator that builds an LlmReply",
     _in_addon("\tvar made := LlmReply.new(\"\", \"\", \"\", \"\", \"\")\n"), "V2"),
    ("a game script that reads a reply's raw text",
     _game("\tprint(reply.raw_text)\n"), "V2"),
    ("a game script that reads raw_text by name",
     _game("\tprint(reply.get(\"raw_text\"))\n"), "V2"),
    ("a game script listening to a runtime's replied",
     _game("\truntime.replied.connect(_on_text)\n"), "V2"),
    ("a game script connecting replied by name",
     _game("\t$Runtime.connect(\"replied\", _on_text)\n"), "V2"),
    ("a game script extending LlmReply to forge one",
     {GAME: "extends LlmReply\n\n\nfunc _init() -> void:\n\tsuper(\"a\", \"open\", \"\", \"\", \"\")\n"},
     "V2"),
    ("a game script extending LlmValidator to let anything in",
     {GAME: "extends LlmValidator\n\n\nfunc _why_shape_is_wrong(_data: Dictionary) -> String:\n"
            "\treturn \"\"\n"}, "V2"),
    ("a game script extending the validator by path",
     {GAME: "extends \"res://addons/ai_llm/llm_validator.gd\"\n"}, "V2"),
    ("a game script taking the text out of a server's answer",
     _game("\tvar text: String = HttpRuntime._text_of(body)[\"text\"]\n"), "V2"),
    ("a game spinning until the model answers",
     _game("\twhile conversation.is_thinking():\n\t\tOS.delay_msec(10)\n"), "V3"),
    ("a while loop polling an HTTPClient in the addon",
     {ADDON_FILE: "extends RefCounted\n\nvar client := HTTPClient.new()\n\n\n"
                  "func wait() -> void:\n"
                  "\twhile client.get_status() == HTTPClient.STATUS_REQUESTING:\n"
                  "\t\tclient.poll()\n\t\tawait Engine.get_main_loop().process_frame\n"}, "V3"),
    ("a busy loop in the addon that never yields",
     _in_addon("\twhile not _done:\n\t\tpass\n"), "V3"),
    ("an HTTPRequest created without use_threads",
     {"godot/addons/ai_llm/http_runtime.gd": SOUND_ADDON["godot/addons/ai_llm/http_runtime.gd"]
      .replace("\t_request.use_threads = true\n", "")}, "V3"),
    ("use_threads set true, then false",
     {"godot/addons/ai_llm/http_runtime.gd": SOUND_ADDON["godot/addons/ai_llm/http_runtime.gd"]
      .replace("\tadd_child(_request)\n", "\t_request.use_threads = false\n\tadd_child(_request)\n")},
     "V3"),
    ("an HTTPRequest made with no name to set threads on",
     _in_addon("\tadd_child(HTTPRequest.new())\n"), "V3"),
    ("a sleep in the addon", _in_addon("\tOS.delay_msec(50)\n"), "V3"),
    ("another program run in the addon", _in_addon("\tOS.execute(\"curl\", [], [])\n"), "V3"),
    ("a semaphore in the addon", _in_addon("\tvar gate := Semaphore.new()\n\tgate.wait()\n"), "V3"),
    ("wait_to_finish outside teardown",
     _in_addon("\tvar worker := Thread.new()\n\tworker.wait_to_finish()\n"), "V3"),
    ("an HTTPRequest declared in an addon scene",
     {"godot/addons/ai_llm/ask.tscn": '[node name="Ask" type="HTTPRequest" parent="."]\n'}, "V3"),
]

# Everything planted above, at once, in vendored code and the import cache.
EVERY_SIN = (
    "extends Node\n\nconst Made := LlmReply\n\nvar peer := StreamPeerTCP.new()\n\n\n"
    "func _ready() -> void:\n"
    "\tadd_child(HTTPRequest.new())\n\tOS.delay_msec(50)\n\tOS.execute(\"curl\", [], [])\n"
    "\tvar forged := LlmReply.new(\"\", \"\", \"\", \"\", \"\")\n\tprint(forged.raw_text)\n"
    "\truntime.replied.connect(_ready)\n"
    "\twhile peer.get_status() == 1:\n\t\tpeer.poll()\n"
    "\twhile conversation.is_thinking():\n\t\tpass\n")


def self_test() -> int:
    failures = []

    def quiet(root: pathlib.Path) -> tuple[int, str]:
        stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            return run(root), stream.getvalue()

    def build(base: pathlib.Path, name: str, files: dict[str, str]) -> pathlib.Path:
        root = base / name
        for relative, text in files.items():
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
        return root

    def expect(label: str, got: tuple[int, str], want: int, code: str = "") -> None:
        exit_code, output = got
        if exit_code != want:
            failures.append(f"{label}: expected exit {want}, got {exit_code} ({output!r})")
        elif code and not output.startswith(code) and f"\n{code} " not in output:
            failures.append(f"{label}: expected a {code} finding, got {output.strip()!r}")

    with tempfile.TemporaryDirectory() as workspace:
        base = pathlib.Path(workspace)
        # The shape the project promises: the door, a game that uses it and
        # waits by yielding, the probe that measures HTTPRequest, and prose,
        # escaped quotes and strings that name what code may not use.
        expect("the sound tree", quiet(build(base, "sound", SOUND_ADDON)), 0)
        for number, (label, files, code) in enumerate(PLANTED):
            planted = build(base, f"planted{number}", {**SOUND_ADDON, **files})
            expect(f"planted: {label}", quiet(planted), 1, code)
        vendored = build(base, "vendored", {
            **SOUND_ADDON,
            "godot/addons/gdUnit4/src/everything.gd": EVERY_SIN,
            "godot/.godot/cache/everything.gd": EVERY_SIN,
        })
        expect("vendored code and the import cache doing all of it", quiet(vendored), 0)
        no_addon = {path: text for path, text in SOUND_ADDON.items() if "ai_llm" not in path}
        expect("no ai_llm addon at all", quiet(build(base, "absent", no_addon)), 1, "V0")
        hollow = {path: text for path, text in SOUND_ADDON.items()
                  if path != "godot/addons/ai_llm/llm_validator.gd"}
        expect("an addon with no validator in it", quiet(build(base, "hollow", hollow)), 1, "V0")

        script = pathlib.Path(__file__).resolve()
        for argv, label in ((["--unknown-flag"], "unknown flag"),
                            (["--root", str(base / "nowhere")], "a root that is not there")):
            extra = subprocess.run([sys.executable, str(script), *argv], capture_output=True)
            if extra.returncode != 2:
                failures.append(f"{label}: expected exit 2, got {extra.returncode}")

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("--root", default=None)
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        if exit_request.code == 0:
            raise
        return 2

    if args.self_test:
        return self_test()

    root = pathlib.Path(args.root) if args.root else pathlib.Path(__file__).resolve().parent.parent
    if not (root / GODOT).is_dir():
        print(f"check_llm_validated: no {GODOT}/ under {root}", file=sys.stderr)
        return 2
    try:
        return run(root.resolve())
    except (OSError, UnicodeDecodeError) as error:
        print(f"check_llm_validated: cannot read a file: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
