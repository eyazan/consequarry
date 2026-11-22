class_name IsoMap
extends Node2D
## The valley: ground, causal pipes (with flowing pulses) and district views.

const SPACING := 128.0
const SQUASH := 0.8

var districts: Dictionary = {}   # id -> DistrictView
var edges: Array = []
var queued_effects: Array = []
var highlight_system := ""
var show_links := true
var pulse_edges: Dictionary = {}  # "from>to" -> remaining seconds
var _t := 0.0


func build() -> void:
	edges = ContentDB.data()["causal_edges"]
	for sd in ContentDB.data()["systems"]:
		var d := DistrictView.new()
		d.system_id = String(sd["id"])
		d.position = grid_to_screen(sd["grid"])
		districts[d.system_id] = d
	# draw back-to-front
	var ids := districts.keys()
	ids.sort_custom(func(a, b): return districts[a].position.y < districts[b].position.y)
	for id in ids:
		add_child(districts[id])


static func grid_to_screen(g: Array) -> Vector2:
	return Vector2(float(g[0]) * SPACING, float(g[1]) * SPACING * SQUASH)


func district_pos(id: String) -> Vector2:
	return districts[id].position


func _process(delta: float) -> void:
	_t += delta
	for k in pulse_edges.keys():
		pulse_edges[k] -= delta
		if pulse_edges[k] <= 0:
			pulse_edges.erase(k)
	queue_redraw()


func pulse(from: String, to: String, dur: float = 1.2) -> void:
	pulse_edges["%s>%s" % [from, to]] = dur


func _edge_points(a: Vector2, b: Vector2) -> PackedVector2Array:
	var mid := (a + b) * 0.5
	var n := (b - a).orthogonal().normalized()
	var ctrl := mid + n * 18.0
	var pts := PackedVector2Array()
	for k in 17:
		var t := k / 16.0
		pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	return pts


func _draw() -> void:
	# ground plate
	var gw := SPACING * 3.6
	var gh := gw * SQUASH
	var ground := PackedVector2Array([Vector2(0, -gh), Vector2(gw, 0), Vector2(0, gh), Vector2(-gw, 0)])
	draw_colored_polygon(ground, Color("171b25"))
	for k in range(-6, 7):
		var f := k / 6.0
		draw_line(Vector2(-gw, 0).lerp(Vector2(0, -gh), (f + 1) / 2), Vector2(0, gh).lerp(Vector2(gw, 0), (f + 1) / 2), Color(1, 1, 1, 0.025), 1)
		draw_line(Vector2(-gw, 0).lerp(Vector2(0, gh), (f + 1) / 2), Vector2(0, -gh).lerp(Vector2(gw, 0), (f + 1) / 2), Color(1, 1, 1, 0.025), 1)
	# river through the valley (decorative)
	var river := PackedVector2Array()
	for k in 30:
		var t := k / 29.0
		river.append(Vector2(-gw * 0.95 + t * gw * 1.9, gh * 0.02 + sin(t * 6.0) * 14.0))
	draw_polyline(river, Color("1c3347"), 9, true)
	draw_polyline(river, Color("2d5878", 0.5), 3, true)
	var font := ThemeDB.fallback_font
	for e in edges:
		var key := "%s>%s" % [e["from"], e["to"]]
		var involved: bool = highlight_system != "" and (e["from"] == highlight_system or e["to"] == highlight_system)
		if not show_links and not involved and not pulse_edges.has(key):
			continue
		var a := district_pos(e["from"])
		var b := district_pos(e["to"])
		var dir := (b - a).normalized()
		a += dir * 62
		b -= dir * 62
		var pts := _edge_points(a, b)
		var col: Color = Palette.SUPPORT if e["kind"] == "support" else Palette.PRESSURE
		var alpha := 0.22
		if involved:
			alpha = 0.85
		elif highlight_system != "":
			alpha = 0.08
		var width := 1.0 + int(e["weight"]) / 9.0
		if pulse_edges.has(key):
			alpha = 1.0
			width += 2
		draw_polyline(pts, Color(col.r, col.g, col.b, alpha), width, true)
		# arrow head
		var tip := pts[pts.size() - 1]
		var back := (pts[pts.size() - 3] - tip).normalized()
		draw_colored_polygon(PackedVector2Array([tip, tip + back.rotated(0.45) * 11, tip + back.rotated(-0.45) * 11]), Color(col.r, col.g, col.b, alpha))
		# flowing pulses show direction of influence
		for p in 3:
			var f := fmod(_t * 0.35 + p / 3.0, 1.0)
			var idx := int(f * (pts.size() - 1))
			draw_circle(pts[idx], width * 0.9 + 1, Color(col.r, col.g, col.b, alpha * 0.9))
		# queued effect for next resolution
		for q in queued_effects:
			if q["from"] == e["from"] and q["to"] == e["to"]:
				var mid := pts[8]
				var qc := Palette.GOOD if int(q["delta"]) > 0 else Palette.BAD
				var s := ("+%d" if int(q["delta"]) > 0 else "%d") % int(q["delta"])
				if alpha > 0.15:
					draw_circle(mid, 11, Color(0.05, 0.06, 0.09, 0.9))
					draw_string(font, mid + Vector2(-16, 5), s, HORIZONTAL_ALIGNMENT_CENTER, 32, 12, qc)
