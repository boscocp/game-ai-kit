# T31 — Generate your own art, with a model on your own machine

Size: L · Prereqs: T9 · Files: `tools/artgen/`, `godot/assets/`, `docs/adr/`, `scripts/check_license.py`, `Makefile`

## Goal

T9 brings in CC0 art and promises "generated later". This is later. The kit
ships a way to **generate its art with a local image model**, so anyone who
wants a different look can produce one. The model is downloaded separately.

**Everyone who clones the repository generates their own art.** The
repository does not carry a generated art set. It carries:
- the CC0 art from T9, which is the default and what a fresh checkout
  shows;
- the generator, its manifest and its style presets;
- **a few generated examples**, enough to show what the generator makes and
  to keep the manifest honest.

A user's own generated art goes to a directory git ignores. When it is
there, the game uses it; when it is not, the game falls back to the CC0 set.

It is part of the kit and not part of any lesson. A reader who never
generates anything loses nothing: they get the CC0 art. That is the
same shape as invariant 6, where Python trains, GDScript only infers, and the
player never needs the trainer.

## Why it lives in this repository, and why it is fenced off

**In the repository**, because a PNG is only reproducible next to the prompt,
the seed and the model that made it, and the manifest that names every asset
the game needs is the game's own. In a separate repository, the two drift,
and a user regenerating one sprite in a new style no longer knows what the
game expects.

**Fenced off**, because generation breaks two promises the rest of the kit
keeps:
- **Python with the standard library only** (tier 1). Generation needs torch
  and a diffusion library.
- **No lesson above tier 1** (invariant 5). Generation needs a GPU.

So:
- `tools/artgen/` is not under `python/`. `make test-python` does not
  import it, and `make check` never runs it.
- Its Python environment and the model weights live on the large disk
  (invariant 8). Nothing goes in `$HOME`, and the weights are never
  committed.
- It is tier 3 in the README's table: optional, like a local LLM.

## Which model: researched, then measured

Researched on 2026-10-13 for the owner's machine: an RTX 5070 with 12 GB of
VRAM (Blackwell, compute 12.0), 30 GB of RAM, and 131 GB free on the large
disk. The licences were checked on each model's own page that day. The VRAM
figures are the pages' claims, and secondary sources disagree with them.

| model | licence (model page) | size | VRAM claim | for this kit |
|---|---|---|---|---|
| FLUX.2 [klein] 4B, with the `Limbicnation/pixel-art-lora` LoRA | Apache 2.0, and the LoRA Apache 2.0 | 4B, 4 steps | "~13 GB", over 12, so fp8 or offload | first candidate: 512x512 RGBA sprites with transparent backgrounds, built with Godot in mind; reference images help keep one style across a set |
| Z-Image-Turbo (Tongyi-MAI) | Apache 2.0 | 6B, 8 steps | "16G consumer devices", so fp8 or quantised | second candidate: strong illustration and prompt adherence; pixel-art LoRAs exist |
| Qwen-Image-2512 | Apache 2.0 | 20B, ~50 steps | not stated; GGUF Q4 only, and slow | the strongest open model overall by its authors' blind test; its strength (text in images) is not what sprites need |
| FLUX.2 dev, FLUX.2 [klein] 9B | non-commercial | | | excluded: the examples are published in the repository |
| SDXL | OpenRAIL++, with use restrictions | | 6-8 GB | fallback: lightest, most LoRAs, an older generation's quality |

Three caveats travel with the table:
- That the LoRA's training images are CC0 is its author's claim. The card
  gives two sizes for that dataset (500 and 1,010 images). Record it as a
  claim, not as checked.
- The model pages are the source for the licences. Recheck them when this
  task starts: a licence can change between versions.
- These models move fast. If this task starts months after 2026-10-13,
  redo the research before the bake-off.

**The choice is measured, not read.** The first step is a bake-off on the
owner's machine:
- the same five prompts the kit needs (a unit, a tower, a terrain tile, a
  checkers piece, the board);
- the two candidates, with peak VRAM and seconds per image recorded;
- the owner picks by eye.

The winner becomes the default, pinned by revision and SHA. The table, the
measurements and the pick go in the ADR.

## Steps

0. **The bake-off above**, with its numbers committed to the ADR.
1. **An ADR, with the trade-off written out**: in the repository and
   fenced, rather than a separate repository or no generator at all.
2. **`make artgen-bootstrap`** creates an isolated environment under the
   toolchain directory, pinned by a lock file. It downloads one default
   model, pinned by name, revision and SHA-256, the way `make bootstrap`
   pins Godot.
   - **The model's licence decides the default.** It must allow the
     generated images to be committed and redistributed. Record the licence
     and its URL.
   - A user may point at another model by editing one config file, and
     the tool writes that model down in the manifest.
3. **`tools/artgen/manifest.json`**: one entry per asset, with the
   destination path, prompt, negative prompt, seed, size, model and
   revision, and any post-processing (palette, background removal). The
   manifest is the source; the PNGs are its output.
4. **`make artgen`** regenerates every entry, or the ones named.
   **`make artgen STYLE=...`** swaps a style preset, a shared prompt suffix,
   so a whole new look is one command.
5. **Where the output goes, and what the game reads.**
   - `make artgen` writes to `godot/assets/generated/`, which git ignores.
   - The game reads art through the same `TileSet` and sprite paths T9 set
     up. For each asset, it uses the generated file when there is one and
     the CC0 file otherwise. Swapping art changes files, not code.
   - A test holds the fallback: with the generated directory empty, every
     asset the game needs resolves to a CC0 file.
6. **A few committed examples** in `godot/assets/generated-examples/`,
   chosen to show the range (a unit, a tile, a piece) and kept small. They
   are what the README shows, and the proof the manifest works.
7. **`check_license.py` gains a rule, with its planted case.** Every
   committed PNG under `godot/assets/generated-examples/` has a manifest
   entry naming its model and licence, and a PNG without one is a finding.
   The gate reads the manifest and never runs the model. A generated PNG
   committed outside that directory is also a finding, so one person's art
   set does not slip into everyone's checkout.
8. **`docs/howto/generate-art.md`**: the hardware it needs and how long a
   full run takes, measured on a named GPU and not guessed. Also how to
   restyle, how to add one asset, and what to do without a GPU (keep the
   CC0 art).

## Acceptance

```bash
make check
python3 scripts/check_license.py
test -f tools/artgen/manifest.json
```

```bash
# The fence holds: nothing outside tools/ imports the generator.
! grep -rn "artgen" python/ godot/addons/ godot/game/
```

`check_license.py`'s new rules are born with their planted cases: a committed
generated PNG with no manifest entry, and one committed outside the examples
directory.

## Manual check

On a machine with a GPU, follow `docs/howto/generate-art.md` from a clean
checkout, then regenerate the unit sprites in a different style preset:
- the game runs with them, unchanged in code;
- the five unit types can still be told apart at a glance;
- `git status` shows nothing new to commit.

Delete the generated directory, and the game is back on the CC0 art.
