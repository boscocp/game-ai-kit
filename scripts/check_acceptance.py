#!/usr/bin/env python3
"""Fail a task whose Acceptance section is not a command with an exit code.

The rule
--------
Invariant 3: every acceptance criterion is a command with an exit code. A game
is visual, and that is exactly where "looks like it works" turns into debt six
weeks later. Anything that needs a person to look at it belongs under
`## Manual check`, where nothing pretends to have an exit code.

What this catches
-----------------
  * an Acceptance section with no command block at all -- prose only;
  * a criterion whose real verdict is prose (`# no output`, "returns nothing");
  * a command that never returns, which hangs whoever runs the acceptance --
    here that means Godot invoked without `--headless`, or with `--editor`;
  * a command whose exit status carries no information about the assertion,
    notably a grep that matches a label while the assertion sits in its comment;
  * prose telling a human what to look at, which belongs under `## Manual check`;
  * acceptance that needs a local model, without the header saying so.

Why this gate exists
--------------------
The original of this script lives in another of the author's repositories, where
it was written after an audit found most acceptance blocks were not commands.
This port adds the `--self-test` the original lacks, and replaces its
domain-specific rules: the original guards against `adb logcat` hanging, which
here is a Godot window that never closes.

Exit codes
----------
0   every task's acceptance is executable
1   violations found (each one printed)
2   wrong usage, or no task files where they were expected

Usage
-----
    check_acceptance.py [--tasks PATH]
    check_acceptance.py --self-test
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

TASK_FILE_RE = re.compile(r"^(T\d+(?:\.\d+)?)-")
FENCE_RE = re.compile(r"```([a-z]*)\n(.*?)```", re.S)

# Only a fence tagged as a shell holds commands. A review found that changing
# ```bash to ```text disabled both halves of this gate at once: the content
# stopped being read as commands, and because prose is the body minus fences,
# it stopped being read as prose too. Untagged counts as shell.
SHELL_TAGS = {"", "bash", "sh", "shell", "console"}

# A criterion whose verdict is read by a person instead of by the shell.
PROSE_VERDICT = [
    (re.compile(r"#\s*no output", re.I), "prose verdict '# no output' -- use `! grep -q ...`"),
    (re.compile(r"#\s*expected:", re.I), "prose verdict '# expected:' -- assert it instead"),
    (re.compile(r"\breturns nothing\b", re.I), "prose verdict 'returns nothing' -- use `! grep -q ...`"),
    (re.compile(r"#\s*should (?:be|show|print)", re.I), "prose verdict '# should ...' -- assert it"),
]

# A Godot invocation, allowing for an interpreter and environment prefixes:
# `godot`, `./scripts/godot`, `bash scripts/godot`, `FOO=1 bash scripts/godot`.
# A review found the bare form missed all three.
GODOT_INVOCATION = re.compile(
    r"^(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*"       # env assignments
    r"(?:(?:bash|sh|exec|time)\s+)*"             # an interpreter, or none
    r"(?:\./)?(?:[\w./-]*/)?godot\b"
)
EDITOR_FLAG = re.compile(r"\s(?:--editor|-e)(?:\s|$)")

# Everything that turns a command's exit status into a constant. These are what
# a person writes when a criterion is inconvenient, which is exactly when the
# criterion matters.
SILENCERS = (
    ("|| true", "`|| true` discards the exit status the criterion is made of"),
    ("||true", "`||true` discards the exit status the criterion is made of"),
    ("|| :", "`|| :` discards the exit status the criterion is made of"),
    ("; true", "`; true` discards the exit status of the command before it"),
    ("set +e", "`set +e` stops the block failing at all"),
)


def split_commands(line: str) -> list[str]:
    """One shell line broken into the commands it actually runs.

    The whole line was the unit before, and a review showed what that costs:
    `godot --headless --version && godot --path godot -s x.gd` passed, because
    the first invocation's flag covered for the second. Each command is now
    judged on its own.
    """
    return [part.strip() for part in re.split(r"&&|\|\||[;|]", line) if part.strip()]


def non_terminating(commands: str) -> list[str]:
    """Commands that never return, and so hang whoever runs the acceptance.

    Godot without `--headless` opens a window and waits; `--editor` does the
    same even with it. Either one hangs CI and hangs a contributor.
    """
    problems = []
    for line in commands.splitlines():
        for command in split_commands(line):
            if not GODOT_INVOCATION.match(command):
                continue
            if "--headless" not in command:
                problems.append(
                    f"`{command[:48]}` invokes Godot without --headless; it opens a window "
                    "and never returns"
                )
            if EDITOR_FLAG.search(command):
                problems.append("`--editor` opens the editor and never returns")
    return problems


def silenced(commands: str) -> list[str]:
    """Criteria whose exit status was switched off."""
    problems = []
    for marker, message in SILENCERS:
        if marker in commands:
            problems.append(message)
    return problems

# A command whose exit status says nothing about the assertion.
ALWAYS_ZERO = [
    (
        # `... | grep -q "Compatibility"   # the renderer must be this` matches
        # the label whatever the value is. The assertion lives in the comment,
        # where the shell cannot reach it.
        # Matches grep at the start of a command as well as after a pipe: the
        # assertion hides in the comment either way.
        re.compile(
            r"(?:^|\|)\s*grep\b[^\n#]*#[^\n]*\b(?:names?|shows?|prints?|must|should|appears?)\b",
            re.I | re.M,
        ),
        "the grep matches a label while the assertion sits in its comment -- grep for the value",
    ),
    (
        re.compile(r"curl[^\n|]*-w[^\n|]*$", re.M),
        "`curl -w` prints the code but always exits 0 -- pipe it into `grep -qx`",
    ),
]

# Prose that tells a person what to look at. Not wrong, but it belongs under
# `## Manual check`.
HUMAN_VERDICT = re.compile(
    r"^\s*(?:Then[, ]+)?(?:Open|Confirm|Observe|Watch|Play|Look|Check that you)\b"
    r"|\blooks? (?:right|correct|fine)\b|\bby eye\b|\bvisibly\b|\bplausible\b"
    r"|\bthe unit (?:moves|attacks|retreats)\b(?![^\n]*exit)",
    re.M | re.I,
)

# Acceptance that cannot run on tier 1 or 2, and so needs declaring.
NEEDS_LOCAL_MODEL = re.compile(r"\bollama\b|localhost:11434|\bapi/chat\b")


def acceptance_section(text: str) -> str | None:
    """The body of the `## Acceptance` section, or None when there is none."""
    found = re.search(r"^##\s+Acceptance\s*$(.*?)(?=^##\s|\Z)", text, re.M | re.S)
    return found.group(1) if found else None


def check_file(path: pathlib.Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    problems: list[str] = []

    body = acceptance_section(text)
    if body is None:
        return [f"{path.name}: no `## Acceptance` section"]

    fences = FENCE_RE.findall(body)
    # An empty fence used to satisfy this: findall returned [""], which is
    # truthy, so the "prose only" branch never fired. The gate failed its own
    # question -- does this pass on an empty scene?
    command_blocks = [body_text for tag, body_text in fences
                      if tag in SHELL_TAGS and body_text.strip()]
    if not command_blocks:
        problems.append(f"{path.name}: Acceptance has no command block -- it is prose only")
    commands = "\n".join(command_blocks)

    # Prose is the body minus the *command* fences only. A ```text fence is
    # prose that happens to be indented, and is read as such.
    # `text` holds the whole file and is needed further down -- naming the loop
    # variable `text` here shadowed it, and the Requires: check then searched a
    # code fence instead of the file. The self-test caught it; the name stays
    # distinct.
    prose_source = body
    for tag, fence_body in fences:
        if tag in SHELL_TAGS:
            prose_source = prose_source.replace(fence_body, "")
    # Inline `code` spans are dropped so a task may quote the wrong way of
    # writing a criterion while explaining why it is wrong.
    prose = re.sub(r"`[^`]*`", "", prose_source)

    # A human verdict hides just as well in a trailing comment inside the fence.
    for line in commands.splitlines():
        comment = line.split("#", 1)
        if len(comment) == 2:
            prose += "\n" + comment[1]

    for pattern, message in PROSE_VERDICT:
        if pattern.search(commands) or pattern.search(prose):
            problems.append(f"{path.name}: {message}")
    for pattern, message in ALWAYS_ZERO:
        if pattern.search(commands):
            problems.append(f"{path.name}: {message}")
    for message in non_terminating(commands) + silenced(commands):
        problems.append(f"{path.name}: {message}")

    looking = HUMAN_VERDICT.search(prose)
    if looking:
        problems.append(
            f"{path.name}: Acceptance asks a person to look ({looking.group(0).strip()!r}) "
            "-- move it to `## Manual check`"
        )

    if NEEDS_LOCAL_MODEL.search(commands) and not re.search(
        r"^Requires:.*\blocal model\b", text, re.M | re.I
    ):
        problems.append(
            f"{path.name}: acceptance needs a local model but the header has no "
            "`Requires: a local model`"
        )

    return problems


def run(tasks: pathlib.Path) -> int:
    files = sorted(p for p in tasks.glob("*.md") if TASK_FILE_RE.match(p.name))
    if not files:
        print(f"A0 no task files in {tasks} -- this gate would pass on an empty tree")
        return 1

    problems = [problem for path in files for problem in check_file(path)]
    for problem in problems:
        print(f"  {problem}")
    if problems:
        print(f"check_acceptance: {len(problems)} problem(s) in {len(files)} task files")
        return 1
    print(f"check_acceptance: ok -- {len(files)} task files")
    return 0


# --- self-test -------------------------------------------------------------


GOOD_TASK = """\
# T3 - A* over the grid

Size: M - Prereqs: T2 - Files: `godot/addons/ai_search/`

## Goal

Four search algorithms over GridGraph.

## Acceptance

```bash
make test-godot
python3 scripts/check_readability.py
```

## Manual check

Open the demo and confirm A* expands visibly fewer nodes than Dijkstra.
"""


def self_test() -> int:
    failures = []

    def expect(label: str, got: int, want: int) -> None:
        if got != want:
            failures.append(f"{label}: expected exit {want}, got {got}")

    def quiet(tasks: pathlib.Path) -> int:
        with contextlib.redirect_stdout(io.StringIO()):
            return run(tasks)

    def tasks_with(root: pathlib.Path, name: str, text: str) -> pathlib.Path:
        folder = root / name
        folder.mkdir(parents=True)
        (folder / "T3-search.md").write_text(text)
        return folder

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)

        expect("executable acceptance", quiet(tasks_with(root, "good", GOOD_TASK)), 0)

        # Planted: no task files at all. An empty tree must not pass.
        empty = root / "empty"
        empty.mkdir()
        expect("no task files", quiet(empty), 1)

        # Planted: no Acceptance section.
        expect("no Acceptance section",
               quiet(tasks_with(root, "nosection", "# T3 - x\n\n## Goal\n\nSomething.\n")), 1)

        # Planted: acceptance that is prose with no command block.
        prose_only = GOOD_TASK.replace(
            "```bash\nmake test-godot\npython3 scripts/check_readability.py\n```",
            "The tests pass and the code is readable.",
        )
        expect("prose-only acceptance", quiet(tasks_with(root, "prose", prose_only)), 1)

        # Planted: a prose verdict inside the command block.
        no_output = GOOD_TASK.replace("make test-godot",
                                      "grep -r TODO godot/addons/   # no output")
        expect("prose verdict in a command", quiet(tasks_with(root, "nooutput", no_output)), 1)

        # Planted: Godot without --headless, which opens a window and hangs.
        hangs = GOOD_TASK.replace("make test-godot", "./scripts/godot --path godot --quit")
        expect("Godot without --headless", quiet(tasks_with(root, "hangs", hangs)), 1)

        # The same command with --headless is fine.
        fine = GOOD_TASK.replace("make test-godot",
                                 "./scripts/godot --headless --path godot -s res://x.gd")
        expect("Godot with --headless", quiet(tasks_with(root, "fine", fine)), 0)

        # Planted: a grep whose assertion lives in its comment.
        label_grep = GOOD_TASK.replace(
            "make test-godot",
            'grep -q "rendering_method" godot/project.godot   # must show Compatibility',
        )
        expect("assertion in a comment", quiet(tasks_with(root, "labelgrep", label_grep)), 1)

        # Planted: a human verdict in the Acceptance prose rather than below it.
        looking = GOOD_TASK.replace(
            "## Acceptance\n\n```bash",
            "## Acceptance\n\nOpen the demo and confirm it looks right.\n\n```bash",
        )
        expect("human verdict in Acceptance", quiet(tasks_with(root, "looking", looking)), 1)

        # The same sentence under `## Manual check` is exactly where it belongs,
        # and GOOD_TASK already proves that passes.

        # Planted: acceptance needing a local model without declaring it.
        needs_model = GOOD_TASK.replace(
            "make test-godot", "curl -sS localhost:11434/api/chat -d @fixtures/llm/ask.json | grep -q ok"
        )
        expect("undeclared local model", quiet(tasks_with(root, "model", needs_model)), 1)

        # Declared in the header, the same acceptance is fine.
        declared = needs_model.replace(
            "Size: M - Prereqs: T2 - Files: `godot/addons/ai_search/`",
            "Size: M - Prereqs: T2 - Files: `godot/addons/ai_llm/`\nRequires: a local model",
        )
        expect("declared local model", quiet(tasks_with(root, "declared", declared)), 0)

        # A task may quote a bad criterion inside backticks while explaining it.
        quoting = GOOD_TASK.replace(
            "Four search algorithms over GridGraph.",
            "Four search algorithms. Do not write `# no output` as a criterion.",
        )
        expect("bad criterion quoted in prose", quiet(tasks_with(root, "quoting", quoting)), 0)

        # Planted: `curl -w`, which prints a status code and always exits 0.
        # Mutation showed deleting this rule left the self-test green.
        curl_w = GOOD_TASK.replace(
            "make test-godot", 'curl -sS -o /dev/null -w "%{http_code}" http://localhost:8000/')
        expect("curl -w always exits 0", quiet(tasks_with(root, "curlw", curl_w)), 1)

        # --- cases from a fresh-context review of this gate ------------------

        # Planted: an empty fence. findall returned [""], which is truthy, so
        # the "prose only" branch never fired. The gate failed its own question.
        empty_fence = GOOD_TASK.replace(
            "make test-godot\npython3 scripts/check_readability.py", "")
        expect("empty code fence", quiet(tasks_with(root, "emptyfence", empty_fence)), 1)

        # Planted: ```text instead of ```bash. This used to disable both halves
        # at once -- not commands, and not prose either.
        text_fence = GOOD_TASK.replace(
            "```bash\nmake test-godot\npython3 scripts/check_readability.py\n```",
            "```text\nThe tests pass and the demo looks right.\n```")
        expect("prose inside a text fence", quiet(tasks_with(root, "textfence", text_fence)), 1)

        # Planted: two invocations on one line, the first one's flag covering
        # for the second. The whole line used to be the unit.
        covered = GOOD_TASK.replace(
            "make test-godot",
            "./scripts/godot --headless --version && ./scripts/godot --path godot -s res://x.gd")
        expect("second invocation uncovered", quiet(tasks_with(root, "covered", covered)), 1)

        # Planted: an interpreter prefix, which the bare pattern missed.
        via_bash = GOOD_TASK.replace("make test-godot", "bash scripts/godot --path godot")
        expect("bash scripts/godot", quiet(tasks_with(root, "viabash", via_bash)), 1)

        # Planted: an environment prefix as well.
        with_env = GOOD_TASK.replace(
            "make test-godot", "GAK_TOOLCHAIN=/tmp/tc bash scripts/godot --path godot")
        expect("env prefix", quiet(tasks_with(root, "withenv", with_env)), 1)

        # Planted: the exit status switched off. This is what a person writes
        # when a criterion is inconvenient, which is when it matters most.
        for label, suffix in (
            ("|| true", "make test-godot || true"),
            ("; true", "python3 scripts/check_readability.py; true"),
            ("set +e", "set +e\nmake check"),
        ):
            silenced_task = GOOD_TASK.replace("make test-godot", suffix)
            expect(f"silenced with {label}",
                   quiet(tasks_with(root, f"silenced-{label.replace(' ', '')}", silenced_task)), 1)

        # Planted: a human verdict as a trailing comment inside the fence, where
        # the prose check never looked.
        in_fence = GOOD_TASK.replace(
            "make test-godot",
            "make test-godot   # then watch the unit attack and confirm it looks right")
        expect("human verdict in a fence comment", quiet(tasks_with(root, "infence", in_fence)), 1)

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
    parser.add_argument("--tasks", default=None)
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

    tasks = pathlib.Path(args.tasks or pathlib.Path(__file__).resolve().parent.parent / "tasks")
    if not tasks.is_dir():
        print(f"check_acceptance: no such directory: {tasks}", file=sys.stderr)
        return 2

    try:
        return run(tasks)
    except OSError as error:
        print(f"check_acceptance: cannot read a file: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
