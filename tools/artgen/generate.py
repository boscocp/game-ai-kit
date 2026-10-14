"""Generate the game's pictures with a local image model (T31).

Not part of any lesson, and fenced off from them: it needs torch and a GPU,
it lives outside `python/`, and `make check` never runs it. A reader who never
generates anything keeps the CC0 art. Run it only through `scripts/artgen`,
which keeps every cache on the large disk.

Two commands:

    make    [--model NAME] [--style NAME] [--only PATH ...]
            Generate the pictures `manifest.json` names into
            godot/assets/generated/, which git ignores and the game prefers.
    measure OUT_DIR [--model NAME]
            Four pictures the kit needs and a whole board, each with its
            seconds and peak VRAM, in OUT_DIR/report.json beside them: how a
            model was judged against another.

Every model is one `model.json` pins, loaded in bfloat16 with model CPU
offload, which keeps only the part running on the GPU: a text encoder of
about 8 GB and a transformer of 8 to 12 GB fit a 12 GB card one at a time and
not together. A model marked `fp8` stores its transformer's weights in 8-bit
floats and computes in bfloat16.

Exit codes: 0 done, 1 a generation failed, 2 wrong usage.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
import pathlib
import sys
import time

import diffusers
import torch
from huggingface_hub import snapshot_download
from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
ASSETS = REPO / "godot" / "assets"
GENERATED = ASSETS / "generated"
# How far a background pixel may stray from the border's colour and still be
# background: the sum of the three channels' differences, out of 765. Measured
# on the 2026-10-14 bake-off, where the asked-for green came out in shades.
BACKGROUND_DISTANCE = 110
# The same, for background enclosed by the object, which only its colour can
# identify: tight enough that the trees' dark green is never taken for it.
ENCLOSED_DISTANCE = 60


# --- the model ---------------------------------------------------------------

def model_config(name: str | None) -> tuple[str, dict]:
    """A model's name and its entry in model.json; the default when none is named."""
    config = json.loads((HERE / "model.json").read_text(encoding="utf-8"))
    chosen = name or config["default"]
    if chosen not in config["models"]:
        raise KeyError(f"no model {chosen!r}; model.json has {', '.join(config['models'])}")
    return chosen, config["models"][chosen]


def load_pipeline(model: dict) -> diffusers.DiffusionPipeline:
    """A pinned model, with its LoRA if it has one, ready to run with offload."""
    folder = snapshot_download(model["repo"], revision=model["revision"], allow_patterns=model["fetch"])
    pipe = getattr(diffusers, model["pipeline"]).from_pretrained(folder, dtype=torch.bfloat16)
    if "lora" in model:
        lora = model["lora"]
        lora_folder = snapshot_download(lora["repo"], revision=lora["revision"], allow_patterns=lora["fetch"])
        pipe.load_lora_weights(lora_folder, weight_name=lora["weights"], adapter_name="style")
        pipe.set_adapters(["style"], adapter_weights=[lora["scale"]])
    if model["fp8"]:
        pipe.transformer.enable_layerwise_casting(storage_dtype=torch.float8_e4m3fn,
                                                  compute_dtype=torch.bfloat16)
    pipe.enable_model_cpu_offload()
    return pipe


def made_by(model: dict) -> str:
    """What made a picture, as the manifest and NOTICE record it."""
    names = [f"{model['repo']}@{model['revision']}"]
    if "lora" in model:
        names.append(f"{model['lora']['repo']}@{model['lora']['revision']}")
    return " + ".join(names)


def run_model(pipe: diffusers.DiffusionPipeline, prompt: str, seed: int, settings: dict,
              size: tuple[int, int] = (0, 0)) -> Image.Image:
    """One picture from one prompt and one seed. Same seed, same picture."""
    width, height = size if size != (0, 0) else (settings["size"], settings["size"])
    return pipe(prompt=prompt, num_inference_steps=settings["steps"], guidance_scale=settings["guidance"],
                width=width, height=height, generator=torch.Generator("cpu").manual_seed(seed)).images[0]


# --- turning a generated picture into a game's ---------------------------------

def clear_background(picture: Image.Image) -> Image.Image:
    """Make the background transparent: the border's colour, where it joins the border.

    The model paints a background even when asked for a transparent one -- it
    drew the grey checkerboard that stands for transparency -- so the prompt
    asks for flat green instead. Not flat in fact: each picture's green differs
    and shades across the frame. So the key is read from each picture's own
    border, and a pixel is background only if it is near that key *and*
    connected to the edge. A global colour key would punch holes in anything
    green inside the object; a flood from one corner's exact colour stops at
    the first shade.
    """
    rgb = picture.convert("RGB")
    width, height = rgb.size
    pixels = rgb.load()
    key = border_colour(rgb)
    reached = bytearray(width * height)
    frontier = [(x, y) for x in range(width) for y in (0, height - 1)]
    frontier += [(x, y) for y in range(height) for x in (0, width - 1)]
    while frontier:
        x, y = frontier.pop()
        if not (0 <= x < width and 0 <= y < height) or reached[y * width + x]:
            continue
        if sum(abs(channel - wanted) for channel, wanted in zip(pixels[x, y], key)) >= BACKGROUND_DISTANCE:
            continue
        reached[y * width + x] = 1
        frontier += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    enclosed = enclosed_background(rgb, key)
    background = bytes(edge or inside for edge, inside in zip(reached, enclosed))
    result = rgb.convert("RGBA")
    result.putalpha(Image.frombytes("L", (width, height), bytes(0 if flag else 255 for flag in background)))
    return result


def enclosed_background(rgb: Image.Image, key: tuple[int, int, int]) -> bytearray:
    """Background the border cannot reach: the inside of an O, the gap in a tower.

    Only pixels much nearer the key than `BACKGROUND_DISTANCE` count, because
    nothing connects them to the edge to say they are background. Measured:
    the first Z-Image set kept a green disc inside its O.
    """
    return bytearray(1 if sum(abs(channel - wanted) for channel, wanted in zip(pixel, key)) < ENCLOSED_DISTANCE
                     else 0 for pixel in rgb.get_flattened_data())


def border_colour(rgb: Image.Image) -> tuple[int, int, int]:
    """The median colour of a picture's outermost pixels: its background, nearly always."""
    width, height = rgb.size
    edge = [rgb.getpixel((x, y)) for x in range(width) for y in (0, height - 1)]
    edge += [rgb.getpixel((x, y)) for y in range(height) for x in (0, width - 1)]
    return tuple(sorted(colour[channel] for colour in edge)[len(edge) // 2] for channel in range(3))


def reduce(picture: Image.Image, pixels: int, colours: int) -> Image.Image:
    """Down to `pixels` square, one colour per cell: real pixel art from fake.

    A diffusion model's "pixels" are blocks of different sizes on no grid.
    Averaging a cell blends its edge into mud, which is what the first set
    looked like; taking the cell's most common colour keeps the edge sharp,
    as the pixel-art clean-up tools do. A cell is opaque if most of it is.
    Then at most `colours` colours, without dithering.
    """
    rgba = picture.convert("RGBA")
    source = rgba.load()
    step = rgba.width / pixels
    result = Image.new("RGBA", (pixels, pixels), (0, 0, 0, 0))
    for row in range(pixels):
        for column in range(pixels):
            cell = [source[x, y] for y in range(int(row * step), max(int(row * step) + 1, int((row + 1) * step)))
                    for x in range(int(column * step), max(int(column * step) + 1, int((column + 1) * step)))]
            colour = dominant_colour(cell)
            if colour is not None:
                result.putpixel((column, row), colour)
    alpha = result.getchannel("A")
    limited = result.convert("RGB").quantize(colors=colours, method=Image.Quantize.MEDIANCUT,
                                             dither=Image.Dither.NONE).convert("RGBA")
    limited.putalpha(alpha)
    return limited


def dominant_colour(cell: list[tuple[int, int, int, int]]) -> tuple[int, int, int, int] | None:
    """The cell's most common colour, near shades counted together; None if mostly see-through."""
    opaque = [pixel[:3] for pixel in cell if pixel[3] >= 128]
    if len(opaque) * 2 < len(cell):
        return None
    shade = Counter((red // 24, green // 24, blue // 24) for red, green, blue in opaque).most_common(1)[0][0]
    members = [pixel for pixel in opaque if (pixel[0] // 24, pixel[1] // 24, pixel[2] // 24) == shade]
    return tuple(sum(channel) // len(members) for channel in zip(*members)) + (255,)


def trim(picture: Image.Image) -> Image.Image:
    """Crop to what is opaque, then pad to a square around it.

    The model leaves a wide margin round an object, and a view that scales a
    picture to its cell would scale the margin too: the first generated set
    drew every unit at about half the size of the CC0 one.
    """
    box = picture.getchannel("A").getbbox()
    if box is None:
        return picture
    cropped = picture.crop(box)
    side = max(cropped.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(cropped, ((side - cropped.width) // 2, (side - cropped.height) // 2))
    return square


def finish(picture: Image.Image, entry: dict) -> Image.Image:
    """The manifest's post-processing for one entry, by its kind."""
    if entry["kind"] == "sprite":
        picture = trim(clear_background(picture))
    return reduce(picture, entry["pixels"], entry["colours"])


def styled(prompt: str, style: dict, kind: str = "sprite") -> str:
    """A prompt with a style's shared prefix, and its suffix for this kind."""
    return style["prefix"] + prompt + style[kind]


# --- make ----------------------------------------------------------------------

def make(model_name: str | None, style_name: str | None, only: list[str]) -> int:
    """Generate every manifest entry, or the ones named, into GENERATED."""
    manifest = json.loads((HERE / "manifest.json").read_text(encoding="utf-8"))
    style = manifest["styles"][style_name or manifest["default_style"]]
    entries = [entry for entry in manifest["assets"] if not only or entry["path"] in only]
    unknown = sorted(set(only) - {entry["path"] for entry in entries})
    if unknown:
        print(f"artgen: not in the manifest: {', '.join(unknown)}", file=sys.stderr)
        return 2
    name, model = model_config(model_name)
    pipe = load_pipeline(model)
    for entry in entries:
        started = time.monotonic()
        raw = run_model(pipe, styled(entry["prompt"], style, entry["kind"]), entry["seed"], model["settings"])
        destination = GENERATED / entry["path"]
        destination.parent.mkdir(parents=True, exist_ok=True)
        finish(raw, entry).save(destination)
        print(f"artgen: {entry['path']} with {name} in {time.monotonic() - started:.1f} s")
    return 0


# --- measure ---------------------------------------------------------------------

# What a model is judged on: a unit, a tower, a terrain tile, a checkers piece,
# and a whole board.
PROBES = {
    "unit": "units/red/shield.png",
    "tower": "units/red/bolt_tower.png",
    "tile": "terrain/plain.png",
    "piece": "checkers/red_man.png",
}
BOARD_PROMPT = ("A top-down tactics game map: green fields, a river with one wooden bridge, "
                "pine trees and grey rocks, on a square grid.")


def timed(work) -> tuple[object, dict]:
    """Run `work`, and say how long it took and the most VRAM it held."""
    torch.cuda.synchronize()
    torch.cuda.reset_peak_memory_stats()
    started = time.monotonic()
    result = work()
    torch.cuda.synchronize()
    return result, {"seconds": round(time.monotonic() - started, 2),
                    "peak_allocated_gb": round(torch.cuda.max_memory_allocated() / 1e9, 2)}


def measure(out: pathlib.Path, model_name: str | None) -> int:
    """Four of the kit's pictures and a board, each timed and weighed."""
    out.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((HERE / "manifest.json").read_text(encoding="utf-8"))
    style = manifest["styles"][manifest["default_style"]]
    entries = {entry["path"]: entry for entry in manifest["assets"]}
    name, model = model_config(model_name)
    pipe, loading = timed(lambda: load_pipeline(model))
    report = {"model": made_by(model), "gpu": torch.cuda.get_device_name(0), "torch": torch.__version__,
              "load": loading, "pictures": {}}
    for probe, path in PROBES.items():
        entry = entries[path]
        raw, cost = timed(lambda: run_model(pipe, styled(entry["prompt"], style, entry["kind"]),
                                            entry["seed"], model["settings"]))
        raw.save(out / f"{name}-{probe}-raw.png")
        finish(raw, entry).save(out / f"{name}-{probe}.png")
        report["pictures"][probe] = cost
    board, cost = timed(lambda: run_model(pipe, styled(BOARD_PROMPT, style, "tile"), 7, model["settings"]))
    board.save(out / f"{name}-board.png")
    report["pictures"]["board"] = cost
    (out / f"{name}-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return 0


# --- entry -------------------------------------------------------------------------

def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    making = commands.add_parser("make")
    making.add_argument("--model", default=None)
    making.add_argument("--style", default=None)
    making.add_argument("--only", nargs="*", default=[])
    measuring = commands.add_parser("measure")
    measuring.add_argument("out", type=pathlib.Path)
    measuring.add_argument("--model", default=None)
    try:
        args = parser.parse_args(argv)
        model_config(args.model)
    except SystemExit as exit_request:
        return 0 if exit_request.code == 0 else 2
    except KeyError as unknown:
        print(f"artgen: {unknown.args[0]}", file=sys.stderr)
        return 2
    if not torch.cuda.is_available():
        print("artgen: no CUDA device; the CC0 art is the way without a GPU", file=sys.stderr)
        return 2
    if args.command == "make":
        return make(args.model, args.style, args.only)
    return measure(args.out, args.model)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
