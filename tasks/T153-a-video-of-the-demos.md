# T153 — A video of the demos, for YouTube

Size: M · Prereqs: T150, T151, T152 · Files: none in the repository (the video and the scripts that make it live in `$HOME/Videos/game-ai-kit/`)

## Goal

The owner wants a video of the demos to post on YouTube, made after the
flocking work (T150-T152) so the boids, the RTS flock and the crowd are
in it (the owner, 2026-11-06). It is made last, from a current `main`.

## Decisions written down first

_The owner asked for this task on 2026-11-06. The decisions below are this session's proposal; the wave that takes the task confirms them, or brings them back to the owner._

- **Recorded by the engine, not the screen.** Godot's Movie Maker mode
  (`--write-movie`, `--fixed-fps`) renders every frame offline, so a busy
  machine drops none. A scratch SceneTree script, outside the repository
  and in a scratch worktree, sets English (`Language.choose`), opens each
  demo and presses its keys on a timeline in game seconds. A frame that is
  not 16:9 is letterboxed onto 1920x1080 with the scene's own background,
  never stretched.
- **Each clip shows the decision** (invariant 13): the overlay on, 15-30
  seconds each. The A* maze, the flock with its three rules switched
  (T150), steering, the 3D race watched from above (Tab, after the grip
  test), the four deciders in `demo-behaviour`, Pac-Man with the ghosts'
  view, the RTS with its plan, its influence and a flocking group (T151),
  the squad mode, the bot match, the infiltration crowd (T152), and the
  new techniques: the decision tree and forest (T113, T114) and the
  guard's Bayesian network (T115). `demo-talk` is left out: it needs a
  local LLM server.
- **Edited with ffmpeg:** a title card ("game-ai-kit — game AI you can
  read, for Godot 4"), a lower-third caption per clip naming the technique
  and its `make` target, short fades, and an end card with
  `github.com/boscocp/game-ai-kit`, `pip install gameaikit` and the Godot
  Asset Store, if it is approved by then. There is no music, because of
  licensing. The owner can add music from YouTube's Audio Library.
- **Delivered to `$HOME/Videos/game-ai-kit/`:**
  - `game-ai-kit.mp4`: 2-4 minutes, 1920x1080, H.264, yuv420p, faststart,
    with a silent AAC track;
  - each raw clip;
  - `thumbnail.png` at 1280x720;
  - `description.txt` with a title, a description, the links, chapters
    that match the edit, and tags.
- **Nothing is uploaded.** Posting is the owner's job.

## Acceptance

```bash
test -s "$HOME/Videos/game-ai-kit/game-ai-kit.mp4"
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,pix_fmt -of csv=p=0 "$HOME/Videos/game-ai-kit/game-ai-kit.mp4" | grep -qx '1920,1080,yuv420p'
python3 -c "import subprocess,sys; d=float(subprocess.run(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',sys.argv[1]],capture_output=True,text=True,check=True).stdout); sys.exit(0 if 120<=d<=240 else 1)" "$HOME/Videos/game-ai-kit/game-ai-kit.mp4"
test -s "$HOME/Videos/game-ai-kit/thumbnail.png"
grep -q '00:00' "$HOME/Videos/game-ai-kit/description.txt"
```

## Manual check

Watch the whole video:

- Is every caption legible, and does none of them cover the AI's overlay?
- Is the interface in English everywhere?
- Is nothing stretched?
- Does each clip show the AI deciding, not only moving?
- Do the chapters in `description.txt` land on the right clips?
