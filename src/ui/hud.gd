class_name Hud
extends Control
## In-game heads-up display. Read-only view of WorldState plus action buttons.
## Emits signals; never mutates the simulation itself.

signal end_turn_pressed
signal undo_pressed
signal settings_pressed
signal menu_pressed
signal action_requested(kind: String, arg: String)
signal cancel_pressed

var top_season: Label
var top_ap: Label
var top_stability: Label
var top_instab: ProgressBar
var top_instab_label: Label
var top_reserve: Label
var top_seed: Label
var undo_btn: Button
var events_box: VBoxContainer
var forecast_box: VBoxContainer
var memory_box: VBoxContainer
var right_box: VBoxContainer
var end_btn: Button
var toast_label: Label
var _toast_t := 0.0
var left_panel: PanelContainer
var right_panel: PanelContainer
var right_scroll: ScrollContainer
var title_label: Label
var season_btn: Button
var compact := false
var top_hbox: HBoxContainer
var settings_btn: Button
var _right_active := false


func _ready() -> void:
	UIKit.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	compact = GameSettings.compact
	_build_top()
	_build_left()
	_build_right()
	_build_bottom()
	_apply_compact()


func _apply_compact() -> void:
	title_label.visible = not compact
	top_seed.visible = not compact
	season_btn.visible = compact
	left_panel.visible = not compact
	top_instab.custom_minimum_size = Vector2(50 if compact else 110, 14)
	if compact:
		top_hbox.add_theme_constant_override("separation", 10)
		undo_btn.text = "Undo"
		settings_btn.text = "Options"
	if compact:
		left_panel.position = Vector2(10, 56)
		right_panel.offset_top = 56
		end_btn.text = "END ▶"
		end_btn.offset_left = -150
		end_btn.offset_top = -58
		end_btn.offset_right = -10
		end_btn.offset_bottom = -10


## Width of the screen-left area the map must avoid.
func left_reserved() -> float:
	return 260.0 if left_panel.visible else 10.0


func right_reserved() -> float:
	return 340.0 if right_panel.visible else 10.0


func toggle_left() -> void:
	left_panel.visible = not left_panel.visible


func _build_top() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 10
	bar.offset_right = -10
	bar.offset_top = 8
	add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	bar.add_child(hb)
	top_hbox = hb
	title_label = UIKit.label("CONSEQUARRY", 18, Palette.ACCENT)
	hb.add_child(title_label)
	season_btn = UIKit.button("Season ▾", toggle_left, "Events, forecast and world memory")
	hb.add_child(season_btn)
	top_season = UIKit.label("Season 1/12", 16)
	hb.add_child(top_season)
	top_ap = UIKit.label("Actions ●●●", 16, Palette.ACCENT)
	top_ap.tooltip_text = "Actions left this season. Surplus overflow above 15 reserve grants +1 next season."
	top_ap.mouse_filter = Control.MOUSE_FILTER_PASS
	hb.add_child(top_ap)
	top_stability = UIKit.label("Stability 70", 16)
	top_stability.tooltip_text = "Average health minus instability and harm arriving this season."
	top_stability.mouse_filter = Control.MOUSE_FILTER_PASS
	hb.add_child(top_stability)
	var ib := HBoxContainer.new()
	top_instab_label = UIKit.label("Instability", 14, Palette.TEXT_DIM)
	ib.add_child(top_instab_label)
	top_instab = ProgressBar.new()
	top_instab.custom_minimum_size = Vector2(110, 14)
	top_instab.show_percentage = false
	top_instab.max_value = 100
	top_instab.tooltip_text = "Raised by controlled crises, overflow and cascades. 100 = defeat. Above 45 an extra event strikes each season."
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.BAD
	fill.set_corner_radius_all(4)
	top_instab.add_theme_stylebox_override("fill", fill)
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(0, 0, 0, 0.5)
	bgs.set_corner_radius_all(4)
	top_instab.add_theme_stylebox_override("background", bgs)
	top_instab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ib.add_child(top_instab)
	hb.add_child(ib)
	top_reserve = UIKit.label("Reserve 0", 15, Palette.GOOD)
	top_reserve.tooltip_text = "Surplus that overflowed a full system. Every 15 grants one extra action next season."
	top_reserve.mouse_filter = Control.MOUSE_FILTER_PASS
	hb.add_child(top_reserve)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)
	top_seed = UIKit.label("", 13, Palette.TEXT_DIM)
	top_seed.tooltip_text = "Share this seed: the same seed produces the same valley and events."
	top_seed.mouse_filter = Control.MOUSE_FILTER_PASS
	hb.add_child(top_seed)
	undo_btn = UIKit.button("Undo (Z)", func(): undo_pressed.emit(), "Undo your last action this season")
	hb.add_child(undo_btn)
	settings_btn = UIKit.button("Settings", func(): settings_pressed.emit())
	hb.add_child(settings_btn)
	hb.add_child(UIKit.button("Menu", func(): menu_pressed.emit()))


func _section(parent: Container, title: String) -> VBoxContainer:
	parent.add_child(UIKit.label(title, 12, Palette.TEXT_DIM))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	parent.add_child(vb)
	return vb


func _build_left() -> void:
	var p := PanelContainer.new()
	left_panel = p
	p.position = Vector2(10, 66)
	p.custom_minimum_size = Vector2(250, 0)
	add_child(p)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(226, 0)
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)
	events_box = _section(vb, "THIS SEASON")
	vb.add_child(HSeparator.new())
	forecast_box = _section(vb, "FORECAST — NEXT SEASON")
	vb.add_child(HSeparator.new())
	memory_box = _section(vb, "WORLD MEMORY")


func _build_right() -> void:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	p.offset_left = -330
	p.offset_right = -10
	p.offset_top = 66
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(p)
	right_panel = p
	right_scroll = ScrollContainer.new()
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(right_scroll)
	right_box = VBoxContainer.new()
	right_box.custom_minimum_size = Vector2(296, 0)
	right_box.add_theme_constant_override("separation", 7)
	right_scroll.add_child(right_box)


func _build_bottom() -> void:
	end_btn = Button.new()
	end_btn.text = "END SEASON  ▶"
	end_btn.tooltip_text = "Resolve the season (Space)"
	end_btn.add_theme_font_size_override("font_size", 20)
	end_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	end_btn.offset_left = -250
	end_btn.offset_top = -70
	end_btn.offset_right = -14
	end_btn.offset_bottom = -14
	end_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	end_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.ACCENT.darkened(0.15)
	sb.set_corner_radius_all(10)
	end_btn.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = Palette.ACCENT
	end_btn.add_theme_stylebox_override("hover", sbh)
	end_btn.add_theme_color_override("font_color", Color("1a1308"))
	end_btn.add_theme_color_override("font_hover_color", Color("1a1308"))
	end_btn.pressed.connect(func(): end_turn_pressed.emit())
	add_child(end_btn)
	toast_label = UIKit.label("", 17, Palette.ACCENT)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.offset_left = -360
	toast_label.offset_right = 360
	toast_label.offset_top = -64
	toast_label.offset_bottom = -30
	toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_label.add_theme_constant_override("outline_size", 6)
	add_child(toast_label)


func _process(delta: float) -> void:
	# Right panel grows with content but never past the screen; it scrolls instead.
	var max_h := size.y - right_panel.offset_top - (10.0 if compact else 90.0) - 24.0
	if compact:
		end_btn.visible = not _right_active
	var want := right_box.get_combined_minimum_size().y
	right_scroll.custom_minimum_size = Vector2(300, clampf(want, 40.0, maxf(80.0, max_h)))
	right_panel.size.y = 0
	right_panel.visible = (not compact) or _right_active
	if _toast_t > 0:
		_toast_t -= delta
		toast_label.modulate.a = clampf(_toast_t, 0, 1)


func toast(text: String, color: Color = Palette.ACCENT, dur: float = 3.0) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	toast_label.modulate.a = 1
	_toast_t = dur


# ------------------------------------------------------------------ refresh

func refresh(w: WorldState, can_undo: bool, busy: bool) -> void:
	var pips := "●".repeat(w.action_points) + "○".repeat(maxi(0, w.actions_per_turn - w.action_points))
	top_season.text = ("%d/%d" if compact else "Season %d / %d") % [w.turn, w.max_turns]
	top_ap.text = pips if compact else "Actions " + pips
	var st := w.stability_index()
	top_stability.text = ("Stab %d" if compact else "Stability %d") % st
	top_stability.add_theme_color_override("font_color", Palette.GOOD if st >= 55 else (Palette.ACCENT if st >= 35 else Palette.BAD))
	top_instab.value = w.instability
	top_instab_label.text = ("Inst %d" if compact else "Instability %d") % w.instability
	top_reserve.text = ("Res %d" if compact else "Reserve %d") % w.reserve
	top_seed.text = SeedCode.encode(w.run_seed)
	undo_btn.disabled = not can_undo or busy
	end_btn.disabled = busy or w.is_over()
	_fill_events(w)
	_fill_memory(w)


func _event_row(parent: VBoxContainer, event_id: String, dim: bool) -> void:
	var ed := ContentDB.event_def(event_id)
	var hb := HBoxContainer.new()
	var name_l := UIKit.label(String(ed["name"]), 14, Palette.TEXT_DIM if dim else Palette.ACCENT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(name_l)
	for spec in ed["consequences"]:
		hb.add_child(GlyphIcon.make(String(spec["type"]), 16))
		hb.add_child(UIKit.label("→%s" % String(ContentDB.system_def(spec["to"])["name"]).substr(0, 4), 11, Palette.TEXT_DIM))
	hb.tooltip_text = String(ed["text"])
	hb.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(hb)


func _fill_events(w: WorldState) -> void:
	UIKit.clear(events_box)
	UIKit.clear(forecast_box)
	for e in w.current_events:
		_event_row(events_box, e, false)
	if w.current_events.is_empty():
		events_box.add_child(UIKit.label("Quiet season.", 13, Palette.TEXT_DIM))
	for e in w.forecast:
		_event_row(forecast_box, e, true)
	if w.forecast.is_empty():
		forecast_box.add_child(UIKit.label("Final season." if w.turn >= w.max_turns else "Unclear.", 13, Palette.TEXT_DIM))
	var future := 0
	for c in w.ledger.pending():
		if c.land_turn > w.turn:
			future += 1
	if future > 0:
		forecast_box.add_child(UIKit.label("+ %d delayed/queued consequence(s)" % future, 12, Palette.TEXT_DIM))


func _fill_memory(w: WorldState) -> void:
	UIKit.clear(memory_box)
	var ch := w.memory.chronicle
	if ch.is_empty():
		memory_box.add_child(UIKit.label("The valley remembers everything.\nNothing yet.", 12, Palette.TEXT_DIM, true))
		return
	for k in range(maxi(0, ch.size() - 5), ch.size()):
		var e: Dictionary = ch[k]
		var col := Palette.system_color(String(e["system"]))
		var r := UIKit.rich("[color=#%s]S%d[/color] %s" % [UIKit.hex(col), int(e["turn"]), e["text"]], 12)
		r.custom_minimum_size = Vector2(226, 0)
		memory_box.add_child(r)


# ------------------------------------------------------------------ right panel

func _close_row() -> void:
	if compact:
		var b := UIKit.button("✕ Close", func(): cancel_pressed.emit())
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		right_box.add_child(b)


func show_idle(w: WorldState, has_report: bool = false) -> void:
	_right_active = false
	right_scroll.scroll_vertical = 0
	UIKit.clear(right_box)
	right_box.add_child(UIKit.label("CONSEQUENCES", 13, Palette.TEXT_DIM))
	right_box.add_child(UIKit.label("Every consequence must go somewhere.", 15, Palette.ACCENT, true))
	right_box.add_child(UIKit.label("Click an orb to route it. Click a district to inspect it or trigger a controlled crisis.", 13, Palette.TEXT, true))
	right_box.add_child(HSeparator.new())
	for t in ContentDB.data()["consequence_types"]:
		var hb := HBoxContainer.new()
		hb.add_child(GlyphIcon.make(String(t["id"]), 20))
		hb.add_child(UIKit.label(String(t["name"]), 14))
		right_box.add_child(hb)
	right_box.add_child(HSeparator.new())
	var arriving := 0
	var harm := 0
	for c in w.ledger.pending_landing_on(w.turn):
		arriving += 1
		if not ContentDB.is_positive(c.type):
			harm += c.current_magnitude
	right_box.add_child(UIKit.label("%d consequences arrive this season (%d harm)." % [arriving, harm], 13, Palette.TEXT_DIM, true))
	if has_report:
		right_box.add_child(UIKit.button("Last season report", func(): action_requested.emit("report", "")))
	if compact:
		right_box.add_child(UIKit.label("Tap an orb to route it. Tap a district to inspect it.", 12, Palette.TEXT_DIM, true))
	else:
		right_box.add_child(UIKit.label("Keys: Tab next orb · 1-4 actions · Space end season · Z undo · Esc cancel", 11, Palette.TEXT_DIM, true))


func _predict_text(pv: Dictionary, sys_name: String) -> String:
	var d := int(pv["delta"])
	var s := "%s %+d health" % [sys_name, d]
	if int(pv["absorbed"]) > 0:
		s += " (cushioned %d)" % int(pv["absorbed"])
	if int(pv["spill"]) > 0:
		s += ", %d overflows onward" % int(pv["spill"])
	return s


func show_consequence(w: WorldState, c: Consequence, mode: String) -> void:
	_right_active = true
	UIKit.clear(right_box)
	_close_row()
	var td := ContentDB.type_def(c.type)
	var hb := HBoxContainer.new()
	hb.add_child(GlyphIcon.make(c.type, 30))
	var title := UIKit.label("%s  %d" % [td["name"], c.current_magnitude], 22, Palette.type_color(c.type))
	hb.add_child(title)
	right_box.add_child(hb)
	var dest_name := String(ContentDB.system_def(c.destination)["name"])
	right_box.add_child(UIKit.rich("From [b]%s[/b]\nHeading to [b][color=#%s]%s[/color][/b]%s" % [
		SimulationEngine.source_label(c.source), UIKit.hex(Palette.system_color(c.destination)), dest_name,
		"" if c.land_turn == w.turn else "  (arrives in %d)" % (c.land_turn - w.turn)], 14))
	var pv := SimulationEngine.preview_landing(w, c.type, c.current_magnitude, c.destination, c.id)
	var pred := _predict_text(pv, dest_name)
	right_box.add_child(UIKit.rich("If left alone: [color=#%s]%s[/color]" % [UIKit.hex(Palette.GOOD if int(pv["delta"]) >= 0 else Palette.BAD), pred], 14))
	if mode != "":
		right_box.add_child(HSeparator.new())
		var verb := "Redirect" if mode == "redirect" else "Split half"
		right_box.add_child(UIKit.label("%s: click a glowing district." % verb, 16, Palette.ACCENT, true))
		if mode == "redirect":
			right_box.add_child(UIKit.label("20% always leaks and stays behind. Receiving systems grow dependent (capacity falls).", 12, Palette.TEXT_DIM, true))
		right_box.add_child(UIKit.button("Cancel (Esc)", func(): cancel_pressed.emit()))
		return
	right_box.add_child(HSeparator.new())
	if c.land_turn != w.turn:
		right_box.add_child(UIKit.label("Arrives in a later season. You can act on it then.", 13, Palette.TEXT_DIM, true))
	else:
		_action_button("redirect", "1  Redirect", "Send it to a causally connected system. 20% leaks.", w, c)
		_action_button("split", "2  Split", "Send half to a connected system to use two cushions.", w, c)
		_action_button("delay", "3  Delay", "Push it to next season. Adds +25% Deferred Strain.", w, c)
		var rule := _rule_for(c)
		if rule.is_empty():
			var none := UIKit.button("4  Transform", func(): pass)
			none.disabled = true
			right_box.add_child(none)
			right_box.add_child(UIKit.label("No known process converts %s." % td["name"], 11, Palette.TEXT_DIM, true))
		else:
			_action_button("transform:" + String(rule["id"]), "4  Transform: %s" % rule["name"],
				"%s\n%s → %d%% Surplus at %s, rest becomes %s at %s." % [rule["text"], td["name"], int(rule["efficiency"]) + w.memory.adaptation(rule["id"]),
				ContentDB.system_def(rule["output_to"])["name"], ContentDB.type_def(rule["residue"])["name"], ContentDB.system_def(rule["residue_to"])["name"]], w, c)
	if c.history.size() > 0:
		right_box.add_child(HSeparator.new())
		right_box.add_child(UIKit.label("LEDGER", 11, Palette.TEXT_DIM))
		var hist := ""
		for k in range(maxi(0, c.history.size() - 3), c.history.size()):
			hist += c.history[k] + "\n"
		right_box.add_child(UIKit.label(hist.strip_edges(), 11, Palette.TEXT_DIM, true))


func _rule_for(c: Consequence) -> Dictionary:
	for r in ContentDB.data()["transformations"]:
		if r["input"] == c.type:
			return r
	return {}


func _action_button(kind: String, text: String, tip: String, w: WorldState, c: Consequence) -> void:
	var reason := ""
	match kind:
		"redirect", "split":
			var any_ok := false
			reason = "No connected system can receive it."
			for n in w.graph.neighbors(c.destination):
				var cand := Intervention.redirect(c.id, n) if kind == "redirect" else Intervention.split(c.id, n)
				var r := SimulationEngine.validate(w, cand)
				if r == "":
					any_ok = true
					break
				reason = r
			if any_ok:
				reason = ""
		"delay":
			reason = SimulationEngine.validate(w, Intervention.delay(c.id))
		_:
			reason = SimulationEngine.validate(w, Intervention.transform(c.id, kind.split(":")[1]))
	var b := UIKit.button(text, func(): action_requested.emit(kind, str(c.id)), tip)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = reason != ""
	right_box.add_child(b)
	if reason != "":
		right_box.add_child(UIKit.label("   " + reason, 11, Color("c98a80"), true))


func show_district(w: WorldState, sid: String) -> void:
	_right_active = true
	right_scroll.scroll_vertical = 0
	UIKit.clear(right_box)
	_close_row()
	var s := w.system(sid)
	var sd := ContentDB.system_def(sid)
	right_box.add_child(UIKit.label(String(sd["name"]).to_upper(), 22, Palette.system_color(sid)))
	var status := "COLLAPSED" if s.collapsed else ("Health %d / %d" % [s.health, s.max_health])
	right_box.add_child(UIKit.label(status, 16, Palette.BAD if s.collapsed or s.health < 30 else Palette.TEXT))
	right_box.add_child(UIKit.rich("Cushion [b]%d/%d[/b] this season · Resilience [b]%d%%[/b]%s" % [
		s.remaining_capacity(w.memory), s.capacity(w.memory), w.memory.resilience(sid),
		"\n[color=#c98a80]Scarred: max health reduced[/color]" if s.scarred else ""], 13))
	right_box.add_child(UIKit.label("VULNERABILITY", 11, Palette.TEXT_DIM))
	var grid := GridContainer.new()
	grid.columns = 4
	for t in ContentDB.data()["consequence_types"]:
		if bool(t["positive"]):
			continue
		var v := ContentDB.vulnerability(String(t["id"]), sid)
		grid.add_child(GlyphIcon.make(String(t["id"]), 18))
		grid.add_child(UIKit.label("%d%%  " % v, 13, Palette.BAD if v >= 90 else (Palette.ACCENT if v >= 50 else Palette.GOOD)))
	right_box.add_child(grid)
	right_box.add_child(UIKit.label("CAUSAL LINKS", 11, Palette.TEXT_DIM))
	var links := ""
	for e in w.graph.edges:
		if e["from"] == sid:
			links += "→ %s (%s %d)\n" % [ContentDB.system_def(e["to"])["name"], e["kind"], int(e["weight"])]
		elif e["to"] == sid:
			links += "← %s (%s %d)\n" % [ContentDB.system_def(e["from"])["name"], e["kind"], int(e["weight"])]
	right_box.add_child(UIKit.label(links.strip_edges(), 12, Palette.TEXT_DIM, true))
	for r in ContentDB.data()["transformations"]:
		if r["at"] == sid:
			right_box.add_child(UIKit.rich("[color=#62e3a8]Process:[/color] [b]%s[/b] converts %s (needs health %d, %d per season)." % [r["name"], ContentDB.type_def(r["input"])["name"], int(r["min_health"]), int(r["capacity_per_turn"])], 12))
	var cd := ContentDB.crisis_for_system(sid)
	if not cd.is_empty():
		right_box.add_child(HSeparator.new())
		var cost := SimulationEngine.cost_of(w, Intervention.crisis(sid))
		var gain: Dictionary = cd["gain"]
		var harm_txt := ""
		for h in cd["harm"]:
			harm_txt += "%s %d → %s%s; " % [ContentDB.type_def(h["type"])["name"], int(h["magnitude"]), ContentDB.system_def(h["to"])["name"], "" if int(h["delay"]) == 0 else " (in %d)" % int(h["delay"])]
		var yield_pct := w.memory.crisis_yield_percent(sid)
		right_box.add_child(UIKit.label("CONTROLLED CRISIS", 11, Palette.TEXT_DIM))
		right_box.add_child(UIKit.rich("[b]%s[/b] — %s\nGain: [color=#62e3a8]Surplus %d → %s%s[/color]\nFallout: [color=#ff5c57]%s[/color]\nInstability +%d" % [
			cd["name"], cd["text"], ContentDB.pct(int(gain["magnitude"]), yield_pct), ContentDB.system_def(gain["to"])["name"],
			"" if int(gain["delay"]) == 0 else " (in %d)" % int(gain["delay"]), harm_txt.trim_suffix("; "),
			int(cd["instability"]) + 3 * int(w.memory.crises.get(sid, 0))], 12))
		var reason := SimulationEngine.validate(w, Intervention.crisis(sid))
		var b := UIKit.button("Trigger (%d actions)" % cost, func(): action_requested.emit("crisis", sid))
		b.disabled = reason != ""
		right_box.add_child(b)
		if reason != "":
			right_box.add_child(UIKit.label(reason, 11, Color("c98a80"), true))


## "What happened last season": every landing traced from origin to impact,
## plus causal-link drag, cascades, collapses and new world memory.
func show_report(w: WorldState, r: Dictionary) -> void:
	_right_active = true
	right_scroll.scroll_vertical = 0
	UIKit.clear(right_box)
	_close_row()
	right_box.add_child(UIKit.label("SEASON %d REPORT" % int(r["turn"]), 18, Palette.ACCENT))
	var harm := 0
	var heal := 0
	var rows: Array = r["landings"].duplicate()
	for l in rows:
		var d := int(l["delta"])
		if d < 0:
			harm -= d
		else:
			heal += d
	right_box.add_child(UIKit.rich("Health lost [color=#%s]%d[/color] · gained [color=#%s]%d[/color]" % [UIKit.hex(Palette.BAD), harm, UIKit.hex(Palette.GOOD), heal], 13))
	rows.sort_custom(func(a, b): return absi(int(a["delta"])) > absi(int(b["delta"])))
	right_box.add_child(UIKit.label("WHERE CONSEQUENCES LANDED", 11, Palette.TEXT_DIM))
	for k in mini(10, rows.size()):
		var l: Dictionary = rows[k]
		var hb := HBoxContainer.new()
		hb.add_child(GlyphIcon.make(String(l["type"]), 16))
		var d := int(l["delta"])
		var extra := ""
		if int(l["absorbed"]) > 0 and d < 0:
			extra = " (cushioned %d)" % int(l["absorbed"])
		if String(l["spill_to"]) != "":
			extra += ", overflowed to %s" % ContentDB.system_def(l["spill_to"])["name"]
		var t := UIKit.rich("%s → [b]%s[/b] [color=#%s]%+d[/color][color=#9aa0ad]%s[/color]" % [
			SimulationEngine.source_label(String(l["source"])), ContentDB.system_def(l["to"])["name"],
			UIKit.hex(Palette.GOOD if d >= 0 else Palette.BAD), d, extra], 12)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(t)
		right_box.add_child(hb)
	if rows.size() > 10:
		right_box.add_child(UIKit.label("+ %d smaller landings" % (rows.size() - 10), 11, Palette.TEXT_DIM))
	var links := {}
	for e in r["effects"]:
		links[e["to"]] = int(links.get(e["to"], 0)) + int(e["delta"])
	if not links.is_empty():
		right_box.add_child(UIKit.label("CAUSAL LINKS (DRAG FROM NEIGHBOURS)", 11, Palette.TEXT_DIM))
		var parts: Array = []
		for sid in links:
			var v: int = links[sid]
			parts.append("%s [color=#%s]%+d[/color]" % [ContentDB.system_def(sid)["name"], UIKit.hex(Palette.GOOD if v >= 0 else Palette.BAD), v])
		right_box.add_child(UIKit.rich(" · ".join(parts), 12))
	for c in r["cascades"]:
		right_box.add_child(UIKit.rich("[color=#%s]Cascade:[/color] %s is failing, %d damage heads to %s next season." % [
			UIKit.hex(Palette.BAD), ContentDB.system_def(c["from"])["name"], int(c["amount"]), ContentDB.system_def(c["to"])["name"]], 12))
	for sid in r["collapses"]:
		right_box.add_child(UIKit.rich("[color=#%s][b]%s collapsed.[/b][/color]" % [UIKit.hex(Palette.BAD), ContentDB.system_def(sid)["name"]], 13))
	var ch := w.memory.chronicle
	if ch.size() > int(r["memory_from"]):
		right_box.add_child(UIKit.label("THE VALLEY REMEMBERS", 11, Palette.TEXT_DIM))
		for k in range(int(r["memory_from"]), ch.size()):
			var note := UIKit.label(String(ch[k]["text"]), 12, Color("9fd3ff"), true)
			note.custom_minimum_size = Vector2(280, 0)
			right_box.add_child(note)
	right_box.add_child(UIKit.label("Select an orb to plan this season.", 12, Palette.TEXT_DIM, true))
