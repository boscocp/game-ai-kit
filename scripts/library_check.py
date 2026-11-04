#!/usr/bin/env python3
"""Follow the page on using the library, where a stranger would (T64, T77).

The release's own self-test proves what is *in* each archive. This proves
the archives *work* away from this repository, which is the only place a
library is used, and it does so by taking the steps of
`docs/techniques/using-the-library.md` -- the page a person follows -- in
a throwaway directory outside the tree:

  release  `release.py --build` from HEAD: what `make release` ships
  unzip    a blank Godot project gets `ai_core`, `ai_search` and
           `ai_learning` as their zips unpack, and the page's two examples
  licence  every zip and the wheel carry LICENSE and NOTICE
  wheel    a fresh virtual environment installs the wheel -- no index, no
           dependencies -- and imports a technique and the registry from
           site-packages, with the repository nowhere on the path
  train    the page's Python block, run as it is printed, from the
           project's folder: it fits a model and writes `chance_model.json`
  import   the project imports itself, which is what registers `class_name`
  route    `scripts/library/stranger.gd` adds the page's route example to
  infer    the tree, and its model example, which reads the file `train`
           wrote; each prints a marker when it decided as the page says.
           The run must exit 0 *and* print both: a script error inside a
           `-s` script still exits 0 (CLAUDE.md)

The page marks each step `<!-- library-step: name -->`, in both languages,
and the check refuses to run a page whose steps are not exactly `STEPS`
below: a step on the page the check does not take is a promise nobody
keeps, and a step the check takes that the page does not say is a test of
something no reader does. Inside `godot/` every `class_name` is already
registered, so this is the portability proof the technique pages' own
gdUnit cases cannot be.

Why `--self-test` exists
------------------------
To prove the check refuses, and refuses for the reason planted. It first
follows the untouched page, which must pass: a Godot that does not start,
or a venv with no pip, would otherwise fail every planted case for the
wrong reason and the self-test would go green. Then: `grid_graph.gd` out
of `ai_core`'s zip must fail naming `GakGridGraph`; `utility/aim.py` out of
the wheel's install must fail naming `aim`; `NOTICE` out of a zip must fail
naming it; and a page with a step the check does not take, or without one
it does, must be refused naming the step.

Exit codes
----------
0   the page's steps all ran outside the repository
1   a step failed, or the page and the check disagree (what is printed)
2   wrong usage, the release could not be built, or the page has no block to run

Usage
-----
    library_check.py
    library_check.py --self-test
"""

from __future__ import annotations

import argparse
import dataclasses
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import venv
import zipfile

REPO = pathlib.Path(__file__).resolve().parent.parent
GODOT = REPO / "scripts" / "godot"
STRANGER = REPO / "scripts" / "library" / "stranger.gd"
PAGES = (REPO / "docs" / "techniques" / "using-the-library.md",
         REPO / "docs" / "techniques" / "using-the-library.pt-BR.md")
MARKERS = ("LIBRARY-CHECK: the route goes round the wall",
           "LIBRARY-CHECK: the model Python wrote decides in Godot")
ADDONS = ("ai_core", "ai_search", "ai_learning")
#: The steps this check takes, in the page's order. The page must name
#: these and no others.
STEPS = ("release", "unzip", "import", "route", "wheel", "train", "infer", "licence")
STEP_RE = re.compile(r"^<!--\s*library-step:\s*([a-z-]+)\s*-->$", re.M)
EXAMPLE_RE = re.compile(r"^<!--\s*example:\s*(\S+)\s*-->$", re.M)
PYTHON_BLOCK_RE = re.compile(r"^```python\n(.*?)^```$", re.M | re.S)
PROBE = (
    "from gameaikit import techniques\n"
    "from gameaikit.utility import aim\n"
    "import gameaikit, pathlib\n"
    "assert 'aim-choice' in techniques.available(), 'the registry lists the kit'\n"
    "assert 'site-packages' in pathlib.Path(gameaikit.__file__).parts, gameaikit.__file__\n"
    "head = aim.Zone('head', 2.0, (0.0, 1.65), [(-0.12, 1.5, 0.12, 1.8)], 1.0)\n"
    "torso = aim.Zone('torso', 1.0, (0.0, 1.175), [(-0.2, 0.85, 0.2, 1.5)], 1.0)\n"
    "assert aim.choose([head, torso], 0.5).aimed == 1, 'far away, the torso'\n"
    "print('LIBRARY-CHECK: the wheel answers from site-packages')\n"
)


class Unbuildable(Exception):
    """The release could not be built, so there is nothing to check."""


# --- the page ---------------------------------------------------------------


@dataclasses.dataclass(frozen=True)
class Followed:
    """What the page hands the run: its Python block and its two examples."""

    training: str
    examples: tuple[pathlib.Path, ...]


def page_steps(text: str) -> dict[str, str]:
    """Each marked step's name and its text, up to the next step's marker."""
    marks = list(STEP_RE.finditer(text))
    ends = [mark.start() for mark in marks[1:]] + [len(text)]
    return {mark.group(1): text[mark.end():end] for mark, end in zip(marks, ends)}


def step_findings(label: str, text: str) -> list[str]:
    """The page's steps against the ones this check takes, both ways."""
    named = list(STEP_RE.findall(text))
    findings = [f"{label}: the page has a step {name!r} this check does not take"
                for name in named if name not in STEPS]
    findings += [f"{label}: this check takes the step {name!r} and the page does not say it"
                 for name in STEPS if name not in named]
    if not findings and named != list(STEPS):
        findings.append(f"{label}: the page's steps are {named}, and the check takes {list(STEPS)}")
    return findings


def followed(text: str) -> Followed:
    """The Python block under `train` and the examples under `route` and `infer`."""
    steps = page_steps(text)
    training = PYTHON_BLOCK_RE.search(steps["train"])
    examples = [EXAMPLE_RE.search(steps[name]) for name in ("route", "infer")]
    if training is None or None in examples:
        raise Unbuildable("the page's train step has no python block, or route or infer no example")
    return Followed(training.group(1), tuple(REPO / found.group(1) for found in examples))


# --- the release ------------------------------------------------------------


def build_release(into: pathlib.Path) -> dict[str, pathlib.Path]:
    """Every artifact `release.py` builds from HEAD, by file name."""
    built = subprocess.run(
        [sys.executable, str(REPO / "scripts" / "release.py"), "--build", "--output", str(into)],
        capture_output=True, text=True,
    )
    if built.returncode != 0:
        raise Unbuildable(built.stderr.strip())
    return {pathlib.Path(line).name: pathlib.Path(line) for line in built.stdout.split()}


def the_one(artifacts: dict[str, pathlib.Path], prefix: str) -> pathlib.Path:
    """The artifact whose name starts with `prefix`."""
    return next(path for name, path in artifacts.items() if name.startswith(prefix))


def addon_zips(artifacts: dict[str, pathlib.Path]) -> list[pathlib.Path]:
    """The zips of the addons the page unzips."""
    return [the_one(artifacts, f"{addon}-") for addon in ADDONS]


def licence_findings(archives: list[pathlib.Path]) -> list[str]:
    """The `licence` step: every archive carries LICENSE and NOTICE."""
    findings = []
    for archive in archives:
        with zipfile.ZipFile(archive) as bundle:
            names = {pathlib.PurePosixPath(name).name for name in bundle.namelist()}
        findings += [f"{archive.name} carries no {needed}" for needed in ("LICENSE", "NOTICE")
                     if needed not in names]
    return findings


# --- the Python half ----------------------------------------------------------


def python_half(wheel: pathlib.Path, place: pathlib.Path, project: pathlib.Path,
                training: str, drop: str = "") -> list[str]:
    """The `wheel` and `train` steps; what failed, if anything.

    `drop` deletes one installed file before the probe -- the self-test's
    planted fault.
    """
    environment = place / "venv"
    venv.EnvBuilder(with_pip=True, clear=True).create(environment)
    python = environment / ("Scripts/python.exe" if sys.platform == "win32" else "bin/python")
    install = subprocess.run(
        [str(python), "-m", "pip", "install", "--quiet", "--no-index", "--no-deps", str(wheel)],
        capture_output=True, text=True, cwd=place,
    )
    if install.returncode != 0:
        return [f"the wheel does not install: {install.stderr.strip()}"]
    for found in environment.rglob(drop) if drop else []:
        found.unlink()
    probe = subprocess.run([str(python), "-I", "-c", PROBE], capture_output=True, text=True, cwd=place)
    if probe.returncode != 0 or "LIBRARY-CHECK" not in probe.stdout:
        return [f"the installed wheel does not answer: {probe.stderr.strip().splitlines()[-3:]}"]
    script = place / "my_training.py"
    script.write_text(training)
    trained = subprocess.run([str(python), "-I", str(script)], capture_output=True, text=True, cwd=project)
    if trained.returncode != 0 or not (project / "chance_model.json").is_file():
        return [f"the page's training block does not run: {trained.stderr.strip().splitlines()[-3:]}"]
    return []


# --- the Godot half -----------------------------------------------------------


def blank_project(place: pathlib.Path, zips: list[pathlib.Path], examples: tuple[pathlib.Path, ...]) -> pathlib.Path:
    """The `unzip` step: a project with nothing but the addons, the examples and the runner."""
    project = place / "stranger"
    (project / "addons").mkdir(parents=True)
    (project / "project.godot").write_text(
        "config_version=5\n\n[application]\n\nconfig/name=\"A stranger's game\"\n")
    for archive in zips:
        with zipfile.ZipFile(archive) as bundle:
            bundle.extractall(project / "addons")
    for copied in (*examples, STRANGER):
        shutil.copy(copied, project / copied.name)
    return project


def godot_half(project: pathlib.Path) -> list[str]:
    """The `import`, `route` and `infer` steps; what failed, if anything."""
    imported = subprocess.run([str(GODOT), "--headless", "--path", str(project), "--import"],
                              capture_output=True, text=True, timeout=300)
    if imported.returncode != 0:
        return [f"the blank project does not import (exit {imported.returncode})"]
    ran = subprocess.run([str(GODOT), "--headless", "--path", str(project), "-s", STRANGER.name],
                         capture_output=True, text=True, timeout=300)
    output = ran.stdout + ran.stderr
    missing = [marker for marker in MARKERS if marker not in output]
    if ran.returncode != 0 or missing:
        errors = [line for line in output.splitlines() if "ERROR" in line][:5]
        return [f"the examples do not decide in a blank project (exit {ran.returncode}, "
                f"missing {missing}): {errors}"]
    return []


# --- the whole page -------------------------------------------------------------


@dataclasses.dataclass(frozen=True)
class Planted:
    """One fault the self-test plants; the empty one is the untouched page."""

    zip_member: str = ""
    installed_file: str = ""


def without(archive: pathlib.Path, member: str) -> pathlib.Path:
    """A copy of `archive` with `member` taken out: a planted fault."""
    planted = archive.with_name(f"planted-{archive.name}")
    with zipfile.ZipFile(archive) as source, zipfile.ZipFile(planted, "w") as copy:
        for entry in source.infolist():
            if entry.filename != member:
                copy.writestr(entry, source.read(entry))
    return planted


def follow(artifacts: dict[str, pathlib.Path], page: Followed, place: pathlib.Path,
           planted: Planted = Planted()) -> list[str]:
    """Every step after `release`, in `place`; what failed, if anything."""
    zips = addon_zips(artifacts)
    if planted.zip_member:
        owner = planted.zip_member.split("/")[0]
        zips = [without(archive, planted.zip_member) if archive.name.startswith(f"{owner}-") else archive
                for archive in zips]
    wheel = the_one(artifacts, "gameaikit-")
    project = blank_project(place, zips, page.examples)
    failures = licence_findings([*zips, wheel])
    failures += python_half(wheel, place, project, page.training, planted.installed_file)
    return failures or godot_half(project)


def pages_findings(texts: dict[str, str]) -> list[str]:
    """Each page's steps against the check's, by label."""
    return [finding for label, text in texts.items() for finding in step_findings(label, text)]


def check() -> int:
    """The page's steps, outside the repository."""
    texts = {path.name: path.read_text(encoding="utf-8") for path in PAGES}
    failures = pages_findings(texts)
    if not failures:
        with tempfile.TemporaryDirectory(prefix="gak-library-") as workspace:
            place = pathlib.Path(workspace)
            artifacts = build_release(place / "release")
            failures = follow(artifacts, followed(texts[PAGES[0].name]), place)
    for failure in failures:
        print(f"library-check: {failure}")
    if not failures:
        print(f"library-check: the {len(STEPS)} steps of {PAGES[0].name} ran outside the repository")
    return 1 if failures else 0


# --- self-test --------------------------------------------------------------------


def page_cases(english: str) -> list[str]:
    """The planted pages: each must be refused, naming the step it plants."""
    extra = english + "\n<!-- library-step: teleport -->\n"
    short = english.replace("<!-- library-step: licence -->\n", "")
    failures = []
    for planted, named in ((extra, "teleport"), (short, "licence")):
        found = step_findings("planted", planted)
        if not any(named in line for line in found):
            failures.append(f"a page whose steps differ from the check's is refused, naming {named} ({found})")
    return failures


def run_cases(artifacts: dict[str, pathlib.Path], page: Followed, place: pathlib.Path) -> list[str]:
    """The untouched page passes, and each planted release fault is named."""
    failures = []
    untouched = follow(artifacts, page, place / "untouched")
    if untouched:
        failures.append(f"the untouched page passes every step ({untouched})")
    planted_faults = ((Planted(zip_member="ai_core/grid_graph.gd"), "GakGridGraph"),
                      (Planted(installed_file="aim.py"), "aim"),
                      (Planted(zip_member="ai_core/NOTICE"), "NOTICE"))
    for number, (planted, named) in enumerate(planted_faults):
        # A folder named for the fault would put the name in every path the
        # failure prints, and the case would pass on the path alone.
        found = follow(artifacts, page, place / f"case-{number}", planted)
        if not any(named in line for line in found):
            failures.append(f"{planted} fails, naming {named} ({found})")
    return failures


def self_test() -> int:
    """The untouched page must pass; every planted fault must be reported."""
    english = PAGES[0].read_text(encoding="utf-8")
    failures = page_cases(english)
    with tempfile.TemporaryDirectory(prefix="gak-library-selftest-") as workspace:
        place = pathlib.Path(workspace)
        failures += run_cases(build_release(place / "release"), followed(english), place)
    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        if exit_request.code == 0:
            raise
        return 2
    try:
        return self_test() if args.self_test else check()
    except Unbuildable as refusal:
        print(f"library-check: cannot follow the page: {refusal}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
