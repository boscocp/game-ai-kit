# 0013 — The art generator lives here, fenced, and runs Z-Image-Turbo

Status: accepted · 2026-10-14 (decided in T31)

## Context

ADR 0012 committed CC0 art and deferred generated art to T31. T31 asks for
a way to generate the game's pictures with a local image model, so that a
person who wants a different look can make one, without any lesson needing
a GPU. The owner's machine: an RTX 5070 with 12 GB of VRAM, 30 GB of RAM,
Python 3.14.

Three ways to have it: no generator; a generator in a repository of its
own; or one here, fenced off from everything the lessons touch.

## Decision

**Here, fenced.** A picture is only reproducible beside its prompt, seed and
model, and the list of pictures the game needs is the game's own
(`godot/game/art.gd`). In a separate repository the two drift. Fenced,
because generation breaks two promises the rest of the kit keeps -- Python
with the standard library only, and no lesson above tier 1:

- `tools/artgen/` is outside `python/`, and nothing in `python/`,
  `godot/addons/` or `godot/game/` names it. `make check` never runs the
  generator; it does *read* the generator's manifest, twice -- the licence
  gate checks the committed examples against it, and a test checks it names
  exactly the pictures `Art` draws.
- It runs only through `scripts/artgen`, which points pip, Hugging Face,
  torch, Triton and the CUDA kernel cache at the toolchain directory on the
  large disk. Measured: after installing 63 packages (7 GB) and fetching 55 GB of
  weights, nothing new appeared under `$HOME`, and `~/.cache/pip` and `~/.nv`
  kept their old timestamps. `check_disk_layout.py` fails on a model cache
  under `$HOME`.
- Packages install from `requirements.lock`, every one pinned by sha256;
  models from `model.json`, by revision and by the sha256 of each weight.
- A person's pictures go to `godot/assets/generated/`, gitignored, which
  `Art` prefers when a file is there. Three examples are committed, under
  `godot/assets/generated-examples/`, each named in the manifest with its
  model, seed and sha256, and the model in `NOTICE`.

**The default model is Z-Image-Turbo** (Tongyi-MAI, Apache-2.0), chosen by
the owner after the same seven prompts on it and on FLUX.2 [klein] 4B with a
pixel-art LoRA, both Apache-2.0. Z-Image drew cleaner, flatter pictures that
read at 32 pixels; klein drew more detailed, illustrated ones. Klein stays in
`model.json`, one word away.

## What was measured, on the owner's machine, 2026-10-14

| | FLUX.2 klein 4B + LoRA | Z-Image-Turbo |
|---|---|---|
| download | 16 GB + 0.3 GB | 33 GB (transformer published in fp32) |
| settings | 512 px, 4 steps, guidance 1 | 1024 px, 9 steps, guidance 0 |
| fits 12 GB by | bfloat16 + model offload | fp8 storage + model offload |
| peak VRAM | 8.4 GB | 8.3 GB |
| a picture, warm | 3-4 s | 13.5 s |
| the 30 pictures | 2 min 15 s | about 8 min |

**Z-Image in bfloat16 does not fit.** Its transformer alone is about 12.3 GB;
model offload ran out of memory. Group offload with streams sat at 0% GPU for
seven minutes and was stopped. fp8 storage, computing in bfloat16, worked; a
documentation page warns fp8 costs Turbo some quality, and that was not
compared here.

**The LoRA's weight is 0.125, not 1.0.** It is rsLoRA (rank 64, alpha 128),
which diffusers scales by alpha/√rank = 16; its card's "strength 0.85-1.4" is
ComfyUI's, which scales by alpha/rank = 2. At 1.0 the output was black noise,
at 0.25 a blur, at 0.125 a clean sprite.

**The first set was ugly, and the owner said so.** What fixed it, each from
a source found in research and then measured:
- a style written as sentences, not keywords, shared by every picture: the
  keyword prompts mixed near-photographic trucks with tiny painted soldiers;
- each side's colour as a hex code tied to a part of the object;
- not "transparent background", which the model paints as the grey
  checkerboard that stands for transparency; not magenta, which came out
  crimson beside the red team; flat green, removed by the colour of each
  picture's own border where it joins the border, plus anything very near it
  enclosed by the object;
- one colour per cell, the most common, instead of an average: averaging
  turned edges to mud;
- the two sides of a kind sharing a seed, so they are one design in two
  colours.

**Asking for "32x32" or "64x64" did not make the pixels bigger.** On klein,
the median run of one colour -- the size of a fake pixel, in a 512-pixel
frame -- for the seven pictures:

| prompt | truck | shield | mortar | tower | trees | checker | X |
|---|---|---|---|---|---|---|---|
| no size | 8.4 | 16.7 | 13.6 | 6.2 | 46.5 | 18.7 | 30.1 |
| "32x32" | 8.3 | 18.1 | 13.7 | 6.2 | 41.3 | 17.0 | 23.0 |
| "64x64" | 8.3 | 15.1 | 15.3 | 6.2 | 46.3 | 17.1 | 23.0 |

Five barely move; the X shrank by a quarter with either size, the opposite of
what asking for big pixels should do, and the two sizes gave the same. The
pictures looked alike. Z-Image was not measured: that run was lost to a power
cut. The size comes from the post-processing.

**Walking is a task of its own (T33).** Twelve frames from a general model
failed both ways: one sheet drew twelve soldiers in random poses, and twelve
frames each given the one before drew near-copies with growing noise. Three
frames per direction at 32 pixels worked, with a LoRA made for it on klein's
undistilled base; the owner judged it good enough to go on with.

## Consequences

- A fresh checkout loses nothing: no GPU, no download, the CC0 art.
- `make artgen-bootstrap` costs about 40 GB on the large disk: 7 GB of
  packages and 33 GB of Z-Image. Klein, fetched only when asked for, is
  16 GB more.
- The lock pins wheels for CPython 3.14 on x86_64 Linux, and bootstrap
  refuses another Python rather than half install.
- Generated pictures still have flaws a person sees and no gate does: the
  grass tile draws its own dark border, and the watchtower came out thin.
  They are a person's own, regenerated with another seed or style.
- The examples are Apache-2.0 model output, credited in `NOTICE`. What the
  licence rules (L16, L18-L24) hold: every file in the examples folder is a
  named example, unchanged, made by a model `model.json` pins at that
  revision under an allowed licence, credited in `NOTICE` on one line; and
  the manifest names no example elsewhere. What they cannot hold: a
  generated picture committed outside that folder *and* entered in
  `LICENCES.md` as a pack's, with its sha256. A PNG does not say what made
  it; that row would be a false statement by a person, which is review's to
  catch.
- The numbers above came from probe scripts run beside the toolchain, not
  from a committed command: `generate.py measure` reproduces the per-picture
  times and peaks, not the walk or the size probes, and two of the probes
  were lost to a power cut. T33 brings walking into the generator.
- The pixel-art LoRA's card says its training images are CC0. That is a
  claim, with two sizes given for the dataset (500 and 1,010), and was not
  checked; it no longer matters for the default, which uses no LoRA.
