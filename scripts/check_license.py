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
  * every picture committed under godot/assets/ is listed, by path, in
    godot/assets/LICENCES.md with its pack and its licence -- and every row
    there names a file that is committed.

The art rule reads `git ls-files`, not the disk. T31 lets a person generate
their own pictures into the same folders, gitignored, and those are theirs:
nothing to attribute and nothing for this gate to trip on.

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
import hashlib
import io
import lzma
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import tarfile
import zipfile
import zlib

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

# Everything reading an archive's bytes can raise when the archive is broken.
# Each of these escaped as a traceback and exit 1 -- the findings code -- once
# the gate began reading content: an encrypted entry, an unknown compression
# method, corrupt deflate data, a truncated `.tar.xz`. Broken is exit 2.
UNREADABLE = (OSError, EOFError, RuntimeError, NotImplementedError,
              zipfile.BadZipFile, tarfile.TarError, zlib.error, lzma.LZMAError)

# Larger than any attribution file, and read no further: a NOTICE that
# decompresses to a gigabyte is not this repository's, and finding that out
# should not cost a gigabyte. Such an entry is read as not ours (L10).
MAX_ATTRIBUTION_BYTES = 1 << 20


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
                pathlib.PurePosixPath(member.filename):
                    bundle.read(member) if member.file_size <= MAX_ATTRIBUTION_BYTES else None
                for member in members
                if not member.is_dir() and not is_zip_link(member) and member.file_size > 0
                and pathlib.PurePosixPath(member.filename).name in REQUIRED_FILES
            }
    else:
        with tarfile.open(archive) as bundle:
            members = bundle.getmembers()
            paths = [pathlib.PurePosixPath(member.name) for member in members]
            counted = {
                pathlib.PurePosixPath(member.name):
                    bundle.extractfile(member).read() if member.size <= MAX_ATTRIBUTION_BYTES
                    else None
                for member in members
                if member.isfile() and member.size > 0
                and pathlib.PurePosixPath(member.name).name in REQUIRED_FILES
            }
    return [path for path in paths if path.parts], counted


def is_zip_link(member: zipfile.ZipInfo) -> bool:
    """A symbolic link stored the Unix way: the file type sits in the high bits."""
    return (member.external_attr >> 16) & 0o170000 == 0o120000


def committed_attribution(repo: pathlib.Path) -> dict[str, bytes]:
    """The LICENSE and NOTICE an artifact must carry: HEAD's, or the root's outside git.

    An archive's copy used to be compared with the file on disk, and two
    ordinary checkouts then failed a correct release: one whose line endings
    git converts (Git for Windows does by default), and one with NOTICE edited
    and not yet committed -- where the message blamed the archives, which held
    exactly what was committed. `release.py` builds from HEAD, so HEAD is what
    to compare with. A release folder, as `--output` writes it, is not a
    checkout, and its root copies are HEAD's already.
    """
    # `git -C` searches upwards, so a release folder that happens to sit inside
    # some other checkout would be compared with that checkout's files.
    toplevel = subprocess.run(["git", "-C", str(repo), "rev-parse", "--show-toplevel"],
                              capture_output=True, text=True)
    is_checkout = (toplevel.returncode == 0
                   and pathlib.Path(toplevel.stdout.strip()).resolve() == repo.resolve())
    baseline = {}
    for name in REQUIRED_FILES:
        committed = subprocess.run(["git", "-C", str(repo), "show", f"HEAD:{name}"],
                                   capture_output=True) if is_checkout else None
        if committed is not None and committed.returncode == 0:
            baseline[name] = committed.stdout
        elif (repo / name).exists():
            baseline[name] = (repo / name).read_bytes()
    return baseline


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
    baseline = committed_attribution(repo)
    for archive in archives:
        findings.extend(check_one_archive(archive, baseline))
    return findings


def check_one_archive(archive: pathlib.Path, baseline: dict[str, bytes]) -> list[str]:
    """Where an archive keeps its attribution, whether it is ours, and whether it stays inside."""
    paths, counted = archive_files(archive)
    # A member at `../x` or `/x` lands outside the folder it is unpacked into,
    # and both used to count as the archive's one top folder.
    findings = [f"L11 {archive.name} has a member outside its own folder: {path}"
                for path in paths if path.is_absolute() or ".." in path.parts]
    if archive.suffix == ".whl":
        located = wheel_licences(archive.name, counted)
        if located is None:
            return findings + [f"L9 {archive.name} is not named like a wheel"]
        code, where = "L9", "in its .dist-info/licenses/"
    else:
        located = attributed_files(paths, counted)
        code, where = "L5", "at its root or in its top folder"
    for name in REQUIRED_FILES:
        if name not in located:
            findings.append(f"{code} {archive.name} has no {name} {where}")
        elif name in baseline and located[name] != baseline[name]:
            findings.append(f"L10 {archive.name} carries a {name} that is not the one "
                            "committed -- rebuild it with `make release`")
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


def wheel_licences(name: str,
                   counted: dict[pathlib.PurePosixPath, bytes]) -> dict[str, bytes] | None:
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


# The art and the table that attributes it. Files beside the pictures that
# are not pictures: the table itself, and Godot's `.import` sidecars, which
# hold import settings and are the engine's, not an artist's.
ASSETS = "godot/assets"
ASSET_LIST = "LICENCES.md"
# The table's header, cell for cell. Read by name rather than by position, so
# a row that lost a cell cannot have its pack read as its licence.
ASSET_COLUMNS = ("path", "pack", "file in the pack", "licence", "sha256")
# The licences a committed picture may carry. Only CC0 today: anything else
# needs a decision about attribution first, and a decision is not a typo.
ALLOWED_LICENCES = ("CC0 1.0",)
# Text the table must not be read from: a fenced block or an HTML comment can
# show a row without granting one.
NOT_TABLE = re.compile(r"```.*?```|<!--.*?-->", re.DOTALL)


def check_assets(repo: pathlib.Path) -> list[str]:
    """Report committed art the table does not attribute, and rows for no file.

    The sha256 is what makes a row mean *this* picture. Without it, a generated
    file written over a CC0 path and committed would still be credited to the
    pack -- the path is listed, so the path rule is satisfied.
    """
    committed = tracked_assets(repo)
    if not committed:
        return []
    table = repo / ASSETS / ASSET_LIST
    rows, findings = asset_rows(table.read_text(encoding="utf-8")) if table.exists() else (None, [])
    if rows is None:
        return [f"L14 {ASSETS} has {len(committed)} committed file(s) and no {ASSET_LIST} table "
                f"headed {' | '.join(ASSET_COLUMNS)}"]
    pictures = [path for path in committed if not path.endswith(".import")]
    for path in pictures:
        if path not in rows:
            findings.append(f"L11 {ASSETS}/{path} is committed and not listed in {ASSET_LIST}")
        elif rows[path] is not None and rows[path]["sha256"] != committed_sha256(repo, path):
            findings.append(f"L17 {ASSETS}/{path} is not the file its row attributes: its sha256 differs")
    for path in sorted(set(rows) - set(pictures)):
        findings.append(f"L13 {ASSET_LIST} lists {path}, which is not committed")
    for path in committed:
        if path.endswith(".import") and path.removesuffix(".import") not in pictures:
            findings.append(f"L16 {ASSETS}/{path} is an import sidecar with no picture beside it")
    return findings


def tracked_assets(repo: pathlib.Path) -> list[str]:
    """Files under godot/assets/ in git's index, relative to it, bar the table."""
    if not (repo / ASSETS).is_dir():
        return []
    listed = subprocess.run(["git", "-C", str(repo), "ls-files", "-z", "--", ASSETS],
                            capture_output=True, check=True).stdout.decode()
    paths = [name[len(ASSETS) + 1:] for name in listed.split("\0") if name]
    return [path for path in paths if path != ASSET_LIST]


def committed_sha256(repo: pathlib.Path, path: str) -> str:
    """The sha256 of a file as git's index holds it, which is what a commit takes."""
    blob = subprocess.run(["git", "-C", str(repo), "show", f":{ASSETS}/{path}"],
                          capture_output=True, check=True).stdout
    return hashlib.sha256(blob).hexdigest()


def asset_rows(text: str) -> tuple[dict[str, dict[str, str] | None] | None, list[str]]:
    """The table's rows by path, and what is wrong with any of them.

    A malformed row maps its path to None: it is reported once, as malformed,
    rather than a second time as a picture nobody listed. The whole answer is
    None when there is no table with the expected header, and nothing in the
    file then counts as attribution.
    """
    lines = [line.strip() for line in NOT_TABLE.sub("", text).splitlines()]
    header = "| " + " | ".join(ASSET_COLUMNS) + " |"
    if header not in lines:
        return None, []
    rows: dict[str, dict[str, str] | None] = {}
    findings = []
    for line in lines[lines.index(header) + 2:]:
        if not line.startswith("|"):
            break
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        problem = row_problem(cells)
        path = cells[0].strip("`")
        if path in rows:
            findings.append(f"L15 {ASSET_LIST} lists {path} twice")
        elif problem:
            findings.append(f"L12 {ASSET_LIST} row for {path or '(no path)'}: {problem}")
            rows[path] = None
        else:
            rows[path] = dict(zip(ASSET_COLUMNS, [path] + cells[1:]))
    return rows, findings


def row_problem(cells: list[str]) -> str:
    """Why a row attributes nothing, or an empty string when it is whole."""
    if len(cells) != len(ASSET_COLUMNS):
        return f"{len(cells)} cells where the header has {len(ASSET_COLUMNS)}"
    row = dict(zip(ASSET_COLUMNS, cells))
    if not row["path"].startswith("`") or not row["pack"]:
        return "no path in backticks, or no pack"
    if row["licence"] not in ALLOWED_LICENCES:
        return f"licence {row['licence']!r} is not one of {', '.join(ALLOWED_LICENCES)}"
    if not re.fullmatch(r"[0-9a-f]{64}", row["sha256"]):
        return "no sha256"
    return ""


def run(repo: pathlib.Path) -> int:
    findings = (check_root(repo) + check_addons(repo) + check_release_archives(repo)
                + check_assets(repo))
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
            planted_members = (("kit/LICENSE", ROOT_TEXT["LICENSE"].encode()),
                               ("kit/NOTICE", b""))
            for member_name, content in planted_members:
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

        # A .dist-info spelled as its project spells itself -- `PyYAML` inside
        # `pyyaml-...whl` -- is the wheel's own, as installers accept. The
        # case tests the name match only: it carries this repository's files,
        # and a real third-party wheel in dist/ is refused on L10, because
        # dist/ is where this repository's own artifacts go.
        spelled = make_repo(root / "spelled")
        (spelled / "dist").mkdir()
        with zipfile.ZipFile(spelled / "dist" / "pyyaml-6.0.1-py3-none-any.whl", "w") as bundle:
            for required in REQUIRED_FILES:
                bundle.writestr(f"PyYAML-6.0.1.dist-info/licenses/{required}", ROOT_TEXT[required])
        expect("a wheel whose .dist-info is spelled differently", quiet(spelled), 0)

        # Planted: members outside the folder they unpack into, both ways.
        for label, prefix in (("parent", "../"), ("absolute", "/")):
            escaping = make_repo(root / f"escaping-{label}")
            (escaping / "dist").mkdir()
            with zipfile.ZipFile(escaping / "dist" / "ai_search.zip", "w") as bundle:
                for required in REQUIRED_FILES:
                    bundle.writestr(f"{prefix}{required}", ROOT_TEXT[required])
                bundle.writestr(f"{prefix}astar.gd", "extends Node\n")
            expect_only(f"zip with {label} member paths", escaping, "L11")

        # Planted: a NOTICE past the size any attribution has. It is read as
        # not ours, and not read in full.
        swollen = make_repo(root / "swollen")
        (swollen / "dist").mkdir()
        with zipfile.ZipFile(swollen / "dist" / "ai_search.zip", "w",
                             compression=zipfile.ZIP_DEFLATED) as bundle:
            bundle.writestr("ai_search/LICENSE", ROOT_TEXT["LICENSE"])
            bundle.writestr("ai_search/NOTICE", b"\0" * (MAX_ATTRIBUTION_BYTES + 1))
        expect_only("zip with a NOTICE too large to be ours", swollen, "L10")

        # Planted: an archive whose NOTICE cannot be decompressed. Broken is
        # exit 2, not a traceback and not a finding.
        corrupt = make_repo(root / "corrupt")
        (corrupt / "dist").mkdir()
        corrupt_zip = corrupt / "dist" / "ai_search.zip"
        with zipfile.ZipFile(corrupt_zip, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
            bundle.writestr("ai_search/LICENSE", ROOT_TEXT["LICENSE"])
            bundle.writestr("ai_search/NOTICE", ROOT_TEXT["NOTICE"] * 50)
        damaged = bytearray(corrupt_zip.read_bytes())
        start = damaged.index(b"ai_search/NOTICE") + len("ai_search/NOTICE")
        damaged[start:start + 40] = b"\xff" * 40
        corrupt_zip.write_bytes(bytes(damaged))
        with contextlib.redirect_stderr(io.StringIO()):
            expect("a zip whose NOTICE cannot be read", main(["--repo", str(corrupt)]), 2)

        # A checkout whose line endings differ from the commit, as Git for
        # Windows makes by default, carries a correct release. Comparing with
        # the file on disk failed every artifact on L10.
        converted = make_repo(root / "converted")
        git = ["git", "-C", str(converted), "-c", "user.name=t", "-c", "user.email=t@t"]
        subprocess.run(git[:3] + ["init", "-q"], check=True)
        subprocess.run(git + ["add", "LICENSE", "NOTICE"], check=True)
        subprocess.run(git + ["commit", "-q", "-m", "attribution"], check=True)
        for required in REQUIRED_FILES:
            (converted / required).write_bytes(ROOT_TEXT[required].replace("\n", "\r\n").encode())
        (converted / "dist").mkdir()
        with zipfile.ZipFile(converted / "dist" / "ai_search.zip", "w") as bundle:
            for required in REQUIRED_FILES:
                bundle.writestr(f"ai_search/{required}", ROOT_TEXT[required])
        expect("a checkout with converted line endings", quiet(converted), 0)

        # Planted: a release folder sitting inside some other checkout. `git -C`
        # searches upwards, and that checkout's NOTICE is not this release's.
        outer = root / "outer"
        outer.mkdir()
        git = ["git", "-C", str(outer), "-c", "user.name=t", "-c", "user.email=t@t"]
        subprocess.run(git[:3] + ["init", "-q"], check=True)
        for required in REQUIRED_FILES:
            (outer / required).write_text("someone else's\n")
        subprocess.run(git + ["add", "LICENSE", "NOTICE"], check=True)
        subprocess.run(git + ["commit", "-q", "-m", "other"], check=True)
        nested = make_repo(outer / "release")
        (nested / "dist").mkdir()
        with zipfile.ZipFile(nested / "dist" / "ai_search.zip", "w") as bundle:
            for required in REQUIRED_FILES:
                bundle.writestr(f"ai_search/{required}", ROOT_TEXT[required])
        expect("a release folder inside another checkout", quiet(nested), 0)

        # Planted: a LICENSE that says nothing. Only NOTICE had a content check.
        placeholder = make_repo(root / "placeholder")
        (placeholder / "LICENSE").write_text("TODO: pick a licence\n")
        expect("placeholder LICENSE", quiet(placeholder), 1)

        art_cases(root, make_repo, expect, expect_only, quiet)

        script = pathlib.Path(__file__).resolve()
        extra = subprocess.run(
            [sys.executable, str(script), "--unknown-flag"], capture_output=True
        )
        expect("unknown flag", extra.returncode, 2)

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


# --- the art rule's planted cases --------------------------------------------

PICTURE = b"\x89PNG one"
OTHER_PICTURE = b"\x89PNG another"


def art_row(path: str, licence: str = "CC0 1.0", picture: bytes = PICTURE, pack: str = "Tiny Battle") -> str:
    """One table row attributing `picture` at `path`."""
    digest = hashlib.sha256(picture).hexdigest()
    return f"| `{path}` | {pack} | `tile_0149.png` | {licence} | {digest} |\n"


def art_repo(repo: pathlib.Path, table: str | None, pictures: dict[str, bytes],
             ignored: tuple[str, ...] = ()) -> pathlib.Path:
    """A git repository with these pictures in its index and this table.

    Staged, not committed: the rule reads the index, and a commit would only
    add a way for the case to fail on a machine that signs commits.
    """
    git = ["git", "-C", str(repo)]
    subprocess.run(git + ["init", "-q"], check=True)
    assets = repo / ASSETS
    for path, data in list(pictures.items()) + [(path, PICTURE) for path in ignored]:
        (assets / path).parent.mkdir(parents=True, exist_ok=True)
        (assets / path).write_bytes(data)
    if table is not None:
        header = "| " + " | ".join(ASSET_COLUMNS) + " |\n|" + "---|" * len(ASSET_COLUMNS) + "\n"
        (assets / ASSET_LIST).write_text(header + table)
    (repo / ".gitignore").write_text("".join(f"{ASSETS}/{path}\n" for path in ignored))
    subprocess.run(git + ["add", "-A"], check=True)
    return repo


def art_cases(root: pathlib.Path, make_repo, expect, expect_only, quiet) -> None:
    """Every art rule, each against a repository of its own."""
    runner = {"units/runner.png": PICTURE}

    def case(name: str, table: str | None, pictures: dict[str, bytes], **extra) -> pathlib.Path:
        return art_repo(make_repo(root / name), table, pictures, **extra)

    listed = case("art-listed", art_row("units/runner.png"), runner | {"units/runner.png.import": b"[remap]"})
    expect("every picture listed; its .import sidecar is not art", quiet(listed), 0)
    # T31: a person's generated picture, gitignored, is theirs and unlisted.
    generated = case("art-generated", art_row("units/runner.png"), runner, ignored=("generated/ram.png",))
    expect("a gitignored generated picture", quiet(generated), 0)

    planted = {
        "L11": case("art-unlisted", art_row("units/runner.png"), runner | {"units/ram.png": OTHER_PICTURE}),
        "L13": case("art-stale", art_row("units/runner.png") + art_row("units/ram.png"), runner),
        "L14": case("art-no-table", None, runner),
        "L15": case("art-twice", art_row("units/runner.png") * 2, runner),
        "L16": case("art-orphan-import", art_row("units/runner.png"), runner | {"units/ram.png.import": b"[remap]"}),
        # A generated picture written over a CC0 path: listed, and not that file.
        "L17": case("art-overwritten", art_row("units/runner.png"), {"units/runner.png": OTHER_PICTURE}),
    }
    for code, repo in planted.items():
        expect_only(f"planted {code}", repo, code)
    art_table_cases(root, make_repo, case, expect, expect_only)
    art_row_cases(root, case, expect_only)
    art_outside_git(root, make_repo, expect)


def art_table_cases(root: pathlib.Path, make_repo, case, expect, expect_only) -> None:
    """What counts as the table, and which copy of a picture is the one judged."""
    runner = {"units/runner.png": PICTURE}
    header = "| " + " | ".join(ASSET_COLUMNS) + " |\n|" + "---|" * len(ASSET_COLUMNS) + "\n"
    for name, text in {"rows with no header": art_row("units/runner.png"),
                       "a table only inside a fence": "```\n" + header + art_row("units/runner.png") + "```\n",
                       "a table only inside a comment": "<!--\n" + header + art_row("units/runner.png") + "-->\n"}.items():
        repo = case("art-" + name.replace(" ", "-"), None, runner)
        (repo / ASSETS / ASSET_LIST).write_text(text)
        expect_only(name, repo, "L14")
    # The index is what a commit takes. A picture changed on disk and not
    # staged is not yet anybody's attribution problem.
    unstaged = case("art-unstaged-edit", art_row("units/runner.png"), runner)
    (unstaged / ASSETS / "units/runner.png").write_bytes(OTHER_PICTURE)
    expect("a picture edited on disk, not staged", quiet_run(unstaged), 0)


def quiet_run(repo: pathlib.Path) -> int:
    """`run`, with its findings swallowed."""
    with contextlib.redirect_stdout(io.StringIO()):
        return run(repo)


def art_row_cases(root: pathlib.Path, case, expect_only) -> None:
    """L12: each way a row can look like attribution without being one."""
    runner = {"units/runner.png": PICTURE}
    whole = art_row("units/runner.png")
    malformed = {
        "no licence": whole.replace("CC0 1.0", ""),
        "a licence that is not allowed": art_row("units/runner.png", licence="All rights reserved"),
        "no pack": art_row("units/runner.png", pack=""),
        "a cell missing": whole.replace("| `tile_0149.png` ", ""),
        "an extra cell": whole.rstrip("\n") + " a note |\n",
        "no sha256": whole.replace(hashlib.sha256(PICTURE).hexdigest(), ""),
    }
    for label, row in malformed.items():
        expect_only(f"a row with {label}", case("art-row-" + label.replace(" ", "-"), row, runner), "L12")


def art_outside_git(root: pathlib.Path, make_repo, expect) -> None:
    """Art where git cannot say what is committed: exit 2, never a quiet 0."""
    loose = make_repo(root / "art-not-a-checkout")
    (loose / ASSETS).mkdir(parents=True)
    (loose / ASSETS / "ram.png").write_bytes(PICTURE)
    script = pathlib.Path(__file__).resolve()
    outside = subprocess.run([sys.executable, str(script), "--repo", str(loose)], capture_output=True,
                             env={**os.environ, "GIT_CEILING_DIRECTORIES": str(root)})
    expect("art git cannot account for", outside.returncode, 2)


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
    except UNREADABLE + (subprocess.CalledProcessError,) as error:
        # The art rule asks git what is committed. Art in a folder git cannot
        # answer for is a question this gate cannot settle, not a clean pass.
        print(f"check_license: cannot read a file: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
