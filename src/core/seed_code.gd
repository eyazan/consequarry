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


## Daily valley: same seed and scenario for everyone on a given UTC date, computed offline.
static func daily(date: Dictionary) -> Dictionary:
	var key := "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]
	var h := DetRng.new(key.hash())
	h.next_u32()
	var run_seed := h.next_u32() & 0x7FFFFFFF
	var ids: Array = []
	for sc in ContentDB.data()["scenarios"]:
		if sc["id"] != "tutorial":
			ids.append(String(sc["id"]))
	var day_index := int(Time.get_unix_time_from_datetime_dict({"year": date["year"], "month": date["month"], "day": date["day"], "hour": 0, "minute": 0, "second": 0}) / 86400)
	return {"date": key, "seed": run_seed, "scenario": ids[posmod(day_index, ids.size())]}


static func today() -> Dictionary:
	return daily(Time.get_date_dict_from_system(true))
