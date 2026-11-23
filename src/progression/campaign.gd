class_name Campaign
extends RefCounted
## Campaign of short levels: stars, unlocking and local progress.

const SAVE_PATH := "user://campaign.cfg"


static func levels() -> Array:
	return ContentDB.campaign().get("levels", [])


static func is_level(scenario_id: String) -> bool:
	return scenario_id.begins_with("lvl_")


## 0 = lost; 1 = survived; 2/3 = average health at the end above the level's bars.
static func stars(w: WorldState) -> int:
	if w.outcome != "victory":
		return 0
	var st: Dictionary = w.scenario().get("stars", {})
	var avg := w.average_health()
	if avg >= int(st.get("three_avg", 999)):
		return 3
	if avg >= int(st.get("two_avg", 999)):
		return 2
	return 1


static func best(level_id: String) -> int:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return 0
	return int(cf.get_value("stars", level_id, 0))


static func record(level_id: String, star_count: int) -> bool:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	if star_count > int(cf.get_value("stars", level_id, 0)):
		cf.set_value("stars", level_id, star_count)
		cf.save(SAVE_PATH)
		return true
	return false


static func total_stars() -> int:
	var n := 0
	for lv in levels():
		n += best(String(lv["id"]))
	return n


## A level is open when it is the first one or the previous one has >= 1 star.
static func is_unlocked(index: int) -> bool:
	if index <= 0:
		return true
	return best(String(levels()[index - 1]["id"])) > 0


static func next_level_id(level_id: String) -> String:
	var lv := levels()
	for i in lv.size():
		if lv[i]["id"] == level_id and i + 1 < lv.size():
			return String(lv[i + 1]["id"])
	return ""


static func first_open_unplayed() -> String:
	var lv := levels()
	for i in lv.size():
		if is_unlocked(i) and best(String(lv[i]["id"])) == 0:
			return String(lv[i]["id"])
	return String(lv[lv.size() - 1]["id"]) if not lv.is_empty() else ""


## Deterministic seed per level so a level plays the same until retried.
static func level_seed(level_id: String, attempt: int) -> int:
	return (level_id.hash() ^ (attempt * 7919)) & 0x7FFFFFFF
