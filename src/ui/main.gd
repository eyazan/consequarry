extends Node
## Application root: switches between the title screen and a run.
## Command-line (after --): --autostart <scenario> <seed>  starts a run directly
## (used for screenshots and automated smoke tests).

var current: Node = null
var ui_theme: Theme


func _ready() -> void:
	GameSettings.load_settings()
	add_child(Music.new())
	GameSettings.apply()
	GameSettings.apply_layout(get_window())
	GameSettings.apply_language()
	_build_rotate_overlay()
	_install_symbol_fallback()
	ui_theme = UIKit.make_theme()
	RenderingServer.set_default_clear_color(Palette.BG)
	var args := OS.get_cmdline_user_args()
	var i := args.find("--autostart")
	if args.has("--daily"):
		_start_daily()
	elif i < 0 and shot_requested(args) == false and not GameSettings.tutorial_done and not SaveSystem.has_run():
		# First launch: teach by playing the first valley instead of a menu full of terms.
		_play_level("lvl_01")
	elif args.has("--map"):
		_show_map()
	elif i >= 0 and args.size() > i + 2:
		_start(args[i + 1], int(args[i + 2]))
	else:
		_show_menu()
	var shot := args.find("--shot")
	if shot >= 0 and args.size() > shot + 2:
		_capture(args[shot + 1], int(args[shot + 2]), args.find("--demo") >= 0)


## Automated capture used for documentation and visual QA (not a gameplay feature).
func _capture(path: String, frames: int, demo: bool) -> void:
	var _p := path
	for _f in 20:
		await get_tree().process_frame
	if demo and current is GameView:
		var gv: GameView = current
		var heat := -1
		for c in gv.world.ledger.pending():
			if c.type == "heat":
				heat = c.id
		if heat >= 0:
			gv._select_orb(heat)
			await get_tree().create_timer(0.3).timeout
			gv._on_action("redirect", str(heat))
			await get_tree().create_timer(0.2).timeout
			gv._do_target("energy")
			await get_tree().create_timer(0.6).timeout
			var moved := gv.selected_id
			gv._on_action("transform:thermal_capture", str(moved))
			await get_tree().create_timer(0.5).timeout
			if args_has("--endturn"):
				gv.end_turn()
				await get_tree().create_timer(1.2).timeout
	var sd := OS.get_cmdline_user_args().find("--select-district")
	if sd >= 0 and current is GameView:
		var gv3: GameView = current
		gv3._click({"district": OS.get_cmdline_user_args()[sd + 1]})
	var so := OS.get_cmdline_user_args().find("--select-type")
	if so >= 0 and current is GameView:
		var gv4: GameView = current
		for c in gv4.world.ledger.pending():
			if c.type == OS.get_cmdline_user_args()[so + 1]:
				gv4._select_orb(c.id)
				break
	if args_has("--guided") and current is GameView:
		await _guided_walk(current, path)
		return
	if args_has("--autoplay") and current is GameView:
		# UI integration smoke test: a bot plays a full run through GameView.
		var gv2: GameView = current
		GameSettings.anim_speed_index = 2 if not args_has("--animated") else 1
		var rng := DetRng.new(7)
		var guard := 0
		while not gv2.world.is_over() and guard < 30:
			guard += 1
			var acts := SimulationEngine.available_actions(gv2.world)
			var n := 0
			while gv2.world.action_points > 0 and not acts.is_empty() and n < 6:
				n += 1
				var a: Intervention = acts[rng.range_int(acts.size())]
				gv2._apply(a)
				acts = SimulationEngine.available_actions(gv2.world)
			gv2.end_turn()
			while gv2.busy:
				await get_tree().process_frame
			await get_tree().process_frame
		print("autoplay finished: ", gv2.world.outcome, " - ", gv2.world.outcome_reason)
		var errs := gv2.world.ledger.verify()
		print("ledger errors: ", errs.size())
	for _f in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
	get_tree().quit()


func args_has(a: String) -> bool:
	return OS.get_cmdline_user_args().has(a)


func _swap(n: Node) -> void:
	if current:
		current.queue_free()
	current = n
	add_child(n)


func _show_menu() -> void:
	var root := Node2D.new()
	var map := IsoMap.new()
	root.add_child(map)
	map.build()
	var r := DetRng.new(Time.get_ticks_msec())
	for id in map.districts:
		map.districts[id].display_health = 45 + r.range_int(50)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var menu := MainMenu.new()
	menu.theme = ui_theme
	layer.add_child(menu)
	menu.start_run.connect(_start)
	menu.continue_run.connect(_continue)
	menu.start_daily.connect(_start_daily)
	menu.open_campaign.connect(_show_map)
	menu.language_changed.connect(_show_menu)
	menu.open_settings.connect(func():
		var sp := SettingsPanel.new()
		sp.theme = ui_theme
		layer.add_child(sp))
	_swap(root)
	root.set_process(true)
	var vr := get_viewport().get_visible_rect().size
	var ms := 0.7 if GameSettings.compact else 1.05
	map.position = Vector2(vr.x * 0.68, vr.y * 0.52)
	map.scale = Vector2(ms, ms)


func _start(scenario_id: String, run_seed: int) -> void:
	SaveSystem.clear_run()
	var w := SimulationEngine.new_run(scenario_id, run_seed)
	var guided := scenario_id == "tutorial" or (TutorialOverlay.LEVEL_SETS.has(scenario_id) and (Campaign.best(scenario_id) == 0 or args_has("--guided")))
	_launch(w, guided)


## Campaign level: each attempt gets a new deterministic seed.
func _play_level(level_id: String) -> void:
	if level_id == "":
		_show_map()
		return
	var attempt := GameSettings.next_attempt(level_id)
	_start(level_id, Campaign.level_seed(level_id, attempt))


func _show_map() -> void:
	var root := Node2D.new()
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var ls := LevelSelect.new()
	ls.theme = ui_theme
	layer.add_child(ls)
	ls.level_chosen.connect(_play_level)
	ls.back.connect(_show_menu)
	_swap(root)


func _start_daily() -> void:
	SaveSystem.clear_run()
	var d := SeedCode.today()
	var w := SimulationEngine.new_run(d["scenario"], d["seed"])
	w.daily_date = d["date"]
	_launch(w, false)


func _continue() -> void:
	var w := SaveSystem.load_world()
	if w == null:
		_show_menu()
		return
	_launch(w, false)


func shot_requested(args: PackedStringArray) -> bool:
	return args.has("--shot")


func _launch(w: WorldState, tutorial: bool) -> void:
	if not tutorial:
		GameSettings.runs_started += 1
		GameSettings.save_settings()
	var gv := GameView.new()
	_swap(gv)
	gv.start(w, tutorial)
	SaveSystem.save_world(w)
	gv.exit_to_menu.connect(func(): _show_map() if Campaign.is_level(w.scenario_id) else _show_menu())
	gv.restart.connect(_start)
	gv.open_map.connect(_show_map)
	gv.play_level.connect(_play_level)


# ------------------------------------------------------------------ portrait guard

var _rotate_layer: CanvasLayer


func _build_rotate_overlay() -> void:
	_rotate_layer = CanvasLayer.new()
	_rotate_layer.layer = 100
	add_child(_rotate_layer)
	var bg := ColorRect.new()
	bg.color = Palette.BG
	_rotate_layer.add_child(bg)
	UIKit.fill_viewport(bg)
	var l := UIKit.label("Rotate your device to landscape\nto play CONSEQUARRY.", 22, Palette.ACCENT, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rotate_layer.add_child(l)
	UIKit.fill_viewport(l)
	_rotate_layer.visible = false


func _process(_delta: float) -> void:
	var ws := DisplayServer.window_get_size()
	if _rotate_layer:
		_rotate_layer.visible = ws.y > ws.x * 1.05


## Web/mobile builds have no system fonts; DejaVu Sans supplies the symbols
## (arrows, pips, triangles) missing from Godot's default font.
func _install_symbol_fallback() -> void:
	var dv: Font = load("res://assets/fonts/DejaVuSans.ttf")
	var base := ThemeDB.fallback_font
	if dv and base and not base.fallbacks.has(dv):
		var fb := base.fallbacks.duplicate()
		fb.append(dv)
		base.fallbacks = fb


## QA: plays like a newcomer who only follows the on-screen arrow (tutorial),
## then only follows Hint. Clicks are real input events at screen positions.
func _guided_walk(gv: GameView, path: String) -> void:
	GameSettings.anim_speed_index = 2
	var clicks := 0
	var shots := 0
	var guard := 0
	while gv.tutorial != null and guard < 40:
		guard += 1
		await get_tree().create_timer(0.25).timeout
		while gv.busy:
			await get_tree().process_frame
		if gv.tutorial == null:
			break
		if gv.tutorial.next_btn.visible:
			gv.tutorial.next_btn.pressed.emit()
			continue
		for ch in gv.ui_layer.get_children():
			if ch is LevelIntro:
				ch.start_pressed.emit()
				ch.queue_free()
		var r := gv._resolve(gv._guide_target())
		if args_has("--verbose"):
			print("step=%d wait=%s resolve=%s selected=%d mode=%s" % [gv.tutorial.step, gv.tutorial.current_wait(), str(r), gv.selected_id, gv.mode])
		if r.has("drag_from"):
			var xf := gv.map.get_global_transform_with_canvas()
			await _drag_gesture(xf * Vector2(r["drag_from"]), xf * Vector2(r["drag_to"]))
		elif r.has("map"):
			var screen: Vector2 = gv.map.get_global_transform_with_canvas() * Vector2(r["map"])
			_click_at(screen)
		elif r.has("ui"):
			var b := gv.hud._guide_button()
			if b == null:
				print("guided: no button for ", r["ui"])
				break
			_click_at(b.get_global_rect().get_center())
		else:
			print("guided: nothing to point at in step ", gv.tutorial.step)
			break
		clicks += 1
		if shots < 3:
			await get_tree().process_frame
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_step%d.png" % shots))
			shots += 1
	print("guided tutorial finished=%s clicks=%d" % [str(gv.tutorial == null), clicks])
	# Hint-only play for the rest of the run.
	guard = 0
	while not gv.world.is_over() and guard < 200:
		guard += 1
		while gv.busy:
			await get_tree().process_frame
		if gv.world.is_over():
			break
		for ch in gv.ui_layer.get_children():
			if ch is LevelIntro:
				ch.start_pressed.emit()
				ch.queue_free()
		if gv.hint_it == null and not gv.hint_end:
			gv._hint()
			await get_tree().process_frame
		var r := gv._resolve(gv._guide_target())
		if r.has("drag_from"):
			var xf := gv.map.get_global_transform_with_canvas()
			await _drag_gesture(xf * Vector2(r["drag_from"]), xf * Vector2(r["drag_to"]))
		elif r.has("map"):
			_click_at(gv.map.get_global_transform_with_canvas() * Vector2(r["map"]))
		elif r.has("ui"):
			var b := gv.hud._guide_button()
			if b == null:
				print("guided: hint button missing for ", r["ui"])
				break
			_click_at(b.get_global_rect().get_center())
		await get_tree().process_frame
		await get_tree().process_frame
	print("guided run outcome=%s (%s) ledger_errors=%d" % [gv.world.outcome, gv.world.outcome_reason, gv.world.ledger.verify().size()])
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _click_at(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		Input.parse_input_event(ev)
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	Input.parse_input_event(mv)


func _drag_gesture(a: Vector2, b: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = a
	down.global_position = a
	Input.parse_input_event(down)
	await get_tree().process_frame
	for k in range(1, 11):
		var mv := InputEventMouseMotion.new()
		mv.position = a.lerp(b, k / 10.0)
		mv.global_position = mv.position
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(mv)
		await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = b
	up.global_position = b
	Input.parse_input_event(up)
	await get_tree().process_frame
