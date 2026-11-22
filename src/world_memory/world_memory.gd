class_name WorldMemory
extends RefCounted
## Persistent within-run memory. Every entry changes later rules, not just visuals:
##  - absorbed harm   -> resilience (less damage from future harm on that system)
##  - transforms      -> adaptation (better efficiency for that rule)
##  - redirects into  -> dependency (lower capacity of the receiving system)
##  - crises          -> resistance (lower crisis yield, higher instability)
##  - event repeats   -> familiarity (smaller magnitude of repeated events)
##  - deep wounds     -> scars (max health reduced permanently)

var harm_absorbed: Dictionary = {}     # system -> int
var transforms: Dictionary = {}        # rule id -> int
var redirects_in: Dictionary = {}      # system -> int
var crises: Dictionary = {}            # system -> int
var events_seen: Dictionary = {}       # event id -> int
var scars: Dictionary = {}             # system -> int
var chronicle: Array = []              # {turn, text, system}


func _r(key: String) -> int:
	return int(ContentDB.rules()[key])


func resilience(system_id: String) -> int:
	return mini(_r("max_resilience"), int(harm_absorbed.get(system_id, 0)) / _r("resilience_per_magnitude"))


func adaptation(rule_id: String) -> int:
	return mini(_r("max_adaptation"), int(transforms.get(rule_id, 0)) * _r("adaptation_per_transform"))


func capacity_loss(system_id: String) -> int:
	return int(redirects_in.get(system_id, 0)) / _r("redirects_per_capacity_loss")


func crisis_yield_percent(system_id: String) -> int:
	var n := int(crises.get(system_id, 0))
	return maxi(_r("crisis_min_yield_percent"), 100 - n * _r("crisis_resistance_percent"))


func event_familiarity_percent(event_id: String) -> int:
	var n := int(events_seen.get(event_id, 0))
	return mini(_r("event_repeat_max_reduction"), n * _r("event_repeat_reduction"))


func note(turn: int, system_id: String, text: String) -> void:
	chronicle.append({"turn": turn, "system": system_id, "text": text})


func add(dict: Dictionary, key: String, amount: int = 1) -> int:
	dict[key] = int(dict.get(key, 0)) + amount
	return int(dict[key])


func to_dict() -> Dictionary:
	return {"harm_absorbed": harm_absorbed.duplicate(), "transforms": transforms.duplicate(),
		"redirects_in": redirects_in.duplicate(), "crises": crises.duplicate(),
		"events_seen": events_seen.duplicate(), "scars": scars.duplicate(),
		"chronicle": chronicle.duplicate(true)}


static func _int_dict(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[String(k)] = int(d[k])
	return out


static func from_dict(d: Dictionary) -> WorldMemory:
	var m := WorldMemory.new()
	m.harm_absorbed = _int_dict(d["harm_absorbed"])
	m.transforms = _int_dict(d["transforms"])
	m.redirects_in = _int_dict(d["redirects_in"])
	m.crises = _int_dict(d["crises"])
	m.events_seen = _int_dict(d["events_seen"])
	m.scars = _int_dict(d["scars"])
	m.chronicle = d["chronicle"].duplicate(true)
	for entry in m.chronicle:
		entry["turn"] = int(entry["turn"])
	return m
