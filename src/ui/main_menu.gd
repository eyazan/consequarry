class_name MainMenu
extends Control
## Title screen over a living, decorative valley.

signal start_run(scenario_id: String, run_seed: int)
signal start_daily
signal continue_run
signal open_settings

var seed_edit: LineEdit
var scenario_pick: OptionButton
var scenario_desc: Label
var error_label: Label


func _ready() -> void:
	UIKit.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	p.offset_left = 20 if GameSettings.compact else 60
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(380, 0)
	add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(vb)
	vb.add_child(UIKit.label("CONSEQUARRY", 30 if GameSettings.compact else 40, Palette.ACCENT))
	vb.add_child(UIKit.label("Every consequence must go somewhere.", 16, Palette.TEXT_DIM))
	vb.add_child(HSeparator.new())
	var first: Button = null
	if SaveSystem.has_run():
		first = UIKit.button("Continue", func(): continue_run.emit())
		vb.add_child(first)
	var tut := UIKit.button(Loc.t("Tutorial (2 min)") if not GameSettings.tutorial_done else Loc.t("Replay tutorial"), func(): start_run.emit("tutorial", 20261122))
	var newb := UIKit.button("New valley", func(): start_run.emit(_scenario(), SeedCode.random_seed()))
	if GameSettings.tutorial_done:
		vb.add_child(newb)
		vb.add_child(tut)
	else:
		vb.add_child(tut)
		vb.add_child(newb)
	if first == null:
		first = vb.get_child(3) as Button
	var d := SeedCode.today()
	var best := GameSettings.daily_best(d["date"])
	var daily_btn := UIKit.button(Loc.t("Daily valley · %s · %s") % [d["date"], Loc.scenario(d["scenario"])], func(): start_daily.emit(),
		"Everyone gets the same valley today. Best score is kept on this device.")
	vb.add_child(daily_btn)
	if best >= 0:
		vb.add_child(UIKit.label(Loc.t("Today's best score: %d") % best, 12, Palette.GOOD))
	scenario_pick = OptionButton.new()
	for sc in ContentDB.data()["scenarios"]:
		if sc["id"] != "tutorial":
			scenario_pick.add_item(String(Loc.t(String(sc["name"]))))
			scenario_pick.set_item_metadata(scenario_pick.item_count - 1, String(sc["id"]))
	scenario_pick.tooltip_text = "Scenario"
	scenario_desc = UIKit.label("", 12, Palette.TEXT_DIM, true)
	scenario_desc.custom_minimum_size = Vector2(340, 0)
	scenario_pick.item_selected.connect(func(_i): _update_desc())
	vb.add_child(scenario_pick)
	vb.add_child(scenario_desc)
	_update_desc()
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
	vb.add_child(UIKit.label(Loc.t("P0 prototype %s · offline · no account") % ProjectSettings.get_setting("application/config/version"), 11, Palette.TEXT_DIM))
	first.call_deferred("grab_focus")


func _play_seed() -> void:
	var v := SeedCode.decode(seed_edit.text)
	if v < 0:
		error_label.text = "Invalid seed code."
		return
	start_run.emit(_scenario(), v)


func _scenario() -> String:
	return String(scenario_pick.get_item_metadata(scenario_pick.selected))


func _update_desc() -> void:
	scenario_desc.text = String(ContentDB.scenario_def(_scenario()).get("description", ""))
