; The game's domain, in the form a planner outside this kit would expect it.
;
; Nothing here is parameterised: every predicate is a fact about the one node
; and the one army, so `:parameters` is empty throughout. That is the subset
; `python/gameaikit/pddl/` reads, and the reader says so rather than guessing
; when it meets a domain that is bigger.
(define (domain frontier-node)
  (:requirements :strips)
  (:predicates
    (army_in_reserve)
    (army_at_node)
    (node_held)
    (resources_banked)
    (barracks_built)
    (unit_trained)
    (enemy_scouted)
    (enemy_beaten))

  (:action march_to_node
    :parameters ()
    :precondition (and (army_in_reserve))
    :effect (and (army_at_node) (not (army_in_reserve))))

  (:action take_the_node
    :parameters ()
    :precondition (and (army_at_node))
    :effect (and (node_held)))

  (:action mine_the_node
    :parameters ()
    :precondition (and (node_held))
    :effect (and (resources_banked)))

  ; The barracks and the unit are paid for out of one bank, so both of these
  ; delete it. That is what makes the plan longer than a rule would guess.
  (:action build_barracks
    :parameters ()
    :precondition (and (resources_banked))
    :effect (and (barracks_built) (not (resources_banked))))

  (:action train_unit
    :parameters ()
    :precondition (and (resources_banked) (barracks_built))
    :effect (and (unit_trained) (not (resources_banked))))

  (:action scout_the_enemy
    :parameters ()
    :precondition (and (army_at_node))
    :effect (and (enemy_scouted)))

  (:action attack
    :parameters ()
    :precondition (and (unit_trained) (enemy_scouted))
    :effect (and (enemy_beaten) (not (unit_trained)))))
