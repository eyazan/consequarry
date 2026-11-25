class_name Store
extends RefCounted
## Thin purchase layer. On iOS it talks to Godot's InAppStore plugin when that
## plugin is present in the build (it is added when the App Store product is
## set up; see docs/platforms/MONETIZATION.md). Elsewhere purchases are not
## available and the UI says so; nothing is ever charged without the platform
## store's own confirmation sheet.

signal purchased
signal failed(reason: String)

const PLUGIN := "InAppStore"
var _plugin: Object = null
var price_text := "$4.99"


func _init() -> void:
	if Engine.has_singleton(PLUGIN):
		_plugin = Engine.get_singleton(PLUGIN)


func available() -> bool:
	return _plugin != null or OS.get_cmdline_user_args().has("--fake-store")


func buy() -> void:
	if OS.get_cmdline_user_args().has("--fake-store"):
		Entitlements.grant_full_game()
		purchased.emit()
		return
	if _plugin == null:
		failed.emit("Purchases are not available in this build.")
		return
	_plugin.call("purchase", {"product_id": Entitlements.PRODUCT_ID})
	_poll()


func restore() -> void:
	if OS.get_cmdline_user_args().has("--fake-store"):
		failed.emit("Nothing to restore.")
		return
	if _plugin == null:
		failed.emit("Purchases are not available in this build.")
		return
	_plugin.call("restore_purchases")
	_poll()


## The iOS plugin reports results through a pending-event queue.
func _poll() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for _i in 600:
		await tree.process_frame
		if int(_plugin.call("get_pending_event_count")) > 0:
			var ev: Dictionary = _plugin.call("pop_pending_event")
			if ev.get("result", "") == "ok" and ev.get("product_id", "") == Entitlements.PRODUCT_ID:
				Entitlements.grant_full_game()
				purchased.emit()
			else:
				failed.emit(String(ev.get("error", "The purchase did not complete.")))
			return
	failed.emit("The store did not answer. Please try again.")
