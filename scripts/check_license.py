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
import re
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


# Every archive shape this gate opens. `.tar.xz` and a bare `.tar` were not in
# the list, so one dropped into dist/ was never examined.
TAR_SUFFIXES = (".tar", ".tar.gz", ".tgz", ".tar.bz2", ".tar.xz")


def archive_files(archive: pathlib.Path) -> tuple[list[pathlib.PurePosixPath],
                                                   dict[pathlib.PurePosixPath, bytes]]:
    """Every path inside an archive, and the attribution files that count.

    A file *counts* when it is a regular file with something in it -- not a
    directory, not a link, not empty. A review planted a directory named
    `NOTICE/`, an empty NOTICE and a link named NOTICE, and each satisfied a
    rule that only compared names. Their bytes come back too, because the
    content has to be checked as well: a NOTICE reading `TODO` passed.

    `.` -- the root, as `tar -C dir -czf x.tar.gz .` writes it -- is not a
    path anything can be inside, and it crashed the top-folder rule.
    """
    if archive.suffix in (".zip", ".whl"):
        with zipfile.ZipFile(archive) as bundle:
            members = bundle.infolist()
            paths = [pathlib.PurePosixPath(member.filename) for member in members]
            counted = {
                pathlib.PurePosixPath(member.filename): bundle.read(member)
                for member in members
                if not member.is_dir() and not is_zip_link(member) and member.file_size > 0
                and pathlib.PurePosixPath(member.filename).name in REQUIRED_FILES
            }
    else:
        with tarfile.open(archive) as bundle:
            members = bundle.getmembers()
            paths = [pathlib.PurePosixPath(member.name) for member in members]
            counted = {
                pathlib.PurePosixPath(member.name): bundle.extractfile(member).read()
                for member in members
                if member.isfile() and member.size > 0
                and pathlib.PurePosixPath(member.name).name in REQUIRED_FILES
            }
    return [path for path in paths if path.parts], counted


def is_zip_link(member: zipfile.ZipInfo) -> bool:
    """A symbolic link stored the Unix way: the file type sits in the high bits."""
    return (member.external_attr >> 16) & 0o170000 == 0o120000


def check_release_archives(repo: pathlib.Path) -> list[str]:
    """Report a built artifact that lost its attribution on the way out.

    The check used to compare basenames anywhere in the archive, so an addon
    shipping bare passed as long as *something* named LICENSE was bundled --
    a vendored dependency's licence satisfied it. The files must sit at the
    archive's own root, or at the root of its single top-level folder, which is
    where someone unpacking it will look. Tarballs were not examined at all.

    And they must be *this repository's* files, byte for byte (L10). The root
    copies get a content check; the archive copies used to get a size check,
    so a release whose NOTICE read `TODO` passed.
    """
    findings = []
    dist = repo / "dist"
    if not dist.exists():
        return findings

    archives = sorted(
        path for path in dist.iterdir()
        if path.suffix in (".zip", ".whl") or path.name.endswith(TAR_SUFFIXES)
    )
    for archive in archives:
        paths, counted = archive_files(archive)
        if archive.suffix == ".whl":
            located = wheel_licences(archive.name, counted)
            if located is None:
                findings.append(f"L9 {archive.name} is not named like a wheel")
                continue
            code, where = "L9", "in its .dist-info/licenses/"
        else:
            located = attributed_files(paths, counted)
            code, where = "L5", "at its root or in its top folder"
        for name in REQUIRED_FILES:
            if name not in located:
                findings.append(f"{code} {archive.name} has no {name} {where}")
            elif (repo / name).exists() and located[name] != (repo / name).read_bytes():
                findings.append(f"L10 {archive.name} carries a {name} that is not the "
                                "repository's own")
    return findings


def attributed_files(paths: list[pathlib.PurePosixPath],
                     counted: dict[pathlib.PurePosixPath, bytes]) -> dict[str, bytes]:
    """The attribution files at an archive's root, or in its one top folder.

    *One* is the rule, and it was only in the prose: the depth test alone
    passed a zip holding `ai_search/astar.gd` beside `vendor/LICENSE`, where
    the attribution belongs to the second folder and not the first. A folder
    counts only when every path in the archive is inside it.
    """
    found = {path.name: data for path, data in counted.items() if len(path.parts) == 1}
    if len({path.parts[0] for path in paths}) == 1:
        found.update({path.name: data for path, data in counted.items()
                      if len(path.parts) == 2})
    return found


def canonical(distribution: str) -> str:
    """A distribution name as installers compare it: case and `-_.` runs folded."""
    return re.sub(r"[-_.]+", "_", distribution).lower()


def wheel_licences(name: str, counted: dict[pathlib.PurePosixPath, bytes]) -> dict[str, bytes] | None:
    """The licence files in a wheel's own `.dist-info/licenses/`, or None for a misnamed wheel.

    A wheel is a zip, and the zip rule would pass one with a NOTICE at
    `gameaikit/NOTICE` -- inside the package, at depth two. An installer copies
    that as module data and nobody reading the installed metadata finds it.
    Wheels were not examined at all until release.py started building one,
    and its own self-test found the hole: five artifacts, four findings.

    Only the wheel's *own* `.dist-info` counts -- the one its filename names,
    compared the way installers compare names, so `PyYAML-6.0.1.dist-info`
    inside `pyyaml-6.0.1-...whl` is its own. Any folder ending in `.dist-info`
    used to count, so a dependency's NOTICE satisfied the rule for the package.
    """
    parts = name[:-len(".whl")].split("-")
    if len(parts) < 5:
        return None
    own = (canonical(parts[0]), parts[1])
    found = {}
    for path, data in counted.items():
        if len(path.parts) != 3 or path.parts[1] != "licenses":
            continue
        folder = path.parts[0]
        if folder.endswith(".dist-info") and "-" in folder:
            distribution, _, version = folder[:-len(".dist-info")].rpartition("-")
            if (canonical(distribution), version) == own:
                found[path.name] = data
    return found


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

    def expect_only(label: str, path: pathlib.Path, code: str) -> None:
        """A planted case fails, and on the rule it plants -- not one next door."""
        printed = io.StringIO()
        with contextlib.redirect_stdout(printed):
            got = run(path)
        lines = printed.getvalue().splitlines()
        if got != 1 or not lines or not all(line.startswith(code + " ") for line in lines):
            failures.append(f"{label}: expected only {code}, got exit {got}: {lines}")

    def quiet(path: pathlib.Path) -> int:
        with contextlib.redirect_stdout(io.StringIO()):
            return run(path)

    # What a planted repository's root carries. Archives in the planted cases
    # carry the same bytes, so each case fails on the rule it plants and not
    # on L10 -- a case passing through a different rule proves nothing.
    ROOT_TEXT = {
        "LICENSE": "Apache License\nVersion 2.0\n",
        "NOTICE": f"game-ai-kit\nCopyright 2026 {COPYRIGHT_HOLDER}\n",
    }

    def make_repo(root: pathlib.Path) -> pathlib.Path:
        root.mkdir(parents=True, exist_ok=True)
        for name, text in ROOT_TEXT.items():
            (root / name).write_text(text)
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
        expect_only("zip without NOTICE", shipped, "L5")

        # Planted: an addon shipping bare, with a dependency's licence deeper
        # in the archive satisfying the basename check.
        deep = make_repo(root / "deep")
        make_addon(deep, "ai_search", with_files=True)
        (deep / "dist").mkdir()
        with zipfile.ZipFile(deep / "dist" / "ai_search.zip", "w") as bundle:
            bundle.writestr("ai_search/plugin.cfg", "[plugin]\n")
            bundle.writestr("ai_search/vendor/other/LICENSE", "MIT\n")
            bundle.writestr("ai_search/vendor/other/NOTICE", "someone else\n")
        expect_only("attribution only deep in the archive", deep, "L5")

        # Planted: a tarball, which was not examined at all.
        tarred = make_repo(root / "tarred")
        make_addon(tarred, "ai_search", with_files=True)
        (tarred / "dist").mkdir()
        with tarfile.open(tarred / "dist" / "kit.tar.gz", "w:gz") as bundle:
            lone = tarred / "plugin.cfg"
            lone.write_text("[plugin]\n")
            bundle.add(lone, arcname="kit/plugin.cfg")
        expect_only("tarball without attribution", tarred, "L5")

        # A wheel with both files where PEP 639 puts them passes.
        wheeled = make_repo(root / "wheeled")
        (wheeled / "dist").mkdir()
        with zipfile.ZipFile(wheeled / "dist" / "kit-1.0.0-py3-none-any.whl", "w") as bundle:
            bundle.writestr("kit/__init__.py", "")
            for required in REQUIRED_FILES:
                bundle.writestr(f"kit-1.0.0.dist-info/licenses/{required}", ROOT_TEXT[required])
        expect("wheel with its licences in .dist-info", quiet(wheeled), 0)

        # Planted: a wheel without NOTICE. Wheels were not opened at all.
        bare_wheel = make_repo(root / "bare-wheel")
        (bare_wheel / "dist").mkdir()
        with zipfile.ZipFile(bare_wheel / "dist" / "kit-1.0.0-py3-none-any.whl", "w") as bundle:
            bundle.writestr("kit-1.0.0.dist-info/licenses/LICENSE", ROOT_TEXT["LICENSE"])
        expect_only("wheel without NOTICE", bare_wheel, "L9")

        # Planted, each found by a review that crafted the wheel by hand: a
        # NOTICE that is a directory, one that is empty, and one belonging to a
        # dependency bundled alongside rather than to the wheel itself.
        crafted = {
            "directory": [("kit-1.0.0.dist-info/licenses/NOTICE/", "")],
            # zipfile lets a directory entry carry bytes; a size check alone
            # then counts it, which made the directory test look redundant.
            "directory-with-data": [("kit-1.0.0.dist-info/licenses/NOTICE/",
                                     ROOT_TEXT["NOTICE"])],
            "empty": [("kit-1.0.0.dist-info/licenses/NOTICE", "")],
            "foreign": [("other-2.0.dist-info/licenses/NOTICE", ROOT_TEXT["NOTICE"])],
        }
        for label, extra in crafted.items():
            wheel_repo = make_repo(root / f"crafted-{label}")
            (wheel_repo / "dist").mkdir()
            wheel_path = wheel_repo / "dist" / "kit-1.0.0-py3-none-any.whl"
            with zipfile.ZipFile(wheel_path, "w") as bundle:
                bundle.writestr("kit-1.0.0.dist-info/licenses/LICENSE", ROOT_TEXT["LICENSE"])
                for entry_name, content in extra:
                    bundle.writestr(entry_name, content)
            expect_only(f"wheel with a {label} NOTICE", wheel_repo, "L9")

        # Planted: an empty NOTICE in an addon zip.
        hollow_zip = make_repo(root / "hollow-zip")
        (hollow_zip / "dist").mkdir()
        with zipfile.ZipFile(hollow_zip / "dist" / "ai_search.zip", "w") as bundle:
            bundle.writestr("ai_search/LICENSE", ROOT_TEXT["LICENSE"])
            bundle.writestr("ai_search/NOTICE", "")
        expect_only("zip with an empty NOTICE", hollow_zip, "L5")

        # Planted: two top folders, the attribution in the one that is not the
        # addon. The depth rule alone passed this.
        two_tops = make_repo(root / "two-tops")
        (two_tops / "dist").mkdir()
        with zipfile.ZipFile(two_tops / "dist" / "ai_search.zip", "w") as bundle:
            bundle.writestr("ai_search/astar.gd", "extends Node\n")
            bundle.writestr("vendor/LICENSE", ROOT_TEXT["LICENSE"])
            bundle.writestr("vendor/NOTICE", ROOT_TEXT["NOTICE"])
        expect_only("zip whose attribution is in a second folder", two_tops, "L5")

        # Planted: a NOTICE somewhere other than .dist-info/licenses/. Each
        # path defeats exactly one of the conditions in wheel_licences, so
        # deleting any one of them turns one of these green. Written out rather
        # than generated, so a path deleted from the list is a visible diff.
        misplaced_notices = (
            "kit/licenses/NOTICE",                          # not in .dist-info
            "kit-1.0.0.dist-info/legal/NOTICE",             # not in licenses/
            "kit-1.0.0.dist-info/licenses/vendor/NOTICE",   # someone else's, deeper
            # the right name and version on a folder that is not .dist-info;
            # the suffix is ten characters, as long as the one the rule strips
            "kit-1.0.0.something/licenses/NOTICE",
        )
        for index, misplaced_path in enumerate(misplaced_notices):
            misplaced = make_repo(root / f"misplaced-wheel-{index}")
            (misplaced / "dist").mkdir()
            wheel_path = misplaced / "dist" / "kit-1.0.0-py3-none-any.whl"
            with zipfile.ZipFile(wheel_path, "w") as bundle:
                bundle.writestr("kit-1.0.0.dist-info/licenses/LICENSE", ROOT_TEXT["LICENSE"])
                bundle.writestr(misplaced_path, ROOT_TEXT["NOTICE"])
            expect_only(f"wheel with NOTICE at {misplaced_path}", misplaced, "L9")

        # Planted: a tarball whose NOTICE is empty. The content rule is
        # written twice, once per archive format, and each needs its case.
        hollow_tar = make_repo(root / "hollow-tar")
        (hollow_tar / "dist").mkdir()
        with tarfile.open(hollow_tar / "dist" / "kit.tar.gz", "w:gz") as bundle:
            for member_name, content in (("kit/LICENSE", ROOT_TEXT["LICENSE"].encode()), ("kit/NOTICE", b"")):
                member = tarfile.TarInfo(member_name)
                member.size = len(content)
                bundle.addfile(member, io.BytesIO(content))
        expect_only("tarball with an empty NOTICE", hollow_tar, "L5")

        # Planted: attribution present, in place, and not ours (L10). The
        # archive copies had only a size check, so `TODO` passed.
        for suffix, prefix in ((".zip", "ai_search/"), ("-1.0.0-py3-none-any.whl",
                                                         "kit-1.0.0.dist-info/licenses/")):
            impostor = make_repo(root / f"impostor{suffix}")
            (impostor / "dist").mkdir()
            name = ("ai_search" if suffix == ".zip" else "kit") + suffix
            with zipfile.ZipFile(impostor / "dist" / name, "w") as bundle:
                bundle.writestr(f"{prefix}LICENSE", "x\n")
                bundle.writestr(f"{prefix}NOTICE", "TODO\n")
            expect_only(f"{name} whose attribution is not the repository's", impostor, "L10")

        # Planted: a link named NOTICE, which is not a NOTICE.
        linked = make_repo(root / "linked")
        (linked / "dist").mkdir()
        with zipfile.ZipFile(linked / "dist" / "ai_search.zip", "w") as bundle:
            bundle.writestr("ai_search/LICENSE", ROOT_TEXT["LICENSE"])
            link = zipfile.ZipInfo("ai_search/NOTICE")
            link.create_system = 3
            link.external_attr = (0o120777 << 16)
            bundle.writestr(link, "../../NOTICE")
        expect_only("zip whose NOTICE is a link", linked, "L5")

        # Planted: a bare `.tar.xz`, a shape that was never opened.
        xz = make_repo(root / "xz")
        (xz / "dist").mkdir()
        with tarfile.open(xz / "dist" / "kit.tar.xz", "w:xz") as bundle:
            member = tarfile.TarInfo("kit/plugin.cfg")
            bundle.addfile(member, io.BytesIO(b""))
        expect_only("a .tar.xz without attribution", xz, "L5")

        # Two ordinary shapes that crashed the gate with a traceback and exit 1:
        # a tarball with a `.` member, as `tar -C dir -czf x .` writes it, and
        # a wheel whose name has no version in it.
        dotted = make_repo(root / "dotted")
        (dotted / "dist").mkdir()
        with tarfile.open(dotted / "dist" / "kit.tar.gz", "w:gz") as bundle:
            bundle.addfile(tarfile.TarInfo("."))
            for required in REQUIRED_FILES:
                content = ROOT_TEXT[required].encode()
                member = tarfile.TarInfo(f"./{required}")
                member.size = len(content)
                bundle.addfile(member, io.BytesIO(content))
        expect("a tarball with a '.' member", quiet(dotted), 0)
        unnamed = make_repo(root / "unnamed")
        (unnamed / "dist").mkdir()
        with zipfile.ZipFile(unnamed / "dist" / "kit.whl", "w") as bundle:
            bundle.writestr("kit/__init__.py", "")
        expect_only("a wheel not named like one", unnamed, "L9")

        # A third-party wheel whose .dist-info is spelled as its project spells
        # itself, as installers accept, passes.
        spelled = make_repo(root / "spelled")
        (spelled / "dist").mkdir()
        with zipfile.ZipFile(spelled / "dist" / "pyyaml-6.0.1-py3-none-any.whl", "w") as bundle:
            for required in REQUIRED_FILES:
                bundle.writestr(f"PyYAML-6.0.1.dist-info/licenses/{required}", ROOT_TEXT[required])
        expect("a wheel whose .dist-info is spelled differently", quiet(spelled), 0)

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
