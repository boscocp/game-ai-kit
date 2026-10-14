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

A manifest entry of kind `walk` is a walking sheet (T33): a 4 by 4 grid of
32-pixel frames, made by the model its entry names -- FLUX.2 klein base with
a LoRA trained on exactly that grid -- whatever `--model` says for the rest.

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
from collections.abc import Callable
import pathlib
import sys
import time

import diffusers
import torch
import transformers
from huggingface_hub import snapshot_download
from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
ASSETS = REPO / "godot" / "assets"
GENERATED = ASSETS / "generated"
# Beside a person's pictures, gitignored with them: the model, style, seed and
# prompt behind each, since a PNG cannot say what made it.
MADE_RECORD = "made-by.json"
# How far a background pixel may stray from the border's colour and still be
# background: the sum of the three channels' differences, out of 765. Measured
# on the 2026-10-14 bake-off, where the asked-for green came out in shades.
BACKGROUND_DISTANCE = 110
# The same, for background enclosed by the object, which only its colour and
# its size can identify: tight enough that the trees' dark green is never taken
# for it, and a patch at least half a percent of the picture -- the inside of
# an O, not a green button.
ENCLOSED_DISTANCE = 60
ENCLOSED_AREA = 0.005
# A finished sprite less than this much opaque is a failed generation -- a
# green object cleared away with its green background -- not a picture.
MINIMUM_OPAQUE = 0.05
# Shades of a colour counted as one when finding a cell's most common colour:
# 256 / 24, about ten steps a channel, coarse enough that the noise inside one
# fake pixel falls in one bucket, fine enough that an outline does not.
SHADE_STEP = 24
# The flat colour a sprite is asked to stand on, unless its entry names
# another: green is far from both teams' colours, and the wrong choice for
# anything green, which names its own.
DEFAULT_BACKGROUND = "pure green (#00FF00)"
# What a model that borrows a text encoder takes from the model it borrows
# from: the encoder alone, not its transformer (T33).
ENCODER_FILES = ["text_encoder/*"]
# The walk LoRA's own sentence for its grid, from its model card, word for
# word: it was trained on this, and a sheet asked for in other words came out
# as figures in random poses (T31).
WALK_PROMPT = ("A pixel art spritesheet of {figure} The spritesheet is a 4 by 4 grid of four rows of frames - "
               "first row is 3 walking frames facing down and 1 frame both arms raised, second row is 3 walking "
               "frames facing left and 1 frame jumping left, third row is 3 walking frames facing right and 1 "
               "frame jumping right, fourth row is 3 walking frames back view facing up and 1 frame lying on floor.")


# --- the model ---------------------------------------------------------------

def model_config(name: str | None) -> tuple[str, dict]:
    """A model's name and its entry in model.json; the default when none is named."""
    config = json.loads((HERE / "model.json").read_text(encoding="utf-8"))
    chosen = name or config["default"]
    if chosen not in config["models"]:
        raise KeyError(f"no model {chosen!r}; model.json has {', '.join(config['models'])}")
    return chosen, config["models"][chosen]


def load_pipeline(model: dict) -> diffusers.DiffusionPipeline:
    """A pinned model, with its LoRA if it has one, ready to run with offload.

    A model with `text_encoder_from` borrows that model's text encoder, which
    is the same file: klein base and klein share theirs byte for byte.
    """
    folder = snapshot_download(model["repo"], revision=model["revision"], allow_patterns=model["fetch"])
    parts = {}
    if "text_encoder_from" in model:
        _, donor = model_config(model["text_encoder_from"])
        donor_folder = snapshot_download(donor["repo"], revision=donor["revision"],
                                         allow_patterns=ENCODER_FILES)
        parts["text_encoder"] = transformers.AutoModelForCausalLM.from_pretrained(
            f"{donor_folder}/text_encoder", dtype=torch.bfloat16)
    pipe = getattr(diffusers, model["pipeline"]).from_pretrained(folder, dtype=torch.bfloat16, **parts)
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


def run_model(pipe: diffusers.DiffusionPipeline, prompt: str, seed: int, settings: dict) -> Image.Image:
    """One picture from one prompt and one seed. Same seed, same picture."""
    return pipe(prompt=prompt, num_inference_steps=settings["steps"], guidance_scale=settings["guidance"],
                width=settings["size"], height=settings["size"],
                generator=torch.Generator("cpu").manual_seed(seed)).images[0]


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

    A pixel counts if it is much nearer the key than `BACKGROUND_DISTANCE`
    *and* lies in a patch of such pixels at least `ENCLOSED_AREA` of the
    picture: nothing connects it to the edge, so only its colour and its size
    say it is background. Without the size test this was the global colour
    key the flood exists to avoid, and a review measured it emptying a lime
    tunic. Measured on the first Z-Image set: its O kept a green disc inside.
    """
    width, height = rgb.size
    near = bytearray(1 if sum(abs(channel - wanted) for channel, wanted in zip(pixel, key)) < ENCLOSED_DISTANCE
                     else 0 for pixel in rgb.get_flattened_data())
    keep = bytearray(width * height)
    for start in range(width * height):
        if near[start] and not keep[start]:
            patch = connected(near, start, width, height)
            if len(patch) >= ENCLOSED_AREA * width * height:
                for index in patch:
                    keep[index] = 1
            for index in patch:
                near[index] = 0
    return keep


def connected(mask: bytearray, start: int, width: int, height: int) -> list[int]:
    """Every index joined to `start` through set pixels of `mask`, four ways."""
    patch, frontier, seen = [], [start], {start}
    while frontier:
        index = frontier.pop()
        patch.append(index)
        x, y = index % width, index // width
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            neighbour = ny * width + nx
            if 0 <= nx < width and 0 <= ny < height and mask[neighbour] and neighbour not in seen:
                seen.add(neighbour)
                frontier.append(neighbour)
    return patch


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
    Then at most `colours` colours, without dithering, chosen from the opaque
    cells only: quantising the whole square gave a palette slot to the black
    the transparent cells turn into.
    """
    rgba = picture.convert("RGBA")
    source = rgba.load()
    step = rgba.width / pixels
    result = Image.new("RGBA", (pixels, pixels), (0, 0, 0, 0))
    for row in range(pixels):
        for column in range(pixels):
            colour = dominant_colour([source[x, y] for x, y in cell_pixels(column, row, step)])
            if colour is not None:
                result.putpixel((column, row), colour)
    return limit_colours(result, colours)


def cell_pixels(column: int, row: int, step: float) -> list[tuple[int, int]]:
    """The source coordinates one output pixel covers: at least one, never none."""
    left, top = int(column * step), int(row * step)
    right, bottom = max(left + 1, int((column + 1) * step)), max(top + 1, int((row + 1) * step))
    return [(x, y) for y in range(top, bottom) for x in range(left, right)]


def limit_colours(picture: Image.Image, colours: int) -> Image.Image:
    """At most `colours` colours, the palette taken from the opaque pixels alone."""
    opaque = [pixel[:3] for pixel in picture.get_flattened_data() if pixel[3]]
    if not opaque:
        return picture
    sample = Image.new("RGB", (len(opaque), 1))
    sample.putdata(opaque)
    palette = sample.quantize(colors=colours, method=Image.Quantize.MEDIANCUT)
    limited = picture.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
    limited.putalpha(picture.getchannel("A"))
    return limited


def dominant_colour(cell: list[tuple[int, int, int, int]]) -> tuple[int, int, int, int] | None:
    """The cell's most common colour, near shades counted together; None if mostly see-through."""
    opaque = [pixel[:3] for pixel in cell if pixel[3] >= 128]
    if len(opaque) * 2 < len(cell):
        return None
    def bucket(pixel: tuple[int, int, int]) -> tuple[int, int, int]:
        return (pixel[0] // SHADE_STEP, pixel[1] // SHADE_STEP, pixel[2] // SHADE_STEP)
    shade = Counter(bucket(pixel) for pixel in opaque).most_common(1)[0][0]
    members = [pixel for pixel in opaque if bucket(pixel) == shade]
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


class EmptyPicture(Exception):
    """A sprite with almost nothing left once its background was removed."""


def finish(picture: Image.Image, entry: dict) -> Image.Image:
    """The manifest's post-processing for one entry, by its kind.

    Raises EmptyPicture rather than save a see-through square: a green object
    asked for on a green background clears to nothing, and the first sign of
    it would otherwise be a gap on the board.
    """
    if entry["kind"] == "sprite":
        picture = trim(clear_background(picture))
    elif entry["kind"] == "walk":
        # Never trimmed: the frames are a grid, and cropping the sheet to what
        # is opaque would move every frame off it.
        picture = clear_background(picture)
    result = reduce(picture, entry["pixels"], entry["colours"])
    opaque = sum(1 for alpha in result.getchannel("A").get_flattened_data() if alpha)
    if entry["kind"] != "tile" and opaque < MINIMUM_OPAQUE * result.width * result.height:
        raise EmptyPicture(f"{entry['path']}: {opaque} opaque pixels of {result.width * result.height} "
                           "after its background was removed; try another seed, or another background")
    return result


def styled(prompt: str, style: dict, kind: str = "sprite", background: str = DEFAULT_BACKGROUND) -> str:
    """A prompt with a style's shared prefix, and its suffix for this kind --
    a sprite's naming the background colour it is drawn on."""
    return style["prefix"] + prompt + style[kind].format(background=background)


# --- make ----------------------------------------------------------------------

def make(model_name: str | None, style_name: str | None, only: list[str]) -> int:
    """Generate every manifest entry, or the ones named, into GENERATED, and
    write down beside them what made each one.

    Entries are made one model at a time, each model loaded once: an entry
    that names its own model -- a walking sheet -- gets that one, and every
    other entry the one asked for. An entry with its own model is made only
    when named in `only`: that model is a fetch of its own, and a plain run
    must work with what `make artgen-bootstrap` fetched. The record is
    written after each model, so a later one failing to load keeps what the
    earlier ones made.
    """
    manifest = json.loads((HERE / "manifest.json").read_text(encoding="utf-8"))
    style_name = style_name or manifest["default_style"]
    entries = [entry for entry in manifest["assets"]
               if entry["path"] in only or (not only and "model" not in entry)]
    unknown = sorted(set(only) - {entry["path"] for entry in entries})
    if unknown:
        print(f"artgen: not in the manifest: {', '.join(unknown)}", file=sys.stderr)
        return 2
    skipped = [entry["path"] for entry in manifest["assets"] if not only and "model" in entry]
    if skipped:
        print(f"artgen: {len(skipped)} walking sheet(s) left out; they need their own model -- "
              "see docs/howto/generate-art.md, 'Walking sheets'")
    by_model = entries_by_model(entries, model_name)
    if isinstance(by_model, str):
        print(f"artgen: {by_model}", file=sys.stderr)
        return 2
    record = made_record()
    failed = 0
    for name, group in by_model.items():
        failed += make_with(name, group, manifest["styles"][style_name], style_name, record)
        (GENERATED / MADE_RECORD).write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
    return 1 if failed else 0


def entries_by_model(entries: list[dict], model_name: str | None) -> dict[str, list[dict]] | str:
    """The entries grouped by the model that makes each, or why one cannot be
    made: a model that lists the `kinds` it makes refuses every other kind --
    the walk LoRA turns a still sprite's prompt into a sheet."""
    by_model: dict[str, list[dict]] = {}
    for entry in entries:
        name, model = model_config(entry.get("model", model_name))
        if entry["kind"] not in model.get("kinds", [entry["kind"]]):
            return f"{entry['path']} is a {entry['kind']}, and {name} makes only {', '.join(model['kinds'])}"
        by_model.setdefault(name, []).append(entry)
    return by_model


def make_with(name: str, entries: list[dict], style: dict, style_name: str, record: dict) -> int:
    """Make `entries` with the model `name`, saving each and noting it in
    `record`. Returns how many failed."""
    _, model = model_config(name)
    pipe = load_pipeline(model)
    failed = 0
    for entry in entries:
        started = time.monotonic()
        prompt = entry_prompt(entry, style)
        try:
            picture = finish(run_model(pipe, prompt, entry["seed"], model["settings"]), entry)
        except EmptyPicture as empty:
            print(f"artgen: {empty}", file=sys.stderr)
            failed += 1
            continue
        destination = GENERATED / entry["path"]
        destination.parent.mkdir(parents=True, exist_ok=True)
        picture.save(destination)
        worn = style_name if entry["kind"] != "walk" else None
        record[entry["path"]] = {"model": made_by(model), "style": worn, "seed": entry["seed"], "prompt": prompt}
        print(f"artgen: {entry['path']} with {name} in {time.monotonic() - started:.1f} s")
    del pipe
    torch.cuda.empty_cache()
    return failed


def entry_prompt(entry: dict, style: dict) -> str:
    """The whole prompt for one manifest entry in one style. A walking sheet
    takes no style: its LoRA answers one sentence, and a style is another."""
    if entry["kind"] == "walk":
        return WALK_PROMPT.format(figure=entry["prompt"])
    return styled(entry["prompt"], style, entry["kind"], entry.get("background", DEFAULT_BACKGROUND))


def made_record() -> dict:
    """What made each picture already generated, so regenerating some keeps the rest's."""
    path = GENERATED / MADE_RECORD
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


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


def timed(work: Callable[[], object]) -> tuple[object, dict]:
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
        raw, cost = timed(lambda: run_model(pipe, entry_prompt(entry, style), entry["seed"], model["settings"]))
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

def check_style(name: str | None) -> None:
    """Raise KeyError for a style the manifest does not have; None is the default."""
    styles = json.loads((HERE / "manifest.json").read_text(encoding="utf-8"))["styles"]
    if name is not None and name not in styles:
        raise KeyError(f"no style {name!r}; the manifest has {', '.join(styles)}")


def main(argv: list[str]) -> int:
    """Parse the command, refuse what cannot run before loading anything, run it."""
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
        check_style(getattr(args, "style", None))
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
