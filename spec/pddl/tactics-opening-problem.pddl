; The opening, as blue sees it on its first turn: red has moved once, blue has
; been paid, and red's shield stands two cells from red's workshop.
(define (problem blue-s-first-turn)
  (:domain tactics)
  (:init (funds_banked) (runner_home) (shield_home) (bridge_open))
  (:goal (and (their_workshop_falls))))
