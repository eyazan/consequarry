class_name GameSettings
extends RefCounted
## Player settings persisted to user://settings.cfg.

const PATH := "user://settings.cfg"
const SPEEDS := [1.0, 1.8, 0.0]  # normal, fast, instant (0 = skip animations)
const SPEED_NAMES := ["Normal", "Fast", "Instant"]

static var master_volume: float = 0.7
static var anim_speed_index: int = 0
static var screen_shake: bool = true
static var fullscreen: bool = false
static var always_show_links: bool = true
static var tutorial_done: bool = false
static var _loaded := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	master_volume = float(cf.get_value("audio", "master_volume", master_volume))
	anim_speed_index = clampi(int(cf.get_value("gameplay", "anim_speed", anim_speed_index)), 0, 2)
	screen_shake = bool(cf.get_value("accessibility", "screen_shake", screen_shake))
	fullscreen = bool(cf.get_value("video", "fullscreen", fullscreen))
	always_show_links = bool(cf.get_value("gameplay", "always_show_links", always_show_links))
	tutorial_done = bool(cf.get_value("progress", "tutorial_done", tutorial_done))


static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "master_volume", master_volume)
	cf.set_value("gameplay", "anim_speed", anim_speed_index)
	cf.set_value("accessibility", "screen_shake", screen_shake)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.set_value("gameplay", "always_show_links", always_show_links)
	cf.set_value("progress", "tutorial_done", tutorial_done)
	cf.save(PATH)


static func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


## Duration multiplier for animations; 0 means instant.
static func anim_scale() -> float:
	var s: float = SPEEDS[anim_speed_index]
	return 0.0 if s == 0.0 else 1.0 / s
