class_name SaveSystem
extends RefCounted
## Local, versioned JSON saves. Writes atomically (temp file + rename).

const RUN_PATH := "user://run_save.json"
const SETTINGS_PATH := "user://settings.cfg"


static func save_world(w: WorldState, path: String = RUN_PATH) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("save failed: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(w.to_dict()))
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	if FileAccess.file_exists(path):
		dir.remove(path.replace("user://", ""))
	return dir.rename(tmp.replace("user://", ""), path.replace("user://", "")) == OK


static func load_world(path: String = RUN_PATH) -> WorldState:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("corrupt save ignored")
		return null
	if int(parsed.get("save_version", 0)) != WorldState.SAVE_VERSION:
		push_warning("save version mismatch ignored")
		return null
	return WorldState.from_dict(parsed)


static func has_run() -> bool:
	if not FileAccess.file_exists(RUN_PATH):
		return false
	var w := load_world()
	return w != null and not w.is_over()


static func clear_run() -> void:
	if FileAccess.file_exists(RUN_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_PATH))
