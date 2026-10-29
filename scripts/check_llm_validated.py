#!/usr/bin/env python3
"""Hold invariant 7: the LLM never blocks a frame, and nothing it returns
becomes an action without passing a validator.

What it holds
-------------
T92. `ai_llm` is the one door between a language model and a game: a
runtime sends the request and signals the text back, `LlmValidator` rules
on it, and only the `LlmReply` it builds reaches the game's rules. That is
true only while nothing goes round the door. This gate reads every GDScript
file under `godot/` as text -- comments and strings blanked, as
`check_no_training.py` reads them for N1 to N3 -- and refuses the three ways
round it:

  V0  there is no `godot/addons/ai_llm/`: rules about an addon that is not
      there would pass on nothing, and "found nothing" is never a pass
  V1  a script outside `ai_llm` reaches a server itself: `HTTPRequest`,
      `HTTPClient`, or a raw stream (`StreamPeerTCP`, `StreamPeerTLS`,
      `TCPServer`, `WebSocketPeer`) -- in code, or as a node in a scene. A
      game that opens its own request reads a model's text no validator saw.
      `ai_llm`'s own tests are inside: `http_frame_probe.gd` measures
      `HTTPRequest` itself, with threads off as well as on.
  V2  a reply made or read outside the door: `LlmReply.new`, or a load of
      `llm_reply.gd`, anywhere but `llm_validator.gd`; or `.raw_text` read
      outside `godot/addons/ai_llm/`. The raw text is what the model sent
      before anybody ruled on it.
  V3  something in the addon waits on the frame: `OS.delay_msec` or
      `OS.delay_usec`; `wait_to_finish` outside `_exit_tree` or
      `_notification` (teardown, when the frame is over anyway); a `while`
      loop that polls (`poll()`, `get_status()`, `Time.get_ticks_*`); an
      `HTTPRequest` made without setting `use_threads = true` on the
      variable it was assigned to -- or made where that cannot be read, in
      a scene or not assigned to a name.

What it deliberately does not do
--------------------------------
Run anything. It is static: no engine, no model, no validator. Whether
the validator refuses what it must is held by running it, which is
`make test-llm-vectors` -- both languages against spec/vectors/llm/. And a
spelling arms race is still one: a script built from strings at run time
(`ClassDB.instantiate("HTTP" + "Request")`) is not caught. What the gate
buys is that the plain spellings, the ones a person writes on a normal day,
cannot drift round the door unnoticed.

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
import io
import pathlib
import re
import subprocess
import sys
import tempfile

GODOT = pathlib.Path("godot")
ADDON = pathlib.Path("godot/addons/ai_llm")
ADDON_TESTS = pathlib.Path("godot/test/ai_llm")
VALIDATOR = ADDON / "llm_validator.gd"

# Third-party GDScript this project does not author.
VENDORED_DIRS = {"gdUnit4"}

NETWORK_CLASSES = ("HTTPRequest", "HTTPClient", "StreamPeerTCP", "StreamPeerTLS",
                   "TCPServer", "WebSocketPeer")
NETWORK_RE = re.compile(r"\b(" + "|".join(NETWORK_CLASSES) + r")\b")
SCENE_NODE_RE = re.compile(r'type="(' + "|".join(NETWORK_CLASSES) + r')"')

REPLY_NEW_RE = re.compile(r"\bLlmReply\s*\.\s*new\b")
# Read off the line with only its comment removed: the path is a string.
REPLY_LOAD_RE = re.compile(r"llm_reply\.gd")
RAW_TEXT_RE = re.compile(r"\.\s*raw_text\b")

DELAY_RE = re.compile(r"\bOS\s*\.\s*delay_(?:msec|usec)\b")
WAIT_RE = re.compile(r"\.\s*wait_to_finish\s*\(")
TEARDOWN = {"_exit_tree", "_notification"}
FUNC_RE = re.compile(r"^\s*(?:static\s+)?func\s+(\w+)")
WHILE_RE = re.compile(r"^(\s*)while\b")
POLL_RE = re.compile(r"\.\s*(?:poll|get_status)\s*\(|\bTime\s*\.\s*get_ticks_\w+")
REQUEST_NEW_RE = re.compile(r"\bHTTPRequest\s*\.\s*new\s*\(")
ASSIGNED_RE = re.compile(
    r"(?:var\s+)?([A-Za-z_][\w.]*)\s*(?::\s*[\w.]+\s*)?:?=\s*HTTPRequest\s*\.\s*new\s*\(")


def gdscript_files(godot: pathlib.Path) -> list[pathlib.Path]:
    """Every .gd file this project authors, vendored code excluded."""
    return [path for path in sorted(godot.rglob("*.gd")) if not is_skipped(path, godot)]


def scene_files(godot: pathlib.Path) -> list[pathlib.Path]:
    """Every scene this project authors."""
    return [path for path in sorted(godot.rglob("*.tscn")) if not is_skipped(path, godot)]


def is_skipped(path: pathlib.Path, godot: pathlib.Path) -> bool:
    """Vendored code, or anything under a dot folder below `godot/`."""
    folders = path.relative_to(godot).parts[:-1]
    return any(part in VENDORED_DIRS or part.startswith(".") for part in folders)


def code_lines(text: str) -> list[str]:
    """The file's lines with comments and string literals blanked out."""
    return [_strip_line(line, strings=True) for line in text.splitlines()]


def _strip_line(line: str, strings: bool) -> str:
    """One line with its comment removed and, if asked, its strings blanked."""
    kept = []
    quote = ""
    for character in line:
        if quote:
            kept.append(" " if strings else character)
            if character == quote:
                quote = ""
            continue
        if character in "\"'":
            quote = character
            kept.append(" " if strings else character)
            continue
        if character == "#":
            break
        kept.append(character)
    return "".join(kept)


def inside(path: pathlib.Path, root: pathlib.Path, folder: pathlib.Path) -> bool:
    """True when `path` is under `root / folder`."""
    try:
        path.resolve().relative_to((root / folder).resolve())
    except ValueError:
        return False
    return True


def check_file(path: pathlib.Path, root: pathlib.Path) -> list[str]:
    """V1, V2 and, inside the addon, V3, on one GDScript file."""
    text = path.read_text(encoding="utf-8")
    label = path.relative_to(root).as_posix()
    code = code_lines(text)
    in_addon = inside(path, root, ADDON)
    findings = []
    for number, line in enumerate(code, start=1):
        place = f"{label}:{number}"
        if not in_addon and not inside(path, root, ADDON_TESTS):
            for found in NETWORK_RE.findall(line):
                findings.append(f"V1 {place} uses {found} outside ai_llm; "
                                "a model's text must arrive through an LlmRuntime")
        if path.resolve() != (root / VALIDATOR).resolve():
            uncommented = _strip_line(text.splitlines()[number - 1], strings=False)
            if REPLY_NEW_RE.search(line) or REPLY_LOAD_RE.search(uncommented):
                findings.append(f"V2 {place} builds an LlmReply; only LlmValidator may")
        if not in_addon and RAW_TEXT_RE.search(line):
            findings.append(f"V2 {place} reads a reply's raw_text; show `refusal`, "
                            "act on `intent` and `argument`")
    if in_addon:
        findings += waits_on_the_frame(label, code)
    return findings


def waits_on_the_frame(label: str, code: list[str]) -> list[str]:
    """V3, on one file of the addon."""
    findings = []
    function = ""
    for number, line in enumerate(code, start=1):
        place = f"{label}:{number}"
        declared = FUNC_RE.match(line)
        if declared:
            function = declared.group(1)
        if DELAY_RE.search(line):
            findings.append(f"V3 {place} sleeps the thread the frame runs on")
        if WAIT_RE.search(line) and function not in TEARDOWN:
            findings.append(f"V3 {place} waits for a thread in {function or 'the file'}, "
                            "not in teardown; that wait is a frame")
        if WHILE_RE.match(line) and POLL_RE.search(" ".join(loop_of(code, number - 1))):
            findings.append(f"V3 {place} is a loop that polls; let a signal say when")
    findings += requests_without_threads(label, code)
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


def requests_without_threads(label: str, code: list[str]) -> list[str]:
    """V3: every HTTPRequest made here is assigned, and that name gets threads."""
    whole = "\n".join(code)
    findings = []
    for number, line in enumerate(code, start=1):
        if not REQUEST_NEW_RE.search(line):
            continue
        assigned = ASSIGNED_RE.search(line)
        if not assigned:
            findings.append(f"V3 {label}:{number} makes an HTTPRequest without a name "
                            "to set use_threads on")
            continue
        name = assigned.group(1).split(".")[-1]
        if not re.search(rf"\b{re.escape(name)}\s*\.\s*use_threads\s*=\s*true\b", whole):
            findings.append(f"V3 {label}:{number} makes an HTTPRequest, `{name}`, "
                            "and never sets use_threads = true on it")
    return findings


def check_scene(path: pathlib.Path, root: pathlib.Path) -> list[str]:
    """V1 and V3 for a network node declared in a scene rather than in code."""
    text = path.read_text(encoding="utf-8")
    label = path.relative_to(root).as_posix()
    if inside(path, root, ADDON):
        if 'type="HTTPRequest"' in text:
            return [f"V3 {label} declares an HTTPRequest in a scene; make it in code, "
                    "where use_threads can be read"]
        return []
    if inside(path, root, ADDON_TESTS):
        return []
    return [f"V1 {label} declares a {found} node outside ai_llm"
            for found in SCENE_NODE_RE.findall(text)]


def check(root: pathlib.Path) -> list[str]:
    """Every finding in the repository at `root`."""
    if not (root / ADDON).is_dir():
        return [f"V0 no {ADDON.as_posix()}/ -- invariant 7's rules have nothing to hold"]
    findings = []
    for path in gdscript_files(root / GODOT):
        findings += check_file(path, root)
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
    "godot/addons/ai_llm/llm_validator.gd": (
        "class_name LlmValidator\nextends RefCounted\n\n\n"
        "func validate(raw_text: String) -> LlmReply:\n"
        "\treturn LlmReply.new(raw_text, \"greet\", \"\", \"\", raw_text)\n"),
    "godot/addons/ai_llm/http_runtime.gd": (
        "class_name HttpRuntime\nextends Node\n\nvar _request: HTTPRequest = null\n\n\n"
        "func _ready() -> void:\n\t_request = HTTPRequest.new()\n"
        "\t_request.use_threads = true\n\tadd_child(_request)\n\n\n"
        "func log_of(reply: LlmReply) -> String:\n\treturn reply.raw_text\n\n\n"
        "func _exit_tree() -> void:\n\t_worker.wait_to_finish()\n"),
    "godot/game/talk/guard.gd": (
        "extends Node\n\n# Never an HTTPRequest here: the conversation asks.\n"
        "var label: String = \"HTTPRequest\"\n\n\n"
        "func show(reply: LlmReply) -> String:\n\treturn reply.speech\n"),
    "godot/test/ai_llm/probe.gd": (
        "extends SceneTree\n\n\nfunc _init() -> void:\n"
        "\tvar request := HTTPRequest.new()\n\trequest.use_threads = false\n"),
}

# Each planted case: (label, files added to the sound tree, the finding code).
PLANTED = [
    ("a game script that opens its own HTTPRequest",
     {"godot/game/talk/sneaky.gd": "extends Node\n\n\nfunc _ready() -> void:\n"
                                   "\tadd_child(HTTPRequest.new())\n"}, "V1"),
    ("a game script with a raw TCP stream",
     {"godot/game/talk/raw.gd": "extends Node\n\nvar peer := StreamPeerTCP.new()\n"}, "V1"),
    ("a game scene with an HTTPRequest node",
     {"godot/game/talk/talk.tscn": '[node name="Ask" type="HTTPRequest" parent="."]\n'}, "V1"),
    ("a game script that builds an LlmReply by hand",
     {"godot/game/talk/forge.gd": "extends Node\n\n\nfunc forge() -> LlmReply:\n"
                                  "\treturn LlmReply.new(\"Go in.\", \"open\", \"\", \"\", \"\")\n"}, "V2"),
    ("a game script that loads llm_reply.gd to build one",
     {"godot/game/talk/forge.gd": "extends Node\n\n"
                                  "const Reply := preload(\"res://addons/ai_llm/llm_reply.gd\")\n"}, "V2"),
    ("an addon file other than the validator that builds an LlmReply",
     {"godot/addons/ai_llm/shortcut.gd": "extends RefCounted\n\n\nfunc quick() -> LlmReply:\n"
                                         "\treturn LlmReply.new(\"\", \"\", \"\", \"\", \"\")\n"}, "V2"),
    ("a game script that reads a reply's raw text",
     {"godot/game/talk/peek.gd": "extends Node\n\n\nfunc act(reply: LlmReply) -> String:\n"
                                 "\treturn reply.raw_text\n"}, "V2"),
    ("a while loop polling an HTTPClient",
     {"godot/addons/ai_llm/poller.gd": "extends RefCounted\n\nvar client := HTTPClient.new()\n\n\n"
                                       "func wait() -> void:\n"
                                       "\twhile client.get_status() == HTTPClient.STATUS_REQUESTING:\n"
                                       "\t\tclient.poll()\n"}, "V3"),
    ("an HTTPRequest created without use_threads",
     {"godot/addons/ai_llm/http_runtime.gd": SOUND_ADDON["godot/addons/ai_llm/http_runtime.gd"]
      .replace("\t_request.use_threads = true\n", "")}, "V3"),
    ("an HTTPRequest made with no name to set threads on",
     {"godot/addons/ai_llm/inline.gd": "extends Node\n\n\nfunc _ready() -> void:\n"
                                       "\tadd_child(HTTPRequest.new())\n"}, "V3"),
    ("a sleep in the addon",
     {"godot/addons/ai_llm/nap.gd": "extends RefCounted\n\n\nfunc nap() -> void:\n"
                                    "\tOS.delay_msec(50)\n"}, "V3"),
    ("wait_to_finish outside teardown",
     {"godot/addons/ai_llm/join.gd": "extends Node\n\nvar _worker := Thread.new()\n\n\n"
                                     "func answer() -> void:\n\t_worker.wait_to_finish()\n"}, "V3"),
    ("an HTTPRequest declared in an addon scene",
     {"godot/addons/ai_llm/ask.tscn": '[node name="Ask" type="HTTPRequest" parent="."]\n'}, "V3"),
]

# Everything planted above, at once, in vendored code and the import cache.
EVERY_SIN = (
    "extends Node\n\nvar peer := StreamPeerTCP.new()\n\n\nfunc _ready() -> void:\n"
    "\tadd_child(HTTPRequest.new())\n\tOS.delay_msec(50)\n"
    "\tvar forged := LlmReply.new(\"\", \"\", \"\", \"\", \"\")\n\tprint(forged.raw_text)\n"
    "\twhile peer.get_status() == 1:\n\t\tpeer.poll()\n")


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
        # The shape the project promises: the door, a game that uses it, the
        # probe that measures HTTPRequest in the addon's own tests, and
        # prose and strings that name what code may not use.
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
        return run(root)
    except (OSError, UnicodeDecodeError) as error:
        print(f"check_llm_validated: cannot read a file: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
