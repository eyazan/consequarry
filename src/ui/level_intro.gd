class_name LevelIntro
extends Control
## Goal card shown before a campaign level starts.

signal start_pressed

var world: WorldState


func setup(w: WorldState) -> void:
	world = w


func _ready() -> void:
	UIKit.fill_viewport(self)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
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
	var sc := world.scenario()
	vb.add_child(UIKit.label(Loc.t("%s · LEVEL %d") % [Loc.upper(Loc.t(String(sc["region"]))), int(sc["number"])], 13, Palette.TEXT_DIM))
	vb.add_child(UIKit.label(Loc.t(String(sc["name"])), 30, Palette.ACCENT))
	var desc := UIKit.label(Loc.t(String(sc["description"])), 16, Palette.TEXT, true)
	desc.custom_minimum_size = Vector2(430, 0)
	vb.add_child(desc)
	vb.add_child(HSeparator.new())
	vb.add_child(UIKit.label(Loc.t("Survive %d seasons.") % world.max_turns, 16))
	vb.add_child(UIKit.label(Loc.t("Keep every district above %d health. If one collapses, you lose.") % int(sc["win"]["min_health"]), 15, Palette.TEXT, true))
	var st: Dictionary = sc.get("stars", {})
	vb.add_child(UIKit.label(Loc.t("★★  average health %d+     ★★★  %d+") % [int(st.get("two_avg", 0)), int(st.get("three_avg", 0))], 15, Palette.ACCENT))
	vb.add_child(UIKit.label(Loc.t("%d moves per season.") % world.actions_per_turn, 14, Palette.TEXT_DIM))
	var play := UIKit.button("Play ▶", func():
		start_pressed.emit()
		queue_free())
	play.add_theme_font_size_override("font_size", 20)
	vb.add_child(play)
	play.call_deferred("grab_focus")
