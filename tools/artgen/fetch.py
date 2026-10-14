"""Fetch a model named in model.json, and check every weight by sha256.

Run by bootstrap, inside the generator's environment, with the caches already
pointed at the large disk. The revision pins what Hugging Face serves; the
sha256 pins what arrived. A revision is a promise by the host, a hash is a
fact about the bytes on this disk, and only the second is checked here.

Usage: fetch.py MODEL_JSON [NAME]   (NAME defaults to the file's `default`)
Exit codes: 0 fetched and verified, 1 a hash did not match, 2 wrong usage.
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import sys

from huggingface_hub import snapshot_download

CHUNK = 1 << 24


def sha256_of(path: pathlib.Path) -> str:
    """The sha256 of a file, read in chunks: the largest weight is 10 GB."""
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(CHUNK), b""):
            digest.update(block)
    return digest.hexdigest()


def fetch(part: dict) -> list[str]:
    """Download one repository at its revision; report each weight that differs."""
    folder = pathlib.Path(snapshot_download(part["repo"], revision=part["revision"],
                                            allow_patterns=part["fetch"]))
    problems = []
    for name, expected in part["sha256"].items():
        actual = sha256_of(folder / name)
        if actual != expected:
            problems.append(f"{part['repo']}/{name}: sha256 {actual}, expected {expected}")
        else:
            print(f"  verified {part['repo']}/{name}")
    return problems


def encoder_of(donor: dict) -> dict:
    """The part of a model that is its text encoder: its repository and
    revision, the encoder's files alone, and their hashes."""
    hashes = {name: digest for name, digest in donor["sha256"].items() if name.startswith("text_encoder/")}
    return {"repo": donor["repo"], "revision": donor["revision"], "fetch": ["text_encoder/*"], "sha256": hashes}


def main(argv: list[str]) -> int:
    if len(argv) not in (1, 2):
        print("usage: fetch.py MODEL_JSON [NAME]", file=sys.stderr)
        return 2
    config = json.loads(pathlib.Path(argv[0]).read_text(encoding="utf-8"))
    name = argv[1] if len(argv) == 2 else config["default"]
    if name not in config["models"]:
        print(f"artgen fetch: no model {name!r}; model.json has {', '.join(config['models'])}", file=sys.stderr)
        return 2
    model = config["models"][name]
    problems = fetch(model) + (fetch(model["lora"]) if "lora" in model else [])
    # A model that borrows another's text encoder needs that encoder on disk
    # too, and only that: the donor's transformer would be 7.75 GB unused.
    if "text_encoder_from" in model:
        problems += fetch(encoder_of(config["models"][model["text_encoder_from"]]))
    for problem in problems:
        print(f"artgen fetch: {problem}", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
