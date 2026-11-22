class_name OrbView
extends Node2D
## A pending consequence floating above the district it is headed for.

var consequence_id := -1
var type_id := ""
var magnitude := 0
var future := false
var turns_away := 0
var hovered := false
var selected := false
var dimmed := false
var _t := 0.0
var _phase := 0.0
var appear := 1.0


func setup(c: Consequence, current_turn: int) -> void:
	consequence_id = c.id
	type_id = c.type
	magnitude = c.current_magnitude
	future = c.land_turn > current_turn
	turns_away = c.land_turn - current_turn
	_phase = float(c.id) * 1.7


func radius() -> float:
	var r := 8.0 + sqrt(float(magnitude)) * 2.2
	return r * (0.65 if future else 1.0)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func bob() -> Vector2:
	return Vector2(0, sin(_t * 2.2 + _phase) * 3.0)


func contains_point(local: Vector2) -> bool:
	return (local - bob()).length() <= radius() + (16.0 if GameSettings.compact else 6.0)


func _draw() -> void:
	var p := bob()
	var a := (0.5 if future else 1.0) * appear
	if dimmed:
		a *= 0.35
	var r := radius() * (0.6 + 0.4 * appear)
	# tether to the ground: shows which district it will hit
	draw_line(p + Vector2(0, r), Vector2(0, 38), Color(1, 1, 1, 0.12 * a), 1.0)
	draw_set_transform(Vector2(0, 40), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, r * 0.8, Color(0, 0, 0, 0.25 * a))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	Palette.draw_glyph(self, p, type_id, r, a)
	var font := ThemeDB.fallback_font
	var txt := str(magnitude)
	draw_string_outline(font, p + Vector2(-20, 5), txt, HORIZONTAL_ALIGNMENT_CENTER, 40, 14 if not future else 11, 4, Color(0, 0, 0, 0.9 * a))
	draw_string(font, p + Vector2(-20, 5), txt, HORIZONTAL_ALIGNMENT_CENTER, 40, 14 if not future else 11, Color(1, 1, 1, a))
	if future:
		draw_string(font, p + Vector2(-20, -r - 4), "+%d" % turns_away, HORIZONTAL_ALIGNMENT_CENTER, 40, 10, Color(1, 1, 1, 0.7 * a))
	if selected:
		var rr := r + 7
		for k in 8:
			var ang := _t * 1.5 + k * TAU / 8
			draw_arc(p, rr, ang, ang + TAU / 16, 6, Color(1, 1, 1, 0.95), 2.0)
	elif hovered:
		draw_arc(p, r + 5, 0, TAU, 24, Color(1, 1, 1, 0.6), 1.5)
