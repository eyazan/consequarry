class_name GuideArrow
extends Control
## Bouncing arrow drawn on the HUD layer that points at a button.

var tip := Vector2.ZERO
var dir := Vector2.RIGHT
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(1, 1)


func setup(p_tip: Vector2, p_dir: Vector2, p_t: float) -> void:
	tip = p_tip
	dir = p_dir
	t = p_t
	queue_redraw()


func _draw() -> void:
	var back := -dir
	var side := dir.orthogonal()
	var b := tip + back * (6.0 + absf(sin(t * 5.0)) * 12.0)
	var pts := PackedVector2Array([b, b + back * 22 + side * 16, b + back * 22 + side * 6, b + back * 46 + side * 6,
		b + back * 46 - side * 6, b + back * 22 - side * 6, b + back * 22 - side * 16])
	draw_colored_polygon(pts, Palette.ACCENT)
	var o := pts.duplicate()
	o.append(pts[0])
	draw_polyline(o, Color(0.1, 0.07, 0.02), 2.0, true)
