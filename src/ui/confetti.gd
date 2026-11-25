class_name Confetti
extends Control
## Celebration burst for a saved valley (drawn, no assets).

var _pieces: Array = []
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.fill_viewport(self)
	var r := DetRng.new(Time.get_ticks_msec())
	var cols := [Palette.ACCENT, Palette.GOOD, Color("9fd3ff"), Color("ff8fb1"), Color("e0d04f")]
	for k in 90:
		_pieces.append({
			"p": Vector2(size.x * 0.5 + r.between(-60, 60), size.y * 0.42),
			"v": Vector2(r.between(-420, 420), r.between(-620, -220)),
			"c": cols[k % cols.size()], "rot": r.range_int(628) / 100.0, "spin": r.between(-8, 8),
		})


func _process(delta: float) -> void:
	_t += delta
	for pc in _pieces:
		pc["v"].y += 900.0 * delta
		pc["v"] *= 0.992
		pc["p"] += pc["v"] * delta
		pc["rot"] += pc["spin"] * delta
	queue_redraw()
	if _t > 3.5:
		queue_free()


func _draw() -> void:
	var a := clampf(3.5 - _t, 0.0, 1.0)
	for pc in _pieces:
		draw_set_transform(pc["p"], pc["rot"], Vector2.ONE)
		var c: Color = pc["c"]
		draw_rect(Rect2(-5, -3, 10, 6), Color(c.r, c.g, c.b, a))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
