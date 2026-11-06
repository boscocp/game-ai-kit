#!/usr/bin/env python3
"""Write the catalogue of the demos and the AI in each, and hold it to the code.

What it writes
--------------
T76. The owner asked for one table, both ways: every demo with the AI
techniques it uses, and every technique with the demos it appears in --
"pois o foco aqui é a IA". The same answer used to be written by hand three
times (the README's table, `docs/godot/examples.md`'s list, the help of each
`demo-*` target), and each copy drifted. Here it is generated:

  * `docs/techniques/catalogue.md` and `catalogue.pt-BR.md`: the matrix of
    demo by technique, a line per demo (its command, the known game it is
    like, the keys that show the decision, its techniques and the
    algorithms of each), and a line per technique (the demos it appears in);
  * a short summary of the two, between `<!-- catalogue:summary -->` and
    `<!-- /catalogue:summary -->` in `README.md` and `README.pt-BR.md`.

What "a demo uses a technique" means here, measured
---------------------------------------------------
A demo is a `run` or `demo-*` target of the Makefile with a `##` help line;
the scene its recipe opens says which example module it is. The candidates
are the techniques that module's manifest declares in `depends_on`, directly
or through another example it depends on (`demo_behaviour` -> `stealth`).
A declaration alone is not enough: `checkers` declares `ai_learning` because
its Python trains the evaluation with it, and the game never touches it. So
each candidate is classified by what the scene reaches, file by file, read
with the rule `check_demos.py` holds the menu's cards to: a class counts
when the code constructs it, calls it or extends it, a `res://` path when
it names a script or a scene; comments, strings, type annotations and
constant reads do not count, and tests are left out:

  ●  the demo's own code reaches it;
  ◐  only another example's code reaches it -- the line names which;
  ○  its own manifest declares it and nothing the scene reaches uses it.

The algorithms come from the demo's card in the menu
(`godot/menu/catalogue.json`), whose evidence classes `check_demos.py`
already holds to the scene: each is filed under the technique whose code
holds the evidence class the scene reaches -- a non-module technique's
files first, then a technique module -- or under "written inside the
example itself" when that class is the example's own (tic-tac-toe's
perfect play is a minimax the game writes for itself).

What a reading cannot see: a script loaded from a path built at run time,
and whether a branch that uses a class is ever taken. The second is each
card's manual check.

A technique that is not a module (`non_module_techniques.json`) is marked ●
on the demos that file names, and a demo whose scene never reaches one of
the technique's Godot scripts is a finding -- the scene file itself does
not count, or a technique living in the scene's folder would always pass.

The rules, one finding each
---------------------------
  C0  no demo target in the Makefile -- a catalogue of nothing
  C1  a committed page or README summary that differs from what is generated
  C2  a technique with no page in both languages, so its column links nowhere
  C3  a demo missing from games.json, an entry naming no demo, or an entry
      missing a field or a language
  C4  a README without exactly one pair of summary markers, in order
  C5  a demo whose recipe opens no scene, or a scene no module owns
  C6  a non-module technique naming a demo that is not a target, or one whose
      scene never reaches the technique's Godot scripts
  C7  an algorithm on a demo's menu card with no short name in games.json in
      both languages, or a name for an algorithm no card lists
  C8  a key games.json gives for a demo that its target's `##` help line
      does not name: the two say the same thing, so one is held to the other

Exit codes
----------
0   written, or (--check) every page as it would be written
1   a finding
2   wrong usage, or a manifest or page that cannot be read

Usage
-----
    catalogue.py [--root PATH]            write the pages and the summaries
    catalogue.py --check [--root PATH]    fail when any of them is stale
    catalogue.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import dataclasses
import io
import json
import pathlib
import re
import shutil
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import check_demos  # noqa: E402 -- what a scene reaches by use, the menu cards' rule
import check_modules  # noqa: E402 -- the manifests, and who owns a file
from check_modules import owner_of  # noqa: E402

PAGES = pathlib.PurePosixPath("docs/techniques")
GAMES = PAGES / "games.json"
NON_MODULE = PAGES / "non_module_techniques.json"
MENU = "godot/menu/catalogue.json"
LANGUAGES = ("en", "pt-BR")
SUFFIX = {"en": ".md", "pt-BR": ".pt-BR.md"}
CATALOGUE = {language: PAGES / f"catalogue{SUFFIX[language]}" for language in LANGUAGES}
README = {"en": "README.md", "pt-BR": "README.pt-BR.md"}
OPEN = "<!-- catalogue:summary -->"
CLOSE = "<!-- /catalogue:summary -->"
GAME_FIELDS = ("game", "like", "keys")

DIRECT, THROUGH, OFFLINE = "●", "◐", "○"
# The column for an algorithm the example writes for itself.
INSIDE = ""
DEMO_RE = re.compile(r"^(run|demo-[\w-]+):[^#\n]*##[ \t]*(.*)$", re.M)
SCENE_RE = re.compile(r"res://([\w./-]+\.tscn)")


class Unreadable(Exception):
    """A manifest, page or input that cannot be read: exit 2, not a finding."""


@dataclasses.dataclass(frozen=True)
class Technique:
    """One column: a page name, and its title's two halves in each language."""

    page: str
    name: dict[str, str]
    decides: dict[str, str]


@dataclasses.dataclass
class Demo:
    """One row: its target, its module, and how it reaches each technique.

    `uses` maps a technique's page to (mark, the example it is reached
    through, or "" when the mark needs no name). `algorithms` maps a page,
    or INSIDE, to the keys of the menu card's algorithms filed under it.
    """

    target: str
    module: str
    uses: dict[str, tuple[str, str]]
    algorithms: dict[str, list[str]]
    text: dict[str, dict[str, str]]


@dataclasses.dataclass
class Catalogue:
    """Everything the pages are written from, and what was found on the way."""

    techniques: list[Technique]
    demos: list[Demo]
    names: dict[str, dict[str, str]]
    verified_on: str
    findings: list[str]


# --- reading -----------------------------------------------------------------


def read_json(path: pathlib.Path) -> dict:
    """A JSON file, or Unreadable naming it."""
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise Unreadable(f"{path}: {error}") from error


def load_modules(root: pathlib.Path) -> dict[str, check_modules.Module]:
    """The manifests, through the gate that already holds them to the tree."""
    try:
        return check_modules.load_modules(root)
    except check_modules.BadManifest as error:
        raise Unreadable(f"modules/: {error}") from error


def demo_targets(root: pathlib.Path) -> list[tuple[str, str | None, str]]:
    """(target, the scene its recipe opens or None, its help line), in order.

    The scene is relative to `godot/`, as `res://` paths are.
    """
    try:
        text = (root / "Makefile").read_text(encoding="utf-8")
    except OSError as error:
        raise Unreadable(f"Makefile: {error}") from error
    targets = []
    for target, help_line in DEMO_RE.findall(text):
        scene = SCENE_RE.search(check_modules.recipe(text, target))
        targets.append((target, scene.group(1) if scene else None, help_line))
    return targets


def page_title(root: pathlib.Path, page: str, language: str) -> tuple[str, str] | None:
    """A technique page's title, split at its dash: (name, what it decides)."""
    path = root / PAGES / f"{page}{SUFFIX[language]}"
    if not path.is_file():
        return None
    first = path.read_text(encoding="utf-8").split("\n", 1)[0].lstrip("# ").strip()
    name, _, decides = first.partition(" — ")
    return name, decides


def technique_pages(root: pathlib.Path, modules: dict) -> tuple[list[Technique], list[str]]:
    """Every column, modules first then the non-module ones, and C2's findings."""
    pages = sorted(name for name, module in modules.items() if module.kind == "technique")
    pages += [entry["page"] for entry in non_module(root)]
    techniques, findings = [], []
    for page in pages:
        titles = {language: page_title(root, page, language) for language in LANGUAGES}
        for language, title in titles.items():
            if title is None:
                findings.append(f"{PAGES}/{page}{SUFFIX[language]}: C2 the technique {page} "
                                f"has no page in {language}, so its column links nowhere")
        techniques.append(Technique(
            page,
            {language: (title or (page, ""))[0] for language, title in titles.items()},
            {language: (title or (page, ""))[1] for language, title in titles.items()}))
    return techniques, findings


def non_module(root: pathlib.Path) -> list[dict]:
    """The techniques that live in Python and a demo, as T74 declared them."""
    path = root / NON_MODULE
    if not path.exists():
        return []
    try:
        return read_json(path)["techniques"]
    except (KeyError, TypeError) as error:
        raise Unreadable(f"{path}: {error!r}") from error


def menu(root: pathlib.Path) -> tuple[dict, dict]:
    """The menu's algorithms, by key, and its cards, by target.

    No menu is no cards: the catalogue then names techniques without their
    algorithms, and `check_demos.py` is the gate that says a card is missing.
    """
    path = root / MENU
    if not path.exists():
        return {}, {}
    raw = read_json(path)
    try:
        return dict(raw["techniques"]), {card["target"]: card for card in raw["examples"]}
    except (KeyError, TypeError) as error:
        raise Unreadable(f"{path}: {error!r}") from error


# --- what a scene reaches ----------------------------------------------------


class SceneCode:
    """The project's Godot code, read the way check_demos.py reads it.

    One rule for "this scene uses that class" across the kit: the menu's
    cards are held to it already, and a catalogue that counted a type
    annotation as a use would disagree with them about the same scene.
    """

    def __init__(self, root: pathlib.Path) -> None:
        """Every class in the project, tests left out, to the script declaring it."""
        self.root = root
        self.classes = check_demos.project_classes(root)
        self._named: dict[str, set[str]] = {}

    def named_by(self, path: str) -> set[str]:
        """The scripts and scenes one file reaches by use, relative to godot/."""
        if path not in self._named:
            self._named[path] = check_demos.references_of(self.root, path, self.classes)
        return self._named[path]


def scene_reach(code: SceneCode, modules: dict, scene: str,
                rulesets: tuple[str, ...] = ()) -> tuple[dict[str, set[str]], set[str]]:
    """The modules a scene reaches, each with the examples it came through,
    and every script it reaches (repository paths, the scene itself not one).

    `rulesets` are the scripts of the card's modes (T85): the menu builds each
    and hands it to the scene, so they are walked from as the scene is --
    `check_demos.py` counts them the same way (wave 142's review: the XCOM
    mode's techniques were on the card and missing from the catalogue).

    "" in a module's set means the demo's own code reached it. A file is
    visited once per example it is reached through, so the answer does not
    depend on which way round the walk went first.
    """
    own = owner_of(f"godot/{scene}", modules)
    reached: dict[str, set[str]] = {}
    seen = {(path, "") for path in (scene, *rulesets)}
    waiting = sorted(seen)
    while waiting:
        path, through = waiting.pop()
        owner = owner_of(f"godot/{path}", modules)
        if owner is None:
            continue
        if modules[owner].kind != "example":
            reached.setdefault(owner, set()).add(through)
        else:
            through = through or ("" if owner == own else owner)
        for following in code.named_by(path):
            if (following, through) not in seen:
                seen.add((following, through))
                waiting.append((following, through))
    return reached, {f"godot/{path}" for path, _ in seen if path.endswith(".gd")}


def declared(modules: dict, name: str) -> tuple[set[str], set[str]]:
    """(the techniques a module declares itself, those its examples declare)."""
    own = {other for other in modules[name].depends_on if modules[other].kind == "technique"}
    inherited: set[str] = set()
    for other in modules[name].depends_on:
        if modules[other].kind == "example":
            theirs, further = declared(modules, other)
            inherited |= theirs | further
    return own, inherited - own


def marks(modules: dict, name: str, reached: dict[str, set[str]]) -> dict[str, tuple[str, str]]:
    """Each declared technique's mark for one demo, from what its scene reached.

    A technique an example further down declares and the scene never reaches
    is left out rather than marked ○: it is that example's business.
    """
    own, inherited = declared(modules, name)
    found = {}
    for technique in sorted(own | inherited):
        ways = reached.get(technique, set())
        if "" in ways:
            found[technique] = (DIRECT, "")
        elif ways:
            found[technique] = (THROUGH, min(ways))
        elif technique in own:
            found[technique] = (OFFLINE, "")
    return found


def reaches(visited: set[str], path: str) -> bool:
    """True when a visited file is `path`, or inside it when it is a folder."""
    folder = path.rstrip("/") + "/"
    return path in visited or any(file.startswith(folder) for file in visited)


def column_of(path: str, modules: dict, entries: list[dict]) -> str:
    """The column a script belongs to: a non-module technique naming it, then
    the technique module owning it, else INSIDE -- the example's own code."""
    for entry in entries:
        if any(reaches({path}, lives) for lives in entry.get("lives_in", [])):
            return entry["page"]
    owner = owner_of(path, modules)
    return owner if owner and modules[owner].kind == "technique" else INSIDE


def file_algorithms(card: dict | None, algorithms: dict, code: SceneCode, scripts: set[str],
                    modules: dict, entries: list[dict]) -> dict[str, list[str]]:
    """Each algorithm a demo's card names, filed under the column whose code runs it.

    An algorithm whose evidence is both in a technique and in the example's
    own code is the technique's: the example only wires it.
    """
    filed: dict[str, list[str]] = {}
    for entry in (card or {}).get("techniques", []):
        key = entry.get("technique", "")
        evidence = [f"godot/{code.classes[name]}" for name in algorithms.get(key, {}).get("evidence", [])
                    if name in code.classes]
        columns = [column_of(path, modules, entries) for path in evidence if path in scripts]
        named = [column for column in columns if column != INSIDE]
        for column in dict.fromkeys(named or columns):
            filed.setdefault(column, []).append(key)
    return filed


# --- the catalogue -----------------------------------------------------------


def games(root: pathlib.Path) -> tuple[dict, dict, str]:
    """games.json's entries by target, its algorithm names, and the day checked."""
    raw = read_json(root / GAMES)
    try:
        return dict(raw["demos"]), dict(raw.get("algorithms", {})), str(raw["verified_on"])
    except (KeyError, TypeError, ValueError) as error:
        raise Unreadable(f"{root / GAMES}: {error!r}") from error


def text_of(entry: object, field: str, language: str) -> str:
    """One field of a games.json entry in one language, or "" when missing."""
    value = entry.get(field) if isinstance(entry, dict) else None
    return str(value.get(language, "")).strip() if isinstance(value, dict) else ""


def game_findings(entries: dict, targets: list[str]) -> list[str]:
    """C3: games.json against the demos the Makefile has."""
    findings = [f"{GAMES}: C3 {target} is a demo with no entry; give the known game it is like, and its keys"
                for target in targets if target not in entries]
    findings += [f"{GAMES}: C3 {target} names no run or demo-* target with a ## help line"
                 for target in entries if target not in targets]
    findings += [f"{GAMES}: C3 {target} has no {field} in {language}"
                 for target, entry in entries.items() if target in targets
                 for field in GAME_FIELDS for language in LANGUAGES
                 if not text_of(entry, field, language)]
    return findings


def key_tokens(keys: str) -> list[str]:
    """The key each `;` clause of a keys line opens with: what a person presses."""
    return [clause.split()[0] for clause in keys.split(";") if clause.split()]


def key_findings(entries: dict, helps: dict[str, str]) -> list[str]:
    """C8: every key games.json names for a demo is one its help line names.

    The keys are a selection of the help line, the ones that show the AI
    deciding, so the help line is the authority: a key renamed in the
    Makefile and not here would send a reader to press the wrong one.
    """
    findings = []
    for target, help_line in helps.items():
        for token in key_tokens(text_of(entries.get(target), "keys", "en")):
            if not re.search(rf"(?<![\w-]){re.escape(token)}(?![\w-])", help_line, re.I):
                findings.append(f"{GAMES}: C8 {target}'s keys name {token!r}, and its make help "
                                f"line does not: {help_line!r}")
    return findings


def name_findings(demos: list[Demo], names: dict) -> list[str]:
    """C7: a short name, in both languages, for each algorithm a card lists, and no more."""
    listed = {key for demo in demos for keys in demo.algorithms.values() for key in keys}
    findings = [f"{GAMES}: C7 the menu card's algorithm {key!r} has no short name in {language}"
                for key in sorted(listed) for language in LANGUAGES if not text_of(names, key, language)]
    findings += [f"{GAMES}: C7 {key!r} names an algorithm no demo's card lists"
                 for key in sorted(set(names) - listed)]
    return findings


def build_demos(root: pathlib.Path, modules: dict, entries: dict) -> tuple[list[Demo], list[str]]:
    """Every demo the Makefile has, marked from what its scene reaches; C5, C6."""
    code, (algorithms, cards), declared_elsewhere = SceneCode(root), menu(root), non_module(root)
    demos, findings, visits = [], [], {}
    for target, scene, _ in demo_targets(root):
        module = owner_of(f"godot/{scene}", modules) if scene else None
        if module is None or not (root / "godot" / scene).is_file():
            findings.append(f"Makefile: C5 {target} opens {scene or 'no res://….tscn scene'}, "
                            f"which is not a file any module owns")
            continue
        rulesets = tuple(str(mode.get("ruleset", "")).removeprefix("res://")
                         for mode in (cards.get(target) or {}).get("modes") or [] if mode.get("ruleset"))
        reached, visits[target] = scene_reach(code, modules, scene, rulesets)
        filed = file_algorithms(cards.get(target), algorithms, code, visits[target], modules,
                                declared_elsewhere)
        uses = marks(modules, module, reached)
        uses.update({page: (DIRECT, "") for page in filed if page != INSIDE and page not in uses})
        text = {language: {field: text_of(entries.get(target), field, language) for field in GAME_FIELDS}
                for language in LANGUAGES}
        demos.append(Demo(target, module, uses, filed, text))
    return demos, findings + non_module_marks(root, demos, visits)


def non_module_marks(root: pathlib.Path, demos: list[Demo], visits: dict[str, set[str]]) -> list[str]:
    """Mark each non-module technique on the demos it names; C6 where it cannot be.

    The file declares the demos by hand, so the scene is asked to agree: one
    of the technique's Godot paths must hold a script the scene reaches.
    """
    by_target = {demo.target: demo for demo in demos}
    findings = []
    for entry in non_module(root):
        paths = [path for path in entry.get("lives_in", []) if path.startswith("godot/")]
        for target in entry.get("demos", []):
            if target not in by_target:
                findings.append(f"{NON_MODULE}: C6 {entry['page']} names {target}, which is not a demo")
            elif not any(reaches(visits[target], path) for path in paths):
                findings.append(f"{NON_MODULE}: C6 {target}'s scene never reaches {entry['page']}'s "
                                f"Godot scripts ({', '.join(paths) or 'none named'})")
            else:
                by_target[target].uses.setdefault(entry["page"], (DIRECT, ""))
    return findings


def catalogue(root: pathlib.Path) -> Catalogue:
    """Read every input and measure every demo: what the pages are written from."""
    modules = load_modules(root)
    techniques, findings = technique_pages(root, modules)
    entries, names, verified_on = games(root)
    targets = demo_targets(root)
    if not targets:
        findings.append("Makefile: C0 no run or demo-* target with a ## help line; a catalogue of nothing")
    demos, more = build_demos(root, modules, entries)
    findings += more + game_findings(entries, [target for target, _, _ in targets])
    findings += name_findings(demos, names)
    findings += key_findings(entries, {target: help_line for target, _, help_line in targets})
    return Catalogue(techniques, demos, names, verified_on, findings)


# --- writing it, in two languages ----------------------------------------------

WORDS = {
    "en": {
        "title": "The catalogue: every demo, and the AI in it",
        "quote": "Em português: [catalogue.pt-BR.md](catalogue.pt-BR.md).",
        "generated": "Generated by `scripts/catalogue.py` from `modules/*.json`, the Makefile's `run` and "
                     "`demo-*` targets, the menu's cards, `non_module_techniques.json` and `games.json`. "
                     "Do not edit it by hand: `make catalogue` writes it again, and `make lint-catalogue` "
                     "fails while it is stale.",
        "matrix": "The demos and their techniques {#matrix}",
        "matrix_intro": "A row per demo, a column per technique; each mark links the technique's page, "
                        "and the lines below name the algorithms.",
        "by_demo": "Demo by demo {#by-demo}",
        "by_technique": "Technique by technique {#by-technique}",
        "how": "How the marks are measured {#how}",
        "how_text": [
            "A mark is measured, not written. The catalogue starts from the techniques a demo's "
            "manifest declares (`depends_on` in `modules/<example>.json`, directly or through another "
            "example it uses), and follows the code from the scene its `make` target opens, file by "
            "file, with the rule `check_demos.py` holds the menu's cards to: a class counts when the "
            "code constructs it, calls it or extends it, and a `res://` path when it names a script or "
            "a scene. Comments, strings, type annotations and constant reads do not count, and tests "
            "are left out:",
            "",
            f"- {DIRECT} the demo's own code reaches the technique;",
            f"- {THROUGH} only another example's code reaches it, and the line names which;",
            f"- {OFFLINE} the demo's manifest declares it and nothing its scene reaches uses it: the "
            "dependency belongs to code the demo does not run -- the Python that trains it, or a file "
            "the scene never loads.",
            "",
            "The algorithms come from the demo's card in the menu (`godot/menu/catalogue.json`): each "
            "is filed under the technique whose code holds the class its card names as evidence, or "
            "under *written inside the example itself* when that class is the example's own.",
            "",
            "What a reading cannot see: a script loaded from a path built at run time, and whether a "
            "branch that uses a class is ever taken. Opening the demo is the check for both.",
            "",
            "A technique that lives in Python and a demo rather than in an addon "
            "(`non_module_techniques.json`) is marked " + DIRECT + " on the demos that file names, and "
            "`make lint-catalogue` fails when such a demo's scene never reaches one of the technique's "
            "Godot scripts. The known game, the keys and the algorithms' short names come from "
            "`games.json`, the one hand-written input, and the keys are held to each target's "
            "`make help` line.",
        ],
        "demo": "demo", "like": "like", "keys": "keys", "techniques": "techniques",
        "inside": "written inside the example itself", "inside_short": "inside the example",
        "through": "through", "offline": "declared in its manifest, never reached from its scene",
        "none_used": "none", "no_demo": "no demo yet", "seen": "Watch it in",
        "summary_intro": "The AI is what this kit is about, so here it is both ways round, generated "
                         f"from the modules' manifests and the menu's cards. {DIRECT} the demo's own code "
                         f"uses the technique; {THROUGH} it reaches it through another example's code. "
                         "[The catalogue]({catalogue}) has the whole matrix, the keys that show each "
                         "decision, and how the marks are measured.",
        "summary_techniques": ["technique", "what it decides", "algorithms", "where to watch it"],
        "summary_demos": ["demo", "like", "the AI in it"],
    },
    "pt-BR": {
        "title": "O catálogo: cada demo, e a IA que há nela",
        "quote": "English: [catalogue.md](catalogue.md). Os termos que ficam em inglês estão no "
                 "[glossário](glossary.pt-BR.md).",
        "generated": "Gerado por `scripts/catalogue.py` a partir de `modules/*.json`, dos alvos `run` e "
                     "`demo-*` do Makefile, dos cartões do menu, de `non_module_techniques.json` e de "
                     "`games.json`. Não edite à mão: `make catalogue` escreve de novo, e "
                     "`make lint-catalogue` falha enquanto estiver desatualizado.",
        "matrix": "As demos e suas técnicas {#matrix}",
        "matrix_intro": "Uma linha por demo, uma coluna por técnica; cada marca leva à página da técnica, "
                        "e as linhas abaixo dão os nomes dos algoritmos.",
        "by_demo": "Demo por demo {#by-demo}",
        "by_technique": "Técnica por técnica {#by-technique}",
        "how": "Como as marcas são medidas {#how}",
        "how_text": [
            "Uma marca é medida, não escrita. O catálogo parte das técnicas que o manifesto da demo "
            "declara (`depends_on` em `modules/<exemplo>.json`, direto ou por outro exemplo que ela "
            "usa) e segue o código a partir da cena que o alvo do `make` abre, arquivo por arquivo, "
            "com a regra que o `check_demos.py` aplica aos cartões do menu: uma classe conta quando o "
            "código a constrói, a chama ou a estende, e um caminho `res://` quando nomeia um script ou "
            "uma cena. Comentários, *strings*, anotações de tipo e leituras de constante não contam, e "
            "os testes ficam de fora:",
            "",
            f"- {DIRECT} o código da própria demo alcança a técnica;",
            f"- {THROUGH} só o código de outro exemplo a alcança, e a linha diz qual;",
            f"- {OFFLINE} o manifesto da demo a declara e nada que a cena alcança a usa: a dependência "
            "é de um código que a demo não roda -- o Python que a treina, ou um arquivo que a cena "
            "nunca carrega.",
            "",
            "Os algoritmos vêm do cartão da demo no menu (`godot/menu/catalogue.json`): cada um fica "
            "sob a técnica cujo código tem a classe que o cartão dá como evidência, ou sob *escrito "
            "dentro do próprio exemplo* quando essa classe é do exemplo.",
            "",
            "O que uma leitura não vê: um script carregado de um caminho montado durante a execução, e "
            "se um ramo que usa uma classe chega a ser tomado. Abrir a demo é a verificação das duas "
            "coisas.",
            "",
            "Uma técnica que vive no Python e numa demo, e não num *addon* "
            "(`non_module_techniques.json`), recebe " + DIRECT + " nas demos que esse arquivo cita, e "
            "`make lint-catalogue` falha quando a cena de uma delas não alcança nenhum dos scripts "
            "Godot da técnica. O jogo conhecido, as teclas e os nomes curtos dos algoritmos vêm de "
            "`games.json`, a única entrada escrita à mão, e as teclas são conferidas com a linha de "
            "`make help` de cada alvo.",
        ],
        "demo": "demo", "like": "parecido com", "keys": "teclas", "techniques": "técnicas",
        "inside": "escrito dentro do próprio exemplo", "inside_short": "dentro do exemplo",
        "through": "por", "offline": "declarada no manifesto, nunca alcançada pela cena",
        "none_used": "nenhuma", "no_demo": "nenhuma demo ainda", "seen": "Veja em",
        "summary_intro": "A IA é o foco deste kit, então aqui ela está nos dois sentidos, gerada a "
                         f"partir dos manifestos dos módulos e dos cartões do menu. {DIRECT} o código da "
                         f"própria demo usa a técnica; {THROUGH} ela a alcança pelo código de outro "
                         "exemplo. [O catálogo]({catalogue}) tem a matriz inteira, as teclas que mostram "
                         "cada decisão e como as marcas são medidas.",
        "summary_techniques": ["técnica", "o que decide", "algoritmos", "onde ver"],
        "summary_demos": ["demo", "parecido com", "a IA nela"],
    },
}

DOC_META = """<!-- doc-meta
half_life: practice
verified_on: {verified_on}
tier: 0
source: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html ; \
book:Ian Millington, "AI for Games", 3rd edition, CRC Press, 2019
invalidated_if: a demo stops showing a technique its scene still reaches, or a known game or a key \
in games.json no longer matches its demo
teaches: none
-->"""


def page_link(page: str, language: str, prefix: str = "") -> str:
    """The path of a technique's page in one language, from where it is linked."""
    return f"{prefix}{page}{SUFFIX[language]}"


def command(target: str) -> str:
    """How a reader opens a demo: the command, never the bare target name,
    because a reader who copies `demo-rts` into a shell gets nothing."""
    return f"`make {target}`"


def table_row(cells: list[str]) -> str:
    """One markdown table row, its cells' own pipes escaped: an algorithm
    name with a `|` in it would otherwise split its cell in two."""
    return "| " + " | ".join(cell.replace("|", "\\|") for cell in cells) + " |"


def sentence(text: str) -> str:
    """The text with a full stop, unless it already ends a sentence."""
    return text if text.endswith((".", "?", "!")) else f"{text}."


def named(model: Catalogue, keys: list[str], language: str) -> str:
    """The short names of some algorithms, in one language."""
    return ", ".join(text_of(model.names, key, language) or key for key in keys)


def note(demo: Demo, page: str, language: str, model: Catalogue) -> str:
    """What follows a technique on a demo's line: the example it came through,
    why its mark is hollow, and the algorithms filed under it."""
    mark, through = demo.uses[page]
    parts = []
    if mark == THROUGH:
        parts.append(f"{WORDS[language]['through']} `{through}`")
    if mark == OFFLINE:
        parts.append(WORDS[language]["offline"])
    if demo.algorithms.get(page):
        parts.append(named(model, demo.algorithms[page], language))
    return f" ({'; '.join(parts)})" if parts else ""


def matrix(model: Catalogue, language: str) -> list[str]:
    """The table of demo by technique, a mark linking the page in each cell."""
    header = [WORDS[language]["demo"], *(f"`{technique.page}`" for technique in model.techniques)]
    rows = [table_row(header), table_row(["---"] * len(header))]
    for demo in model.demos:
        cells = [f"[{demo.text[language]['game']}](#{demo.target})"]
        for technique in model.techniques:
            mark = demo.uses.get(technique.page, ("", ""))[0]
            cells.append(f"[{mark}]({page_link(technique.page, language)})" if mark else "")
        rows.append(table_row(cells))
    return rows


def by_demo(model: Catalogue, language: str) -> list[str]:
    """A line per demo: its command, the known game, the keys, its techniques."""
    words = WORDS[language]
    lines = []
    for demo in model.demos:
        text = demo.text[language]
        used = [f"{demo.uses[technique.page][0]} [{technique.name[language]}]"
                f"({page_link(technique.page, language)}){note(demo, technique.page, language, model)}"
                for technique in model.techniques if technique.page in demo.uses]
        lines += [f"- <a id=\"{demo.target}\"></a>**{text['game']}**, {command(demo.target)} -- "
                  f"{words['like']} {sentence(text['like'])}",
                  f"  - {words['keys']}: {sentence(text['keys'])}",
                  f"  - {words['techniques']}: {'; '.join(used) or words['none_used']}."]
        if demo.algorithms.get(INSIDE):
            lines.append(f"  - {words['inside']}: {named(model, demo.algorithms[INSIDE], language)}.")
    return lines


def by_technique(model: Catalogue, language: str) -> list[str]:
    """A line per technique: what it decides, and the demos it appears in."""
    words = WORDS[language]
    lines = []
    for technique in model.techniques:
        shown = [f"{demo.uses[technique.page][0]} [{command(demo.target)}](#{demo.target})"
                 f"{note(demo, technique.page, language, model)}"
                 for demo in model.demos if technique.page in demo.uses]
        decides = technique.decides[language]
        title = f"[{technique.name[language]}]({page_link(technique.page, language)})"
        lines.append(f"- <a id=\"{technique.page}\"></a>{title}"
                     f"{' -- ' + sentence(decides) if decides else '.'} "
                     f"{words['seen']}: {'; '.join(shown) or words['no_demo']}.")
    return lines


def render_page(model: Catalogue, language: str) -> str:
    """One catalogue page, whole."""
    words = WORDS[language]
    lines = [f"# {words['title']}", "", DOC_META.format(verified_on=model.verified_on), "",
             f"> {words['quote']}", "", words["generated"], "",
             f"## {words['matrix']}", "", words["matrix_intro"], "", *matrix(model, language), "",
             f"## {words['by_demo']}", "", *by_demo(model, language), "",
             f"## {words['by_technique']}", "", *by_technique(model, language), "",
             f"## {words['how']}", "", *words["how_text"]]
    return "\n".join(lines) + "\n"


def watched(demo: Demo, page: str) -> bool:
    """True when a demo is a place to watch the technique: it uses it, not
    only declares it. The README's summary lists only these."""
    return demo.uses.get(page, (OFFLINE,))[0] != OFFLINE


def summary_techniques(model: Catalogue, language: str, catalogue_path: str) -> list[str]:
    """The README's first table: each technique, its algorithms, the demos that show it."""
    rows = [table_row(WORDS[language]["summary_techniques"]), table_row(["---"] * 4)]
    for technique in model.techniques:
        demos = [demo for demo in model.demos if watched(demo, technique.page)]
        keys = list(dict.fromkeys(key for demo in demos for key in demo.algorithms.get(technique.page, [])))
        shown = [f"{demo.uses[technique.page][0]} [{command(demo.target)}]({catalogue_path}#{demo.target})"
                 for demo in demos]
        rows.append(table_row([
            f"[{technique.name[language]}]({page_link(technique.page, language, f'{PAGES}/')})",
            technique.decides[language], named(model, keys, language),
            ", ".join(shown) or WORDS[language]["no_demo"]]))
    return rows


def summary_demos(model: Catalogue, language: str, catalogue_path: str) -> list[str]:
    """The README's second table: each demo, the game it is like, its AI."""
    rows = [table_row(WORDS[language]["summary_demos"]), table_row(["---"] * 3)]
    for demo in model.demos:
        used = [f"{demo.uses[technique.page][0]} [{technique.name[language]}]"
                f"({page_link(technique.page, language, f'{PAGES}/')})"
                + (f": {named(model, demo.algorithms[technique.page], language)}"
                   if demo.algorithms.get(technique.page) else "")
                for technique in model.techniques if watched(demo, technique.page)]
        if demo.algorithms.get(INSIDE):
            used.append(f"{WORDS[language]['inside_short']}: {named(model, demo.algorithms[INSIDE], language)}")
        rows.append(table_row([f"[{command(demo.target)}]({catalogue_path}#{demo.target}) "
                               f"{demo.text[language]['game']}", demo.text[language]["like"],
                               "; ".join(used) or WORDS[language]["none_used"]]))
    return rows


def render_summary(model: Catalogue, language: str) -> str:
    """The block between the README's markers, markers included."""
    path = f"{PAGES}/{CATALOGUE[language].name}"
    return "\n".join([
        OPEN, "<!-- written by scripts/catalogue.py: edit the inputs, then `make catalogue` -->", "",
        WORDS[language]["summary_intro"].format(catalogue=path), "",
        *summary_techniques(model, language, path), "", *summary_demos(model, language, path), "",
        CLOSE])


# --- the gate ------------------------------------------------------------------


def summary_span(text: str) -> tuple[int, int] | None:
    """Where the summary sits in a README, markers included; None unless one pair, in order."""
    if text.count(OPEN) != 1 or text.count(CLOSE) != 1:
        return None
    start, end = text.index(OPEN), text.index(CLOSE) + len(CLOSE)
    return (start, end) if start < end else None


def compare(root: pathlib.Path, model: Catalogue) -> tuple[list[str], dict[str, str]]:
    """C1 and C4: what differs from what would be written, and the new texts."""
    findings, rewritten = [], {}
    for language in LANGUAGES:
        page = root / CATALOGUE[language]
        new = render_page(model, language)
        if not page.is_file() or page.read_text(encoding="utf-8") != new:
            findings.append(f"{CATALOGUE[language]}: C1 not what the manifests generate; run `make catalogue`")
            rewritten[str(CATALOGUE[language])] = new
        readme = root / README[language]
        old = readme.read_text(encoding="utf-8") if readme.is_file() else ""
        span = summary_span(old)
        if span is None:
            findings.append(f"{README[language]}: C4 needs one {OPEN} and one {CLOSE}, in that order")
            continue
        new = old[:span[0]] + render_summary(model, language) + old[span[1]:]
        if new != old:
            findings.append(f"{README[language]}: C1 the summary is not what the manifests generate; "
                            f"run `make catalogue`")
            rewritten[README[language]] = new
    return findings, rewritten


def run(root: pathlib.Path, check_only: bool) -> int:
    """Check or write; print the findings; 0 clean, 1 findings, 2 unreadable.

    Writing refuses while any finding other than staleness stands: a page
    written from a demo with no known game, or a column with no page, would
    commit the gap along with the table.
    """
    try:
        model = catalogue(root)
        drift, rewritten = compare(root, model)
    except (Unreadable, OSError, UnicodeDecodeError) as error:
        print(f"catalogue: cannot read: {error}", file=sys.stderr)
        return 2
    blocking = model.findings + [finding for finding in drift if " C4 " in finding]
    if check_only or blocking:
        findings = model.findings + drift if check_only else blocking
        for finding in findings:
            print(finding)
        return 1 if findings else 0
    for path, text in rewritten.items():
        (root / path).write_text(text, encoding="utf-8", newline="\n")
        print(f"catalogue: wrote {path}")
    return 0


# --- self-test -------------------------------------------------------------
#
# A tiny repository with one demo that shows each mark: `play` uses ai_a
# itself, reaches ai_b only through the `lib` example, and declares ai_c
# that only a type annotation, a comment and a test name. It carries the
# non-module `trick`, in a folder of its own, and an algorithm of its own
# (`Own`) that its card names.

MAKEFILE = ".PHONY: demo-play\ndemo-play: import ## Play against it: space plays, K keeps\n" \
           "\t@$(GODOT) --path godot res://game/play/play.tscn\n"

PLAY_SCRIPT = ("extends Node\nvar a := AiA.new()\nvar lib := Lib.new()\nvar trick := Trick.new()\n"
               "var own := Own.new()\nvar hinted: AiC\nvar probe := PlayTest.new()\n"
               "# AiC is only mentioned here\n")

# Each algorithm on the card, to its evidence classes. `mixed` has evidence in a
# technique and in the example itself, and belongs to the technique alone.
CARD_ALGORITHMS = {"alpha": ["AiA"], "beta": ["AiB"], "own": ["Own"], "tricky": ["Trick"], "mixed": ["Own", "AiA"]}


def manifest(name: str, kind: str, owns: list[str], depends_on: list[str] = ()) -> str:
    """A module's manifest, as JSON text."""
    return json.dumps({"module": name, "kind": kind, "owns": owns, "depends_on": list(depends_on)})


def games_text(demos: dict[str, dict], names: dict[str, dict] | None = None) -> str:
    """games.json for these entries, and a name for each card algorithm by default."""
    if names is None:
        names = {key: {"en": key.title(), "pt-BR": f"{key} em português"} for key in CARD_ALGORITHMS}
    return json.dumps({"verified_on": "2026-10-26", "demos": demos, "algorithms": names})


def game_entry(name: str) -> dict:
    """A complete games.json entry, its keys ones the help line names."""
    entry = {field: {"en": f"{name} {field}", "pt-BR": f"{name} {field} em português"}
             for field in GAME_FIELDS}
    entry["keys"] = {"en": "space plays; K keeps", "pt-BR": "espaço joga; K guarda"}
    return entry


def non_module_text(lives_in: str, demo: str = "demo-play") -> str:
    """non_module_techniques.json with the one technique, `trick`."""
    return json.dumps({"techniques": [{"page": "trick", "lives_in": [lives_in], "demos": [demo]}]})


def menu_text(modes: list[dict] | None = None) -> str:
    """The menu's catalogue: one card, naming the four algorithms by their
    evidence, and the `modes` given, each with the ruleset it is built from."""
    card = {"target": "demo-play", "techniques": [{"technique": key} for key in CARD_ALGORITHMS]}
    if modes:
        card["modes"] = modes
    return json.dumps({
        "techniques": {key: {"name": key, "evidence": names} for key, names in CARD_ALGORITHMS.items()},
        "examples": [card],
    })


def fixture() -> dict[str, str]:
    """The good repository, path -> text."""
    files = {
        "Makefile": MAKEFILE,
        "modules/core.json": manifest("core", "kernel", ["godot/addons/core/"]),
        "modules/lib.json": manifest("lib", "example", ["godot/game/lib/"], ["ai_b"]),
        "modules/play.json": manifest("play", "example", ["godot/game/play/", "godot/test/play/"],
                                      ["ai_a", "ai_c", "lib"]),
        "godot/addons/core/grid.gd": "class_name Grid\n",
        "godot/game/lib/lib.gd": "class_name Lib\nvar helper := AiB.new()\n",
        "godot/game/lib/unused.gd": "class_name Unused\n",
        "godot/game/play/play.tscn": '[ext_resource type="Script" path="res://game/play/play.gd" id="1"]\n',
        "godot/game/play/play.gd": PLAY_SCRIPT,
        "godot/game/play/own.gd": "class_name Own\n",
        "godot/game/play/tricks/trick.gd": "class_name Trick\n",
        "godot/test/play/play_test.gd": "class_name PlayTest\nvar c := AiC.new()\n",
        MENU: menu_text(),
        str(GAMES): games_text({"demo-play": game_entry("Play")}),
        str(NON_MODULE): non_module_text("godot/game/play/tricks/"),
        "README.md": f"# Kit\n\n{OPEN}\n{CLOSE}\n\nMore.\n",
        "README.pt-BR.md": f"# Kit\n\n{OPEN}\n{CLOSE}\n\nMais.\n",
    }
    for page in ("ai_a", "ai_b", "ai_c"):
        files[f"modules/{page}.json"] = manifest(page, "technique", [f"godot/addons/{page}/"], ["core"])
        files[f"godot/addons/{page}/{page}.gd"] = f"class_name {page.title().replace('_', '')}\n"
    for page in ("ai_a", "ai_b", "ai_c", "trick"):
        files[f"{PAGES}/{page}.md"] = f"# {page} — decides {page}\n"
        files[f"{PAGES}/{page}.pt-BR.md"] = f"# {page} — decide {page}\n"
    return files


def lay_out(repo: pathlib.Path, files: dict[str, str | None]) -> None:
    """Write each file; None removes it."""
    for path, text in files.items():
        target = repo / path
        if text is None:
            target.unlink()
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")


def planted(root: pathlib.Path, name: str, changes: dict[str, str | None]) -> pathlib.Path:
    """The good repository, its pages written, then `changes` made to it."""
    repo = root / name
    lay_out(repo, fixture())
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        if run(repo, check_only=False) != 0:
            raise AssertionError(f"the self-test's own fixture does not generate: {output.getvalue()}")
    lay_out(repo, changes)
    return repo


def cases() -> list[tuple[str, dict[str, str | None], int, str]]:
    """(label, changes to the generated repository, exit, the finding it must name)."""
    new_demo = MAKEFILE + MAKEFILE.replace("demo-play", "demo-more")
    play = {"demo-play": game_entry("Play")}
    return [
        ("the pages as written", {}, 0, ""),
        ("a demo added without regenerating",
         {"Makefile": new_demo, str(GAMES): games_text(dict(play, **{"demo-more": game_entry("More")}))},
         1, "C1"),
        ("a demo's code now reaching a technique, not regenerated",
         {"godot/game/play/play.gd": PLAY_SCRIPT + "var c := AiC.new()\n"}, 1, "C1"),
        ("a key changed in games.json, not regenerated",
         {str(GAMES): games_text({"demo-play": dict(game_entry("Play"), keys={"en": "K", "pt-BR": "T"})})},
         1, f"{CATALOGUE['en']}: C1"),
        ("a README.pt-BR.md that is missing", {"README.pt-BR.md": None}, 1, "C4"),
        ("a technique with no pt-BR page", {f"{PAGES}/ai_b.pt-BR.md": None}, 1, "C2"),
        ("a demo missing from games.json", {str(GAMES): games_text({})}, 1, "C3"),
        ("games.json naming no demo",
         {str(GAMES): games_text(dict(play, **{"demo-gone": game_entry("Gone")}))}, 1, "C3"),
        ("an entry with a language missing",
         {str(GAMES): games_text({"demo-play": dict(game_entry("Play"), like={"en": "Play like"})})}, 1, "C3"),
        ("a README without its markers", {"README.md": "# Kit\n"}, 1, "C4"),
        ("no demo at all", {"Makefile": "all:\n\t@true\n"}, 1, "C0"),
        # Wave 142's review: a mode's ruleset is reached as the scene is, so a
        # technique only the mode uses is marked once regenerated.
        ("a mode's ruleset now reaching a technique, not regenerated",
         {"godot/game/play/mode.gd": "extends RefCounted\nvar c := AiC.new()\n",
          MENU: menu_text([{"mode": "m", "ruleset": "res://game/play/mode.gd"}])}, 1, "C1"),
        ("a demo opening a scene nobody owns",
         {"Makefile": MAKEFILE.replace("game/play/play.tscn", "game/gone/gone.tscn")}, 1, "C5"),
        *planted_reach_cases(play),
    ]


def planted_reach_cases(play: dict) -> list[tuple[str, dict[str, str | None], int, str]]:
    """C6, C7 and C8: the scene, the cards and the keys held to each other."""
    names = json.loads(games_text(play))["algorithms"]
    return [
        ("a non-module technique its demo never reaches",
         {str(NON_MODULE): non_module_text("godot/game/lib/unused.gd")}, 1, "C6"),
        # The scene is not a script the technique could live in: a folder or
        # file counted by the scene alone would pass every time.
        ("a non-module technique living in the scene file",
         {str(NON_MODULE): non_module_text("godot/game/play/play.tscn")}, 1, "C6"),
        ("a non-module technique naming no demo",
         {str(NON_MODULE): non_module_text("godot/game/play/tricks/", "demo-gone")}, 1, "C6"),
        ("a card's algorithm with no short name",
         {str(GAMES): games_text(play, {key: value for key, value in names.items() if key != "own"})}, 1, "C7"),
        ("a card's algorithm named in one language",
         {str(GAMES): games_text(play, dict(names, own={"en": "Own"}))}, 1, "C7"),
        ("a short name for an algorithm no card lists",
         {str(GAMES): games_text(play, dict(names, gone={"en": "Gone", "pt-BR": "Ido"}))}, 1, "C7"),
        ("a key the help line does not name",
         {str(GAMES): games_text({"demo-play": dict(game_entry("Play"), keys={"en": "Q quits", "pt-BR": "Q"})})},
         1, "C8"),
        ("a manifest that is not JSON", {"modules/lib.json": "{"}, 2, ""),
        ("a menu that is not JSON", {MENU: "{"}, 2, ""),
    ]


def drifted_summary_case(root: pathlib.Path) -> list[str]:
    """A README summary changed by hand, markers kept, must be C1 (step 4)."""
    repo = planted(root, "summary", {})
    readme = repo / "README.pt-BR.md"
    before = readme.read_text(encoding="utf-8")
    readme.write_text(before.replace("decide ai_a", "decide outra coisa"), encoding="utf-8")
    if readme.read_text(encoding="utf-8") == before:
        return ["a README summary that drifted: the planted edit changed nothing"]
    return expect("a README summary that drifted", repo, 1, "README.pt-BR.md: C1")


def mark_cases(root: pathlib.Path) -> list[str]:
    """Each mark and each algorithm is filed as the module docstring says."""
    repo = root / "the pages as written"
    page = (repo / CATALOGUE["en"]).read_text(encoding="utf-8")
    readme = (repo / README["en"]).read_text(encoding="utf-8").split(OPEN)[1]
    wanted = {
        "the demo's own use, with its algorithm": f"{DIRECT} [ai_a](ai_a.md) (Alpha, Mixed)",
        "a use through another example": f"{THROUGH} [ai_b](ai_b.md) (through `lib`; Beta)",
        "a declaration only a type, a test and a comment use":
            f"{OFFLINE} [ai_c](ai_c.md) (declared in its manifest, never reached from its scene)",
        "a non-module technique in a folder": f"{DIRECT} [trick](trick.md) (Tricky)",
        "an algorithm the example writes itself": "  - written inside the example itself: Own.",
        "the technique's way back to its demo":
            f"{THROUGH} [`make demo-play`](#demo-play) (through `lib`; Beta)",
    }
    failures = [f"{label}: expected {text!r} in the page" for label, text in wanted.items() if text not in page]
    if OFFLINE in readme:
        failures.append("a hollow mark reached the README summary, which says where to watch")
    if "| Alpha, Mixed |" not in readme or "inside the example: Own" not in readme:
        failures.append("the README summary does not name the algorithms")
    return failures


def expect(label: str, repo: pathlib.Path, want: int, code: str) -> list[str]:
    """One --check run: the exit it must give, and a finding it must name.

    `code` may carry the file too (`README.md: C1`), when which file is
    stale is the point of the case.
    """
    output = io.StringIO()
    with contextlib.redirect_stdout(output), contextlib.redirect_stderr(io.StringIO()):
        got = run(repo, check_only=True)
    if got != want:
        return [f"{label}: expected exit {want}, got {got}: {output.getvalue().strip()!r}"]
    if code and f"{code} " not in output.getvalue():
        return [f"{label}: expected a {code} finding, got {output.getvalue().strip()!r}"]
    return []


def self_test() -> int:
    """Run every planted case; 0 when each is rejected or passed as it must be.

    Invariant 4: each rule has a case it must reject, and the good
    repository is the case it must pass, so a gate gone blind or gone
    paranoid both fail here.
    """
    failures = []
    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)
        try:
            for label, changes, want, code in cases():
                failures += expect(label, planted(root, label, changes), want, code)
            failures += drifted_summary_case(root) + mark_cases(root)
        except AssertionError as broken:
            failures.append(f"the sound repository: {broken}")
        refused = planted(root, "refused", {str(GAMES): games_text({})})
        shutil.copy(refused / README["en"], root / "before")
        with contextlib.redirect_stdout(io.StringIO()):
            run(refused, check_only=False)
        if (refused / README["en"]).read_text() != (root / "before").read_text():
            failures.append("writing went ahead over a C3 finding")
    with contextlib.redirect_stderr(io.StringIO()):
        if main(["--unknown-flag"]) != 2:
            failures.append("an unknown flag is wrong usage, exit 2")
    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    """Parse the command line, then write, check, or test the checker.

    `--help` keeps argparse's exit 0; any other usage error is 2, which every
    gate here returns for wrong usage.
    """
    parser = argparse.ArgumentParser(add_help=True, description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", default=None)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        if exit_request.code == 0:
            raise
        return 2
    if args.self_test:
        return self_test()
    return run(pathlib.Path(args.root or pathlib.Path(__file__).resolve().parent.parent), args.check)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
