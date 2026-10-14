# Generate your own art

<!-- doc-meta
half_life: tool
verified_on: 2026-10-14
tier: 3
source: https://huggingface.co/Tongyi-MAI/Z-Image-Turbo ; https://huggingface.co/black-forest-labs/FLUX.2-klein-4B ; https://huggingface.co/Limbicnation/pixel-art-lora ; https://huggingface.co/docs/diffusers/main/en/api/pipelines/z_image
invalidated_if: a model in tools/artgen/model.json is re-published, diffusers renames a pipeline, or a run's time or VRAM on the named GPU moves by more than a third
teaches: none
-->

> Optional, and fenced off from every lesson. Without a GPU, keep the CC0 art
> the repository ships: the game loses nothing. Why it is built this way is
> [ADR 0013](../adr/0013-the-art-generator-and-its-model.md).

## What it needs

Measured on an RTX 5070 (12 GB, Blackwell), 30 GB of RAM, Python 3.14:

- **an NVIDIA GPU with 12 GB of VRAM.** The default model peaked at 8.3 GB;
- **CPython 3.14 on x86_64 Linux**: the lock pins wheels for it, and
  bootstrap refuses another;
- **about 40 GB on the large disk**: 7 GB of packages and 33 GB for the
  default model, 16 GB more for the other. Nothing goes to `$HOME`;
- **a first run of about 7 minutes** to install and download, more on a slow
  line.

## Making the art

```bash
make artgen-bootstrap     # once: the environment and the default model, verified by sha256
make artgen               # every picture the game draws, into godot/assets/generated/
make demo-tactical        # the game, drawn with them
make artgen-clean         # back to the CC0 art
```

`make artgen` took about 8 minutes for the 30 pictures with Z-Image-Turbo,
13.5 s a picture after the first. Its output is gitignored and is yours:
`git status` shows nothing new. Beside the pictures, `made-by.json` records
the model, style, seed and prompt behind each one.

## Changing the look

- **A style**: `make artgen STYLE=toy`. A style is a shared prefix in
  `tools/artgen/manifest.json`, written as sentences. Add your own beside
  `pixel` and `toy`.
- **One picture**: `make artgen ONLY="units/red/ram.png units/blue/ram.png"`.
  A kind's red and blue pictures share a seed; change both together.
- **A different seed** for a picture you dislike: edit its `seed` in the
  manifest and regenerate it.
- **The other model**: `make artgen MODEL=klein` (fetch it first with
  `scripts/artgen bootstrap klein`). Faster, more detailed, less legible at
  32 pixels.

## Adding a picture the game does not have yet

1. Give it a path in `godot/game/art.gd`.
2. Give it an entry in the manifest: its path, `sprite` (on a background to
   remove) or `tile` (fills the square), a prompt in sentences, a seed, its
   size in pixels and its number of colours.
3. Commit a CC0 picture at that path too, listed in `godot/assets/LICENCES.md`,
   so that a checkout without a GPU still draws something. A test fails if
   the manifest and the art table name different pictures.

## When a picture comes out wrong

- **A grey checkerboard round the object**: a prompt asked for a transparent
  background. Ask for flat green; the generator removes it.
- **"opaque pixels ... after its background was removed"**: a green object
  on the green background cleared to nothing, and the picture was not saved.
  Give its entry `"background": "pure magenta (#FF00FF)"`, as the trees have.
- **Black noise**: a LoRA at full weight. The pixel-art LoRA's weight is
  0.125 in `model.json`, for reasons the ADR gives.
- **The game shows the old picture**: Godot draws only imported pictures.
  `make artgen` imports; after copying files by hand, run `make import`.
- **`make import` refuses with "marked invalid"**: a picture failed to import
  and poisoned its `.import` file. Delete the sidecar, fix the picture, and
  import again.
