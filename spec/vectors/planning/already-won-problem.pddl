; The goal holds before anything runs. The plan is empty and the answer is
; still "solved", which is the one case an empty plan does not mean failure.
(define (problem nothing-to-do)
  (:domain already-won)
  (:init (enemy_beaten))
  (:goal (and (enemy_beaten))))
