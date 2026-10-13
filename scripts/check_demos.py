#!/usr/bin/env python3
"""Hold the half of invariant 13 that a command can hold.

The rule
--------
Every example in the kit can be watched, and shows the AI deciding rather than
only what it decided. A command cannot look at a screen -- `--headless`
rasterises nothing on the pinned engine -- so this gate holds the structure
that makes watching possible, and `test/demo_overlays.gd` holds the half that
needs the engine:

  * an example is a Makefile target: `run`, or `demo-<name>`, with a `##` line
    so `make help` lists it;
  * its recipe names a scene (`run` uses the project's main scene) and the
    scene exists;
  * the scene carries a `Legend` (`res://game/legend.gd`), because a coloured
    square means nothing to somebody who did not write it;
  * its root script offers `step_decision()` and `decision_overlay()` -- one
    decision at a time, and what the AI is reasoning with;
  * the scene is listed in `test/demo_overlays.gd`, so the engine half cannot
    be skipped by an example nobody added there.

Finding no example at all is a finding: a gate that passes on an empty
Makefile is the defect invariant 4 is about.

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

MAIN_SCENE = re.compile(r'^run/main_scene\s*=\s*"res://([^"]+)"', re.MULTILINE)
# The header is the whole line up to its *last* bracket: `groups=["x"]` puts a
# bracket inside the attributes, and stopping at the first lost the body.
SECTION = re.compile(r"^\[(ext_resource|node)\b([^\n]*)\]$((?:\n(?!\[)[^\n]*)*)", re.MULTILINE)
ATTRIBUTE = re.compile(r'(\w+)=("[^"]*"|\S+)')
SCRIPT_LINE = re.compile(r'^script = ExtResource\("([^"]+)"\)', re.MULTILINE)
TRIPLE_QUOTED = re.compile(r'"""(?:.|\n)*?"""')
SCENES_BLOCK = re.compile(r"^const SCENES\b[^=]*=\s*\[(.*?)\]", re.MULTILINE | re.DOTALL)

LEGEND_SCRIPT = "game/legend.gd"
CONTRACT = ("step_decision", "decision_overlay")
OVERLAYS = "godot/test/demo_overlays.gd"
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
    if len(recipe) != 1 or not WINDOW_RECIPE.match(recipe[0]):
        return None, "its recipe is not one line opening the project in a window"
    named = WINDOW_RECIPE.match(recipe[0]).group(1)
    if named:
        return named, ""
    if target != "run":
        return None, "its recipe names no scene"
    main = MAIN_SCENE.search((root / "godot" / "project.godot").read_text(encoding="utf-8"))
    return (main.group(1), "") if main else (None, "the project has no main scene")


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


def check(root: pathlib.Path) -> list[str]:
    """Every finding about every example."""
    makefile = (root / "Makefile").read_text(encoding="utf-8")
    declared = LOOKS_LIKE_AN_EXAMPLE.findall(makefile)
    if not declared:
        return ["D1 no example targets (run, demo-*) in the Makefile: nothing can be watched"]
    listed, opened, findings = listed_scenes(root), set(), []
    for names, rest in declared:
        if not GOOD_NAME.match(names):
            findings.append(f"D8 {names!r}: an example is one target named run or demo-<name>")
            continue
        if "##" not in rest:
            findings.append(f"D2 {names}: no `##` line, so `make help` does not list it")
        scene, why = scene_of(root, makefile, names)
        if scene is None:
            findings.append(f"D3 {names}: {why}")
            continue
        opened.add(scene)
        findings += check_scene(root, names, scene)
        if scene not in listed:
            findings.append(f"D7 {names}: res://{scene} is not in SCENES in {OVERLAYS}")
    for scene in sorted(example_scenes_on_disk(root) - opened):
        findings.append(f"D9 res://{scene} is an example no make target opens")
    return findings


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

func step_decision() -> void:
\tpass

func decision_overlay() -> Dictionary:
\treturn {"x": 1}
"""


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
          detached_legend: bool = False, stray: bool = False, editor_form: bool = False) -> pathlib.Path:
    """A small repository with two examples, broken where a test says."""
    godot = folder / "godot"
    (godot / "game").mkdir(parents=True)
    (godot / "demos").mkdir()
    (godot / "test").mkdir()
    (folder / "Makefile").write_text(makefile, encoding="utf-8")
    (godot / "project.godot").write_text('[application]\nrun/main_scene="res://game/main.tscn"\n',
                                         encoding="utf-8")
    (godot / "game" / "main.gd").write_text(SOUND_SCRIPT, encoding="utf-8")
    (godot / "demos" / "search.gd").write_text(search_script, encoding="utf-8")
    (godot / LEGEND_SCRIPT).write_text("class_name Legend\nextends Control\n", encoding="utf-8")
    for scene in scenes:
        script = "game/main.gd" if scene.startswith("game") else "demos/search.gd"
        (godot / scene).write_text(scene_text(script, legend or scene.startswith("game")),
                                   encoding="utf-8")
    listing = ", ".join(f'"res://{scene}"' for scene in listed)
    note = f'\n\t# not yet: "res://{commented}"\n' if commented else ""
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
