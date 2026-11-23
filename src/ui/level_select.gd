class_name LevelSelect
extends Control
## Campaign map: 30 short levels in three regions, stars and locks.

signal level_chosen(level_id: String)
signal back


func _ready() -> void:
	UIKit.fill_viewport(self)
	var bg := ColorRect.new()
	bg.color = Color(Palette.BG.r, Palette.BG.g, Palette.BG.b, 0.92)
	add_child(bg)
	UIKit.fill_viewport(bg)
	var margin := MarginContainer.new()
	add_child(margin)
	UIKit.fill_viewport(margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16 if GameSettings.compact else 40)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)
	var head := HBoxContainer.new()
	head.add_child(UIKit.button("◀ Menu", func(): back.emit()))
	var title := UIKit.label("VALLEYS", 26, Palette.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title)
	head.add_child(UIKit.label(Loc.t("★ %d / %d") % [Campaign.total_stars(), Campaign.levels().size() * 3], 20, Palette.ACCENT))
	outer.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	var levels := Campaign.levels()
	var region := ""
	var grid: GridContainer = null
	var focus_btn: Button = null
	for i in levels.size():
		var lv: Dictionary = levels[i]
		if lv["region"] != region:
			region = String(lv["region"])
			list.add_child(UIKit.label(Loc.upper(Loc.t(region)), 16, Palette.TEXT_DIM))
			grid = GridContainer.new()
			grid.columns = 10 if not GameSettings.compact else 10
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 8)
			list.add_child(grid)
		var unlocked := Campaign.is_unlocked(i)
		var st := Campaign.best(String(lv["id"]))
		var b := Button.new()
		b.custom_minimum_size = Vector2(76, 70) if not GameSettings.compact else Vector2(78, 64)
		b.text = "%d\n%s" % [int(lv["number"]), ("★".repeat(st) + "☆".repeat(3 - st)) if unlocked else "—"]
		b.add_theme_font_size_override("font_size", 18)
		b.tooltip_text = Loc.t(String(lv["name"]))
		b.disabled = not unlocked
		if st > 0:
			b.add_theme_color_override("font_color", Palette.ACCENT)
		var id := String(lv["id"])
		b.pressed.connect(func(): level_chosen.emit(id))
		grid.add_child(b)
		if unlocked and st == 0 and focus_btn == null:
			focus_btn = b
	if focus_btn:
		focus_btn.call_deferred("grab_focus")
