; The tactical board, as the planner sees it (T11).
;
; Everything is a fact about "our" side and "their" side, so the same domain
; plans for whichever side is to move. Nothing is parameterised -- a fact per
; walker type, not a variable over types -- because that is the subset
; `python/gameaikit/pddl/` reads and `ai_planning` plans over.
;
; The board is abstracted, as ADR 0010 says it must be:
;
; * money is one fact, `funds_banked`: enough for the dearest purchase, the
;   forge. Income is not an action a side takes; `bank_income` is a turn spent
;   waiting for it, and the executor skips it when the board can already pay;
; * a walker is in one of three places, by type: on our bank (`_home`), on
;   theirs (`_across`), or in reach of their workshop. A fact says "at least
;   one", so the plan reasons about a walker of each type, not an army;
; * nothing here can tell how many blows a workshop takes. `siege_with_*` is
;   a step that lasts until the workshop falls, carried out turn after turn.
;
; What it cannot do: clear a crossing, or draw a guard off their workshop.
; No action adds `crossing_open` or `their_workshop_unguarded`, so with every
; dry crossing shut and the workshop guarded there is no plan (6 of the
; benchmark's boards before T48 added the fords) and the rules play that
; turn, saying so. Those two would be the
; next actions to add, and each is a tactical question the rules answer now.
;
; STRIPS has no negative preconditions, so "their workshop has no guard" is a
; fact of its own, `their_workshop_unguarded`, and not `(not (guarded))`.
;
; Kept equal to `tactics.json` beside it by `make test-python`; the game reads
; a byte-for-byte copy of that JSON (`godot/game/tactical/tactics_domain.json`).
(define (domain tactics)
  (:requirements :strips)
  (:predicates
    (funds_banked)
    (forge_owned)
    (runner_home)
    (shield_home)
    (mortar_home)
    (wader_home)
    (ram_home)
    (crossing_open)
    (runner_across)
    (shield_across)
    (mortar_across)
    (wader_across)
    (ram_across)
    (runner_at_their_workshop)
    (shield_at_their_workshop)
    (mortar_at_their_workshop)
    (wader_at_their_workshop)
    (ram_at_their_workshop)
    (their_workshop_unguarded)
    (their_workshop_falls))

  ; A turn of income, waited for. Needs nothing: income always comes.
  (:action bank_income
    :parameters ()
    :precondition (and)
    :effect (and (funds_banked)))

  ; The forge is what a ram needs, and the purchase the rules never make.
  (:action buy_the_forge
    :parameters ()
    :precondition (and (funds_banked))
    :effect (and (forge_owned) (not (funds_banked))))

  ; One purchase each. The ram also needs the forge.
  (:action build_runner
    :parameters ()
    :precondition (and (funds_banked))
    :effect (and (runner_home) (not (funds_banked))))

  (:action build_shield
    :parameters ()
    :precondition (and (funds_banked))
    :effect (and (shield_home) (not (funds_banked))))

  (:action build_mortar
    :parameters ()
    :precondition (and (funds_banked))
    :effect (and (mortar_home) (not (funds_banked))))

  (:action build_wader
    :parameters ()
    :precondition (and (funds_banked))
    :effect (and (wader_home) (not (funds_banked))))

  (:action build_ram
    :parameters ()
    :precondition (and (funds_banked) (forge_owned))
    :effect (and (ram_home) (not (funds_banked))))

  ; Everything but the wader crosses dry -- by the bridge or, since T48, a
  ; ford -- and only while one of those crossings has none of theirs on it.
  (:action cross_the_river_runner
    :parameters ()
    :precondition (and (runner_home) (crossing_open))
    :effect (and (runner_across) (not (runner_home))))

  (:action cross_the_river_shield
    :parameters ()
    :precondition (and (shield_home) (crossing_open))
    :effect (and (shield_across) (not (shield_home))))

  (:action cross_the_river_mortar
    :parameters ()
    :precondition (and (mortar_home) (crossing_open))
    :effect (and (mortar_across) (not (mortar_home))))

  ; The wader crosses anywhere, which is the whole of what makes it a wader.
  (:action wade_across
    :parameters ()
    :precondition (and (wader_home))
    :effect (and (wader_across) (not (wader_home))))

  (:action cross_the_river_ram
    :parameters ()
    :precondition (and (ram_home) (crossing_open))
    :effect (and (ram_across) (not (ram_home))))

  ; From their bank to within reach of their workshop.
  (:action close_in_runner
    :parameters ()
    :precondition (and (runner_across))
    :effect (and (runner_at_their_workshop) (not (runner_across))))

  (:action close_in_shield
    :parameters ()
    :precondition (and (shield_across))
    :effect (and (shield_at_their_workshop) (not (shield_across))))

  (:action close_in_mortar
    :parameters ()
    :precondition (and (mortar_across))
    :effect (and (mortar_at_their_workshop) (not (mortar_across))))

  (:action close_in_wader
    :parameters ()
    :precondition (and (wader_across))
    :effect (and (wader_at_their_workshop) (not (wader_across))))

  (:action close_in_ram
    :parameters ()
    :precondition (and (ram_across))
    :effect (and (ram_at_their_workshop) (not (ram_across))))

  ; A guarded workshop can only be sieged by a ram, which the counter table
  ; makes strong against buildings. Anything else needs the guard gone.
  (:action siege_with_runner
    :parameters ()
    :precondition (and (runner_at_their_workshop) (their_workshop_unguarded))
    :effect (and (their_workshop_falls)))

  (:action siege_with_shield
    :parameters ()
    :precondition (and (shield_at_their_workshop) (their_workshop_unguarded))
    :effect (and (their_workshop_falls)))

  (:action siege_with_mortar
    :parameters ()
    :precondition (and (mortar_at_their_workshop) (their_workshop_unguarded))
    :effect (and (their_workshop_falls)))

  (:action siege_with_wader
    :parameters ()
    :precondition (and (wader_at_their_workshop) (their_workshop_unguarded))
    :effect (and (their_workshop_falls)))

  (:action siege_with_ram
    :parameters ()
    :precondition (and (ram_at_their_workshop))
    :effect (and (their_workshop_falls))))
