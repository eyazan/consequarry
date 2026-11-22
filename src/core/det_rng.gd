class_name DetRng
extends RefCounted
## Deterministic, serializable 32-bit xorshift RNG.
## Integer-only so results are identical on every platform.

const MASK32 := 0xFFFFFFFF

var state: int = 1


func _init(seed_value: int = 1) -> void:
	set_seed(seed_value)


func set_seed(seed_value: int) -> void:
	# SplitMix-style scramble of the seed into a non-zero 32-bit state.
	var s := (seed_value ^ 0x9E3779B9) & MASK32
	s = ((s ^ (s >> 16)) * 0x45D9F3B) & MASK32
	s = ((s ^ (s >> 16)) * 0x45D9F3B) & MASK32
	s = (s ^ (s >> 16)) & MASK32
	state = s if s != 0 else 0x1234567


func next_u32() -> int:
	var x := state
	x ^= (x << 13) & MASK32
	x ^= x >> 17
	x ^= (x << 5) & MASK32
	state = x & MASK32
	return state


## Uniform integer in [0, n).
func range_int(n: int) -> int:
	if n <= 1:
		return 0
	return next_u32() % n


## Integer in [lo, hi] inclusive.
func between(lo: int, hi: int) -> int:
	return lo + range_int(hi - lo + 1)


func chance_percent(p: int) -> bool:
	return range_int(100) < p


## Picks an index according to integer weights. Returns -1 if all weights are zero.
func weighted_index(weights: Array) -> int:
	var total := 0
	for w in weights:
		total += maxi(0, int(w))
	if total <= 0:
		return -1
	var roll := range_int(total)
	for i in weights.size():
		roll -= maxi(0, int(weights[i]))
		if roll < 0:
			return i
	return weights.size() - 1
