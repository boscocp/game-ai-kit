"""Write the core vectors in this directory.

Imports nothing from the repository, so the numbers come from neither
implementation the vectors hold -- the generator written out once more,
from Marsaglia (2003) and the README's rules:

    python3 spec/vectors/core/derive.py spec/vectors/core
"""
import json, sys

MASK = 0xFFFFFFFF
SEEDS = (1, 0, 2463534242, 86, 4294967297, 7, -1)


def stream(seed):
    x = (seed & MASK) or 1
    while True:
        x ^= (x << 13) & MASK
        x ^= x >> 17
        x ^= (x << 5) & MASK
        yield x


def case(seed):
    draws = stream(seed)
    first = [next(draws) for _ in range(6)]
    fresh = stream(seed)
    uniforms = [next(fresh) / 4294967296.0 for _ in range(3)]
    # A pick of one is 0 and spends nothing; a pick of five spends one draw.
    again = stream(seed)
    picks = [0, next(again) % 5, 0, next(again) % 5]
    return {"seed": seed, "draws": first, "uniforms": uniforms,
            "picks_of": [1, 5, 1, 5], "picks": picks}


def main(out):
    vector = {"description": "Marsaglia's 32-bit xorshift: the first six draws, three uniforms and "
                             "four picks, each from a fresh generator; seed 1 starts 270369, seed 0 "
                             "is seed 1, a seed is cut to 32 bits, a pick of one spends no draw.",
              "cases": [case(seed) for seed in SEEDS]}
    with open(f"{out}/xorshift.json", "w", encoding="utf-8") as handle:
        json.dump(vector, handle, indent=1)
        handle.write("\n")


if __name__ == "__main__":
    main(sys.argv[1])
