#!/usr/bin/env python3
"""Keep the Apache-2.0 attribution attached to everything that ships.

The rule
--------
Apache-2.0 section 4 obliges whoever redistributes this code to carry the
LICENSE and the NOTICE along with it. That only works if the files are actually
in the artifacts. So:

  * LICENSE and NOTICE exist at the repository root;
  * NOTICE names the copyright holder, so it is not an empty formality;
  * every addon under godot/addons/ carries its own copy, because the Godot
    Asset Library ships one addon folder at a time and a user who installs only
    `ai_search` must still receive the attribution;
  * every zip produced under dist/ contains both.

Why this gate exists
--------------------
Attribution is the one thing this project asks in return for the code. A rule
that depends on remembering to copy two files at release time is a rule that
breaks on the first release made in a hurry.

Exit codes
----------
0   every required copy is present
1   violations found (each one printed)
2   wrong usage, or a file that cannot be read

Usage
-----
    check_license.py [--repo PATH]
    check_license.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import io
import pathlib
import subprocess
import sys
import tempfile
import zipfile

REQUIRED_FILES = ("LICENSE", "NOTICE")
COPYRIGHT_HOLDER = "Adalberto Pereira"

# Third-party addons vendored into godot/addons/. They carry their own licence
# and must NOT carry this project's NOTICE -- putting our NOTICE in someone
# else's folder is a false attribution claim, not a formality.
#
# Declared one by one on purpose. Inferring "not ours" from the absence of a
# file would mean a folder dropped in by accident silently stops being checked.
VENDORED = {
    "gdUnit4": "MIT -- github.com/godot-gdunit-labs/gdUnit4, pinned in .pinned-version",
}


def check_root(repo: pathlib.Path) -> list[str]:
    """Report a missing or hollow LICENSE/NOTICE at the repository root."""
    findings = []
    for name in REQUIRED_FILES:
        path = repo / name
        if not path.exists():
            findings.append(f"L1 {name} missing at the repository root")
        elif path.stat().st_size == 0:
            findings.append(f"L2 {name} is empty")

    notice = repo / "NOTICE"
    if notice.exists() and COPYRIGHT_HOLDER not in notice.read_text(encoding="utf-8"):
        findings.append(f"L3 NOTICE does not name the copyright holder")
    return findings


def check_addons(repo: pathlib.Path) -> list[str]:
    """Report an addon that would ship without its own attribution files."""
    findings = []
    addons = repo / "godot" / "addons"
    if not addons.exists():
        return findings

    for addon in sorted(p for p in addons.iterdir() if p.is_dir()):
        # Every folder under addons/ counts. An earlier version used the
        # presence of plugin.cfg as the marker for "shippable", which was wrong
        # twice over: the library addons here have no plugin.cfg at all (a
        # plugin.cfg requires an @tool script extending EditorPlugin, and
        # `class_name` already registers a class project-wide without one), and
        # a marker-based rule fails open -- a new addon would be skipped in
        # silence, which is the kind of green this project refuses.
        if addon.name in VENDORED:
            # Someone else's code: it keeps its own licence and must not wear
            # ours. Both halves are asserted, so a vendored addon cannot be
            # used as a way to ship unlicensed code either.
            if not (addon / "LICENSE").exists():
                findings.append(f"L6 vendored {addon.name} has no licence of its own")
            if (addon / "NOTICE").exists():
                findings.append(
                    f"L7 vendored {addon.name} carries this project's NOTICE; "
                    "that claims authorship we do not have"
                )
            continue

        for name in REQUIRED_FILES:
            if not (addon / name).exists():
                findings.append(f"L4 {addon.name} would ship without {name}")
    return findings


def check_release_zips(repo: pathlib.Path) -> list[str]:
    """Report a built artifact that lost its attribution on the way out."""
    findings = []
    dist = repo / "dist"
    if not dist.exists():
        return findings

    for archive in sorted(dist.glob("*.zip")):
        with zipfile.ZipFile(archive) as bundle:
            names = [pathlib.PurePosixPath(n).name for n in bundle.namelist()]
        for name in REQUIRED_FILES:
            if name not in names:
                findings.append(f"L5 {archive.name} does not contain {name}")
    return findings


def run(repo: pathlib.Path) -> int:
    findings = check_root(repo) + check_addons(repo) + check_release_zips(repo)
    for finding in findings:
        print(finding)
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

    def make_repo(root: pathlib.Path) -> pathlib.Path:
        root.mkdir(parents=True, exist_ok=True)
        (root / "LICENSE").write_text("Apache License\nVersion 2.0\n")
        (root / "NOTICE").write_text(f"game-ai-kit\nCopyright 2026 {COPYRIGHT_HOLDER}\n")
        return root

    def make_addon(repo: pathlib.Path, name: str, with_files: bool) -> pathlib.Path:
        addon = repo / "godot" / "addons" / name
        addon.mkdir(parents=True)
        if with_files:
            for required in REQUIRED_FILES:
                (addon / required).write_text("copy\n")
        return addon

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)

        good = make_repo(root / "good")
        make_addon(good, "ai_search", with_files=True)
        expect("complete repo", quiet(good), 0)

        # Planted: NOTICE deleted.
        no_notice = make_repo(root / "no-notice")
        (no_notice / "NOTICE").unlink()
        expect("missing NOTICE", quiet(no_notice), 1)

        # Planted: NOTICE present but hollowed out.
        hollow = make_repo(root / "hollow")
        (hollow / "NOTICE").write_text("TODO\n")
        expect("NOTICE without holder", quiet(hollow), 1)

        # Planted: an addon that would ship bare.
        bare = make_repo(root / "bare-addon")
        make_addon(bare, "ai_planning", with_files=False)
        expect("addon without LICENSE", quiet(bare), 1)

        # Planted: a library addon with no plugin.cfg -- which is the normal
        # shape here -- must still be required to carry the attribution. This
        # case used to pass, and that was the bug.
        library = make_repo(root / "library")
        (library / "godot" / "addons" / "ai_llm").mkdir(parents=True)
        expect("library addon without plugin.cfg", quiet(library), 1)

        # A declared third-party addon keeps its own licence and skips ours.
        vendored_name = next(iter(VENDORED))
        vendored_ok = make_repo(root / "vendored-ok")
        bundled = make_addon(vendored_ok, vendored_name, with_files=False)
        (bundled / "LICENSE").write_text("MIT License\n")
        expect("vendored addon with its own licence", quiet(vendored_ok), 0)

        # Planted: vendored code shipped with no licence at all.
        vendored_bare = make_repo(root / "vendored-bare")
        make_addon(vendored_bare, vendored_name, with_files=False)
        expect("vendored addon with no licence", quiet(vendored_bare), 1)

        # Planted: our NOTICE dropped into someone else's addon.
        vendored_claimed = make_repo(root / "vendored-claimed")
        claimed = make_addon(vendored_claimed, vendored_name, with_files=True)
        expect("our NOTICE inside a vendored addon", quiet(vendored_claimed), 1)

        # Planted: a release zip that lost the attribution.
        shipped = make_repo(root / "shipped")
        make_addon(shipped, "ai_search", with_files=True)
        (shipped / "dist").mkdir()
        with zipfile.ZipFile(shipped / "dist" / "ai_search.zip", "w") as bundle:
            bundle.writestr("ai_search/plugin.cfg", "[plugin]\n")
        expect("zip without NOTICE", quiet(shipped), 1)

        script = pathlib.Path(__file__).resolve()
        extra = subprocess.run(
            [sys.executable, str(script), "--unknown-flag"], capture_output=True
        )
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
    except SystemExit:
        return 2

    if args.self_test:
        return self_test()

    repo = pathlib.Path(args.repo or pathlib.Path(__file__).resolve().parent.parent)
    try:
        return run(repo)
    except (OSError, zipfile.BadZipFile) as error:
        print(f"check_license: cannot read a file: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
