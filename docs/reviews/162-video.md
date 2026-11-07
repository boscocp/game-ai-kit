# Review: wave/162-video

T153's video is posted. The owner put it on YouTube at
https://youtu.be/1tvfXbz6LJQ. The PR links it from both READMEs, under
each one's opening line, and marks T153 done in the task index. Three
files change: `README.md`, `README.pt-BR.md` and `tasks/STATUS.md`.

A fresh context reviewed PR #119 at head 514cccd. **Verdict: approve, no
blocker. There are two shoulds, both in `tasks/STATUS.md`, and three
nits.**

## What was reviewed

- The commit's message and author. The author is Adalberto Pereira and the
  message has no tooling byline (invariant 11).
- Both README paragraphs, read against the text around them, the pt-BR
  README's conventions and `docs/techniques/glossary.pt-BR.md`.
- The claim "thirteen of the demos in three minutes", checked against
  `tasks/T153-a-video-of-the-demos.md` and against what was delivered in
  `$HOME/Videos/game-ai-kit/`: 13 demo chapters, 13 clips, and the task's
  five acceptance commands all exit 0 (1920x1080 yuv420p, 203 s, the
  thumbnail, chapters from 00:00).
- The generated sections. `<!-- catalogue:summary -->` and the other
  catalogue blocks are untouched in both READMEs.
- The T153 row, compared with the index's other done rows (T142-T152).

## Findings

1. **Should.** The T153 row did not have the shape of a done row (`wave
   NNN (#PR):` and what was delivered); it kept the todo row's plan.
   **Applied:** rewritten like its neighbours.
2. **Should.** The topmost `## Resuming after` section still said T153
   waits, and its "Next" began with T153. **Applied:** that line says the
   video was made and posted, and "Next" starts at the follow-ups.
3. **Nit.** The video runs 3:23 and the READMEs say "three minutes". A
   fair round number, inside the task's 2-4 minutes. **Left.**
4. **Nit.** "**Veja antes:**" in pt-BR leaves "before what?".
   **Applied:** "**Assista primeiro:**", closer to "Watch first".
5. **Nit.** The two READMEs place the line in each file's own order (after
   the tagline and the pointer in English, after the pointer and the
   tagline in pt-BR). Recorded so a later reader does not "fix" it.
   **Nothing to change.**

Not findings: invariant 8 (the video and its scripts live in
`$HOME/Videos`, outside the checkout, as the task decided); the YouTube
link was not fetched, the URL is the owner's.

## What was done about them

Findings 1, 2 and 4 were applied in a second commit on the branch;
3 and 5 were left, as their verdicts say. `make check-affected
BASE=origin/main` exited 0 again after that commit.

Found after the review by the implementer: the video's end card says "MIT
licensed", and the repository is Apache-2.0. The video is already posted;
`tasks/STATUS.md` records it, and the local `description.txt` and edit
script are corrected.
