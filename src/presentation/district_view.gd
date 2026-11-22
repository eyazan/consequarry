class_name DistrictView
extends Node2D
## Procedurally drawn isometric miniature district. Health is shown physically:
## fewer intact buildings, ash-tinted ground, smoke and fire as it degrades.

const W := 172.0
const H := 86.0
const T := 16.0

var system_id := ""
var display_health := 70.0
var max_health := 100
var collapsed := false
var scarred := false
var capacity := 12
var capacity_used := 0
var resilience := 0
var hovered := false
var selected := false
var target_state := 0          # 0 none, 1 valid target, -1 invalid target
var preview_text := ""
var preview_color := Color.WHITE
var shake := Vector2.ZERO
var flash := 0.0
var _t := 0.0
var _rng_layout: Array = []


func _ready() -> void:
	var r := DetRng.new(system_id.hash())
	for i in 9:
		_rng_layout.append(r.range_int(1000) / 1000.0)


func _process(delta: float) -> void:
	_t += delta
	flash = maxf(0.0, flash - delta * 2.5)
	queue_redraw()


func contains_point(local: Vector2) -> bool:
	var p := local - Vector2(0, -12)
	return absf(p.x) / (W * 0.5) + absf(p.y) / (H * 0.5 + 26) <= 1.0


func _health_ratio() -> float:
	return clampf(display_health / 100.0, 0.0, 1.0)


func _ground_color() -> Color:
	var base: Color
	match system_id:
		"environment": base = Color("3e8f5e")
		"agriculture": base = Color("8fae4a")
		"energy": base = Color("5f6270")
		"industry": base = Color("6b5a52")
		"infrastructure": base = Color("62697a")
		"population": base = Color("6f6a78")
		_: base = Color("666666")
	var ash := Color("3a3330")
	return base.lerp(ash, clampf(1.0 - _health_ratio() * 1.4, 0.0, 0.85))


func _draw() -> void:
	var o := shake
	var h := _health_ratio()
	# shadow
	draw_set_transform(o + Vector2(0, T + 8), 0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, W * 0.52, Color(0, 0, 0, 0.35))
	draw_set_transform(o, 0, Vector2.ONE)
	var top := _ground_color()
	var top_pts := PackedVector2Array([Vector2(0, -H / 2), Vector2(W / 2, 0), Vector2(0, H / 2), Vector2(-W / 2, 0)])
	var left := PackedVector2Array([Vector2(-W / 2, 0), Vector2(0, H / 2), Vector2(0, H / 2 + T), Vector2(-W / 2, T)])
	var right := PackedVector2Array([Vector2(W / 2, 0), Vector2(0, H / 2), Vector2(0, H / 2 + T), Vector2(W / 2, T)])
	draw_colored_polygon(left, top.darkened(0.45))
	draw_colored_polygon(right, top.darkened(0.6))
	var accent := Palette.system_color(system_id)
	draw_colored_polygon(top_pts, top)
	# coloured rim identifies the system
	var rim := top_pts.duplicate()
	rim.append(top_pts[0])
	draw_polyline(rim, accent.darkened(0.1), 2.0, true)
	if flash > 0.0:
		draw_colored_polygon(top_pts, Color(1, 0.4, 0.3, flash * 0.45))
	_draw_surface_detail(h)
	_draw_buildings(h)
	if scarred:
		draw_polyline(PackedVector2Array([Vector2(-W * 0.3, -4), Vector2(-W * 0.12, 6), Vector2(0, -2), Vector2(W * 0.18, 10)]), Color(0.1, 0.05, 0.05, 0.8), 2.5)
	if not collapsed and h < 0.4:
		_draw_fire(h)
	_draw_highlight()
	_draw_label()
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _sub(i: int, j: int) -> Vector2:
	return Vector2((i - j) * W / 6.2, (i + j) * H / 6.2)


func _iso_box(c: Vector2, s: float, height: float, col: Color) -> void:
	var q := s * 0.5
	var top_c := c - Vector2(0, height)
	var tp := PackedVector2Array([top_c + Vector2(0, -q * 0.5), top_c + Vector2(q, 0), top_c + Vector2(0, q * 0.5), top_c + Vector2(-q, 0)])
	var lf := PackedVector2Array([top_c + Vector2(-q, 0), top_c + Vector2(0, q * 0.5), c + Vector2(0, q * 0.5), c + Vector2(-q, 0)])
	var rt := PackedVector2Array([top_c + Vector2(q, 0), top_c + Vector2(0, q * 0.5), c + Vector2(0, q * 0.5), c + Vector2(q, 0)])
	draw_colored_polygon(lf, col.darkened(0.25))
	draw_colored_polygon(rt, col.darkened(0.45))
	draw_colored_polygon(tp, col.lightened(0.12))


func _roof(c: Vector2, s: float, height: float, col: Color) -> void:
	var q := s * 0.5
	var b := c - Vector2(0, height)
	var apex_l := b + Vector2(-q * 0.5, -q * 0.55 - 2)
	var apex_r := b + Vector2(q * 0.5, -q * 0.3 - 2)
	draw_colored_polygon(PackedVector2Array([b + Vector2(-q, 0), apex_l, apex_r, b + Vector2(0, q * 0.5)]), col.darkened(0.15))
	draw_colored_polygon(PackedVector2Array([b + Vector2(0, q * 0.5), apex_r, b + Vector2(q, 0)]), col.darkened(0.4))


func _slots() -> Array:
	# back-to-front order of the 3x3 sub-grid
	var out := []
	for sum in range(-2, 3):
		for i in range(-1, 2):
			var j := sum - i
			if j >= -1 and j <= 1:
				out.append(Vector2i(i, j))
	return out


func _draw_surface_detail(h: float) -> void:
	match system_id:
		"agriculture":
			for k in range(-3, 4):
				var a := Vector2(-W / 2, 0).lerp(Vector2(0, -H / 2), (k + 3.5) / 7.0)
				var b := Vector2(0, H / 2).lerp(Vector2(W / 2, 0), (k + 3.5) / 7.0)
				var crop := Color("d8c25a").lerp(Color("4a3b2a"), 1.0 - h)
				draw_line(a.lerp(b, 0.08), a.lerp(b, 0.92), crop, 3.0)
		"infrastructure":
			draw_line(Vector2(-W / 2, 0).lerp(Vector2(0, H / 2), 0.5), Vector2(0, -H / 2).lerp(Vector2(W / 2, 0), 0.5), Color("2d3039"), 7)
			draw_line(Vector2(-W / 2, 0).lerp(Vector2(0, -H / 2), 0.5), Vector2(0, H / 2).lerp(Vector2(W / 2, 0), 0.5), Color("2d3039"), 7)
			draw_line(Vector2(-W / 2, 0).lerp(Vector2(0, -H / 2), 0.5), Vector2(0, H / 2).lerp(Vector2(W / 2, 0), 0.5), Color("e3d36a", 0.5 * h + 0.1), 1)
		"environment":
			draw_set_transform(shake + Vector2(W * 0.18, H * 0.12), 0, Vector2(1, 0.5))
			draw_circle(Vector2.ZERO, 22, Color("2f6f9a").lerp(Color("5a4a3a"), 1.0 - h))
			draw_set_transform(shake, 0, Vector2.ONE)


func _draw_buildings(h: float) -> void:
	var slots := _slots()
	var intact := int(round(clampf((h - 0.15) / 0.6, 0.0, 1.0) * 9.0))
	var accent := Palette.system_color(system_id)
	var gray := Color("6a5f58")
	for idx in slots.size():
		var sl: Vector2i = slots[idx]
		if system_id == "infrastructure" and (sl.x == 0 or sl.y == 0):
			continue
		if system_id == "agriculture" and idx % 2 == 0:
			continue
		if system_id == "environment" and sl == Vector2i(1, 0):
			continue
		var c := _sub(sl.x, sl.y)
		var rnd: float = _rng_layout[idx % _rng_layout.size()]
		var alive := (idx * 7 % 9) < intact and not collapsed
		if not alive:
			_iso_box(c, 18, 3 + rnd * 3, gray)
			draw_line(c + Vector2(-5, -3), c + Vector2(4, -6), Color(0.15, 0.12, 0.1), 1.5)
			continue
		var tall := 0.6 + h * 0.5
		match system_id:
			"energy":
				if idx % 3 == 0:
					_tower(c, 13, (26 + rnd * 10) * tall, Color("c9ccd6"))
				else:
					_iso_box(c, 20, (12 + rnd * 8) * tall, Color("7a7f8f"))
					var glow := Color(accent.r, accent.g, accent.b, 0.5 + 0.4 * sin(_t * 3 + idx) * (1.0 - h * 0.5))
					draw_circle(c - Vector2(0, (12 + rnd * 8) * tall + 4), 3.5, glow)
			"industry":
				_iso_box(c, 22, (14 + rnd * 10) * tall, Color("8a6d5e"))
				if idx % 2 == 1:
					var chim_h := (30 + rnd * 10) * tall
					_iso_box(c + Vector2(6, -2), 6, chim_h, Color("5a4a44"))
					_smoke(c + Vector2(6, -2 - chim_h), 1.0 - h * 0.4, idx)
			"infrastructure":
				_iso_box(c, 22, (16 + rnd * 18) * tall, Color("9aa3b5"))
				var top_y := (16 + rnd * 18) * tall
				for k in 3:
					draw_line(c + Vector2(-8, -top_y * (k + 1) / 4.0), c + Vector2(-1, -top_y * (k + 1) / 4.0 + 3), Color("f5e6a3", 0.6 * h), 1.5)
			"population":
				var bh := (9 + rnd * 6) * tall
				_iso_box(c, 18, bh, Color("d8c7b8"))
				_roof(c, 18, bh, Color("c0504d").lerp(Color("6b4b4b"), 1.0 - h))
				draw_circle(c + Vector2(-4, -bh * 0.5), 1.8, Color("ffe7a0", 0.9 * h))
			"agriculture":
				_iso_box(c, 16, 10 * tall, Color("b5653f"))
				_roof(c, 16, 10 * tall, Color("8a3b2a"))
			"environment":
				var th := (14 + rnd * 10) * tall
				draw_line(c, c - Vector2(0, th * 0.5), Color("5a3d2a"), 3)
				var leaf := Color("4fbf6a").lerp(Color("7a6a3a"), 1.0 - h)
				draw_colored_polygon(PackedVector2Array([c - Vector2(0, th + 10), c + Vector2(9, -th * 0.35), c + Vector2(-9, -th * 0.35)]), leaf)
				draw_colored_polygon(PackedVector2Array([c - Vector2(0, th + 2), c + Vector2(11, -th * 0.15), c + Vector2(-11, -th * 0.15)]), leaf.darkened(0.15))


func _tower(c: Vector2, r: float, height: float, col: Color) -> void:
	draw_set_transform(shake + c, 0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, r, col.darkened(0.3))
	draw_set_transform(shake, 0, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(-r * 0.7, -height), c + Vector2(r * 0.7, -height), c + Vector2(r, 0)]), col.darkened(0.15))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0), c + Vector2(0, -height), c + Vector2(r * 0.7, -height), c + Vector2(r, 0)]), col.darkened(0.35))
	draw_set_transform(shake + c - Vector2(0, height), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, r * 0.7, col.lightened(0.1))
	draw_circle(Vector2.ZERO, r * 0.45, Color("2a2c33"))
	draw_set_transform(shake, 0, Vector2.ONE)
	var steam := 0.35 + 0.15 * sin(_t * 2)
	for k in 3:
		var p := fmod(_t * 0.4 + k / 3.0, 1.0)
		draw_circle(c - Vector2(-p * 6, height + 6 + p * 22), 4 + p * 6, Color(0.95, 0.95, 1, steam * (1.0 - p)))


func _smoke(p: Vector2, dark: float, idx: int) -> void:
	for k in 4:
		var f := fmod(_t * 0.35 + k / 4.0 + idx * 0.13, 1.0)
		var col := Color(0.35, 0.33, 0.33, 0.5 * (1.0 - f)).lerp(Color(0.12, 0.1, 0.1, 0.6 * (1.0 - f)), dark)
		draw_circle(p + Vector2(f * 14 + sin(_t + k) * 2, -f * 26), 3 + f * 7, col)


func _draw_fire(h: float) -> void:
	var intensity := (0.4 - h) / 0.4
	for k in 3:
		var p := _sub([-1, 1, 0][k], [0, -1, 1][k])
		var flick := 0.6 + 0.4 * sin(_t * 11 + k * 2.3)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 0), p + Vector2(0, -14 * flick * intensity - 4), p + Vector2(5, 0)]), Color(1, 0.45, 0.1, 0.85))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-2.5, 0), p + Vector2(0, -7 * flick * intensity - 2), p + Vector2(2.5, 0)]), Color(1, 0.9, 0.4, 0.9))
		for s in 2:
			var f := fmod(_t * 0.5 + s * 0.5 + k * 0.2, 1.0)
			draw_circle(p + Vector2(f * 8, -18 - f * 24), 4 + f * 6, Color(0.1, 0.08, 0.08, 0.45 * (1.0 - f) * intensity))


func _draw_highlight() -> void:
	var pts := PackedVector2Array([Vector2(0, -H / 2), Vector2(W / 2, 0), Vector2(0, H / 2), Vector2(-W / 2, 0), Vector2(0, -H / 2)])
	if target_state == 1:
		var pulse := 0.6 + 0.4 * sin(_t * 6)
		draw_polyline(pts, Color(1, 0.75, 0.3, pulse), 4.0, true)
	elif target_state == -1:
		draw_colored_polygon(pts.slice(0, 4), Color(0, 0, 0, 0.35))
	if selected:
		draw_polyline(pts, Color(1, 1, 1, 0.95), 3.0, true)
	elif hovered:
		draw_polyline(pts, Color(1, 1, 1, 0.5), 2.0, true)


func _draw_label() -> void:
	var font := ThemeDB.fallback_font
	var name_s := String(ContentDB.system_def(system_id)["name"]).to_upper()
	var y := H / 2 + T + 18
	var col := Palette.system_color(system_id)
	draw_string(font, Vector2(-80, y), name_s, HORIZONTAL_ALIGNMENT_CENTER, 160, 13, col.lightened(0.25))
	# health bar
	var bw := 108.0
	var by := y + 6
	draw_rect(Rect2(-bw / 2 - 1, by - 1, bw + 2, 9), Color(0, 0, 0, 0.6))
	var hcol := Palette.GOOD.lerp(Palette.BAD, clampf(1.0 - display_health / 70.0, 0, 1))
	draw_rect(Rect2(-bw / 2, by, bw * clampf(display_health / 100.0, 0, 1), 7), hcol)
	if max_health < 100:
		var mx := -bw / 2 + bw * max_health / 100.0
		draw_rect(Rect2(mx, by, bw / 2 - mx + bw / 2 - bw / 2, 7), Color(0.25, 0.1, 0.1, 0.9))
	draw_string(font, Vector2(bw / 2 + 5, by + 8), str(int(round(display_health))), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.TEXT)
	# capacity pips: how much harm can still be cushioned this season
	var free := maxi(0, capacity - capacity_used)
	var pips := mini(capacity, 16)
	for k in pips:
		var filled := k < int(ceil(float(free) / capacity * pips))
		draw_rect(Rect2(-bw / 2 + k * (bw / pips), by + 11, bw / pips - 2, 3), Color(0.55, 0.8, 1.0, 0.85) if filled else Color(0.3, 0.3, 0.35, 0.6))
	if resilience > 0:
		draw_string(font, Vector2(-bw / 2 - 34, by + 8), "◆%d" % resilience, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("9fd3ff"))
	if collapsed:
		draw_string(font, Vector2(-80, -20), "COLLAPSED", HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Palette.BAD)
	if preview_text != "":
		var pw := 120.0
		draw_rect(Rect2(-pw / 2, -H / 2 - 64, pw, 22), Color(0, 0, 0, 0.75))
		draw_string(font, Vector2(-pw / 2, -H / 2 - 48), preview_text, HORIZONTAL_ALIGNMENT_CENTER, pw, 14, preview_color)
