class_name GameSettings
extends RefCounted
## Player settings persisted to user://settings.cfg.

const PATH := "user://settings.cfg"
const SPEEDS := [1.0, 1.8, 0.0]  # normal, fast, instant (0 = skip animations)
const SPEED_NAMES := ["Normal", "Fast", "Instant"]

static var master_volume: float = 0.7
static var music_volume: float = 0.6
static var sfx_volume: float = 0.8
static var anim_speed_index: int = 0
static var screen_shake: bool = true
static var fullscreen: bool = false
static var always_show_links: bool = true
static var tutorial_done: bool = false
static var runs_started: int = 0
static var layout_mode: int = 0  # 0 auto, 1 desktop, 2 compact (phones/tablets)
const LAYOUT_NAMES := ["Auto", "Desktop", "Compact (touch)"]
static var compact: bool = false
static var language: String = "auto"  # "auto", "en", "tr"
const LANGUAGES := ["auto", "en", "tr"]
const LANGUAGE_NAMES := ["Auto", "English", "Türkçe"]
static var _loaded := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	master_volume = float(cf.get_value("audio", "master_volume", master_volume))
	music_volume = float(cf.get_value("audio", "music_volume", music_volume))
	sfx_volume = float(cf.get_value("audio", "sfx_volume", sfx_volume))
	anim_speed_index = clampi(int(cf.get_value("gameplay", "anim_speed", anim_speed_index)), 0, 2)
	screen_shake = bool(cf.get_value("accessibility", "screen_shake", screen_shake))
	fullscreen = bool(cf.get_value("video", "fullscreen", fullscreen))
	always_show_links = bool(cf.get_value("gameplay", "always_show_links", always_show_links))
	tutorial_done = bool(cf.get_value("progress", "tutorial_done", tutorial_done))
	runs_started = int(cf.get_value("progress", "runs_started", runs_started))
	layout_mode = clampi(int(cf.get_value("video", "layout_mode", layout_mode)), 0, 2)
	language = String(cf.get_value("general", "language", language))


static func next_attempt(level_id: String) -> int:
	var cf := ConfigFile.new()
	cf.load(PATH)
	var n := int(cf.get_value("attempts", level_id, 0)) + 1
	cf.set_value("attempts", level_id, n)
	cf.save(PATH)
	return n


static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)  # keep other sections (attempt counters)
	cf.set_value("audio", "master_volume", master_volume)
	cf.set_value("audio", "music_volume", music_volume)
	cf.set_value("audio", "sfx_volume", sfx_volume)
	cf.set_value("gameplay", "anim_speed", anim_speed_index)
	cf.set_value("accessibility", "screen_shake", screen_shake)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.set_value("gameplay", "always_show_links", always_show_links)
	cf.set_value("progress", "tutorial_done", tutorial_done)
	cf.set_value("progress", "runs_started", runs_started)
	cf.set_value("video", "layout_mode", layout_mode)
	cf.set_value("general", "language", language)
	cf.save(PATH)


static func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)
	Music.ensure_buses()
	for pair in [["Music", music_volume], ["SFX", sfx_volume]]:
		var bi := AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_volume_db(bi, linear_to_db(maxf(float(pair[1]), 0.0001)))
		AudioServer.set_bus_mute(bi, float(pair[1]) <= 0.001)
	if DisplayServer.get_name() != "headless" and not OS.has_feature("web") and not OS.has_feature("mobile"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


## Duration multiplier for animations; 0 means instant.
static func anim_scale() -> float:
	var s: float = SPEEDS[anim_speed_index]
	return 0.0 if s == 0.0 else 1.0 / s


## Phones and small touch screens get a larger, decluttered layout.
static func detect_compact() -> bool:
	if OS.get_cmdline_user_args().has("--compact") or layout_mode == 2:
		return true
	if layout_mode == 1:
		return false
	if OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android"):
		return true
	return false


## Applies the logical canvas size: compact uses a smaller canvas so text and
## touch targets render physically larger.
static func apply_layout(window: Window) -> void:
	compact = detect_compact()
	window.content_scale_size = Vector2i(900, 460) if compact else Vector2i(1280, 720)


# ------------------------------------------------------------------ daily best (local only)

const DAILY_PATH := "user://daily.cfg"


static func daily_best(date: String) -> int:
	var cf := ConfigFile.new()
	if cf.load(DAILY_PATH) != OK:
		return -1
	return int(cf.get_value("best", date, -1))


## Returns true if this is a new best for the date.
static func record_daily(date: String, score: int) -> bool:
	var cf := ConfigFile.new()
	cf.load(DAILY_PATH)
	var prev := int(cf.get_value("best", date, -1))
	if score > prev:
		cf.set_value("best", date, score)
		cf.save(DAILY_PATH)
		return true
	return false


## Applies the language: "auto" follows the device (Turkish devices get Turkish).
static func apply_language() -> void:
	var arg := OS.get_cmdline_user_args().find("--lang")
	var lang := language
	if arg >= 0 and OS.get_cmdline_user_args().size() > arg + 1:
		lang = OS.get_cmdline_user_args()[arg + 1]
	if lang == "auto":
		lang = "tr" if OS.get_locale_language() == "tr" else "en"
	TranslationServer.set_locale(lang)
