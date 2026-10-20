#!/usr/bin/env python3
"""Download the RTS's Bos Wars sheets, refusing any whose sha256 differs.

The rule (ADR 0020)
-------------------
The RTS's pictures are referenced, never committed: `godot/game/rts/
art_sources.json` names each sheet's URL and sha256, and this script puts the
sheets in `build/rts-art/`, which git ignores. A sheet whose bytes are not the
ones the manifest names is deleted and reported, never kept: a changed file
upstream would otherwise reach the screen unreviewed. The game draws plain
shapes when the folder is empty, so nothing else depends on this having run.

Exit codes
----------
0   every sheet is present and matches
1   a download failed or a sheet did not match (it was removed)
2   wrong usage, or the manifest cannot be read

Usage
-----
    fetch_rts_art.py [--manifest PATH] [--into DIR]
    fetch_rts_art.py --self-test
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import sys
import tempfile
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "godot" / "game" / "rts" / "art_sources.json"
INTO = ROOT / "build" / "rts-art"


def sha256_of(path: pathlib.Path) -> str:
    """The file's sha256, as the manifest writes it."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def keep_if_matching(path: pathlib.Path, wanted: str) -> str:
    """Why `path` was refused and removed, or "" when it matches `wanted`."""
    found = sha256_of(path)
    if found == wanted:
        return ""
    path.unlink()
    return f"{path.name}: sha256 {found}, the manifest names {wanted}; removed"


def fetch(manifest: dict, into: pathlib.Path, download=urllib.request.urlretrieve) -> list[str]:
    """Every sheet of `manifest` into `into`; the problems, one line each.

    A sheet already there and matching is not downloaded again.
    """
    into.mkdir(parents=True, exist_ok=True)
    problems = []
    for kind, sheet in manifest["sheets"].items():
        target = into / f"{kind}.png"
        if target.exists() and sha256_of(target) == sheet["sha256"]:
            continue
        try:
            download(manifest["base_url"] + sheet["path"], target)
        except OSError as error:
            problems.append(f"{kind}: {error}")
            continue
        refusal = keep_if_matching(target, sheet["sha256"])
        if refusal:
            problems.append(refusal)
    return problems


def self_test() -> int:
    """A sheet with the wrong bytes is refused and removed; a right one kept."""
    with tempfile.TemporaryDirectory() as scratch:
        into = pathlib.Path(scratch)
        right = b"the bytes the manifest names"
        manifest = {"base_url": "planted:", "sheets": {
            "good": {"path": "good", "sha256": hashlib.sha256(right).hexdigest()},
            "bad": {"path": "bad", "sha256": hashlib.sha256(b"something else").hexdigest()},
        }}

        def planted_download(_url: str, target: pathlib.Path) -> None:
            target.write_bytes(right)

        problems = fetch(manifest, into, planted_download)
        if len(problems) != 1 or "bad" not in problems[0] or (into / "bad.png").exists():
            print(f"self-test: the planted mismatch was not refused: {problems}")
            return 1
        if not (into / "good.png").exists():
            print("self-test: the matching sheet was not kept")
            return 1
    print("self-test: a mismatched sheet is refused and removed, a matching one kept")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--manifest", type=pathlib.Path, default=MANIFEST)
    parser.add_argument("--into", type=pathlib.Path, default=INTO)
    parser.add_argument("--self-test", action="store_true")
    arguments = parser.parse_args(argv)
    if arguments.self_test:
        return self_test()
    try:
        manifest = json.loads(arguments.manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"cannot read {arguments.manifest}: {error}")
        return 2
    problems = fetch(manifest, arguments.into)
    for problem in problems:
        print(problem)
    print(f"{len(manifest['sheets']) - len(problems)} of {len(manifest['sheets'])} sheets in {arguments.into}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
