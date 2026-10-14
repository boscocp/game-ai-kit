"""Fetch the model named in model.json, and check every weight by sha256.

Run by bootstrap, inside the generator's environment, with the caches already
pointed at the large disk. The revision pins what Hugging Face serves; the
sha256 pins what arrived. A revision is a promise by the host, a hash is a
fact about the bytes on this disk, and only the second is checked here.

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
    """The sha256 of a file, read in chunks: the largest weight is 7.8 GB."""
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


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print("usage: fetch.py MODEL_JSON", file=sys.stderr)
        return 2
    config = json.loads(pathlib.Path(argv[0]).read_text(encoding="utf-8"))
    problems = fetch(config["base"]) + fetch(config["lora"])
    for problem in problems:
        print(f"artgen fetch: {problem}", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
