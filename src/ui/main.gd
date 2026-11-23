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
	elif i >= 0 and args.size() > i + 2:
		_start(args[i + 1], int(args[i + 2]))
	else:
		_show_menu()
	var shot := args.find("--shot")
	if shot >= 0 and args.size() > shot + 2:
		_capture(args[shot + 1], int(args[shot + 2]), args.find("--demo") >= 0)


## Automated capture used for documentation and visual QA (not a gameplay feature).
func _capture(path: String, frames: int, demo: bool) -> void:
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
	_launch(w, scenario_id == "tutorial")


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


func _launch(w: WorldState, tutorial: bool) -> void:
	var gv := GameView.new()
	_swap(gv)
	gv.start(w, tutorial)
	SaveSystem.save_world(w)
	gv.exit_to_menu.connect(_show_menu)
	gv.restart.connect(_start)


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
