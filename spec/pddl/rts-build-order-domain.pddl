; The RTS's build order, as the commander plans it (T20).
;
; Level 1 PDDL, as ADR 0010 asks: plain facts, no numbers, no time. The two
; things a real build order is made of and STRIPS has no words for are
; abstracted the way Churchill and Buro (2011) do:
;
; * resources are income, not a balance. No action spends ore; the plan is
;   an order, and how long each step waits for its price is worked out
;   afterwards from the side's income rates (`BuildSchedule`), jumping to
;   the moment the step becomes affordable instead of stepping tick by tick;
; * a fact says "enough of": `workers_saturated` is enough workers on the
;   home deposits, `runners_ready` is a squad of runners, `supply_room` is
;   room for one more batch. Training a batch uses the room up, which is how
;   a depot gets into a plan that never names supply.
;
; `magma_flowing` is workers sent to a vent. It needs the home saturated
; first -- a worker on magma is one off ore -- and everything that costs
; magma needs it: the shield, the mortar, the lab and the tower. So the
; mortar is the end of the longest chain in the game: workers, magma, room,
; barracks, lab, mortars.
;
; `tower_armed` is T56's one upgrade: a tower standing, then its gun bought.
; It costs magma too, so it needs `magma_flowing`, and its price competes
; with a squad's -- which is the choice the commander has to time.
;
; Kept equal to `rts-build-order.json` beside it by `make test-python`; the
; game reads a byte-for-byte copy of that JSON
; (`godot/game/rts/build_order_domain.json`).
(define (domain rts-build-order)
  (:requirements :strips)
  (:predicates
    (workers_saturated)
    (supply_room)
    (magma_flowing)
    (barracks_up)
    (lab_up)
    (tower_up)
    (tower_armed)
    (expansion_up)
    (runners_ready)
    (shields_ready)
    (mortars_ready))

  (:action train_workers
    :parameters ()
    :precondition (and (supply_room))
    :effect (and (workers_saturated) (not (supply_room))))

  (:action build_depot
    :parameters ()
    :precondition (and)
    :effect (and (supply_room)))

  (:action mine_magma
    :parameters ()
    :precondition (and (workers_saturated))
    :effect (and (magma_flowing)))

  (:action build_barracks
    :parameters ()
    :precondition (and)
    :effect (and (barracks_up)))

  (:action build_lab
    :parameters ()
    :precondition (and (barracks_up) (magma_flowing))
    :effect (and (lab_up)))

  (:action build_tower
    :parameters ()
    :precondition (and (magma_flowing))
    :effect (and (tower_up)))

  (:action arm_tower
    :parameters ()
    :precondition (and (tower_up) (magma_flowing))
    :effect (and (tower_armed)))

  (:action expand
    :parameters ()
    :precondition (and (workers_saturated))
    :effect (and (expansion_up)))

  (:action train_runners
    :parameters ()
    :precondition (and (barracks_up) (supply_room))
    :effect (and (runners_ready) (not (supply_room))))

  (:action train_shields
    :parameters ()
    :precondition (and (barracks_up) (supply_room) (magma_flowing))
    :effect (and (shields_ready) (not (supply_room))))

  (:action train_mortars
    :parameters ()
    :precondition (and (lab_up) (supply_room) (magma_flowing))
    :effect (and (mortars_ready) (not (supply_room)))))
