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

SCENE_TYPE = re.compile(r'\[node name="[^"]*" type="([A-Za-z0-9_]+)"')
SCRIPT_EXTENDS = re.compile(r"^\s*extends\s+([A-Za-z0-9_]+)", re.MULTILINE)

# Directories whose contents must stay 2D. addons/ is deliberately absent: an
# addon is a library and may legitimately offer 3D helpers later.
TIER_TWO_DIRS = ("game", "demos")


def check_rendering_method(project_file: pathlib.Path) -> list[str]:
    """Report a project that no longer pins the Compatibility renderer."""
    if not project_file.exists():
        return [f"R0 no project.godot at {project_file}"]

    text = project_file.read_text(encoding="utf-8")
    declared = re.search(r'renderer/rendering_method\s*=\s*"([^"]+)"', text)
    if declared is None:
        return [f"R1 {project_file} does not declare renderer/rendering_method"]
    if declared.group(1) != REQUIRED_METHOD:
        return [
            f"R2 {project_file} uses {declared.group(1)!r}; "
            f"tier 2 requires {REQUIRED_METHOD!r}"
        ]
    return []


def check_no_3d_nodes(godot_dir: pathlib.Path) -> list[str]:
    """Report any 3D node declared under the tier-2 directories."""
    findings = []
    for directory in TIER_TWO_DIRS:
        root = godot_dir / directory
        if not root.exists():
            continue
        for path in sorted(root.rglob("*")):
            if path.suffix not in (".tscn", ".gd"):
                continue
            text = path.read_text(encoding="utf-8")
            pattern = SCENE_TYPE if path.suffix == ".tscn" else SCRIPT_EXTENDS
            for found in pattern.findall(text):
                if found in THREE_D_TYPES:
                    findings.append(f"R3 {path} uses {found}; tier 2 is 2D only")
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
    except SystemExit:
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
