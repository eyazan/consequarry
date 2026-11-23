class_name GameView
extends Node2D
## Connects the simulation to the screen: input, selection, targeting,
## resolution animation, autosave. Simulation logic lives in SimulationEngine only.

signal exit_to_menu
signal restart(scenario_id: String, run_seed: int)

var world: WorldState
var map: IsoMap
var orb_layer: Node2D
var fx: FxLayer
var hud: Hud
var ui_layer: CanvasLayer
var sfx: Sfx
var tutorial: TutorialOverlay
var orbs: Dictionary = {}          # consequence id -> OrbView
var selected_id := -1
var selected_district := ""
var mode := ""                     # "", "redirect", "split"
var hovered_orb := -1
var hovered_district := ""
var busy := false
var undo_stack: Array = []
var last_report: Dictionary = {}
var report_open := false
var guide: GuidePointer
var hint_it: Intervention = null
var hint_end := false
var _shake_t := 0.0
var _target_cursor := 0


func start(w: WorldState, with_tutorial: bool) -> void:
	world = w
	map = IsoMap.new()
	add_child(map)
	map.build()
	orb_layer = Node2D.new()
	map.add_child(orb_layer)
	fx = FxLayer.new()
	map.add_child(fx)
	guide = GuidePointer.new()
	guide.visible = false
	map.add_child(guide)
	sfx = Sfx.new()
	add_child(sfx)
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	hud = Hud.new()
	hud.theme = UIKit.make_theme()
	ui_layer.add_child(hud)
	hud.end_turn_pressed.connect(end_turn)
	hud.undo_pressed.connect(undo)
	hud.action_requested.connect(_on_action)
	hud.cancel_pressed.connect(_cancel)
	hud.hint_pressed.connect(_hint)
	hud.settings_pressed.connect(_open_settings)
	hud.menu_pressed.connect(func(): SaveSystem.save_world(world); exit_to_menu.emit())
	if with_tutorial:
		tutorial = TutorialOverlay.new()
		tutorial.theme = hud.theme
		ui_layer.add_child(tutorial)
		tutorial.finished.connect(func(): tutorial = null)
	_sync_districts(true)
	_rebuild_orbs(true)
	_refresh_ui()
	if world.is_over():
		_show_game_over()
	elif not with_tutorial and GameSettings.runs_started <= 3 and world.turn == 1:
		hud.toast(Loc.t("New here? Tap Hint any time for a suggested move."), Palette.ACCENT, 7.0)


func _process(delta: float) -> void:
	if map == null:
		return
	var vr := get_viewport_rect().size
	var lm := hud.left_reserved()
	var rm := hud.right_reserved()
	var top := 56.0 if GameSettings.compact else 66.0
	var avail_w := vr.x - lm - rm
	var s := clampf(minf(avail_w / 700.0, (vr.y - top - 30.0) / 600.0), 0.45, 1.5)
	var target_scale := Vector2(s, s)
	var target_pos := Vector2(lm + 5.0 + avail_w * 0.5, top + (vr.y - top) * 0.5 + 6.0 * s)
	# Smoothly re-centre when side panels open/close (compact layout).
	map.scale = map.scale.lerp(target_scale, minf(1.0, delta * 10.0)) if map.scale != Vector2.ONE else target_scale
	map.position = map.position.lerp(target_pos, minf(1.0, delta * 10.0)) if map.position != Vector2.ZERO else target_pos
	_update_guide()
	if _shake_t > 0.0:
		_shake_t -= delta
		map.position += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 6.0 * _shake_t
	map.show_links = GameSettings.always_show_links


# ------------------------------------------------------------------ view sync

func _sync_districts(immediate: bool) -> void:
	for id in map.districts:
		var d: DistrictView = map.districts[id]
		var s := world.system(id)
		d.max_health = s.max_health
		d.collapsed = s.collapsed
		d.scarred = s.scarred
		d.capacity = s.capacity(world.memory)
		d.capacity_used = s.capacity_used
		d.resilience = world.memory.resilience(id)
		if immediate:
			d.display_health = s.health
		else:
			create_tween().tween_property(d, "display_health", float(s.health), 0.4 * maxf(GameSettings.anim_scale(), 0.01))
	map.queued_effects = world.queued_effects


func _orb_slots(dest: String, count: int, future: bool) -> Array:
	var base := map.district_pos(dest)
	var out: Array = []
	if future:
		for k in count:
			out.append(base + Vector2(58 + (k % 3) * 20, 8 + (k / 3) * 20))
	else:
		for k in count:
			var row := k / 4
			var col := k % 4
			var n_in_row := mini(4, count - row * 4)
			out.append(base + Vector2((col - (n_in_row - 1) * 0.5) * 38.0, -66.0 - row * 36.0 + absf(col - (n_in_row - 1) * 0.5) * 6.0))
	return out


func _rebuild_orbs(appear: bool) -> void:
	for o in orbs.values():
		o.queue_free()
	orbs.clear()
	var groups := {}
	for c in world.ledger.pending():
		var key := "%s|%s" % [c.destination, "f" if c.land_turn > world.turn else "n"]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(c)
	for key in groups:
		var parts: PackedStringArray = key.split("|")
		var list: Array = groups[key]
		var slots := _orb_slots(parts[0], list.size(), parts[1] == "f")
		for k in list.size():
			var c: Consequence = list[k]
			var o := OrbView.new()
			o.setup(c, world.turn)
			o.position = slots[k]
			orb_layer.add_child(o)
			orbs[c.id] = o
			if appear and GameSettings.anim_scale() > 0.0 and c.created_turn == world.turn and c.source.begins_with("event:"):
				o.appear = 0.0
				o.position.y -= 160
				var tw := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
				tw.tween_interval(0.05 * k)
				tw.tween_property(o, "position:y", slots[k].y, 0.6 * GameSettings.anim_scale())
				tw.parallel().tween_property(o, "appear", 1.0, 0.3 * GameSettings.anim_scale())
	_apply_selection_visuals()


func _apply_selection_visuals() -> void:
	if selected_id >= 0 and not orbs.has(selected_id):
		selected_id = -1
		mode = ""
	for id in orbs:
		var o: OrbView = orbs[id]
		o.selected = id == selected_id
		o.hovered = id == hovered_orb
		o.dimmed = mode != "" and id != selected_id
	var c := world.ledger.get_c(selected_id) if selected_id >= 0 else null
	for id in map.districts:
		var d: DistrictView = map.districts[id]
		d.hovered = id == hovered_district
		d.selected = id == selected_district
		d.target_state = 0
		d.preview_text = ""
		if mode != "" and c != null:
			var it := Intervention.redirect(c.id, id) if mode == "redirect" else Intervention.split(c.id, id)
			var ok := SimulationEngine.validate(world, it) == ""
			d.target_state = 1 if ok else -1
			if ok:
				var mag := c.current_magnitude - maxi(1, ContentDB.pct(c.current_magnitude, int(ContentDB.rules()["redirect_leak_percent"]))) if mode == "redirect" else c.current_magnitude / 2
				var pv := SimulationEngine.preview_landing(world, c.type, mag, id)
				d.preview_text = Loc.t("%+d health") % int(pv["delta"])
				d.preview_color = Palette.GOOD if int(pv["delta"]) >= 0 else Palette.BAD
	map.highlight_system = selected_district if selected_district != "" else (c.destination if c != null else hovered_district)


func _refresh_ui() -> void:
	hud.refresh(world, not undo_stack.is_empty(), busy)
	if Music.instance:
		Music.instance.set_tension(1.0 - world.stability_index() / 100.0)
	var c := world.ledger.get_c(selected_id) if selected_id >= 0 else null
	if c != null and c.is_pending():
		hud.show_consequence(world, c, mode)
	elif selected_district != "":
		hud.show_district(world, selected_district)
	elif report_open and not last_report.is_empty():
		hud.show_report(world, last_report)
	else:
		hud.show_idle(world, not last_report.is_empty())
	_apply_selection_visuals()


# ------------------------------------------------------------------ input

## Map-local position of a pointer event (uses the event's own position, so
## taps are correct even when the cursor position is stale, e.g. touch screens).
func _map_point(screen_pos: Vector2) -> Vector2:
	return map.to_local(get_canvas_transform().affine_inverse() * screen_pos)


func _pick(screen_pos: Vector2) -> Dictionary:
	var m := _map_point(screen_pos)
	var best := -1
	var best_d := 1e9
	for id in orbs:
		var o: OrbView = orbs[id]
		var local := m - o.position
		if o.contains_point(local):
			var d := local.length()
			if d < best_d:
				best_d = d
				best = id
	if best >= 0:
		return {"orb": best}
	var ids := map.districts.keys()
	ids.sort_custom(func(a, b): return map.districts[a].position.y > map.districts[b].position.y)
	for id in ids:
		var dv: DistrictView = map.districts[id]
		if dv.contains_point(m - dv.position):
			return {"district": id}
	return {}


func _unhandled_input(event: InputEvent) -> void:
	if world == null or busy or world.is_over():
		return
	if event is InputEventMouseMotion:
		var p := _pick(event.position)
		var ho: int = p.get("orb", -1)
		var hd: String = p.get("district", "")
		if ho != hovered_orb or hd != hovered_district:
			hovered_orb = ho
			hovered_district = hd
			_apply_selection_visuals()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(_pick(event.position))
	elif event.is_action_pressed("cancel_selection") or event.is_action_pressed("ui_cancel"):
		_cancel()
	elif event.is_action_pressed("end_turn"):
		end_turn()
	elif event.is_action_pressed("undo_action"):
		undo()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB: _cycle(-1 if event.shift_pressed else 1)
			KEY_1: _key_action("redirect")
			KEY_2: _key_action("split")
			KEY_3: _key_action("delay")
			KEY_4: _key_action("transform")
			KEY_ENTER, KEY_KP_ENTER: _confirm_cursor()


func _click(p: Dictionary) -> void:
	if mode != "":
		if p.has("district"):
			_do_target(p["district"])
		elif p.has("orb") and p["orb"] != selected_id:
			_cancel()
			_select_orb(p["orb"])
		return
	if p.has("orb"):
		_select_orb(p["orb"])
	elif p.has("district"):
		selected_id = -1
		selected_district = p["district"]
		sfx.play("select", 0.8)
		_refresh_ui()
	else:
		_cancel()


func _select_orb(id: int) -> void:
	selected_id = id
	selected_district = ""
	mode = ""
	sfx.play("select")
	var c := world.ledger.get_c(id)
	if tutorial and c:
		tutorial.notify("select", {"type": c.type, "dest": c.destination})
	_refresh_ui()


func _cancel() -> void:
	hint_it = null
	hint_end = false
	if mode != "":
		mode = ""
	elif selected_id < 0 and selected_district == "":
		report_open = false
	else:
		selected_id = -1
		selected_district = ""
	_refresh_ui()


func _cycle(dir: int) -> void:
	if mode != "":
		var targets := _valid_targets()
		if targets.is_empty():
			return
		_target_cursor = posmod(_target_cursor + dir, targets.size())
		hovered_district = targets[_target_cursor]
		_apply_selection_visuals()
		return
	var ids: Array = []
	for c in world.ledger.pending_landing_on(world.turn):
		if orbs.has(c.id):
			ids.append(c.id)
	if ids.is_empty():
		return
	var idx := ids.find(selected_id)
	_select_orb(ids[posmod(idx + dir, ids.size())])


func _valid_targets() -> Array:
	var out: Array = []
	var c := world.ledger.get_c(selected_id)
	if c == null:
		return out
	for id in map.districts:
		var it := Intervention.redirect(c.id, id) if mode == "redirect" else Intervention.split(c.id, id)
		if SimulationEngine.validate(world, it) == "":
			out.append(id)
	return out


func _confirm_cursor() -> void:
	if mode != "" and hovered_district != "":
		_do_target(hovered_district)


func _key_action(kind: String) -> void:
	if selected_id < 0:
		return
	if kind == "transform":
		var c := world.ledger.get_c(selected_id)
		for r in ContentDB.data()["transformations"]:
			if r["input"] == c.type:
				_on_action("transform:" + String(r["id"]), str(selected_id))
				return
		return
	_on_action(kind, str(selected_id))


# ------------------------------------------------------------------ actions

func _on_action(kind: String, arg: String) -> void:
	if busy:
		return
	if kind == "report":
		report_open = true
		selected_id = -1
		selected_district = ""
		_refresh_ui()
		return
	if kind == "redirect" or kind == "split":
		if tutorial:
			tutorial.notify("mode", {"mode": kind})
		mode = kind
		_target_cursor = 0
		var t := _valid_targets()
		if not t.is_empty():
			hovered_district = t[0]
		_refresh_ui()
		return
	var it: Intervention
	if kind == "delay":
		it = Intervention.delay(int(arg))
	elif kind.begins_with("transform:"):
		it = Intervention.transform(int(arg), kind.split(":")[1])
	elif kind == "crisis":
		it = Intervention.crisis(arg)
	else:
		return
	_apply(it)


func _do_target(target: String) -> void:
	var it := Intervention.redirect(selected_id, target) if mode == "redirect" else Intervention.split(selected_id, target)
	_apply(it)


func _apply(it: Intervention) -> void:
	var snapshot := world.to_dict()
	var origin := Vector2.ZERO
	if it.consequence_id >= 0 and orbs.has(it.consequence_id):
		origin = orbs[it.consequence_id].position
	var why := SimulationEngine.validate_msg(world, it)
	var err := SimulationEngine.apply(world, it)
	if err != "":
		hud.toast(Loc.m(why), Palette.BAD)
		sfx.play("error")
		mode = ""
		_refresh_ui()
		return
	undo_stack.append(snapshot)
	mode = ""
	hint_it = null
	hint_end = false
	var sc := GameSettings.anim_scale()
	match it.kind:
		Intervention.REDIRECT:
			sfx.play("redirect")
			fx.flight(origin, map.district_pos(it.target) + Vector2(0, -66), world.ledger.get_c(world.last_focus_id).type, world.ledger.get_c(world.last_focus_id).current_magnitude, 0.45 * maxf(sc, 0.05))
			selected_id = world.last_focus_id
			if tutorial:
				tutorial.notify("redirect", {"target": it.target})
				var moved := world.ledger.get_c(selected_id)
				tutorial.notify("select", {"type": moved.type, "dest": moved.destination})
		Intervention.SPLIT:
			sfx.play("split")
			fx.sparks(origin, Palette.type_color(world.ledger.get_c(it.consequence_id).type), 10, 0.5)
			selected_id = -1
		Intervention.DELAY:
			sfx.play("delay")
			fx.text(origin, Loc.t("Delayed +strain"), Palette.ACCENT, 1.0, 15)
			selected_id = -1
		Intervention.TRANSFORM:
			sfx.play("transform")
			fx.sparks(origin, Palette.GOOD, 22, 0.8)
			fx.ring(origin, Palette.GOOD, 0.6, 50)
			fx.text(origin, Loc.t(String(ContentDB.transformation_def(it.rule_id)["name"])), Palette.GOOD, 1.3, 16)
			selected_id = -1
			if tutorial:
				tutorial.notify("transform")
		Intervention.CRISIS:
			sfx.play("crisis")
			var p := map.district_pos(it.system)
			fx.ring(p, Palette.BAD, 0.8, 120)
			fx.text(p + Vector2(0, -40), Loc.t(String(ContentDB.crisis_for_system(it.system)["name"])), Palette.BAD, 1.5, 18)
			_shake(0.4)
	_sync_districts(true)
	_rebuild_orbs(false)
	_refresh_ui()


func undo() -> void:
	if busy or undo_stack.is_empty():
		return
	world = WorldState.from_dict(undo_stack.pop_back())
	selected_id = -1
	mode = ""
	sfx.play("delay", 1.3)
	_sync_districts(true)
	_rebuild_orbs(false)
	_refresh_ui()


func _shake(t: float) -> void:
	if GameSettings.screen_shake:
		_shake_t = maxf(_shake_t, t)


# ------------------------------------------------------------------ resolution

func _wait(t: float) -> void:
	if t > 0.0:
		await get_tree().create_timer(t).timeout


func end_turn() -> void:
	if busy or world.is_over():
		return
	busy = true
	selected_id = -1
	selected_district = ""
	mode = ""
	_refresh_ui()
	sfx.play("end_turn")
	var positions := {}
	for id in orbs:
		positions[id] = orbs[id].position
	var shown := {}
	for id in map.districts:
		shown[id] = map.districts[id].display_health
	var report := SimulationEngine.end_turn(world)
	undo_stack.clear()
	hint_it = null
	hint_end = false
	last_report = report
	report_open = true
	var sc := GameSettings.anim_scale()
	if sc > 0.0:
		await _animate_report(report, positions, shown, sc)
	_sync_districts(sc == 0.0)
	busy = false
	if world.is_over():
		SaveSystem.clear_run()
		await _wait(0.6 * sc)
		_show_game_over()
		return
	SaveSystem.save_world(world)
	if sc > 0.0 and not world.current_events.is_empty():
		var names: Array = []
		for e in world.current_events:
			names.append(Loc.event(e))
		sfx.play("event")
		fx.banner(Vector2(0, -250), Loc.t("SEASON %d") % world.turn, " · ".join(names), Palette.ACCENT, 1.8 * sc)
	_rebuild_orbs(true)
	_refresh_ui()
	if tutorial:
		tutorial.notify("end_turn_done")


func _animate_report(report: Dictionary, positions: Dictionary, shown: Dictionary, sc: float) -> void:
	for l in report["landings"]:
		var id: int = l["id"]
		var to := map.district_pos(l["to"])
		var from: Vector2 = positions.get(id, to + Vector2(0, -120))
		if orbs.has(id):
			orbs[id].visible = false
		var landing: Dictionary = l
		fx.flight(from, to + Vector2(0, -10), l["type"], int(l["amount"]), 0.42 * sc, -40.0, func(): _impact(landing, shown))
		await _wait(0.16 * sc)
	await _wait(0.5 * sc)
	for e in report["effects"]:
		map.pulse(e["from"], e["to"], 1.0 * sc)
		var d := int(e["delta"])
		shown[e["to"]] += d
		map.districts[e["to"]].display_health = maxf(0.0, shown[e["to"]])
		fx.text(map.district_pos(e["to"]) + Vector2(0, 20), "%+d %s" % [d, "link"], Palette.GOOD if d > 0 else Palette.PRESSURE, 1.0 * sc, 14)
	if not report["effects"].is_empty():
		await _wait(0.6 * sc)
	for cas in report["cascades"]:
		fx.bolt(map.district_pos(cas["from"]), map.district_pos(cas["to"]), Palette.BAD, 0.7 * sc)
		fx.text(map.district_pos(cas["from"]) + Vector2(0, -30), "CASCADE", Palette.BAD, 1.2 * sc, 16)
		sfx.play("impact", 0.7)
		_shake(0.3)
	for sid in report["collapses"]:
		fx.banner(Vector2(0, -250), Loc.t("%s COLLAPSED") % Loc.upper(Loc.sys(sid)), Loc.t("Its dependents will feel it."), Palette.BAD, 2.0 * sc)
		_shake(0.6)
	if not report["cascades"].is_empty() or not report["collapses"].is_empty():
		await _wait(0.8 * sc)
	var from_idx: int = report["memory_from"]
	if world.memory.chronicle.size() > from_idx:
		var note: Dictionary = world.memory.chronicle[from_idx]
		hud.toast(Loc.t("World memory: ") + Loc.note(note), Color("9fd3ff"), 4.0)
	while fx.busy():
		await _wait(0.05)


func _impact(l: Dictionary, shown: Dictionary) -> void:
	var sid: String = l["to"]
	var d := int(l["delta"])
	var pos := map.district_pos(sid)
	shown[sid] += d
	var dv: DistrictView = map.districts[sid]
	dv.display_health = clampf(shown[sid], 0.0, 100.0)
	if d >= 0 and ContentDB.is_positive(l["type"]):
		fx.text(pos + Vector2(0, -40), Loc.t("+%d") % d, Palette.GOOD, 1.1, 22)
		fx.sparks(pos, Palette.GOOD, 10, 0.6)
		sfx.play("heal")
	else:
		fx.text(pos + Vector2(0, -40), Loc.t("%d") % d, Palette.BAD, 1.1, 22 + mini(10, -d))
		fx.ring(pos, Palette.type_color(l["type"]), 0.5, 70)
		dv.flash = minf(1.0, 0.3 + absf(d) / 12.0)
		sfx.play("impact", 1.0 + randf() * 0.2)
		if d <= -8:
			_shake(0.25)
	if int(l["absorbed"]) > 0 and not ContentDB.is_positive(l["type"]):
		fx.text(pos + Vector2(60, -10), Loc.t("cushioned %d") % int(l["absorbed"]), Color("9fd3ff"), 1.0, 12)
	if String(l["spill_to"]) != "":
		var sc := GameSettings.anim_scale()
		fx.flight(pos, map.district_pos(l["spill_to"]) + Vector2(60, 10), l["type"], 4, 0.5 * sc, -60.0)
		fx.text(pos + Vector2(0, 10), Loc.t("OVERFLOW →"), Palette.ACCENT, 1.0, 13)
		map.pulse(sid, l["spill_to"], 0.8)


# ------------------------------------------------------------------ overlays

func _open_settings() -> void:
	var sp := SettingsPanel.new()
	sp.theme = hud.theme
	ui_layer.add_child(sp)


func _show_game_over() -> void:
	sfx.play("victory" if world.outcome == "victory" else "defeat")
	var g := GameOverPanel.new()
	g.setup(world)
	g.theme = hud.theme
	ui_layer.add_child(g)
	g.replay_seed.connect(func(): restart.emit("p0_valley" if world.scenario_id == "tutorial" else world.scenario_id, world.run_seed))
	g.new_run.connect(func(): restart.emit("p0_valley" if world.scenario_id == "tutorial" else world.scenario_id, SeedCode.random_seed()))
	g.to_menu.connect(func(): exit_to_menu.emit())
	if tutorial:
		tutorial.queue_free()
		tutorial = null


# ------------------------------------------------------------------ guidance (tutorial pointer + hints)

func _orb_matching(spec: Dictionary) -> int:
	if spec.has("orb_id"):
		return int(spec["orb_id"]) if orbs.has(int(spec["orb_id"])) else -1
	for c in world.ledger.pending_landing_on(world.turn):
		if c.type == spec.get("type", "") and c.destination == spec.get("dest", "") and orbs.has(c.id):
			return c.id
	return -1


func _selected_matches(spec: Dictionary) -> bool:
	if spec.is_empty():
		return selected_id >= 0
	var id := _orb_matching(spec)
	return id >= 0 and id == selected_id


## Turns a guidance target into either a map position or a HUD button id,
## falling back through the steps the player still has to take.
func _resolve(t: Dictionary) -> Dictionary:
	match String(t.get("kind", "")):
		"orb":
			var id := _orb_matching(t)
			if id >= 0 and id != selected_id:
				return {"map": orbs[id].position + orbs[id].bob()}
			return {}
		"action":
			var spec: Dictionary = t.get("orb", {})
			if not spec.is_empty() and not _selected_matches(spec):
				var r := spec.duplicate()
				r["kind"] = "orb"
				return _resolve(r)
			return {"ui": String(t["id"])}
		"district":
			if mode == "" and t.has("via"):
				return _resolve({"kind": "action", "id": t["via"], "orb": t.get("orb", {})})
			return {"map": map.district_pos(String(t["id"])) + Vector2(0, -10)}
		"crisis":
			if selected_district != String(t["id"]):
				return {"map": map.district_pos(String(t["id"])) + Vector2(0, -10)}
			return {"ui": "crisis"}
		"end":
			return {"ui": "end"}
		"hint":
			return {"ui": "hint"}
	return {}


func _guide_target() -> Dictionary:
	if tutorial:
		return tutorial.target()
	if hint_end:
		return {"kind": "end"}
	if hint_it == null:
		return {}
	match hint_it.kind:
		Intervention.CRISIS:
			return {"kind": "crisis", "id": hint_it.system}
		Intervention.REDIRECT, Intervention.SPLIT:
			return {"kind": "district", "id": hint_it.target, "via": hint_it.kind, "orb": {"orb_id": hint_it.consequence_id}}
	return {"kind": "action", "id": hint_it.kind, "orb": {"orb_id": hint_it.consequence_id}}


func _update_guide() -> void:
	if busy or world.is_over():
		guide.point_at(null)
		hud.set_guide("")
		return
	var r := _resolve(_guide_target())
	guide.point_at(r.get("map", null))
	hud.set_guide(String(r.get("ui", "")))


func _describe(it: Intervention) -> String:
	if it.kind == Intervention.CRISIS:
		return Loc.t("start the controlled crisis at %s") % Loc.sys(it.system)
	var c := world.ledger.get_c(it.consequence_id)
	var what := "%s %d" % [Loc.typ(c.type), c.current_magnitude]
	match it.kind:
		Intervention.REDIRECT: return Loc.t("move %s from %s to %s") % [what, Loc.sys(c.destination), Loc.sys(it.target)]
		Intervention.SPLIT: return Loc.t("split %s between %s and %s") % [what, Loc.sys(c.destination), Loc.sys(it.target)]
		Intervention.DELAY: return Loc.t("delay %s at %s to next season") % [what, Loc.sys(c.destination)]
		Intervention.TRANSFORM: return Loc.t("turn %s at %s into a bonus") % [what, Loc.sys(c.destination)]
	return ""


func _hint() -> void:
	if busy or world.is_over():
		return
	var actions := SimulationEngine.available_actions(world)
	var pick := BotStrategies.best_move(world, actions)
	if pick == null:
		hint_it = null
		hint_end = true
		hud.toast(Loc.t("No urgent move. Tap END to finish the season."), Palette.GOOD, 5.0)
		sfx.play("select")
		return
	hint_it = pick
	hint_end = false
	mode = ""
	report_open = false
	if pick.consequence_id >= 0:
		selected_id = pick.consequence_id
		selected_district = ""
	else:
		selected_id = -1
	hud.toast(Loc.t("Hint: %s") % _describe(pick), Palette.ACCENT, 6.0)
	sfx.play("select", 1.2)
	_refresh_ui()
