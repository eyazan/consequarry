class_name GameOverPanel
extends Control
## End-of-run screen: outcome, causal post-mortem, health chart, shareable seed.

signal replay_seed
signal new_run
signal to_menu

var world: WorldState


class HealthChart extends Control:
	var history: Array = []

	func _draw() -> void:
		var r := Rect2(Vector2(30, 6), size - Vector2(40, 26))
		draw_rect(r, Color(0, 0, 0, 0.3))
		var font := ThemeDB.fallback_font
		for y in [25, 55]:
			var py: float = r.position.y + r.size.y * (1.0 - y / 100.0)
			draw_line(Vector2(r.position.x, py), Vector2(r.end.x, py), Color(1, 1, 1, 0.12), 1)
			draw_string(font, Vector2(2, py + 4), str(y), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.TEXT_DIM)
		if history.size() < 1:
			return
		var n := maxi(1, history.size() - 1)
		for sid in ContentDB.system_ids():
			var pts := PackedVector2Array()
			for k in history.size():
				var hv := float(history[k]["health"][sid])
				pts.append(Vector2(r.position.x + r.size.x * k / n, r.position.y + r.size.y * (1.0 - hv / 100.0)))
			if pts.size() == 1:
				pts.append(pts[0] + Vector2(2, 0))
			draw_polyline(pts, Palette.system_color(sid), 2.0, true)
		draw_string(font, Vector2(r.position.x, r.end.y + 16), "Health of each system by season", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.TEXT_DIM)


func setup(w: WorldState) -> void:
	world = w


func _ready() -> void:
	UIKit.fill_viewport(self)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(720, 0)
	add_child(p)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.custom_minimum_size = Vector2(696, 0)
	scroll.add_child(vb)
	# Fit to screen height; scroll on small (phone) screens.
	vb.resized.connect(func(): scroll.custom_minimum_size = Vector2(700, minf(vb.size.y, size.y - 40.0)))
	var win := world.outcome == "victory"
	var title := Loc.t("THE VALLEY ENDURES") if win else (Loc.t("UNSUSTAINABLE") if world.outcome_reason.begins_with("Survived") else Loc.t("COLLAPSE"))
	vb.add_child(UIKit.label(title, 34, Palette.GOOD if win else Palette.BAD))
	vb.add_child(UIKit.label(Loc.outcome(world), 16, Palette.TEXT, true))
	var score_txt := Loc.t("Score %d") % world.score()
	if world.daily_date != "":
		var is_best := GameSettings.record_daily(world.daily_date, world.score())
		score_txt += Loc.t("  ·  Daily valley %s  ·  %s") % [world.daily_date, Loc.t("New best today!") if is_best else Loc.t("Best today: %d") % GameSettings.daily_best(world.daily_date)]
	vb.add_child(UIKit.label(score_txt, 18, Palette.ACCENT))
	var chart := HealthChart.new()
	chart.history = world.history
	chart.custom_minimum_size = Vector2(680, 110 if GameSettings.compact else 150)
	vb.add_child(chart)
	var legend := HBoxContainer.new()
	for sid in ContentDB.system_ids():
		legend.add_child(UIKit.label("■ %s  " % Loc.sys(sid), 12, Palette.system_color(sid)))
	vb.add_child(legend)
	vb.add_child(UIKit.rich(_post_mortem(), 13))
	var kinds := {"redirect": 0, "split": 0, "delay": 0, "transform": 0, "crisis": 0}
	for a in world.actions_log:
		kinds[a["kind"]] = int(kinds[a["kind"]]) + 1
	vb.add_child(UIKit.label(Loc.t("Seasons survived %d · Consequences tracked %d · Redirects %d · Splits %d · Delays %d · Transforms %d · Crises %d") % [
		world.history.size(), world.ledger.items.size(), kinds["redirect"], kinds["split"], kinds["delay"], kinds["transform"], kinds["crisis"]], 12, Palette.TEXT_DIM, true))
	var seed_row := HBoxContainer.new()
	seed_row.add_child(UIKit.label("Seed  ", 14, Palette.TEXT_DIM))
	var code := LineEdit.new()
	code.text = SeedCode.encode(world.run_seed)
	code.editable = false
	code.custom_minimum_size = Vector2(150, 0)
	seed_row.add_child(code)
	seed_row.add_child(UIKit.button("Copy", func(): DisplayServer.clipboard_set(code.text)))
	vb.add_child(seed_row)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	var again := UIKit.button("Retry this seed", func(): replay_seed.emit())
	btns.add_child(again)
	btns.add_child(UIKit.button("New valley", func(): new_run.emit()))
	btns.add_child(UIKit.button("Main menu", func(): to_menu.emit()))
	btns.add_child(UIKit.button("Copy run report", func(): DisplayServer.clipboard_set(run_report(world)); report_btn_feedback()))
	vb.add_child(btns)
	again.call_deferred("grab_focus")


func _post_mortem() -> String:
	## Failure must be educational: show what hurt the weakest system most.
	var worst := ""
	var worst_h := 1000
	for s: CivilizationSystem in world.systems.values():
		var key := s.health - (1000 if s.collapsed else 0)
		if key < worst_h:
			worst_h = key
			worst = s.id
	var sources: Dictionary = world.damage_by_source.get(worst, {})
	var arr: Array = []
	for k in sources:
		arr.append([k, int(sources[k])])
	arr.sort_custom(func(a, b): return a[1] > b[1])
	var s := Loc.t("[b]What hurt %s most:[/b] ") % Loc.sys(worst)
	if arr.is_empty():
		s += Loc.t("causal drag from its neighbours.")
	else:
		var parts: Array = []
		for k in mini(3, arr.size()):
			parts.append("%s (−%d)" % [Loc.source(String(arr[k][0])), arr[k][1]])
		s += ", ".join(parts)
	var mem := world.memory.chronicle
	if not mem.is_empty():
		s += "\n[b]" + Loc.t("The valley remembers:") + "[/b] " + Loc.note(mem[mem.size() - 1])
	return s


var _copied_label: Label


func report_btn_feedback() -> void:
	if _copied_label == null:
		_copied_label = UIKit.label("Copied — paste it into the feedback form.", 12, Palette.GOOD)
		get_child(1).get_child(0).get_child(0).add_child(_copied_label)


## Plain-text run report for playtest feedback (no network; tester pastes it).
static func run_report(w: WorldState) -> String:
	var kinds := {"redirect": 0, "split": 0, "delay": 0, "transform": 0, "crisis": 0}
	for a in w.actions_log:
		kinds[a["kind"]] = int(kinds[a["kind"]]) + 1
	var lines: Array = []
	lines.append("CONSEQUARRY run report v1 (%s)" % ProjectSettings.get_setting("application/config/version"))
	lines.append("seed=%s scenario=%s outcome=%s seasons=%d" % [SeedCode.encode(w.run_seed), w.scenario_id, w.outcome, w.history.size()])
	lines.append("reason=%s" % w.outcome_reason)
	lines.append("score=%d daily=%s" % [w.score(), w.daily_date if w.daily_date != "" else "no"])
	lines.append("avg_health=%d min_health=%d instability=%d reserve=%d" % [w.average_health(), w.min_health(), w.instability, w.reserve])
	lines.append("actions redirect=%d split=%d delay=%d transform=%d crisis=%d" % [kinds["redirect"], kinds["split"], kinds["delay"], kinds["transform"], kinds["crisis"]])
	var hs: Array = []
	for id in w.systems:
		hs.append("%s=%d%s" % [id, w.system(id).health, "X" if w.system(id).collapsed else ""])
	lines.append("final " + " ".join(hs))
	lines.append("platform=%s layout=%s" % [OS.get_name(), "compact" if GameSettings.compact else "desktop"])
	return "\n".join(lines)
