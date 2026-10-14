"""Generate the game's pictures with a local image model (T31).

Not part of any lesson, and fenced off from them: it needs torch and a GPU,
it lives outside `python/`, and `make check` never runs it. A reader who never
generates anything keeps the CC0 art. Run it only through `scripts/artgen`,
which keeps every cache on the large disk.

Two commands:

    make    [--style NAME] [--only PATH ...]
            Generate the pictures `manifest.json` names into
            godot/assets/generated/, which git ignores and the game prefers.
    measure OUT_DIR [--fp8]
            The bake-off T31 opens with: five pictures the kit needs and a
            12-frame walk cycle, with seconds and peak VRAM for each, written
            to OUT_DIR/report.json beside the pictures.

The model is the one `model.json` pins. The base is loaded in bfloat16 with
model CPU offload: the transformer and the text encoder are about 7.8 GB and
8 GB, over a 12 GB card together and under it one at a time, and offload keeps
only the part running on the GPU. `--fp8` also stores the transformer's weights
in 8-bit floats, computing in bfloat16.

Exit codes: 0 done, 1 a generation failed, 2 wrong usage.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
import pathlib
import sys
import time

import torch
from diffusers import Flux2KleinPipeline
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


# --- the model ---------------------------------------------------------------

def load_pipeline(fp8: bool) -> Flux2KleinPipeline:
    """The pinned base model with the pinned LoRA, ready to run with offload."""
    config = json.loads((HERE / "model.json").read_text(encoding="utf-8"))
    base, lora = config["base"], config["lora"]
    base_folder = snapshot_download(base["repo"], revision=base["revision"], allow_patterns=base["fetch"])
    lora_folder = snapshot_download(lora["repo"], revision=lora["revision"], allow_patterns=lora["fetch"])
    pipe = Flux2KleinPipeline.from_pretrained(base_folder, dtype=torch.bfloat16)
    pipe.load_lora_weights(lora_folder, weight_name=lora["weights"], adapter_name="style")
    pipe.set_adapters(["style"], adapter_weights=[lora["scale"]])
    if fp8:
        pipe.transformer.enable_layerwise_casting(storage_dtype=torch.float8_e4m3fn,
                                                  compute_dtype=torch.bfloat16)
    pipe.enable_model_cpu_offload()
    return pipe


def model_names() -> dict[str, str]:
    """What made a picture, as the manifest and NOTICE record it."""
    config = json.loads((HERE / "model.json").read_text(encoding="utf-8"))
    return {part: f"{config[part]['repo']}@{config[part]['revision']}" for part in ("base", "lora")}


def run_model(pipe: Flux2KleinPipeline, prompt: str, seed: int, settings: dict,
              size: tuple[int, int] = (0, 0), reference: Image.Image | None = None) -> Image.Image:
    """One picture from one prompt and one seed. Same seed, same picture."""
    width, height = size if size != (0, 0) else (settings["size"], settings["size"])
    extra = {"image": reference} if reference is not None else {}
    return pipe(prompt=prompt, num_inference_steps=settings["steps"], guidance_scale=settings["guidance"],
                width=width, height=height, generator=torch.Generator("cpu").manual_seed(seed),
                **extra).images[0]


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
    background = bytearray(width * height)
    frontier = [(x, y) for x in range(width) for y in (0, height - 1)]
    frontier += [(x, y) for y in range(height) for x in (0, width - 1)]
    while frontier:
        x, y = frontier.pop()
        if not (0 <= x < width and 0 <= y < height) or background[y * width + x]:
            continue
        if sum(abs(channel - wanted) for channel, wanted in zip(pixels[x, y], key)) >= BACKGROUND_DISTANCE:
            continue
        background[y * width + x] = 1
        frontier += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    result = rgb.convert("RGBA")
    result.putalpha(Image.frombytes("L", (width, height), bytes(0 if flag else 255 for flag in background)))
    return result


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

def make(style_name: str | None, only: list[str]) -> int:
    """Generate every manifest entry, or the ones named, into GENERATED."""
    manifest = json.loads((HERE / "manifest.json").read_text(encoding="utf-8"))
    style = manifest["styles"][style_name or manifest["default_style"]]
    entries = [entry for entry in manifest["assets"] if not only or entry["path"] in only]
    unknown = sorted(set(only) - {entry["path"] for entry in entries})
    if unknown:
        print(f"artgen: not in the manifest: {', '.join(unknown)}", file=sys.stderr)
        return 2
    pipe = load_pipeline(fp8=False)
    for entry in entries:
        started = time.monotonic()
        raw = run_model(pipe, styled(entry["prompt"], style, entry["kind"]), entry["seed"], manifest["settings"])
        destination = GENERATED / entry["path"]
        destination.parent.mkdir(parents=True, exist_ok=True)
        finish(raw, entry).save(destination)
        print(f"artgen: {entry['path']} in {time.monotonic() - started:.1f} s")
    return 0


# --- measure ---------------------------------------------------------------------

# The five pictures T31 measures: a unit, a tower, a terrain tile, a checkers
# piece, and a whole board.
PROBES = {
    "unit": "units/red/shield.png",
    "tower": "units/red/bolt_tower.png",
    "tile": "terrain/plain.png",
    "piece": "checkers/red_man.png",
}
BOARD_PROMPT = ("a top-down tactics game map, green fields, a river with one wooden bridge, "
                "pine trees and grey rocks, square grid")
WALKER = "a foot soldier carrying a large tower shield and a short spear, painted red, side view facing right"
# A walk cycle in twelve frames, by what the legs are doing: the contact, the
# step down, the pass and the rise, for each leg, at the speed animators use.
WALK_PHASES = [
    "right foot forward touching the ground, left foot back", "weight dropping onto the right foot",
    "lowest point, right leg bent", "left leg passing the right", "rising on the right leg",
    "highest point, left leg swinging forward", "left foot forward touching the ground, right foot back",
    "weight dropping onto the left foot", "lowest point, left leg bent", "right leg passing the left",
    "rising on the left leg", "highest point, right leg swinging forward",
]


def timed(work) -> tuple[object, dict]:
    """Run `work`, and say how long it took and the most VRAM it held."""
    torch.cuda.synchronize()
    torch.cuda.reset_peak_memory_stats()
    started = time.monotonic()
    result = work()
    torch.cuda.synchronize()
    return result, {"seconds": round(time.monotonic() - started, 2),
                    "peak_allocated_gb": round(torch.cuda.max_memory_allocated() / 1e9, 2),
                    "peak_reserved_gb": round(torch.cuda.max_memory_reserved() / 1e9, 2)}


def measure(out: pathlib.Path, fp8: bool) -> int:
    """The bake-off: five pictures and two walk cycles, each timed and weighed."""
    out.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((HERE / "manifest.json").read_text(encoding="utf-8"))
    settings, style = manifest["settings"], manifest["styles"][manifest["default_style"]]
    entries = {entry["path"]: entry for entry in manifest["assets"]}
    pipe, loading = timed(lambda: load_pipeline(fp8))
    report = {"model": model_names(), "fp8": fp8, "gpu": torch.cuda.get_device_name(0),
              "torch": torch.__version__, "load": loading, "pictures": {}}
    for name, path in PROBES.items():
        entry = entries[path]
        raw, cost = timed(lambda: run_model(pipe, styled(entry["prompt"], style, entry["kind"]), entry["seed"], settings))
        raw.save(out / f"{name}-raw.png")
        finish(raw, entry).save(out / f"{name}.png")
        report["pictures"][name] = cost
    board, cost = timed(lambda: run_model(pipe, styled(BOARD_PROMPT, style, "tile"), 7, settings, (768, 512)))
    board.save(out / "board.png")
    report["pictures"]["board"] = cost
    report["walk_sheet"] = walk_sheet(pipe, settings, style, out)
    report["walk_frames"] = walk_frames(pipe, settings, style, out)
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return 0


def walk_sheet(pipe, settings: dict, style: dict, out: pathlib.Path) -> dict:
    """The walk cycle asked for as one picture: twelve frames in a 6x2 grid.

    Of the layouts tried on 2026-10-14 -- 4x3, one row of 6, one row of 4, 6x2
    -- this one held the character best. None drew a walk: the frame counts
    were wrong, the facing flipped and the poses did not follow each other.
    """
    prompt = styled(f"animation sprite sheet, 12-frame walk cycle, 6 columns and 2 rows, read left to right, "
                    f"side view facing right in every frame, identical character, only the legs move, {WALKER}", style)
    sheet, cost = timed(lambda: run_model(pipe, prompt, 3, settings, (1536, 512)))
    sheet.save(out / "walk-sheet.png")
    return cost


def walk_frames(pipe, settings: dict, style: dict, out: pathlib.Path) -> dict:
    """The walk cycle as twelve pictures, each given the one before as reference.

    The reference is what might hold the character the same from frame to
    frame; a fresh seed per frame without it draws twelve different soldiers.
    """
    frames: list[Image.Image] = []
    started = time.monotonic()
    peak = 0.0
    for index, phase in enumerate(WALK_PHASES):
        prompt = styled(f"{WALKER}, walking, {phase}", style)
        reference = frames[-1] if frames else None
        frame, cost = timed(lambda: run_model(pipe, prompt, 31, settings, reference=reference))
        peak = max(peak, cost["peak_allocated_gb"])
        frames.append(frame)
        reduce(trim(clear_background(frame)), 32, 24).save(out / f"walk-{index:02d}.png")
    save_strip_and_loop(frames, out)
    return {"seconds": round(time.monotonic() - started, 2), "peak_allocated_gb": peak}


def save_strip_and_loop(frames: list[Image.Image], out: pathlib.Path) -> None:
    """The twelve frames side by side, and as a looping GIF, both at game size
    and enlarged eight times so a person can judge them."""
    small = [reduce(clear_background(frame), 32, 24) for frame in frames]
    strip = Image.new("RGBA", (32 * len(small), 32), (0, 0, 0, 0))
    for index, frame in enumerate(small):
        strip.paste(frame, (32 * index, 0))
    strip.resize((strip.width * 8, strip.height * 8), Image.Resampling.NEAREST).save(out / "walk-strip.png")
    large = [frame.resize((256, 256), Image.Resampling.NEAREST) for frame in small]
    large[0].save(out / "walk.gif", save_all=True, append_images=large[1:], duration=90, loop=0, disposal=2)


# --- entry -------------------------------------------------------------------------

def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    making = commands.add_parser("make")
    making.add_argument("--style", default=None)
    making.add_argument("--only", nargs="*", default=[])
    measuring = commands.add_parser("measure")
    measuring.add_argument("out", type=pathlib.Path)
    measuring.add_argument("--fp8", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        return 0 if exit_request.code == 0 else 2
    if not torch.cuda.is_available():
        print("artgen: no CUDA device; the CC0 art is the way without a GPU", file=sys.stderr)
        return 2
    if args.command == "make":
        return make(args.style, args.only)
    return measure(args.out, args.fp8)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
