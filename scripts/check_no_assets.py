#!/usr/bin/env python3
"""Keep every 3D pack out of git: referenced by link, never committed.

The rule (ADR 0018)
-------------------
The owner's rule for open 3D assets: the repository carries what is about AI,
and a pack is only referenced -- `godot/game3d/assets.json` names its page,
its archive and every file's sha256, and `make assets-3d` downloads them into a
folder git ignores. Not even a crop is committed. Three ways that breaks, and
this gate refuses each:

  A1  a tracked file with a 3D-asset extension (`.glb`, `.fbx`, `.blend`, ...),
      an archive, a texture format the kit's 2D art does not use (`.jpg`,
      `.tga`, `.exr`, ...), or one of Godot's binary resources (`.res`,
      `.scn`, `.mesh`), which is what a model saved from the editor becomes.
      The common slip: `git add -A` after a download;
  A2  a tracked file whose sha256 is one the manifest knows: a whole archive,
      or any file inside one, from the pack's `members` list -- not only the
      files the examples use. This is the one an extension cannot catch: a
      pack's `colormap.png` looks like the kit's own 2D art, and a model
      renamed to something innocent is the same bytes;
  A3  a manifest row or pack with no sha256, or one that is not 64 hex
      digits, and a pack with no members list. Each is a hole A2 and
      `make assets-3d` would fall through;
  A4  a scene or resource under `godot/game3d/` that carries a mesh or a
      picture inside itself (an `ArrayMesh`'s surfaces, an `Image`'s data):
      a pack's model cut and pasted into a `.tscn` is still the pack.

What it cannot see, said so: a pack's file re-encoded (a texture saved again
from an editor) has new bytes and no tell-tale extension. That is review's.

Why this gate exists
--------------------
The `.gitignore` line keeps the download folder out, and a `.gitignore` is
advice: `git add -f`, a copy one folder over, or a texture moved into
`godot/assets/` passes it silently.

Exit codes
----------
0   nothing from a manifest is tracked, and every row has a hash
1   findings (each printed with a code)
2   wrong usage, or a manifest or a tracked file that cannot be read

Usage
-----
    check_no_assets.py [--repo PATH]
    check_no_assets.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
import pathlib
import re
import subprocess
import sys
import tempfile

MANIFEST = pathlib.Path("godot/game3d/assets.json")

# Extensions no file of the kit's own has, so any tracked one came from a pack.
# `.bin` is glTF's buffer; `.zip` and friends are a pack whole. `.png` is not
# here -- the kit commits its own pictures -- and A2 covers a pack's.
ASSET_EXTENSIONS = (
    ".glb", ".gltf", ".bin", ".fbx", ".obj", ".mtl", ".blend", ".blend1",
    ".dae", ".3ds", ".usd", ".usda", ".usdc", ".usdz", ".ktx", ".ktx2",
    ".zip", ".7z", ".rar", ".tar", ".gz",
    ".jpg", ".jpeg", ".tga", ".webp", ".exr", ".hdr", ".dds",
    ".res", ".scn", ".mesh",
)

# What a mesh or a picture looks like written inside a text scene or resource.
EMBEDDED = re.compile(r'^\[sub_resource type="(ArrayMesh|Image|ImageTexture|PortableCompressedTexture2D)"',
                      re.MULTILINE)
GAME3D = "godot/game3d/"

SHA256 = re.compile(r"^[0-9a-f]{64}$")


def tracked_files(repo: pathlib.Path) -> list[str]:
    """Every path git tracks in `repo`, as git writes it."""
    listing = subprocess.run(["git", "ls-files", "-z"], cwd=repo, capture_output=True,
                             check=True)
    return [name for name in listing.stdout.decode("utf-8").split("\0") if name]


def named_hashes(repo: pathlib.Path, manifest: dict) -> tuple[dict[str, str], list[str]]:
    """Every sha256 the manifest knows, mapped to what it is; and A3 findings."""
    hashes = {}
    findings = []
    for name, pack in manifest.get("packs", {}).items():
        digest = str(pack.get("archive_sha256", ""))
        if not SHA256.match(digest):
            findings.append(f"A3 {MANIFEST} pack {name} has no archive_sha256 a check can use")
        else:
            hashes[digest] = f"pack {name}'s archive"
        members, problem = member_hashes(repo, name, pack)
        hashes.update(members)
        if problem:
            findings.append(problem)
    for row in manifest.get("files", []):
        digest = str(row.get("sha256", ""))
        label = row.get("name", row.get("path", "?"))
        if not SHA256.match(digest):
            findings.append(f"A3 {MANIFEST} file {label} has no sha256 a check can use")
        else:
            hashes[digest] = f"{label} ({row.get('path', '?')})"
    return hashes, findings


def member_hashes(repo: pathlib.Path, name: str, pack: dict) -> tuple[dict[str, str], str]:
    """The hashes in a pack's members list (`sha256  path` lines); an A3 finding
    when the list is missing or empty."""
    listed = repo / str(pack.get("members", ""))
    if not pack.get("members") or not listed.is_file():
        return {}, f"A3 {MANIFEST} pack {name} has no members list on disk; run fetch_assets_3d.py --list-members {name}"
    hashes = {}
    for line in listed.read_text(encoding="utf-8").splitlines():
        digest, _, member = line.partition("  ")
        if SHA256.match(digest):
            hashes[digest] = f"{member} in pack {name}"
    if not hashes:
        return {}, f"A3 {pack['members']} lists no member of pack {name}"
    return hashes, ""


def embedded_findings(repo: pathlib.Path, name: str) -> list[str]:
    """A4: a text scene or resource under game3d/ carrying a mesh or a picture."""
    if not name.startswith(GAME3D) or not name.endswith((".tscn", ".tres")):
        return []
    found = EMBEDDED.search((repo / name).read_text(encoding="utf-8", errors="replace"))
    if found is None:
        return []
    return [f"A4 {name} carries an embedded {found.group(1)}; a pack's model or texture, cut, is still the pack"]


def run(repo: pathlib.Path) -> int:
    """Print every finding in `repo`; 1 if there were any."""
    manifest_path = repo / MANIFEST
    if not manifest_path.exists():
        print(f"A0 no manifest at {MANIFEST}: nothing to hold tracked files against")
        return 1
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if not manifest.get("files"):
        print(f"A0 {MANIFEST} names no file: nothing to hold tracked files against")
        return 1
    hashes, findings = named_hashes(repo, manifest)
    tracked = tracked_files(repo)
    for name in tracked:
        if name.lower().endswith(ASSET_EXTENSIONS):
            findings.append(f"A1 {name} is tracked; 3D assets are referenced, never committed")
        path = repo / name
        if not path.is_file():
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest in hashes:
            findings.append(f"A2 {name} is {hashes[digest]} from {MANIFEST}, committed")
        findings += embedded_findings(repo, name)
    for finding in findings:
        print(finding)
    print(f"no-assets: {len(tracked)} tracked file(s) against {len(hashes)} named hash(es), "
          f"{len(findings)} finding(s)")
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

    texture = b"a pack's colormap, which looks like any png"
    archive = b"the pack's whole archive"
    preview = b"a preview picture nobody uses"
    members = "\n".join(f"{hashlib.sha256(data).hexdigest()}  {path}" for data, path in
                        ((texture, "Textures/colormap.png"), (preview, "Preview.png"))) + "\n"

    def make_repo(root: pathlib.Path, files: dict[str, bytes], rows: list[dict],
                  pack: dict | None = None) -> pathlib.Path:
        root.mkdir(parents=True)
        subprocess.run(["git", "init", "-q"], cwd=root, check=True)
        if pack is None:
            pack = {"archive_sha256": hashlib.sha256(archive).hexdigest(), "members": "members.sha256"}
        manifest = {"packs": {"pack": pack}, "files": rows}
        files = {str(MANIFEST): json.dumps(manifest).encode("utf-8"),
                 "members.sha256": members.encode("utf-8"), **files}
        for name, data in files.items():
            (root / name).parent.mkdir(parents=True, exist_ok=True)
            (root / name).write_bytes(data)
        subprocess.run(["git", "add", "-A"], cwd=root, check=True)
        return root

    good_row = {"name": "colormap", "path": "Textures/colormap.png",
                "sha256": hashlib.sha256(texture).hexdigest()}

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)

        clean = make_repo(root / "clean", {"godot/assets/tile.png": b"the kit's own art"},
                          [good_row])
        expect("own art only", quiet(clean), 0)

        # Planted: the case the ADR names -- a manifest file under another name.
        renamed = make_repo(root / "renamed", {"godot/assets/grass.png": texture}, [good_row])
        expect("a manifest file committed under another name", quiet(renamed), 1)

        # Planted: a model added whole.
        model = make_repo(root / "model", {"godot/game3d/bot.glb": b"glTF"}, [good_row])
        expect("a tracked .glb", quiet(model), 1)

        # Planted: an extension in capitals, as packs on Windows ship them.
        shouting = make_repo(root / "shouting", {"godot/game3d/BOT.FBX": b"fbx"}, [good_row])
        expect("a tracked .FBX", quiet(shouting), 1)

        # Planted: a row with no hash, and one with a hash that is not one.
        for label, digest in (("missing", None), ("short", "abc")):
            row = {"name": "colormap", "path": "Textures/colormap.png"}
            if digest:
                row["sha256"] = digest
            unhashed = make_repo(root / label, {}, [row])
            expect(f"a row whose sha256 is {label}", quiet(unhashed), 1)

        # Planted: a pack's file the examples never use, and the whole archive,
        # each under an innocent name.
        unused = make_repo(root / "unused", {"godot/assets/title.png": preview}, [good_row])
        expect("an unused member of the pack, committed", quiet(unused), 1)
        whole = make_repo(root / "whole", {"notes/backup.dat": archive}, [good_row])
        expect("the archive committed under another name", quiet(whole), 1)

        # Planted: a model as Godot saves it, and one pasted into a scene.
        saved = make_repo(root / "saved", {"godot/game3d/bot.res": b"RSRC"}, [good_row])
        expect("a tracked .res", quiet(saved), 1)
        pasted = make_repo(root / "pasted", {"godot/game3d/arena.tscn":
                           b'[gd_scene format=3]\n\n[sub_resource type="ArrayMesh" id="1"]\n'}, [good_row])
        expect("a mesh embedded in a game3d scene", quiet(pasted), 1)
        plain = make_repo(root / "plain", {"godot/game3d/arena.tscn":
                          b'[gd_scene format=3]\n\n[sub_resource type="BoxMesh" id="1"]\n'}, [good_row])
        expect("a primitive mesh in a game3d scene", quiet(plain), 0)

        # Planted: a pack with no members list, and a manifest naming no file.
        listless = make_repo(root / "listless", {}, [good_row],
                             {"archive_sha256": hashlib.sha256(archive).hexdigest()})
        expect("a pack with no members list", quiet(listless), 1)
        empty = make_repo(root / "empty", {}, [])
        expect("a manifest naming no file", quiet(empty), 1)

        # Planted: no manifest at all; the gate would otherwise check nothing.
        bare = root / "bare"
        bare.mkdir()
        subprocess.run(["git", "init", "-q"], cwd=bare, check=True)
        expect("no manifest", quiet(bare), 1)

        script = pathlib.Path(__file__).resolve()
        extra = subprocess.run([sys.executable, str(script), "--unknown-flag"],
                               capture_output=True)
        expect("unknown flag", extra.returncode, 2)

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("--repo", default=None)
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        if exit_request.code == 0:
            raise
        return 2

    if args.self_test:
        return self_test()

    repo = pathlib.Path(args.repo) if args.repo else pathlib.Path(__file__).resolve().parent.parent
    try:
        return run(repo)
    except (OSError, json.JSONDecodeError, subprocess.CalledProcessError) as error:
        print(f"check_no_assets: cannot read: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
