class_name Music
extends Node
## Procedural ambient soundtrack: no audio files, no licences.
## A slow four-chord loop (pad + bass + plucked arpeggio) is synthesised in
## small chunks across frames so it never stalls the game (web builds are
## single-threaded). The Music bus has a low-pass filter whose cutoff follows
## the valley's stability: the calmer the valley, the brighter the music.

const RATE := 22050
const BPM := 72.0
# A minor-ish progression in Hz roots: Am, F, C, G (pad voicings below).
const CHORDS := [
	[220.00, 261.63, 329.63],
	[174.61, 220.00, 261.63],
	[196.00, 261.63, 329.63],
	[196.00, 246.94, 293.66],
]
const BASS := [110.00, 87.31, 130.81, 98.00]
const ARP_PATTERN := [0, 1, 2, 1, 2, 1, 0, 2]
const CHUNK := 2500

static var instance: Music
var player: AudioStreamPlayer
var _data := PackedByteArray()
var _total := 0
var _pos := 0
var _done := false
var _target_cutoff := 6000.0


func _ready() -> void:
	instance = self
	ensure_buses()
	player = AudioStreamPlayer.new()
	player.bus = "Music"
	player.volume_db = -6.0
	add_child(player)
	_total = total_samples()
	_data.resize(_total * 2)


static func ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	var mi := AudioServer.get_bus_index("Music")
	if AudioServer.get_bus_effect_count(mi) == 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 6000.0
		AudioServer.add_bus_effect(mi, lp)


static func seconds_per_chord() -> float:
	return 4.0 * 60.0 / BPM


static func total_samples() -> int:
	return int(RATE * seconds_per_chord() * CHORDS.size())


## Pure sample function (also used by tests): value in [-1, 1] at sample i.
static func sample(i: int) -> float:
	var t := float(i) / RATE
	var spc := seconds_per_chord()
	var ci := int(t / spc) % CHORDS.size()
	var tc := fmod(t, spc)
	# Crossfade envelope inside each chord avoids clicks at chord changes.
	var env := minf(1.0, tc / 0.6) * minf(1.0, (spc - tc) / 0.6)
	var v := 0.0
	for f in CHORDS[ci]:
		v += sin(TAU * f * t) * 0.10 + sin(TAU * f * 1.003 * t) * 0.06
	v *= env
	var b: float = BASS[ci]
	v += sin(TAU * b * t) * 0.16 * env
	# Eighth-note plucks an octave up with exponential decay.
	var eighth := 60.0 / BPM / 2.0
	var step := int(t / eighth)
	var te := fmod(t, eighth)
	var note: float = CHORDS[ci][ARP_PATTERN[step % ARP_PATTERN.size()]] * 2.0
	var ph := fmod(note * t, 1.0)
	var tri := 4.0 * absf(ph - 0.5) - 1.0
	v += tri * 0.07 * exp(-te * 6.0) * minf(1.0, te / 0.005)
	return clampf(v, -1.0, 1.0)


func _process(delta: float) -> void:
	if not _done:
		var end := mini(_pos + CHUNK, _total)
		for i in range(_pos, end):
			_data.encode_s16(i * 2, int(sample(i) * 26000.0))
		_pos = end
		if _pos >= _total:
			_finish()
	var mi := AudioServer.get_bus_index("Music")
	if mi >= 0 and AudioServer.get_bus_effect_count(mi) > 0:
		var lp := AudioServer.get_bus_effect(mi, 0) as AudioEffectLowPassFilter
		lp.cutoff_hz = lerpf(lp.cutoff_hz, _target_cutoff, minf(1.0, delta * 1.5))


func _finish() -> void:
	_done = true
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = _data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = _total
	player.stream = wav
	if DisplayServer.get_name() != "headless":
		player.play()


func is_ready() -> bool:
	return _done


## 0 = calm (bright), 1 = crisis (muffled).
func set_tension(t: float) -> void:
	_target_cutoff = lerpf(6000.0, 700.0, clampf(t, 0.0, 1.0))
