class_name ContentDB
extends RefCounted
## Loads data-driven game content from res://data/content.json once and caches it.

const CONTENT_PATH := "res://data/content.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var text := FileAccess.get_file_as_string(CONTENT_PATH)
		var parsed: Variant = JSON.parse_string(text)
		assert(parsed is Dictionary, "content.json failed to parse")
		_data = parsed
	return _data


static func rules() -> Dictionary:
	return data()["rules"]


static func system_ids() -> Array[String]:
	var out: Array[String] = []
	for s in data()["systems"]:
		out.append(String(s["id"]))
	return out


static func system_def(id: String) -> Dictionary:
	for s in data()["systems"]:
		if s["id"] == id:
			return s
	return {}


static func type_def(id: String) -> Dictionary:
	for t in data()["consequence_types"]:
		if t["id"] == id:
			return t
	return {}


static func event_def(id: String) -> Dictionary:
	for e in data()["events"]:
		if e["id"] == id:
			return e
	return {}


static func transformation_def(id: String) -> Dictionary:
	for t in data()["transformations"]:
		if t["id"] == id:
			return t
	return {}


static func crisis_for_system(system_id: String) -> Dictionary:
	for c in data()["crises"]:
		if c["system"] == system_id:
			return c
	return {}


static func crisis_def(id: String) -> Dictionary:
	for c in data()["crises"]:
		if c["id"] == id:
			return c
	return {}


static var _campaign: Dictionary = {}


static func campaign() -> Dictionary:
	if _campaign.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))
		_campaign = parsed if parsed is Dictionary else {"levels": []}
	return _campaign


static func scenario_def(id: String) -> Dictionary:
	for s in data()["scenarios"]:
		if s["id"] == id:
			return s
	for s in campaign().get("levels", []):
		if s["id"] == id:
			return s
	return {}


static func intervention_def(kind: String) -> Dictionary:
	return data()["interventions"].get(kind, {})


static func vulnerability(type_id: String, system_id: String) -> int:
	return int(type_def(type_id)["vulnerability"].get(system_id, 100))


static func is_positive(type_id: String) -> bool:
	return bool(type_def(type_id).get("positive", false))


## Integer percentage with round-half-up. Keeps simulation float-free.
static func pct(value: int, percent: int) -> int:
	return int((value * percent + 50) / 100)
