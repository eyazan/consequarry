class_name SettingsPanel
extends Control
## Modal settings: volume, animation speed, accessibility, display.

signal closed


func _ready() -> void:
	UIKit.fill_viewport(self)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(420, 0)
	add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	p.add_child(vb)
	vb.add_child(UIKit.label("SETTINGS", 22, Palette.ACCENT))
	vb.add_child(UIKit.label("Master volume", 14))
	var vol := HSlider.new()
	vol.min_value = 0
	vol.max_value = 1
	vol.step = 0.05
	vol.value = GameSettings.master_volume
	vol.value_changed.connect(func(v): GameSettings.master_volume = v; GameSettings.apply())
	vb.add_child(vol)
	vb.add_child(UIKit.label("Resolution animation speed", 14))
	var sp := OptionButton.new()
	for n in GameSettings.SPEED_NAMES:
		sp.add_item(n)
	sp.selected = GameSettings.anim_speed_index
	sp.item_selected.connect(func(i): GameSettings.anim_speed_index = i)
	vb.add_child(sp)
	var shake := CheckBox.new()
	shake.text = "Screen shake"
	shake.button_pressed = GameSettings.screen_shake
	shake.toggled.connect(func(v): GameSettings.screen_shake = v)
	vb.add_child(shake)
	var links := CheckBox.new()
	links.text = "Always show causal links"
	links.button_pressed = GameSettings.always_show_links
	links.toggled.connect(func(v): GameSettings.always_show_links = v)
	vb.add_child(links)
	var fs := CheckBox.new()
	fs.text = "Fullscreen"
	fs.button_pressed = GameSettings.fullscreen
	fs.toggled.connect(func(v): GameSettings.fullscreen = v; GameSettings.apply())
	vb.add_child(fs)
	vb.add_child(UIKit.label("Consequence types are always shape-coded for colour-blind play.", 12, Palette.TEXT_DIM, true))
	var close := UIKit.button("Close", _close)
	vb.add_child(close)
	close.call_deferred("grab_focus")


func _close() -> void:
	GameSettings.save_settings()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
