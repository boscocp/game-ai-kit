# Review: wave/133-the-talk-game-starts-its-own-model

T130 adds `LlmLocalServer` to `ai_llm`. It asks `/health` on
`HttpRuntime.PORT`. A server that answers is used and never stopped. When
nothing answers, it starts `scripts/llm serve` with `OS.create_process` and
polls `/health` every 0.25 s on a threaded `HTTPRequest`. In `_exit_tree`
it calls `OS.kill`, only on a process it started. The talk scene makes it
at the first Tab and keeps typing closed while it loads.
`check_llm_validated.py` allows `OS.create_process` in that one file, by
path. The tests use `fake_llm_server.py`.

A fresh context reviewed PR #82 at head 44d910b. It read the code and the
Godot 4.7.2-stable source for `OS_Unix`, and planted faults one at a time.
It did not start the real model, and it made no commit, push or PR comment.

**Verdict: changes requested, no blocker.** Invariant 7 holds on the play
path: nothing on the main thread waits for the model while it loads or
answers. The gate exemption is exact and planted. The command line is
fixed. Four should-fix findings: three are lifecycle gaps that can strand
the game or the GPU, and one is an untested exit path. Three nits.

## What was reviewed

- `CLAUDE.md`, ADR 0023 and its amendment, `scripts/llm`,
  `tools/llm/llm.py` (`serve`, `SERVER_FLAGS`, `port`), the task file and
  the PR body.
- The diff against `origin/main`: `llm_local_server.gd`, `talk.gd`,
  `talk_panel.gd`, the gate, both suites, the fake server, the measuring
  script, `docs/godot/talk.md`, the locale rows and the Makefile line.
- `drivers/unix/os_unix.cpp` at `4.7.2-stable`: `create_process`, `kill`,
  `is_process_running`, `_check_pid_is_running` and
  `_wait_for_pid_completion`.

## What was run (green at 44d910b unless stated)

- `python3 scripts/check_llm_validated.py --self-test`: ok. The gate on the
  tree: exit 0.
- `python3 scripts/check_readability.py`: exit 0.
- `make test-godot-some SUITES="test/ai_llm/llm_local_server_test.gd
  test/talk/talk_server_test.gd"`: 11 cases, 0 failures, no
  `SCRIPT ERROR`. No fake server was left running.
- A probe (`-s`, headless) that `create_process`es `sleep` and holds the
  pid in a node whose `_exit_tree` kills it. Godot was then sent SIGINT
  with the default disposition, as Ctrl+C in a terminal would, and SIGTERM
  in a second run. Godot died both times (exit -2 for SIGINT). `_exit_tree`
  never ran, and the child was left running. `ps` shows that the child has
  its own session (`setsid()` in `create_process`), so a terminal's Ctrl+C
  never reaches it. Both orphans were killed by hand.

## Findings

1. **Ctrl+C or a plain `kill` leaves `llama-server` holding the card
   (should-fix).** `llm_local_server.gd:126-130`, ADR 0023's amendment.
   The PR and the ADR say only a crash leaves it running. The probe above
   shows that SIGINT and SIGTERM do as well: Godot has no handler for
   them, `_exit_tree` is skipped, and the server is in its own session. So
   it survives the usual way to stop `make demo-talk` from its terminal,
   with about 5 GB of VRAM. Its log keeps writing into that terminal,
   because it inherited Godot's stdout. The next Tab reuses it, but nothing
   ever stops it.
   Suggested fix, Linux only, in `tools/llm/llm.py:serve`: when the game
   asks (an environment variable or a flag), call
   `prctl(PR_SET_PDEATHSIG, SIGTERM)` through `ctypes` before `os.execv`.
   The setting survives `execve`, and the parent is Godot (bash and Python
   both `exec`), so the server then ends with the game however the game
   ends. At minimum, the ADR and `docs/godot/talk.md` should say "Ctrl+C or
   a kill", not "a crash", and name `pkill llama-server`.
   *Planted:* the SIGINT and SIGTERM probes above.

2. **Leaving while the model loads is untested (should-fix).**
   `llm_local_server.gd:130`. Mutant: `_stop()` became
   `if state == READY: _stop()`. Both suites stayed green (11/11). This is
   the path that leaves a 5 GB orphan if it breaks, and the brief names it.
   Wanted: a case that frees the node (or the scene) in `LOADING`, with the
   fake on a long `loading`, and then checks that the port is silent.

3. **`READY` is sticky, and a `LOADING` server that this node did not
   start is never given up on (should-fix).** `llm_local_server.gd:89`
   returns at once in `READY` or `LOADING`. `_on_answer`
   (`:144-147`) ignores failed asks outside `CHECKING`. `_process`
   (`:113-119`) checks the exit code and the 180 s limit only for a server
   it started. Three consequences:
   - **A found server stops later:** `make llm-serve` stopped with Ctrl+C,
     or a second worktree on the same port leaving the scene that started
     it. The scene then stays `READY`: every turn is F1, and "Tab twice"
     does not check again.
   - **A found server dies while loading:** the state stays `LOADING`
     forever. Typing stays closed (`talk.gd:201`), and Tab does nothing.
     The only way out is to leave the scene.
   - **Two worktrees** hit the first consequence, because the port is
     shared.

   Suggested fix: let `begin()` ask again from `READY` (one `/health`
   costs nothing). In `LOADING` with no pid of its own, count failed asks
   and drop to `BY_HAND` after a few.
   *Not planted.* This is a gap in the design, read from the code; there
   is no line to mutate.

4. **`OS.kill` mid-play, and the gate cannot see it (should-fix).**
   `llm_local_server.gd:165-167`. `_give_up` runs from `_process` and
   calls `_stop()`, so `OS.kill`. At 4.7.2, `OS_Unix::kill` is
   `kill(SIGKILL)` followed by a blocking `waitpid`, which the PR measured
   at about 90 ms. When a load passes 180 s, that frame falls during play,
   not on leaving. `check_llm_validated.py` has no pattern for `OS.kill`,
   so V3 cannot refuse it. Compare `wait_to_finish`, which V3 allows only
   in `TEARDOWN`.
   Suggested fix: hold `OS.kill` to `TEARDOWN` in the gate, with a planted
   case. In `_give_up`, either send SIGTERM through a short-lived `kill`
   process (decision 4's own alternative) or only mark the server stopped
   and leave the kill to `_exit_tree`.
   *Planted:* the gate passes the PR's own `_give_up`. `grep kill` in the
   gate finds nothing. The give-up path itself has no test (mutant
   `waited > LOAD_SECONDS` to `false` is untestable: the constant is 180 s
   and cannot be overridden).

5. **Nit: the gate's exemption is exact, but a looser one would pass the
   self-test.** `check_llm_validated.py:219`. Mutant
   `relative.name == STARTER.name`: self-test still ok. That mutant
   exempts any `llm_local_server.gd` in a subfolder of `ai_llm`. A second
   mutant, exempting the whole addon, was caught by "a process started by
   an addon file that is not the starter". Add a planted
   `godot/addons/ai_llm/sub/llm_local_server.gd`. A copy under
   `godot/game/` is already refused by V1.

6. **Nit: the export guard has no test of its own.** `talk.gd:44-46`.
   A headless test cannot tell `OS.has_feature("template")` from `true`.
   The guard is doubled by `file_exists("../scripts/llm")`, which an
   export does not have, so the risk is small. Say this in the test's
   comment instead of claiming the exported build is covered.

7. **Nit: a comment that is half right.** `llm_local_server.gd:171-172`
   says that once the process ended, "Godot forgets it". At 4.7.2,
   `_check_pid_is_running` caches the exit in `process_map`, and asking
   again returns the cached value. The error comes only after `OS.kill`,
   which reaps without updating the map. `_alive` is still right; only the
   reason given is wrong.

## Checked and found sound

- **No wait on the play path.** `OS.create_process` is `fork` plus
  `execvp`, and returns at once. Each ask is an `HTTPRequest` with
  `use_threads` and a 1 s timeout. No synchronous HTTP or process call
  runs on the frame while the model loads or answers.
- **The 101 ms windowed frame.** Headless frames stay under 10 ms, and the
  long ones come only while the weights upload. That is GPU contention.
  The code does not block. It could only be avoided by not sharing the
  card, which makes it a matter for the owner (below), not a defect.
- **The game cannot kill a server it did not start.** `pid` is set only
  from `create_process`. An unreaped child stays a zombie, so its PID
  cannot be reused. `_still_running()` reaps it, and then `_alive` stays
  false, so `OS.kill` never reaches a recycled PID. If our process exits
  in the same frame that another server answers 200, `_stop()` reaps first
  and does not kill.
- **The chain keeps one PID.** `scripts/llm` does `exec python3`, and
  `serve` does `os.execv(llama-server)`. The PID Godot holds is the
  server's own, and `OS.kill` reaches it.
- **Invariant 8.** The program is `scripts/llm`, which sets every cache on
  the toolchain and refuses to start (exit 2, so `STOPPED`) if the
  toolchain is under `$HOME`. It binds `--host 127.0.0.1`, offline, on the
  port read out of `http_runtime.gd`.
- **No command from data.** The path is `res://` + `../scripts/llm`, the
  arguments are `["serve"]`, and only tests set `server_program`.
- **Fallbacks.** Headless, a missing `scripts/llm` and an empty program all
  give `BY_HAND`. A program that exits gives `STOPPED` with its code. All
  of these are tested. Recorded mode starts nothing, also tested.
- **Tab twice quickly** is a no-op in `CHECKING` and `LOADING`. Quitting
  the window runs `_exit_tree`; the PR measured that.
- **Readability.** The file is 192 lines, every function is under 40 lines
  with nesting at most 2, and the header says when not to use it. The gate
  is green.

## On the decisions in the PR body

- 1, 2, 3, 5, 6, 7, 9 and 10: agree.
- 4 (one ~90 ms frame on leaving): acceptable. It is teardown, the same
  allowance the gate already gives `wait_to_finish`. A thread does not
  help: joining it in `_exit_tree` waits just as long. Spawning
  `kill -TERM` would remove the long frame, at the cost of a zombie until
  the game exits. Either way, finding 4 still stands for the mid-play
  call.
- 8 ("a crash leaves it running"): the scope is wider than stated. See
  finding 1.

## Items for the owner

1. Finding 1: let the server die with the game (`PR_SET_PDEATHSIG`, Linux
   only), or accept orphans on Ctrl+C and document `pkill llama-server`?
2. Decision 4: keep the ~90 ms frame on leaving, or SIGTERM through a
   spawned `kill`?
3. The 101 ms windowed frame while the weights upload is GPU contention.
   Accept it, or start the model when the scene opens rather than on Tab?
   That trades decision 5 for a hitch at a calmer moment.
4. `llama-server` runs with no API key and CORS open to all origins. Until
   now that happened only when a person typed `make llm-serve`. Now a game
   starts it on its own, so while it runs, any web page open in a browser
   can use the model at `127.0.0.1:9931`. The risk is compute only, but it
   is now on without anyone asking for it.

## How to reproduce

```bash
git checkout --detach 44d910b
make test-godot-some SUITES="test/ai_llm/llm_local_server_test.gd test/talk/talk_server_test.gd"
# finding 2: in llm_local_server.gd:130, `_stop()` -> `if state == READY: _stop()`; still 11/11
# finding 5: in check_llm_validated.py:219, `relative == STARTER` -> `relative.name == STARTER.name`;
#            --self-test still ok
# finding 1: a -s script that create_process'es `sleep` and kills it in _exit_tree;
#            send Godot SIGINT (default disposition) or SIGTERM; the child outlives it
```

## What was done about them

1. **Applied.** `scripts/llm serve` takes `--parent-pid` (and the key,
   below). `tools/llm/llm.py:die_with` calls `prctl(PR_SET_PDEATHSIG,
   SIGTERM)` before the `execv`, and refuses if the game is already gone.
   `LlmLocalServer` passes its process id to every server it starts.
   `scripts/llm --self-test` kills the parent of a child that called
   `die_with` and checks the child goes. Its planted twin, a child that did
   not call it, must be seen to survive. A no-op `die_with` fails the
   self-test. Measured with the real model: Ctrl+C on the game (SIGINT,
   default disposition, exit -2) and SIGTERM both left no `llama-server`.
   Off Linux only the parent check is made. The page and the ADR say so,
   and they name `pkill llama-server`.
2. **Applied.** `test_leaving_while_the_model_loads_stops_the_server`
   frees the node in `LOADING`, with the fake on a 30 s load. Then the
   port is silent. Your mutant (stop only in `READY`) fails it.
3. **Applied.** `begin()` now asks again from `READY`, `BY_HAND` and
   `STOPPED`, and starts a server again when nothing answers. In the talk
   scene, a turn ruled F1 calls it. A found server in `LOADING` that leaves
   four asks in a row unanswered goes to `STOPPED`, which opens typing
   again. Tests: a found server that went away is started again on
   `begin()`; one that dies while loading is said to have stopped; in the
   scene, an F1 turn starts a server in place of the one that went away.
   Mutants (a sticky `READY`, a silence never counted, an F1 that asks
   nothing) each fail one of them.
4. **Applied.** V3 now refuses `OS.kill` outside `_exit_tree` and
   `_notification`, with a planted case. `_give_up` only says the server
   is stopped. A server still running then stops when the node leaves.
   `load_seconds` is a variable now, and
   `test_a_load_past_its_limit_is_said_not_killed_during_play` runs that
   path at 0.5 s.
5. **Applied.** Planted: a same-named `llm_local_server.gd` in a folder of
   the addon. The looser `relative.name == STARTER.name` now fails the
   self-test.
6. **Applied, as a comment.** `talk.gd` says that no test can see the
   "template" guard, and that `file_exists` also holds it.
7. **Applied.** The comment now says Godot keeps an ended child's exit
   code, and that the error comes only after `OS.kill`.

Owner item 4, the key: **applied.** A server the game starts gets a key
of 16 random bytes, made for that launch (`Crypto`).
- **How it reaches the server.** `scripts/llm` puts it in `LLAMA_API_KEY`,
  the server's own variable. It is not on `llama-server`'s command line:
  `/proc/PID/cmdline` was measured.
- **How the game sends it.** `HttpRuntime.api_key` sends it as
  `Authorization: Bearer`.
- **Measured at the pinned build.** `/health` still answers 200 without
  the key. A chat request without it, or with a wrong one, gets 401
  `{"error":{"message":"Invalid API Key","type":"authentication_error","code":401}}`.
  The right key gets 200. `/v1/models` without the key gets 401. The "no
  API key is set" warning is gone.
- **Test.** The fake server answers in that shape. A turn with the key is
  a reply; one with no key or the wrong key is F2. A found server gets no
  key.
- **`make llm-serve` is unchanged:** no key. The PR recommends leaving it
  so.

Owner items 1 to 3 are in the PR body, with a recommendation on each.
