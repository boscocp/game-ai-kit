# Run the kit on Windows

<!-- doc-meta
half_life: tool
verified_on: 2026-10-25
tier: 1
source: https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html ; https://github.com/godotengine/godot/blob/master/platform/windows/os_windows.cpp ; https://www.gnu.org/software/make/manual/html_node/Choosing-the-Shell.html
invalidated_if: Godot's Windows build stops reading APPDATA for user://, its release stops shipping a _console twin, or winget drops ezwinports.make
teaches: none
-->

> The kit was written on Linux, and every command in it is still a Makefile
> target run by bash. On Windows the same targets run from **Git Bash**, with
> GNU make for Windows. Nothing about the lessons changes.

## What it needs

- **Git for Windows**, which brings Git Bash, `curl`, `unzip` and `sha512sum`;
- **Python 3.12 or later** from python.org, on `PATH` as `python`. The
  `python3` Windows answers with is the Microsoft Store's placeholder: it
  exits 9009 and installs nothing, so the Makefile uses `python` there;
- **GNU make**, which Windows does not have. Install it on the large disk,
  beside the toolchain, from PowerShell:

  ```powershell
  winget install ezwinports.make --location D:\games\gamedev\toolchain\make
  ```

  and open a new Git Bash so `make` is on `PATH`.

Then, from Git Bash at the repository's root, the same three lines as on
Linux:

```bash
make bootstrap     # Godot, SHA-512 checked, into D:/games/gamedev/toolchain
make hooks
make check
```

`bootstrap` skips the 1.28 GB of export templates on Windows, since `make
export` is not ported there.

## What differs, and why

| | Linux | Windows |
|---|---|---|
| toolchain | `/mnt/games/gamedev/toolchain` | `D:/games/gamedev/toolchain` |
| Godot | `godot/godot` | `godot/godot_console.exe`, which starts `godot/godot.exe` |
| `user://` kept off the small disk by | `XDG_DATA_HOME` | `APPDATA` and `LOCALAPPDATA` |
| Python | `python3` | `python`, with `PYTHONUTF8=1` |

To put the toolchain elsewhere, on either system: `make bootstrap
TOOLCHAIN=E:/tc` installs it there, and `GAK_TOOLCHAIN=E:/tc` in the
environment is where `scripts/godot` and the gates then look for it. The
two are separate names, and both must say the same place.

**Two programs, not one.** The Windows release of Godot is a GUI program and
a `_console` twin that starts it with a console attached. Measured on 4.7.2
from Git Bash, both pass a script's output and its `quit(3)` back through a
pipe, so either would hold the gates. `scripts/godot` calls the twin all the
same: it is the one Godot documents for a terminal, and a windowed example
started from one keeps printing its log there.

**`APPDATA`, not `XDG_DATA_HOME`.** Self-contained mode (`._sc_`) keeps the
editor's own data beside the binary on both systems, and on neither does it
cover the project's `user://`. On Linux the engine finds that under
`XDG_DATA_HOME`; on Windows `OS_Windows::get_config_path` reads `APPDATA`, and
the cache `LOCALAPPDATA`. `scripts/godot` points both inside the checkout,
at its own `.user-data/` (ADR 0022: one directory per checkout, so two
worktrees never share a `user://`), written as `D:/...` by Git Bash's
`pwd -W` because `godot.exe` reads them as Windows paths (written on
Linux and not yet run on Windows: T83's manual check); and
`make lint-disk-layout` fails if `%APPDATA%\Godot` or `%LOCALAPPDATA%\Godot`
appears.

**`PYTHONUTF8=1`.** Python on Windows writes to the console in cp1252, and the
first gate whose output held a character outside it died with a
`UnicodeEncodeError`. UTF-8 mode makes it behave as it does on Linux.

## What does not work on Windows

- **`make test-rts-budget` fails on the author's desk under Windows.**
  Measured on 2026-10-25, idle, three runs: the RTS core's simulation took
  1.47 ms a step on average and its flow fields 1.85-2.00 ms at the 95th
  percentile, against a 1.5 ms share. The gate's own comment records 0.7 ms
  for the simulation on the same desk under Linux: the same core runs about
  twice as slow here. The share is a frame on the machine a person plays on,
  so this is a finding about Windows, not noise, and the gate is left to
  say so rather than loosened. **`make test-rts-match` fails the same
  way**: one plan took 7.9 ms against the strategy's 1.5 ms share; its other
  claims held. The project is developed on Linux, where both hold; Windows
  is for playing the examples.
- **Not run on Windows yet**: `test-botmatch-effects`, the four
  `test-racing3d-*` gates and the two infiltration gates. The full check
  runs on Linux.

- **`make export` and `make release`** build and start a *Linux* executable,
  the one platform the project exports to (T24). They are not ported.
- **`make artgen`** pins Linux wheels (see [generate-art](generate-art.md)).
- **The execute-bit case of `lint-disk-layout`'s self-test** is skipped:
  Windows has no execute bit to take away, and the run says so.
