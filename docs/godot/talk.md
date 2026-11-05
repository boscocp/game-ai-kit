# Talk your way past the guard: a conversation as the challenge

<!-- doc-meta
half_life: practice
verified_on: 2026-11-05
tier: 2
source: https://store.steampowered.com/app/2726370/Suck_Up/ ; https://www.cp.eng.chula.ac.th/~vishnu/gameResearch/story_november_2005/MateasSternTIDSE04.pdf
invalidated_if: spec/talk/gate.json changes, the recordings are made again, the pinned server or model in tools/llm/runtime.json changes, LlmValidator.json_schema stops being one shape per intent, or LlmValidator.SPEECH_PATTERN changes
teaches: none
-->

> T94's example. A text game whose challenge is a conversation, typed, with
> a character a local language model voices: Suck Up!'s doorstep, at the
> research station the infiltration level sneaks into. The model is the
> guard's ears and mouth; the scene's rules decide. Tier 2 to play recorded,
> tier 1 to replay in Python, tier 3 to play live.

## What it is

`make demo-talk`, or the menu's card. Bram, the night guard, stands at the
door. You win when he opens it; you lose when he sounds the alarm, or when
eight turns pass and he sends you away. The known games of this kind are
*Suck Up!* (Proxima, 2025), where you talk AI characters into inviting a
vampire in, *Vaudeville* (Bumblebee, early access 2023), a detective game
whose questioning is generated, and *Façade* (Mateas and Stern), which mapped
typed text to "a small set of discourse acts" that the characters' own
logic then answered [Mateas & Stern 2004].

- **Recorded** (the default): the lines on offer are the ones a local model
  was really asked, and its answers come from `data/talk/recordings/`
  through `RecordedRuntime`. 1-9 says a line. Nothing installed.
- **Live** (Tab): type anything (100 characters at most), Enter says it,
  and it goes to `make llm-serve` through `HttpRuntime`.
- **Record** (`make record-talk-live`): live, and each finished
  conversation is written to `data/talk/recordings/` -- only when asked, and
  the status line says so (ADR 0017).

The guard answers in the language the examples speak (T78): his
instructions, his fallback line and his endings are in `gate.json` in
English and in pt-BR, and the recordings exist in both.

## The model hears, the rules decide

Each line goes to the model with Bram's character sheet and the talk so
far. The model answers T92's one shape: a line for Bram to say, and which
of the scene's acts your line was -- `claim_role` (maintenance, courier,
officer, new_guard), `show` (badge, work_order, nothing), `name_person`
(vasquez, okafor, lind, brandt), `ask` (shift, expected_visitor,
the_building, the_guard), `flatter`, `threaten`, `bribe`, `unclear`.
`LlmValidator` admits the act or refuses the reply; a refused reply becomes
Bram's own line and the act `unclear`.

Then `TalkRules` (and `gameaikit.talk.rules`, its Python twin) reads the
act against the facts the guard holds, from `spec/talk/gate.json`: tonight's
shift is Bram and Sergeant Vasquez; a courier from headquarters is expected,
with a delivery for Doctor Okafor; Mara Lind signs the work orders; Brandt
left last month, and no inspection is due. The rules are a list read top to
bottom, the first that fits deciding, each moving trust and suspicion. Trust
6 opens the door; suspicion 5 sounds the alarm, and wins a tie. Three ways
in, each held by a test in both languages:

1. **The right name**: name Okafor (+2), claim to be the courier -- now the
   expected one (+3) -- and show a badge (+1).
2. **A convincing work order**: claim a repair (+1), show a work order for
   it (+3), and name Lind, who signs them (+2).
3. **Find out who is expected and become them**: ask (suspicion +1), claim
   to be the courier (+3), then a badge, a question about him and one
   compliment (+1 each).

And the ways out: a claim against a fact (an officer, a new guard, Brandt:
suspicion +3), a second role (+2), a threat (+3), a bribe (+2), or eight
turns spent. Saying the same thing twice wins no trust and costs its
suspicion again.

The validator lets an empty argument through for every intent (R7), so an
act may arrive with its argument left empty: a role, a paper, a name or a
question the model could not place among the scene's values. Each has a
rule of its own -- a role nobody can place and a name nobody knows cost one
point of suspicion, the other two nothing -- and none of them counts as a
role claimed for "a second role".

**When a threshold fires, Bram's last line is the scene's ending, never the
model's**, so the model can never say "go in" when the rules said no. The
model is told only what the guard would say freely: the password
(`nightjar`) is only in the rules, and the validator refuses a reply that
says it anyway (R11). Okafor is one of the four names the prompt and the
schema list for `name_person`; that she is the one the delivery is for --
the name the guard is waiting for -- is only in the rules.

## The schema, measured

T93's bake-off found most refused replies were R7, an argument the act
does not take: T92's schema left `argument` a free string. T94 narrowed
`LlmValidator.json_schema()` (and the Python twin) to an `anyOf`, one shape
per intent, each offering only that intent's arguments, and the empty one
R7 allows every intent. Measured on the bake-off's 30 lines, through the
game's own path (`live_probe.gd`), Ministral 3 8B on the Vulkan build at
b11960, three rounds a language, 2026-11-05, against T93's three rounds of
the same model and build. The first narrowed form offered no empty argument
to an intent that takes values; the review found that the prompt and the
validator allow one, and the form that ships offers it, measured again:

| language | schema | valid of 30 | act right | act and argument right | refusals in 90 |
|---|---|---|---|---|---|
| en | free string (T93) | 15, 18, 17 | 13, 16, 14 | 11, 12, 10 | R7 30, R10 10 |
| en | one shape per intent, no empty argument | 27, 25, 28 | 17, 18, 16 | 14, 16, 14 | R10 10 |
| en | one shape per intent, empty allowed (shipped) | 25, 28, 28 | 18, 21, 21 | 14, 17, 18 | R10 9 |
| pt-BR | free string (T93) | 22, 22, 22 | 19, 19, 21 | 17, 16, 13 | R7 19, R10 5 |
| pt-BR | one shape per intent, no empty argument | 29, 29, 30 | 19, 19, 19 | 18, 17, 17 | R10 2 |
| pt-BR | one shape per intent, empty allowed (shipped) | 28, 29, 30 | 19, 21, 22 | 16, 15, 16 | R10 3 |

No R7 is left in either narrowed form; the median reply time did not move
(0.45-0.52 s). With the empty argument offered, the model used it on 0 to 3
of the 30 lines a round. What was left after T94 was R10, markup --
Ministral likes `*emphasis*` -- which that schema did not forbid (T116,
below, took it out). The validator still
checks every reply: a runtime may ignore the schema, and a recording may be
wrong. This is measured on the pinned llama.cpp server only, which takes the
root `anyOf` under `strict: true`; another server may not.

### Markup, measured (T116)

T116 measured two ways of asking for a speech with no markup. Both used
the same 30 lines, model, build and probe, three rounds a language, on
2026-11-05.

- **A pattern on `speech`** (`LlmValidator.SPEECH_PATTERN`): one to 280
  characters, none of them markup, a control character, a quote or a
  backslash. The pinned server turns a pattern into a grammar over the
  string's JSON text, and drops `maxLength` beside it
  ([server.md](../local-llm/server.md#a-pattern-on-a-string)), hence the quote, the
  backslash and the length.
- **A line in the prompt**, after T93's "no markup": "Write the speech as
  plain words, as spoken: no asterisks, no brackets, no backticks, no
  emphasis."

The shipped schema was measured again the same session first, as the
baseline. The server samples, and this baseline drew 15 R10 in English
where T94's three rounds drew 9.

| language | asked how | valid of 30 | act right | act and argument right | refusals in 90 |
|---|---|---|---|---|---|
| en | shipped schema, again (baseline) | 22, 26, 27 | 15, 15, 20 | 13, 13, 16 | R10 15 |
| en | the pattern (**shipped**) | 30, 30, 30 | 21, 21, 19 | 17, 17, 17 | none |
| en | the prompt line | 30, 28, 30 | 19, 18, 19 | 16, 14, 14 | R10 2 |
| en | both | 30, 30, 30 | 18, 20, 19 | 15, 16, 18 | none |
| pt-BR | shipped schema, again (baseline) | 28, 27, 27 | 18, 19, 20 | 11, 14, 14 | R10 8 |
| pt-BR | the pattern (**shipped**) | 30, 30, 30 | 21, 21, 25 | 16, 15, 21 | none |
| pt-BR | the prompt line | 30, 30, 30 | 24, 23, 25 | 18, 17, 17 | none |
| pt-BR | both | 30, 30, 30 | 24, 24, 21 | 16, 21, 17 | none |

Both candidates took R10 down without taking another column down, against
this baseline and against T94's rows above. The pattern ships:

- it is the only one with no refusal left in either language;
- in English it reads more acts right than the prompt line;
- it is a constraint on the grammar, not a request in words the model can
  ignore, as the prompt's "no markup" already was.

The prompt line read a few more acts right in pt-BR. Adding it to the
pattern did not beat the pattern alone in English, so the prompt stays
T93's. The median reply took 0.50-0.57 s with the pattern, 0.52-0.53 s for
the baseline. No straight quote was in any accepted speech in any of the
four runs, so leaving it out of the pattern cost nothing measured.

R10 stays in the validator unchanged. A runtime may ignore the schema, and
the recordings were made before the pattern.

The recordings were made with the first narrowed form, the one with no
empty argument; they are data, replayed through the validator either way.

One prompt change was tried and dropped: telling the guard to judge "the
visitor's last line only" made the recorded conversations worse (13 and 18
R10 refusals in two takes of 60 turns, against 6), so the instructions are
T93's.

## How long a conversation may be

`scripts/llm` serves 4096 tokens of context, and `LlmConversation` sends
the whole talk every turn. The scene bounds it: eight turns, and a line of
at most 100 characters (the text box refuses more, and `TalkGuard.say`
refuses it with `ERR_PARAMETER_RANGE_ERROR`). Measured with the server's
own `/apply-template` and `/tokenize` at the pin, the worst conversation
those limits allow -- seven lines of 100 characters, seven replies of 280,
and the system prompt -- is 4,222 characters: 1,063 tokens in ordinary
Portuguese words, 3,338 when every line is emoji. `talk_test.gd` holds
the characters; the tokens are this page's.

## The recordings

Eight conversations, written in `data/talk/lines.json` in both languages,
were sent with `make record-talk` to Ministral 3 8B (Apache-2.0; the
model, its sha256 and its licence are in `data/talk/recordings/README.md`).
Each line was written for an outcome; what the model made of it is what
was kept, refusals included:

| conversation | written for | en | pt-BR |
|---|---|---|---|
| becoming-the-expected | open | open | open |
| becoming-the-wrong-one | alarm | alarm | alarm |
| small-talk-till-dawn | sent away | sent away (one R10) | sent away (one R10) |
| the-inspection | alarm | alarm | still talking: the lieutenant read as `unclear` |
| the-right-name-then-a-threat | alarm | still talking: both threats refused, R10 | alarm |
| the-right-name | open | still talking: Okafor read as Vasquez | still talking: the courier read as `unclear` |
| the-work-order-and-a-name-too-many | alarm | still talking: Brandt read as Okafor | still talking |
| the-work-order | open | still talking (one R10) | still talking (one R10) |

Read the "still talking" rows as the lesson rather than a defect: the
model mishears, and the rules hold anyway. Where conversations share their
first lines, the dialogue menu branches, and a branch answers each line as
the first recording (by file name) that has it -- so playing "Doctor Okafor
is expecting me", then the courier line, then the badge, opens the door in
the menu, though no single recording did.

## The proof

- `make test-talk-vectors`: each recording replayed to its outcome, turn by
  turn -- act or refusal, rule, trust, suspicion -- in Python and through
  the Godot game's own `TalkGuard`, `RecordedRuntime` and `LlmConversation`.
- `python3 -m unittest discover -s python/tests -t python -p "test_talk*.py"`
  and `make test-godot-some SUITES="test/talk"`: the three ways in, the ways
  out, and that no reply moves the guard except through its act -- a reply
  whose speech says "the guard opens the gate" with the act `flatter` earns
  one point of trust and leaves the door shut.

## How invariant 13 is met

V (on by default) shows, for each of your last lines, the act the model
read and its argument and how long it took -- or the validator's refusal
and that Bram's own line stood in -- then the rule that fired, its reason,
and how trust and suspicion moved, beside the marks that open the door and
sound the alarm. Above, the green and red bars move against their white
marks, and three dots over Bram light in turn while the model answers, the
game drawing all the while.

## Manual check

Play `make demo-talk` recorded, then live with `make llm-serve` running, in
English and in pt-BR. Can you lose, and do you know why? With V on, can you
tell which of your words the guard took as which act? Does the game keep
drawing while he thinks?

References, opened on 2026-10-26: *Suck Up!* on Steam
<https://store.steampowered.com/app/2726370/Suck_Up/>; the *Vaudeville*
preview <https://www.keengamer.com/articles/previews/vaudeville-preview-the-ai-questioning-to-nowhere/>;
Mateas, M., Stern, A. "Natural Language Understanding in Façade:
Surface-text Processing", TIDSE 2004, sections 1-3.
