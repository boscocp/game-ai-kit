#!/usr/bin/env python3
"""Download the 3D examples' packs, and copy out only the files they use.

The rule (ADR 0018)
-------------------
Nothing from a 3D pack is committed, whole or cut. `godot/game3d/assets.json`
names each pack's page, its archive's URL and sha256, and each file used: its
path inside the archive and its own sha256. This script downloads each archive
into `build/assets-3d/` and copies the named files into
`godot/game3d/downloaded/`; git ignores both. Inside the project, so Godot
imports the models like any other asset and the editor sees them.

An archive or a file whose bytes are not the ones the manifest names is
removed and reported, never kept: a pack changed upstream would otherwise
reach the screen unreviewed. A download lands under a temporary name and is
renamed only once it matches; a file is hashed in memory before it is
written, so Godot never finds unchecked bytes in its project. A pack with no
archive URL (an itch.io page, whose links expire) is downloaded by hand into
`build/assets-3d/` under the name the manifest gives, and checked the same
way. The examples draw primitives when the folder is empty, so nothing else
depends on this having run.

`--list-members PACK` writes the sha256 of every file in a checked archive to
the list the pack's `members` names. `check_no_assets.py` reads it, so a
pack's file nobody uses -- a preview, another texture -- is caught committed
too, not only the files the manifest copies out.

Exit codes
----------
0   every file is present and matches
1   a download failed, or an archive or file did not match (it was removed)
2   wrong usage, or the manifest cannot be read

Usage
-----
    fetch_assets_3d.py [--manifest PATH] [--archives DIR] [--into DIR]
    fetch_assets_3d.py --list-members PACK
    fetch_assets_3d.py --self-test
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import pathlib
import sys
import tempfile
import urllib.request
import zipfile
from typing import Callable

#: How a URL becomes a file: `urllib.request.urlretrieve`, or a test's stand-in.
Download = Callable[[str, pathlib.Path], object]

ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "godot" / "game3d" / "assets.json"
ARCHIVES = ROOT / "build" / "assets-3d"


def sha256_of(path: pathlib.Path) -> str:
    """The file's sha256, as the manifest writes it."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def refuse_unless_matching(path: pathlib.Path, wanted: str) -> str:
    """Why `path` was refused and removed, or "" when it matches `wanted`."""
    found = sha256_of(path)
    if found == wanted:
        return ""
    path.unlink()
    return f"{path.name}: sha256 {found}, the manifest names {wanted}; removed"


def archive_for(name: str, pack: dict, archives: pathlib.Path,
                download: Download) -> tuple[pathlib.Path | None, str]:
    """The pack's checked archive on disk, or None and why not.

    An archive already there and matching is not downloaded again; one there
    and not matching is removed first, whether it was downloaded or put there
    by hand.
    """
    target = archives / f"{name}.zip"
    if target.exists():
        refusal = refuse_unless_matching(target, pack["archive_sha256"])
        if not refusal:
            return target, ""
        if not pack.get("archive"):
            return None, f"{name}: {refusal}"
    if not pack.get("archive"):
        return None, (f"{name}: no stable archive URL; download it by hand from "
                      f"{pack['page']} into {target}")
    partial = target.with_name(target.name + ".part")
    try:
        download(pack["archive"], partial)
    except OSError as error:
        partial.unlink(missing_ok=True)
        return None, f"{name}: {error}"
    refusal = refuse_unless_matching(partial, pack["archive_sha256"])
    if refusal:
        return None, f"{name}: {refusal}"
    partial.rename(target)
    return target, ""


def inside(into: pathlib.Path, saved_as: str) -> pathlib.Path | None:
    """Where `saved_as` lands under `into`, or None if it would land outside.

    The manifest is committed and reviewed, and a `..` in it is still refused:
    it is the one line that decides where bytes from the internet are written.
    """
    target = (into / saved_as).resolve()
    return target if target.is_relative_to(into.resolve()) else None


def copy_out(archive: pathlib.Path, row: dict, into: pathlib.Path) -> str:
    """Copy one manifest row out of its archive; why it failed, or ""."""
    target = inside(into, row["saved_as"])
    if target is None:
        return f"{row['name']}: saved_as {row['saved_as']!r} leaves {into}"
    if target.exists() and sha256_of(target) == row["sha256"]:
        return ""
    try:
        with zipfile.ZipFile(archive) as opened:
            data = opened.read(row["path"])
    except (KeyError, zipfile.BadZipFile) as error:
        return f"{row['name']}: {row['path']} not read from {archive.name}: {error}"
    found = hashlib.sha256(data).hexdigest()
    if found != row["sha256"]:
        target.unlink(missing_ok=True)
        return f"{target.name}: sha256 {found}, the manifest names {row['sha256']}; not written"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    return ""


def fetch(manifest: dict, archives: pathlib.Path, into: pathlib.Path,
          download: Download = urllib.request.urlretrieve) -> list[str]:
    """Every file of `manifest` into `into`; the problems, one line each."""
    archives.mkdir(parents=True, exist_ok=True)
    problems = []
    opened = {}
    for name, pack in manifest["packs"].items():
        opened[name], problem = archive_for(name, pack, archives, download)
        if problem:
            problems.append(problem)
    for row in manifest["files"]:
        if opened.get(row["pack"]) is None:
            continue
        problem = copy_out(opened[row["pack"]], row, into)
        if problem:
            problems.append(problem)
    return problems


def member_hashes(archive: pathlib.Path) -> list[str]:
    """`sha256  path` for every non-empty file in `archive`, sorted by path.

    Empty files are left out: every empty file has the same hash, and an
    empty `__init__.py` is not a pack's file.
    """
    lines = []
    with zipfile.ZipFile(archive) as opened:
        for info in sorted(opened.infolist(), key=lambda entry: entry.filename):
            if info.is_dir() or info.file_size == 0:
                continue
            lines.append(f"{hashlib.sha256(opened.read(info)).hexdigest()}  {info.filename}")
    return lines


def self_test() -> int:
    """A wrong archive is removed, a wrong file is removed, a `..` is refused,
    and the right file is kept."""
    with tempfile.TemporaryDirectory() as scratch:
        root = pathlib.Path(scratch)
        right = b"the bytes the manifest names"
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w") as archive:
            archive.writestr("Models/good.glb", right)
            archive.writestr("Models/bad.glb", b"something else")
        zipped = buffer.getvalue()

        def planted_download(_url: str, target: pathlib.Path) -> None:
            target.write_bytes(zipped if "right" in _url else b"not the archive")

        def row(name: str, path: str, saved_as: str) -> dict:
            return {"name": name, "pack": "right", "path": path, "saved_as": saved_as,
                    "sha256": hashlib.sha256(right).hexdigest(), "fallback": "box"}

        # Planted too: an archive put there by hand with the wrong bytes.
        (root / "archives").mkdir()
        (root / "archives" / "by_hand.zip").write_bytes(b"not the archive either")
        manifest = {"packs": {
            "right": {"page": "p", "archive": "planted:right",
                      "archive_sha256": hashlib.sha256(zipped).hexdigest()},
            "wrong": {"page": "p", "archive": "planted:wrong",
                      "archive_sha256": hashlib.sha256(zipped).hexdigest()},
            "by_hand": {"page": "p", "archive": "",
                        "archive_sha256": hashlib.sha256(zipped).hexdigest()},
        }, "files": [row("good", "Models/good.glb", "good.glb"),
                     row("bad", "Models/bad.glb", "bad.glb"),
                     row("escape", "Models/good.glb", "../escape.glb")]}
        into = root / "into"
        problems = fetch(manifest, root / "archives", into, planted_download)
        expected = {"wrong", "by_hand", "bad.glb", "escape"}
        seen = {word for problem in problems for word in expected if problem.startswith(word + ":")}
        failures = []
        if seen != expected or len(problems) != 4:
            failures.append(f"the planted cases were not each refused once: {problems}")
        leftovers = [root / "archives" / name for name in ("wrong.zip", "wrong.zip.part", "by_hand.zip")]
        if any(path.exists() for path in leftovers) or (into / "bad.glb").exists():
            failures.append("a refused file was kept")
        if (root / "escape.glb").exists():
            failures.append("a saved_as with .. wrote outside the folder")
        if not (into / "good.glb").exists():
            failures.append("the matching file was not kept")
    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--manifest", type=pathlib.Path, default=MANIFEST)
    parser.add_argument("--archives", type=pathlib.Path, default=ARCHIVES)
    parser.add_argument("--into", type=pathlib.Path, default=None)
    parser.add_argument("--list-members", metavar="PACK", default=None)
    parser.add_argument("--self-test", action="store_true")
    try:
        arguments = parser.parse_args(argv)
    except SystemExit as exit_request:
        if exit_request.code == 0:
            raise
        return 2
    if arguments.self_test:
        return self_test()
    try:
        manifest = json.loads(arguments.manifest.read_text(encoding="utf-8"))
        packs, files, folder = manifest["packs"], manifest["files"], manifest["into"]
    except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
        print(f"cannot read {arguments.manifest}: {error!r}")
        return 2
    into = arguments.into or inside(ROOT, folder)
    if into is None:
        print(f"{arguments.manifest}: into {folder!r} leaves the repository")
        return 2
    if arguments.list_members:
        return list_members(arguments.list_members, packs, arguments.archives)
    problems = fetch(manifest, arguments.archives, into)
    for problem in problems:
        print(problem)
    print(f"{len(files)} file(s) named, {len(problems)} problem(s); in {into}")
    return 1 if problems else 0


def list_members(name: str, packs: dict, archives: pathlib.Path) -> int:
    """Write the pack's member list from its checked archive; the exit code."""
    if name not in packs or "members" not in packs[name]:
        print(f"no pack {name!r} with a members list in the manifest")
        return 2
    archive, problem = archive_for(name, packs[name], archives, urllib.request.urlretrieve)
    if archive is None:
        print(problem)
        return 1
    target = inside(ROOT, packs[name]["members"])
    if target is None:
        print(f"members {packs[name]['members']!r} leaves the repository")
        return 2
    lines = member_hashes(archive)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{len(lines)} member(s) of {name} written to {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
