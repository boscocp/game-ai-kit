"""A PID controller, as `ai_steering`'s `PidController`: the same terms in
the same order, so the 3D driver's vectors can hold the two to one answer.

The proportional term pushes with the error now, the integral with the error
summed over time -- which removes an offset that sits there -- and the
derivative against its rate of change, which damps the overshoot (Melder &
Tomlinson, Game AI Pro 2013). The integral is held to `integral_limit`.
"""

from __future__ import annotations


class PidController:
    """Three gains, a limit on the integral term, and the past it remembers."""

    def __init__(self, kp: float, ki: float, kd: float, most_integral: float):
        self.proportional = kp
        self.integral = ki
        self.derivative = kd
        self.integral_limit = most_integral
        self.proportional_only = False
        self.proportional_term = self.integral_term = self.derivative_term = 0.0
        self._summed = 0.0
        self._last_error = 0.0
        self._started = False

    def update(self, error: float, step: float) -> float:
        """The push for `error`, `step` seconds after the last update."""
        self.proportional_term = self.proportional * error
        self.integral_term = 0.0
        self.derivative_term = 0.0
        if not self.proportional_only:
            self._summed += error * step
            if self.integral != 0.0:
                most = self.integral_limit / abs(self.integral)
                self._summed = max(-most, min(most, self._summed))
            self.integral_term = self.integral * self._summed
            rate = (error - self._last_error) / step if self._started and step > 0.0 else 0.0
            self.derivative_term = self.derivative * rate
        self._last_error = error
        self._started = True
        return self.proportional_term + self.integral_term + self.derivative_term

    def reset(self) -> None:
        """Forget the past."""
        self._summed = 0.0
        self._last_error = 0.0
        self._started = False
