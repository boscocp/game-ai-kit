"""Write one vector per recording in data/talk/recordings/, from the Python replay.

    PYTHONPATH=python python3 spec/vectors/talk/write.py

Run after recording (`make record-talk`), then read each new file against
`spec/talk/gate.json` by hand before committing it: the vectors are what the
Python replay computed, so they hold the Godot game to it, and a person
holds both to the rules. `make test-talk-vectors` and the Python tests then
fail on any drift.
"""

import json
import pathlib

from gameaikit.talk import replay

REPO = pathlib.Path(__file__).resolve().parents[3]
RECORDINGS = REPO / "data" / "talk" / "recordings"
HERE = pathlib.Path(__file__).resolve().parent


def main() -> None:
    for path in sorted(RECORDINGS.glob("*.json")):
        vector = {"recording": f"data/talk/recordings/{path.name}"}
        vector.update(replay.vector_of(replay.replay(json.loads(path.read_text(encoding="utf-8")))))
        (HERE / path.name).write_text(json.dumps(vector, indent=2, ensure_ascii=False) + "\n",
                                      encoding="utf-8")
        print(f"{path.name}: {vector['outcome']} after {len(vector['turns'])} turn(s)")


if __name__ == "__main__":
    main()
