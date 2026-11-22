class_name Palette
extends RefCounted
## Shared colours and glyph drawing. Glyph SHAPES encode consequence type so the
## game is readable without colour (colour-blind accessibility).

const BG := Color("12141c")
const BG2 := Color("1a1e2a")
const PANEL := Color("1d2230ee")
const PANEL_LIGHT := Color("283043")
const TEXT := Color("e9e6dc")
const TEXT_DIM := Color("9aa0ad")
const ACCENT := Color("ffb347")
const GOOD := Color("62e3a8")
const BAD := Color("ff5c57")
const SUPPORT := Color("4fc3b0")
const PRESSURE := Color("b48cff")


static func system_color(id: String) -> Color:
	return Color(String(ContentDB.system_def(id).get("color", "#ffffff")))


static func type_color(id: String) -> Color:
	return Color(String(ContentDB.type_def(id).get("color", "#ffffff")))


static func glyph_points(glyph: String, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match glyph:
		"triangle":
			for i in 3:
				var a := -PI / 2 + i * TAU / 3
				pts.append(Vector2(cos(a), sin(a)) * r * 1.15)
		"diamond":
			pts = PackedVector2Array([Vector2(0, -r * 1.2), Vector2(r * 0.85, 0), Vector2(0, r * 1.2), Vector2(-r * 0.85, 0)])
		"hexagon":
			for i in 6:
				var a := i * TAU / 6
				pts.append(Vector2(cos(a), sin(a)) * r)
		"square":
			pts = PackedVector2Array([Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)])
			for i in pts.size():
				pts[i] *= 0.85
		_:
			for i in 20:
				var a := i * TAU / 20
				pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


static func draw_glyph(ci: CanvasItem, pos: Vector2, type_id: String, r: float, alpha: float = 1.0, outline: bool = true) -> void:
	var td := ContentDB.type_def(type_id)
	var col := type_color(type_id)
	col.a *= alpha
	var pts := glyph_points(String(td.get("glyph", "circle")), r)
	for i in pts.size():
		pts[i] += pos
	# soft glow
	ci.draw_circle(pos, r * 1.9, Color(col.r, col.g, col.b, 0.12 * alpha))
	ci.draw_circle(pos, r * 1.4, Color(col.r, col.g, col.b, 0.18 * alpha))
	ci.draw_colored_polygon(pts, col)
	if outline:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, Color(1, 1, 1, 0.75 * alpha), 1.5, true)
	if String(td["id"]) == "surplus":
		# star sparkle marks the positive type independent of colour
		ci.draw_line(pos + Vector2(-r * 0.5, 0), pos + Vector2(r * 0.5, 0), Color(1, 1, 1, 0.9 * alpha), 2)
		ci.draw_line(pos + Vector2(0, -r * 0.5), pos + Vector2(0, r * 0.5), Color(1, 1, 1, 0.9 * alpha), 2)
