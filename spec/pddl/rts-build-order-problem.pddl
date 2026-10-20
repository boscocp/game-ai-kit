; The opening, as either side sees it: a base, four workers, room to spare,
; nothing else -- and the goal the commander sets when it has seen shields,
; the mortars that beat them, at the end of the game's longest chain.
(define (problem mortars-from-the-opening)
  (:domain rts-build-order)
  (:init (supply_room))
  (:goal (and (mortars_ready))))
