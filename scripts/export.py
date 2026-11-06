#!/usr/bin/env python3
"""Export the menu as a Linux x86_64 executable, into dist/ (T24).

What it does
------------
  1. refuses unless the release template is installed and matches the
     SHA-512 pinned below -- `make bootstrap` installs it, in the toolchain;
  2. exports the project's "Linux x86_64" preset (`godot/export_presets.cfg`)
     into `dist/game-ai-kit-linux/`: the engine binary and its `.pck`;
  3. reads the `.pck`'s own file directory and refuses a pack holding the
     tests, the test framework or a person's generated art, or missing the
     catalogue, any scene a card opens, or any JSON the repository keeps
     under godot/ -- the weights and tables the examples load at run time.
     The export filters are text, and text drifts;
  4. runs the exported binary `--headless` for a few frames and refuses a
     build that does not exit 0 or prints an engine error (`ERROR:`) on the
     way. A refused build is deleted, binary and pack, so nothing that failed
     is left in dist/ to be mistaken for one that passed;
  5. writes `BUILD` beside it: the commit it was exported from, whether
     `godot/` had changes nobody committed, and the SHA-256 of the binary and
     the pack. `release.py` ships only a build of HEAD from a clean tree whose
     files still match those hashes, because what ships is what was reviewed.

What it cannot do: open each example inside the build. The release template
refuses a scene on the command line ("compiled without support for path
overrides"), so the build proves the menu starts, and the pack check proves
everything each example loads is in it.

Why the pack is read, not the export log
----------------------------------------
The exporter prints every file it stores, and the first version of this
check read that. A progress bar is not an interface; the pack's directory
is the file format the engine itself loads, measured on 4.7.2 (format 4):
a header naming the engine version and the directory's offset, then one
entry per file -- its path, offset, size, MD5 and flags.

Exit codes
----------
0   exported, and the executable started and stopped cleanly
1   refused: no template, a template that does not match, a pack holding the
    wrong files, or an executable that failed to start
2   wrong usage, or not run inside a git checkout

Usage
-----
    export.py
    export.py --self-test
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import shutil
import struct
import subprocess
import sys
import tempfile

REPO = pathlib.Path(__file__).resolve().parent.parent
#: GAK_TOOLCHAIN, or this checkout's own `.toolchain/` (T143, docs/adr/0002).
TOOLCHAIN = pathlib.Path(os.environ.get("GAK_TOOLCHAIN") or REPO / ".toolchain")
PRESET = "Linux x86_64"
OUTPUT = REPO / "dist" / "game-ai-kit-linux"
BINARY = "game-ai-kit.x86_64"
#: The release template inside Godot_v4.7.2-stable_export_templates.tpz,
#: whose own SHA-512 `bootstrap.sh` pins. Pinned again here because this is
#: the file that becomes the executable.
TEMPLATE_SHA512 = ("08be8a6ab54c9dbadad046ab526f22e351bed43a92b3ad19436f53a9dd44267a"
                   "8a96338252ebc28f31047dd23d3e27a89a9dd0a7aefede0b3a61fb2ac66fb08c")
#: What the pack must always hold; `required_files` adds what the examples
#: load. And what must never be in it.
REQUIRED = ("menu/catalogue.json", "project.binary")
CATALOGUE = REPO / "godot" / "menu" / "catalogue.json"
FORBIDDEN = ("test/", "addons/gdUnit4/", "assets/generated/", "reports/")
#: Frames the exported binary runs before it is asked to quit.
FRAMES = 120
PACK_HEADER = struct.Struct("<4sIIIIIQQ")
PACK_ENTRY_TAIL = struct.Struct("<QQ16sI")


class Refused(Exception):
    """A reason not to ship this build, said in one sentence."""


def template_path(toolchain: pathlib.Path) -> pathlib.Path:
    """Where self-contained mode keeps the release template."""
    version = (REPO / ".godot-version").read_text(encoding="utf-8").strip().replace("-", ".")
    return toolchain / "godot" / "editor_data" / "export_templates" / version / "linux_release.x86_64"


def template_problem(path: pathlib.Path, pinned: str = TEMPLATE_SHA512) -> str:
    """Why this template must not be used, or "" when it may."""
    if not path.is_file():
        return f"no release template at {path}: run `make bootstrap`"
    found = hashlib.sha512(path.read_bytes()).hexdigest()
    if found != pinned:
        return f"{path} has SHA-512 {found[:16]}..., not the pinned {pinned[:16]}..."
    return ""


def pack_files(data: bytes) -> list[str]:
    """The paths in a `.pck`'s directory, in the order it lists them."""
    if len(data) < PACK_HEADER.size or data[:4] != b"GDPC":
        raise Refused("the .pck does not start with GDPC: not a Godot pack")
    _, _, _, _, _, _, _, directory = PACK_HEADER.unpack_from(data, 0)
    (count,), position = struct.unpack_from("<I", data, directory), directory + 4
    names = []
    for _ in range(count):
        (length,) = struct.unpack_from("<I", data, position)
        names.append(data[position + 4:position + 4 + length].rstrip(b"\0").decode("utf-8"))
        position += 4 + length + PACK_ENTRY_TAIL.size
    return names


def required_files() -> list[str]:
    """What the pack must hold: the fixed few, every scene a card opens (as
    the `.remap` the exporter writes for it), and every JSON committed under
    godot/ outside the tests -- the weights, beads and tables the examples
    read with FileAccess, which nothing else would miss until a card failed.
    Wave 59's review: excluding the beads and the weights still exported ok."""
    cards = json.loads(CATALOGUE.read_text(encoding="utf-8"))["examples"]
    scenes = [card["scene"].removeprefix("res://") + ".remap" for card in cards]
    listed = subprocess.run(["git", "ls-files", "--", "godot/*.json"], cwd=REPO, capture_output=True,
                            text=True, check=True).stdout.split()
    tables = [path.removeprefix("godot/") for path in listed if not path.startswith(("godot/test/",))]
    return sorted(set(REQUIRED) | set(scenes) | set(tables))


def pack_problems(names: list[str], required: list[str] | tuple[str, ...] = REQUIRED) -> list[str]:
    """What is wrong with a pack's contents: files missing, or files leaking."""
    problems = [f"the pack has no {needed}" for needed in required if needed not in names]
    problems += [f"the pack holds {name}, which must not ship" for name in names
                 if name.startswith(FORBIDDEN)]
    return problems


def run_godot(*arguments: str) -> subprocess.CompletedProcess:
    """Godot through `scripts/godot`, the only way this repository calls it."""
    return subprocess.run([str(REPO / "scripts" / "godot"), *arguments], cwd=REPO,
                          capture_output=True, text=True, timeout=600)


def user_data_redirect() -> dict[str, str]:
    """The NAME=PATH pairs scripts/godot gives user://, refused when it gives none.

    Without them the exported game writes ~/.local/share/godot/app_userdata/
    (measured by T83's review), so an empty or failed answer stops the export
    rather than starting the game unredirected.
    """
    return redirect_from(run_godot("--gak-print-redirect"))


def redirect_from(asked: subprocess.CompletedProcess) -> dict[str, str]:
    """The wrapper's answer read as NAME=PATH pairs; Refused if it failed or gave none."""
    pairs = [line.split("=", 1) for line in asked.stdout.splitlines() if "=" in line]
    if asked.returncode != 0 or not pairs:
        raise Refused(f"scripts/godot --gak-print-redirect gave no user:// redirect "
                      f"(exit {asked.returncode}): {asked.stderr.strip()}")
    return {name: value for name, value in pairs}


def start_problem(binary: pathlib.Path) -> str:
    """Why the exported binary did not start and stop cleanly, or ""."""
    # The exported game writes user:// like any Godot program. The same
    # redirect scripts/godot sets -- this checkout's .user-data/ (T83) --
    # asked of it rather than copied, keeps it out of the home.
    environment = {**os.environ, **user_data_redirect()}
    ran = subprocess.run([str(binary), "--headless", "--quit-after", str(FRAMES)], env=environment,
                         capture_output=True, text=True, timeout=120)
    printed = ran.stdout + ran.stderr
    if ran.returncode != 0:
        return f"{binary.name} exited {ran.returncode}:\n{printed}"
    errors = [line for line in printed.splitlines() if "ERROR" in line]
    return f"{binary.name} printed engine errors:\n" + "\n".join(errors) if errors else ""


def stamp(binary: pathlib.Path, pack: pathlib.Path) -> dict:
    """The commit this build came from, whether godot/ matched it, and the
    hashes of the two files it vouches for."""
    commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=REPO, capture_output=True,
                            text=True, check=True).stdout.strip()
    changes = subprocess.run(["git", "status", "--porcelain", "--", "godot"], cwd=REPO,
                             capture_output=True, text=True, check=True).stdout.strip()
    return {"commit": commit, "clean": changes == "",
            binary.name: hashlib.sha256(binary.read_bytes()).hexdigest(),
            pack.name: hashlib.sha256(pack.read_bytes()).hexdigest()}


def export() -> pathlib.Path:
    """Export, check and stamp the executable; the folder it is in."""
    problem = template_problem(template_path(TOOLCHAIN))
    if problem:
        raise Refused(problem)
    shutil.rmtree(OUTPUT, ignore_errors=True)
    OUTPUT.mkdir(parents=True)
    exported = run_godot("--headless", "--path", "godot", "--export-release", PRESET, str(OUTPUT / BINARY))
    binary, pack = OUTPUT / BINARY, (OUTPUT / BINARY).with_suffix(".pck")
    if exported.returncode != 0 or not binary.is_file() or not pack.is_file():
        raise Refused(f"the export did not write {BINARY} and its .pck:\n{exported.stdout}{exported.stderr}")
    problems = pack_problems(pack_files(pack.read_bytes()), required_files())
    problem = start_problem(binary)
    if problems or problem:
        shutil.rmtree(OUTPUT, ignore_errors=True)
        raise Refused("\n".join(problems + ([problem] if problem else [])))
    (OUTPUT / "BUILD").write_text(json.dumps(stamp(binary, pack)) + "\n", encoding="utf-8")
    return OUTPUT


# --- self-test ---------------------------------------------------------------

def planted_pack(names: list[str], magic: bytes = b"GDPC") -> bytes:
    """A pack with these paths in its directory, laid out as format 4 is."""
    directory = struct.pack("<I", len(names))
    for name in names:
        encoded = name.encode("utf-8")
        padded = encoded + b"\0" * (-len(encoded) % 4)
        directory += struct.pack("<I", len(padded)) + padded + PACK_ENTRY_TAIL.pack(0, 0, bytes(16), 0)
    return PACK_HEADER.pack(magic, 4, 4, 7, 2, 2, PACK_HEADER.size, PACK_HEADER.size) + directory


def redirect_cases() -> list[str]:
    """T83's review: an empty or failed redirect answer is refused, a sound one read."""
    def answer(code: int, printed: str) -> subprocess.CompletedProcess:
        return subprocess.CompletedProcess(["scripts/godot"], code, printed, "")

    failures = []
    if redirect_from(answer(0, "XDG_DATA_HOME=/big/repo/.user-data/xdg\n")) != {
            "XDG_DATA_HOME": "/big/repo/.user-data/xdg"}:
        failures.append("a sound redirect was not read back")
    for label, planted in {"an empty answer": answer(0, ""),
                           "a failed wrapper": answer(2, "XDG_DATA_HOME=/half/said\n")}.items():
        try:
            redirect_from(planted)
            failures.append(f"{label} was not refused: Godot would have written under ~")
        except Refused:
            pass
    return failures


def self_test() -> int:
    """Each refusal rejects a planted case, and the sound ones pass."""
    sound = ["project.binary", "menu/catalogue.json", "game/legend.gdc"]
    failures = []
    if pack_files(planted_pack(sound)) != sound:
        failures.append("a planted pack's directory was not read back")
    if pack_problems(sound):
        failures.append(f"a sound pack was refused: {pack_problems(sound)}")
    for label, names in {"the tests": sound + ["test/menu/menu_walk.gd"],
                         "the framework": sound + ["addons/gdUnit4/plugin.cfg"],
                         "generated art": sound + ["assets/generated/tile.png"],
                         "no catalogue": sound[:1] + sound[2:]}.items():
        if not pack_problems(pack_files(planted_pack(names))):
            failures.append(f"a pack holding {label} was not refused")
    for label, missing in {"the beads": "game/tictactoe/menace_beads.json",
                           "a card's scene": "game/checkers/checkers.tscn.remap"}.items():
        if missing not in required_files():
            failures.append(f"{label} ({missing}) is not among the files a pack must hold")
    try:
        pack_files(planted_pack(sound, magic=b"ZIPS"))
        failures.append("a file that is not a pack was read as one")
    except Refused:
        pass
    failures += template_cases() + redirect_cases()
    for failure in failures:
        print(f"FAIL {failure}")
    print(f"export self-test: 14 cases, {len(failures)} failure(s)")
    return 1 if failures else 0


def template_cases() -> list[str]:
    """No template, the wrong template, and the right one."""
    failures = []
    with tempfile.TemporaryDirectory() as temporary:
        template = pathlib.Path(temporary) / "linux_release.x86_64"
        if "no release template" not in template_problem(template):
            failures.append("a missing template was not refused")
        template.write_bytes(b"not the engine")
        if "not the pinned" not in template_problem(template):
            failures.append("a template with the wrong hash was not refused")
        if template_problem(template, hashlib.sha512(b"not the engine").hexdigest()):
            failures.append("a template matching its pin was refused")
    return failures


def main(argv: list[str]) -> int:
    """Parse the arguments and export, or run the self-test."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--self-test", action="store_true")
    arguments = parser.parse_args(argv)
    if arguments.self_test:
        return self_test()
    try:
        folder = export()
    except Refused as refusal:
        print(f"export: refused -- {refusal}", file=sys.stderr)
        return 1
    except (OSError, subprocess.CalledProcessError) as problem:
        print(f"export: {problem}", file=sys.stderr)
        return 2
    print(f"export: ok -- {folder.relative_to(REPO)}/{BINARY} started and stopped cleanly")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
