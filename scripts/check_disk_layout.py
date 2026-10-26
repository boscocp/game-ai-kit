#!/usr/bin/env python3
"""Fail if the Godot toolchain, or the art generator's model, writes to the small disk.

The rule
--------
Everything this project installs lives on the large disk, under the toolchain
directory. Nothing lands in the user's home.

Why this gate exists
--------------------
On 2026-10-12, during bootstrap, enabling Godot's self-contained mode (an empty
`._sc_` file next to the binary) was assumed to be enough. It is not. Measured
on Godot 4.7.2: `._sc_` redirects editor settings, cache and export templates
-- the part that grows past 1 GB -- but a single `--headless --import` still
recreated `~/.local/share/godot/app_userdata/`, because the project's `user://`
directory is not editor data. The second mechanism, XDG_DATA_HOME, covers it.
On Windows the engine reads APPDATA and LOCALAPPDATA instead (OS_Windows's
get_config_path and get_cache_path), so scripts/godot points those two at the
toolchain, and the leaks looked for include where they would land.

Two mechanisms means two ways to silently regress, so both are asserted here
rather than trusted.

The art generator (T31) has the same trap, larger: tens of GB of model that Hugging
Face, torch and Triton would all cache under ~/.cache by default. scripts/artgen
points every one of them at the toolchain directory, and the paths below say
where they would land if it stopped.

Exit codes
----------
0   clean: nothing on the small disk, toolchain intact
1   violations found (each one printed)
2   wrong usage, or a path that cannot be read

Usage
-----
    check_disk_layout.py [--repo PATH] [--toolchain PATH] [--home PATH]
    check_disk_layout.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import io
import os
import pathlib
import subprocess
import sys
import tempfile

# Where Godot writes when neither mechanism is in place. Relative to home.
LEAK_PATHS = (
    ".local/share/godot",
    ".config/godot",
    ".cache/godot",
    # Added after a review pointed out the list was three fixed paths and the
    # engine has more than three places to write.
    ".local/state/godot",
    ".godot",
    # The art generator's model and kernel caches, where they land without
    # scripts/artgen. ~/.cache/pip and ~/.nv are not listed: on the owner's
    # machine other software already keeps caches there, so their presence
    # says nothing about this repository. That pip and the driver honour
    # PIP_CACHE_DIR and CUDA_CACHE_PATH was measured instead, by mtime.
    # The three below are shared with any other machine-learning project, so
    # a developer with one will see this fire: that is the price of catching
    # a 30 GB model landing on the small disk, and the message says where from.
    ".cache/huggingface",
    ".cache/torch",
    ".triton",
    # Windows: %APPDATA%/Godot holds editor data and user://, and
    # %LOCALAPPDATA%/Godot the cache, when scripts/godot is bypassed.
    "AppData/Roaming/Godot",
    "AppData/Local/Godot",
)

WINDOWS = os.name == "nt"
DEFAULT_TOOLCHAIN = "D:/games/gamedev/toolchain" if WINDOWS else "/mnt/games/gamedev/toolchain"


def find_leaks(home: pathlib.Path) -> list[str]:
    """Report any Godot directory, or model cache, that exists under home.

    An empty leftover directory is reported too: it means a mechanism stopped
    working, and the files follow the directory.
    """
    findings = []
    for relative in LEAK_PATHS:
        leaked = home / relative
        if leaked.exists():
            size = sum(f.stat().st_size for f in leaked.rglob("*") if f.is_file())
            findings.append(f"D1 {leaked} exists on the small disk ({size} bytes)")
    return findings


def check_toolchain(toolchain: pathlib.Path, windows: bool = WINDOWS) -> list[str]:
    """Report a toolchain that is missing or has lost self-contained mode.

    On Windows the toolchain is two programs: `godot_console.exe`, which
    scripts/godot calls, and the `godot.exe` it starts. Either one missing is
    a toolchain that cannot run. There is no execute bit to ask about there --
    `os.access(X_OK)` is true of any file -- so being a file is what is asked.
    """
    findings = []
    names = ("godot_console.exe", "godot.exe") if windows else ("godot",)
    marker = toolchain / "godot" / "._sc_"

    for name in names:
        binary = toolchain / "godot" / name
        # `exists()` was true for a *directory* named godot/godot, which then
        # satisfied every other check here.
        if not binary.is_file() or not (windows or os.access(binary, os.X_OK)):
            findings.append(f"D2 no executable Godot at {binary} -- run 'make bootstrap'")
    if findings:
        return findings
    if not marker.exists():
        findings.append(f"D3 self-contained marker missing: {marker}")
    if not (toolchain / "godot" / "editor_data").exists():
        findings.append(f"D4 no editor_data/ beside the binary; is ._sc_ being honoured?")
    return findings


def check_repo_location(repo: pathlib.Path, home: pathlib.Path,
                        on_runner: bool = False) -> list[str]:
    """Report a repository that sits on the small disk.

    Not asked on a CI runner, and the run says so. The two disks are the
    author's machine; a GitHub runner has one, and checks the repository out
    under /home/runner whatever the workflow says. The first CI run of this
    repository (wave 63) failed here and nowhere else. The leaks above are
    still looked for on the runner: a Godot that writes to ~/.local is wrong
    on any machine. The runner is known by GitHub's own `GITHUB_ACTIONS=true`;
    set by hand on a desk, it turns this one rule into a note, and says so.
    """
    try:
        repo.resolve().relative_to(home.resolve())
    except ValueError:
        return []
    if on_runner:
        print(f"D5 note: the repository is under {home}, and this is a CI runner "
              "with one disk; not a finding there")
        return []
    return [f"D5 the repository itself is under {home} -- it belongs on the large disk"]


# --- each checkout its own user:// (T83) ------------------------------------
#
# Until wave 93 scripts/godot pointed every checkout's user:// at one
# directory under the toolchain, and two waves testing at once wrote each
# other's files (wave 78's effects shards failed during wave 80's check). The
# wrapper now points it inside its own checkout, at .user-data/, and prints
# that redirect when asked -- so what is checked here is what Godot is given,
# not a copy of the rule.

PRINT_REDIRECT = "--gak-print-redirect"

# What one checkout's wrapper redirects user:// to: its NAME=PATH paths, or
# None when the wrapper predates T83 and cannot say.
Redirects = dict[pathlib.Path, "list[pathlib.Path] | None"]


def list_checkouts(repo: pathlib.Path) -> list[pathlib.Path]:
    """Every checkout git knows for this repository: the main one and each worktree.

    A copy with no git (a release unpacked somewhere) is one checkout, itself.
    A worktree whose folder is gone is skipped: nothing there can run Godot.
    """
    listed = subprocess.run(["git", "-C", str(repo), "worktree", "list", "--porcelain"],
                            capture_output=True, text=True)
    if listed.returncode != 0:
        return [repo]
    paths = [pathlib.Path(line.split(" ", 1)[1]) for line in listed.stdout.splitlines()
             if line.startswith("worktree ")]
    return [path for path in paths if path.is_dir()] or [repo]


def read_redirect(checkout: pathlib.Path) -> "list[pathlib.Path] | None":
    """Ask one checkout's own scripts/godot where it sends user://.

    None for a wrapper that does not know the question: running an older one
    with an unknown flag would start Godot, so it is not run at all.
    """
    wrapper = checkout / "scripts" / "godot"
    if not wrapper.is_file() or PRINT_REDIRECT not in wrapper.read_text(errors="replace"):
        return None
    printed = subprocess.run(["bash", str(wrapper), PRINT_REDIRECT],
                             capture_output=True, text=True, timeout=60)
    return [pathlib.Path(line.split("=", 1)[1].strip())
            for line in printed.stdout.splitlines() if "=" in line]


def is_inside(path: pathlib.Path, folder: pathlib.Path) -> bool:
    """Whether path is folder or lies under it, after resolving both."""
    try:
        path.resolve().relative_to(folder.resolve())
    except ValueError:
        return False
    return True


def ignored_by_git(checkout: pathlib.Path, path: pathlib.Path) -> bool:
    """Whether git in that checkout ignores path: user:// holds logs, never commits."""
    asked = subprocess.run(["git", "-C", str(checkout), "check-ignore", "-q", str(path)],
                           capture_output=True)
    return asked.returncode == 0


def check_own_redirect(checkout: pathlib.Path, folders: list[pathlib.Path], home: pathlib.Path,
                       on_runner: bool, ignored) -> list[str]:
    """D6 and D8 for one checkout: off home, inside itself, and ignored by git.

    Under home on a CI runner is a note, as D5 is: there the checkout itself
    is under home, and so is everything inside it.
    """
    if not folders:
        return [f"D8 {checkout}/scripts/godot printed no user:// redirect"]
    findings = []
    for folder in folders:
        if is_inside(folder, home) and on_runner:
            print(f"D6 note: user:// at {folder} is under {home}, on a one-disk CI runner")
        elif is_inside(folder, home):
            findings.append(f"D6 user:// for {checkout} is {folder}, under {home} -- the small disk")
        if not is_inside(folder, checkout):
            findings.append(f"D8 user:// for {checkout} is {folder}, outside the checkout "
                            "-- shared by every checkout that resolves there (docs/adr/0022)")
        elif not ignored(checkout, folder):
            findings.append(f"D8 user:// for {checkout} is {folder}, which git does not ignore")
    return findings


def check_shared_redirects(redirects: Redirects) -> list[str]:
    """D7: no two checkouts write one user://, nor one inside the other's."""
    findings = []
    known = [(checkout, folder) for checkout, folders in redirects.items()
             for folder in folders or []]
    for index, (first, first_folder) in enumerate(known):
        for second, second_folder in known[index + 1:]:
            if first != second and (is_inside(first_folder, second_folder)
                                    or is_inside(second_folder, first_folder)):
                findings.append(f"D7 {first} and {second} share user:// "
                                f"({first_folder} and {second_folder})")
    return findings


def check_user_dirs(redirects: Redirects, home: pathlib.Path, on_runner: bool = False,
                    ignored=ignored_by_git) -> list[str]:
    """D6-D8 over every checkout: each its own user://, on the large disk.

    A checkout whose wrapper predates T83 is a note: it is another branch's
    state, and it stops being one when that branch takes main.
    """
    older = sorted(str(checkout) for checkout, folders in redirects.items() if folders is None)
    if older:
        print(f"D7 note: {len(older)} checkout(s) predate T83 and still share the old "
              f"user:// -- {', '.join(older)}")
    findings = []
    for checkout, folders in redirects.items():
        if folders is not None:
            findings += check_own_redirect(checkout, folders, home, on_runner, ignored)
    return findings + check_shared_redirects(redirects)


def run(repo: pathlib.Path, toolchain: pathlib.Path, home: pathlib.Path,
        on_runner: bool = False, windows: bool = WINDOWS,
        redirects: "Redirects | None" = None, ignored=ignored_by_git) -> int:
    """Every check; the redirects are read from the checkouts unless given."""
    if redirects is None:
        redirects = {checkout: read_redirect(checkout) for checkout in list_checkouts(repo)}
    findings = (find_leaks(home) + check_toolchain(toolchain, windows)
                + check_repo_location(repo, home, on_runner)
                + check_user_dirs(redirects, home, on_runner, ignored))
    for finding in findings:
        print(finding)
    return 1 if findings else 0


# --- self-test -------------------------------------------------------------
#
# Every gate in this repo is born with a case it must reject. A gate that only
# knows how to go green is worse than no gate, because nobody investigates a
# green.


def wrapper_copy(root: pathlib.Path, name: str) -> pathlib.Path:
    """A checkout holding only this repository's real scripts/godot.

    The wrapper's own answer is what the case holds, so a wrapper changed back
    to one directory for everyone fails the self-test, not just a planted dict.
    """
    checkout = root / name
    (checkout / "scripts").mkdir(parents=True)
    source = pathlib.Path(__file__).resolve().parent / "godot"
    (checkout / "scripts" / "godot").write_text(source.read_text())
    return checkout


def user_dir_cases(root: pathlib.Path, toolchain: pathlib.Path, home: pathlib.Path,
                   repo: pathlib.Path, expect, said) -> None:
    """The planted user:// layouts (T83): D6, D7 and D8, each asked for by code."""
    other = root / "other-checkout"
    other.mkdir()
    shared = toolchain / "xdg"
    # Planted: the layout before T83 -- two checkouts, one directory.
    expect("two checkouts, one user:// (D7)",
           int(said("D7", repo, toolchain, home, {repo: [shared], other: [shared]})), 1)
    # Planted: one checkout back on the toolchain; with one checkout (CI)
    # there is nothing to collide with, and D8 is what catches it.
    expect("user:// outside its checkout (D8)",
           int(said("D8", repo, toolchain, home, {repo: [shared]})), 1)
    expect("user:// under home (D6)",
           int(said("D6", repo, toolchain, home, {repo: [home / ".user-data"]})), 1)
    expect("user:// git does not ignore (D8)",
           int(said("D8", repo, toolchain, home, {repo: [repo / ".user-data"]},
                    ignored=lambda *_: False)), 1)
    expect("a wrapper that prints nothing (D8)", int(said("D8", repo, toolchain, home, {repo: []})), 1)
    # Planted, D7 alone: a checkout inside another's user://, so each is
    # inside itself and only the overlap is wrong.
    inner = repo / ".user-data" / "xdg" / "inner"
    expect("one user:// inside another's (D7 alone)",
           int(said("D7", repo, toolchain, home,
                    {repo: [repo / ".user-data" / "xdg"], inner: [inner / ".user-data"]})), 1)
    with contextlib.redirect_stdout(io.StringIO()):
        older = run(repo, toolchain, home, False, False,
                    {repo: [repo / ".user-data"], other: None}, lambda *_: True)
        on_runner = run(home / "runner-repo", toolchain, home, True, False,
                        {home / "runner-repo": [home / "runner-repo" / ".user-data"]},
                        lambda *_: True)
    expect("a worktree that predates T83 is a note", older, 0)
    expect("user:// under home on a runner is a note", on_runner, 0)
    first, second = wrapper_copy(root, "copy-one"), wrapper_copy(root, "copy-two")
    real = {first: read_redirect(first), second: read_redirect(second)}
    with contextlib.redirect_stdout(io.StringIO()):
        expect("the real wrapper in two checkouts",
               run(repo, toolchain, home, False, False, real, lambda *_: True), 0)


def self_test() -> int:
    failures = []

    def expect(label: str, got: int, want: int) -> None:
        if got != want:
            failures.append(f"{label}: expected exit {want}, got {got}")

    def quiet(repo: pathlib.Path, toolchain: pathlib.Path, home: pathlib.Path,
              on_runner: bool = False, windows: bool = False) -> int:
        """Run the check without printing: a planted finding is not a failure.

        The Linux layout unless told otherwise, whatever the host: a planted
        missing `._sc_` must be refused for that, not because a Windows host
        went looking for `godot.exe` beside it. The checkout's user:// is the
        decided one, inside it, so these cases plant one thing each.
        """
        own = {repo: [repo / ".user-data" / "xdg"]}
        with contextlib.redirect_stdout(io.StringIO()):
            return run(repo, toolchain, home, on_runner, windows, own, lambda *_: True)

    def said(code: str, repo: pathlib.Path, toolchain: pathlib.Path, home: pathlib.Path,
             redirects: Redirects, on_runner: bool = False, ignored=lambda *_: True) -> bool:
        """Whether a planted user:// layout fails with that code among its findings.

        The code is asked for, not only exit 1: the cases overlap (a shared
        directory is also outside its checkout), and a gate with one of its
        checks deleted would still exit 1 on the others.
        """
        printed = io.StringIO()
        with contextlib.redirect_stdout(printed):
            code_returned = run(repo, toolchain, home, on_runner, False, redirects, ignored)
        lines = printed.getvalue().splitlines()
        return code_returned == 1 and any(line.startswith(code + " ")
                                          and not line.startswith(code + " note")
                                          for line in lines)

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)

        clean_home = root / "clean-home"
        clean_home.mkdir()
        good_toolchain = root / "toolchain"
        (good_toolchain / "godot" / "editor_data").mkdir(parents=True)
        binary = good_toolchain / "godot" / "godot"
        binary.write_text("#!/bin/sh\n")
        binary.chmod(0o755)
        (good_toolchain / "godot" / "._sc_").touch()
        # Both layouts are held on every host: the cases pass `windows`
        # explicitly where it matters, so neither depends on the desk.
        for name in ("godot_console.exe", "godot.exe"):
            (good_toolchain / "godot" / name).write_text("MZ")
        repo_off_home = root / "repo"
        repo_off_home.mkdir()

        expect("clean layout", quiet(repo_off_home, good_toolchain, clean_home, False, False), 0)
        expect("clean Windows layout",
               quiet(repo_off_home, good_toolchain, clean_home, False, True), 0)

        # Planted: Godot run on Windows without scripts/godot, so user://
        # landed under %APPDATA%.
        roaming_home = root / "roaming-home"
        (roaming_home / "AppData/Roaming/Godot/app_userdata/game-ai-kit").mkdir(parents=True)
        expect("leaked %APPDATA% user:// dir",
               quiet(repo_off_home, good_toolchain, roaming_home, False, True), 1)

        # Planted: a Windows toolchain with the console twin and no editor
        # for it to start -- and its mirror image.
        for missing in ("godot.exe", "godot_console.exe"):
            half = root / ("half-" + missing)
            (half / "godot" / "editor_data").mkdir(parents=True)
            (half / "godot" / "._sc_").touch()
            for name in {"godot.exe", "godot_console.exe"} - {missing}:
                (half / "godot" / name).write_text("MZ")
            expect(f"Windows toolchain without {missing}",
                   quiet(repo_off_home, half, clean_home, False, True), 1)

        # Planted: the exact leak measured during bootstrap.
        dirty_home = root / "dirty-home"
        (dirty_home / ".local/share/godot/app_userdata/game-ai-kit").mkdir(parents=True)
        expect("leaked user:// dir", quiet(repo_off_home, good_toolchain, dirty_home), 1)

        # Planted: the generator run without its wrapper, fetching a model
        # into Hugging Face's default cache.
        model_home = root / "model-home"
        (model_home / ".cache/huggingface/hub/models--some--model").mkdir(parents=True)
        expect("a model cache under home", quiet(repo_off_home, good_toolchain, model_home), 1)
        # Planted: torch's and Triton's caches, each on its own -- with only
        # the Hugging Face case, deleting either path from the list stayed green.
        for leak in (".cache/torch/hub", ".triton/cache"):
            leaked_home = root / ("leak-" + leak.replace("/", "-"))
            (leaked_home / leak).mkdir(parents=True)
            expect(f"{leak} under home", quiet(repo_off_home, good_toolchain, leaked_home), 1)

        # Planted: someone removed the self-contained marker.
        no_marker = root / "no-marker"
        (no_marker / "godot" / "editor_data").mkdir(parents=True)
        (no_marker / "godot" / "godot").write_text("#!/bin/sh\n")
        (no_marker / "godot" / "godot").chmod(0o755)
        expect("missing ._sc_", quiet(repo_off_home, no_marker, clean_home), 1)

        # Planted: a directory where the binary should be. exists() said yes.
        a_directory = root / "adirectory"
        (a_directory / "godot" / "godot").mkdir(parents=True)
        (a_directory / "godot" / "editor_data").mkdir()
        (a_directory / "godot" / "._sc_").touch()
        expect("a directory named godot/godot", quiet(repo_off_home, a_directory, clean_home), 1)

        # Planted: a non-executable file where the binary should be.
        not_executable = root / "notexec"
        (not_executable / "godot" / "editor_data").mkdir(parents=True)
        (not_executable / "godot" / "godot").write_text("#!/bin/sh\n")
        (not_executable / "godot" / "godot").chmod(0o644)
        (not_executable / "godot" / "._sc_").touch()
        # Windows has no execute bit to take away: chmod leaves os.access
        # saying yes, so this case is held only where it can be planted.
        if not WINDOWS:
            expect("binary without the execute bit",
                   quiet(repo_off_home, not_executable, clean_home), 1)
        else:
            print("self-test note: the execute-bit case needs a POSIX host; skipped here")

        # Planted: no toolchain at all.
        expect("absent toolchain", quiet(repo_off_home, root / "nowhere", clean_home), 1)

        # Planted: the repository living on the small disk.
        repo_on_home = clean_home / "projects" / "game-ai-kit"
        repo_on_home.mkdir(parents=True)
        expect("repo under home", quiet(repo_on_home, good_toolchain, clean_home), 1)
        # On a CI runner the repository is always under home, and that alone
        # is not a finding -- but a leak there still is.
        expect("repo under home on a runner", quiet(repo_on_home, good_toolchain, clean_home, True), 0)
        expect("a leak on a runner", quiet(repo_on_home, good_toolchain, dirty_home, True), 1)

        user_dir_cases(root, good_toolchain, clean_home, repo_off_home, expect, said)

        # Usage errors must be exit 2, never confused with a finding.
        script = pathlib.Path(__file__).resolve()
        extra = subprocess.run(
            [sys.executable, str(script), "--unknown-flag"],
            capture_output=True,
        )
        expect("unknown flag", extra.returncode, 2)

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("--repo", default=None)
    parser.add_argument("--toolchain", default=None)
    parser.add_argument("--home", default=None)
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
    toolchain = pathlib.Path(
        args.toolchain or os.environ.get("GAK_TOOLCHAIN", DEFAULT_TOOLCHAIN)
    )
    home = pathlib.Path(args.home or pathlib.Path.home())

    try:
        return run(repo, toolchain, home, on_runner=os.environ.get("GITHUB_ACTIONS") == "true")
    except OSError as error:
        print(f"check_disk_layout: cannot read a path: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
