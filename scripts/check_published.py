#!/usr/bin/env python3
"""Download what the Godot Asset Store hands a stranger, and test that (T159).

Why it exists
-------------
`make library-check` builds `dist/` from HEAD and installs it: it tests what
we would publish today. A stranger gets the file the store holds, uploaded
on some earlier day from some earlier commit, and until this gate no command
in the repository had opened it. `tools/store/published.json` records each
upload -- its download URL, sha256, size, version and `provenance`, the tag
it was built from or `unknown` with a sentence saying what was found -- and
this gate holds the record true:

  integrity  the download's sha256 and size are the recorded ones;
  contents   every path is under `addons/ai_<name>/`, each addon carries
             LICENSE and NOTICE (invariant 9), and no path has a `test`,
             `tests`, `demo`, `gdUnit4` or `.toolchain` folder in it;
  install    the zip unzipped into a blank project outside the repository,
             imported headless on the pinned engine, and every script under
             `res://addons/` loaded by `scripts/store/load_every_class.gd`
             through `godot_checked.py --project`, so a `SCRIPT ERROR` fails
             it; the count of scripts and of registered `class_name`s must
             be the zip's own; and the engine must not say, as it quits,
             that something loaded is still alive (T162, below);
  rebuild    when `provenance` names a tag: the kit zip rebuilt in a clone
             of that tag, in a temporary folder, by **the tag's own**
             `release.py`, and its sha256 compared. A later change to the
             build script would otherwise read as a mismatch. An `unknown`
             entry skips the rebuild and says why, so the record that admits
             it does not know is still a true one.

Where the download goes
-----------------------
Into the toolchain, `GAK_TOOLCHAIN` or the checkout's `.toolchain`, as
`store/<version>-<download id>.zip`: never into the checkout or the home
folder (invariant 8). It is downloaded again on every run, because what is
checked is what the store hands out now, not what it handed out once.

Why it is not in `make check`
-----------------------------
It needs the network. `make check-published` runs it by hand, after each
upload and before a release, the way `make library-check` is run.

Why `--self-test` exists
------------------------
To prove it refuses (invariant 4). It needs no network, but it does need
the pinned engine: with no toolchain it exits 2, as the gate does. It zips
`ai_core` as the release lays it out and checks that untouched zip first --
it must pass, or a Godot that does not start would fail every plant for the
wrong reason -- then the planted ones, each named in what it prints: a zip
with no NOTICE in its addon, a record whose sha256 is wrong, one whose size
is wrong, a `test/` folder inside, an addon script that does not parse, and
a `class_name` the import cannot register (it sits inside a string), so the
loaded count is one fewer than the zip's, and three scripts that leave one
of them alive at exit.

What "alive at exit" is (T162)
------------------------------
On 2026-11-10 the 0.1.0 download loaded clean and then printed `7 resources
still in use at exit`. `godot_shards.FORGIVEN` lets that line through as
no engine error, on purpose, for the gates that are not about it, so the
run exited 0. Here it is a finding: a stranger who loads the kit the same
way sees the same line. Its cause, measured on 4.7.2, is in
`docs/godot/exit-leaks.md`: a script naming its own class as a value. The rebuild compare and the
stray-path rule are planted in `python/tests/test_check_published.py`,
which needs neither the network nor the engine.

Exit codes
----------
0   every recorded upload is what its record says
1   findings: a hash, a size, a path, an install or a rebuild disagrees
2   wrong usage, a record that cannot be read, a download that cannot be
    reached, no engine, or a tag the record names that is not here

Usage
-----
    check_published.py [--record PATH]
    check_published.py --self-test
"""

from __future__ import annotations

import argparse
import dataclasses
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
import zipfile

from check_exit_leaks import IN_USE, LEAKED
from godot_shards import engine_errors

REPO = pathlib.Path(__file__).resolve().parent.parent
RECORD = REPO / "tools" / "store" / "published.json"
GODOT = REPO / "scripts" / "godot"
CHECKED = REPO / "scripts" / "godot_checked.py"
LOADER = REPO / "scripts" / "store" / "load_every_class.gd"
#: A folder that marks a path as something no published archive should carry.
FORBIDDEN_FOLDERS = ("test", "tests", "demo", "demos", "gdunit4", ".toolchain")
ADDON_PATH = re.compile(r"^addons/(ai_[a-z0-9_]+)/.+")
MARKER = re.compile(r"PUBLISHED-CHECK: (\d+) script\(s\) loaded, (\d+) class_name\(s\) registered")
CLASS_NAME = re.compile(r"^class_name\s+\w+", re.M)
TAG = re.compile(r"^v\d+\.\d+\.\d+$")
FIELDS = ("download", "version", "sha256", "size", "provenance", "note")
#: Long enough for an import on a loaded machine; short enough to be a finding.
IMPORT_SECONDS = 240
DOWNLOAD_SECONDS = 120
#: Sent to the store instead of anything naming a person (CLAUDE.md, privacy).
USER_AGENT = "game-ai-kit-check-published"


class Unreachable(Exception):
    """A record unreadable, a download unreachable, no engine, no tag: exit 2."""


@dataclasses.dataclass(frozen=True)
class Upload:
    """One upload as `published.json` records it."""

    download: str
    version: str
    sha256: str
    size: int
    provenance: str
    note: str

    @property
    def label(self) -> str:
        return f"{self.version} ({self.download})"


def read_record(path: pathlib.Path) -> list[Upload]:
    """Every upload in the record; Unreachable when one lacks a field.

    Why so strict: a record missing its sha256 would make every check after
    it vacuous, and a vacuous check reads green.
    """
    try:
        entries = json.loads(path.read_text(encoding="utf-8"))["uploads"]
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise Unreachable(f"{path} cannot be read as a record of uploads: {error}") from error
    uploads = []
    for entry in entries:
        missing = [field for field in FIELDS if field not in entry]
        if missing:
            raise Unreachable(f"{path}: an upload lacks {missing}")
        if entry["provenance"] != "unknown" and not TAG.match(entry["provenance"]):
            raise Unreachable(f"{path}: provenance {entry['provenance']!r} is neither a tag nor 'unknown'")
        uploads.append(Upload(**{field: entry[field] for field in FIELDS}))
    if not uploads:
        raise Unreachable(f"{path} records no upload")
    return uploads


# --- the download -----------------------------------------------------------


def toolchain() -> pathlib.Path:
    """The toolchain folder, as `scripts/godot` and the Makefile choose it."""
    return pathlib.Path(os.environ.get("GAK_TOOLCHAIN") or REPO / ".toolchain")


def download(upload: Upload, folder: pathlib.Path) -> pathlib.Path:
    """The store's file for `upload`, fetched again into `folder`.

    Written beside its final name and renamed when whole, so an interrupted
    download never sits there looking like the store's file.
    """
    number = upload.download.rstrip("/").rsplit("/", 1)[-1]
    target = folder / "store" / f"{upload.version}-{number}.zip"
    target.parent.mkdir(parents=True, exist_ok=True)
    partial = target.with_suffix(".part")
    request = urllib.request.Request(upload.download, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=DOWNLOAD_SECONDS) as response:
            partial.write_bytes(response.read())
    except (urllib.error.URLError, OSError) as error:
        raise Unreachable(f"{upload.download} cannot be downloaded: {error}") from error
    partial.replace(target)
    return target


# --- what the file is ---------------------------------------------------------


def sha256_of(path: pathlib.Path) -> str:
    """The file's sha256, as hex."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def integrity_findings(archive: pathlib.Path, upload: Upload) -> list[str]:
    """The download's sha256 and size against the record's."""
    findings = []
    measured = sha256_of(archive)
    if measured != upload.sha256:
        findings.append(f"integrity: the sha256 is {measured}, and the record says {upload.sha256}")
    size = archive.stat().st_size
    if size != upload.size:
        findings.append(f"integrity: the size is {size} bytes, and the record says {upload.size}")
    return findings


def contents_findings(names: list[str]) -> list[str]:
    """Every path an addon's, each addon attributed, nothing from a test or a demo."""
    findings = [f"contents: {name} is not under addons/ai_<name>/"
                for name in names if not ADDON_PATH.match(name)]
    findings += [f"contents: {name} is in a {folder}/ folder, which no archive ships"
                 for name in names for folder in name.lower().split("/")[:-1]
                 if folder in FORBIDDEN_FOLDERS]
    addons = sorted({found.group(1) for found in map(ADDON_PATH.match, names) if found})
    findings += [f"contents: addons/{addon}/ carries no {needed}"
                 for addon in addons for needed in ("LICENSE", "NOTICE")
                 if f"addons/{addon}/{needed}" not in names]
    if not addons:
        findings.append("contents: the archive holds no addon")
    return findings


# --- the install ---------------------------------------------------------------


def blank_project(root: pathlib.Path, archive: pathlib.Path) -> pathlib.Path:
    """A blank Godot project in `root` with the archive unzipped into it."""
    project = root / "a_strangers_game"
    project.mkdir()
    (project / "project.godot").write_text(
        "config_version=5\n\n[application]\n\nconfig/name=\"A stranger's game\"\n")
    with zipfile.ZipFile(archive) as bundle:
        bundle.extractall(project)
    return project


def expected_counts(archive: pathlib.Path) -> tuple[int, int]:
    """How many scripts the archive holds, and how many declare a `class_name`."""
    with zipfile.ZipFile(archive) as bundle:
        scripts = [bundle.read(name).decode("utf-8", errors="replace")
                   for name in bundle.namelist() if name.endswith(".gd")]
    return len(scripts), sum(1 for text in scripts if CLASS_NAME.search(text))


def run_godot(command: list[str], seconds: int) -> tuple[int | None, str]:
    """Run one command; its exit code (None when killed at `seconds`) and output."""
    try:
        done = subprocess.run(command, capture_output=True, text=True, timeout=seconds)
    except subprocess.TimeoutExpired:
        return None, ""
    return done.returncode, done.stdout + done.stderr


def exit_leaks(output: str) -> list[str]:
    """The engine's lines saying something loaded was still alive as it quit."""
    return [line.strip() for line in output.splitlines() if LEAKED in line or IN_USE in line]


def load_every_class(project: pathlib.Path, step: str) -> tuple[list[str], tuple[int, int] | None]:
    """Every script under the imported `project`'s `addons/` loaded; what went wrong, and the counts.

    Why the exit lines are read here and not in `godot_checked.py`: there
    they are forgiven for every gate that is not about them, and they are
    printed after the last line the loader runs, so only its output shows
    them. `library_check.py` calls this on the kit it unzipped (T162).
    """
    (project / LOADER.name).write_bytes(LOADER.read_bytes())
    command = [sys.executable, str(CHECKED), "--project", str(project),
               "--timeout", str(IMPORT_SECONDS), f"res://{LOADER.name}"]
    code, output = run_godot(command, IMPORT_SECONDS + 30)
    found = MARKER.search(output)
    if code != 0 or found is None:
        errors = [line for line in output.splitlines() if "ERROR" in line][:5]
        return [f"{step}: a script does not load in a stranger's project (exit {code}): {errors}"], None
    leaks = exit_leaks(output)
    if leaks:
        return [f"{step}: loading every script leaves something alive at exit, "
                f"which a stranger sees too (docs/godot/exit-leaks.md): {leaks}"], None
    return [], (int(found.group(1)), int(found.group(2)))


def install_findings(archive: pathlib.Path) -> list[str]:
    """The archive in a blank project outside the repository: imported, every script loaded."""
    with tempfile.TemporaryDirectory(prefix="gak-published-") as root:
        project = blank_project(pathlib.Path(root), archive)
        code, output = run_godot([str(GODOT), "--headless", "--path", str(project), "--import"], IMPORT_SECONDS)
        if code == 2 and "toolchain missing" in output:
            raise Unreachable("no engine: run 'make bootstrap'")
        if code != 0 or engine_errors(output):
            return [f"install: the import fails (exit {code}): {engine_errors(output)[:5]}"]
        findings, loaded = load_every_class(project, "install")
    if loaded is None:
        return findings
    if loaded != expected_counts(archive):
        return [f"install: {loaded[0]} script(s) and {loaded[1]} class_name(s) came up, "
                f"and the archive holds {expected_counts(archive)}"]
    print(f"check-published: {archive.name}: {loaded[0]} script(s) loaded and "
          f"{loaded[1]} class_name(s) registered in a blank project")
    return []


# --- the rebuild -------------------------------------------------------------------


def rebuilt_sha256(tag: str, version: str) -> str:
    """The sha256 of the kit zip that `tag`'s own `release.py` builds, in a clone of the tag."""
    with tempfile.TemporaryDirectory(prefix="gak-rebuild-") as root:
        clone = pathlib.Path(root) / "clone"
        cloned = subprocess.run(["git", "clone", "-q", "--branch", tag, str(REPO), str(clone)],
                                capture_output=True, text=True)
        if cloned.returncode != 0:
            raise Unreachable(f"the tag {tag} cannot be cloned here (git fetch --tags?): {cloned.stderr.strip()}")
        output = pathlib.Path(root) / "out"
        built = subprocess.run([sys.executable, "-I", "scripts/release.py", "--build", "--output", str(output)],
                               cwd=clone, capture_output=True, text=True)
        kit = output / "dist" / f"game-ai-kit-addons-{version}.zip"
        if built.returncode != 0 or not kit.is_file():
            return f"no build: {tag}'s release.py exited {built.returncode}"
        return sha256_of(kit)


def rebuild_findings(upload: Upload) -> list[str]:
    """When the record names a tag, the tag's build must be the store's file, byte for byte."""
    if upload.provenance == "unknown":
        print(f"check-published: {upload.label}: provenance unknown, so no rebuild: {upload.note}")
        return []
    rebuilt = rebuilt_sha256(upload.provenance, upload.version)
    if rebuilt != upload.sha256:
        return [f"rebuild: {upload.provenance}'s own release.py builds {rebuilt}, "
                f"and the store's file is {upload.sha256}"]
    print(f"check-published: {upload.label}: rebuilt from {upload.provenance}, byte for byte")
    return []


# --- the whole record ------------------------------------------------------------------


def archive_findings(archive: pathlib.Path, upload: Upload) -> list[str]:
    """What one archive is, against its record: integrity, contents, then the install.

    The install runs only on contents that are clean: an archive carrying a
    test folder or a stray path has already failed, and importing it would
    only add noise to the finding that matters.
    """
    findings = integrity_findings(archive, upload)
    try:
        with zipfile.ZipFile(archive) as bundle:
            names = bundle.namelist()
    except zipfile.BadZipFile:
        return [*findings, "contents: the download is not a zip"]
    contents = contents_findings(names)
    return [*findings, *(contents or install_findings(archive))]


def check(record: pathlib.Path) -> int:
    """Every recorded upload, downloaded into the toolchain and held to its record."""
    findings = []
    for upload in read_record(record):
        archive = download(upload, toolchain())
        found = archive_findings(archive, upload)
        found += rebuild_findings(upload) if not found else []
        findings += [f"{upload.label}: {line}" for line in found]
        if not found:
            print(f"check-published: {upload.label}: {upload.size} bytes, sha256 {upload.sha256[:12]}..., "
                  f"installs in a blank project")
    for line in findings:
        print(f"check-published: {line}")
    return 1 if findings else 0


# --- self-test ------------------------------------------------------------------------------


def addon_entries(addon: str) -> dict[str, bytes]:
    """`addon`'s committed files, laid out `addons/<addon>/` as the release lays them out."""
    listed = subprocess.run(["git", "-C", str(REPO), "ls-files", f"godot/addons/{addon}"],
                            capture_output=True, text=True, check=True).stdout.split()
    entries = {path.removeprefix("godot/"): (REPO / path).read_bytes() for path in listed}
    entries[f"addons/{addon}/VERSION"] = (REPO / "VERSION").read_bytes()
    return entries


def planted_zip(path: pathlib.Path, entries: dict[str, bytes]) -> Upload:
    """`entries` written as a zip at `path`, and a record that is true of it."""
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as bundle:
        for name, data in sorted(entries.items()):
            bundle.writestr(name, data)
    return Upload(download="planted", version="0.0.0", sha256=sha256_of(path),
                  size=path.stat().st_size, provenance="unknown", note="planted")


#: Three scripts that leave the first alive at exit, as measured on 4.7.2
#: (docs/godot/exit-leaks.md). `a_` names its own class as a value, so only
#: the engine's walk at exit can free it. `c_` does the same and extends
#: `b_`, loaded before it: freeing `c_` frees `b_`, the next script on that
#: walk, and the walk ends there, before `a_`. The loader loads them in
#: name order. Should a later engine stop leaking here, this case fails, and
#: the page is out of date.
LEAKING = {
    "addons/ai_core/a_planted_self.gd": b"class_name GakPlantedSelf\nextends RefCounted\n\n\n"
                                        b"static func make() -> RefCounted:\n\treturn GakPlantedSelf.new()\n",
    "addons/ai_core/b_planted_base.gd": b"class_name GakPlantedBase\nextends RefCounted\n",
    "addons/ai_core/c_planted_child.gd": b"class_name GakPlantedChild\nextends GakPlantedBase\n\n\n"
                                         b"static func make() -> RefCounted:\n\treturn GakPlantedChild.new()\n",
}


def plants(clean: dict[str, bytes]) -> list[tuple[str, dict[str, bytes], str, str]]:
    """Each planted case: its label, its entries, the record field that lies, and what must be named."""
    no_notice = {name: data for name, data in clean.items() if name != "addons/ai_core/NOTICE"}
    with_test = {**clean, "addons/ai_core/test/grid_graph_test.gd": b"extends RefCounted\n"}
    broken = {**clean, "addons/ai_core/planted.gd": b"class_name GakPlanted\nextends RefCounted\n\nfunc f( -> void:\n\tpass\n"}
    # It parses, and its `class_name` line is text in a string: the zip's
    # count sees one more class than the import can register.
    unseen = {**clean, "addons/ai_core/planted.gd":
              b'extends RefCounted\n\nconst NOTE: String = """\nclass_name GakNever\n"""\n'}
    return [
        ("an addon with no NOTICE", no_notice, "", "carries no NOTICE"),
        ("a record whose sha256 is wrong", clean, "sha256", "integrity: the sha256 is"),
        ("a record whose size is wrong", clean, "size", "integrity: the size is"),
        ("a test/ folder inside", with_test, "", "is in a test/ folder"),
        ("an addon script that does not parse", broken, "", "Parse Error"),
        ("a class_name the import cannot register", unseen, "", "class_name(s) came up"),
        ("a script left alive at exit", {**clean, **LEAKING}, "", "alive at exit"),
    ]


def lying(upload: Upload, field: str) -> Upload:
    """`upload` with `field` made false; as it is when `field` is empty."""
    if field == "sha256":
        return dataclasses.replace(upload, sha256="0" * 64)
    if field == "size":
        return dataclasses.replace(upload, size=upload.size + 1)
    return upload


def self_test() -> int:
    """The untouched zip must pass; each planted fault must be named."""
    clean = addon_entries("ai_core")
    failures = []
    with tempfile.TemporaryDirectory(prefix="gak-published-selftest-") as root:
        # Numbered, not named for the fault: a name in the path would put
        # the expected words in every finding that prints a path.
        untouched = planted_zip(pathlib.Path(root) / "case-clean.zip", clean)
        found = archive_findings(pathlib.Path(root) / "case-clean.zip", untouched)
        if found:
            failures.append(f"the untouched zip passes ({found})")
        for number, (label, entries, lies, named) in enumerate(plants(clean)):
            archive = pathlib.Path(root) / f"case-{number}.zip"
            upload = lying(planted_zip(archive, entries), lies)
            found = archive_findings(archive, upload)
            if not any(named in line for line in found):
                failures.append(f"{label} is refused, naming {named!r} ({found})")
    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    """Parse the command line and run; usage errors and unreachable things exit 2."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--record", type=pathlib.Path, default=RECORD)
    parser.add_argument("--self-test", action="store_true")
    try:
        options = parser.parse_args(argv)
    except SystemExit as exit_request:
        return 0 if exit_request.code == 0 else 2
    try:
        return self_test() if options.self_test else check(options.record)
    except Unreachable as refusal:
        print(f"check-published: {refusal}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
