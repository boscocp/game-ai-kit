# T31 — Generate your own art, with a model on your own machine

Size: L · Prereqs: T9 · Files: `tools/artgen/`, `godot/assets/`, `docs/adr/`, `docs/howto/`, `scripts/check_license.py`, `scripts/check_disk_layout.py`, `scripts/artgen`, `Makefile`, `NOTICE`

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
  (invariant 8), and the weights are never committed. **That does not hold
  by itself.**
  - pip, Hugging Face and torch all cache under `~/.cache` by default. That
    is the same trap as Godot's `user://`, which needed `XDG_DATA_HOME`.
  - So the generator is only ever invoked through `scripts/artgen`, a
    wrapper like `scripts/godot`. It sets `HF_HOME`, `PIP_CACHE_DIR`,
    `TORCH_HOME` and `XDG_CACHE_HOME` to the toolchain directory.
  - `check_disk_layout.py` gains those paths, with a planted case: a model
    cache under `$HOME` is a finding.
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

**The owner chose FLUX.2 [klein] 4B with the pixel-art LoRA** as the default
(2026-10-13), after reading the table above. What is left to measure is
whether it fits. The first step, on the owner's machine:
- generate the same five prompts the kit needs (a unit, a tower, a terrain
  tile, a checkers piece, the board) with klein 4B and the LoRA;
- record peak VRAM and seconds per image, in fp8 and with CPU offload,
  since the page's own "~13 GB" is over the card's 12.
- **a 12-frame walk cycle of one unit** (added by the owner on 2026-10-14,
  from a designer's advice: frame-to-frame consistency is where general
  image models fail most, and a low pixel density may hide it). Two ways,
  both recorded: one image asking for the whole sheet, and twelve images each
  given the previous frame as a reference. The owner judges the strip and a
  looping GIF; no command can. Nothing in the kit animates units yet, so this
  is evidence for the ADR, not a feature. If it is good, animating units is
  a task of its own.

**Z-Image-Turbo is the reserve**, the owner's choice too. Fall back to it if
neither setting fits in 12 GB, or if the owner looks at the five sprites and
judges them poor. Run the same five prompts on it, and say in the ADR which
was taken and why. Otherwise klein 4B is the default,
pinned by revision and SHA. The table, the measurements and the choice go in
the ADR.

## Steps

0. **The measurement above**: klein 4B fits in 12 GB, or the fallback is
   taken. The numbers go in the ADR.
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
   - `make artgen` writes to `godot/assets/generated/`, which git ignores,
     then runs `./scripts/godot --headless --path godot --import`. Godot
     does not `load()` a PNG it has not imported.
   - An exported build (T24) carries what is in the project when it is
     exported. A user's generated art ships in *their* export, and the
     kit's release carries the CC0 art. Say so in the how-to.
   - The game reads art through the same `TileSet` and sprite paths T9 set
     up. For each asset, it uses the generated file when there is one and
     the CC0 file otherwise. Swapping art changes files, not code.
   - A test holds the fallback: with the generated directory empty, every
     asset the game needs resolves to a CC0 file.
6. **A few committed examples** in `godot/assets/generated-examples/`,
   chosen to show the range (a unit, a tile, a piece) and kept small. They
   are what the README shows, and the proof the manifest works.
7. **`check_license.py` gains rules, each with its planted case.** They read
   tracked files only (`git ls-files`): a user's gitignored generated
   directory is not the repository's business, and a rule that read the
   disk would fire on it.
   - **Every committed PNG is accounted for**: listed by file in T9's
     `LICENCES.md` (CC0) or in the manifest (generated). That is what makes
     the next rule decidable. A stray PNG outside both looks the same
     whatever made it, and is a finding either way.
   - **A manifest entry's PNG lives in `godot/assets/generated-examples/`.**
     A generated file committed anywhere else is a finding, so one person's
     art set does not slip into everyone's checkout.
   - **The committed examples carry their model and its licence in
     `NOTICE`** (invariant 9).

   The gate reads the manifest and never runs the model.
8. **`docs/howto/generate-art.md`**: the hardware it needs and how long a
   full run takes, measured on a named GPU and not guessed. Also how to
   restyle, how to add one asset, and what to do without a GPU (keep the
   CC0 art).

## Acceptance

```bash
make check
make lint-selftests
python3 scripts/check_license.py
python3 scripts/check_disk_layout.py
```

```bash
# The fence holds in both directions: nothing in the kit's code mentions the
# generator, and no gate `make check` runs reaches it.
test -n "$(ls python/ godot/addons/ godot/game/)"
! grep -rn "artgen" python/ godot/addons/ godot/game/
! make -n check | grep -q "artgen"
```

The suite must include:
- **The fallback.** With the generated directory empty, every asset in the
  manifest resolves to a CC0 file, and the game loads.
- **The planted cases**, one for each new rule:
  - a committed PNG listed in neither `LICENCES.md` nor the manifest;
  - a generated PNG outside the examples directory;
  - an example missing from `NOTICE`;
  - a model cache under `$HOME`.

## Manual check

On a machine with a GPU, follow `docs/howto/generate-art.md` from a clean
checkout, then regenerate the unit sprites in a different style preset:
- the game runs with them, unchanged in code;
- the five unit types can still be told apart at a glance;
- `git status` shows nothing new to commit.

Delete the generated directory, and the game is back on the CC0 art.
