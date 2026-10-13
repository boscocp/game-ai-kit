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
  * every zip produced under dist/ contains both, at its root or in its one
    top folder;
  * every wheel under dist/ carries both in its `.dist-info/licenses/`, which
    is where PEP 639 puts a wheel's licence files and where pip installs them.

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
import tarfile
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
        elif name == "LICENSE" and "Apache License" not in path.read_text(encoding="utf-8"):
            # Only NOTICE had a content check, so a LICENSE reading
            # `TODO: pick a licence` passed.
            findings.append("L8 LICENSE does not contain the Apache licence text")

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


def archive_entries(archive: pathlib.Path) -> list[str]:
    """Every path inside a .zip, .whl or .tar.gz, as written."""
    if archive.suffix in (".zip", ".whl"):
        with zipfile.ZipFile(archive) as bundle:
            return bundle.namelist()
    with tarfile.open(archive) as bundle:
        return bundle.getnames()


def check_release_archives(repo: pathlib.Path) -> list[str]:
    """Report a built artifact that lost its attribution on the way out.

    The check used to compare basenames anywhere in the archive, so an addon
    shipping bare passed as long as *something* named LICENSE was bundled --
    a vendored dependency's licence satisfied it. The files must sit at the
    archive's own root, or at the root of its single top-level folder, which is
    where someone unpacking it will look. Tarballs were not examined at all.
    """
    findings = []
    dist = repo / "dist"
    if not dist.exists():
        return findings

    archives = sorted(
        path for path in dist.iterdir()
        if path.suffix in (".zip", ".whl") or path.name.endswith((".tar.gz", ".tgz"))
    )
    for archive in archives:
        entries = [pathlib.PurePosixPath(entry) for entry in archive_entries(archive)]
        if archive.suffix == ".whl":
            findings.extend(check_wheel(archive.name, entries))
            continue
        # Depth 0 is the archive root; depth 1 covers the usual single wrapper
        # folder, `ai_search/LICENSE`.
        shallow = {entry.name for entry in entries if len(entry.parts) <= 2}
        for name in REQUIRED_FILES:
            if name not in shallow:
                findings.append(
                    f"L5 {archive.name} has no {name} at its root or in its top folder"
                )
    return findings


def check_wheel(name: str, entries: list[pathlib.PurePosixPath]) -> list[str]:
    """Report a wheel whose licence files are not where an installer puts them.

    A wheel is a zip, and the zip rule would pass one with a NOTICE at
    `gameaikit/NOTICE` -- inside the package, at depth two. An installer copies
    that as module data and nobody reading the installed metadata finds it.
    Wheels were not examined at all until release.py started building one,
    and its own self-test found the hole: five artifacts, four findings.
    """
    licensed = {
        entry.name for entry in entries
        if len(entry.parts) == 3
        and entry.parts[0].endswith(".dist-info") and entry.parts[1] == "licenses"
    }
    return [
        f"L9 {name} has no {required} in its .dist-info/licenses/"
        for required in REQUIRED_FILES if required not in licensed
    ]


def run(repo: pathlib.Path) -> int:
    findings = check_root(repo) + check_addons(repo) + check_release_archives(repo)
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

        # Planted: a zero-byte NOTICE. The "hollow" case below writes TODO and
        # is caught by the holder check, so mutation showed the size rule was
        # never the thing that fired.
        zero_byte = make_repo(root / "zerobyte")
        (zero_byte / "NOTICE").write_text("")
        expect("zero-byte NOTICE", quiet(zero_byte), 1)

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

        # Planted: an addon shipping bare, with a dependency's licence deeper
        # in the archive satisfying the basename check.
        deep = make_repo(root / "deep")
        make_addon(deep, "ai_search", with_files=True)
        (deep / "dist").mkdir()
        with zipfile.ZipFile(deep / "dist" / "ai_search.zip", "w") as bundle:
            bundle.writestr("ai_search/plugin.cfg", "[plugin]\n")
            bundle.writestr("ai_search/vendor/other/LICENSE", "MIT\n")
            bundle.writestr("ai_search/vendor/other/NOTICE", "someone else\n")
        expect("attribution only deep in the archive", quiet(deep), 1)

        # Planted: a tarball, which was not examined at all.
        tarred = make_repo(root / "tarred")
        make_addon(tarred, "ai_search", with_files=True)
        (tarred / "dist").mkdir()
        with tarfile.open(tarred / "dist" / "kit.tar.gz", "w:gz") as bundle:
            lone = tarred / "plugin.cfg"
            lone.write_text("[plugin]\n")
            bundle.add(lone, arcname="kit/plugin.cfg")
        expect("tarball without attribution", quiet(tarred), 1)

        # A wheel with both files where PEP 639 puts them passes.
        wheeled = make_repo(root / "wheeled")
        (wheeled / "dist").mkdir()
        with zipfile.ZipFile(wheeled / "dist" / "kit-1.0.0-py3-none-any.whl", "w") as bundle:
            bundle.writestr("kit/__init__.py", "")
            for required in REQUIRED_FILES:
                bundle.writestr(f"kit-1.0.0.dist-info/licenses/{required}", "copy\n")
        expect("wheel with its licences in .dist-info", quiet(wheeled), 0)

        # Planted: a wheel without NOTICE. Wheels were not opened at all.
        bare_wheel = make_repo(root / "bare-wheel")
        (bare_wheel / "dist").mkdir()
        with zipfile.ZipFile(bare_wheel / "dist" / "kit-1.0.0-py3-none-any.whl", "w") as bundle:
            bundle.writestr("kit-1.0.0.dist-info/licenses/LICENSE", "copy\n")
        expect("wheel without NOTICE", quiet(bare_wheel), 1)

        # Planted: a NOTICE somewhere other than .dist-info/licenses/. Each
        # path defeats exactly one of the three conditions in check_wheel, so
        # deleting any one of them turns one of these green. Written out rather
        # than generated, so a path deleted from the list is a visible diff.
        misplaced_notices = (
            "kit/licenses/NOTICE",                          # not in .dist-info
            "kit-1.0.0.dist-info/legal/NOTICE",             # not in licenses/
            "kit-1.0.0.dist-info/licenses/vendor/NOTICE",   # someone else's, deeper
        )
        for index, misplaced_path in enumerate(misplaced_notices):
            misplaced = make_repo(root / f"misplaced-wheel-{index}")
            (misplaced / "dist").mkdir()
            wheel_path = misplaced / "dist" / "kit-1.0.0-py3-none-any.whl"
            with zipfile.ZipFile(wheel_path, "w") as bundle:
                bundle.writestr("kit-1.0.0.dist-info/licenses/LICENSE", "copy\n")
                bundle.writestr(misplaced_path, "copy\n")
            expect(f"wheel with NOTICE at {misplaced_path}", quiet(misplaced), 1)

        # Planted: a LICENSE that says nothing. Only NOTICE had a content check.
        placeholder = make_repo(root / "placeholder")
        (placeholder / "LICENSE").write_text("TODO: pick a licence\n")
        expect("placeholder LICENSE", quiet(placeholder), 1)

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
    except SystemExit as exit_request:
        # argparse raises SystemExit for `--help` too, with code 0. Catching it
        # blindly turned a successful --help into exit 2 in every gate here.
        if exit_request.code == 0:
            raise
        return 2

    if args.self_test:
        return self_test()

    repo = pathlib.Path(args.repo or pathlib.Path(__file__).resolve().parent.parent)
    try:
        return run(repo)
    except (OSError, zipfile.BadZipFile, tarfile.TarError) as error:
        print(f"check_license: cannot read a file: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
