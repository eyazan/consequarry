class_name Entitlements
extends RefCounted
## What the player owns. Business model (owner decision D-018):
##  - Free: the first FREE_LEVELS campaign levels (River Valley).
##  - Full game (one-time purchase, no ads, no subscription): all levels,
##    Daily valley, Classic mode and its scenarios.
## Build flavours are chosen with export feature tags:
##  - "store"  : mobile store build; full game is bought in-app (Store).
##  - "demo"   : Steam demo; only the free levels, no purchase inside.
##  - neither  : full builds (Steam full game, playtest/web/dev) — all unlocked.

const FREE_LEVELS := 10
const SAVE_PATH := "user://entitlements.cfg"
const PRODUCT_ID := "consequarry.full_game"

static var _cache := -1
static var test_flavour := ""  # tests only: "demo", "store" or "full"


static func is_demo() -> bool:
	if test_flavour != "":
		return test_flavour == "demo"
	return OS.has_feature("demo") or OS.get_cmdline_user_args().has("--demo-build")


static func is_store_build() -> bool:
	if test_flavour != "":
		return test_flavour == "store"
	return OS.has_feature("store") or OS.get_cmdline_user_args().has("--store-build")


static func owns_full_game() -> bool:
	if is_demo():
		return false
	if not is_store_build():
		return true
	if _cache < 0:
		var cf := ConfigFile.new()
		_cache = 1 if cf.load(SAVE_PATH) == OK and bool(cf.get_value("owned", PRODUCT_ID, false)) else 0
	return _cache == 1


static func grant_full_game() -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("owned", PRODUCT_ID, true)
	cf.save(SAVE_PATH)
	_cache = 1


static func level_index_is_free(index: int) -> bool:
	return index < FREE_LEVELS


static func can_play_level(index: int) -> bool:
	return level_index_is_free(index) or owns_full_game()


static func can_play_extras() -> bool:
	return owns_full_game()
