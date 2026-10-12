# Review: docs/10-an-open-finding

Not reviewed by a fresh context, and said so here rather than implied. This
branch adds no code and takes no decision; it writes down a finding that was
about to be lost.

## What was reviewed

The four records under `docs/reviews/`, checked against every finding this
session actually received, one by one. The wave 07 review arrived in pieces --
its first message was truncated by the transport and the rest came hours later,
after its record had already been written and merged.

## Findings

**One finding was received and then neither fixed nor recorded.** Findings 4 to
10 of the wave 07 review were fixed during wave 8. Finding 11 -- header lengths,
two doc comments that paraphrase their signatures, and a function sitting four
public functions away from the helper it calls -- was addressed nowhere, and
nothing in the repository would have shown that. That is precisely how a review
finding disappears: not by being argued down, but by arriving late.

Measured while recording it, the header half is worse than reported: eleven of
twelve addon files exceed the guideline, not six, because wave 8 made two of
them longer.

## What was done about them

It is written at the end of `docs/reviews/07-ai-core-and-the-board.md` with the
measurement, and `STATUS.md` points at it from the section a new session reads
first.

The decision itself is left to the owner, deliberately. Either the headers are
too long or the rule is, and the longest headers are long because they carry
measurements this project asked somebody to go and take. A session failing a
rule is the last one that should be trusted to rewrite it.
