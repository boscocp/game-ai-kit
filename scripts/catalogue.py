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
    like, the keys that show the decision), and a line per technique (the
    demos it appears in);
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
each candidate is classified by what the scene actually reaches -- every
class name and `res://` path, file by file, from the scene the target
opens, tests left out (the same evidence `check_modules.py` reads):

  ●  the demo's own code reaches it;
  ◐  only another example's code reaches it -- the line names which;
  ○  its own manifest declares it and nothing the scene reaches uses it.

A technique that is not a module (`non_module_techniques.json`) is marked ●
on the demos that file names, and a demo whose scene never reaches the
technique's Godot code is a finding.

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
      scene never reaches the technique's Godot code

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
import check_modules  # noqa: E402 -- the manifests, ownership, and how code names code
from check_modules import CLASS_NAME_RE, RES_PATH_RE, WORD_RE, owner_of  # noqa: E402

PAGES = pathlib.PurePosixPath("docs/techniques")
GAMES = PAGES / "games.json"
NON_MODULE = PAGES / "non_module_techniques.json"
LANGUAGES = ("en", "pt-BR")
SUFFIX = {"en": ".md", "pt-BR": ".pt-BR.md"}
CATALOGUE = {language: PAGES / f"catalogue{SUFFIX[language]}" for language in LANGUAGES}
README = {"en": "README.md", "pt-BR": "README.pt-BR.md"}
OPEN = "<!-- catalogue:summary -->"
CLOSE = "<!-- /catalogue:summary -->"
GAME_FIELDS = ("game", "like", "keys")

DIRECT, THROUGH, OFFLINE = "●", "◐", "○"
DEMO_RE = re.compile(r"^(run|demo-[\w-]+):[^#\n]*##", re.M)
SCENE_RE = re.compile(r"res://([\w./-]+\.tscn)")
READ_SUFFIXES = (".gd", ".tscn", ".json")
GODOT_TESTS = "godot/test/"


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
    through, or "" when the mark needs no name).
    """

    target: str
    module: str
    uses: dict[str, tuple[str, str]]
    text: dict[str, dict[str, str]]


@dataclasses.dataclass
class Catalogue:
    """Everything the pages are written from, and what was found on the way."""

    techniques: list[Technique]
    demos: list[Demo]
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


def demo_targets(root: pathlib.Path) -> list[tuple[str, str | None]]:
    """(target, the scene its recipe opens or None), in the Makefile's order."""
    try:
        text = (root / "Makefile").read_text(encoding="utf-8")
    except OSError as error:
        raise Unreadable(f"Makefile: {error}") from error
    targets = []
    for target in DEMO_RE.findall(text):
        scene = SCENE_RE.search(check_modules.recipe(text, target))
        targets.append((target, f"godot/{scene.group(1)}" if scene else None))
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


# --- what a scene reaches ----------------------------------------------------


class CodeIndex:
    """The Godot code every module owns, tests left out, and who names what."""

    def __init__(self, root: pathlib.Path, modules: dict) -> None:
        """Read every owned file once, comments out, and map each class to its file.

        Comments are left out because a class named in a sentence is not a
        class used -- the same rule as check_modules.py.
        """
        self.texts: dict[str, str] = {}
        for module in modules.values():
            for owned in module.owns:
                self._read(root, owned)
        self.classes = {name: path for path, text in self.texts.items()
                        if path.endswith(".gd") for name in CLASS_NAME_RE.findall(text)}

    def _read(self, root: pathlib.Path, owned: str) -> None:
        """Index one owned path: a file, or every readable file in a folder."""
        base = root / owned
        files = [base] if base.is_file() else sorted(base.rglob("*")) if base.is_dir() else []
        for file in files:
            path = file.relative_to(root).as_posix()
            if file.suffix in READ_SUFFIXES and file.is_file() and not path.startswith(GODOT_TESTS):
                code = file.read_text(encoding="utf-8")
                self.texts[path] = check_modules.without_comments(code, file.suffix)

    def named_by(self, path: str) -> set[str]:
        """The files one file reaches: the classes it names, the paths it loads."""
        code = self.texts[path]
        found = {self.classes[word] for word in WORD_RE.findall(code) if word in self.classes}
        for named in RES_PATH_RE.findall(code):
            named = f"godot/{named}"
            folder = named.rstrip("/") + "/"
            found |= {named} if named in self.texts else {
                other for other in self.texts if other.startswith(folder)}
        return found - {path}


def scene_reach(index: CodeIndex, modules: dict, scene: str) -> tuple[dict[str, set[str]], set[str]]:
    """The modules a scene reaches, each with the examples it came through.

    "" in a module's set means the demo's own code reached it. The walk
    stops at a technique or a kernel: those depend on nothing a demo is
    about. A file is visited once per example it is reached through, so the
    answer does not depend on which way round the walk went first.
    """
    own = owner_of(scene, modules)
    reached: dict[str, set[str]] = {}
    seen, waiting = {(scene, "")}, [(scene, "")]
    while waiting:
        path, through = waiting.pop()
        owner = owner_of(path, modules)
        if modules[owner].kind != "example":
            reached.setdefault(owner, set()).add(through)
            continue
        through = through or ("" if owner == own else owner)
        for following in index.named_by(path):
            if (following, through) not in seen:
                seen.add((following, through))
                waiting.append((following, through))
    return reached, {path for path, _ in seen}


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


# --- the catalogue -----------------------------------------------------------


def games(root: pathlib.Path) -> tuple[dict, str]:
    """games.json's entries by target, and the day they were last checked."""
    raw = read_json(root / GAMES)
    try:
        return dict(raw["demos"]), str(raw["verified_on"])
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


def build_demos(root: pathlib.Path, modules: dict, entries: dict) -> tuple[list[Demo], list[str]]:
    """Every demo the Makefile has, marked from what its scene reaches; C5, C6."""
    index = CodeIndex(root, modules)
    demos, findings, visits = [], [], {}
    for target, scene in demo_targets(root):
        if scene is None or scene not in index.texts:
            findings.append(f"Makefile: C5 {target} opens {scene or 'no res://….tscn scene'}, "
                            f"which is not a file any module owns")
            continue
        reached, visits[target] = scene_reach(index, modules, scene)
        module = owner_of(scene, modules)
        text = {language: {field: text_of(entries.get(target), field, language) for field in GAME_FIELDS}
                for language in LANGUAGES}
        demos.append(Demo(target, module, marks(modules, module, reached), text))
    return demos, findings + non_module_marks(root, demos, visits)


def non_module_marks(root: pathlib.Path, demos: list[Demo], visits: dict[str, set[str]]) -> list[str]:
    """Mark each non-module technique on the demos it names; C6 where it cannot be.

    The file declares the demos by hand, so the scene is asked to agree: one
    of the technique's Godot paths must be among the files it reaches.
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
                                f"Godot code ({', '.join(paths) or 'none named'})")
            else:
                by_target[target].uses[entry["page"]] = (DIRECT, "")
    return findings


def catalogue(root: pathlib.Path) -> Catalogue:
    """Read every input and measure every demo: what the pages are written from."""
    modules = load_modules(root)
    techniques, findings = technique_pages(root, modules)
    entries, verified_on = games(root)
    targets = [target for target, _ in demo_targets(root)]
    if not targets:
        findings.append("Makefile: C0 no run or demo-* target with a ## help line; a catalogue of nothing")
    demos, more = build_demos(root, modules, entries)
    findings += more + game_findings(entries, targets)
    return Catalogue(techniques, demos, verified_on, findings)


# --- writing it, in two languages ----------------------------------------------

WORDS = {
    "en": {
        "title": "The catalogue: every demo, and the AI in it",
        "quote": "Em português: [catalogue.pt-BR.md](catalogue.pt-BR.md).",
        "generated": "Generated by `scripts/catalogue.py` from `modules/*.json`, the Makefile's `run` and "
                     "`demo-*` targets, `non_module_techniques.json` and `games.json`. Do not edit it by "
                     "hand: `make catalogue` writes it again, and `make lint-catalogue` fails while it is "
                     "stale.",
        "matrix": "The demos and their techniques {#matrix}",
        "matrix_intro": "A row per demo, a column per technique; each mark links the technique's page.",
        "by_demo": "Demo by demo {#by-demo}",
        "by_technique": "Technique by technique {#by-technique}",
        "how": "How the marks are measured {#how}",
        "how_text": [
            "A mark is measured, not written. The catalogue starts from the techniques a demo's "
            "manifest declares (`depends_on` in `modules/<example>.json`, directly or through another "
            "example it uses), and follows the code from the scene its `make` target opens -- every "
            "class name and every `res://` path, file by file, tests left out:",
            "",
            f"- {DIRECT} the demo's own code reaches the technique;",
            f"- {THROUGH} only another example's code reaches it, and the line names which;",
            f"- {OFFLINE} the demo's manifest declares it and nothing its scene reaches uses it: the "
            "dependency belongs to code the demo does not run -- the Python that trains it, or a file "
            "the scene never loads.",
            "",
            "A technique that lives in Python and a demo rather than in an addon "
            "(`non_module_techniques.json`) is marked " + DIRECT + " on the demos that file names, and "
            "`make lint-catalogue` fails when such a demo's scene never reaches the technique's Godot "
            "code. The known game and the keys come from `games.json`, the one hand-written input; "
            "`make menu` opens every demo here.",
        ],
        "demo": "demo", "like": "like", "keys": "keys", "techniques": "techniques",
        "through": "through", "offline": "declared in its manifest, never reached from its scene",
        "none_used": "none", "no_demo": "no demo yet", "seen": "Watch it in",
        "summary_intro": "The AI is what this kit is about, so here it is both ways round, generated "
                         f"from the modules' manifests. {DIRECT} the demo's own code uses the technique; "
                         f"{THROUGH} it reaches it through another example's code. [The catalogue]"
                         "({catalogue}) has the whole matrix, the keys that show each decision, and how "
                         "the marks are measured.",
        "summary_techniques": ["technique", "what it decides", "where to watch it"],
        "summary_demos": ["demo", "like", "the AI in it"],
    },
    "pt-BR": {
        "title": "O catálogo: cada demo, e a IA que há nela",
        "quote": "English: [catalogue.md](catalogue.md). Os termos que ficam em inglês estão no "
                 "[glossário](glossary.pt-BR.md).",
        "generated": "Gerado por `scripts/catalogue.py` a partir de `modules/*.json`, dos alvos `run` e "
                     "`demo-*` do Makefile, de `non_module_techniques.json` e de `games.json`. Não edite "
                     "à mão: `make catalogue` escreve de novo, e `make lint-catalogue` falha enquanto "
                     "estiver desatualizado.",
        "matrix": "As demos e suas técnicas {#matrix}",
        "matrix_intro": "Uma linha por demo, uma coluna por técnica; cada marca leva à página da técnica.",
        "by_demo": "Demo por demo {#by-demo}",
        "by_technique": "Técnica por técnica {#by-technique}",
        "how": "Como as marcas são medidas {#how}",
        "how_text": [
            "Uma marca é medida, não escrita. O catálogo parte das técnicas que o manifesto da demo "
            "declara (`depends_on` em `modules/<exemplo>.json`, direto ou por outro exemplo que ela "
            "usa) e segue o código a partir da cena que o alvo do `make` abre -- cada nome de classe e "
            "cada caminho `res://`, arquivo por arquivo, sem os testes:",
            "",
            f"- {DIRECT} o código da própria demo alcança a técnica;",
            f"- {THROUGH} só o código de outro exemplo a alcança, e a linha diz qual;",
            f"- {OFFLINE} o manifesto da demo a declara e nada que a cena alcança a usa: a dependência "
            "é de um código que a demo não roda -- o Python que a treina, ou um arquivo que a cena "
            "nunca carrega.",
            "",
            "Uma técnica que vive no Python e numa demo, e não num *addon* "
            "(`non_module_techniques.json`), recebe " + DIRECT + " nas demos que esse arquivo cita, e "
            "`make lint-catalogue` falha quando a cena de uma delas nunca alcança o código Godot da "
            "técnica. O jogo conhecido e as teclas vêm de `games.json`, a única entrada escrita à mão; "
            "`make menu` abre todas as demos daqui.",
        ],
        "demo": "demo", "like": "como", "keys": "teclas", "techniques": "técnicas",
        "through": "por", "offline": "declarada no manifesto, nunca alcançada pela cena",
        "none_used": "nenhuma", "no_demo": "nenhuma demo ainda", "seen": "Veja em",
        "summary_intro": "A IA é o foco deste kit, então aqui ela está nos dois sentidos, gerada a "
                         f"partir dos manifestos dos módulos. {DIRECT} o código da própria demo usa a "
                         f"técnica; {THROUGH} ela a alcança pelo código de outro exemplo. [O catálogo]"
                         "({catalogue}) tem a matriz inteira, as teclas que mostram cada decisão e como "
                         "as marcas são medidas.",
        "summary_techniques": ["técnica", "o que decide", "onde ver"],
        "summary_demos": ["demo", "como", "a IA nela"],
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
    """How a reader opens a demo."""
    return f"`make {target}`"


def table_row(cells: list[str]) -> str:
    """One markdown table row."""
    return "| " + " | ".join(cells) + " |"


def sentence(text: str) -> str:
    """The text with a full stop, unless it already ends a sentence."""
    return text if text.endswith((".", "?", "!")) else f"{text}."


def why(mark: str, through: str, language: str) -> str:
    """What follows a mark: the example it came through, or why it is hollow."""
    if mark == THROUGH:
        return f" ({WORDS[language]['through']} `{through}`)"
    if mark == OFFLINE:
        return f" ({WORDS[language]['offline']})"
    return ""


def matrix(model: Catalogue, language: str) -> list[str]:
    """The table of demo by technique, a mark linking the page in each cell."""
    header = [WORDS[language]["demo"], *(technique.name[language] for technique in model.techniques)]
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
                f"({page_link(technique.page, language)}){why(*demo.uses[technique.page], language)}"
                for technique in model.techniques if technique.page in demo.uses]
        lines += [f"- <a id=\"{demo.target}\"></a>**{text['game']}**, {command(demo.target)} -- "
                  f"{words['like']} {sentence(text['like'])}",
                  f"  - {words['keys']}: {sentence(text['keys'])}",
                  f"  - {words['techniques']}: {', '.join(used) or words['none_used']}."]
    return lines


def by_technique(model: Catalogue, language: str) -> list[str]:
    """A line per technique: what it decides, and the demos it appears in."""
    words = WORDS[language]
    lines = []
    for technique in model.techniques:
        shown = [f"{demo.uses[technique.page][0]} [{command(demo.target)}](#{demo.target})"
                 f"{why(*demo.uses[technique.page], language)}"
                 for demo in model.demos if technique.page in demo.uses]
        decides = technique.decides[language]
        title = f"[{technique.name[language]}]({page_link(technique.page, language)})"
        lines.append(f"- <a id=\"{technique.page}\"></a>{title}"
                     f"{' -- ' + sentence(decides) if decides else '.'} "
                     f"{words['seen']}: {', '.join(shown) or words['no_demo']}.")
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


def summary_techniques(model: Catalogue, language: str, catalogue_path: str) -> list[str]:
    """The README's first table: each technique and the demos that show it.

    A hollow mark is left out here: the summary says where to watch a
    technique, and a demo that only declares it is not such a place.
    """
    rows = [table_row(WORDS[language]["summary_techniques"]), table_row(["---"] * 3)]
    for technique in model.techniques:
        shown = [f"{demo.uses[technique.page][0]} [{command(demo.target)}]({catalogue_path}#{demo.target})"
                 for demo in model.demos if demo.uses.get(technique.page, (OFFLINE,))[0] != OFFLINE]
        rows.append(table_row([
            f"[{technique.name[language]}]({page_link(technique.page, language, f'{PAGES}/')})",
            technique.decides[language], ", ".join(shown) or WORDS[language]["no_demo"]]))
    return rows


def summary_demos(model: Catalogue, language: str, catalogue_path: str) -> list[str]:
    """The README's second table: each demo, the game it is like, its AI."""
    rows = [table_row(WORDS[language]["summary_demos"]), table_row(["---"] * 3)]
    for demo in model.demos:
        used = [f"{demo.uses[technique.page][0]} [{technique.name[language]}]"
                f"({page_link(technique.page, language, f'{PAGES}/')})"
                for technique in model.techniques
                if demo.uses.get(technique.page, (OFFLINE,))[0] != OFFLINE]
        rows.append(table_row([f"[{command(demo.target)}]({catalogue_path}#{demo.target}) "
                               f"{demo.text[language]['game']}", demo.text[language]["like"],
                               ", ".join(used) or WORDS[language]["none_used"]]))
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
# itself, reaches ai_b only through the `lib` example, declares ai_c that
# only its test and a comment name, and carries the non-module `trick`.

MAKEFILE = ".PHONY: demo-play\ndemo-play: import ## Play against it\n" \
           "\t@$(GODOT) --path godot res://game/play/play.tscn\n"


def manifest(name: str, kind: str, owns: list[str], depends_on: list[str] = ()) -> str:
    """A module's manifest, as JSON text."""
    return json.dumps({"module": name, "kind": kind, "owns": owns, "depends_on": list(depends_on)})


def games_text(demos: dict[str, dict]) -> str:
    """games.json for these entries."""
    return json.dumps({"verified_on": "2026-10-26", "demos": demos})


def game_entry(name: str) -> dict:
    """A complete games.json entry."""
    return {field: {"en": f"{name} {field}", "pt-BR": f"{name} {field} em português"}
            for field in GAME_FIELDS}


def non_module_text(lives_in: str, demo: str = "demo-play") -> str:
    """non_module_techniques.json with the one technique, `trick`."""
    return json.dumps({"techniques": [{"page": "trick", "lives_in": [lives_in], "demos": [demo]}]})


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
        "godot/game/play/play.gd": "extends Node\nvar a := AiA.new()\nvar lib := Lib.new()\n"
                                   "var trick := Trick.new()\n# AiC is only mentioned here\n",
        "godot/game/play/trick.gd": "class_name Trick\n",
        "godot/test/play/play_test.gd": "var c := AiC.new()\n",
        str(GAMES): games_text({"demo-play": game_entry("Play")}),
        str(NON_MODULE): non_module_text("godot/game/play/trick.gd"),
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
    with contextlib.redirect_stdout(io.StringIO()):
        if run(repo, check_only=False) != 0:
            raise AssertionError("the self-test's own fixture does not generate")
    lay_out(repo, changes)
    return repo


def cases() -> list[tuple[str, dict[str, str | None], int, str]]:
    """(label, changes to the generated repository, exit, the finding it must name)."""
    good = fixture()
    new_demo = MAKEFILE + MAKEFILE.replace("demo-play", "demo-more")
    return [
        ("the pages as written", {}, 0, ""),
        ("a demo added without regenerating",
         {"Makefile": new_demo, str(GAMES): games_text({"demo-play": game_entry("Play"),
                                                        "demo-more": game_entry("More")})}, 1, "C1"),
        ("a demo's code now reaching a technique, not regenerated",
         {"godot/game/play/play.gd": good["godot/game/play/play.gd"] + "var c := AiC.new()\n"}, 1, "C1"),
        ("a key changed in games.json, not regenerated",
         {str(GAMES): games_text({"demo-play": dict(game_entry("Play"), keys={"en": "K", "pt-BR": "T"})})},
         1, f"{CATALOGUE['en']}: C1"),
        ("a README.pt-BR.md that is missing", {"README.pt-BR.md": None}, 1, "C4"),
        ("a technique with no pt-BR page", {f"{PAGES}/ai_b.pt-BR.md": None}, 1, "C2"),
        ("a demo missing from games.json", {str(GAMES): games_text({})}, 1, "C3"),
        ("games.json naming no demo",
         {str(GAMES): games_text({"demo-play": game_entry("Play"), "demo-gone": game_entry("Gone")})}, 1, "C3"),
        ("an entry with a language missing",
         {str(GAMES): games_text({"demo-play": dict(game_entry("Play"), like={"en": "Play like"})})}, 1, "C3"),
        ("a README without its markers", {"README.md": "# Kit\n"}, 1, "C4"),
        ("no demo at all", {"Makefile": "all:\n\t@true\n"}, 1, "C0"),
        ("a demo opening a scene nobody owns",
         {"Makefile": MAKEFILE.replace("game/play/play.tscn", "game/gone/gone.tscn")}, 1, "C5"),
        ("a non-module technique its demo never reaches",
         {str(NON_MODULE): non_module_text("godot/game/lib/unused.gd")}, 1, "C6"),
        ("a non-module technique naming no demo",
         {str(NON_MODULE): non_module_text("godot/game/play/trick.gd", "demo-gone")}, 1, "C6"),
        ("a manifest that is not JSON", {"modules/lib.json": "{"}, 2, ""),
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
    """Each mark is measured as the module docstring says, in both directions."""
    repo = root / "the pages as written"
    page = (repo / CATALOGUE["en"]).read_text(encoding="utf-8")
    readme = (repo / README["en"]).read_text(encoding="utf-8")
    wanted = {
        "the demo's own use": f"{DIRECT} [ai_a](ai_a.md)",
        "a use through another example": f"{THROUGH} [ai_b](ai_b.md) (through `lib`)",
        "a declaration only a test and a comment use": f"{OFFLINE} [ai_c](ai_c.md)",
        "a non-module technique": f"{DIRECT} [trick](trick.md)",
        "the technique's way back to its demo": f"{THROUGH} [`make demo-play`](#demo-play) (through `lib`)",
    }
    failures = [f"{label}: expected {text!r} in the page" for label, text in wanted.items() if text not in page]
    if OFFLINE in readme.split(OPEN)[1]:
        failures.append("a hollow mark reached the README summary, which says where to watch")
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
        for label, changes, want, code in cases():
            failures += expect(label, planted(root, label, changes), want, code)
        failures += drifted_summary_case(root) + mark_cases(root)
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
