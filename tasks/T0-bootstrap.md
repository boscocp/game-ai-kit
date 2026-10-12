# T0 — Bootstrap: the pinned toolchain on the large disk

Size: M · Prereqs: none · Files: `scripts/bootstrap.sh`, `scripts/godot`, `.godot-version`

## Goal

A pinned, SHA-verified Godot installed on the large disk, with nothing of the
toolchain reaching `$HOME`, and a single wrapper that is the only way this repo
invokes the engine.

## Steps

1. Download the Godot named in `.godot-version`, verify its SHA-512 against the
   release's `SHA512-SUMS.txt`, and install under `$GAK_TOOLCHAIN`.
2. Enable self-contained mode with an empty `._sc_` beside the binary.
3. Point `XDG_DATA_HOME` at the toolchain in `scripts/godot`, because
   self-contained mode does not cover the project's `user://` directory.
4. Install gdUnit4, pinned by tag and SHA-256.

## Acceptance

```bash
make bootstrap
make godot-version
python3 scripts/check_disk_layout.py
./scripts/godot --headless --version
```

Then, proving the wrapper refuses a mismatch rather than trusting the pin:

```bash
cp .godot-version /tmp/pin.bak && echo "4.6-stable" > .godot-version
! ./scripts/godot --headless --version
cp /tmp/pin.bak .godot-version
```

## Manual check

None. Every criterion above is a command.
