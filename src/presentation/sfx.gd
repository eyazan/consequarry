class_name Sfx
extends Node
## Tiny procedural sound synthesiser: no audio assets, no licences required.

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _next := 0
const RATE := 22050


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)


func play(name: String, pitch: float = 1.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not _cache.has(name):
		_cache[name] = _make(name)
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _cache[name]
	p.pitch_scale = pitch
	p.play()


func _make(name: String) -> AudioStreamWAV:
	match name:
		"select": return _tone([880.0], 0.06, 0.25, "sine")
		"hover": return _tone([1320.0], 0.03, 0.08, "sine")
		"redirect": return _tone([520.0, 780.0], 0.14, 0.3, "sine")
		"split": return _tone([660.0, 440.0], 0.14, 0.3, "triangle")
		"delay": return _tone([330.0, 300.0], 0.2, 0.3, "triangle")
		"transform": return _tone([523.0, 659.0, 784.0, 1046.0], 0.32, 0.3, "sine")
		"crisis": return _tone([110.0, 82.0], 0.5, 0.45, "noise_low")
		"impact": return _tone([140.0], 0.18, 0.45, "noise_low")
		"heal": return _tone([700.0, 940.0], 0.18, 0.25, "sine")
		"end_turn": return _tone([220.0, 330.0], 0.25, 0.3, "triangle")
		"event": return _tone([196.0, 185.0], 0.35, 0.35, "square")
		"victory": return _tone([523.0, 659.0, 784.0, 1046.0, 1318.0], 0.9, 0.35, "sine")
		"defeat": return _tone([392.0, 330.0, 262.0, 196.0], 1.0, 0.35, "triangle")
		"error": return _tone([180.0, 160.0], 0.12, 0.3, "square")
	return _tone([440.0], 0.1, 0.2, "sine")


func _tone(freqs: Array, dur: float, vol: float, wave: String) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := DetRng.new(int(freqs[0]))
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var seg := mini(freqs.size() - 1, int(float(i) / n * freqs.size()))
		var f: float = freqs[seg]
		var ph := fmod(t * f, 1.0)
		var v := 0.0
		match wave:
			"sine": v = sin(TAU * ph)
			"triangle": v = 4.0 * absf(ph - 0.5) - 1.0
			"square": v = 0.6 if ph < 0.5 else -0.6
			"noise_low":
				var noise := (rng.range_int(2000) / 1000.0) - 1.0
				lp = lp * 0.92 + noise * 0.08
				v = lp * 3.0 + sin(TAU * ph) * 0.5
		var env := minf(1.0, t / 0.008) * pow(1.0 - float(i) / n, 2.0)
		var s := int(clampf(v * env * vol, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
