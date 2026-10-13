#!/usr/bin/env python3
"""Build what ships: one zip per addon and one Python wheel, each attributed.

What it builds
--------------
Into `OUTPUT/dist/`, from the commit at HEAD and nothing else:

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

Why HEAD, and not the folder
----------------------------
What ships is what was reviewed. Walking the folder would pick up whatever
happens to be lying in it -- a scratch file, a `.import` cache. And listing
tracked paths is not enough either: the first version did that and then read
the bytes off disk, so a review edited a tracked file and staged a new one
without committing either, and both shipped. Paths and bytes both come from
git now, so an edit nobody committed cannot reach an artifact.

Why `--skip-notice` exists
--------------------------
To prove the gate refuses. It builds every artifact without NOTICE and leaves
the root copy alone, so the *only* fault is inside the archives; a gate that
went red on the missing root file would be going red for the wrong reason. The
self-test asserts that every finding is about an archive.

Every build is byte-for-byte reproducible: entries are sorted, every
timestamp is the zip format's earliest, and the system each entry claims to
have been made on is fixed, so two builds of one commit are equal on any
machine and a difference between them is a difference in the source.

Exit codes
----------
0   built
1   refused: VERSION malformed, an addon or the package has no files, or
    the output would land inside the repository's own dist/
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


def committed_files(repo: pathlib.Path, folder: str) -> list[str]:
    """Every path under `folder` in the commit at HEAD -- not staged, not on disk."""
    listing = subprocess.run(
        ["git", "-C", str(repo), "ls-tree", "-r", "-z", "--name-only", "HEAD", "--", folder],
        capture_output=True, check=True, text=True,
    )
    return sorted(path for path in listing.stdout.split("\0") if path)


def committed_bytes(repo: pathlib.Path, path: str) -> bytes:
    """A file's content as HEAD has it, whatever the working tree says."""
    return subprocess.run(
        ["git", "-C", str(repo), "show", f"HEAD:{path}"],
        capture_output=True, check=True,
    ).stdout


def checked_version(text: str) -> str:
    """The version, or a refusal when it is not major.minor.patch."""
    version = text.strip()
    if not VERSION_RE.match(version):
        raise Refused(f"VERSION reads {version!r}, which is not major.minor.patch")
    return version


def read_version(repo: pathlib.Path) -> str:
    """The version every artifact is stamped with, from the one file that holds it."""
    return checked_version(committed_bytes(repo, "VERSION").decode("utf-8"))


def add_entry(bundle: zipfile.ZipFile, name: str, data: bytes) -> None:
    """Write one file with a fixed date and mode, so the build is reproducible."""
    entry = zipfile.ZipInfo(name, date_time=EPOCH)
    entry.compress_type = zipfile.ZIP_DEFLATED
    entry.external_attr = 0o644 << 16
    # Unix, whatever machine builds it. Left to the default, a build on
    # Windows writes 0 here and the two releases of one commit differ.
    entry.create_system = 3
    bundle.writestr(entry, data)


def attribution(repo: pathlib.Path, skip_notice: bool) -> dict[str, bytes]:
    """The files every artifact must carry, minus NOTICE when planting a fault."""
    names = [name for name in ATTRIBUTION if not (skip_notice and name == "NOTICE")]
    return {name: committed_bytes(repo, name) for name in names}


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
        path[len(prefix):]: committed_bytes(repo, path)
        for path in committed_files(repo, prefix)
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
        path[len("python/"):]: committed_bytes(repo, path)
        for path in committed_files(repo, f"python/{PACKAGE}/")
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
        for path in committed_files(repo, "godot/addons/")
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
    # The repository's own dist/ is where the gate looks for archives, and
    # only at its top. A release rooted there writes them one level down,
    # where nothing checks them.
    if output.resolve().is_relative_to((repo / "dist").resolve()):
        raise Refused(f"{output} is inside the repository's dist/; "
                      "use the repository itself or a folder outside it")
    dist = output / "dist"
    dist.mkdir(parents=True, exist_ok=True)
    clear_previous(dist)

    # The root copy is written even with --skip-notice: the fault planted is in
    # the archives, and the gate must find it there.
    if output.resolve() != repo.resolve():
        for name in ATTRIBUTION:
            (output / name).write_bytes(committed_bytes(repo, name))

    artifacts = [
        build_addon(repo, addon, version, dist, skip_notice)
        for addon in shipped_addons(repo)
    ]
    artifacts.append(build_wheel(repo, version, dist, skip_notice))
    return artifacts


# --- self-test -------------------------------------------------------------
#
# Each check returns the labels of what failed, so the runner at the bottom
# can say which claim broke rather than that something did.


def license_gate(release: pathlib.Path) -> tuple[int, list[str]]:
    """Run the attribution gate on a release, as a separate process."""
    gate = REPO / "scripts" / "check_license.py"
    result = subprocess.run(
        [sys.executable, str(gate), "--repo", str(release)],
        capture_output=True, text=True,
    )
    return result.returncode, result.stdout.splitlines()


def quiet_build(repo: pathlib.Path, output: pathlib.Path,
                skip_notice: bool = False) -> list[pathlib.Path]:
    """A build whose list of artifacts is not printed."""
    with contextlib.redirect_stdout(io.StringIO()):
        return build(repo, output, skip_notice)


def check_the_gate_agrees(root: pathlib.Path) -> list[str]:
    """A complete release passes the gate; one without NOTICE fails it, per artifact."""
    failures = []
    artifacts = quiet_build(REPO, root / "good")
    code, findings = license_gate(root / "good")
    if code != 0:
        failures.append(f"a complete release passes the gate (got {code}: {findings})")
    if len(artifacts) != len(shipped_addons(REPO)) + 1:
        failures.append("one zip per addon plus the wheel")

    # Planted: every artifact without NOTICE. The gate must fail, and fail
    # once per artifact on the archive rule -- not on the root file, which
    # this build deliberately leaves in place.
    planted = quiet_build(REPO, root / "bad", skip_notice=True)
    code, findings = license_gate(root / "bad")
    if code != 1:
        failures.append("a release without NOTICE fails the gate")
    if not all(line.startswith(("L5 ", "L9 ")) for line in findings):
        failures.append(f"every finding is about an archive (got {findings})")
    if len(findings) != len(planted):
        failures.append(f"one finding per artifact (got {len(findings)} for {len(planted)})")
    return failures


def check_reproducible_and_stamped(root: pathlib.Path) -> list[str]:
    """Two builds are the same bytes, carry no clock, and say their version."""
    failures = []
    first = quiet_build(REPO, root / "first")
    second = quiet_build(REPO, root / "second")
    if [path.read_bytes() for path in first] != [path.read_bytes() for path in second]:
        failures.append("the build is reproducible")
    # Comparing two builds is not enough on its own: both run inside the same
    # second, so a date read from the clock would match too.
    if not all(entries_are_fixed(path) for path in first):
        failures.append("every entry carries the fixed date and system")
    version = read_version(REPO)
    if not all(stamped_version(path) == version for path in first):
        failures.append("every artifact is stamped with VERSION")
    return failures


def check_the_wheel(root: pathlib.Path) -> list[str]:
    """The wheel is well formed by the spec, and its modules import once unpacked."""
    wheel = quiet_build(REPO, root / "wheel")[-1]
    failures = [f"the wheel is well formed: {problem}" for problem in wheel_problems(wheel)]
    # Unpacked the way an installer unpacks a pure wheel. Importing from the
    # zip directly is wrong for this package: `dataset/` and `training/` are
    # namespace packages, which zipimport does not find.
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
    if probe.returncode != 0:
        failures.append(f"the wheel imports ({probe.stderr.strip()})")
    return failures


def check_only_the_commit_ships(root: pathlib.Path) -> list[str]:
    """An edit, a staged file and an untracked one all stay out of the release.

    Planted in a clone of this repository, because planting them here would
    change the working tree of whoever runs the self-test.
    """
    clone = root / "clone"
    subprocess.run(["git", "clone", "-q", str(REPO), str(clone)], check=True)
    addon = clone / "godot" / "addons" / shipped_addons(clone)[0]
    edited = sorted(path for path in addon.iterdir() if path.suffix == ".gd")[0]
    edited.write_text(edited.read_text() + "# UNCOMMITTED\n")
    (addon / "staged_only.gd").write_text("# STAGED\n")
    subprocess.run(["git", "-C", str(clone), "add", "--", str(addon / "staged_only.gd")],
                   check=True)
    (addon / "untracked.gd").write_text("# UNTRACKED\n")
    (clone / "VERSION").write_text("9.9.9\n")

    shipped = quiet_build(clone, root / "from-clone")
    with zipfile.ZipFile(shipped[0]) as bundle:
        names = bundle.namelist()
        content = b"".join(bundle.read(name) for name in names)
    failures = []
    for mark in (b"UNCOMMITTED", b"STAGED", b"UNTRACKED"):
        if mark in content:
            failures.append(f"a file marked {mark.decode()} stayed out of the release")
    if any("9.9.9" in path.name for path in shipped):
        failures.append("an uncommitted VERSION stayed out of the release")
    return failures


def check_refusals(root: pathlib.Path) -> list[str]:
    """Versions that are not major.minor.patch, and an output inside dist/, are refused."""
    failures = []
    for written in ("0.1", "0.1.0-rc1", "v0.1.0", "0.1.0.1"):
        try:
            checked_version(written + "\n")
            failures.append(f"VERSION {written!r} is refused")
        except Refused:
            pass
    if checked_version("0.1.0\n") != "0.1.0":
        failures.append("VERSION 0.1.0 is accepted")
    try:
        build(REPO, REPO / "dist" / "nested", skip_notice=False)
        failures.append("an output inside the repository's dist/ is refused")
    except Refused:
        pass
    return failures


def check_stale_artifacts(root: pathlib.Path) -> list[str]:
    """Artifacts of an earlier version are cleared; what `make train` staged is not."""
    release = root / "stale"
    quiet_build(REPO, release)
    stale = [release / "dist" / "ai_search-0.0.1.zip",
             release / "dist" / f"{PACKAGE}-0.0.1-py3-none-any.whl"]
    for path in stale:
        path.write_bytes(b"stale")
    (release / "dist" / "weights.json").write_text("{}")
    quiet_build(REPO, release)
    failures = [f"{path.name} is cleared" for path in stale if path.exists()]
    if not (release / "dist" / "weights.json").exists():
        failures.append("weights.json is left alone")
    return failures


def self_test() -> int:
    checks = (check_the_gate_agrees, check_reproducible_and_stamped, check_the_wheel,
              check_only_the_commit_ships, check_refusals, check_stale_artifacts)
    failures = []
    with tempfile.TemporaryDirectory() as workspace:
        for check in checks:
            area = pathlib.Path(workspace) / check.__name__
            area.mkdir()
            failures.extend(check(area))

    unknown = subprocess.run(
        [sys.executable, str(pathlib.Path(__file__).resolve()), "--unknown-flag"],
        capture_output=True,
    )
    if unknown.returncode != 2:
        failures.append("an unknown flag exits 2")

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def entries_are_fixed(archive: pathlib.Path) -> bool:
    """No entry carries the time or system it was built on, and each one is readable.

    The mode matters beyond reproducibility: left at zero, `unzip` on Linux
    honours it and writes files nobody can open.
    """
    with zipfile.ZipFile(archive) as bundle:
        return all(entry.date_time == EPOCH and entry.create_system == 3
                   and entry.external_attr == 0o644 << 16
                   for entry in bundle.infolist())


def stamped_version(archive: pathlib.Path) -> str | None:
    """The version an artifact says it is, read from inside it rather than its name."""
    with zipfile.ZipFile(archive) as bundle:
        for name in bundle.namelist():
            if archive.suffix == ".zip" and name.count("/") == 1 and name.endswith("/VERSION"):
                return bundle.read(name).decode().strip()
            if archive.suffix == ".whl" and name.endswith(".dist-info/METADATA"):
                return header_fields(bundle.read(name)).get("Version")
    return None


def header_fields(text: bytes) -> dict[str, list[str] | str]:
    """`Key: value` lines as a dict; a key written twice keeps every value as a list."""
    fields: dict[str, list[str] | str] = {}
    for line in text.decode().splitlines():
        key, _, value = line.partition(": ")
        if key in fields:
            earlier = fields[key]
            fields[key] = (earlier if isinstance(earlier, list) else [earlier]) + [value]
        else:
            fields[key] = value
    return fields


def wheel_problems(wheel: pathlib.Path) -> list[str]:
    """What the wheel spec asks of a pure wheel, checked without the code that wrote it.

    A review found the first self-test called a wheel valid when it was a zip
    that imported: a missing WHEEL file, a missing `Name:`, a misnamed
    `.dist-info` and a wrong filename tag all passed it, and pip refused every
    one. RECORD was checked by recomputing each row with the function that
    wrote it, which agrees with itself whatever the encoding. Every check here
    reads the archive cold.
    """
    distribution, version, *tags = wheel.stem.split("-")
    info = f"{distribution}-{version}.dist-info"
    problems = [] if tags == ["py3", "none", "any"] else [f"filename tag {tags}"]
    with zipfile.ZipFile(wheel) as bundle:
        names = set(bundle.namelist())
        for required in ("WHEEL", "METADATA", "RECORD"):
            if f"{info}/{required}" not in names:
                return problems + [f"no {info}/{required}"]
        problems += wheel_file_problems(header_fields(bundle.read(f"{info}/WHEEL")))
        licences = sorted(name.rsplit("/", 1)[1] for name in names
                          if name.startswith(f"{info}/licenses/"))
        problems += metadata_problems(header_fields(bundle.read(f"{info}/METADATA")),
                                      distribution, version, licences)
        problems += record_problems(bundle, f"{info}/RECORD")
    return problems


def wheel_file_problems(fields: dict) -> list[str]:
    """The WHEEL file of a pure wheel tagged py3-none-any."""
    expected = {"Wheel-Version": "1.0", "Root-Is-Purelib": "true", "Tag": "py3-none-any"}
    return [f"WHEEL {key} is {fields.get(key)!r}"
            for key, value in expected.items() if fields.get(key) != value]


def metadata_problems(fields: dict, distribution: str, version: str,
                      licences: list[str]) -> list[str]:
    """METADATA names this wheel, and declares each file in `licenses/` (PEP 639)."""
    problems = [f"METADATA {key} is {fields.get(key)!r}"
                for key, value in (("Metadata-Version", "2.4"), ("Name", distribution),
                                   ("Version", version), ("License-Expression", "Apache-2.0"))
                if fields.get(key) != value]
    declared = fields.get("License-File", [])
    declared = sorted(declared if isinstance(declared, list) else [declared])
    if declared != licences:
        problems.append(f"License-File declares {declared}, licenses/ holds {licences}")
    if "Requires-Python" not in fields:
        problems.append("METADATA has no Requires-Python")
    return problems


def record_problems(bundle: zipfile.ZipFile, record_name: str) -> list[str]:
    """Every other entry is in RECORD, hashed sha256 in unpadded urlsafe base64."""
    problems = []
    rows = bundle.read(record_name).decode().splitlines()
    listed = {row.split(",")[0]: row.split(",")[1:] for row in rows}
    if listed.pop(record_name, None) != ["", ""]:
        problems.append("RECORD lists itself without a hash")
    for name in sorted(set(bundle.namelist()) - {record_name}):
        hashed, size = listed.get(name, ["", ""])
        algorithm, _, encoded = hashed.partition("=")
        data = bundle.read(name)
        if algorithm != "sha256" or "=" in encoded or not re.fullmatch(r"[A-Za-z0-9_-]+", encoded):
            problems.append(f"RECORD hash for {name} is not unpadded urlsafe sha256")
        elif base64.urlsafe_b64decode(encoded + "=" * (-len(encoded) % 4)) != hashlib.sha256(data).digest():
            problems.append(f"RECORD hash for {name} is wrong")
        if size != str(len(data)):
            problems.append(f"RECORD size for {name} is wrong")
    return problems


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--build", action="store_true")
    parser.add_argument("--output", default=None,
                        help="release root, relative to the current directory; "
                             "archives go to OUTPUT/dist, and earlier ai_*-*.zip and "
                             "gameaikit-*.whl there are removed (default: the repo)")
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
