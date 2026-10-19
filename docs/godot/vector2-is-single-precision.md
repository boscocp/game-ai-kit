# A Vector2 holds 32-bit floats, and a float holds 64

<!-- doc-meta
half_life: practice
verified_on: 2026-10-19
tier: 1
source: https://docs.godotengine.org/en/stable/classes/class_vector2.html ; https://docs.godotengine.org/en/stable/classes/class_float.html
invalidated_if: the pinned engine becomes a double-precision build, or Vector2.normalized() stops answering a non-finite vector with zero
teaches: none
-->

> What T22 had to know before two languages could agree on a trajectory.
> Read in the documentation first, then measured on 4.7.2.

## What the documentation says

`Vector2`'s page: its coordinates are floating point and "by default, these
floating-point values use 32-bit precision, unlike float which is always
64-bit". A double-precision build of the engine changes that; the binary
`make bootstrap` pins is not one.

## What was measured

On 4.7.2, headless:

| expression | prints |
|---|---|
| `String.num(Vector2(0.1, 0).x, 17)` | `0.10000000149011612` |
| `String.num(0.1, 17)` (a `float`) | `0.10000000000000001` |
| `Vector2(0.1, 0).x == 0.1` | `false` |
| `Vector2(INF, 1).normalized()` | `(0.0, 0.0)` |
| `Vector2(INF, 1).is_finite()` | `false` |

## What it means here

- **A vector computed in GDScript and the same one computed in Python differ
  in the eighth significant figure**, and a trajectory a hundred steps long
  carries that further. The steering vectors (`spec/vectors/steering/`)
  therefore hold both sides to a tolerance sized for single precision, not
  the `1e-9` the fuzzy and learning vectors use on plain `float`s.
- **`normalized()` answers a non-finite vector with zero**, silently. A
  target at infinity would make a vehicle that seeks it stop. `ai_steering`
  turns an infinite offset into its direction before normalising, and its
  property test aims at infinity on purpose.
