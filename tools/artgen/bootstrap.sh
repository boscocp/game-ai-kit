#!/usr/bin/env bash
# Create the generator's environment and fetch its model, both on the large
# disk, both pinned: packages from requirements.lock by sha256, the model from
# model.json by revision and sha256. The way `make bootstrap` pins Godot.
#
# Called by scripts/artgen, which has already pointed every cache at the
# toolchain directory. Idempotent: a second run installs nothing new and
# re-verifies the weights.
#
# Usage: tools/artgen/bootstrap.sh ENVIRONMENT_DIR [MODEL]   (MODEL as named in model.json)
# Exit codes: 0 ready, 1 an install or a verification failed, 2 wrong usage.
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
home=${1:?usage: bootstrap.sh ENVIRONMENT_DIR [MODEL]}
model=${2:-}

command -v python3 >/dev/null || { echo "artgen bootstrap: python3 is required" >&2; exit 2; }
mkdir -p "$home/cache"
[[ -x "$home/venv/bin/python" ]] || python3 -m venv "$home/venv"

echo "artgen bootstrap: installing $(grep -c '==' "$here/requirements.lock") pinned packages"
"$home/venv/bin/python" -m pip install --quiet --require-hashes --only-binary=:all: \
  --index-url https://pypi.org/simple --extra-index-url https://download.pytorch.org/whl/cu128 \
  -r "$here/requirements.lock"

echo "artgen bootstrap: fetching ${model:-the default model} from model.json"
HF_HUB_OFFLINE=0 "$home/venv/bin/python" -I "$here/fetch.py" "$here/model.json" $model
