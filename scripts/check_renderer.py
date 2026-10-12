#!/usr/bin/env python3
"""Keep the project runnable on a modest machine.

The rule
--------
Tier 2 of this project -- playing the game and opening the demos -- must run on
integrated graphics from around 2015. Two things guarantee that, and both are
easy to undo by accident:

  1. `project.godot` declares the "gl_compatibility" rendering method.
     Switching to Forward+ costs nothing today and quietly raises the hardware
     floor for everyone.
  2. Nothing under `game/` or `demos/` is a 3D node. A single Node3D pulls in
     the 3D renderer and the floor rises with it.

Why this gate exists
--------------------
Teaching material that only runs on the author's machine teaches nobody. The
hardware tiers are a promise in the README, and a promise with no gate is prose.

Exit codes
----------
0   renderer pinned, no 3D nodes found
1   violations found (each one printed)
2   wrong usage, or a file that cannot be read

Usage
-----
    check_renderer.py [--godot-dir PATH]
    check_renderer.py --self-test
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

REQUIRED_METHOD = "gl_compatibility"

# Node types that drag in the 3D renderer. Matched where a scene file declares
# a node's type, so a string in a comment or a variable name is not a finding.
THREE_D_TYPES = (
    "Node3D",
    "Camera3D",
    "MeshInstance3D",
    "CharacterBody3D",
    "RigidBody3D",
    "StaticBody3D",
    "Area3D",
    "DirectionalLight3D",
    "OmniLight3D",
    "SpotLight3D",
    "GPUParticles3D",
    "CollisionShape3D",
)

# `type=` anywhere in the node line, not immediately after `name=`: Godot
# writes `parent=` between them whenever the node is not a root, so the strict
# form matched only root nodes and a nested Camera3D passed.
SCENE_TYPE = re.compile(r'\[node\b[^\]]*\btype="([A-Za-z0-9_]+)"')
# Both ways a script reaches a 3D type: inheriting it, and constructing one.
# Only `extends` was matched, so `var world := Node3D.new()` passed.
SCRIPT_TYPE = re.compile(
    r"^\s*extends\s+([A-Za-z0-9_]+)|\b([A-Za-z0-9_]+)\.new\s*\(", re.MULTILINE
)

# Directories whose contents must stay 2D. addons/ is deliberately absent: an
# addon is a library and may legitimately offer 3D helpers later.
TIER_TWO_DIRS = ("game", "demos")


def strip_comments(text: str) -> str:
    """Drop the lines Godot ignores.

    A `.godot` file comments with `;`. An earlier version of this check read the
    first match anywhere in the file, so commenting the compliant line out and
    adding a different one below it left the gate green while the engine loaded
    the other renderer -- confirmed by asking the running engine what it had.
    Commenting a line out while trying something, and forgetting to undo it, is
    the most ordinary way this happens.
    """
    return "\n".join(line for line in text.splitlines() if not line.lstrip().startswith(";"))


def check_rendering_method(project_file: pathlib.Path) -> list[str]:
    """Report a project that no longer pins the Compatibility renderer."""
    if not project_file.exists():
        return [f"R0 no project.godot at {project_file}"]

    text = strip_comments(project_file.read_text(encoding="utf-8"))
    declared = re.findall(r'renderer/rendering_method\s*=\s*"([^"]+)"', text)
    if not declared:
        return [f"R1 {project_file} does not declare renderer/rendering_method"]

    # Every live declaration is checked, not just the first. Two of them is
    # already a problem -- whichever one the engine honours, a reader cannot
    # tell which is in force.
    findings = []
    for method in declared:
        if method != REQUIRED_METHOD:
            findings.append(
                f"R2 {project_file} uses {method!r}; tier 2 requires {REQUIRED_METHOD!r}"
            )
    if len(declared) > 1 and not findings:
        findings.append(
            f"R4 {project_file} declares renderer/rendering_method {len(declared)} times; "
            "keep one, so which is in force is readable"
        )
    return findings


def check_no_3d_nodes(godot_dir: pathlib.Path) -> list[str]:
    """Report any 3D node declared under the tier-2 directories.

    Prints a note when there is nothing to inspect. `game/` and `demos/` are
    empty while the kit is being built, so this half of the gate passes today
    by looking at no files at all -- which is worth seeing rather than reading
    as a clean result.
    """
    findings = []
    inspected = 0
    for directory in TIER_TWO_DIRS:
        root = godot_dir / directory
        if not root.exists():
            continue
        for path in sorted(root.rglob("*")):
            if path.suffix not in (".tscn", ".gd"):
                continue
            text = path.read_text(encoding="utf-8")
            inspected += 1
            pattern = SCENE_TYPE if path.suffix == ".tscn" else SCRIPT_TYPE
            for found in pattern.findall(text):
                # SCRIPT_TYPE has two groups; exactly one matches per hit.
                names = [found] if isinstance(found, str) else [n for n in found if n]
                for name in names:
                    if name in THREE_D_TYPES:
                        findings.append(f"R3 {path} uses {name}; tier 2 is 2D only")
    if inspected == 0:
        print(f"R5 note: no scenes or scripts under {'/, '.join(TIER_TWO_DIRS)}/ "
              "-- the 2D rule passed by inspecting nothing")
    return findings


def run(godot_dir: pathlib.Path) -> int:
    findings = check_rendering_method(godot_dir / "project.godot")
    findings += check_no_3d_nodes(godot_dir)
    for finding in findings:
        print(finding)
    return 1 if findings else 0


# --- self-test -------------------------------------------------------------


def self_test() -> int:
    failures = []

    def expect(label: str, got: int, want: int) -> None:
        if got != want:
            failures.append(f"{label}: expected exit {want}, got {got}")

    def quiet(path: pathlib.Path) -> int:
        with contextlib.redirect_stdout(io.StringIO()):
            return run(path)

    def make_project(root: pathlib.Path, method: str) -> pathlib.Path:
        godot_dir = root
        godot_dir.mkdir(parents=True, exist_ok=True)
        (godot_dir / "project.godot").write_text(
            f'config_version=5\n\n[rendering]\n\nrenderer/rendering_method="{method}"\n'
        )
        (godot_dir / "game").mkdir(exist_ok=True)
        (godot_dir / "demos").mkdir(exist_ok=True)
        return godot_dir

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)

        good = make_project(root / "good", REQUIRED_METHOD)
        (good / "game" / "board.tscn").write_text(
            '[node name="Board" type="Node2D"]\n'
        )
        (good / "game" / "unit.gd").write_text("extends Node2D\n\nvar hp: int = 10\n")
        expect("2D project", quiet(good), 0)

        # Planted: the renderer silently switched to Forward+.
        forward = make_project(root / "forward", "forward_plus")
        expect("forward_plus renderer", quiet(forward), 1)

        # Planted: a 3D node in a scene.
        scene3d = make_project(root / "scene3d", REQUIRED_METHOD)
        (scene3d / "demos" / "x.tscn").write_text('[node name="X" type="Node3D"]\n')
        expect("3D node in scene", quiet(scene3d), 1)

        # Planted: a script extending a 3D type.
        script3d = make_project(root / "script3d", REQUIRED_METHOD)
        (script3d / "game" / "y.gd").write_text("extends CharacterBody3D\n")
        expect("script extends 3D", quiet(script3d), 1)

        # The word "Node3D" inside a comment must NOT be a finding: a gate that
        # fires on prose gets disabled by the first person it annoys.
        prose = make_project(root / "prose", REQUIRED_METHOD)
        (prose / "game" / "z.gd").write_text(
            "extends Node2D\n\n# This kit is 2D; do not reach for Node3D here.\n"
        )
        expect("3D named in a comment", quiet(prose), 0)

        # Planted: a nested node, where Godot writes `parent=` between `name=`
        # and `type=`. The strict pattern matched only root nodes.
        nested3d = make_project(root / "nested3d", REQUIRED_METHOD)
        (nested3d / "demos" / "n.tscn").write_text(
            '[node name="Cam" parent="." type="Camera3D"]\n')
        expect("nested 3D node", quiet(nested3d), 1)

        # Planted: a 3D type constructed rather than inherited.
        constructed = make_project(root / "constructed", REQUIRED_METHOD)
        (constructed / "game" / "spawn.gd").write_text(
            "extends Node2D\n\n\nfunc _ready() -> void:\n\tvar world := Node3D.new()\n")
        expect("3D type constructed", quiet(constructed), 1)

        # Planted: the compliant line commented out, a different one below it.
        # The gate used to pass this while the engine loaded forward_plus.
        commented = make_project(root / "commented", REQUIRED_METHOD)
        (commented / "project.godot").write_text(
            f'config_version=5\n\n[rendering]\n\n'
            f';renderer/rendering_method="{REQUIRED_METHOD}"\n'
            f'renderer/rendering_method="forward_plus"\n'
        )
        expect("compliant line commented out", quiet(commented), 1)

        # Planted: declared twice, both compliant. A reader cannot tell which
        # one the engine honours, so it is a finding of its own.
        twice = make_project(root / "twice", REQUIRED_METHOD)
        (twice / "project.godot").write_text(
            f'config_version=5\n\n[rendering]\n\n'
            f'renderer/rendering_method="{REQUIRED_METHOD}"\n'
            f'renderer/rendering_method="{REQUIRED_METHOD}"\n'
        )
        expect("declared twice", quiet(twice), 1)

        # A comment that merely mentions the other renderer is not a finding.
        mentions = make_project(root / "mentions", REQUIRED_METHOD)
        (mentions / "project.godot").write_text(
            f'config_version=5\n\n; do not switch to forward_plus: it raises the floor\n'
            f'[rendering]\n\nrenderer/rendering_method="{REQUIRED_METHOD}"\n'
        )
        expect("other renderer named in a comment", quiet(mentions), 0)

        # Planted: no project file at all.
        expect("missing project.godot", quiet(root / "nowhere"), 1)

        script = pathlib.Path(__file__).resolve()
        extra = subprocess.run(
            [sys.executable, str(script), "--unknown-flag"], capture_output=True
        )
        expect("unknown flag", extra.returncode, 2)

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("--godot-dir", default=None)
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        # argparse raises SystemExit for `--help` too, with code 0. Catching it
        # blindly turned a successful --help into exit 2 in every gate here.
        if exit_request.code == 0:
            raise
        return 2

    if args.self_test:
        return self_test()

    repo = pathlib.Path(__file__).resolve().parent.parent
    godot_dir = pathlib.Path(args.godot_dir) if args.godot_dir else repo / "godot"

    try:
        return run(godot_dir)
    except OSError as error:
        print(f"check_renderer: cannot read a file: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
