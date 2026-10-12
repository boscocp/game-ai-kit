# 0001 — Godot 4, 2D, Compatibility renderer

Status: accepted · 2026-10-12 (T0)

## Context

The predecessor of this project was built on Unity in 2020. Two things have
changed since: Unity's licensing history cost it trust among hobbyists and
educators, and Godot became a complete engine rather than a promising one.

This is teaching material. Whoever reads it must be able to run it, and the
audience includes people on old laptops with integrated graphics.

## Decision

Godot 4, pinned to a single version in `.godot-version`, verified by SHA-512 at
bootstrap. 2D only. The rendering method is `gl_compatibility`, not Forward+.

## Alternatives considered

- **Unity.** Largest asset ecosystem and the predecessor's home. Rejected:
  proprietary, heavier to install, and licensing changes can strand a reader.
- **Unreal.** Unmatched for high-end 3D, irrelevant for a 2D grid game, and its
  hardware floor is far above tier 2.
- **Forward+ renderer.** The modern default and better looking. Rejected: it
  raises the hardware floor for everyone and buys a 2D grid game nothing.
- **An engine-agnostic C or Rust core via GDExtension.** Portable and fast.
  Rejected: binary distribution and cross-compilation would dominate the work,
  and the code would stop being readable as teaching material — which
  invariant 1 says wins.

## Consequences

- Runs on integrated graphics from around 2015; `check_renderer.py` fails if
  the renderer changes or a 3D node appears under `game/` or `demos/`.
- No 3D lessons. If the kit ever grows them, they are a separate tier with
  their own ADR.
- Addons are GDScript, which is what makes them readable; the price is that
  they are slower than a tuned native implementation. Accepted deliberately.
