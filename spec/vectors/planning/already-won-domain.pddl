; One action, which is never needed: the problem beside this one starts with
; the goal already true.
(define (domain already-won)
  (:requirements :strips)
  (:predicates
    (enemy_scouted)
    (enemy_beaten))

  (:action scout_the_enemy
    :parameters ()
    :precondition (and (enemy_beaten))
    :effect (and (enemy_scouted))))
