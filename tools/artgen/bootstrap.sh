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

# The lock pins wheels built for CPython 3.14 on x86_64 Linux; another Python
# would fail halfway through installing, or worse, half work.
want="3.14"
version_of() { "$1" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null; }
command -v python3 >/dev/null || { echo "artgen bootstrap: python3 is required" >&2; exit 2; }
[[ "$(version_of python3)" == "$want" ]] || {
  echo "artgen bootstrap: the lock is for Python $want, and python3 is $(version_of python3)" >&2; exit 2; }
mkdir -p "$home/cache"
# The environment links to the system's python3. After a distribution upgrade
# it can still exist and no longer run, so it is checked by running it.
if [[ -x "$home/venv/bin/python" && "$(version_of "$home/venv/bin/python")" != "$want" ]]; then
  echo "artgen bootstrap: the environment at $home/venv no longer runs Python $want; rebuilding it"
  rm -rf "$home/venv"
fi
[[ -x "$home/venv/bin/python" ]] || python3 -m venv "$home/venv"

echo "artgen bootstrap: installing $(grep -c '==' "$here/requirements.lock") pinned packages"
"$home/venv/bin/python" -m pip install --quiet --require-hashes --only-binary=:all: \
  --index-url https://pypi.org/simple --extra-index-url https://download.pytorch.org/whl/cu128 \
  -r "$here/requirements.lock"

echo "artgen bootstrap: fetching ${model:-the default model} from model.json"
HF_HUB_OFFLINE=0 "$home/venv/bin/python" -I "$here/fetch.py" "$here/model.json" $model
