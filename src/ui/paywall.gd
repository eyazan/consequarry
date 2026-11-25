class_name Paywall
extends Control
## Upgrade screen. Honest and simple: one price, one time, no ads.

signal unlocked
signal closed

var store := Store.new()
var status: Label


func _ready() -> void:
	UIKit.fill_viewport(self)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	add_child(dim)
	UIKit.fill_viewport(dim)
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(460, 0)
	add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(vb)
	if Entitlements.is_demo():
		vb.add_child(UIKit.label("You finished the demo!", 28, Palette.ACCENT))
		vb.add_child(UIKit.label("The full game has 20 more valleys in the Dry Hills and Boomtown, the Daily valley and Classic mode.", 15, Palette.TEXT, true))
		vb.add_child(UIKit.label("Get CONSEQUARRY on Steam to keep playing. Your progress carries over.", 14, Palette.TEXT_DIM, true))
		vb.add_child(UIKit.button("Close", _close))
		return
	vb.add_child(UIKit.label("Unlock the full game", 28, Palette.ACCENT))
	for line in ["20 more valleys: Dry Hills and Boomtown", "New moves: Split, Delay, Controlled Crisis", "Daily valley and Classic mode", "One-time purchase. No ads. No subscription."]:
		vb.add_child(UIKit.label("•  " + Loc.t(line), 15, Palette.TEXT, true))
	var buy := UIKit.button(Loc.t("Unlock for %s") % store.price_text, _buy)
	buy.add_theme_font_size_override("font_size", 20)
	vb.add_child(buy)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UIKit.button("Restore purchase", _restore))
	row.add_child(UIKit.button("Not now", _close))
	vb.add_child(row)
	status = UIKit.label("", 13, Palette.TEXT_DIM, true)
	vb.add_child(status)
	store.purchased.connect(func():
		unlocked.emit()
		queue_free())
	store.failed.connect(func(reason: String): status.text = Loc.t(reason))
	buy.call_deferred("grab_focus")


func _buy() -> void:
	status.text = Loc.t("Opening the store…")
	store.buy()


func _restore() -> void:
	status.text = Loc.t("Checking your purchases…")
	store.restore()


func _close() -> void:
	closed.emit()
	queue_free()
