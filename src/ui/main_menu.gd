class_name MainMenu
extends Control
## Title screen over a living, decorative valley.

signal start_run(scenario_id: String, run_seed: int)
signal continue_run
signal open_settings

var seed_edit: LineEdit
var error_label: Label


func _ready() -> void:
	UIKit.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	p.offset_left = 60
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(380, 0)
	add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(vb)
	vb.add_child(UIKit.label("CONSEQUARRY", 40, Palette.ACCENT))
	vb.add_child(UIKit.label("Every consequence must go somewhere.", 16, Palette.TEXT_DIM))
	vb.add_child(HSeparator.new())
	var first: Button = null
	if SaveSystem.has_run():
		first = UIKit.button("Continue", func(): continue_run.emit())
		vb.add_child(first)
	var tut := UIKit.button("Tutorial (2 min)" if not GameSettings.tutorial_done else "Replay tutorial", func(): start_run.emit("tutorial", 20261122))
	var newb := UIKit.button("New valley", func(): start_run.emit("p0_valley", SeedCode.random_seed()))
	if GameSettings.tutorial_done:
		vb.add_child(newb)
		vb.add_child(tut)
	else:
		vb.add_child(tut)
		vb.add_child(newb)
	if first == null:
		first = vb.get_child(3) as Button
	var row := HBoxContainer.new()
	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = "CQ-XXXX-XXXX"
	seed_edit.custom_minimum_size = Vector2(190, 0)
	row.add_child(seed_edit)
	row.add_child(UIKit.button("Play seed", _play_seed))
	vb.add_child(row)
	error_label = UIKit.label("", 12, Palette.BAD)
	vb.add_child(error_label)
	vb.add_child(UIKit.button("Settings", func(): open_settings.emit()))
	if not OS.has_feature("web"):
		vb.add_child(UIKit.button("Quit", func(): get_tree().quit()))
	vb.add_child(UIKit.label("P0 prototype %s · offline · no account" % ProjectSettings.get_setting("application/config/version"), 11, Palette.TEXT_DIM))
	first.call_deferred("grab_focus")


func _play_seed() -> void:
	var v := SeedCode.decode(seed_edit.text)
	if v < 0:
		error_label.text = "Invalid seed code."
		return
	start_run.emit("p0_valley", v)
