class_name GuidePointer
extends Node2D
## Bouncing arrow + pulsing ring that points at a spot on the map
## (tutorial steps and hints: "tap here").

var _t := 0.0
var active := false


var drag_mode := false
var drag_from := Vector2.ZERO
var drag_to := Vector2.ZERO


## Shows a "drag from here to there" gesture (ghost shape sliding along).
func drag_between(a: Vector2, b: Vector2) -> void:
	drag_mode = true
	drag_from = a
	drag_to = b
	position = Vector2.ZERO
	visible = true


func point_at(pos: Variant) -> void:
	drag_mode = false
	active = pos != null
	if active:
		position = position.lerp(pos, 0.35) if visible else pos
	visible = active


func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()


func _draw() -> void:
	if drag_mode:
		_draw_drag()
		return
	var bounce := absf(sin(_t * 5.0)) * 14.0
	var col := Palette.ACCENT
	# ring around the target
	var r := 30.0 + sin(_t * 5.0) * 4.0
	draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(col.r, col.g, col.b, 0.9), 3.0, true)
	draw_arc(Vector2.ZERO, r + 8, 0, TAU, 40, Color(col.r, col.g, col.b, 0.35), 2.0, true)
	# arrow above, pointing down
	var tip := Vector2(0, -r - 6 - bounce)
	var pts := PackedVector2Array([tip, tip + Vector2(-16, -22), tip + Vector2(-6, -22), tip + Vector2(-6, -46),
		tip + Vector2(6, -46), tip + Vector2(6, -22), tip + Vector2(16, -22)])
	draw_colored_polygon(pts, col)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0.1, 0.07, 0.02), 2.0, true)


func _draw_drag() -> void:
	var col := Palette.ACCENT
	var k := fmod(_t * 0.7, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var mid := (drag_from + drag_to) * 0.5 + Vector2(0, -60)
	var pts := PackedVector2Array()
	for i in 21:
		var t := i / 20.0
		pts.append(drag_from.lerp(mid, t).lerp(mid.lerp(drag_to, t), t))
	for i in range(0, 20, 2):
		draw_line(pts[i], pts[i + 1], Color(col.r, col.g, col.b, 0.8), 3.0, true)
	var p := drag_from.lerp(mid, e).lerp(mid.lerp(drag_to, e), e)
	draw_circle(p, 16, Color(col.r, col.g, col.b, 0.35 * (1.0 - k * 0.5)))
	draw_circle(p, 9, Color(1, 1, 1, 0.8 * (1.0 - k * 0.5)))
	# fingertip
	draw_circle(p + Vector2(10, 14), 7, Color(0.95, 0.85, 0.75, 0.9))
	draw_arc(drag_to, 32 + sin(_t * 5.0) * 4.0, 0, TAU, 40, Color(col.r, col.g, col.b, 0.9), 3.0, true)
