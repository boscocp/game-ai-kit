#!/usr/bin/env bash
# Install the pinned Godot editor on the large disk, verified by SHA-512.
#
# Idempotent: a second run with the toolchain already in place does nothing but
# re-verify. The version comes from .godot-version, never from a flag, so the
# repo and the toolchain cannot drift.
#
# Exit codes
#   0  toolchain present and verified
#   1  download or verification failed
#   2  wrong usage, or a required tool is missing
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
  # Nothing to plant here: this script's assertion is the SHA check itself,
  # exercised on every real run. The self-test only proves the usage contract,
  # so that lint-selftests has something to call and a broken script is caught.
  for tool in curl unzip sha512sum; do
    command -v "$tool" >/dev/null || { echo "self-test FAIL: missing $tool"; exit 1; }
  done
  echo "self-test: ok"
  exit 0
fi

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
toolchain=${1:?usage: bootstrap.sh TOOLCHAIN_DIR GODOT_VERSION}
version=${2:?usage: bootstrap.sh TOOLCHAIN_DIR GODOT_VERSION}

archive="Godot_v${version}_linux.x86_64.zip"
base="https://github.com/godotengine/godot/releases/download/${version}"
binary="$toolchain/godot/godot"

if [[ -x "$binary" ]] && "$binary" --headless --version 2>/dev/null | grep -q "^${version%-stable}.stable"; then
  echo "bootstrap: Godot $version already installed at $binary"
else
  mkdir -p "$toolchain/godot" "$toolchain/dl"
  pushd "$toolchain/dl" >/dev/null

  echo "bootstrap: downloading Godot $version"
  curl -fsSL -O "$base/$archive"
  curl -fsSL -O "$base/SHA512-SUMS.txt"

  echo "bootstrap: verifying SHA-512"
  grep -F "$archive" SHA512-SUMS.txt | sed 's|\./||' > expected.sha512
  # An empty expected file would make sha512sum -c succeed vacuously, which is
  # exactly the "gate that only knows how to go green" this project refuses.
  [[ -s expected.sha512 ]] || { echo "bootstrap: $archive not listed in SHA512-SUMS.txt" >&2; exit 1; }
  sha512sum -c expected.sha512

  unzip -q -o "$archive" -d "$toolchain/godot"
  mv -f "$toolchain/godot/Godot_v${version}_linux.x86_64" "$binary"
  chmod +x "$binary"
  popd >/dev/null
fi

# Mechanism 1: self-contained mode keeps editor data, settings and export
# templates beside the binary instead of in ~/.local/share/godot.
touch "$toolchain/godot/._sc_"

# Mechanism 2: the project's user:// directory, which self-contained mode does
# not cover. scripts/godot sets XDG_DATA_HOME to this path on every call.
mkdir -p "$toolchain/xdg"

# Create editor_data/ now so check_disk_layout.py can assert ._sc_ is honoured
# without waiting for someone to open the editor. `--quit`, not `--version`:
# measured on 4.7.2 in an empty toolchain, `--version` prints and exits before
# the editor's paths exist, and creates nothing. This line used `--version`
# from the start, and only CI's first run on a fresh runner (wave 63) showed
# it -- the author's toolchain had had its editor_data/ for months.
env XDG_DATA_HOME="$toolchain/xdg" "$binary" --headless --quit >/dev/null 2>&1

# Export templates (T24), for `make export`. The archive is 1.28 GB and holds
# every platform; only the Linux x86_64 pair is unpacked, because that is the
# one platform this project exports to. Pinned here by SHA-512 rather than read
# from the release's SHA512-SUMS.txt, so a release replaced upstream is refused
# instead of trusted. Self-contained mode looks for them under editor_data/.
templates_sha="ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079"
templates_archive="Godot_v${version}_export_templates.tpz"
templates_dest="$toolchain/godot/editor_data/export_templates/${version/-/.}"

# CI sets GAK_SKIP_TEMPLATES=1: it runs the tests, never `make export`, and
# 1.28 GB in its cache would buy nothing.
if [[ "${GAK_SKIP_TEMPLATES:-}" == "1" ]]; then
  echo "bootstrap: export templates skipped (GAK_SKIP_TEMPLATES=1)"
elif [[ -f "$templates_dest/linux_release.x86_64" && -f "$templates_dest/.pinned-sha512" ]] \
    && grep -q "$templates_sha" "$templates_dest/.pinned-sha512"; then
  echo "bootstrap: export templates $version already installed"
else
  mkdir -p "$toolchain/dl" "$templates_dest"
  if [[ ! -f "$toolchain/dl/$templates_archive" ]]; then
    echo "bootstrap: downloading export templates $version (1.28 GB)"
    curl -fsSL -o "$toolchain/dl/$templates_archive" "$base/$templates_archive"
  fi
  echo "$templates_sha  $toolchain/dl/$templates_archive" | sha512sum -c -
  unzip -q -o -j "$toolchain/dl/$templates_archive" \
    templates/linux_release.x86_64 templates/linux_debug.x86_64 templates/version.txt -d "$templates_dest"
  echo "$templates_sha" > "$templates_dest/.pinned-sha512"
fi

# gdUnit4: the test framework, installed rather than vendored. Pinned by tag
# and verified by SHA-256 -- the project publishes no release assets, so the
# source archive is what there is to pin.
gdunit_tag="v6.2.2"
gdunit_sha="ddb44730ffb9cd77fd70d283753450759b00c5016143d7572bf63625f64d5433"
gdunit_dest="$here/godot/addons/gdUnit4"

if [[ -f "$gdunit_dest/.pinned-version" ]] && grep -q "$gdunit_tag" "$gdunit_dest/.pinned-version"; then
  echo "bootstrap: gdUnit4 $gdunit_tag already installed"
else
  echo "bootstrap: downloading gdUnit4 $gdunit_tag"
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
  curl -fsSL -o "$work/gdunit4.zip" \
    "https://github.com/godot-gdunit-labs/gdUnit4/archive/refs/tags/${gdunit_tag}.zip"
  echo "$gdunit_sha  $work/gdunit4.zip" | sha256sum -c -
  unzip -q "$work/gdunit4.zip" -d "$work"
  rm -rf "$gdunit_dest"
  mkdir -p "$(dirname "$gdunit_dest")"
  mv "$work"/gdUnit4-*/addons/gdUnit4 "$gdunit_dest"
  printf '%s\nsha256:%s\n' "$gdunit_tag" "$gdunit_sha" > "$gdunit_dest/.pinned-version"
fi

echo "bootstrap: ok -- $("$binary" --headless --version)"
