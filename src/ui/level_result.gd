class_name LevelResult
extends Control
## End of a campaign level: stars, why, and what next.

signal next_level
signal retry
signal to_map

var world: WorldState


func setup(w: WorldState) -> void:
	world = w


func _ready() -> void:
	UIKit.fill_viewport(self)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
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
	var stars := Campaign.stars(world)
	var new_best := Campaign.record(world.scenario_id, stars)
	var won := stars > 0
	vb.add_child(UIKit.label(Loc.t("Valley saved!") if won else Loc.t("Valley lost"), 30, Palette.GOOD if won else Palette.BAD))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for k in 3:
		var s := UIKit.label("★", 64, Palette.ACCENT if k < stars else Color(0.3, 0.32, 0.38))
		s.pivot_offset = Vector2(24, 36)
		row.add_child(s)
		if k < stars:
			s.scale = Vector2.ZERO
			var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.25 + 0.25 * k)
			tw.tween_property(s, "scale", Vector2.ONE, 0.35)
	vb.add_child(row)
	if new_best and won:
		vb.add_child(UIKit.label("New best!", 14, Palette.ACCENT))
	var reason := UIKit.label(Loc.outcome(world), 15, Palette.TEXT, true)
	reason.custom_minimum_size = Vector2(430, 0)
	vb.add_child(reason)
	var st: Dictionary = world.scenario().get("stars", {})
	if won and stars < 3:
		vb.add_child(UIKit.label(Loc.t("Next star: average health %d+ (you had %d).") % [int(st.get("two_avg", 0)) if stars == 1 else int(st.get("three_avg", 0)), world.average_health()], 14, Palette.TEXT_DIM, true))
	if not won:
		vb.add_child(UIKit.label(Loc.t("Tip: move the biggest troubles away from weak districts, or tap Hint."), 14, Palette.TEXT_DIM, true))
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	var has_next := Campaign.next_level_id(world.scenario_id) != ""
	var first: Button
	if won and has_next:
		first = UIKit.button("Next level ▶", func(): next_level.emit())
		btns.add_child(first)
	var again := UIKit.button("Retry", func(): retry.emit())
	btns.add_child(again)
	btns.add_child(UIKit.button("Map", func(): to_map.emit()))
	vb.add_child(btns)
	(first if first else again).call_deferred("grab_focus")
