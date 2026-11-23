class_name GuidePointer
extends Node2D
## Bouncing arrow + pulsing ring that points at a spot on the map
## (tutorial steps and hints: "tap here").

var _t := 0.0
var active := false


func point_at(pos: Variant) -> void:
	active = pos != null
	if active:
		position = position.lerp(pos, 0.35) if visible else pos
	visible = active


func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()


func _draw() -> void:
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
