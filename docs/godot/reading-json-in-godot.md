# Reading a JSON file without filling the log

<!-- doc-meta
half_life: practice
verified_on: 2026-10-12
tier: 2
source: https://docs.godotengine.org/en/stable/classes/class_json.html
invalidated_if: JSON.parse_string stops printing an engine error of its own, or JSON.parse starts
teaches: none
-->

> Godot has two JSON parsers and only one of them lets you write the error
> message. Checked against the Godot 4.7 documentation and measured on 4.7.2
> on 2026-10-12.

`ai_learning` loads a weights file and has to refuse a malformed one in a
sentence a person can act on. There are two ways to parse it, and the obvious
one is the wrong one.

## What the documentation says

> **`parse_string(json_string)`** (static) — Attempts to parse the
> `json_string` provided and returns the parsed data. Returns `null` if parse
> failed. [...] this method doesn't handle errors.
>
> **`parse(json_text, keep_text)`** — Attempts to parse the `json_text`
> provided. Returns an `Error`. If the parse was successful, it returns
> `@GlobalScope.OK`. If unsuccessful, use `get_error_line()` and
> `get_error_message()` to identify the source of failure.
>
> — [JSON](https://docs.godotengine.org/en/stable/classes/class_json.html)

So the documented difference is that one hands back a message and the other
does not.

## What measuring adds

The undocumented half, and the one that matters for a kit whose output a
person reads. **`JSON.parse_string` prints an engine error of its own** before
returning null:

```
ERROR: Parse JSON failed. Error at line 0: Expected 'true', 'false', or 'null', got 'weights'
   at: parse_string (core/io/json.cpp:629)
```

followed by a GDScript backtrace. `JSON.new().parse()` on the same input
returns `43` quietly and fills in `get_error_message()`.

"Doesn't handle errors" reads like *says nothing*; it means *says it loudly,
somewhere you cannot stop it, and then tells the caller nothing*.

## Why that is worth a page

It was found by a test. `learning_test.gd` deliberately loads a file that is
not JSON and asserts the refusal, and a green run printed a stack trace in the
middle of itself. Nothing was broken -- and a log that prints errors during a
normal, passing run is a log people stop reading, which is the same argument
`BoardState.apply` makes for refusing a move with a value rather than with
`push_error`.

So: **`JSON.new().parse()` everywhere a file might legitimately be malformed.**
The caller then owns the message, and the message can name the file, the line
and what to do about it.

Two places in this repository still use the static form -- the search and
planning vector runners, which parse files that are checked in beside them and
have never been malformed. The noise there would arrive immediately before
their own exit-2 message rather than inside a passing run, which is why they
are listed here rather than changed in a wave that is not about them.
