#!/usr/bin/env python3
"""Hold the half of invariant 13 that a command can hold.

The rule
--------
Every example in the kit can be watched, and shows the AI deciding rather than
only what it decided. A command cannot look at a screen -- `--headless`
rasterises nothing on the pinned engine -- so this gate holds the structure
that makes watching possible, and `test/menu/demo_overlays.gd` holds the half that
needs the engine:

  * an example is a Makefile target: `run`, or `demo-<name>`, with a `##` line
    so `make help` lists it;
  * its recipe names a scene (`run` uses the project's main scene) and the
    scene exists;
  * the scene carries a `Legend` (`res://game/legend.gd`), because a coloured
    square means nothing to somebody who did not write it;
  * its root script offers `step_decision()` and `decision_overlay()` -- one
    decision at a time, and what the AI is reasoning with;
  * the scene is listed in `test/menu/demo_overlays.gd`, so the engine half cannot
    be skipped by an example nobody added there.

Finding no example at all is a finding: a gate that passes on an empty
Makefile is the defect invariant 4 is about.

And the half of T24 a command can hold -- every example is *reachable*, from
the menu the executable opens on. `godot/menu/catalogue.json` is the one list
the menu and this gate share:

  * every example target has exactly one card, and every card a target (C2),
    opening the scene its target opens (C3);
  * every card says what the AI decides, what to watch and where to read
    more, names at least one technique with a line on its part (C4), and its
    page exists (C5);
  * every technique is one the catalogue defines (C6), and one of the
    classes the catalogue names as its evidence is reachable from the scene
    -- its scripts, the scenes it instances, and every class those use in
    code: constructed, called or extended, while comments, strings, type
    annotations and constant reads do not count (C7). That is "reachable by
    use", the most a reading can hold; whether the scene takes that path at
    run time is the card's manual check;
  * no script an example reaches calls quit(), which would take the menu
    down with it (C8);
  * a card that lists the `controllers` its example offers names the
    `roster` its game cycles them from, and the two agree: every name listed
    is a row of that table, every row is listed, in the table's order and
    once each (C9). A row
    is a line opening a list with its name as a string literal, which is how
    `TacticalRoster` writes them (T63); one in a comment is not a row;
  * a card whose example plays in several `modes` (T85) names, for each, the
    mode's key, its title, the `ruleset` script the menu builds it from, and
    its own `controllers` and `roster`, held to each other as above (C9) --
    and lists no controllers outside them. A technique reached only through
    a mode's ruleset counts as reached (C7): the menu hands the scene that
    ruleset, which is the only way the scene ever runs it;
  * a target may open its card's mode instead, when `MODE` is given:
    `$(if $(MODE),-- --open=<itself> --mode=$(MODE),res://<scene>)` -- the
    main scene, the menu, straight into its own card; any other card is a D3.
    After `--mode=$(MODE)` it may pass `$(if $(VIEW), --view=$(VIEW))`, the
    view the example opens in -- the tactical card's teaching view, which
    starts XCOM with the computer's reasoning on the board (T124). A view a
    person must ask for is one they must be told of: the card's `watch`
    line then names `VIEW=`, or it is a C10. Only that it names one: which
    values the scene reads is the scene's, which refuses an unknown one
    aloud at run time (`TacticalGame.unknown_view`), so a watch line saying
    `VIEW=teaching` passes here (wave 191's review).

Exit codes
----------
0   every example has its window, its legend and its decision
1   findings (each printed with a code)
2   wrong usage, or a file that cannot be read

Usage
-----
    check_demos.py [--root PATH]
    check_demos.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import io
import json
import pathlib
import re
import sys
import tempfile

#: Any target line that looks like an example, however it is spelled, so a
#: misspelt or doubled one is a finding rather than invisible.
LOOKS_LIKE_AN_EXAMPLE = re.compile(r"^((?:run|demo[-_][\w-]*)(?:\s+[\w$()-]+)*)\s*:(?!=)(.*)$",
                                   re.MULTILINE)
GOOD_NAME = re.compile(r"^(run|demo-[a-z0-9-]+)$")

#: The one recipe an example may have: open the project in a window, on a
#: scene or (for `run`) on its main scene. `--headless` is no window.
WINDOW_RECIPE = re.compile(r"^\t@?\$\(GODOT\) --path godot(?: res://(\S+\.tscn))?$")
#: The same, opening the menu on its own card in a mode when MODE is given.
MODE_RECIPE = re.compile(r"^\t@?\$\(GODOT\) --path godot \$\(if \$\(MODE\),-- --open=(\S+) "
                         r"--mode=\$\(MODE\)(\$\(if \$\(VIEW\), --view=\$\(VIEW\)\))?,res://(\S+\.tscn)\)$")

MAIN_SCENE = re.compile(r'^run/main_scene\s*=\s*"res://([^"]+)"', re.MULTILINE)
# The header is the whole line up to its *last* bracket: `groups=["x"]` puts a
# bracket inside the attributes, and stopping at the first lost the body.
SECTION = re.compile(r"^\[(ext_resource|node)\b([^\n]*)\]$((?:\n(?!\[)[^\n]*)*)", re.MULTILINE)
ATTRIBUTE = re.compile(r'(\w+)=("[^"]*"|\S+)')
SCRIPT_LINE = re.compile(r'^script = ExtResource\("([^"]+)"\)', re.MULTILINE)
TRIPLE_QUOTED = re.compile(r'"""(?:.|\n)*?"""' + r"|'''(?:.|\n)*?'''")
SCENES_BLOCK = re.compile(r"^const SCENES\b[^=]*=\s*\[(.*?)\]", re.MULTILINE | re.DOTALL)

LEGEND_SCRIPT = "game/legend.gd"
CONTRACT = ("step_decision", "decision_overlay")
OVERLAYS = "godot/test/menu/demo_overlays.gd"
EXAMPLE_FOLDERS = ("game", "demos")


def recipe_of(makefile: str, target: str) -> list[str]:
    """The recipe lines of a target: every line after it that starts with a tab.

    It stops at the first line that does not. Reading up to the next blank
    line, the first version credited a target with no recipe with the scene of
    the target below it.
    """
    lines = makefile.splitlines()
    for index, line in enumerate(lines):
        if re.match(rf"^{re.escape(target)}\s*:", line):
            recipe = []
            for following in lines[index + 1:]:
                if not following.startswith("\t"):
                    break
                recipe.append(following)
            return [line for line in recipe if not line.lstrip("\t@").startswith("#")]
    return []


def scene_of(root: pathlib.Path, makefile: str, target: str) -> tuple[str | None, str]:
    """The scene a target opens, relative to `godot/`, or None and why not."""
    recipe = recipe_of(makefile, target)
    if len(recipe) == 1 and MODE_RECIPE.match(recipe[0]):
        return mode_scene_of(target, MODE_RECIPE.match(recipe[0]))
    if len(recipe) != 1 or not WINDOW_RECIPE.match(recipe[0]):
        return None, "its recipe is not one line opening the project in a window"
    named = WINDOW_RECIPE.match(recipe[0]).group(1)
    if named:
        return named, ""
    if target != "run":
        return None, "its recipe names no scene"
    main = MAIN_SCENE.search((root / "godot" / "project.godot").read_text(encoding="utf-8"))
    return (main.group(1), "") if main else (None, "the project has no main scene")


def mode_scene_of(target: str, found: re.Match) -> tuple[str | None, str]:
    """The scene a MODE recipe opens without MODE; with it, the project's
    main scene -- the menu -- opens, and must open on the target's own card."""
    card, _view, scene = found.groups()
    if card != target:
        return None, f"with MODE it opens the menu on {card}'s card, not its own"
    return scene, ""


def sections(text: str) -> list[tuple[str, dict[str, str], str]]:
    """Each `[ext_resource ...]` and `[node ...]` with its attributes and body.

    Attributes are read by name, in any order, because the editor is free to
    write `uid=` before `path=`, or `groups=` on a root node.
    """
    found = []
    for kind, attributes, body in SECTION.findall(text):
        values = {name: value.strip('"') for name, value in ATTRIBUTE.findall(attributes)}
        found.append((kind, values, body))
    return found


def strip_strings(source: str) -> str:
    """GDScript with its triple-quoted strings removed, so a function written
    inside one does not count as written."""
    return TRIPLE_QUOTED.sub('""', source)


def contract_findings(root: pathlib.Path, target: str, script_path: str) -> list[str]:
    """The two functions every example's root script must offer."""
    source = strip_strings((root / "godot" / script_path).read_text(encoding="utf-8"))
    return [f"D6 {target}: res://{script_path} has no {method}()" for method in CONTRACT
            if not re.search(rf"^func {method}\(", source, re.MULTILINE)]


def root_script(text: str) -> str | None:
    """The script on a scene's root node (the first node with no parent)."""
    parts = sections(text)
    scripts = {values.get("id"): values.get("path", "").removeprefix("res://")
               for kind, values, _ in parts if kind == "ext_resource" and values.get("type") == "Script"}
    for kind, values, body in parts:
        if kind == "node" and "parent" not in values:
            used = SCRIPT_LINE.search(body)
            return scripts.get(used.group(1)) if used else None
    return None


def legend_is_attached(text: str) -> bool:
    """True when some node actually runs the legend script."""
    parts = sections(text)
    ids = {values.get("id") for kind, values, _ in parts
           if kind == "ext_resource" and values.get("path") == f"res://{LEGEND_SCRIPT}"}
    return any(kind == "node" and (used := SCRIPT_LINE.search(body)) and used.group(1) in ids
               for kind, _, body in parts)


def check_scene(root: pathlib.Path, target: str, scene: str) -> list[str]:
    """The legend and the contract, read off one example's scene."""
    path = root / "godot" / scene
    if not path.exists():
        return [f"D4 {target}: its scene res://{scene} does not exist"]
    text = path.read_text(encoding="utf-8")
    findings = []
    if not legend_is_attached(text):
        findings.append(f"D5 {target}: res://{scene} has no node running res://{LEGEND_SCRIPT}")
    script_path = root_script(text)
    if script_path is None or not (root / "godot" / script_path).exists():
        return findings + [f"D6 {target}: res://{scene} has no script on its root node"]
    return findings + contract_findings(root, target, script_path)


def listed_scenes(root: pathlib.Path) -> set[str]:
    """The scenes in `SCENES` in the engine half, comments ignored."""
    path = root / OVERLAYS
    if not path.exists():
        return set()
    lines = [line.split("#", 1)[0] for line in path.read_text(encoding="utf-8").splitlines()]
    block = SCENES_BLOCK.search("\n".join(lines))
    return set(re.findall(r'"res://([^"]+\.tscn)"', block.group(1))) if block else set()


def example_scenes_on_disk(root: pathlib.Path) -> set[str]:
    """Every scene under game/ or demos/ whose root script offers step_decision.

    An example the Makefile never mentions is invisible to every other rule
    here, so the disk is asked as well.
    """
    found = set()
    for folder in EXAMPLE_FOLDERS:
        for scene in sorted((root / "godot" / folder).rglob("*.tscn")):
            script_path = root_script(scene.read_text(encoding="utf-8"))
            script = root / "godot" / script_path if script_path else None
            if script and script.exists() and "func step_decision(" in strip_strings(script.read_text(encoding="utf-8")):
                found.add(scene.relative_to(root / "godot").as_posix())
    return found


# --- the catalogue (T24) -----------------------------------------------------
#
# T21 made every example watchable; the catalogue makes every example
# reachable, from the menu the executable opens on. It is one file, read by
# the menu and by this gate, because a list kept in two places is a list that
# will one day differ.

CATALOGUE = "godot/menu/catalogue.json"
CARD_TEXT = ("title", "decides", "watch", "docs")
#: What a card's mode names (T85).
MODE_FIELDS = ("mode", "title", "ruleset", "controllers", "roster")

#: A row of a controller table: a line opening a list, its name the first
#: element, written as a literal.
ROSTER_ROW = re.compile(r'^\s*\[\s*"([^"]+)"\s*,', re.MULTILINE)
#: Folders whose scripts are not part of any example: the test framework and
#: the tests themselves, which reference everything.
NOT_EXAMPLE_CODE = ("addons/gdUnit4/", "test/")
CLASS_NAME = re.compile(r"^class_name\s+(\w+)", re.MULTILINE)
RESOURCE_PATH = re.compile(r'"res://([^"]+\.(?:gd|tscn))"')
STRING = re.compile(r"'(?:\\.|[^'\\\n])*'|\"(?:\\.|[^\"\\\n])*\"")
#: An example takes the window down with it: the menu could not come back.
#: `quit(` called, or "quit" named as a string -- `call("quit")` -- which is
#: why it is read with strings kept (wave 59's review).
QUITS = re.compile(r"""\bquit\s*\(|["']quit["']""")
#: A class named only as a type -- `: X`, `-> X`, `as X`, `is X`, `[X]` --
#: or only to read one of its constants, `X.SOME_NUMBER`, is not a class the
#: scene runs. Wave 59's review: the behaviour demo read one constant of
#: `StealthWorld`, and so "reached" the influence map it never builds.
TYPE_ONLY = re.compile(r"(?::|->|\bas\b|\bis\b|\[|,)\s*[A-Z]\w*(?=\s*[\],=)\n:]|\s*$)", re.MULTILINE)
CONSTANT_READ = re.compile(r"\b[A-Z]\w*\.[A-Z][A-Z0-9_]*\b(?!\s*\()")


def code_of(source: str, keep_strings: bool = False) -> str:
    """GDScript with its strings and comments removed: only what runs.

    A line at a time, left to right, because the two hide each other: the
    first version took strings out of the whole file first, and the
    apostrophe in a comment's "don't" opened a string that swallowed every
    line down to the next one -- and with them a class the scene does use.
    """
    return "\n".join(line_code(line, keep_strings) for line in strip_strings(source).splitlines())


def line_code(line: str, keep_strings: bool = False) -> str:
    """One line with its comment cut off, and its strings emptied unless kept."""
    kept, position = [], 0
    while position < len(line):
        character = line[position]
        if character == "#":
            break
        found = STRING.match(line, position) if character in "\"'" else None
        if found:
            kept.append(found.group(0) if keep_strings else '""')
            position = found.end()
            continue
        kept.append(character)
        position += 1
    return "".join(kept)


def project_classes(root: pathlib.Path) -> dict[str, str]:
    """Every `class_name` in the project, to the script declaring it."""
    godot = root / "godot"
    classes = {}
    for script in sorted(godot.rglob("*.gd")):
        relative = script.relative_to(godot).as_posix()
        if relative.startswith(NOT_EXAMPLE_CODE):
            continue
        found = CLASS_NAME.search(script.read_text(encoding="utf-8"))
        if found:
            classes[found.group(1)] = relative
    return classes


def references_of(root: pathlib.Path, path: str, classes: dict[str, str]) -> set[str]:
    """The scripts and scenes one file names: by path, or by a class it uses --
    constructs, calls, extends -- rather than only types a value as, or reads
    a constant of."""
    file = root / "godot" / path
    if not file.exists():
        return set()
    text = file.read_text(encoding="utf-8")
    if not path.endswith(".gd"):
        return set(RESOURCE_PATH.findall(text))
    named = set(RESOURCE_PATH.findall(code_of(text, keep_strings=True)))
    used = TYPE_ONLY.sub(" ", CONSTANT_READ.sub(" ", code_of(text)))
    words = set(re.findall(r"\b[A-Z]\w*\b", used))
    return named | {classes[word] for word in words if word in classes}


class Reach:
    """What each scene reaches, worked out once per run of the gate.

    Every card's techniques and every example's `quit()` are held against
    the same closure, and the first version walked it again for each.
    """

    def __init__(self, root: pathlib.Path) -> None:
        self.root = root
        self.classes = project_classes(root)
        self._scripts: dict[str, set[str]] = {}

    def scripts_with_modes(self, scene: str, card: dict) -> set[str]:
        """`scripts(scene)`, and every script a mode's ruleset reaches: the
        menu builds that ruleset and hands it to the scene (T85)."""
        reached = set(self.scripts(scene))
        for mode in card.get("modes") or []:
            if isinstance(mode, dict) and mode.get("ruleset"):
                reached |= self.scripts(str(mode["ruleset"]).removeprefix("res://"))
        return reached

    def scripts(self, scene: str) -> set[str]:
        """Every script reachable from `scene`: its own, the scenes it
        instances, and whatever those scripts use, followed until nothing new
        turns up. Reachable by name in code -- comments, strings, types and
        constant reads not counting -- which is the most reading can say about
        what runs."""
        if scene not in self._scripts:
            reached, waiting = set(), [scene]
            while waiting:
                path = waiting.pop()
                if path not in reached:
                    reached.add(path)
                    waiting += sorted(references_of(self.root, path, self.classes) - reached)
            self._scripts[scene] = {path for path in reached if path.endswith(".gd")}
        return self._scripts[scene]


def read_catalogue(root: pathlib.Path) -> tuple[dict | None, str]:
    """The catalogue, or None and why it cannot be used."""
    path = root / CATALOGUE
    if not path.exists():
        return None, f"C1 {CATALOGUE} does not exist: no example can be reached from the menu"
    try:
        catalogue = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as problem:
        return None, f"C1 {CATALOGUE} is not JSON: {problem}"
    if not isinstance(catalogue.get("examples"), list) or not isinstance(catalogue.get("techniques"), dict):
        return None, f"C1 {CATALOGUE} needs an `examples` list and a `techniques` table"
    return catalogue, ""


def card_findings(reach: Reach, card: dict, techniques: dict, opened: str | None) -> list[str]:
    """What is wrong with one card: its words, its page, its techniques."""
    target = card.get("target", "?")
    findings = [f"C4 {target}: the card has no {field}" for field in CARD_TEXT
                if not str(card.get(field, "")).strip()]
    scene = str(card.get("scene", "")).removeprefix("res://")
    if opened is not None and scene != opened:
        findings.append(f"C3 {target}: the card opens res://{scene}, the make target res://{opened}")
    docs = str(card.get("docs", ""))
    if docs and not (reach.root / docs).is_file():
        findings.append(f"C5 {target}: its page {docs} does not exist")
    named = card.get("techniques") or []
    if not named:
        findings.append(f"C4 {target}: the card names no technique")
    exists = scene and (reach.root / "godot" / scene).exists()
    run = reach.scripts_with_modes(scene, card) if exists else set()
    for entry in named:
        findings += technique_findings(reach, target, entry, techniques, run)
    return findings + controller_findings(reach.root, card) + mode_findings(reach.root, card)


def mode_findings(root: pathlib.Path, card: dict) -> list[str]:
    """Each of the card's modes: named, built from a ruleset that exists, and
    its controllers held to its own roster (C9)."""
    target, modes = card.get("target", "?"), card.get("modes")
    if modes is None:
        return []
    if not isinstance(modes, list) or len(modes) < 2:
        return [f"C9 {target}: `modes` lists two or more modes, or is left out"]
    if card.get("controllers") is not None or card.get("roster") is not None:
        return [f"C9 {target}: a card with modes lists its controllers under each mode, not beside them"]
    findings, keys = [], []
    for mode in modes:
        if not isinstance(mode, dict) or not all(str(mode.get(field, "")).strip() for field in MODE_FIELDS):
            findings.append(f"C9 {target}: a mode needs {', '.join(MODE_FIELDS)}")
            continue
        keys.append(mode["mode"])
        if not (root / "godot" / str(mode["ruleset"]).removeprefix("res://")).is_file():
            findings.append(f"C9 {target}: mode {mode['mode']!r}'s ruleset {mode['ruleset']} does not exist")
        else:
            findings += roster_of_ruleset(root, target, mode)
        findings += controller_findings(root, {**mode, "target": f"{target} in {mode['mode']}"})
    if len(set(keys)) != len(keys):
        findings.append(f"C9 {target}: a mode is listed twice")
    return findings


def roster_of_ruleset(root: pathlib.Path, target: str, mode: dict) -> list[str]:
    """A mode's roster is the one its ruleset builds from: the ruleset's code
    uses the roster's class. Otherwise the card would hold its controllers to
    one table while the scene cycled another (wave 119's review)."""
    roster = root / "godot" / str(mode["roster"]).removeprefix("res://")
    found = CLASS_NAME.search(roster.read_text(encoding="utf-8")) if roster.is_file() else None
    ruleset = (root / "godot" / str(mode["ruleset"]).removeprefix("res://")).read_text(encoding="utf-8")
    if found is None or not re.search(rf"\b{found.group(1)}\b", code_of(ruleset)):
        return [f"C9 {target}: mode {mode['mode']!r}'s ruleset {mode['ruleset']} does not build from its roster {mode['roster']}"]
    return []


def controller_findings(root: pathlib.Path, card: dict) -> list[str]:
    """The card's controllers against the table its game cycles them from (C9)."""
    target, listed, roster = card.get("target", "?"), card.get("controllers"), card.get("roster")
    if listed is None and roster is None:
        return []
    if not listed or not roster:
        return [f"C9 {target}: a card offering controllers names both the list and its roster"]
    path = root / "godot" / str(roster).removeprefix("res://")
    if not path.is_file():
        return [f"C9 {target}: its roster {roster} does not exist"]
    rows = ROSTER_ROW.findall(code_of(path.read_text(encoding="utf-8"), keep_strings=True))
    if not rows:
        return [f"C9 {target}: {roster} has no rows"]
    findings = [f"C9 {target}: {name!r} is on the card and is not a row of {roster}"
                for name in listed if name not in rows]
    findings += [f"C9 {target}: {name!r} is a row of {roster} and is not on the card"
                 for name in rows if name not in listed]
    if not findings and list(listed) != rows:
        findings.append(f"C9 {target}: the card lists the rows of {roster} out of order, or one twice")
    return findings


def technique_findings(reach: Reach, target: str, entry: dict, techniques: dict,
                       run: set[str]) -> list[str]:
    """One technique on a card: known, explained, and reached by the scene."""
    key = entry.get("technique", "")
    if key not in techniques:
        return [f"C6 {target}: {key!r} is not in the catalogue's techniques table"]
    findings = [] if str(entry.get("part", "")).strip() else [f"C4 {target}: {key} has no line on its part"]
    evidence = techniques[key].get("evidence", [])
    if not any(reach.classes.get(name) in run for name in evidence):
        listed = ", ".join(evidence) or "nothing"
        findings.append(f"C7 {target}: the card says {key}, and the scene runs none of {listed}")
    return findings


def quit_findings(reach: Reach, target: str, scene: str) -> list[str]:
    """An example that ends the program cannot hand the window back. Every
    script it reaches is read, the addons' too: a library that quit would take
    the menu down as surely as the example."""
    findings = []
    for script in sorted(reach.scripts(scene)):
        source = (reach.root / "godot" / script).read_text(encoding="utf-8")
        if QUITS.search(code_of(source, keep_strings=True)):
            findings.append(f"C8 {target}: res://{script} calls quit(), so the menu cannot come back")
    return findings


def offers_a_view(makefile: str, target: str) -> bool:
    """True when the target's MODE recipe passes `VIEW` on to the example."""
    recipe = recipe_of(makefile, target)
    found = MODE_RECIPE.match(recipe[0]) if len(recipe) == 1 else None
    return bool(found and found.group(2))


def view_findings(makefile: str, card: dict) -> list[str]:
    """A view the target can open, which the card's watch line never names (C10)."""
    target = card.get("target", "?")
    if offers_a_view(makefile, target) and "VIEW=" not in str(card.get("watch", "")):
        return [f"C10 {target}: its make target opens a VIEW the card's watch line does not name (VIEW=)"]
    return []


def catalogue_findings(root: pathlib.Path, scenes: dict[str, str | None]) -> list[str]:
    """Every example has exactly one card, every card an example, each honest."""
    catalogue, why = read_catalogue(root)
    if catalogue is None:
        return [why]
    makefile = (root / "Makefile").read_text(encoding="utf-8")
    reach, findings, seen = Reach(root), [], set()
    for card in catalogue["examples"]:
        target = card.get("target", "?")
        if target in seen:
            findings.append(f"C2 {target}: two cards")
        seen.add(target)
        if target not in scenes:
            findings.append(f"C2 {target}: a card with no make target")
        findings += card_findings(reach, card, catalogue["techniques"], scenes.get(target))
        findings += view_findings(makefile, card)
    for target in sorted(set(scenes) - seen):
        findings.append(f"C2 {target}: an example with no card in {CATALOGUE}")
    for target, scene in sorted(scenes.items()):
        if scene is not None:
            findings += quit_findings(reach, target, scene)
    return findings


def check(root: pathlib.Path) -> list[str]:
    """Every finding about every example."""
    makefile = (root / "Makefile").read_text(encoding="utf-8")
    declared = LOOKS_LIKE_AN_EXAMPLE.findall(makefile)
    if not declared:
        return ["D1 no example targets (run, demo-*) in the Makefile: nothing can be watched"]
    listed, opened, findings = listed_scenes(root), {}, []
    for names, rest in declared:
        if not GOOD_NAME.match(names):
            findings.append(f"D8 {names!r}: an example is one target named run or demo-<name>")
            continue
        if "##" not in rest:
            findings.append(f"D2 {names}: no `##` line, so `make help` does not list it")
        scene, why = scene_of(root, makefile, names)
        opened[names] = scene
        if scene is None:
            findings.append(f"D3 {names}: {why}")
            continue
        findings += check_scene(root, names, scene)
        if scene not in listed:
            findings.append(f"D7 {names}: res://{scene} is not in SCENES in {OVERLAYS}")
    for scene in sorted(example_scenes_on_disk(root) - set(opened.values())):
        findings.append(f"D9 res://{scene} is an example no make target opens")
    return findings + catalogue_findings(root, opened)


def run(root: pathlib.Path) -> int:
    """Print the findings; the exit code says whether there were any."""
    try:
        findings = check(root)
    except OSError as problem:
        print(f"check_demos: {problem}", file=sys.stderr)
        return 2
    for finding in findings:
        print(finding)
    if not findings:
        count = len(LOOKS_LIKE_AN_EXAMPLE.findall((root / "Makefile").read_text(encoding="utf-8")))
        print(f"check_demos: ok -- {count} examples, each with a window, a legend and its decision")
    return 1 if findings else 0


# --- the planted cases -------------------------------------------------------

SOUND_MAKEFILE = """\
.PHONY: run
run: ## Play
\t@$(GODOT) --path godot

.PHONY: demo-search
demo-search: ## Search
\t@$(GODOT) --path godot res://demos/search.tscn
"""

SOUND_SCRIPT = """\
extends Node2D

# Do not quit() here: the menu needs the window back.
var search := AStarSearch.new()

func step_decision() -> void:
\tpass

func decision_overlay() -> Dictionary:
\treturn {"x": 1}
"""


SOUND_ROSTER = """\
class_name SoundRoster
extends RefCounted

static func rows() -> Array[Array]:
\treturn [
\t\t["rules", "the baseline",
\t\t\tfunc() -> int: return 1],
\t\t["planner", "plans", func() -> int: return 2],
\t]
"""


def card(target: str, scene: str, **changes: object) -> dict:
    """One sound card, changed where a test says."""
    sound = {"target": target, "title": "An example", "scene": f"res://{scene}",
             "decides": "Where to go.", "watch": "The frontier.", "docs": "docs/concepts/search.md",
             "techniques": [{"technique": "a-star", "part": "the route"}]}
    return {**sound, **changes}


SOUND_CARDS = (card("run", "game/main.tscn"), card("demo-search", "demos/search.tscn"))


def catalogue_text(cards: tuple[dict, ...] = SOUND_CARDS) -> str:
    """A catalogue holding `cards`, with A* as its one technique."""
    return json.dumps({"techniques": {"a-star": {"name": "A*", "evidence": ["AStarSearch"]}},
                       "examples": list(cards)})


def scene_text(script: str, legend: bool = True) -> str:
    """A scene whose root runs `script`, with or without a legend."""
    lines = ['[gd_scene load_steps=3 format=3]', '',
             f'[ext_resource type="Script" path="res://{script}" id="1_root"]']
    if legend:
        lines.append(f'[ext_resource type="Script" path="res://{LEGEND_SCRIPT}" id="9_legend"]')
    lines += ['', '[node name="Root" type="Node2D"]', 'position = Vector2(1, 1)',
              'script = ExtResource("1_root")', '']
    if legend:
        lines += ['[node name="Legend" type="Control" parent="."]', 'script = ExtResource("9_legend")', '']
    return "\n".join(lines)


def build(folder: pathlib.Path, makefile: str = SOUND_MAKEFILE, search_script: str = SOUND_SCRIPT,
          legend: bool = True, listed: tuple[str, ...] = ("game/main.tscn", "demos/search.tscn"),
          scenes: tuple[str, ...] = ("game/main.tscn", "demos/search.tscn"), commented: str = "",
          detached_legend: bool = False, stray: bool = False, editor_form: bool = False,
          catalogue: str | None = catalogue_text(), roster: str = SOUND_ROSTER,
          ruleset: str | None = None) -> pathlib.Path:
    """A small repository with two examples, broken where a test says."""
    godot = folder / "godot"
    for made in ("game", "demos", "test", "menu", "addons/ai_search"):
        (godot / made).mkdir(parents=True)
    (godot / "addons/ai_search/astar.gd").write_text("class_name AStarSearch\nextends RefCounted\n", encoding="utf-8")
    (folder / "docs/concepts").mkdir(parents=True)
    (folder / "docs/concepts/search.md").write_text("# Search\n", encoding="utf-8")
    if catalogue is not None:
        (folder / CATALOGUE).write_text(catalogue, encoding="utf-8")
    (folder / "Makefile").write_text(makefile, encoding="utf-8")
    (godot / "project.godot").write_text('[application]\nrun/main_scene="res://game/main.tscn"\n',
                                         encoding="utf-8")
    (godot / "game" / "main.gd").write_text(SOUND_SCRIPT, encoding="utf-8")
    (godot / "game" / "roster.gd").write_text(roster, encoding="utf-8")
    (godot / "game" / "ruleset.gd").write_text(ruleset or SOUND_RULESET, encoding="utf-8")
    (godot / "demos" / "search.gd").write_text(search_script, encoding="utf-8")
    (godot / LEGEND_SCRIPT).write_text("class_name Legend\nextends Control\n", encoding="utf-8")
    for scene in scenes:
        script = "game/main.gd" if scene.startswith("game") else "demos/search.gd"
        (godot / scene).write_text(scene_text(script, legend or scene.startswith("game")),
                                   encoding="utf-8")
    listing = ", ".join(f'"res://{scene}"' for scene in listed)
    note = f'\n\t# not yet: "res://{commented}"\n' if commented else ""
    (folder / OVERLAYS).parent.mkdir(parents=True, exist_ok=True)
    (folder / OVERLAYS).write_text(f"const SCENES: Array[String] = [{listing}{note}]\n", encoding="utf-8")
    search = godot / "demos" / "search.tscn"
    if detached_legend and search.exists():
        text = search.read_text(encoding="utf-8")
        search.write_text(text.replace('script = ExtResource("9_legend")', ""), encoding="utf-8")
    if editor_form and search.exists():
        text = search.read_text(encoding="utf-8").replace('type="Script" path=', 'type="Script" uid="uid://abc" path=')
        search.write_text(text.replace('[node name="Root" type="Node2D"]', '[node name="Root" type="Node2D" groups=["x"]]'),
                          encoding="utf-8")
    if stray:
        (godot / "demos" / "racing.tscn").write_text(scene_text("demos/search.gd"), encoding="utf-8")
    return folder


SOUND_RULESET = """\
class_name SoundRuleset
extends RefCounted

var search := AStarSearch.new()

func roster_names() -> Array:
\treturn SoundRoster.rows()
"""

#: A ruleset that cycles some other table than the roster its mode names.
OTHER_RULESET = SOUND_RULESET.replace("SoundRoster.rows()", "[]")

#: The sound example's MODE recipe: the menu (the main scene) on its own card.
MODE_MAKEFILE = SOUND_MAKEFILE.replace(
    "\t@$(GODOT) --path godot res://demos/search.tscn",
    "\t@$(GODOT) --path godot $(if $(MODE),-- --open=demo-search --mode=$(MODE),res://demos/search.tscn)")


#: The same, passing the view it opens in on to the example (T124).
VIEW_MAKEFILE = MODE_MAKEFILE.replace("--mode=$(MODE),", "--mode=$(MODE)$(if $(VIEW), --view=$(VIEW)),")


def moded(**changes: object) -> dict:
    """The search card in two modes, each its own roster, changed where a test says."""
    modes = [{"mode": "one", "title": "One", "ruleset": "res://game/ruleset.gd",
              "controllers": ["rules", "planner"], "roster": "res://game/roster.gd"},
             {"mode": "two", "title": "Two", "ruleset": "res://game/ruleset.gd",
              "controllers": ["rules", "planner"], "roster": "res://game/roster.gd"}]
    return card("demo-search", "demos/search.tscn", modes=changes.pop("modes", modes), **changes)


def mode_cases() -> dict[str, tuple[dict, str | None]]:
    """The planted cases of a card's modes and of a MODE recipe (T85)."""
    without_astar = SOUND_SCRIPT.replace("var search := AStarSearch.new()", "var search := 1")
    sound = moded()
    one, two = sound["modes"]
    return {
        "a card in two modes": ({"catalogue": catalogue_text((SOUND_CARDS[0], sound))}, None),
        "a technique reached through a mode only": (
            {"catalogue": catalogue_text((SOUND_CARDS[0], sound)), "search_script": without_astar}, None),
        "a mode's controller that is not a row": ({"catalogue": catalogue_text((SOUND_CARDS[0], moded(
            modes=[one, {**two, "controllers": ["rules", "planner", "cheat"]}])))}, "C9"),
        "a mode's row that is not on the card": ({"catalogue": catalogue_text((SOUND_CARDS[0], moded(
            modes=[{**one, "controllers": ["rules"]}, two])))}, "C9"),
        "a mode with no ruleset": ({"catalogue": catalogue_text((SOUND_CARDS[0], moded(
            modes=[one, {k: v for k, v in two.items() if k != "ruleset"}])))}, "C9"),
        "a mode whose ruleset does not exist": ({"catalogue": catalogue_text((SOUND_CARDS[0], moded(
            modes=[one, {**two, "ruleset": "res://game/nowhere.gd"}])))}, "C9"),
        "a mode whose ruleset builds from another roster": (
            {"catalogue": catalogue_text((SOUND_CARDS[0], sound)), "ruleset": OTHER_RULESET}, "C9"),
        "a mode listed twice": ({"catalogue": catalogue_text((SOUND_CARDS[0], moded(modes=[one, one])))}, "C9"),
        "one mode only": ({"catalogue": catalogue_text((SOUND_CARDS[0], moded(modes=[one])))}, "C9"),
        "controllers beside the modes": ({"catalogue": catalogue_text((SOUND_CARDS[0], moded(
            controllers=["rules", "planner"], roster="res://game/roster.gd")))}, "C9"),
        "a MODE recipe": ({"makefile": MODE_MAKEFILE}, None),
        "a MODE recipe opening another card": (
            {"makefile": MODE_MAKEFILE.replace("--open=demo-search", "--open=run")}, "D3"),
        "a MODE recipe naming a scene for the menu": (
            {"makefile": MODE_MAKEFILE.replace("$(MODE),-- --open", "$(MODE),res://demos/search.tscn -- --open")}, "D3"),
        "a VIEW the card's watch line names": ({"makefile": VIEW_MAKEFILE, "catalogue": catalogue_text(
            (SOUND_CARDS[0], card("demo-search", "demos/search.tscn", watch="VIEW=teach shows the frontier.")))}, None),
        "a VIEW the card's watch line does not name": ({"makefile": VIEW_MAKEFILE}, "C10"),
        "a VIEW passed outside the MODE form": (
            {"makefile": VIEW_MAKEFILE.replace("$(MODE)$(if", "$(MODE) $(if")}, "D3"),
    }


def catalogue_cases() -> dict[str, tuple[dict, str | None]]:
    """The catalogue's planted cases, each with the code its rule writes."""
    search = "demos/search.tscn"
    without_astar = SOUND_SCRIPT.replace("var search := AStarSearch.new()", "var search := 1")
    offering = card("run", "game/main.tscn", controllers=["rules", "planner"], roster="res://game/roster.gd")
    return {
        "no catalogue": ({"catalogue": None}, "C1"),
        "a catalogue that is not JSON": ({"catalogue": "{"}, "C1"),
        "an example with no card": ({"catalogue": catalogue_text(SOUND_CARDS[:1])}, "C2"),
        "a card with no example": ({"catalogue": catalogue_text(SOUND_CARDS + (card("demo-racing", search),))}, "C2"),
        "two cards for one example": ({"catalogue": catalogue_text(SOUND_CARDS + (SOUND_CARDS[1],))}, "C2"),
        "a card opening another scene": (
            {"catalogue": catalogue_text((SOUND_CARDS[0], card("demo-search", "game/main.tscn")))}, "C3"),
        "a card that says nothing": ({"catalogue": catalogue_text((SOUND_CARDS[0], card("demo-search", search, decides=" ")))}, "C4"),
        "a card naming no technique": ({"catalogue": catalogue_text((SOUND_CARDS[0], card("demo-search", search, techniques=[])))}, "C4"),
        "a page that does not exist": (
            {"catalogue": catalogue_text((SOUND_CARDS[0], card("demo-search", search, docs="docs/concepts/racing.md")))}, "C5"),
        "a technique nobody defined": ({"catalogue": catalogue_text((SOUND_CARDS[0], card(
            "demo-search", search, techniques=[{"technique": "neural-network", "part": "magic"}])))}, "C6"),
        "a technique the scene never runs": ({"search_script": without_astar}, "C7"),
        "a technique only in a comment": ({"search_script": without_astar + "# AStarSearch.new()\n"}, "C7"),
        "a technique only in a string": ({"search_script": without_astar + 'const NOTE = "AStarSearch.new()"\n'}, "C7"),
        "an example that quits": ({"search_script": SOUND_SCRIPT + "\nfunc _done() -> void:\n\tget_tree().quit()\n"}, "C8"),
        "an example that quits by name": (
            {"search_script": SOUND_SCRIPT + '\nfunc _done() -> void:\n\tget_tree().call("quit")\n'}, "C8"),
        "a technique only in a single-quoted block": (
            {"search_script": without_astar + "const NOTE = '''\nAStarSearch.new()\n'''\n"}, "C7"),
        "a card offering controllers": (
            {"catalogue": catalogue_text((offering, SOUND_CARDS[1]))}, None),
        "a controller that is not a row": (
            {"catalogue": catalogue_text((card("run", "game/main.tscn", controllers=["rules", "planner", "cheat"],
                                               roster="res://game/roster.gd"), SOUND_CARDS[1]))}, "C9"),
        "a row that is not on the card": (
            {"catalogue": catalogue_text((card("run", "game/main.tscn", controllers=["rules"],
                                               roster="res://game/roster.gd"), SOUND_CARDS[1]))}, "C9"),
        "a row only in a comment": (
            {"catalogue": catalogue_text((offering, SOUND_CARDS[1])),
             "roster": SOUND_ROSTER.replace('\t\t["planner"', '\t\t# ["planner"')}, "C9"),
        "the rows out of order": (
            {"catalogue": catalogue_text((card("run", "game/main.tscn", controllers=["planner", "rules"],
                                               roster="res://game/roster.gd"), SOUND_CARDS[1]))}, "C9"),
        "a row listed twice": (
            {"catalogue": catalogue_text((card("run", "game/main.tscn", controllers=["rules", "planner", "rules"],
                                               roster="res://game/roster.gd"), SOUND_CARDS[1]))}, "C9"),
        "controllers with no roster": (
            {"catalogue": catalogue_text((card("run", "game/main.tscn", controllers=["rules"]), SOUND_CARDS[1]))}, "C9"),
        "a roster that does not exist": (
            {"catalogue": catalogue_text((card("run", "game/main.tscn", controllers=["rules", "planner"],
                                               roster="res://game/nowhere.gd"), SOUND_CARDS[1]))}, "C9"),
        "a technique only as a type": ({"search_script": without_astar + "var never: AStarSearch = null\n"}, "C7"),
        "a technique only for a constant": (
            {"search_script": without_astar + "var cost: int = AStarSearch.MAX_COST\n"}, "C7"),
    }


def self_test() -> int:
    """Each rule rejects a planted case, and the sound repository passes."""
    failures = []

    def expect(label: str, folder: pathlib.Path, want: str | None) -> None:
        with contextlib.redirect_stdout(io.StringIO()) as printed:
            code = run(folder)
        output = printed.getvalue()
        if want is None and code != 0:
            failures.append(f"{label}: expected clean, got {code}: {output}")
        if want is not None and (code != 1 or want not in output):
            failures.append(f"{label}: expected {want}, got {code}: {output}")

    cases = {
        "sound": ({}, None),
        "no examples at all": ({"makefile": ".PHONY: check\ncheck:\n\t@true\n"}, "D1"),
        "an example make help cannot list": (
            {"makefile": SOUND_MAKEFILE.replace("demo-search: ## Search", "demo-search:")}, "D2"),
        "a recipe naming no scene": (
            {"makefile": SOUND_MAKEFILE.replace(" res://demos/search.tscn", "")}, "D3"),
        "a scene that does not exist": ({"scenes": ("game/main.tscn",)}, "D4"),
        "a scene with no legend": ({"legend": False}, "D5"),
        "no step_decision": ({"search_script": SOUND_SCRIPT.replace("step_decision", "advance")}, "D6"),
        "no decision_overlay": (
            {"search_script": SOUND_SCRIPT.replace("decision_overlay", "overlay")}, "D6"),
        "a scene the engine half never opens": ({"listed": ("game/main.tscn",)}, "D7"),
        "a recipe with no window": (
            {"makefile": SOUND_MAKEFILE.replace("--path godot res://", "--headless --path godot res://")}, "D3"),
        "a recipe that only echoes": (
            {"makefile": SOUND_MAKEFILE.replace("@$(GODOT) --path godot res://", "@echo res://")}, "D3"),
        "run opening nothing": ({"makefile": SOUND_MAKEFILE.replace("\t@$(GODOT) --path godot\n", "\t@true\n")}, "D3"),
        "an empty recipe above another": (
            {"makefile": SOUND_MAKEFILE.replace(".PHONY: demo-search", "demo-racing: ## Racing\n.PHONY: demo-search")}, "D3"),
        "a scene only in a comment": ({"listed": ("game/main.tscn",), "commented": "demos/search.tscn"}, "D7"),
        "an underscore": ({"makefile": SOUND_MAKEFILE.replace("demo-search:", "demo_search:")}, "D8"),
        "two targets on one line": ({"makefile": SOUND_MAKEFILE.replace("demo-search:", "demo-search demo-racing:")}, "D8"),
        "a legend declared and not attached": ({"detached_legend": True}, "D5"),
        "the functions only in a string": (
            {"search_script": SOUND_SCRIPT.replace("func ", "func renamed_") + '\nconst DOC = """\nfunc step_decision(\nfunc decision_overlay(\n"""\n'}, "D6"),
        "an example on disk with no target": ({"stray": True}, "D9"),
        "the editor's own attribute order": ({"editor_form": True}, None),
    }
    cases.update(catalogue_cases())
    cases.update(mode_cases())
    for label, (changes, want) in cases.items():
        with tempfile.TemporaryDirectory() as temporary:
            expect(label, build(pathlib.Path(temporary), **changes), want)

    for failure in failures:
        print(f"FAIL {failure}")
    print(f"check_demos self-test: {len(cases)} cases, {len(failures)} failure(s)")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    """Parse the arguments and run the check or its self-test."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", type=pathlib.Path, default=pathlib.Path(__file__).resolve().parents[1])
    parser.add_argument("--self-test", action="store_true")
    arguments = parser.parse_args(argv)
    if arguments.self_test:
        return self_test()
    return run(arguments.root)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
