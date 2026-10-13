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

#: A target that is an example, with its help text.
EXAMPLE_TARGET = re.compile(r"^(run|demo-[a-z0-9-]+):[^\n#]*##\s*(.*)$", re.MULTILINE)

#: Any target line, help or not, so an example without `##` is still seen.
ANY_TARGET = re.compile(r"^(run|demo-[a-z0-9-]+):", re.MULTILINE)

SCENE_IN_RECIPE = re.compile(r"\bres://(\S+\.tscn)")
MAIN_SCENE = re.compile(r'^run/main_scene\s*=\s*"res://([^"]+)"', re.MULTILINE)
EXT_SCRIPT = re.compile(r'\[ext_resource type="Script" path="res://([^"]+)" id="([^"]+)"\]')
ROOT_NODE = re.compile(r'^\[node name="[^"]+" type="[^"]+"\]\n(?:[^\[\n][^\n]*\n)*?script = '
                       r'ExtResource\("([^"]+)"\)', re.MULTILINE)

LEGEND_SCRIPT = "game/legend.gd"
CONTRACT = ("step_decision", "decision_overlay")
OVERLAYS = "godot/test/demo_overlays.gd"


def recipe_of(makefile: str, target: str) -> str:
    """The lines of a target's recipe, up to the next blank line."""
    start = re.search(rf"^{re.escape(target)}:.*$", makefile, re.MULTILINE)
    if start is None:
        return ""
    rest = makefile[start.end():].split("\n\n", 1)[0]
    return rest


def scene_of(root: pathlib.Path, makefile: str, target: str) -> str | None:
    """The scene a target opens, relative to `godot/`, or None."""
    found = SCENE_IN_RECIPE.search(recipe_of(makefile, target))
    if found:
        return found.group(1)
    if target == "run":
        project = (root / "godot" / "project.godot").read_text(encoding="utf-8")
        main = MAIN_SCENE.search(project)
        return main.group(1) if main else None
    return None


def check_scene(root: pathlib.Path, target: str, scene: str) -> list[str]:
    """The legend and the contract, read off one example's scene."""
    path = root / "godot" / scene
    if not path.exists():
        return [f"D4 {target}: its scene res://{scene} does not exist"]
    text = path.read_text(encoding="utf-8")
    scripts = {identifier: script for script, identifier in EXT_SCRIPT.findall(text)}
    findings = []
    if LEGEND_SCRIPT not in scripts.values():
        findings.append(f"D5 {target}: res://{scene} carries no Legend (res://{LEGEND_SCRIPT})")
    root_script = ROOT_NODE.search(text)
    script_path = scripts.get(root_script.group(1)) if root_script else None
    if script_path is None or not (root / "godot" / script_path).exists():
        return findings + [f"D6 {target}: res://{scene} has no script on its root node"]
    source = (root / "godot" / script_path).read_text(encoding="utf-8")
    for method in CONTRACT:
        if not re.search(rf"^func {method}\(", source, re.MULTILINE):
            findings.append(f"D6 {target}: res://{script_path} has no {method}()")
    return findings


def check(root: pathlib.Path) -> list[str]:
    """Every finding about every example."""
    makefile = (root / "Makefile").read_text(encoding="utf-8")
    targets = ANY_TARGET.findall(makefile)
    if not targets:
        return ["D1 no example targets (run, demo-*) in the Makefile: nothing can be watched"]
    helped = {name for name, _ in EXAMPLE_TARGET.findall(makefile)}
    overlays_path = root / OVERLAYS
    overlays = overlays_path.read_text(encoding="utf-8") if overlays_path.exists() else ""
    findings = []
    for target in targets:
        if target not in helped:
            findings.append(f"D2 {target}: no `##` line, so `make help` does not list it")
        scene = scene_of(root, makefile, target)
        if scene is None:
            findings.append(f"D3 {target}: its recipe names no scene")
            continue
        findings += check_scene(root, target, scene)
        if f'"res://{scene}"' not in overlays:
            findings.append(f"D7 {target}: res://{scene} is not in {OVERLAYS}")
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
        count = len(ANY_TARGET.findall((root / "Makefile").read_text(encoding="utf-8")))
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
          scenes: tuple[str, ...] = ("game/main.tscn", "demos/search.tscn")) -> pathlib.Path:
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
    (folder / OVERLAYS).write_text(f"const SCENES: Array[String] = [{listing}]\n", encoding="utf-8")
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
