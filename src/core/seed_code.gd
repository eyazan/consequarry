class_name SeedCode
extends RefCounted
## Shareable seed codes like "CQ-7K2M-9QXA". Crockford-style alphabet, no 0/O/1/I.

const ALPHABET := "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"


static func encode(value: int) -> String:
	var v := value & 0xFFFFFFFF
	var chars := ""
	for _i in 7:
		chars = ALPHABET[v % 32] + chars
		v = v / 32
	chars = ALPHABET[v % 32] + chars
	return "CQ-%s-%s" % [chars.substr(0, 4), chars.substr(4, 4)]


## Returns -1 if the code is invalid.
static func decode(code: String) -> int:
	var clean := code.strip_edges().to_upper().replace("CQ-", "").replace("-", "").replace(" ", "")
	if clean.length() != 8:
		return -1
	var v := 0
	for ch in clean:
		var idx := ALPHABET.find(ch)
		if idx < 0:
			return -1
		v = v * 32 + idx
	return v & 0xFFFFFFFF


static func random_seed() -> int:
	var t := Time.get_ticks_usec() ^ int(Time.get_unix_time_from_system() * 1000.0)
	var r := DetRng.new(t)
	return r.next_u32() & 0x7FFFFFFF
