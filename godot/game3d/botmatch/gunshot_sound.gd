## A gunshot made in code: a tenth of a second of noise that falls away
## fast, with a low thump under it. The kit carries no recorded sound, and a
## shot nobody hears is a shot that feels like nothing happened.
class_name GunshotSound
extends RefCounted

const RATE: int = 22050
const SECONDS: float = 0.09


## The sound, as 16-bit mono PCM. Its noise has its own seed, so making it
## draws nothing from a match's random numbers.
static func make() -> AudioStreamWAV:
	var noise := RandomNumberGenerator.new()
	noise.seed = 1
	var samples: int = int(RATE * SECONDS)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for index: int in range(samples):
		var time: float = float(index) / RATE
		var crack: float = noise.randf_range(-1.0, 1.0) * exp(-time * 60.0)
		var thump: float = sin(TAU * 90.0 * time) * exp(-time * 30.0)
		var value: int = clampi(int((crack * 0.7 + thump * 0.5) * 32767.0), -32768, 32767)
		data.encode_s16(index * 2, value)
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = RATE
	sound.data = data
	return sound
