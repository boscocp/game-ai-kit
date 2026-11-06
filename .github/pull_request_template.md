<!-- Delete any heading that does not apply: an empty one is worse than none.
     This body is checked like a commit message, and a squash merge turns it
     into one on main: one author, no tooling byline. -->

## What changed, and why

<!-- The why is the part a reviewer cannot rebuild from the diff. -->

## Which checks ran

```
$ 
```

<!-- Paste the command and the last lines of its output:
     `make check-no-engine` with Python only, or
     `make check-affected BASE=upstream/main` with the engine
     (`origin/main` if you have push access). Say if a check could not run
     here, and why. -->

## Both languages?

<!-- A technique page and its `.pt-BR.md` twin change together, and a code
     block changed in one is changed in both. If you wrote only one
     language, say so: the other is a follow-up, not a refusal, and
     `make lint-translations-docs` reporting D5 on that page is expected. -->

## What you saw, versus what a check says

<!-- A game is visual. Say which this is: opened the demo and watched the
     decision, ran a suite, or reasoned about it without running it. All
     three are fine; mixing them up silently is not. -->
