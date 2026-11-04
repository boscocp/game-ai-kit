#!/usr/bin/env python3
"""Build what ships: one zip per addon and one Python wheel, each attributed.

What it builds
--------------
Into `OUTPUT/dist/`, from the commit at HEAD and nothing else:

  * `ai_<name>-<version>.zip` for every addon under godot/addons/, with a
    single top folder `ai_<name>/` holding LICENSE, NOTICE, VERSION and a
    README beside the code -- unzip it into `res://addons/`. Each addon is
    read from its manifest, `modules/ai_<name>.json` (T64): an addon folder
    no technique or kernel manifest owns, or one holding a test, is refused;
  * `gameaikit-<version>-py3-none-any.whl`, the Python half, with LICENSE and
    NOTICE in `.dist-info/licenses/`, where PEP 639 says a wheel keeps them.
    It holds the packages `python/pyproject.toml` lists -- the techniques
    and the kernel's, not the examples' -- and its metadata is that file's,
    refused when the file's version is not VERSION's or its packages are not
    the techniques' and the kernel's.
  * with `--executable FOLDER`, `game-ai-kit-linux-x86_64-<version>.zip`:
    the menu exported by `make export` (T24), the binary and its `.pck` under
    one top folder `game-ai-kit/` beside LICENSE, NOTICE and VERSION. Only a
    build whose `BUILD` stamp names HEAD, exported from a `godot/` with
    nothing uncommitted, and whose binary and pack still match the hashes
    the stamp records, ships -- the one artifact not built from git's own
    bytes is held to the same commit by its stamp.

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
1   refused: VERSION malformed, an addon or the package has no files, an
    addon has no manifest or holds a test, pyproject.toml disagrees with
    VERSION or the manifests, or the output would land inside the
    repository's own dist/
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
import json
import pathlib
import re
import subprocess
import sys
import tarfile
import tempfile
import tomllib
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

# The manifests whose addon ships: a technique, or the kernel every one
# stands on (ADR 0021). The examples' modules are the kit's games.
SHIPPED_KINDS = ("technique", "kernel")

# A gdUnit4 suite: a `*_test.gd`, or any script extending GdUnitTestSuite.
# Suites live in godot/test/<module>/; one inside an addon folder would ship
# to a stranger who has no gdUnit4, so it is refused rather than quietly
# dropped. A plain helper a suite uses is not recognised by its content --
# that one is held by review, and by the manifest owning the test folder.
TEST_FILE = re.compile(r"(^|/)[^/]*_test\.gd$")
TEST_MARK = b"GdUnitTestSuite"


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
    return committed_contents(repo, [path])[path]


def committed_contents(repo: pathlib.Path, paths: list[str]) -> dict[str, bytes]:
    """Many files' contents as HEAD has them, read by one git process.

    One `git show` a file cost the self-test over two minutes on Windows,
    where starting a process takes about 30 ms: it builds the addons fourteen
    times, nearly four thousand files. `git cat-file --batch` answers every
    path on its stdin with a header -- `<sha> blob <size>` -- and the bytes.
    """
    if not paths:
        return {}
    request = "".join(f"HEAD:{path}\n" for path in paths).encode()
    answer = subprocess.run(["git", "-C", str(repo), "cat-file", "--batch"],
                            input=request, capture_output=True, check=True).stdout
    contents = {}
    position = 0
    for path in paths:
        header_end = answer.index(b"\n", position)
        header = answer[position:header_end].split()
        if len(header) != 3 or header[1] != b"blob":
            raise subprocess.CalledProcessError(128, f"git cat-file HEAD:{path}")
        size = int(header[2])
        contents[path] = answer[header_end + 1:header_end + 1 + size]
        position = header_end + 1 + size + 1
    return contents


def checked_version(text: str) -> str:
    """The version, or a refusal when it is not major.minor.patch."""
    version = text.strip()
    if not VERSION_RE.match(version):
        raise Refused(f"VERSION reads {version!r}, which is not major.minor.patch")
    return version


def read_version(repo: pathlib.Path) -> str:
    """The version every artifact is stamped with, from the one file that holds it."""
    return checked_version(committed_bytes(repo, "VERSION").decode("utf-8"))


def add_entry(bundle: zipfile.ZipFile, name: str, data: bytes, mode: int = 0o644) -> None:
    """Write one file with a fixed date and mode, so the build is reproducible."""
    entry = zipfile.ZipInfo(name, date_time=EPOCH)
    entry.compress_type = zipfile.ZIP_DEFLATED
    entry.external_attr = mode << 16
    # Unix, whatever machine builds it. Left to the default, a build on
    # Windows writes 0 here and the two releases of one commit differ.
    entry.create_system = 3
    bundle.writestr(entry, data)


def attribution(repo: pathlib.Path, skip_notice: bool) -> dict[str, bytes]:
    """The files every artifact must carry, minus NOTICE when planting a fault."""
    names = [name for name in ATTRIBUTION if not (skip_notice and name == "NOTICE")]
    return committed_contents(repo, names)


def manifests(repo: pathlib.Path) -> dict[str, dict]:
    """Every module's manifest as HEAD has it, by module name."""
    paths = [path for path in committed_files(repo, "modules/") if path.endswith(".json")]
    found = {}
    for path, data in committed_contents(repo, paths).items():
        manifest = json.loads(data)
        found[manifest["module"]] = manifest
    return found


def addon_manifest(addon: str, every: dict[str, dict]) -> dict:
    """The manifest that ships `addon`, or a refusal naming what is missing."""
    manifest = every.get(addon)
    if manifest is None or f"godot/addons/{addon}/" not in manifest["owns"]:
        raise Refused(f"godot/addons/{addon}/ is owned by no manifest, so nothing says it ships")
    if manifest["kind"] not in SHIPPED_KINDS:
        raise Refused(f"{addon} is a module of kind {manifest['kind']!r}; "
                      f"only {', '.join(SHIPPED_KINDS)} addons ship")
    return manifest


def addon_readme(manifest: dict, version: str, files: dict[str, bytes]) -> bytes:
    """The README a stranger opens first: what the addon is, and what it needs.

    Written from the manifest's `summary` -- its `about` is for this
    repository's readers and names tasks a stranger cannot follow -- so it
    cannot describe an addon other than the one in the zip. The Asset
    Library asks for a readme inside the plugin folder; this is that file.
    The note on the `Gak` prefix is printed only where the addon has a class
    that carries it.
    """
    name = manifest["module"]
    needs = manifest["depends_on"]
    if not manifest.get("summary"):
        raise Refused(f"modules/{name}.json has no summary for the README a stranger reads")
    prefixed = any(re.search(rb"^class_name Gak", data, re.M) for data in files.values())
    lines = [f"# {name} {version}", "", manifest["summary"], "",
             f"Unzip into your project's `res://addons/`. The classes register "
             f"themselves by `class_name`; no plugin needs enabling."]
    if needs:
        lines += ["", "It needs " + ", ".join(f"`{each}`" for each in needs)
                  + ", from the same release: unzip that beside it."]
    if prefixed:
        lines += ["", "The classes a game extends carry the prefix `Gak`; the algorithms "
                  "keep their names."]
    lines += ["", "If a class here collides with one of yours, rename its `class_name` "
              "line, and its uses, inside this folder.",
              "", "Apache-2.0: LICENSE and NOTICE are beside this file. "
              "Source, tests and documentation: https://github.com/boscocp/game-ai-kit", ""]
    return "\n".join(lines).encode()


def build_addon(repo: pathlib.Path, addon: str, version: str,
                dist: pathlib.Path, skip_notice: bool, manifest: dict) -> pathlib.Path:
    """Zip one addon under a single top folder named after it.

    The addon's own LICENSE and NOTICE are dropped and the root copies put in
    their place, so a stale copy inside an addon cannot ship instead of the
    real one. `check_license.py` already insists every addon carries its own;
    this decides which bytes those are.
    """
    prefix = f"godot/addons/{addon}/"
    shipped = [path for path in committed_files(repo, prefix)
               if path[len(prefix):] not in ATTRIBUTION]
    files = {path[len(prefix):]: data for path, data in committed_contents(repo, shipped).items()}
    if not files:
        raise Refused(f"{addon} has no committed files to ship")
    tests = sorted(name for name, data in files.items()
                   if TEST_FILE.search(name) or (name.endswith(".gd") and TEST_MARK in data))
    if tests:
        raise Refused(f"{addon} holds a test, {tests[0]}; tests live in godot/test/{addon}/")
    files.update(attribution(repo, skip_notice))
    files["VERSION"] = f"{version}\n".encode()
    files["README.md"] = addon_readme(manifest, version, files)

    archive = dist / f"{addon}-{version}.zip"
    with zipfile.ZipFile(archive, "w") as bundle:
        for name in sorted(files):
            add_entry(bundle, f"{addon}/{name}", files[name])
    return archive


def record_line(name: str, data: bytes) -> str:
    """One row of a wheel's RECORD: path, urlsafe sha256 without padding, size."""
    digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b"=")
    return f"{name},sha256={digest.decode()},{len(data)}"


def project_table(repo: pathlib.Path, version: str, every: dict[str, dict]) -> dict:
    """`python/pyproject.toml` as HEAD has it, refused when it disagrees.

    The wheel is written by hand (ADR 0009), and a person who runs `pip
    install ./python` gets one from setuptools; both must be the same
    package. So the file's name, version and floor must be this script's, and
    its packages exactly the shipped ones -- one per technique or kernel
    manifest's `python/gameaikit/<name>/` (the kernel's is the generator
    the techniques draw from, T109), and the root.
    """
    pyproject = tomllib.loads(committed_bytes(repo, "python/pyproject.toml").decode("utf-8"))
    project = pyproject["project"]
    for key, wanted in (("name", PACKAGE), ("version", version),
                        ("requires-python", REQUIRES_PYTHON)):
        if project.get(key) != wanted:
            raise Refused(f"python/pyproject.toml says {key} = {project.get(key)!r}, "
                          f"the release builds {wanted!r}")
    shipped = {f"{PACKAGE}.{owned.split('/')[2]}"
               for manifest in every.values() if manifest["kind"] in SHIPPED_KINDS
               for owned in manifest["owns"]
               if owned.startswith(f"python/{PACKAGE}/") and owned.endswith("/")}
    in_order = pyproject["tool"]["setuptools"]["packages"]
    # Sorted, one a line: two waves adding a package each then conflict
    # only when their names are neighbours (T111). Appended at the end,
    # every two would.
    if in_order != sorted(in_order):
        raise Refused(f"python/pyproject.toml lists its packages out of order; sorted they are {sorted(in_order)}")
    listed = set(in_order)
    if listed != shipped | {PACKAGE}:
        raise Refused(f"python/pyproject.toml packages differ from the technique and kernel manifests "
                      f"by {sorted(listed ^ (shipped | {PACKAGE}))}")
    # setuptools ships a listed package's own folder and no folder below it,
    # and so does this script; a technique growing a subpackage would leave
    # both wheels without it, and agree. Refused, until it is listed.
    folders = {pathlib.PurePosixPath(path).parent.as_posix()[len("python/"):].replace("/", ".")
               for package in shipped
               for path in committed_files(repo, f"python/{package.replace('.', '/')}/")}
    if folders - listed:
        raise Refused(f"python/pyproject.toml does not list {sorted(folders - listed)}, "
                      "a folder inside a technique's package")
    return project


def wheel_metadata(project: dict, licences: list[str], readme: str) -> dict[str, str]:
    """The `.dist-info` text files, apart from RECORD, which hashes all the rest."""
    metadata = [
        "Metadata-Version: 2.4",
        f"Name: {project['name']}",
        f"Version: {project['version']}",
        f"Summary: {project['description']}",
        "License-Expression: Apache-2.0",
        *(f"License-File: {name}" for name in licences),
        f"Requires-Python: {project['requires-python']}",
        *(f"Project-URL: {label}, {url}" for label, url in project.get("urls", {}).items()),
        "Description-Content-Type: text/markdown",
    ]
    wheel = [
        "Wheel-Version: 1.0",
        "Generator: game-ai-kit scripts/release.py",
        "Root-Is-Purelib: true",
        "Tag: py3-none-any",
    ]
    return {"METADATA": "\n".join(metadata) + "\n\n" + readme, "WHEEL": "\n".join(wheel) + "\n"}


def build_wheel(repo: pathlib.Path, version: str, dist: pathlib.Path,
                skip_notice: bool, every: dict[str, dict]) -> pathlib.Path:
    """Write the Python package as a pure wheel, by hand.

    Only the packages `pyproject.toml` lists, and the files directly in the
    root package -- not the examples' packages beside them. Everything goes
    in the archive except RECORD first; RECORD then lists every one of them
    with its hash, and itself without one, which is how the format says a
    reader knows the file it is reading is the last word.
    """
    project = project_table(repo, version, every)
    # A listed package is its folder's own files, as setuptools reads it: a
    # folder below one is shipped only when it is listed itself.
    folders = {name.replace(".", "/") for name in project_packages(repo)}
    package = [path for path in committed_files(repo, f"python/{PACKAGE}/")
               if pathlib.PurePosixPath(path[len("python/"):]).parent.as_posix() in folders]
    files = {path[len("python/"):]: data for path, data in committed_contents(repo, package).items()}
    if not files:
        raise Refused(f"python/{PACKAGE} has no committed files to ship")

    info = f"{PACKAGE}-{version}.dist-info"
    licences = attribution(repo, skip_notice)
    for name, data in licences.items():
        files[f"{info}/licenses/{name}"] = data
    readme = committed_bytes(repo, "python/README.md").decode("utf-8")
    for name, text in wheel_metadata(project, sorted(licences), readme).items():
        files[f"{info}/{name}"] = text.encode()

    record = [record_line(name, files[name]) for name in sorted(files)]
    record.append(f"{info}/RECORD,,")
    files[f"{info}/RECORD"] = ("\n".join(record) + "\n").encode()

    archive = dist / f"{PACKAGE}-{version}-py3-none-any.whl"
    with zipfile.ZipFile(archive, "w") as bundle:
        for name in sorted(files):
            add_entry(bundle, name, files[name])
    return archive


def head_commit(repo: pathlib.Path) -> str:
    """The commit at HEAD, in full."""
    return subprocess.run(["git", "-C", str(repo), "rev-parse", "HEAD"],
                          capture_output=True, check=True, text=True).stdout.strip()


def exported_from_head(repo: pathlib.Path, folder: pathlib.Path) -> None:
    """Refuse an exported build that is not HEAD's, exactly."""
    stamp_file = folder / "BUILD"
    if not stamp_file.is_file():
        raise Refused(f"{folder} has no BUILD stamp: run `make export`")
    stamp = json.loads(stamp_file.read_text(encoding="utf-8"))
    if stamp.get("commit") != head_commit(repo):
        raise Refused(f"{folder} was exported from {str(stamp.get('commit'))[:12]}, not HEAD: run `make export`")
    if stamp.get("clean") is not True:
        raise Refused(f"{folder} was exported with uncommitted changes under godot/")
    # The stamp vouches for bytes, not only for a commit: a pack rewritten
    # after `make export` would otherwise ship under it (wave 59's review).
    for shipped in sorted(folder.glob("*.x86_64")) + sorted(folder.glob("*.pck")):
        if stamp.get(shipped.name) != hashlib.sha256(shipped.read_bytes()).hexdigest():
            raise Refused(f"{shipped.name} is not the file `make export` stamped: run `make export`")


def build_executable(repo: pathlib.Path, folder: pathlib.Path, version: str,
                     dist: pathlib.Path, skip_notice: bool) -> pathlib.Path:
    """Zip the exported menu under one top folder, beside its attribution."""
    exported_from_head(repo, folder)
    binaries = sorted(folder.glob("*.x86_64"))
    if len(binaries) != 1 or not binaries[0].with_suffix(".pck").is_file():
        raise Refused(f"{folder} should hold one .x86_64 and its .pck")
    files = {name: (data, 0o644) for name, data in attribution(repo, skip_notice).items()}
    files["VERSION"] = (f"{version}\n".encode(), 0o644)
    files[binaries[0].name] = (binaries[0].read_bytes(), 0o755)
    files[binaries[0].with_suffix(".pck").name] = (binaries[0].with_suffix(".pck").read_bytes(), 0o644)
    archive = dist / f"game-ai-kit-linux-x86_64-{version}.zip"
    with zipfile.ZipFile(archive, "w") as bundle:
        for name in sorted(files):
            add_entry(bundle, f"game-ai-kit/{name}", files[name][0], files[name][1])
    return archive


def project_packages(repo: pathlib.Path) -> list[str]:
    """The packages `python/pyproject.toml` lists, dotted, as HEAD has it."""
    pyproject = tomllib.loads(committed_bytes(repo, "python/pyproject.toml").decode("utf-8"))
    return sorted(pyproject["tool"]["setuptools"]["packages"])


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
    for pattern in ("ai_*-*.zip", f"{PACKAGE}-*.whl", "game-ai-kit-*.zip"):
        for stale in dist.glob(pattern):
            stale.unlink()


def build(repo: pathlib.Path, output: pathlib.Path, skip_notice: bool,
          executable: pathlib.Path | None = None) -> list[pathlib.Path]:
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

    every = manifests(repo)
    artifacts = [
        build_addon(repo, addon, version, dist, skip_notice, addon_manifest(addon, every))
        for addon in shipped_addons(repo)
    ]
    artifacts.append(build_wheel(repo, version, dist, skip_notice, every))
    if executable is not None:
        artifacts.append(build_executable(repo, executable, version, dist, skip_notice))
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


def quiet_build(repo: pathlib.Path, output: pathlib.Path, skip_notice: bool = False,
                executable: pathlib.Path | None = None) -> list[pathlib.Path]:
    """A build whose list of artifacts is not printed."""
    with contextlib.redirect_stdout(io.StringIO()):
        return build(repo, output, skip_notice, executable)


def check_the_gate_agrees(root: pathlib.Path) -> list[str]:
    """A complete release passes the gate; one without NOTICE fails it, per artifact."""
    failures = []
    artifacts = quiet_build(REPO, root / "good")
    code, findings = license_gate(root / "good")
    if code != 0:
        failures.append(f"a complete release passes the gate (got {code}: {findings})")

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
    """The wheel is well formed by the spec, its techniques import, its games are left out."""
    wheel = quiet_build(REPO, root / "wheel")[-1]
    failures = [f"the wheel is well formed: {problem}" for problem in wheel_problems(wheel)]
    # Unpacked the way an installer unpacks a pure wheel. Importing from the
    # zip directly is wrong for this package: `training/` is a namespace
    # package, which zipimport does not find. Every technique the registry
    # names must import from it -- and the examples' packages must not.
    site = root / "site-packages"
    with zipfile.ZipFile(wheel) as bundle:
        bundle.extractall(site)
    def registered(path: pathlib.Path) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, "-I", "-c",
             f"import sys; sys.path.insert(0, {str(path)!r}); "
             "from gameaikit import techniques; print(sorted(techniques.kit()))"],
            capture_output=True, text=True, cwd=root,
        )
    from_wheel, from_tree = registered(site), registered(REPO / "python")
    if from_wheel.returncode != 0 or from_wheel.stdout != from_tree.stdout:
        failures.append(f"every technique imports from the wheel ({from_wheel.stderr.strip()})")
    examples = {owned.split("/")[2] for manifest in manifests(REPO).values()
                if manifest["kind"] == "example" for owned in manifest["owns"]
                if owned.startswith(f"python/{PACKAGE}/") and owned.endswith("/")}
    if not examples:
        failures.append("the manifests name the examples' Python packages")
    for game in sorted(examples):
        if (site / PACKAGE / game).exists():
            failures.append(f"the examples' {game} package stays out of the wheel")
    return failures


def check_manifest_refusals(root: pathlib.Path) -> list[str]:
    """What the manifests and pyproject.toml forbid is refused, each on its own commit.

    Planted in a clone, one commit each, and reset between: a test inside an
    addon folder, an addon folder no manifest owns, a subpackage pyproject
    does not list, a pyproject whose version is not VERSION's, one that
    lists an example's package, and one whose list is out of order.
    """
    clone = root / "clone"
    subprocess.run(["git", "clone", "-q", str(REPO), str(clone)], check=True)
    head = head_commit(clone)
    pyproject = clone / "python" / "pyproject.toml"

    def an_orphan_addon() -> None:
        (clone / "godot/addons/ai_orphan").mkdir()
        (clone / "godot/addons/ai_orphan/orphan.gd").write_text("extends RefCounted\n")

    def a_subpackage() -> None:
        (clone / "python/gameaikit/search/grids").mkdir()
        (clone / "python/gameaikit/search/grids/__init__.py").write_text("")

    def a_manifest_without_summary() -> None:
        manifest = clone / "modules" / "ai_search.json"
        data = json.loads(manifest.read_text())
        del data["summary"]
        manifest.write_text(json.dumps(data, indent=2) + "\n")

    plants = {
        "a test inside an addon": lambda: (clone / "godot/addons/ai_search/stray_test.gd")
        .write_text("extends GdUnitTestSuite\n"),
        "a script running a test suite": lambda: (clone / "godot/addons/ai_search/helper.gd")
        .write_text("extends GdUnitTestSuite\n"),
        "an addon no manifest owns": an_orphan_addon,
        "a technique's subpackage pyproject does not list": a_subpackage,
        "an addon whose manifest has no summary": a_manifest_without_summary,
        "a pyproject at another version": lambda: pyproject.write_text(
            pyproject.read_text().replace('version = "', 'version = "9', 1)),
        "a pyproject shipping an example": lambda: pyproject.write_text(
            pyproject.read_text().replace('"gameaikit.utility",', '"gameaikit.utility",\n    "gameaikit.checkers",', 1)),
        "a pyproject listing out of order": lambda: pyproject.write_text(
            pyproject.read_text().replace('    "gameaikit.adversarial",\n', '', 1).replace(
                '"gameaikit.utility",', '"gameaikit.utility",\n    "gameaikit.adversarial",', 1)),
    }
    failures = []
    for label, plant in plants.items():
        subprocess.run(["git", "-C", str(clone), "reset", "-q", "--hard", head], check=True)
        subprocess.run(["git", "-C", str(clone), "clean", "-qfdx"], check=True)
        plant()
        subprocess.run(["git", "-C", str(clone), "add", "-A"], check=True)
        subprocess.run(["git", "-C", str(clone), "-c", "user.name=t", "-c", "user.email=t@t",
                        "commit", "-q", "--no-verify", "-m", "plant"], check=True)
        try:
            quiet_build(clone, root / "out")
            failures.append(f"{label} is refused")
        except Refused:
            pass
    return failures


def check_only_the_commit_ships(root: pathlib.Path) -> list[str]:
    """No edit, staged file or untracked file reaches any artifact, or the root copies.

    Planted in a clone of this repository, because planting them here would
    change the working tree of whoever runs the self-test. Planted in *every*
    source the build reads -- an addon, the Python package, the root LICENSE,
    NOTICE and VERSION -- and every artifact is opened: the first version of
    this check planted in one addon and opened one zip, so reading the
    package or the attribution off disk passed it.
    """
    clone = root / "clone"
    subprocess.run(["git", "clone", "-q", str(REPO), str(clone)], check=True)
    package = clone / "python" / PACKAGE
    sources = [sorted((clone / "godot" / "addons").rglob("*.gd")),
               sorted(package.rglob("*.py"))]
    if not all(sources):
        return ["the clone has an addon script and a package module to plant beside"]
    for source in (found[0] for found in sources):
        folder = source.parent
        source.write_text(source.read_text() + "# UNCOMMITTED\n")
        (folder / f"staged_only{source.suffix}").write_text("# STAGED\n")
        subprocess.run(["git", "-C", str(clone), "add", "--",
                        str(folder / f"staged_only{source.suffix}")], check=True)
        (folder / f"untracked{source.suffix}").write_text("# UNTRACKED\n")
    for name in ATTRIBUTION:
        (clone / name).write_text((clone / name).read_text() + "UNCOMMITTED\n")
    (clone / "VERSION").write_text("9.9.9\n")

    output = root / "from-clone"
    shipped = quiet_build(clone, output)
    content = b"".join(archive_bytes(path) for path in shipped)
    content += b"".join((output / name).read_bytes() for name in ATTRIBUTION)
    failures = [f"a change marked {mark.decode()} stayed out of the release"
                for mark in (b"UNCOMMITTED", b"STAGED", b"UNTRACKED") if mark in content]
    if any("9.9.9" in path.name for path in shipped):
        failures.append("an uncommitted VERSION stayed out of the release")
    return failures


def archive_bytes(archive: pathlib.Path) -> bytes:
    """Every entry's name and content, run together, to search for a marker."""
    with zipfile.ZipFile(archive) as bundle:
        return b"".join(name.encode() + bundle.read(name) for name in bundle.namelist())


def check_contents(root: pathlib.Path) -> list[str]:
    """The release is exactly what HEAD holds: every addon, every file, nothing else.

    A review dropped every `.gd` from the addon zips, and then one module from
    the wheel, and nothing noticed: the gate looks for attribution and the
    import probe loads three modules. The first check written for it then
    built its expectation with the build's own helpers, so the same defect one
    function down -- `committed_files` skipping `.gd`, or one addon instead of
    four -- agreed with itself. The expectation comes from `git archive` now,
    a reader of HEAD that shares nothing with the build.
    """
    tree = head_archive(REPO)
    version = tree["VERSION"].decode().strip()
    expected = expected_release(tree, version)
    artifacts = quiet_build(REPO, root / "contents")
    built = {path.name: path for path in artifacts}
    if set(built) != set(expected):
        return [f"the release is {sorted(built)}, HEAD calls for {sorted(expected)}"]
    failures = []
    for name, wanted in expected.items():
        with zipfile.ZipFile(built[name]) as bundle:
            listed = bundle.namelist()
            held = {entry: bundle.read(entry) for entry in listed}
        if len(listed) != len(held):
            failures.append(f"{name} writes an entry twice")
        if set(held) != set(wanted):
            failures.append(f"{name} differs from HEAD by {sorted(set(held) ^ set(wanted))[:4]}")
            continue
        changed = [entry for entry, data in wanted.items()
                   if data is not None and held[entry] != data]
        if changed:
            failures.append(f"{name} changes {changed[:4]}")
    return failures


def head_archive(repo: pathlib.Path) -> dict[str, bytes]:
    """Every file HEAD holds that a release reads, by path, through `git archive`."""
    exported = subprocess.run(
        ["git", "-C", str(repo), "archive", "--format=tar", "HEAD", "--",
         "godot/addons", f"python/{PACKAGE}", "python/pyproject.toml", *ATTRIBUTION, "VERSION"],
        capture_output=True, check=True,
    ).stdout
    with tarfile.open(fileobj=io.BytesIO(exported)) as bundle:
        return {member.name: bundle.extractfile(member).read()
                for member in bundle.getmembers() if member.isfile()}


def expected_release(tree: dict[str, bytes], version: str) -> dict[str, dict[str, bytes | None]]:
    """Artifact name to its entries and their bytes; None where the build writes the file."""
    attribution_files = {name: tree[name] for name in ATTRIBUTION}
    addons = sorted({path.split("/")[2] for path in tree if path.startswith("godot/addons/")})
    release: dict[str, dict[str, bytes | None]] = {}
    for addon in addons:
        prefix = f"godot/addons/{addon}/"
        entries = {f"{addon}/{path[len(prefix):]}": data
                   for path, data in tree.items() if path.startswith(prefix)}
        entries.update({f"{addon}/{name}": data for name, data in attribution_files.items()})
        entries[f"{addon}/VERSION"] = f"{version}\n".encode()
        entries[f"{addon}/README.md"] = None
        release[f"{addon}-{version}.zip"] = entries
    info = f"{PACKAGE}-{version}.dist-info"
    listed = tomllib.loads(tree["python/pyproject.toml"].decode())["tool"]["setuptools"]["packages"]
    folders = {f"python/{name.replace('.', '/')}" for name in listed}
    wheel = {path[len("python/"):]: data
             for path, data in tree.items() if path.rsplit("/", 1)[0] in folders}
    wheel.update({f"{info}/licenses/{name}": data for name, data in attribution_files.items()})
    wheel.update({f"{info}/{name}": None for name in ("METADATA", "WHEEL", "RECORD")})
    release[f"{PACKAGE}-{version}-py3-none-any.whl"] = wheel
    return release


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
    # Two shapes the build does not write today and the spec allows: a folded
    # line and a field that may repeat. The reader must not call them broken.
    _, problems = header_fields(b"Keywords: one\n  folded\nProject-URL: a, b\nProject-URL: c, d\n")
    if problems:
        failures.append(f"a folded line and a repeated Project-URL are read cleanly ({problems})")
    _, problems = header_fields(b"Name: one\nName: two\n")
    if not problems:
        failures.append("a single-use field written twice is refused")
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
              check_only_the_commit_ships, check_contents, check_refusals,
              check_manifest_refusals,
              check_stale_artifacts, check_the_executable)
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


def check_the_executable(root: pathlib.Path) -> list[str]:
    """The exported menu ships from HEAD's stamp only, runnable and attributed."""
    failures = []
    folder = root / "exported"
    folder.mkdir()
    (folder / "game-ai-kit.x86_64").write_bytes(b"an engine")
    (folder / "game-ai-kit.pck").write_bytes(b"GDPC")
    hashes = {name: hashlib.sha256(data).hexdigest()
              for name, data in (("game-ai-kit.x86_64", b"an engine"), ("game-ai-kit.pck", b"GDPC"))}
    stamps = {"no stamp": None, "another commit": {"commit": "0" * 40, "clean": True, **hashes},
              "uncommitted changes": {"commit": head_commit(REPO), "clean": False, **hashes},
              "a pack changed after it": {"commit": head_commit(REPO), "clean": True, **hashes,
                                          "game-ai-kit.pck": "0" * 64}}
    for label, stamp in stamps.items():
        (folder / "BUILD").unlink(missing_ok=True)
        if stamp is not None:
            (folder / "BUILD").write_text(json.dumps(stamp), encoding="utf-8")
        try:
            quiet_build(REPO, root / label.replace(" ", "-"), executable=folder)
            failures.append(f"an export with {label} was shipped")
        except Refused:
            pass
    (folder / "BUILD").write_text(json.dumps({"commit": head_commit(REPO), "clean": True, **hashes}),
                                  encoding="utf-8")
    built = quiet_build(REPO, root / "sound", executable=folder)[-1]
    with zipfile.ZipFile(built) as bundle:
        modes = {info.filename: info.external_attr >> 16 for info in bundle.infolist()}
    if modes.get("game-ai-kit/game-ai-kit.x86_64") != 0o755:
        failures.append(f"the executable does not ship executable: {modes}")
    code, lines = license_gate(root / "sound")
    if code != 0:
        failures.append(f"the licence gate refused the executable's zip: {lines}")
    return failures


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
                return header_fields(bundle.read(name))[0].get("Version")
    return None


# Fields a METADATA or WHEEL file may carry more than once: the multiple-use
# fields of core metadata 2.4, and WHEEL's `Tag`. Any other field written
# twice is a malformed file, and reading it as a list hid that.
REPEATABLE_FIELDS = {
    "Platform", "Supported-Platform", "Classifier", "Requires-Dist",
    "Requires-External", "Project-URL", "Provides-Extra", "Provides-Dist",
    "Obsoletes-Dist", "Dynamic", "License-File", "Tag",
}


def header_fields(text: bytes) -> tuple[dict[str, list[str] | str], list[str]]:
    """`Key: value` lines up to the first blank one, and what is wrong with them.

    The format is email headers: a blank line ends them and anything after is
    the description. The first version read every line, so a stray blank line
    after `Metadata-Version` left a file pip refuses -- every later field is
    description to pip -- and this read it as complete.
    """
    fields: dict[str, list[str] | str] = {}
    problems = []
    key = ""
    for line in text.decode().splitlines():
        if not line:
            break
        if line[0] in " \t" and fields:
            # A folded line continues the field before it, as email headers
            # do -- except `Summary`, which core metadata defines as one line.
            if key == "Summary":
                problems.append("Summary runs over more than one line")
            continue
        key, separator, value = line.partition(": ")
        if not separator:
            problems.append(f"header line {line!r} is not 'Key: value'")
        elif key in fields and key not in REPEATABLE_FIELDS:
            problems.append(f"{key} is written twice")
        elif key in REPEATABLE_FIELDS:
            fields.setdefault(key, [])
            fields[key].append(value)
        else:
            fields[key] = value
    return fields, problems


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
        wheel_fields, malformed = header_fields(bundle.read(f"{info}/WHEEL"))
        problems += malformed + wheel_file_problems(wheel_fields)
        licences = sorted(name.rsplit("/", 1)[1] for name in names
                          if name.startswith(f"{info}/licenses/"))
        metadata_fields, malformed = header_fields(bundle.read(f"{info}/METADATA"))
        problems += malformed + metadata_problems(metadata_fields, distribution,
                                                  version, licences)
        problems += record_problems(bundle, f"{info}/RECORD")
    return problems


def wheel_file_problems(fields: dict) -> list[str]:
    """The WHEEL file of a pure wheel tagged py3-none-any."""
    expected = {"Wheel-Version": "1.0", "Root-Is-Purelib": "true", "Tag": ["py3-none-any"]}
    return [f"WHEEL {key} is {fields.get(key)!r}"
            for key, value in expected.items() if fields.get(key) != value]


def metadata_problems(fields: dict, distribution: str, version: str,
                      licences: list[str]) -> list[str]:
    """METADATA names this wheel, and declares each file in `licenses/` (PEP 639)."""
    problems = [f"METADATA {key} is {fields.get(key)!r}"
                for key, value in (("Metadata-Version", "2.4"), ("Name", distribution),
                                   ("Version", version), ("License-Expression", "Apache-2.0"))
                if fields.get(key) != value]
    declared = sorted(fields.get("License-File", []))
    if declared != licences:
        problems.append(f"License-File declares {declared}, licenses/ holds {licences}")
    # Exactly the floor this script means, and one the interpreter running the
    # tests clears -- presence alone passed `>=3.99`, which no installer takes.
    floor = fields.get("Requires-Python")
    if floor != REQUIRES_PYTHON:
        problems.append(f"Requires-Python is {floor!r}, not {REQUIRES_PYTHON!r}")
    elif sys.version_info[:2] < tuple(int(part) for part in floor[2:].split(".")):
        problems.append(f"Requires-Python {floor} excludes the Python running this")
    return problems


def record_problems(bundle: zipfile.ZipFile, record_name: str) -> list[str]:
    """Every other entry is in RECORD, hashed sha256 in unpadded urlsafe base64."""
    problems = []
    rows = bundle.read(record_name).decode().splitlines()
    listed = {row.split(",")[0]: row.split(",")[1:] for row in rows}
    if listed.pop(record_name, None) != ["", ""]:
        problems.append("RECORD lists itself without a hash")
    for phantom in sorted(set(listed) - set(bundle.namelist())):
        problems.append(f"RECORD lists {phantom}, which the wheel does not hold")
    for name in sorted(set(bundle.namelist()) - {record_name}):
        hashed, size = listed.get(name, ["", ""])
        algorithm, _, encoded = hashed.partition("=")
        data = bundle.read(name)
        if algorithm != "sha256" or "=" in encoded or not re.fullmatch(r"[A-Za-z0-9_-]+", encoded):
            problems.append(f"RECORD hash for {name} is not unpadded urlsafe sha256")
        elif (base64.urlsafe_b64decode(encoded + "=" * (-len(encoded) % 4))
              != hashlib.sha256(data).digest()):
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
    parser.add_argument("--executable", default=None,
                        help="also ship the menu `make export` wrote into this folder")
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
        executable = pathlib.Path(args.executable).resolve() if args.executable else None
        artifacts = build(REPO, output, args.skip_notice, executable)
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
