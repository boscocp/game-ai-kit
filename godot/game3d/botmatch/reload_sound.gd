## A reload made in code, as the gunshot is: the magazine coming out, the
## new one going in, and the bolt -- three clicks spread over the reload's
## time, so a person hears when one starts, near or far, and when the rifle
## is ready again.
class_name ReloadSound
extends RefCounted

const RATE: int = 22050
## Where each click falls, as a share of the reload, and how loud it is.
const CLICKS: Array[Vector2] = [Vector2(0.05, 0.6), Vector2(0.65, 0.8), Vector2(0.9, 1.0)]
const CLICK_SECONDS: float = 0.04


## The sound for a reload of `seconds`, as 16-bit mono PCM. Its noise has
## its own seed, so making it draws nothing from a match's random numbers.
static func make(seconds: float) -> AudioStreamWAV:
	var noise := RandomNumberGenerator.new()
	noise.seed = 2
	var samples: int = int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for click: Vector2 in CLICKS:
		var start: int = int(click.x * samples)
		for index: int in range(mini(int(RATE * CLICK_SECONDS), samples - start)):
			var time: float = float(index) / RATE
			var tick: float = noise.randf_range(-1.0, 1.0) * exp(-time * 150.0)
			var ring: float = sin(TAU * 1800.0 * time) * exp(-time * 90.0)
			var value: int = clampi(int((tick * 0.6 + ring * 0.4) * click.y * 32767.0), -32768, 32767)
			data.encode_s16((start + index) * 2, value)
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = RATE
	sound.data = data
	return sound
