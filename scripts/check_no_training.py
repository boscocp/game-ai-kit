#!/usr/bin/env python3
"""Hold invariant 6: Python trains and emits weights, GDScript only infers.

The rule
--------
No training at game time. Fitting is a batch job that runs on a desk, writes a
file and is reviewed; inference is four multiplications in a frame. Mixing the
two is how a game ships a model nobody can reproduce, and the first symptom is
an opponent that plays differently on two machines and identically to no
recorded version of itself.

So the split is physical. `python/gameaikit/training/` descends a gradient;
`godot/addons/ai_learning/` multiplies published weights by a feature row and
stops. This gate is four claims about that split:

  * N1 no GDScript *code* uses the vocabulary of fitting;
  * N2 nothing in the inference addon writes a file, and nothing in GDScript
    writes over the weights;
  * N3 no GDScript assigns to a model's weights after it is built -- which is
    the update step itself, whatever it is called;
  * N4 the committed weights are the Python pipeline's own output, and a fresh
    run still produces them;
  * N5 no GDScript writes a bead count. MENACE (T28) learns by adding and
    removing beads, and that is training whatever the words: Godot reads the
    published beads and plays by them. A `bead = ...` key on a line that
    continues a dictionary literal is a key, not a write (wave 93);
  * N6 the published beads are what `gameaikit.menace` trains from its seed,
    and a fresh run still produces them;
  * N7 the published checkers weights (T32) are what `gameaikit.checkers`
    fits from its seed -- self-play, both fits and the match -- and a fresh
    run still produces them;
  * N8 no GDScript writes a file where the checkers weights live: the game
    reads them and only multiplies.
  * N9 nothing in `ai_opponent` writes a file, and no GDScript writes an
    n-gram table anywhere. One of this invariant's exceptions, which ADR
    0016 names one by one -- this one, N13's bandit, and N14's player
    model: the opponent model counts during a fight, and is
    allowed to only because its table starts empty, replays from the input
    log, and is never written down -- a table that was saved would be a
    model fitted at game time;
  * N10 the published cloned player (T18) is what `gameaikit.cloning`
    fits from the committed rows, and a fresh run still produces it. The
    rows themselves are cut by Godot from the recordings, and
    `make test-clone-rows` holds them to the recordings;
  * N11 no GDScript writes a file where the cloned player lives -- by its
    file name or by `FightCloneOpponent.PUBLISHED_PATH`, the constant the
    fighting game names it by;
  * N16 the published decision tree that reads the fighting opponent
    (T113) is what `gameaikit.cloning.opponent_tree` fits from the same
    committed rows, and a fresh run still produces it;
  * N17 no GDScript writes a file where that tree lives -- by its file name
    or by `FightTreeOpponent.PUBLISHED_PATH`. A tree the game grew or pruned
    as it watched would be a model fitted at game time; the "tree:" modes
    only walk the published one, and the n-gram beside them does the
    counting ADR 0016 allows;
  * N12 no GDScript outside `ai_learning` writes into a ghost's `cases`.
    A ghost that counted what it saw during the fight would be a Shadow
    trained at game time, and since the game loads the player once, it
    would outlive the fight -- what ADR 0016 allows the n-gram only because
    its table starts empty and is never kept;
  * N13 the bandit (T99, ADR 0016 as amended on 2026-10-26): in every file
    under `ai_bandit` and every GDScript that names `Bandit` or
    `FightBanditOpponent` -- a script holding one by type -- no line writes
    a file, a `ConfigFile` or a resource, and no `+=` or `-=` multiplies or
    divides a difference. The bandit keeps pulls and payoff sums and
    computes a mean when it is read; `x += rate * (target - x)` is a step
    towards a target, and so is the incremental mean `mean += (payoff -
    mean) / n`, which the amendment refuses because a gate cannot tell it
    from a learning rate -- nor the step written out with its left side
    read back, or `lerp`; and inside `ai_bandit`, no scaled `+=` at all,
    which catches a difference named on the line before. A net for the common spellings, not
    a proof; that the counts start empty and replay from the fight's log is
    held by `fight_bandit_opponent_test.gd`, and that is the only thing that
    would catch a `static var` keeping bandits from one fight to the next,
    which writes no file and steps nothing;
  * N14 the player model (T100, ADR 0016 as amended on 2026-10-26): in
    `godot/game3d/botmatch/player_model.gd` and `match_difficulty.gd`, and
    every GDScript that names `PlayerModel` or `MatchDifficulty` -- the
    match and its scene hold the model through the second -- N13's
    refusals: no file, `ConfigFile` or resource written, no step towards a
    target, nor a value read back into itself through a product (a moving
    average); in the model's two files no scaled `+=` and no read-back with
    a product at all (an Elo multiplied out). And no line that reads a
    file: none names `user://` or the user data folder, `FileAccess`,
    `ConfigFile`, `ResourceLoader`, `JSON`, `load(` or `preload(`. A model
    read back at the start of a match would be a profile, and a profile
    outlives the match; a holder is handed its table and its fixtures by
    scripts that hold no model. A net for the common spellings, not a
    proof: a value stepped through a helper function, or a file read by a
    script that holds nothing and handed in, passes it. The match's event log is not a finding: it
    holds events, is written only under `-- --record`, and its writer,
    `MatchEventLog`, neither is the model nor names it. That the counts
    start empty and replay from the person's events is held by
    `player_model_test.gd`;
  * N15 the maze's MDP (T98): the published values and policy in
    `godot/game/maze/` are what `gameaikit.mdp.publish` solves from the committed
    rules, a fresh run writing the same bytes; and no GDScript writes a
    file where they live -- by their folder, their file names or
    `MdpPacMan`'s constants -- nor any file from inside the maze game; and
    nothing updates the tables once read: in the maze game and in any
    script naming `MdpPacMan`, no line reads an indexed value back into
    itself (N3's net for an update step, there too), and no line outside
    `_load_tables` assigns to `_values` or `_letters`. A value updated at game time
    (Q-learning, any temporal-difference step) is refused by that ADR's
    amendment; this rule is a net for its common spellings, not a proof --
    an update through a renamed copy of the table passes it.

N4, N6, N7, N10, N15 and N16 are the ones with teeth. The others are about the shape of the code and
could all pass over a weights file somebody typed by hand.

What this gate cannot do
------------------------
Recognise a training loop written in innocent words. A function called
`_improve_the_numbers` that walks a gradient trips N1 on nothing and N3 only
if it assigns to something called `weights`. That hole is real and is left
open deliberately: the alternative is a list of verbs long enough to fire on
the word `fit` in a comment about a window, and a gate that fires on good code
teaches people to switch it off.

`train` is deliberately not in the vocabulary. This game's planner trains
units, in a domain written out in GDScript, and the word belongs to the game
before it belongs to machine learning.

Exit codes
----------
0   training lives on the Python side
1   violations found (each one printed)
2   wrong usage, or a file that cannot be read
3   the Python pipeline could not be run, so N4 checked nothing

Usage
-----
    check_no_training.py [--repo PATH] [--skip-retrain | --retrain N4,N7]
    check_no_training.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import io
import json
import math
import pathlib
import re
import subprocess
import sys
import tempfile

# Where each half of the split lives.
GODOT = pathlib.Path("godot")
LEARNING_ADDON = pathlib.Path("godot") / "addons" / "ai_learning"
# The tactical board's published weights, beside the policy that reads them
# (T60 moved them out of the technique: they are a game's data).
TACTICAL_GAME = GODOT / "game" / "tactical"
WEIGHTS = TACTICAL_GAME / "weights.json"

# The readable half of the same fit, shipped in the same folder. `report.py`
# calls it "the one that matters here", and until a review rewrote it to claim
# 999999 games and watched this gate pass, nothing in the repository had ever
# read it: no target, no CI step, no test. It costs one string comparison
# against a training run N4 is performing anyway.
READABLE = TACTICAL_GAME / "weights.txt"
TRAINER = "gameaikit.tactical.report"

# Where inference runs, held to the addon's strict rules (N2's "writes no
# file", N3's "reads an indexed value back into itself"): the addon, and the
# tactical board's adapter that runs its model every decision. T60 moved the
# adapter out of the addon, and the rules would have stopped at the folder.
# Named file by file, because the rest of `game/tactical/` keeps running
# totals and records games, which the strict rules would call training.
INFERENCE_FILES = [TACTICAL_GAME / name for name in
                   ("learned_policy.gd", "learned_decision.gd", "board_features.gd")]

# MENACE's published beads, and the pipeline that must reproduce them.
BEADS = GODOT / "game" / "tictactoe" / "menace_beads.json"
BEAD_TRAINER = "gameaikit.menace.report"

# The learned checkers evaluation (T32), and the pipeline that must reproduce
# it. About forty seconds: self-play is four hundred games in pure Python.
CHECKERS_GAME = GODOT / "game" / "checkers"
CHECKERS_WEIGHTS = CHECKERS_GAME / "checkers_weights.json"
CHECKERS_TRAINER = "gameaikit.checkers.report"
CLONE_WEIGHTS = GODOT / "game" / "fighting" / "clone_weights.json"
CLONE_TRAINER = "gameaikit.cloning.publish"
CLONE_NAMES_RE = re.compile(r"clone_weights|FightCloneOpponent\.PUBLISHED_PATH")
# The decision tree that reads the fighting opponent (T113, N16 and N17).
OPPONENT_TREE = GODOT / "game" / "fighting" / "opponent_tree.json"
TREE_TRAINER = "gameaikit.cloning.opponent_tree"
TREE_NAMES_RE = re.compile(r"opponent_tree|FightTreeOpponent\.PUBLISHED_PATH")
# Writing into a ghost's table: an assignment through `cases`, or a call that
# changes a dictionary in place. A net for the common spellings, like N5's.
# Through a member, `.cases`: a local list called `cases` -- every vector
# runner has one -- is not a ghost.
CASE_WRITE_RE = re.compile(r"\.cases\b(?:\[[^\]]*\])*\s*(?:[-+*/]?=)(?!=)"
                           r"|\.cases\b(?:\[[^\]]*\])*\.(?:merge|erase|clear|get_or_add|assign)\(")
# A line names the checkers weights by the file, by the class that reads it,
# or by a path into the game's folder -- `"res://game/checkers/" + name`
# builds the file without naming it.
# The opponent model (T17, ADR 0016): the one addon whose numbers change
# while a game runs, and so the one that must never write them down.
OPPONENT_ADDON = GODOT / "addons" / "ai_opponent"
NGRAM_NAMES_RE = re.compile(r"ngram|n_gram|NGram", re.I)
# A script that holds a table -- names the predictor or the opponent built on
# it -- writes nothing at all: the table is reachable from anywhere in it, by
# any name, and the line that saves it need not say "ngram".
TABLE_HOLDERS_RE = re.compile(r"\b(?:NGramPredictor|FightModelOpponent)\b")
CHECKERS_NAMES_RE = re.compile(r"checkers_weights|CheckersWeights|game/checkers/")

# The bandit (T99, N13): the second component ADR 0016 lets count during a
# fight. Its addon, and any script that names its class or the fighting
# game's opponent built on it, writes nothing at all -- as N9 holds the
# n-gram's.
BANDIT_ADDON = GODOT / "addons" / "ai_bandit"
BANDIT_HOLDERS_RE = re.compile(r"\b(?:Bandit|FightBanditOpponent)\b")
# The player model (T100, N14): the third and last component ADR 0016 lets
# count during play. Its file, and any script that names its class or the
# bot match's `MatchDifficulty` that holds it -- as N13 names the fighting
# game's opponent beside `Bandit` -- writes nothing and reads nothing: the
# match and its scene hold the model through `world.difficulty`, and never
# name `PlayerModel`.
PLAYER_MODEL_FILE = GODOT / "game3d" / "botmatch" / "player_model.gd"
# The model's own two files, the model and what reads it each interval:
# held to the strict half too -- no scaled `+=`, nothing assigned from
# itself through a product -- which a script merely holding one is not.
PLAYER_MODEL_OWN = (PLAYER_MODEL_FILE, GODOT / "game3d" / "botmatch" / "match_difficulty.gd")
PLAYER_MODEL_HOLDERS_RE = re.compile(r"\b(?:PlayerModel|MatchDifficulty)\b")
# Loading state: read off the raw line, since a path is a string literal,
# for `user://` and the folder behind it; off the code view for every way a
# script reads a file -- `FileAccess` at all, a `ConfigFile`, a
# `ResourceLoader`, `load(` and `preload(`, and `JSON` parsing. A holder is
# handed what it needs (the table comes from `MatchRules`, a fixture from a
# reader of its own): it reads no file, whatever the path says.
USER_DATA_RE = re.compile(r"user://|get_user_data_dir")
LOADING_RE = re.compile(r"\b(?:FileAccess|ConfigFile|ResourceLoader|JSON)\b|\b(?:pre)?load\s*\(")
# A value read back into itself through a product, which a difference
# never needs to appear in: the moving average `skill = skill * 0.9 + won *
# 0.1` is `skill += 0.1 * (won - skill)`, and the expanded Elo `rating =
# rating + 32.0 * won - 32.0 * expected` is a step too. Beside the player
# model, a field is never scaled into itself; in its own file, nothing is
# assigned from itself with a product or a quotient anywhere on the right.

# A step towards a target: `+=` or `-=` whose right-hand side multiplies or
# divides a difference in brackets -- `rate * (target - x)`, `(payoff -
# mean) / n`, either way round. `pulls[arm] += 1` and `sums[arm] += payoff`
# are counts, and pass. The difference is a word or a bracket, a minus, and
# more, so `(-1)` is not one.
DIFFERENCE = r"\([^()]*[\w)\]]\s*-\s*[^()]*\)"
STEP_TOWARDS_RE = re.compile(rf"[-+]=.*(?:[*/]\s*{DIFFERENCE}|{DIFFERENCE}\s*[*/])")
# The same step with the difference named on the line before -- `var delta
# = payoff - mean`, then `mean += delta / n`: inside the bandit's addon,
# nothing is added to or taken from a field scaled at all. Its counts grow
# by one, and its sums by a payoff. Only there: a script that merely holds a
# bandit adds `fight * 2` to a seed and takes `RANGE / 2` off a health, and
# the rule would fire on good code.
SCALED_ADD_RE = re.compile(r"[-+]=[^#]*[*/]")
# The step written out: `mean = mean + (payoff - mean) / n`, the left side
# read back on the right beside a difference multiplied or divided.
SPELLED_STEP_RE = re.compile(rf"^\s*([A-Za-z_]\w*)\s*(?:\[[^\]]*\])*\s*=(?!=)(.*)$")
STEP_SHAPE_RE = re.compile(rf"[*/]\s*{DIFFERENCE}|{DIFFERENCE}\s*[*/]")
# And the engine's own step: `lerp(q[a], payoff, 0.1)` is `q[a] + 0.1 *
# (payoff - q[a])`, and `move_toward` a step of fixed size.
ENGINE_STEP_RE = re.compile(r"\b(?:lerp|lerpf|lerp_angle|move_toward)\s*\(")

# The maze's MDP (T98): Python solves it and publishes two tables to
# the maze game's folder, where `MdpPacMan` reads them. A line names
# them by the folder, a file name or one of the reader's constants; and any
# file written from the maze game's own folder is one too many, since the
# game writes none.
MAZE_GAME = GODOT / "game" / "maze"
MDP_FOLDER = MAZE_GAME
MDP_FILES = ("values.json", "policy.json")
MDP_SOLVER = "gameaikit.mdp.publish"
# Writing into the tables `MdpPacMan` read: by assignment or by a call that
# changes a packed array or a string in place. Allowed only in the function
# that reads them in.
MDP_TABLE_WRITE_RE = re.compile(
    r"\b_(?:values|letters)\b(?:\[[^\]]*\])*\s*(?:[-+*/]?=)(?!=)"
    r"|\b_(?:values|letters)\.(?:set|append|append_array|push_back|fill|resize|insert|remove_at|clear|"
    r"reverse|sort)\s*\(")
MDP_TABLE_LOADER = "_load_tables"
FUNC_NAME_RE = re.compile(r"^(?:static\s+)?func\s+(\w+)")
# A declaration names a new variable, so it cannot read its own old value:
# `var ways: Array[Dictionary] = [...] as Array[Dictionary]` has the shape
# of a read-back and is a type written twice.
DECLARATION_RE = re.compile(r"^\s*(?:static\s+)?(?:var|const)\s")
MDP_NAMES_RE = re.compile(r"game/maze/|data/maze|MdpPacMan\.|PUBLISHED_FOLDER|VALUES_FILE|POLICY_FILE"
                          r"|\b(?:values|policy)\.json\b")

# Writing a bead count. This rule is a net for the common spellings; the
# guarantee is the engine's. `MenacePlayer` keeps every box in a read-only
# Array inside read-only Dictionaries, and measured on the pinned engine any
# write through any path -- an index, `+=`, a copy of the reference, a
# replaced box, `clear()` -- is refused and changes nothing. A gdUnit test
# holds that the store is read-only at every level.
#
# The net has two meshes. Anywhere under godot/, a name containing `bead`.
# Inside the noughts-and-crosses game, where the beads live, also names with
# `box`, `snapshot` or `count` -- because there the beads are reached as
# `_snapshots[age][box][square]`, and the first version of this rule, looking
# only for `beads`, let `player._snapshots[10][box][4] += 100` straight past.
# The wider mesh is not used elsewhere: "box" is a label's rectangle in the
# checkers view.
#
# Searched anywhere on a line, not only at its start, so `if done: beads[0] = 1`
# and `var x := 0; beads[0] += 1` are seen. What is allowed: a declaration
# (`var beads: Array[int] = ...`), and an object setting its own store in its
# constructor (`_snapshots = published`) -- the shape N3 allows for weights.
BEAD_WORD = r"bead"
BEAD_GAME_WORDS = r"(?:bead|box|snapshot|count)"
BEAD_GAME = GODOT / "game" / "tictactoe"


def _bead_patterns(words: str) -> list[re.Pattern]:
    """The shapes of a write to something whose name contains `words`."""
    name = rf"\w*{words}\w*"
    return [
        # An indexed write, compounded or not: beads[i] += 1, a[b][c] = 0.
        re.compile(rf"\b[\w.]*?{name}\s*(?:\[[^\]]*\])+\s*[-+*/]?=(?!=)", re.I),
        # A compound write to the whole name: beads += other.
        re.compile(rf"\b{name}\s*[-+*/]=", re.I),
        # Another object's store replaced: player._snapshots = {}.
        re.compile(rf"\.{name}\s*=(?!=)", re.I),
        # A bare reassignment of a bead list, outside a declaration.
        re.compile(rf"(?:^|;|:)\s*\w*{BEAD_WORD}\w*\s*=(?!=)", re.I),
        # A method that changes it in place.
        re.compile(rf"\b[\w.]*?{name}\s*(?:\[[^\]]*\])*\.(?:set|append|append_array|push_back|push_front"
                   r"|insert|fill|resize|remove_at|erase|clear|reverse|sort|merge|assign|encode_\w+)\s*\(", re.I),
    ]


# A Lua-style key at the start of a line that begins inside an open `{`:
# `bead = overlay["bead"],` continuing a dictionary literal is a key, not an
# assignment, and N5 read it as one (wave 91's tictactoe panel, found in
# wave 93). Only the key is taken off; the value after it is still read by
# every pattern, so `bead = beads.append(1)` there is still a write.
DICT_KEY_RE = re.compile(r"^\s*\w+\s*=(?!=)")

BEAD_PATTERNS = _bead_patterns(BEAD_WORD)
BEAD_GAME_PATTERNS = _bead_patterns(BEAD_GAME_WORDS)

# `obj.set("_snapshots", ...)` names its target in a string, which the code
# view blanks, so this one is read off the raw line.
BEAD_SET_BY_NAME_RE = re.compile(r"\.set\s*\(\s*[\"'][^\"']*(?:bead|box|snapshot)", re.I)

# Third-party GDScript this project does not author.
VENDORED_DIRS = {"gdUnit4"}

# The vocabulary of fitting. Each entry is a word that has no other job in a
# game, which is the whole test for putting one here.
FITTING_WORDS = {
    "gradient": "the direction a fit moves in; a game has no use for one",
    "backprop": "the chain rule through a network, by its short name",
    "backpropagate": "the same, spelled out",
    "learning_rate": "how far along the gradient to step",
    "epoch": "one pass over a training set",
    "optimizer": "the thing that holds the update rule",
    "optimiser": "the same, spelled the other way",
    "sgd": "stochastic gradient descent, by its initials",
    "standardise": "centring and scaling rows, which happens before a fit",
    "standardize": "the same, spelled the other way",
}

WORD_RE = {word: re.compile(rf"\b{re.escape(word)}\b", re.I) for word in FITTING_WORDS}

# Writing a file. `FileAccess.WRITE` covers the two open modes that truncate;
# the store_* calls are what a writer then does, and are listed separately so
# a handle obtained some other way is still caught.
WRITING_RE = re.compile(
    r"FileAccess\.(?:ModeFlags\.)?(?:WRITE|WRITE_READ)\b"
    r"|ConfigFile\b.*\.save\w*\s*\(|\b\w*config\w*\.save\w*\s*\("
    r"|FileAccess\.open_encrypted\w*\s*\("
    r"|\.store_(?:string|var|line|buffer|8|16|32|64|float|double|real|csv_line)\s*\("
    r"|ResourceSaver\.save\s*\("
)

# Assigning to a model's numbers. Two shapes: writing another object's weights
# at all, and the compound assignment that *is* the update step.
MEMBER_WRITE_RE = re.compile(r"\b[A-Za-z_][\w.]*\.(weights|bias)\s*(?:\[[^\]]*\])?\s*=[^=]")
UPDATE_RE = re.compile(r"\b(weights|bias)\s*(?:\[[^\]]*\])?\s*(?:\+|-|\*|/)=")

# The same update step with the numbers called something else, and this one
# applies **only inside the inference addon**. A review defeated N1 to N3 with
# thirty-four lines of honest gradient descent whose accumulator was called
# `_numbers`, which is exactly the hole the docstring admits to. The verb list
# cannot be lengthened without firing on good code -- but the one directory
# that is read-only by construction can be held to a stricter rule, and it
# contains no line of this shape at all.
ADDON_UPDATE_RE = re.compile(r"\w+\[[^\]]*\]\s*(?:\+|-|\*|/)=")

# The same step again, written out rather than compounded. The first version
# of the rule above pinned the one spelling a review happened to use, and the
# next review walked past it with `_numbers[index] = _numbers[index] - step`
# and with `_numbers.set(index, _numbers[index] - step)` -- the second being
# the idiomatic form for the packed array the weights actually live in.
#
# Both read the value back out of the thing they are writing into, which is
# what an update step is and what no inference does.
#
# They are crude, and they are safe only because of the scope. Measured over
# every .gd file in the project: **zero** matches inside the inference addon
# and three outside it -- `ai_search/dijkstra.gd` relaxing `g[step] = g[current]
# + cost`, which is correct code, and two that are not update steps at all but
# type declarations the regex misreads. A rule this blunt applied repo-wide
# would be a nuisance, and a nuisance is a rule somebody switches off; applied
# to one directory that contains no such line by construction, it costs
# nothing and closes the evasion.
#
# This is a spelling arms race and the docstring says so. What it buys is that
# the planted cases pin the rule rather than one sentence that tripped it.
ADDON_READBACK_RE = re.compile(r"(\w+)\[[^\]]*\]\s*=[^=].*?\b\1\[")
ADDON_SETBACK_RE = re.compile(r"\b(\w+)\.set\s*\([^,]+,.*?\b\1\[")

# How far two runs of a deterministic pipeline may differ. The weights are
# published rounded to six decimals precisely so that two machines can agree
# on the text.
#
# It errs strict, and a review measured which way: a weight moved by exactly
# `1e-6` is *rejected*, because the float difference comes out as
# 1.0000000000287e-6 and the comparison is `<=`. So this admits a difference
# below one unit in the last published place, not one of exactly that size --
# which is the right direction for a gate and was not what the comment said.
TOLERANCE = 1e-6


def gdscript_files(root: pathlib.Path) -> list[pathlib.Path]:
    """Every .gd file this project authors, vendored code excluded."""
    if not root.is_dir():
        return []
    return [path for path in sorted(root.rglob("*.gd")) if not is_skipped(path, root)]


def is_skipped(path: pathlib.Path, root: pathlib.Path) -> bool:
    """Vendored code, or anything under a folder below root whose name starts with a dot.

    The dot folders are tool state, never this project's source. This gate
    reads `godot/` only, so the one it meets is `godot/.godot/`, the import
    cache; check_readability.py reads the whole checkout and skips the same
    rule's `.user-data/` and `.claude/worktrees/` too (T83). Only the parts
    *below* root are asked, so a checkout that itself lives under
    `.claude/worktrees/` is still read.
    """
    folders = path.relative_to(root).parts[:-1]
    return any(part in VENDORED_DIRS or part.startswith(".") for part in folders)


def code_only(text: str) -> str:
    """The same file with its comments and string literals blanked out.

    Prose about training is not training, and this gate would be unusable
    without that distinction: every file in the inference addon explains, in
    its header, what it is deliberately not doing. Blanked rather than removed
    so that line numbers survive.
    """
    kept = []
    for line in text.splitlines():
        kept.append(_strip_line(line))
    return "\n".join(kept)


def _strip_line(line: str) -> str:
    """One line, with anything quoted or commented replaced by spaces."""
    out = []
    quote = ""
    for character in line:
        if quote:
            out.append(" ")
            if character == quote:
                quote = ""
            continue
        if character in "\"'":
            quote = character
            out.append(" ")
            continue
        if character == "#":
            break
        out.append(character)
    return "".join(out)


def check_vocabulary(root: pathlib.Path, repo: pathlib.Path) -> list[str]:
    """N1: no GDScript code uses a word that only fitting needs."""
    findings = []
    for path in gdscript_files(root):
        code = code_only(path.read_text(encoding="utf-8"))
        for number, line in enumerate(code.splitlines(), start=1):
            for word, pattern in WORD_RE.items():
                if pattern.search(line):
                    findings.append(
                        f"N1 {_label(path, repo)}:{number} uses `{word}` in code -- "
                        f"{FITTING_WORDS[word]}"
                    )
    return findings


def runs_inference(path: pathlib.Path, root: pathlib.Path) -> bool:
    """True for the inference addon and the adapter files that run its model."""
    return any(is_under(path, root, place) for place in [LEARNING_ADDON, *INFERENCE_FILES])


def is_under(path: pathlib.Path, root: pathlib.Path, folder: pathlib.Path) -> bool:
    """True when `path` lies in `folder`, a repository path under godot/.

    By the whole folder, not by its last name. The rules used to ask
    `"checkers" in path.parts`, and wave 63 filed the tests by module: then
    `godot/test/checkers/` counted as the checkers game, and a test writing a
    planted file to `user://` was reported as overwriting the weights.
    """
    try:
        relative = path.relative_to(root)
    except ValueError:
        return False
    inside = folder.relative_to(GODOT).parts
    return relative.parts[:len(inside)] == inside


def check_writing(root: pathlib.Path, repo: pathlib.Path) -> list[str]:
    """N2 and N3: the addon writes nothing, and nobody rewrites the weights."""
    findings = []
    for path in gdscript_files(root):
        raw = path.read_text(encoding="utf-8").splitlines()
        code = code_only("\n".join(raw)).splitlines()
        inside_addon = runs_inference(path, root)
        holds_a_table = is_under(path, root, OPPONENT_ADDON) or bool(TABLE_HOLDERS_RE.search("\n".join(code)))
        holds_a_bandit = holds_bandit(path, root, code)
        holds_a_model = holds_player_model(path, root, code)
        # Both spellings of the line. The write is read off the stripped one,
        # because `# we never FileAccess.WRITE here` is a sentence; the path
        # is read off the raw one, because a path *is* a string literal and
        # stripping it leaves the rule nothing to match. That was not a guess
        # -- the planted case for it passed until both were read.
        for number, (line, written) in enumerate(zip(raw, code), start=1):
            label = f"{_label(path, repo)}:{number}"
            if not WRITING_RE.search(written):
                continue
            if inside_addon:
                findings.append(
                    f"N2 {label} writes a file; the inference addon only reads")
            elif holds_a_table or NGRAM_NAMES_RE.search(line):
                findings.append(f"N9 {label} writes an opponent model down; it counts during "
                                "one fight and is never saved (ADR 0016)")
            elif holds_a_bandit:
                findings.append(f"N13 {label} writes a file beside a bandit; it counts during "
                                "one fight and is never saved (ADR 0016)")
            elif holds_a_model:
                findings.append(f"N14 {label} writes a file beside the player model; it counts during "
                                "one match and is never saved (ADR 0016)")
            elif CLONE_NAMES_RE.search(line):
                findings.append(f"N11 {label} writes where the cloned player lives; the game only reads it")
            elif TREE_NAMES_RE.search(line):
                findings.append(f"N17 {label} writes where the opponent's decision tree lives; "
                                "Python fits it and the game only walks it")
            elif MDP_NAMES_RE.search(line) or is_under(path, root, MAZE_GAME):
                findings.append(f"N15 {label} writes a file where the maze's MDP lives; "
                                "Python solves it and the game only reads it")
            elif CHECKERS_NAMES_RE.search(line) or is_under(path, root, CHECKERS_GAME):
                # Before the rule below: `checkers_weights.json` ends in the
                # addon's `weights.json`, and would be named as the wrong file.
                findings.append(f"N8 {label} writes a file where the checkers weights live; "
                                "the game only reads them")
            elif WEIGHTS.name in line:
                findings.append(f"N2 {label} writes over the weights file")
            elif BEADS.stem in line or is_under(path, root, BEAD_GAME):
                findings.append(f"N2 {label} writes a file where MENACE's beads live; "
                                "the game only reads them")
        for number, written in enumerate(code, start=1):
            label = f"{_label(path, repo)}:{number}"
            if MEMBER_WRITE_RE.search(written) or UPDATE_RE.search(written):
                findings.append(
                    f"N3 {label} assigns to a model's weights; "
                    "a fitted model is read-only at game time")
            elif inside_addon and _accumulates(written):
                findings.append(
                    f"N3 {label} reads an indexed value back into itself; inside "
                    "the inference addon that is an update step whatever it is called")
    return findings


def holds_bandit(path: pathlib.Path, root: pathlib.Path, code: list[str]) -> bool:
    """N13's targets: a file in the bandit's addon, or one that names its classes."""
    return is_under(path, root, BANDIT_ADDON) or bool(BANDIT_HOLDERS_RE.search("\n".join(code)))


def steps_towards(line: str, in_addon: bool) -> bool:
    """True for a line, in the code view, that moves a value towards a target.

    Four spellings: a compound step (`+= rate * (a - b)`), the step written
    out with its left side read back (`x = x + (a - x) / n`), the engine's
    `lerp` or `move_toward`, and -- inside the addon only -- any scaled
    compound add (`+= delta / n`). Declarations are new names, and are not
    steps.
    """
    if STEP_TOWARDS_RE.search(line) or ENGINE_STEP_RE.search(line):
        return True
    if in_addon and SCALED_ADD_RE.search(line):
        return True
    spelled = SPELLED_STEP_RE.match(line)
    if not spelled or DECLARATION_RE.match(line):
        return False
    name, right = spelled.groups()
    return bool(re.search(rf"\b{name}\b", right)) and bool(STEP_SHAPE_RE.search(right))


def check_bandit_steps(root: pathlib.Path, repo: pathlib.Path) -> list[str]:
    """N13's second half: beside a bandit, nothing moves a value a step
    towards a target -- a learning rate's step, or the incremental mean."""
    findings = []
    for path in gdscript_files(root):
        code = code_only(path.read_text(encoding="utf-8")).splitlines()
        if not holds_bandit(path, root, code):
            continue
        in_addon = is_under(path, root, BANDIT_ADDON)
        for number, line in enumerate(code, start=1):
            if steps_towards(line, in_addon):
                findings.append(f"N13 {_label(path, repo)}:{number} moves a value a step towards a target; "
                                "a bandit keeps pulls and sums, and computes a mean when it reads one (ADR 0016)")
    return findings


def holds_player_model(path: pathlib.Path, root: pathlib.Path, code: list[str]) -> bool:
    """N14's targets: the model's two files, or one naming `PlayerModel` or `MatchDifficulty`."""
    return any(is_under(path, root, own) for own in PLAYER_MODEL_OWN) or bool(
        PLAYER_MODEL_HOLDERS_RE.search("\n".join(code)))


def scales_itself(line: str, own_file: bool) -> bool:
    """True for an assignment that reads its own left side back through a
    product: `x = x * a + y * b` anywhere beside the model, and in the
    model's own file `x = x + a * y - a * z`, any read-back with a `*` or
    `/` on the right. Declarations are new names, and are not steps."""
    spelled = SPELLED_STEP_RE.match(line)
    if not spelled or DECLARATION_RE.match(line):
        return False
    name, right = spelled.groups()
    if not re.search(rf"\b{name}\b", right):
        return False
    if own_file:
        return bool(re.search(r"[*/]", right))
    return bool(re.search(rf"\b{name}\b\s*[*/]|[*/]\s*\b{name}\b", right))


def check_player_model(root: pathlib.Path, repo: pathlib.Path) -> list[str]:
    """N14's other halves: beside the player model, nothing steps a value
    towards a target, and nothing loads state back -- a model read in at the
    start of a match would be a profile, which outlives it."""
    findings = []
    for path in gdscript_files(root):
        raw = path.read_text(encoding="utf-8").splitlines()
        code = code_only("\n".join(raw)).splitlines()
        if not holds_player_model(path, root, code):
            continue
        own_file = any(is_under(path, root, own) for own in PLAYER_MODEL_OWN)
        for number, (line, written) in enumerate(zip(raw, code), start=1):
            label = f"{_label(path, repo)}:{number}"
            if steps_towards(written, own_file) or scales_itself(written, own_file):
                findings.append(f"N14 {label} moves a value a step towards a target; the player model "
                                "keeps counts and reads its estimate off them (ADR 0016)")
            elif LOADING_RE.search(written) or (written.strip() and USER_DATA_RE.search(line)):
                findings.append(f"N14 {label} loads state beside the player model; it starts empty "
                                "every match, and a model read back would be a profile (ADR 0016)")
    return findings


def open_braces(code: list[str]) -> list[bool]:
    """For each line of the code view, whether it begins inside an open `{...}`.

    GDScript has no braces around blocks, and the code view has blanked
    strings and comments, so a `{` still standing opens a dictionary.
    """
    inside, depth = [], 0
    for line in code:
        inside.append(depth > 0)
        depth = max(0, depth + line.count("{") - line.count("}"))
    return inside


def check_bead_writes(root: pathlib.Path, repo: pathlib.Path) -> list[str]:
    """N5: no GDScript changes a bead count. Adding and removing beads is how
    MENACE learns, so a bead written in the game is training at game time."""
    findings = []
    for path in gdscript_files(root):
        raw = path.read_text(encoding="utf-8").splitlines()
        code = code_only("\n".join(raw)).splitlines()
        in_game = is_under(path, root, BEAD_GAME)
        patterns = BEAD_GAME_PATTERNS if in_game else BEAD_PATTERNS
        for number, (line, written, inside) in enumerate(zip(raw, code, open_braces(code)), start=1):
            if inside:
                written = DICT_KEY_RE.sub("", written, count=1)
            if _writes_a_bead(written, patterns) or (in_game and BEAD_SET_BY_NAME_RE.search(line)):
                findings.append(
                    f"N5 {_label(path, repo)}:{number} changes a bead count; MENACE learns "
                    "in Python, and the game only draws from the published beads")
    return findings


def check_case_writes(root: pathlib.Path, repo: pathlib.Path) -> list[str]:
    """N12: nothing outside the inference addon writes into a ghost's cases."""
    findings = []
    for path in gdscript_files(root):
        if is_under(path, root, LEARNING_ADDON):
            continue
        code = code_only(path.read_text(encoding="utf-8")).splitlines()
        for number, written in enumerate(code, start=1):
            if _writes_a_bead(written, [CASE_WRITE_RE]):
                findings.append(f"N12 {_label(path, repo)}:{number} writes into a ghost's cases; "
                                "the ghost is counted in Python from the recordings, and only read here")
    return findings


def _writes_a_bead(code: str, patterns: list[re.Pattern]) -> bool:
    """True for a line with a statement that writes through a bead name.

    Statement by statement, because `;` joins several on one line. A
    declaration is skipped as a whole: in GDScript an assignment is not an
    expression, so nothing inside a `var` initialiser can write anything.
    """
    for statement in code.split(";"):
        if statement.strip().startswith(("var ", "const ", "static var ")):
            continue
        if any(pattern.search(statement) for pattern in patterns):
            return True
    return False


def check_beads(repo: pathlib.Path, retrain: bool,
                trained: dict | None = None) -> tuple[list[str], bool]:
    """N6: the published beads are what the MENACE pipeline trains from its seed.

    The same shape as N4, and injectable for the same reason: a planted case
    hands it a run and watches the comparison and its wiring both fire.
    """
    path = repo / BEADS
    if not path.parent.is_dir():
        print(f"N0 note: no {BEADS.parent} yet -- N6 inspected nothing")
        return [], True
    if not path.exists():
        return [f"N6 {BEADS} is missing; run `make train-menace`"], True
    committed = json.loads(path.read_text(encoding="utf-8"))
    if not str(committed.get("generated_by", "")).startswith(BEAD_TRAINER):
        return [f"N6 {BEADS} says it was generated by {committed.get('generated_by')!r}, "
                f"not by {BEAD_TRAINER}"], True
    if not retrain:
        return [], False
    fresh = trained if trained is not None else fresh_beads(repo)
    if fresh is None:
        return [], False
    findings = differences_between(committed, fresh, BEADS.name)
    return [finding.replace("N4 ", "N6 ", 1).replace("`make train`", "`make train-menace`")
            for finding in findings], True


def fresh_beads(repo: pathlib.Path) -> dict | None:
    """The bead file as the MENACE pipeline writes it right now."""
    sys.path.insert(0, str(repo / "python"))
    try:
        from gameaikit.menace import report, train  # noqa: PLC0415
    except ImportError as error:
        print(f"N0 the MENACE pipeline could not be imported: {error}")
        return None
    return report.as_json(train.run())


def check_checkers_weights(repo: pathlib.Path, retrain: bool,
                           trained: dict | None = None) -> tuple[list[str], bool]:
    """N7: the published checkers weights are what the checkers pipeline fits
    from its seed. The shape of N6, injectable for the same reason."""
    path = repo / CHECKERS_WEIGHTS
    if not path.parent.is_dir():
        print(f"N0 note: no {CHECKERS_WEIGHTS.parent} yet -- N7 inspected nothing")
        return [], True
    if not path.exists():
        return [f"N7 {CHECKERS_WEIGHTS} is missing; run `make train-checkers`"], True
    committed = json.loads(path.read_text(encoding="utf-8"))
    if not str(committed.get("generated_by", "")).startswith(CHECKERS_TRAINER):
        return [f"N7 {CHECKERS_WEIGHTS} says it was generated by {committed.get('generated_by')!r}, "
                f"not by {CHECKERS_TRAINER}"], True
    if not retrain:
        return [], False
    fresh = trained if trained is not None else fresh_checkers_weights(repo)
    if fresh is None:
        return [], False
    findings = differences_between(committed, fresh, CHECKERS_WEIGHTS.name)
    return [finding.replace("N4 ", "N7 ", 1).replace("`make train`", "`make train-checkers`")
            for finding in findings], True


def fresh_checkers_weights(repo: pathlib.Path) -> dict | None:
    """The checkers weights file as the pipeline writes it right now."""
    sys.path.insert(0, str(repo / "python"))
    try:
        from gameaikit.checkers import report, train  # noqa: PLC0415
    except ImportError as error:
        print(f"N0 the checkers pipeline could not be imported: {error}")
        return None
    return report.as_json(train.run())


def check_clone_weights(repo: pathlib.Path, retrain: bool,
                        trained: dict | None = None) -> tuple[list[str], bool]:
    """N10: the published cloned player is what the cloning pipeline fits from
    the committed rows. The shape of N7, injectable for the same reason.

    A tree with no inference addon is noted; an addon without its cloned
    player is a finding, as N7 makes a missing checkers file one."""
    path = repo / CLONE_WEIGHTS
    if not path.parent.is_dir():
        print(f"N0 note: no {CLONE_WEIGHTS.parent} -- N10 inspected nothing")
        return [], True
    if not path.exists():
        return [f"N10 {CLONE_WEIGHTS} is missing; run `make train-clone`"], True
    committed = json.loads(path.read_text(encoding="utf-8"))
    if not str(committed.get("generated_by", "")).startswith(CLONE_TRAINER):
        return [f"N10 {CLONE_WEIGHTS} says it was generated by {committed.get('generated_by')!r}, "
                f"not by {CLONE_TRAINER}"], True
    if not retrain:
        return [], False
    fresh = trained if trained is not None else fresh_clone_weights(repo, committed)
    if fresh is None:
        return [], False
    findings = differences_between(committed, fresh, CLONE_WEIGHTS.name)
    return [finding.replace("N4 ", "N10 ", 1).replace("`make train`", "`make train-clone`")
            for finding in findings], True


def fresh_clone_weights(repo: pathlib.Path, committed: dict) -> dict | None:
    """The cloned player, for the player the committed file names, as the pipeline fits it now."""
    sys.path.insert(0, str(repo / "python"))
    try:
        from gameaikit.cloning import publish, rows  # noqa: PLC0415
        recorded = rows.read(repo / rows.ROWS_PATH)
    except (ImportError, OSError, ValueError) as error:
        print(f"N0 the cloning pipeline could not be run: {error}")
        return None
    return json.loads(publish.as_text(publish.published(recorded, committed["trained_on"]["player"])))


def check_opponent_tree(repo: pathlib.Path, retrain: bool,
                        trained: dict | None = None) -> tuple[list[str], bool]:
    """N16: the published opponent tree is what `gameaikit.cloning.opponent_tree`
    fits from the committed rows. N10's shape, injectable for the same reason:
    a fighting game without the tree is a finding, a tree without a fighting
    game is noted."""
    path = repo / OPPONENT_TREE
    if not path.parent.is_dir():
        print(f"N0 note: no {OPPONENT_TREE.parent} -- N16 inspected nothing")
        return [], True
    if not path.exists():
        return [f"N16 {OPPONENT_TREE} is missing; run `make train-tree`"], True
    committed = json.loads(path.read_text(encoding="utf-8"))
    if str(committed.get("generated_by", "")) != TREE_TRAINER:
        return [f"N16 {OPPONENT_TREE} says it was generated by {committed.get('generated_by')!r}, "
                f"not by {TREE_TRAINER}"], True
    if not retrain:
        return [], False
    fresh = trained if trained is not None else fresh_opponent_tree(repo, committed)
    if fresh is None:
        return [], False
    findings = differences_between(committed, fresh, OPPONENT_TREE.name)
    return [finding.replace("N4 ", "N16 ", 1).replace("`make train`", "`make train-tree`")
            for finding in findings], True


def fresh_opponent_tree(repo: pathlib.Path, committed: dict) -> dict | None:
    """The opponent tree, for the player the committed file names, as the pipeline fits it now."""
    sys.path.insert(0, str(repo / "python"))
    try:
        from gameaikit.cloning import opponent_tree, rows  # noqa: PLC0415
        recorded = rows.read(repo / rows.ROWS_PATH)
        player = committed["trained_on"]["player"]
    except (ImportError, OSError, ValueError, KeyError, TypeError) as error:
        print(f"N0 the opponent tree's pipeline could not be run: {error}")
        return None
    return json.loads(opponent_tree.as_text(opponent_tree.published(recorded, player)))


def check_mdp_updates(root: pathlib.Path, repo: pathlib.Path) -> list[str]:
    """N15's game-time half: nothing in the maze game, or holding `MdpPacMan`,
    updates the tables it read. A value moved towards a target while playing
    is Q-learning, and ADR 0016's amendment keeps it out."""
    findings = []
    for path in gdscript_files(root):
        code = code_only(path.read_text(encoding="utf-8")).splitlines()
        if not (is_under(path, root, MAZE_GAME) or any("MdpPacMan" in line for line in code)):
            continue
        function = ""
        for number, line in enumerate(code, start=1):
            named = FUNC_NAME_RE.match(line)
            function = named.group(1) if named else function
            label = f"{_label(path, repo)}:{number}"
            if MDP_TABLE_WRITE_RE.search(line) and function != MDP_TABLE_LOADER:
                findings.append(f"N15 {label} writes into the MDP's tables after they were read; "
                                "the values are Python's, and the game only looks them up")
            elif _accumulates(line) and not DECLARATION_RE.match(line):
                findings.append(f"N15 {label} reads an indexed value back into itself; "
                                "beside the MDP's tables that is an update step whatever it is called")
    return findings


def check_mdp_policy(repo: pathlib.Path, retrain: bool,
                     solved: tuple[str, str] | None = None) -> tuple[list[str], bool]:
    """N15: the maze's published values and policy are what the MDP solver writes.

    The shape of N10, compared as text: the solver is deterministic and
    writes the same bytes on every run, and a file of a hundred and seventy
    thousand slots is better named whole than slot by slot. Injectable, so
    the self-test hands it a solve instead of running one.
    """
    folder = repo / MDP_FOLDER
    if not folder.is_dir():
        print(f"N0 note: no {MDP_FOLDER} -- N15 inspected nothing")
        return [], True
    committed = {}
    for name in MDP_FILES:
        if not (folder / name).exists():
            return [f"N15 {MDP_FOLDER / name} is missing; run `make solve-maze`"], True
        committed[name] = (folder / name).read_text(encoding="utf-8")
        head = json.loads(committed[name])
        if head.get("generated_by") != MDP_SOLVER:
            return [f"N15 {MDP_FOLDER / name} says it was generated by {head.get('generated_by')!r}, "
                    f"not by {MDP_SOLVER}"], True
    if not retrain:
        return [], False
    fresh = solved if solved is not None else fresh_mdp_policy(repo)
    if fresh is None:
        return [], False
    return [f"N15 {MDP_FOLDER / name} is not what {MDP_SOLVER} writes from the committed rules; "
            "run `make solve-maze`" for name, text in zip(MDP_FILES, fresh) if committed[name] != text], True


def fresh_mdp_policy(repo: pathlib.Path) -> tuple[str, str] | None:
    """Both MDP files as the solver writes them right now: values, then policy."""
    sys.path.insert(0, str(repo / "python"))
    try:
        from gameaikit.mdp import publish  # noqa: PLC0415
    except ImportError as error:
        print(f"N0 the MDP solver could not be imported: {error}")
        return None
    return publish.run()


def _accumulates(line: str) -> bool:
    """True for a line that writes a value computed from itself.

    Three spellings of one thing: `x[i] -= d`, `x[i] = x[i] - d`, and
    `x.set(i, x[i] - d)`. Inference reads weights; only fitting writes them.
    """
    return bool(ADDON_UPDATE_RE.search(line)
                or ADDON_READBACK_RE.search(line)
                or ADDON_SETBACK_RE.search(line))


def check_weights(repo: pathlib.Path, retrain: bool,
                  trained: tuple[dict, str] | None = None) -> tuple[list[str], bool]:
    """N4: the committed weights are what the Python pipeline produces.

    Returns the findings and whether the pipeline actually ran. A gate that
    quietly skips its only expensive claim is a gate reporting green about
    something it did not look at, so the caller turns a skip into its own
    exit code.
    """
    if not (repo / WEIGHTS.parent).is_dir():
        print(f"N0 note: no {WEIGHTS.parent} yet -- N4 inspected nothing")
        return [], True

    path = repo / WEIGHTS
    if not path.exists():
        return [f"N4 {WEIGHTS} is missing; run `make train`"], True
    committed = json.loads(path.read_text(encoding="utf-8"))
    if not str(committed.get("generated_by", "")).startswith(TRAINER):
        return [
            f"N4 {WEIGHTS} says it was generated by "
            f"{committed.get('generated_by')!r}, not by {TRAINER}"
        ], True

    if not retrain:
        return [], False
    # Injectable, so a planted case can hand this function a fit and assert
    # that both halves of N4 are reached. The three cases for the dump rule
    # were testing the helper, and deleting the *call* left the self-test
    # green -- the rule was planted and its wiring was not.
    trained = trained if trained is not None else fresh_training(repo)
    if trained is None:
        return [], False
    fresh, readable = trained
    findings = differences_between(committed, fresh, WEIGHTS.name)
    return findings + _differences_in_the_dump(repo, readable), True


def _differences_in_the_dump(repo: pathlib.Path, readable: str) -> list[str]:
    """The readable weights ship beside the JSON and must come from the same fit."""
    path = repo / READABLE
    if not path.exists():
        return [f"N4 {READABLE} is missing; `make train` writes it beside the JSON"]
    if path.read_text(encoding="utf-8") != readable:
        return [f"N4 {READABLE} is not what this pipeline writes; run `make train`"]
    return []


def fresh_training(repo: pathlib.Path) -> tuple[dict, str] | None:
    """Both published artifacts as the pipeline writes them right now.

    One fit, both artifacts, because that is how `make train` produces them
    and comparing them against two different runs would be comparing the
    committed pair against a pair that never existed together.
    """
    sys.path.insert(0, str(repo / "python"))
    try:
        from gameaikit.tactical import report, train  # noqa: PLC0415
    except ImportError as error:
        print(f"N0 the training pipeline could not be imported: {error}")
        return None
    training = train.run()
    return report.as_json(training), report.dump(training)


def differences_between(committed: object, fresh: object, where: str) -> list[str]:
    """Every place the committed weights and a fresh run disagree.

    Pure, and public, so a test can hand it two reports that differ in one
    specific way rather than training for four seconds to find out whether the
    rule works.
    """
    if isinstance(committed, dict) and isinstance(fresh, dict):
        return _differences_in_dicts(committed, fresh, where)
    if isinstance(committed, list) and isinstance(fresh, list):
        if len(committed) != len(fresh):
            return [f"N4 {where} has {len(committed)} entries, a fresh run has "
                    f"{len(fresh)}"]
        return [finding
                for index, (one, other) in enumerate(zip(committed, fresh))
                for finding in differences_between(one, other, f"{where}[{index}]")]
    if _both_numbers(committed, fresh):
        # The type as well as the value. `2224` and `2224.0` compare equal and
        # are not the same published artifact: one is a count and the other is
        # a count that has been through something that rounds.
        if isinstance(committed, float) != isinstance(fresh, float):
            return [f"N4 {where} is {committed!r}, and a fresh run gives {fresh!r} "
                    "-- the same number, published as a different kind"]
        if not math.isclose(committed, fresh, rel_tol=0.0, abs_tol=TOLERANCE):
            return [f"N4 {where} is {committed}, and a fresh run gives {fresh}"]
        return []
    if committed != fresh:
        return [f"N4 {where} is {committed!r}, and a fresh run gives {fresh!r}"]
    return []


def _differences_in_dicts(committed: dict, fresh: dict, where: str) -> list[str]:
    """The same comparison over two objects, keys included."""
    findings = []
    for key in sorted(set(committed) | set(fresh)):
        if key not in committed:
            findings.append(f"N4 {where}.{key} is missing; run `make train`")
        elif key not in fresh:
            findings.append(f"N4 {where}.{key} is no longer produced by the pipeline")
        else:
            findings += differences_between(committed[key], fresh[key], f"{where}.{key}")
    return findings


def _both_numbers(one: object, other: object) -> bool:
    """True for two numbers, and false for the booleans that pretend to be."""
    return (isinstance(one, (int, float)) and not isinstance(one, bool)
            and isinstance(other, (int, float)) and not isinstance(other, bool))


def _label(path: pathlib.Path, repo: pathlib.Path) -> str:
    """The path as a reader would type it, when it is inside the repository."""
    try:
        return str(path.resolve().relative_to(repo.resolve()))
    except ValueError:
        return str(path)


# The four rules that refit a model from its seed, and the module each one's
# model belongs to (`modules/<name>.json`, its `retrain` field). They are
# nearly all of this gate's two minutes, so a wave refits only its own.
RETRAINING = ("N4", "N6", "N7", "N10", "N15", "N16")


def run(repo: pathlib.Path, retrain: bool | set[str] = True) -> int:
    """Every rule; the refits are all of them, none, or the named subset.

    Exit 3 means a refit that was asked for could not run. A refit nobody
    asked for -- `--retrain N7` skips N4, N6, N10 and N15 -- is not a failure to
    see; it is a choice made by whoever selected the subset.
    """
    wanted = set(RETRAINING) if retrain is True else (retrain or set())
    findings = check_vocabulary(repo / GODOT, repo)
    findings += check_writing(repo / GODOT, repo)
    findings += check_bead_writes(repo / GODOT, repo)
    findings += check_case_writes(repo / GODOT, repo)
    findings += check_mdp_updates(repo / GODOT, repo)
    findings += check_bandit_steps(repo / GODOT, repo)
    findings += check_player_model(repo / GODOT, repo)
    ran = {}
    for rule, refit in (("N4", check_weights), ("N6", check_beads),
                        ("N7", check_checkers_weights), ("N10", check_clone_weights),
                        ("N15", check_mdp_policy), ("N16", check_opponent_tree)):
        rule_findings, ran[rule] = refit(repo, rule in wanted)
        findings += rule_findings
    for finding in findings:
        print(finding)
    if findings:
        return 1
    if retrain is True or retrain is False:
        return 0 if all(ran.values()) else 3
    return 0 if all(ran[rule] for rule in wanted) else 3


# --- self-test -------------------------------------------------------------


INFERENCE = """\
## Multiplies published weights by a row. Nothing here fits anything: the
## gradient descent that produced these numbers is in Python, and this file
## exists so that it stays there.
class_name LearnedModel
extends RefCounted

var weights: PackedFloat64Array
var bias: float


func _init(given: PackedFloat64Array, given_bias: float) -> void:
\tweights = given
\tbias = given_bias
"""

SOUND_WEIGHTS = {
    "generated_by": "gameaikit.tactical.report",
    "games": 1500,
    "feature_conventions": {"nearby_radius": 2},
    "models": {"combat": {"weights": [0.5081, 1.8326], "bias": 3.3937}},
}


def self_test() -> int:
    failures = []

    def expect(label: str, got: tuple[int, str], want: int, code: str = "") -> None:
        exit_code, output = got
        if exit_code != want:
            failures.append(f"{label}: expected exit {want}, got {exit_code} ({output!r})")
        elif code and code not in output:
            failures.append(
                f"{label}: expected a {code} finding, got {output.strip() or 'nothing'!r}")

    def quietly(argv: list[str]) -> int:
        """`main` with both streams caught.

        The three cases that use this go through `main` rather than `run`,
        because what they are about is its exit code -- and `main` reports an
        unreadable file on stderr, which `quiet` does not catch. Without it, a
        *passing* self-test printed three error lines: the argument
        docs/godot/reading-json-in-godot.md makes against the noisy JSON
        parser, made against this file.
        """
        with contextlib.redirect_stdout(io.StringIO()), \
                contextlib.redirect_stderr(io.StringIO()):
            return main(argv)

    def run_quietly(repo: pathlib.Path, retrain: set[str]) -> int:
        with contextlib.redirect_stdout(io.StringIO()):
            return run(repo, retrain=retrain)

    def quiet(repo: pathlib.Path) -> tuple[int, str]:
        stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            return run(repo, retrain=False), stream.getvalue()

    def build(root: pathlib.Path, name: str, files: dict[str, str]) -> pathlib.Path:
        repo = root / name
        for relative, text in files.items():
            path = repo / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        return repo

    sound = {
        str(LEARNING_ADDON / "learned_model.gd"): INFERENCE,
        str(WEIGHTS): json.dumps(SOUND_WEIGHTS),
        str(CLONE_WEIGHTS): json.dumps(SOUND_CLONE),
        str(OPPONENT_TREE): json.dumps(SOUND_TREE),
    }

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)

        # Inference beside a published weights file. This is the shape the
        # project promises and it must pass -- including the header above,
        # which says `gradient` in a comment about not having one.
        expect("inference only", quiet(build(root, "good", dict(sound))), 3)

        # Planted: the vocabulary of fitting, in code rather than in prose.
        expect("a learning rate in code", quiet(build(root, "rate", dict(
            sound, **{str(LEARNING_ADDON / "fitter.gd"):
                      "const learning_rate: float = 0.1\n"}))), 1, "N1")

        expect("a gradient in code", quiet(build(root, "grad", dict(
            sound, **{str(GODOT / "game" / "ai.gd"):
                      "var gradient: float = 0.0\n"}))), 1, "N1")

        # The same word in a comment is prose about training, not training.
        expect("a gradient in a comment", quiet(build(root, "comment", dict(
            sound, **{str(GODOT / "game" / "ai.gd"):
                      "# No gradient is computed here; see python/.\nvar steps: int = 0\n"}))), 3)

        # ...and in a string. The word has to be one the gate actually
        # looks for: this planted `"train_the_unit"` until a review pointed
        # out that `train` is deliberately absent from the vocabulary, so the
        # case passed whether or not strings were stripped at all.
        expect("a word inside a string", quiet(build(root, "string", dict(
            sound, **{str(GODOT / "game" / "domain.gd"):
                      'var label: String = "gradient of the hill"\n'}))), 3)

        # The planner's own domain, which is why `train` is not a word this
        # gate knows. A game that trains units is a game, not a fit.
        expect("the planner's domain", quiet(build(root, "domain", dict(
            sound, **{str(GODOT / "game" / "domain.gd"):
                      'var action: String = "train_the_unit"\n'}))), 3)

        # Planted: the inference addon writing a file.
        expect("the addon writes a file", quiet(build(root, "writes", dict(
            sound, **{str(LEARNING_ADDON / "saver.gd"):
                      'var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)\n'}))),
            1, "N2")

        # A file *read* is the addon's whole job.
        expect("the addon reads a file", quiet(build(root, "reads", dict(
            sound, **{str(LEARNING_ADDON / "loader.gd"):
                      'var file: FileAccess = FileAccess.open(path, FileAccess.READ)\n'}))), 3)

        # Planted: something outside the addon writing over the weights.
        expect("the game rewrites the weights", quiet(build(root, "rewrite", dict(
            sound, **{str(GODOT / "game" / "ai.gd"):
                      'var out: FileAccess = FileAccess.open("res://weights.json", FileAccess.WRITE)\n'}))),
            1, "N2")

        # Planted: the update step itself, under any name at all.
        expect("the update step", quiet(build(root, "update", dict(
            sound, **{str(GODOT / "game" / "ai.gd"):
                      "\tweights[index] -= rate * error\n"}))), 1, "N3")

        expect("writing another model's weights", quiet(build(root, "member", dict(
            sound, **{str(GODOT / "game" / "ai.gd"):
                      "\tmodel.weights = fresh\n"}))), 1, "N3")

        # Setting one's own fields in a constructor is how a model is built.
        expect("a constructor", quiet(build(root, "ctor", dict(sound))), 3)

        # Planted: the tactical game is there, and the weights it reads are not.
        expect("no weights file", quiet(build(root, "noweights", {
            str(TACTICAL_GAME / "learned_policy.gd"): INFERENCE})), 1, "N4")

        # Planted: weights nobody generated. The numbers may be perfect; what
        # is missing is any claim that a pipeline produced them.
        expect("hand-written weights", quiet(build(root, "byhand", dict(
            sound, **{str(WEIGHTS): json.dumps(
                dict(SOUND_WEIGHTS, generated_by="a person, carefully"))}))), 1, "N4")

        # No addon at all is the state of any checkout before T6, and of one
        # that took `ai_search` and left this behind: a note, not a finding.
        # Nothing infers, so nothing can be training to do it. Every case
        # above is what proves the gate can still fail.
        expect("no learning addon", quiet(build(root, "empty", {
            str(GODOT / "game" / "main.gd"): "var turn: int = 0\n"})), 0)

        # Planted: the two unreadable files. Both used to be a traceback on
        # exit 1, which every caller reads as a finding.
        broken = build(root, "brokenjson", dict(
            sound, **{str(WEIGHTS): "{ not json at all"}))
        expect("a weights file that is not JSON",
               (quietly(["--repo", str(broken), "--skip-retrain"]), ""), 2)

        unreadable = build(root, "notutf8", dict(sound))
        (unreadable / GODOT / "game" / "ai.gd").parent.mkdir(parents=True, exist_ok=True)
        (unreadable / GODOT / "game" / "ai.gd").write_bytes(b"var name := \xff\xfe\n")
        expect("a script that is not UTF-8",
               (quietly(["--repo", str(unreadable), "--skip-retrain"]), ""), 2)

        # Planted: every other way of writing a file. Only `FileAccess.WRITE`
        # had a case, so three of the four alternatives in WRITING_RE could be
        # deleted with the self-test green.
        for spelling in ['file.store_string("x")',
                         'ResourceSaver.save(thing, path)',
                         'FileAccess.open_encrypted(path, 2, key)',
                         'FileAccess.open(path, FileAccess.WRITE_READ)']:
            expect(f"the addon writing with {spelling[:20]}", quiet(build(
                root, "w" + str(abs(hash(spelling))), dict(
                    sound, **{str(LEARNING_ADDON / "saver.gd"): spelling + "\n"}))),
                1, "N2")

        # The vocabulary, written out. A loop over `FITTING_WORDS` -- which is
        # what this was first -- proves every word in the list fires, and
        # **cannot notice a word being deleted from the list**, because the
        # loop shrinks with it. Measured: dropping `backprop` left the
        # self-test green. So the words are named here as well, and the two
        # mechanisms catch different things: this one catches the list losing
        # an entry, the loop below catches an entry that does not work.
        named = {
            "gradient", "backprop", "backpropagate", "learning_rate", "epoch",
            "optimizer", "optimiser", "sgd", "standardise", "standardize",
        }
        if set(FITTING_WORDS) != named:
            failures.append(
                "the vocabulary has changed: "
                f"{sorted(set(FITTING_WORDS) ^ named)} -- a word added to the gate "
                "needs naming here too, and a word removed needs a reason")

        for word in sorted(FITTING_WORDS):
            # The word on its own, not as part of a longer identifier: the
            # rules match whole words, so `gradient_value` is not `gradient`
            # and planting that would have been ten cases proving nothing.
            expect(f"the word {word}", quiet(build(root, "word_" + word, dict(
                sound, **{str(GODOT / "game" / "fit.gd"): f"var value: float = {word}\n"}))),
                1, "N1")

        # Planted: the vendored exclusion. It was inert -- gdUnit4 happens to
        # contain none of these words -- so nothing would have noticed it
        # being deleted.
        vendored = str(GODOT / "addons" / "gdUnit4" / "src" / "Fitter.gd")
        expect("a forbidden word in vendored code", quiet(build(root, "vendored2", dict(
            sound, **{vendored: "var learning_rate: float = 0.1\n"}))), 3)

        # Planted (T83): the same word under godot/.godot/, the engine's
        # import cache -- the one dot folder inside what this gate reads
        # (godot/; a checkout's .user-data/ and .claude/worktrees/ lie
        # outside it, so planting there would prove nothing).
        stray = str(GODOT / ".godot" / "editor" / "Fitter.gd")
        expect("a forbidden word under godot/.godot", quiet(build(root, "dot-cache", dict(
            sound, **{stray: "var learning_rate: float = 0.1\n"}))), 3)
        # ... but a checkout that itself lives under .claude/worktrees is read.
        expect("a checkout under .claude/worktrees still read", quiet(build(
            root / ".claude" / "worktrees", "this-one", dict(
                sound, **{str(GODOT / "game" / "fit.gd"): "var value: float = learning_rate\n"}))),
            1, "N1")

        # Planted: the update step with the numbers called something else,
        # inside the addon. Thirty-four lines of real gradient descent got
        # past N1 to N3 during review by doing exactly this -- and a second
        # review then walked past the first fix with the other two spellings,
        # so all three are here. A case that pins one sentence rather than
        # the rule is the defect this file is most prone to.
        for spelling in ["\t_numbers[index] -= STEP * slope\n",
                         "\t_numbers[index] = _numbers[index] - STEP * slope\n",
                         "\t_numbers.set(index, _numbers[index] - STEP * slope)\n"]:
            expect(f"an update spelled {spelling.strip()[:28]}", quiet(build(
                root, "evasion" + str(abs(hash(spelling))), dict(
                    sound, **{str(LEARNING_ADDON / "fitter.gd"): spelling}))), 1, "N3")

        # ...and in the tactical adapter, which runs the model every decision
        # and left the addon in T60: the rules follow the inference, not the
        # folder. Planted after a review moved both lines into
        # `learned_policy.gd` and the gate said nothing.
        expect("an update in the tactical adapter", quiet(build(root, "adapterupdate", dict(
            sound, **{str(TACTICAL_GAME / "learned_policy.gd"):
                      "\t_numbers[index] = _numbers[index] - step\n"}))), 1, "N3")
        expect("the tactical adapter writing a file", quiet(build(root, "adapterwrite", dict(
            sound, **{str(TACTICAL_GAME / "learned_policy.gd"):
                      'var out: FileAccess = FileAccess.open("user://policy.json", FileAccess.WRITE)\n'}))), 1, "N2")

        # ...and the same lines outside the addon, which are ordinary code: a
        # running total, a score, a cost table in a search.
        for ordinary in ["\t_points[index] -= cost\n",
                         "\tg[step] = g[current] + graph.cost_at(step)\n"]:
            expect(f"ordinary code: {ordinary.strip()[:24]}", quiet(build(
                root, "tally" + str(abs(hash(ordinary))), dict(
                    sound, **{str(GODOT / "game" / "score.gd"): ordinary}))), 3)

        # ...and the two indexed writes the inference addon legitimately makes,
        # which must not become findings: neither reads its target back.
        for legitimate in ['\tloaded._models[name] = _model_from(entry)\n',
                           "\tseen[feature] = true\n"]:
            expect(f"the addon writing {legitimate.strip()[:24]}", quiet(build(
                root, "legit" + str(abs(hash(legitimate))), dict(
                    sound, **{str(LEARNING_ADDON / "loader.gd"): legitimate}))), 3)

        # Planted: a --repo that is not there at all.
        expect("a path that is not a repository",
               (quietly(["--repo", str(root / "nowhere")]), ""), 2)

        # The refits a wave asks for (T58). None asked: the shape rules alone,
        # and a pass is a pass. One asked that cannot run here: exit 3, as
        # the whole gate does. A rule it does not know is a usage error.
        subset = build(root, "subset", dict(sound))
        expect("no refit asked for", (run_quietly(subset, set()), ""), 0)
        expect("a refit asked for that cannot run", (run_quietly(subset, {"N4"}), ""), 3)
        expect("an unknown refit", (quietly(["--repo", str(subset), "--retrain", "N99"]), ""), 2)
        expect("a planted finding still found with no refit", (run_quietly(build(
            root, "subset-rate", dict(sound, **{str(LEARNING_ADDON / "x.gd"): "var learning_rate := 0.1\n"})),
            set()), ""), 1)

        # Planted: the call site of the dump rule, not only the rule. Deleting
        # the call left the self-test green, because the three cases below
        # reach the helper directly.
        wired = build(root, "wired", dict(sound))
        (wired / READABLE).write_text("what the pipeline writes\n")
        with contextlib.redirect_stdout(io.StringIO()):
            found, _ran = check_weights(
                wired, True, trained=(SOUND_WEIGHTS, "something else entirely\n"))
        if not any("weights.txt" in finding for finding in found):
            failures.append("check_weights never reached the readable dump")

        # Planted: a bead written in GDScript, every spelling of it. T28's
        # acceptance names the first: before N5, `beads[move] += 1` passed.
        # The rest are the ones a review walked past the first version with.
        game_file = str(GODOT / "game" / "tictactoe" / "menace_player.gd")
        for spelling in ["\tbeads[move] += 1\n",
                         "\tbox.beads[square] -= 1\n",
                         "\t_beads = PackedInt32Array([4, 4, 0, 0, 4, 0, 0, 0, 0])\n",
                         "\tbeads.set(square, beads[square] + 3)\n",
                         "\tbeads[square] = beads[square] + 3\n",
                         "\tsnapshot.beads.fill(0)\n",
                         "\t_boxes[box][square] += 3\n",
                         "\tplayer._snapshots[10][box][4] += 100\n",
                         "\t_snapshots[age][box] = PackedInt32Array([99, 0, 0, 0, 0, 0, 0, 0, 0])\n",
                         "\t_snapshots[age][box].set(square, 99)\n",
                         "\t_snapshots.clear()\n",
                         "\t_snapshots[age].merge(other)\n",
                         '\tplayer.set("_snapshots", {})\n',
                         "\tcounts[square] += 1\n",
                         "\tbead_counts[0] += 1\n",
                         "\tBEADS[0] = 1\n",
                         "\tbox[square] += 1\n",
                         "\tbeads.encode_s32(0, 99)\n",
                         "\tvar x := 0; beads[move] += 1\n",
                         "\tif true: beads[move] += 1\n",
                         "\tpass; beads[move] += 1\n",
                         # Statements after a dictionary literal closes: the
                         # key rule is for inside one only.
                         "\tvar values: Dictionary = {games = 3,\n\t\ttotal = 9}\n\tbead = 3\n",
                         "\tshow({games = 3})\n\tbeads[move] += 1\n",
                         # A write in a value inside the literal: only the
                         # key is taken off.
                         "\tvar values: Dictionary = {games = 3,\n\t\tbead = beads.append(1)}\n"]:
            expect(f"a bead written as {spelling.strip()[:34]}", quiet(build(
                root, "bead" + str(abs(hash(spelling))), dict(
                    sound, **{game_file: spelling, str(BEADS): json.dumps(SOUND_BEADS)}))),
                1, "N5")

        # ...and outside the game the wide mesh is off: a label's box in the
        # checkers view is not a matchbox.
        expect("a box elsewhere", quiet(build(root, "elsewhere", dict(
            sound, **{str(GODOT / "game" / "checkers" / "view.gd"): "\tboxes.append(rect)\n\tbox.position.y += 2.0\n",
                      str(CHECKERS_WEIGHTS): json.dumps(SOUND_CHECKERS)}))), 3)

        # Planted: the bead file written from GDScript.
        expect("the bead file written", quiet(build(root, "beadfile", dict(
            sound, **{str(GODOT / "game" / "ai.gd"):
                      'var out: FileAccess = FileAccess.open("res://game/tictactoe/menace_beads.json", FileAccess.WRITE)\n'}))),
            1, "N2")

        # ...and what reading the beads legitimately looks like: declarations,
        # a fresh row filled before it is made read-only, a constructor
        # setting its own store, a bead count read.
        for reading in ["\tvar beads: Array[int] = beads_for(age, board)\n",
                        "\tvar row: Array[int] = []\n\trow.assign(published[key])\n\ttable[key] = row\n",
                        "\t_snapshots = published\n",
                        "\tvar total: int = beads[square] + beads[0]\n",
                        "\tfor count: int in beads:\n\t\ttotal += count\n",
                        "\tif beads[0] <= 3 and beads[1] >= 2 and beads[2] != 0:\n\t\tpass\n",
                        '\tvar words: String = "beads[move] += 1"\n',
                        "\t# never beads[move] += 1 here\n",
                        # A Lua-style key continuing a dictionary literal, as
                        # wave 91's panel writes it for `.format()`.
                        '\tvar values: Dictionary = {games = 3,\n\t\t\tbead = overlay["bead"], total = 9}\n',
                        "\tshow({\n\t\tbeads = count,\n\t\tbox = 4,\n\t})\n"]:
            expect(f"reading beads: {reading.strip()[:30]}", quiet(build(
                root, "read" + str(abs(hash(reading))), dict(
                    sound, **{game_file: reading, str(BEADS): json.dumps(SOUND_BEADS)}))), 3)

        # Planted: the checkers weights written from GDScript, by name from
        # anywhere, and any file written from inside the checkers game.
        expect("the checkers weights written", quiet(build(root, "checkersfile", dict(
            sound, **{str(GODOT / "game" / "ai.gd"):
                      'var out: FileAccess = FileAccess.open("res://game/checkers/checkers_weights.json", FileAccess.WRITE)\n'}))),
            1, "N8")
        for spelling in ['var out: FileAccess = FileAccess.open(CheckersWeights.PATH, FileAccess.WRITE)\n',
                         'var out: FileAccess = FileAccess.open("res://game/checkers/" + name, FileAccess.WRITE)\n']:
            expect(f"the checkers weights written as {spelling[30:62]}", quiet(build(
                root, "checkersby" + str(abs(hash(spelling))), dict(sound, **{str(GODOT / "game" / "ai.gd"): spelling}))),
                1, "N8")
        expect("a file written in the checkers game", quiet(build(root, "checkersgame", dict(
            sound, **{str(CHECKERS_GAME / "checkers.gd"): 'var out: FileAccess = FileAccess.open(path, FileAccess.WRITE)\n'}))),
            1, "N8")
        # A test filed beside the game it tests is not the game: wave 63 put
        # the tests in godot/test/<module>/, and this one is checkers'.
        expect("a test in test/checkers/ writing a planted file", quiet(build(root, "checkerstest", dict(
            sound, **{str(GODOT / "test" / "checkers" / "weights_test.gd"):
                      'var out: FileAccess = FileAccess.open("user://planted.json", FileAccess.WRITE)\n'}))), 3)

        # Planted: the opponent model written down, from inside its addon and
        # by name from anywhere; and counting in the addon, which is allowed.
        expect("a file written in the opponent addon", quiet(build(root, "opponentaddon", dict(
            sound, **{str(OPPONENT_ADDON / "ngram_predictor.gd"):
                      'var out: FileAccess = FileAccess.open("user://table.json", FileAccess.WRITE)\n'}))),
            1, "N9")
        expect("an n-gram table saved from the game", quiet(build(root, "ngramsaved", dict(
            sound, **{str(GODOT / "game" / "ai.gd"):
                      'var out: FileAccess = FileAccess.open("user://ngram_table.json", FileAccess.WRITE)\n'}))),
            1, "N9")
        expect("the table saved by a script that holds one, under another name", quiet(build(root, "habits", dict(
            sound, **{str(GODOT / "game" / "fighting" / "learner.gd"):
                      'var watcher := FightModelOpponent.new("medium", data)\n'
                      'var out: FileAccess = FileAccess.open("user://habits.txt", FileAccess.WRITE)\n'}))),
            1, "N9")
        expect("the table saved through a ConfigFile", quiet(build(root, "habitsconfig", dict(
            sound, **{str(OPPONENT_ADDON / "keep.gd"): '\tvar config := ConfigFile.new()\n\tconfig.save("user://t.cfg")\n'}))),
            1, "N9")
        expect("the game writing over the cloned player", quiet(build(root, "clonewrite", dict(
            sound, **{str(GODOT / "game" / "fighting" / "keep.gd"):
                      'var out: FileAccess = FileAccess.open(FightCloneOpponent.PUBLISHED_PATH, FileAccess.WRITE)\n'}))),
            1, "N11")
        expect("the game writing over the opponent's tree", quiet(build(root, "treewrite", dict(
            sound, **{str(GODOT / "game" / "fighting" / "grow.gd"):
                      'var out: FileAccess = FileAccess.open(FightTreeOpponent.PUBLISHED_PATH, FileAccess.WRITE)\n'}))),
            1, "N17")
        expect("the opponent's tree written by its file name", quiet(build(root, "treename", dict(
            sound, **{str(GODOT / "game" / "fighting" / "prune.gd"):
                      'var out := FileAccess.open("res://game/fighting/opponent_tree.json", FileAccess.WRITE)\n'}))),
            1, "N17")
        expect("a ghost counting during the fight", quiet(build(root, "ghostcounts", dict(
            sound, **{str(GODOT / "game" / "fighting" / "ghost.gd"):
                      '\tplayer.cases.cases[key] = counts\n'}))),
            1, "N12")
        expect("a ghost's counts bumped in place", quiet(build(root, "ghostbumps", dict(
            sound, **{str(GODOT / "game" / "fighting" / "ghost.gd"):
                      '\tplayer.cases.cases[key]["jump"] += 1\n'}))),
            1, "N12")
        expect("reading a ghost's cases is not writing them", quiet(build(root, "ghostreads", dict(
            sound, **{str(GODOT / "game" / "fighting" / "ghost.gd"):
                      '\tvar seen: int = player.cases.cases.size()\n\tif player.cases.cases == {}:\n\t\tpass\n'}))),
            3)
        # Planted: the maze's MDP tables written from GDScript, by name from
        # anywhere and by the reader's constant, and any file from the maze game.
        expect("the MDP's policy written by name", quiet(build(root, "mdpbyname", dict(
            sound, **{str(GODOT / "game" / "ai.gd"):
                      'var out: FileAccess = FileAccess.open("res://../data/maze/policy.json", FileAccess.WRITE)\n'}))),
            1, "N15")
        expect("the MDP's values written through the reader's constant", quiet(build(root, "mdpbyconstant", dict(
            sound, **{str(GODOT / "test" / "maze" / "keep.gd"):
                      'var out := FileAccess.open(folder.path_join(MdpPacMan.VALUES_FILE), FileAccess.WRITE)\n'}))),
            1, "N15")
        expect("a file written in the maze game", quiet(build(root, "mazegame", dict(
            sound, **{str(MAZE_GAME / "mdp_pac_man.gd"): '\tvar out := FileAccess.open(path, FileAccess.WRITE)\n'}))),
            1, "N15")
        # Planted: the published values updated at game time -- the review's
        # three spellings inside the reader, one from a script holding it --
        # and the reader's own loading, which must stay allowed.
        reader = str(MAZE_GAME / "mdp_pac_man.gd")
        for spelling in ["\t_values[slot_of(game)] += 0.1 * (worth - _values[slot_of(game)])\n",
                         "\t_values[slot_of(game)] = worth\n",
                         "\t_values.set(slot_of(game), _values[slot_of(game)] + 0.1 * (worth - 1.0))\n"]:
            expect(f"the MDP's values updated: {spelling.strip()[:34]}", quiet(build(
                root, "mdpupdate" + str(abs(hash(spelling))), dict(
                    sound, **{reader: "static func q_value(game: MazeGame) -> float:\n" + spelling}))), 1, "N15")
        expect("the MDP's policy rewritten from a script that holds it", quiet(build(root, "mdpholder", dict(
            sound, **{str(GODOT / "game" / "pac.gd"):
                      "var mdp := MdpPacMan.new()\nfunc play() -> void:\n\tMdpPacMan._letters = \"\"\n"}))),
            1, "N15")
        # The tables sit in the maze game's folder, so a planted maze game
        # that should pass carries a sound pair of them.
        tables = {str(MDP_FOLDER / name): text for name, text in zip(MDP_FILES, SOUND_MDP)}
        expect("a typed declaration in the maze game is not a read-back", quiet(build(root, "mazedeclares", dict(
            sound, **tables, **{str(MAZE_GAME / "maze_ghost.gd"):
                      "\tvar open_ways: Array[Dictionary] = [_way(back, goal)] as Array[Dictionary]\n"}))), 3)
        expect("the MDP's tables read in by their loader", quiet(build(root, "mdploads", dict(
            sound, **tables, **{reader: "static func _load_tables() -> void:\n\t_values.append(1.0)\n"
                              "\t_letters = \"r\"\n"}))), 3)
        # Planted (N13): the bandit's counts saved from its addon, saved under
        # another name from a script that holds one, and moved a step towards
        # a target -- by a learning rate, and as an incremental mean; and
        # counting, which is what it is allowed to do.
        expect("a bandit that saves its counts", quiet(build(root, "banditsaves", dict(
            sound, **{str(BANDIT_ADDON / "bandit.gd"):
                      'var out: FileAccess = FileAccess.open("user://pulls.json", FileAccess.WRITE)\n'}))),
            1, "N13")
        expect("a bandit saved through a ConfigFile in its addon", quiet(build(root, "banditconfig", dict(
            sound, **{str(BANDIT_ADDON / "keep.gd"): '\tvar config := ConfigFile.new()\n\tconfig.save("user://b.cfg")\n'}))),
            1, "N13")
        expect("the counts saved under another name by a script that holds a bandit", quiet(build(root, "banditheld", dict(
            sound, **{str(GODOT / "game" / "fighting" / "keeper.gd"):
                      'var gambler := FightBanditOpponent.new("medium", data)\n'
                      'var out: FileAccess = FileAccess.open("user://answers.txt", FileAccess.WRITE)\n'}))),
            1, "N13")
        expect("a bandit saved as a resource", quiet(build(root, "banditresource", dict(
            sound, **{str(GODOT / "game" / "keeper.gd"):
                      'var arms := Bandit.new(3)\nfunc keep() -> void:\n\tResourceSaver.save(table, "user://t.tres")\n'}))),
            1, "N13")
        for spelling in ["\tvalues[arm] += rate * (payoff - values[arm])\n",
                         "\t_value -= (_value - payoff) * 0.1\n",
                         "\tmeans[arm] += (payoff - means[arm]) / pulls[arm]\n",
                         "\tmean += (payoff - mean)/n\n",
                         "\tmean = mean + (payoff - mean) / n\n",
                         "\tq[arm] = lerp(q[arm], payoff, 0.1)\n",
                         "\tvar delta: float = payoff - mean\n\tmean += delta / n\n"]:
            expect(f"a bandit's value stepped: {spelling.strip()[:36]}", quiet(build(
                root, "banditstep" + str(abs(hash(spelling))), dict(
                    sound, **{str(BANDIT_ADDON / "bandit.gd"): "func reward(arm: int, payoff: float) -> void:\n" + spelling}))),
                1, "N13")
        expect("an incremental mean in a script that holds a bandit", quiet(build(root, "bandithelder", dict(
            sound, **{str(GODOT / "game" / "fighting" / "fighter.gd"):
                      "var gambler: FightBanditOpponent\nfunc paid(x: float) -> void:\n\t_mean += (x - _mean) / _count\n"}))),
            1, "N13")
        expect("a bandit counting pulls and summing payoffs", quiet(build(root, "banditcounts", dict(
            sound, **{str(BANDIT_ADDON / "bandit.gd"):
                      "func reward(arm: int, payoff: float) -> void:\n\tpulls[arm] += 1\n"
                      "\tsums[arm] += clampf(payoff, 0.0, 1.0)\n\tvar lead: int = (after - before) * 2\n"
                      "\tcounted += pulled\n"}))),
            3)
        expect("a step outside the bandit's files is not N13's", quiet(build(root, "notabandit", dict(
            sound, **{str(GODOT / "game" / "steering.gd"): "\tposition += speed * (target - position)\n"}))),
            3)
        # Planted (N14): the player model saved, loaded at the start of a
        # match, moved by an Elo-style update, and kept as an incremental
        # mean; and counting, and the event log, which must pass.
        model = str(PLAYER_MODEL_FILE)
        expect("a player model that saves itself", quiet(build(root, "modelsaves", dict(
            sound, **{model: 'func keep() -> void:\n'
                      '\tvar out: FileAccess = FileAccess.open("user://skill.json", FileAccess.WRITE)\n'}))),
            1, "N14")
        expect("a player model saved by a script that holds one", quiet(build(root, "modelheld", dict(
            sound, **{str(GODOT / "game3d" / "botmatch" / "keeper.gd"):
                      'var reading := PlayerModel.new()\nfunc keep() -> void:\n'
                      '\tResourceSaver.save(table, "res://you.tres")\n'}))),
            1, "N14")
        for name, spelling in [
                ("from user://", '\tvar file: FileAccess = FileAccess.open("user://skill.json", FileAccess.READ)\n'),
                ("through a ConfigFile", '\tvar config := ConfigFile.new()\n\tconfig.load(PROFILE)\n'),
                ("as a resource", '\tvar kept: Resource = load(PROFILE)\n'),
                ("from the user folder", '\tvar path: String = OS.get_user_data_dir() + "/skill.json"\n')]:
            expect(f"a player model loaded at start, {name}", quiet(build(root, "modelloads" + name.split()[-1], dict(
                sound, **{str(GODOT / "game3d" / "botmatch" / "match_difficulty.gd"):
                          "var model := PlayerModel.new()\nfunc _init() -> void:\n" + spelling}))),
                1, "N14")
        for spelling in ["\trating += 32.0 * (won - expected)\n",
                         "\trating = rating + K * (won - expected)\n",
                         "\tskill += (hit - skill) / shots\n",
                         "\tvar surprise: float = won - expected\n\trating += surprise * 32.0\n"]:
            expect(f"a player model stepped: {spelling.strip()[:36]}", quiet(build(
                root, "modelstep" + str(abs(hash(spelling))), dict(
                    sound, **{model: "func count(won: float) -> void:\n" + spelling}))),
                1, "N14")
        match = str(GODOT / "game3d" / "botmatch" / "bot_match.gd")
        scene = str(GODOT / "game3d" / "botmatch" / "botmatch.gd")
        expect("the model's counts saved by the scene, which names only MatchDifficulty", quiet(build(
            root, "modelscene", dict(sound, **{scene: 'var difficulty: MatchDifficulty\nfunc keep() -> void:\n'
                                             '\tvar out: FileAccess = FileAccess.open("user://skill.json", '
                                             'FileAccess.WRITE)\n\tout.store_string(str(difficulty.model.counts()))\n'}))),
            1, "N14")
        expect("the model's counts loaded back by the scene", quiet(build(root, "modelsceneloads", dict(
            sound, **{scene: 'var difficulty: MatchDifficulty\nfunc restore() -> void:\n'
                      '\tdifficulty.model.dealt = int(FileAccess.get_file_as_string("user://skill.txt"))\n'}))),
            1, "N14")
        expect("an Elo update in the match that holds MatchDifficulty", quiet(build(root, "modelmatchelo", dict(
            sound, **{match: "var difficulty: MatchDifficulty = null\nfunc seen(won: float, expected: float) -> void:\n"
                      "\trating += 32.0 * (won - expected)\n"}))),
            1, "N14")
        for name, spelling in [
                ("as a string from res://", '\tdealt = int(FileAccess.get_file_as_string("res://profile.txt"))\n'),
                ("opened to read by a constant", '\tvar file: FileAccess = FileAccess.open(PROFILE, FileAccess.READ)\n'),
                ("preloaded", '\tvar kept: Resource = preload("res://profile.tres")\n'),
                ("as JSON", '\tvar kept: Variant = JSON.parse_string(text)\n')]:
            expect(f"a player model read back, {name}", quiet(build(root, "modelreads" + name.split()[-1], dict(
                sound, **{model: "func _init() -> void:\n" + spelling}))),
                1, "N14")
        for spelling in ["\tskill = skill * 0.9 + won * 0.1\n",
                         "\trating = rating + 32.0 * won - 32.0 * expected\n",
                         "\tmean = (mean * (shots - 1) + hit) / shots\n"]:
            expect(f"a player model stepped in its own file: {spelling.strip()[:36]}", quiet(build(
                root, "modelscales" + str(abs(hash(spelling))), dict(
                    sound, **{model: "func seen(won: float) -> void:\n" + spelling}))),
                1, "N14")
        expect("an Elo update with its difference named first, in MatchDifficulty", quiet(build(
            root, "modeldifference", dict(sound, **{str(PLAYER_MODEL_OWN[1]):
                                                  "func seen(won: float, expected: float) -> void:\n"
                                                  "\tvar surprise: float = won - expected\n\trating += surprise * 32.0\n"}))),
            1, "N14")
        expect("a moving average in a script that holds the model", quiet(build(root, "modelheldema", dict(
            sound, **{str(GODOT / "game3d" / "botmatch" / "keeper.gd"):
                      "var difficulty: MatchDifficulty\nfunc seen(won: float) -> void:\n"
                      "\tskill = 0.1 * won + skill * 0.9\n"}))),
            1, "N14")
        expect("a player model counting", quiet(build(root, "modelcounts", dict(
            sound, **{model: "func count(points: int) -> void:\n\tshots += 1\n\tdealt += points\n"
                      "\tvar share: float = (float(dealt) + prior) / (float(dealt + taken) + 2.0 * prior)\n"}))),
            3)
        expect("the event log written beside the match, not by the model", quiet(build(root, "eventlog", dict(
            sound, **{str(GODOT / "game3d" / "botmatch" / "match_event_log.gd"):
                      'const FOLDER: String = "user://botmatch-logs"\nfunc save(events: Array) -> void:\n'
                      '\tvar file: FileAccess = FileAccess.open(FOLDER + "/a.json", FileAccess.WRITE)\n'
                      '\tfile.store_string(JSON.stringify(events))\n'}))),
            3)
        expect("counting in the opponent addon", quiet(build(root, "opponentcounts", dict(
            sound, **{str(OPPONENT_ADDON / "ngram_predictor.gd"):
                      '\trow[action] = row.get(action, 0.0) + 1.0\n'}))), 3)

        failures += _self_test_the_beads(root)
        failures += _self_test_the_checkers_weights(root)
        failures += _self_test_the_clone_weights(root)
        failures += _self_test_the_opponent_tree(root)
        failures += _self_test_the_mdp_policy(root)
        failures += _self_test_the_dump(root)
        failures += _self_test_the_comparison()

        script = pathlib.Path(__file__).resolve()
        extra = subprocess.run(
            [sys.executable, str(script), "--unknown-flag"], capture_output=True)
        expect("unknown flag", (extra.returncode, ""), 2)

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


SOUND_BEADS = {
    "generated_by": "gameaikit.menace.report",
    "seed": 1961,
    "snapshots": {"10": {"games": 10, "boxes": {".........": [3, 17, 0, 0, 6, 0, 0, 0, 0]}}},
}


def _self_test_the_beads(root: pathlib.Path) -> list[str]:
    """N6, handed a run rather than training for a second each time.

    T28's acceptance names the second case: a published bead file that does
    not match its seed.
    """
    failures = []
    repo = root / "beads"
    (repo / BEADS).parent.mkdir(parents=True, exist_ok=True)
    (repo / BEADS).write_text(json.dumps(SOUND_BEADS))
    quietly = contextlib.redirect_stdout(io.StringIO())

    with quietly:
        found, ran = check_beads(repo, True, trained=json.loads(json.dumps(SOUND_BEADS)))
    if found or not ran:
        failures.append(f"beads that match their seed were reported: {found}")

    drifted = json.loads(json.dumps(SOUND_BEADS))
    drifted["snapshots"]["10"]["boxes"]["........."][4] = 7
    with contextlib.redirect_stdout(io.StringIO()):
        found, _ran = check_beads(repo, True, trained=drifted)
    if not any(finding.startswith("N6") for finding in found):
        failures.append(f"beads that do not match their seed were not reported: {found}")

    (repo / BEADS).write_text(json.dumps(dict(SOUND_BEADS, generated_by="a person")))
    with contextlib.redirect_stdout(io.StringIO()):
        found, _ran = check_beads(repo, False)
    if not any(finding.startswith("N6") for finding in found):
        failures.append("hand-written beads were not reported")

    (repo / BEADS).unlink()
    with contextlib.redirect_stdout(io.StringIO()):
        found, _ran = check_beads(repo, False)
    if not any(finding.startswith("N6") for finding in found):
        failures.append("a missing bead file beside the game was not reported")

    # The wiring, not only the rule: `run` must reach N6 at all.
    (repo / BEADS).write_text(json.dumps(dict(SOUND_BEADS, generated_by="a person")))
    with contextlib.redirect_stdout(io.StringIO()) as printed:
        code = run(repo, retrain=False)
    if code != 1 or "N6" not in printed.getvalue():
        failures.append("run() never reached the bead check")
    return failures


SOUND_CHECKERS = {
    "generated_by": "gameaikit.checkers.report",
    "features": ["men", "kings", "advancement"],
    "learned": {"weights": [0.629, 0.218, -0.212]},
    "learned_against_hand": [{"depth": 2, "games": 100, "won": 3, "drawn": 19, "lost": 78}],
}


def _self_test_the_checkers_weights(root: pathlib.Path) -> list[str]:
    """N7, handed a run rather than self-playing for forty seconds each time.
    T32 asks for the case of weights that do not match their seed."""
    failures = []
    repo = root / "checkers"
    (repo / CHECKERS_WEIGHTS).parent.mkdir(parents=True, exist_ok=True)
    (repo / CHECKERS_WEIGHTS).write_text(json.dumps(SOUND_CHECKERS))
    with contextlib.redirect_stdout(io.StringIO()):
        found, ran = check_checkers_weights(repo, True, trained=json.loads(json.dumps(SOUND_CHECKERS)))
    if found or not ran:
        failures.append(f"checkers weights that match their seed were reported: {found}")

    for where, value in (("weights", [0.629, 0.218, 0.05]), ("match", 4)):
        drifted = json.loads(json.dumps(SOUND_CHECKERS))
        if where == "weights":
            drifted["learned"]["weights"] = value
        else:
            drifted["learned_against_hand"][0]["won"] = value
        with contextlib.redirect_stdout(io.StringIO()):
            found, _ran = check_checkers_weights(repo, True, trained=drifted)
        if not any(finding.startswith("N7") for finding in found):
            failures.append(f"checkers {where} that do not match their seed were not reported: {found}")

    (repo / CHECKERS_WEIGHTS).write_text(json.dumps(dict(SOUND_CHECKERS, generated_by="a person")))
    with contextlib.redirect_stdout(io.StringIO()):
        found, _ran = check_checkers_weights(repo, False)
    if not any(finding.startswith("N7") for finding in found):
        failures.append("hand-written checkers weights were not reported")

    (repo / CHECKERS_WEIGHTS).unlink()
    with contextlib.redirect_stdout(io.StringIO()):
        found, _ran = check_checkers_weights(repo, False)
    if not any(finding.startswith("N7") for finding in found):
        failures.append("a missing checkers weights file beside the game was not reported")

    # A pipeline that could not be run checked nothing, and `run` must say so
    # with its own exit code rather than pass.
    (repo / CHECKERS_WEIGHTS).write_text(json.dumps(SOUND_CHECKERS))
    global fresh_checkers_weights
    real, fresh_checkers_weights = fresh_checkers_weights, lambda _repo: None
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            code = run(repo, retrain=True)
    finally:
        fresh_checkers_weights = real
    if code != 3:
        failures.append(f"run() passed with the checkers pipeline unable to run: exit {code}")

    # The wiring, not only the rule: `run` must reach N7 at all.
    (repo / CHECKERS_WEIGHTS).write_text(json.dumps(dict(SOUND_CHECKERS, generated_by="a person")))
    with contextlib.redirect_stdout(io.StringIO()) as printed:
        code = run(repo, retrain=False)
    if code != 1 or "N7" not in printed.getvalue():
        failures.append("run() never reached the checkers weights check")
    return failures


SOUND_CLONE = {
    "generated_by": "gameaikit.cloning.publish",
    "trained_on": {"player": "person", "recordings": ["one.json"], "held_out": ["two.json"], "rows": 2},
    "model": {"kind": "softmax", "weights": [[0.25, -0.5], [-0.25, 0.5]], "bias": [0.0, 0.0]},
    "cases": {"close | nothing": {"throw": 2}},
}


def _self_test_the_clone_weights(root: pathlib.Path) -> list[str]:
    """N10, handed a fit rather than running one: a matching file passes, a
    drifted weight, a hand-written file and a pipeline that cannot run do not."""
    failures = []
    repo = root / "clone"
    (repo / CLONE_WEIGHTS).parent.mkdir(parents=True, exist_ok=True)
    (repo / CLONE_WEIGHTS).write_text(json.dumps(SOUND_CLONE))
    with contextlib.redirect_stdout(io.StringIO()):
        found, ran = check_clone_weights(repo, True, trained=json.loads(json.dumps(SOUND_CLONE)))
    if found or not ran:
        failures.append(f"a cloned player that matches its fit was reported: {found}")
    drifted = json.loads(json.dumps(SOUND_CLONE))
    drifted["model"]["weights"][1][0] = 0.75
    with contextlib.redirect_stdout(io.StringIO()):
        found, _ran = check_clone_weights(repo, True, trained=drifted)
    if not any(finding.startswith("N10") for finding in found):
        failures.append(f"a cloned weight that does not match its fit was not reported: {found}")
    (repo / CLONE_WEIGHTS).write_text(json.dumps(dict(SOUND_CLONE, generated_by="a person")))
    with contextlib.redirect_stdout(io.StringIO()) as printed:
        code = run(repo, retrain=False)
    if code != 1 or "N10" not in printed.getvalue():
        failures.append("run() never reached the cloned player check, or passed a hand-written one")
    (repo / CLONE_WEIGHTS).unlink()
    with contextlib.redirect_stdout(io.StringIO()):
        found, _ran = check_clone_weights(repo, False)
    if not any(finding.startswith("N10") for finding in found):
        failures.append("a missing cloned player beside the inference addon was not reported")
    (repo / CLONE_WEIGHTS).write_text(json.dumps(SOUND_CLONE))
    with contextlib.redirect_stdout(io.StringIO()):
        found, ran = check_clone_weights(repo, True)
    if found or ran:
        failures.append("a cloned player whose pipeline could not run was not reported as unchecked")
    return failures


SOUND_TREE = {
    "generated_by": "gameaikit.cloning.opponent_tree",
    "trained_on": {"player": "person", "recordings": ["one.json"], "held_out": ["two.json"], "rows": 3},
    "models": {"next action": {"kind": "tree", "features": ["distance"], "classes": ["high", "throw"],
                               "nodes": [{"feature": "distance", "is": "close", "yes": 1, "no": 2},
                                         {"counts": {"throw": 2}}, {"counts": {"high": 1}}]}},
}


def _self_test_the_opponent_tree(root: pathlib.Path) -> list[str]:
    """N16, handed a fit rather than running one: a matching tree passes; a
    moved test, a hand-written file, a missing one and a pipeline that
    cannot run do not."""
    failures = []
    repo = root / "tree"
    (repo / OPPONENT_TREE).parent.mkdir(parents=True, exist_ok=True)
    (repo / OPPONENT_TREE).write_text(json.dumps(SOUND_TREE))
    with contextlib.redirect_stdout(io.StringIO()):
        found, ran = check_opponent_tree(repo, True, trained=json.loads(json.dumps(SOUND_TREE)))
    if found or not ran:
        failures.append(f"an opponent tree that matches its fit was reported: {found}")
    moved = json.loads(json.dumps(SOUND_TREE))
    moved["models"]["next action"]["nodes"][0]["is"] = "far"
    with contextlib.redirect_stdout(io.StringIO()):
        found, _ran = check_opponent_tree(repo, True, trained=moved)
    if not any(finding.startswith("N16") for finding in found):
        failures.append(f"a test that does not match its fit was not reported: {found}")
    (repo / OPPONENT_TREE).write_text(json.dumps(dict(SOUND_TREE, generated_by="a person")))
    with contextlib.redirect_stdout(io.StringIO()) as printed:
        code = run(repo, retrain=False)
    if code != 1 or "N16" not in printed.getvalue():
        failures.append("run() never reached the opponent tree check, or passed a hand-written one")
    (repo / OPPONENT_TREE).unlink()
    with contextlib.redirect_stdout(io.StringIO()):
        found, _ran = check_opponent_tree(repo, False)
    if not any(finding.startswith("N16") for finding in found):
        failures.append("a missing opponent tree beside the fighting game was not reported")
    (repo / OPPONENT_TREE).write_text(json.dumps(SOUND_TREE))
    with contextlib.redirect_stdout(io.StringIO()):
        found, ran = check_opponent_tree(repo, True)
    if found or ran:
        failures.append("an opponent tree whose pipeline could not run was not reported as unchecked")
    return failures


SOUND_MDP = ('{"generated_by": "gameaikit.mdp.publish", "values": [[1250, null]]}\n',
             '{"generated_by": "gameaikit.mdp.publish", "actions": ["r."]}\n')


def _self_test_the_mdp_policy(root: pathlib.Path) -> list[str]:
    """N15, handed a solve rather than running one: matching files pass; a
    policy edited by hand, a hand-written file, a missing one and a solver
    that cannot run do not."""
    failures = []
    repo = root / "mdp"
    (repo / MDP_FOLDER).mkdir(parents=True, exist_ok=True)
    for name, text in zip(MDP_FILES, SOUND_MDP):
        (repo / MDP_FOLDER / name).write_text(text)
    with contextlib.redirect_stdout(io.StringIO()):
        found, ran = check_mdp_policy(repo, True, solved=SOUND_MDP)
    if found or not ran:
        failures.append(f"MDP tables that match their solve were reported: {found}")
    (repo / MDP_FOLDER / MDP_FILES[1]).write_text(SOUND_MDP[1].replace('"r."', '"l."'))
    with contextlib.redirect_stdout(io.StringIO()):
        found, _ran = check_mdp_policy(repo, True, solved=SOUND_MDP)
    if not any(finding.startswith("N15") and "policy.json" in finding for finding in found):
        failures.append(f"a policy edited by hand was not reported: {found}")
    (repo / MDP_FOLDER / MDP_FILES[0]).write_text(SOUND_MDP[0].replace("gameaikit.mdp.publish", "a person"))
    with contextlib.redirect_stdout(io.StringIO()) as printed:
        code = run(repo, retrain=False)
    if code != 1 or "N15" not in printed.getvalue():
        failures.append("run() never reached the MDP check, or passed a hand-written table")
    (repo / MDP_FOLDER / MDP_FILES[0]).unlink()
    with contextlib.redirect_stdout(io.StringIO()):
        found, _ran = check_mdp_policy(repo, False)
    if not any(finding.startswith("N15") for finding in found):
        failures.append("a missing MDP table was not reported")
    for name, text in zip(MDP_FILES, SOUND_MDP):
        (repo / MDP_FOLDER / name).write_text(text)
    with contextlib.redirect_stdout(io.StringIO()):
        found, ran = check_mdp_policy(repo, True)
    if found or ran:
        failures.append("MDP tables whose solver could not run were not reported as unchecked")
    return failures


def _self_test_the_dump(root: pathlib.Path) -> list[str]:
    """The readable half, handed text rather than a four-second pipeline.

    Separate from the self-test's other cases because they all run with
    `--skip-retrain`, which is exactly the path that does not reach this rule
    -- so a case written up there would have proved nothing.
    """
    failures = []
    repo = root / "dump"
    (repo / READABLE).parent.mkdir(parents=True, exist_ok=True)

    (repo / READABLE).write_text("what the model learned\n")
    if _differences_in_the_dump(repo, "what the model learned\n"):
        failures.append("a dump that matches the pipeline was reported as drifted")

    if not _differences_in_the_dump(repo, "trained on 999999 games\n"):
        failures.append("a dump the pipeline did not write was not reported")

    (repo / READABLE).unlink()
    if not _differences_in_the_dump(repo, "anything at all\n"):
        failures.append("a missing dump was not reported")
    return failures


def _self_test_the_comparison() -> list[str]:
    """N4's own rule, handed two reports rather than a four-second pipeline."""
    failures = []
    fresh = json.loads(json.dumps(SOUND_WEIGHTS))

    if differences_between(SOUND_WEIGHTS, fresh, "w"):
        failures.append("two identical reports were reported as different")

    drifted = json.loads(json.dumps(SOUND_WEIGHTS))
    drifted["models"]["combat"]["weights"][0] = 0.5082
    if not differences_between(SOUND_WEIGHTS, drifted, "w"):
        failures.append("a weight that moved was not reported")

    rounded = json.loads(json.dumps(SOUND_WEIGHTS))
    rounded["models"]["combat"]["bias"] = 3.3937004
    if differences_between(SOUND_WEIGHTS, rounded, "w"):
        failures.append("a difference inside the published rounding was reported")

    renamed = json.loads(json.dumps(SOUND_WEIGHTS))
    renamed["feature_conventions"] = {"nearby_distance": 2}
    if len(differences_between(SOUND_WEIGHTS, renamed, "w")) != 2:
        failures.append("a renamed convention was not reported as both a loss and a gain")

    counted = json.loads(json.dumps(SOUND_WEIGHTS))
    counted["models"]["combat"]["weights"].append(0.0)
    if not differences_between(SOUND_WEIGHTS, counted, "w"):
        failures.append("a weight appearing from nowhere was not reported")

    # A count republished as a float is the same number and a different
    # artifact. `math.isclose` called them equal until a review asked.
    retyped = json.loads(json.dumps(SOUND_WEIGHTS))
    retyped["games"] = float(retyped["games"])
    if not differences_between(SOUND_WEIGHTS, retyped, "w"):
        failures.append("a number republished as a float was not reported")
    return failures


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("--repo", default=None)
    parser.add_argument("--skip-retrain", action="store_true")
    parser.add_argument("--retrain", default=None,
                        help="refit only these, comma-separated: " + ",".join(RETRAINING))
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        if exit_request.code == 0:
            raise
        return 2

    if args.self_test:
        return self_test()

    repo = pathlib.Path(args.repo or pathlib.Path(__file__).resolve().parent.parent)
    # A typo'd path used to come back as a confident green, by way of the
    # "no addon here yet" note. *Does this pass on an empty scene* is the
    # question invariant 4 asks of every gate, and this one answered yes.
    if not repo.is_dir():
        print(f"check_no_training: no such directory: {repo}", file=sys.stderr)
        return 2
    try:
        if args.retrain is not None:
            wanted = {rule for rule in args.retrain.split(",") if rule}
            if wanted - set(RETRAINING):
                print(f"check_no_training: --retrain knows {', '.join(RETRAINING)}", file=sys.stderr)
                return 2
            return run(repo, retrain=wanted)
        return run(repo, retrain=not args.skip_retrain)
    except (OSError, ValueError) as error:
        # ValueError as well as OSError, and the docstring promised it before
        # the code did. A malformed weights.json raises JSONDecodeError and a
        # .gd file that is not UTF-8 raises UnicodeDecodeError; both are
        # ValueErrors, both used to come out as a traceback on exit 1 -- the
        # code reserved for "violations found, each one printed", which is
        # indistinguishable from a finding to every caller.
        print(f"check_no_training: cannot read a file: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
