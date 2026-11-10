# A black Project Manager on a machine whose OpenGL context fails

<!-- doc-meta
half_life: practice
verified_on: 2026-11-10
tier: 1
source: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
invalidated_if: the pin moves past 4.7.2, or the machine's graphics driver changes
teaches: none
-->

> On the author's machine (Linux, NVIDIA, 4.7.2), `./scripts/godot -p` opened a
> Project Manager window that stayed black. The project's own editor
> (`./scripts/godot --path godot -e`) drew normally. Measured once, on
> 2026-11-10, during the store install check.

## What the log said

The editor's output began with these lines:

```
ERROR: Condition "ctxErrorOccurred || !gl_display.context->glx_context" is true. Returning: ERR_UNCONFIGURED
WARNING: Your video card drivers seem not to support the required OpenGL version, switching to OpenGLES.
MESA-EGL: warning: egl: failed to create dri2 screen
```

The GLX context failed, and the engine fell back to OpenGL ES. The kit's
project draws anyway, because `project.godot` pins
`rendering_method="gl_compatibility"`. With no project open, nothing pins
the renderer. That is why the Project Manager differs, though it is
inferred from the log and not traced in the source.

## What worked

The command-line options `--rendering-method` and `--rendering-driver`,
which the command-line tutorial documents, pin the renderer for that run:

```bash
./scripts/godot -p --rendering-method gl_compatibility --rendering-driver opengl3 &
```

The window drew, and the AssetLib install went through.

## Not done

- No fix in the repository. This is the machine's driver, and the flags
  are a workaround for one person's run, not a project setting.
- The black window was not reproduced on another machine, or with the
  Vulkan driver installed.
