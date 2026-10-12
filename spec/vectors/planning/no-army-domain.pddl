; The same world with the first link missing: there is no action that puts an
; army at the node, so nothing downstream of it can ever be true.
(define (domain stranded)
  (:requirements :strips)
  (:predicates
    (army_at_node)
    (node_held)
    (resources_banked)
    (enemy_beaten))

  (:action take_the_node
    :parameters ()
    :precondition (and (army_at_node))
    :effect (and (node_held)))

  (:action mine_the_node
    :parameters ()
    :precondition (and (node_held))
    :effect (and (resources_banked)))

  (:action attack
    :parameters ()
    :precondition (and (resources_banked))
    :effect (and (enemy_beaten))))
