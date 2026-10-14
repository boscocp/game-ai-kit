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

- `tools/artgen/` is outside `python/`; `make check` never runs it, and
  nothing in `python/`, `godot/addons/` or `godot/game/` names it.
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

**Asking for "32x32" or "64x64" changed nothing.** On klein, the median run
of one colour -- the size of a fake pixel -- was the same with and without it
(8.4, 16.7, 13.6, 6.2 against 8.3, 18.1, 13.7, 6.2 for four of the pictures).
The size is the post-processing's.

**Walking is a task of its own (T33).** Twelve frames from a general model
failed both ways: one sheet drew twelve soldiers in random poses, and twelve
frames each given the one before drew near-copies with growing noise. Three
frames per direction at 32 pixels worked, with a LoRA made for it on klein's
undistilled base; the owner judged it good enough to go on with.

## Consequences

- A fresh checkout loses nothing: no GPU, no download, the CC0 art.
- `make artgen-bootstrap` costs about 24 GB for packages and klein, 33 GB
  more for Z-Image, all on the large disk.
- Generated pictures still have flaws a person sees and no gate does: the
  grass tile draws its own dark border, and the watchtower came out thin.
  They are a person's own, regenerated with another seed or style.
- The examples are Apache-2.0 model output, credited in `NOTICE`; the
  licence rules (L18-L23) hold that every committed generated picture is a
  named example in its folder, unchanged, with its model credited.
