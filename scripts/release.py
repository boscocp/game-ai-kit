#!/usr/bin/env python3
"""Build what ships: one zip per addon and one Python wheel, each attributed.

What it builds
--------------
Into `OUTPUT/dist/`, from what is committed and nothing else:

  * `ai_<name>-<version>.zip` for every addon under godot/addons/ that has
    tracked files, with a single top folder `ai_<name>/` holding LICENSE,
    NOTICE and VERSION beside the code -- unzip it into `res://addons/`;
  * `gameaikit-<version>-py3-none-any.whl`, the Python half, with LICENSE and
    NOTICE in `.dist-info/licenses/`, where PEP 639 says a wheel keeps them.

`OUTPUT` is laid out like the repository -- LICENSE and NOTICE at its root,
archives in `dist/` -- so `check_license.py --repo OUTPUT` reads a release
exactly as it reads the repository. That is the whole point: this script does
not get to say it attributed anything. The gate opens the archives and looks.

Why the wheel is written by hand
--------------------------------
The Python here is standard library only, and CI's tier-1 job asserts it by
having no install step. A pure-Python wheel is a zip with three small text
files in a `.dist-info` folder; writing them is fifty lines and needs nothing
installed, where calling a build backend would need setuptools first.

Why only tracked files
----------------------
What ships is what was reviewed. Walking the folder would pick up whatever
happens to be lying in it -- a scratch file, a `.import` cache -- and the
release would contain something no commit does.

Why `--skip-notice` exists
--------------------------
To prove the gate refuses. It builds every artifact without NOTICE and leaves
the root copy alone, so the *only* fault is inside the archives; a gate that
went red on the missing root file would be going red for the wrong reason. The
self-test asserts that every finding is about an archive.

Every build is byte-for-byte reproducible: entries are sorted and every
timestamp is the zip format's earliest, so two builds of one commit are equal
and a difference between them is a difference in the source.

Exit codes
----------
0   built
1   refused: VERSION malformed, or an addon or the package has no files
2   wrong usage, or not run inside a git checkout

Usage
-----
    release.py --build [--output PATH] [--skip-notice]
    release.py --self-test
"""

from __future__ import annotations

import argparse
import base64
import contextlib
import hashlib
import io
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

REPO = pathlib.Path(__file__).resolve().parent.parent
ATTRIBUTION = ("LICENSE", "NOTICE")
PACKAGE = "gameaikit"

# Major.minor.patch and nothing else. A suffix such as `-rc1` would need its
# own normalisation rules for a wheel's filename, and there is no release here
# that wants one yet.
VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")

# The earliest date a zip entry can carry. Any fixed date would do; a real one
# would make two builds of the same commit differ by when they were run.
EPOCH = (1980, 1, 1, 0, 0, 0)

# Python the wheel claims to run on: the oldest CI's ubuntu-latest image ships
# and the tests therefore run against.
REQUIRES_PYTHON = ">=3.12"


class Refused(Exception):
    """The build would produce something that should not ship."""


def tracked_files(repo: pathlib.Path, folder: str) -> list[str]:
    """Every committed path under `folder`, relative to the repository."""
    listing = subprocess.run(
        ["git", "-C", str(repo), "ls-files", "-z", "--", folder],
        capture_output=True, check=True, text=True,
    )
    return sorted(path for path in listing.stdout.split("\0") if path)


def read_version(repo: pathlib.Path) -> str:
    """The version every artifact is stamped with, from the one file that holds it."""
    version = (repo / "VERSION").read_text(encoding="utf-8").strip()
    if not VERSION_RE.match(version):
        raise Refused(f"VERSION reads {version!r}, which is not major.minor.patch")
    return version


def add_entry(bundle: zipfile.ZipFile, name: str, data: bytes) -> None:
    """Write one file with a fixed date and mode, so the build is reproducible."""
    entry = zipfile.ZipInfo(name, date_time=EPOCH)
    entry.compress_type = zipfile.ZIP_DEFLATED
    entry.external_attr = 0o644 << 16
    bundle.writestr(entry, data)


def attribution(repo: pathlib.Path, skip_notice: bool) -> dict[str, bytes]:
    """The files every artifact must carry, minus NOTICE when planting a fault."""
    names = [name for name in ATTRIBUTION if not (skip_notice and name == "NOTICE")]
    return {name: (repo / name).read_bytes() for name in names}


def build_addon(repo: pathlib.Path, addon: str, version: str,
                dist: pathlib.Path, skip_notice: bool) -> pathlib.Path:
    """Zip one addon under a single top folder named after it.

    The addon's own LICENSE and NOTICE are dropped and the root copies put in
    their place, so a stale copy inside an addon cannot ship instead of the
    real one. `check_license.py` already insists every addon carries its own;
    this decides which bytes those are.
    """
    prefix = f"godot/addons/{addon}/"
    files = {
        path[len(prefix):]: (repo / path).read_bytes()
        for path in tracked_files(repo, prefix)
        if path[len(prefix):] not in ATTRIBUTION
    }
    if not files:
        raise Refused(f"{addon} has no committed files to ship")
    files.update(attribution(repo, skip_notice))
    files["VERSION"] = f"{version}\n".encode()

    archive = dist / f"{addon}-{version}.zip"
    with zipfile.ZipFile(archive, "w") as bundle:
        for name in sorted(files):
            add_entry(bundle, f"{addon}/{name}", files[name])
    return archive


def record_line(name: str, data: bytes) -> str:
    """One row of a wheel's RECORD: path, urlsafe sha256 without padding, size."""
    digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b"=")
    return f"{name},sha256={digest.decode()},{len(data)}"


def wheel_metadata(version: str, licences: list[str]) -> dict[str, str]:
    """The `.dist-info` text files, apart from RECORD, which hashes all the rest."""
    metadata = [
        "Metadata-Version: 2.4",
        f"Name: {PACKAGE}",
        f"Version: {version}",
        "Summary: The Python half of game-ai-kit: a PDDL reader, the dataset "
        "simulator and the trainer that publishes weights for the Godot addons.",
        "License-Expression: Apache-2.0",
        *(f"License-File: {name}" for name in licences),
        f"Requires-Python: {REQUIRES_PYTHON}",
    ]
    wheel = [
        "Wheel-Version: 1.0",
        "Generator: game-ai-kit scripts/release.py",
        "Root-Is-Purelib: true",
        "Tag: py3-none-any",
    ]
    return {"METADATA": "\n".join(metadata) + "\n", "WHEEL": "\n".join(wheel) + "\n"}


def build_wheel(repo: pathlib.Path, version: str,
                dist: pathlib.Path, skip_notice: bool) -> pathlib.Path:
    """Write the Python package as a pure wheel, by hand.

    Everything goes in the archive except RECORD first; RECORD then lists
    every one of them with its hash, and itself without one, which is how the
    format says a reader knows the file it is reading is the last word.
    """
    files = {
        path[len("python/"):]: (repo / path).read_bytes()
        for path in tracked_files(repo, f"python/{PACKAGE}/")
    }
    if not files:
        raise Refused(f"python/{PACKAGE} has no committed files to ship")

    info = f"{PACKAGE}-{version}.dist-info"
    licences = attribution(repo, skip_notice)
    for name, data in licences.items():
        files[f"{info}/licenses/{name}"] = data
    for name, text in wheel_metadata(version, sorted(licences)).items():
        files[f"{info}/{name}"] = text.encode()

    record = [record_line(name, files[name]) for name in sorted(files)]
    record.append(f"{info}/RECORD,,")
    files[f"{info}/RECORD"] = ("\n".join(record) + "\n").encode()

    archive = dist / f"{PACKAGE}-{version}-py3-none-any.whl"
    with zipfile.ZipFile(archive, "w") as bundle:
        for name in sorted(files):
            add_entry(bundle, name, files[name])
    return archive


def shipped_addons(repo: pathlib.Path) -> list[str]:
    """Addons with committed files. gdUnit4 is installed, not committed, so it is not one."""
    names = {
        pathlib.PurePosixPath(path).parts[2]
        for path in tracked_files(repo, "godot/addons/")
    }
    return sorted(names)


def clear_previous(dist: pathlib.Path) -> None:
    """Remove artifacts an earlier build left, and only those.

    A zip from the last version left beside this one would be checked and
    shipped along with it. The patterns are this script's own names, so
    `weights.json` -- which `make train` stages in the same folder -- stays.
    """
    for pattern in ("ai_*-*.zip", f"{PACKAGE}-*.whl"):
        for stale in dist.glob(pattern):
            stale.unlink()


def build(repo: pathlib.Path, output: pathlib.Path, skip_notice: bool) -> list[pathlib.Path]:
    """Every artifact, into `output/dist/`, with the attribution at `output/`."""
    version = read_version(repo)
    dist = output / "dist"
    dist.mkdir(parents=True, exist_ok=True)
    clear_previous(dist)

    # The root copy is written even with --skip-notice: the fault planted is in
    # the archives, and the gate must find it there.
    if output.resolve() != repo.resolve():
        for name in ATTRIBUTION:
            shutil.copyfile(repo / name, output / name)

    artifacts = [
        build_addon(repo, addon, version, dist, skip_notice)
        for addon in shipped_addons(repo)
    ]
    artifacts.append(build_wheel(repo, version, dist, skip_notice))
    return artifacts


# --- self-test -------------------------------------------------------------


def license_gate(release: pathlib.Path) -> tuple[int, list[str]]:
    """Run the attribution gate on a release, as a separate process."""
    gate = REPO / "scripts" / "check_license.py"
    result = subprocess.run(
        [sys.executable, str(gate), "--repo", str(release)],
        capture_output=True, text=True,
    )
    return result.returncode, result.stdout.splitlines()


def self_test() -> int:
    failures = []

    def expect(label: str, condition: bool) -> None:
        if not condition:
            failures.append(label)

    def quiet_build(output: pathlib.Path, skip_notice: bool) -> list[pathlib.Path]:
        with contextlib.redirect_stdout(io.StringIO()):
            return build(REPO, output, skip_notice)

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)

        good = root / "good"
        artifacts = quiet_build(good, skip_notice=False)
        code, findings = license_gate(good)
        expect(f"a complete release passes the gate (got {code}: {findings})", code == 0)
        expect("one zip per addon plus the wheel",
               len(artifacts) == len(shipped_addons(REPO)) + 1)

        # Planted: every artifact without NOTICE. The gate must fail, and fail
        # once per artifact on the archive rule -- not on the root file, which
        # this build deliberately leaves in place.
        bad = root / "bad"
        planted = quiet_build(bad, skip_notice=True)
        code, findings = license_gate(bad)
        expect("a release without NOTICE fails the gate", code == 1)
        expect(f"every finding is about an archive (got {findings})",
               all(line.startswith(("L5 ", "L9 ")) for line in findings))
        expect(f"one finding per artifact (got {len(findings)} for {len(planted)})",
               len(findings) == len(planted))

        # Two builds of one commit are the same bytes. Comparing two builds is
        # not enough on its own: both run inside the same second, so a date
        # read from the clock would match too. Every entry's date is read.
        again = quiet_build(root / "again", skip_notice=False)
        expect("the build is reproducible",
               [path.read_bytes() for path in artifacts]
               == [path.read_bytes() for path in again])
        expect("every entry carries the fixed date",
               all(dates_are_fixed(path) for path in artifacts))

        # Every artifact is stamped with the version in VERSION.
        version = read_version(REPO)
        expect("every artifact is stamped with VERSION",
               all(stamped_version(path) == version for path in artifacts))

        # The wheel is a wheel: unpacked the way an installer unpacks a pure
        # one, its modules import, and its RECORD matches what it holds.
        # Importing from the zip directly is stricter than any installer and
        # wrong for this package -- `dataset/` and `training/` are namespace
        # packages, which zipimport does not find.
        wheel = artifacts[-1]
        site = root / "site-packages"
        with zipfile.ZipFile(wheel) as bundle:
            bundle.extractall(site)
        probe = subprocess.run(
            [sys.executable, "-I", "-c",
             f"import sys; sys.path.insert(0, {str(site)!r}); "
             "import gameaikit.pddl.reader, gameaikit.dataset.simulate, "
             "gameaikit.training.report"],
            capture_output=True, text=True, cwd=root,
        )
        expect(f"the wheel imports ({probe.stderr.strip()})", probe.returncode == 0)
        expect("RECORD hashes every entry", record_is_true(wheel))

        # Planted: a malformed VERSION is refused rather than stamped.
        fake = root / "fake-repo"
        fake.mkdir()
        (fake / "VERSION").write_text("0.1\n")
        try:
            read_version(fake)
            expect("a malformed VERSION is refused", False)
        except Refused:
            pass

        # Planted: a stale artifact from an earlier version is removed, and a
        # file `make train` staged in dist/ is not.
        (good / "dist" / "ai_search-0.0.1.zip").write_bytes(b"stale")
        (good / "dist" / "weights.json").write_text("{}")
        quiet_build(good, skip_notice=False)
        expect("a stale artifact is cleared",
               not (good / "dist" / "ai_search-0.0.1.zip").exists())
        expect("weights.json is left alone", (good / "dist" / "weights.json").exists())

    unknown = subprocess.run(
        [sys.executable, str(pathlib.Path(__file__).resolve()), "--unknown-flag"],
        capture_output=True,
    )
    expect("an unknown flag exits 2", unknown.returncode == 2)

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def dates_are_fixed(archive: pathlib.Path) -> bool:
    """No entry carries the time it was built at."""
    with zipfile.ZipFile(archive) as bundle:
        return all(entry.date_time == EPOCH for entry in bundle.infolist())


def stamped_version(archive: pathlib.Path) -> str | None:
    """The version an artifact says it is, read from inside it rather than its name."""
    with zipfile.ZipFile(archive) as bundle:
        for name in bundle.namelist():
            if archive.suffix == ".zip" and name.count("/") == 1 and name.endswith("/VERSION"):
                return bundle.read(name).decode().strip()
            if archive.suffix == ".whl" and name.endswith(".dist-info/METADATA"):
                fields = dict(line.split(": ", 1)
                              for line in bundle.read(name).decode().splitlines())
                return fields.get("Version")
    return None


def record_is_true(wheel: pathlib.Path) -> bool:
    """Every entry but RECORD is listed in RECORD with its real hash and size."""
    with zipfile.ZipFile(wheel) as bundle:
        names = bundle.namelist()
        record_name = next(name for name in names if name.endswith(".dist-info/RECORD"))
        listed = bundle.read(record_name).decode().splitlines()
        expected = [record_line(name, bundle.read(name))
                    for name in sorted(names) if name != record_name]
    return listed == expected + [f"{record_name},,"]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--build", action="store_true")
    parser.add_argument("--output", default=None,
                        help="release root; archives go to OUTPUT/dist (default: the repo)")
    parser.add_argument("--skip-notice", action="store_true",
                        help="plant a fault: build every artifact without NOTICE")
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        if exit_request.code == 0:
            raise
        return 2

    if args.self_test:
        return self_test()
    if not args.build:
        parser.print_usage(sys.stderr)
        return 2

    output = pathlib.Path(args.output) if args.output else REPO
    try:
        artifacts = build(REPO, output, args.skip_notice)
    except Refused as refusal:
        print(f"release: refused: {refusal}", file=sys.stderr)
        return 1
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"release: cannot build: {error}", file=sys.stderr)
        return 2

    for artifact in artifacts:
        print(artifact)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
