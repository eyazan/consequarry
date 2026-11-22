class_name FxLayer
extends Node2D
## Lightweight immediate-mode effects: flights, rings, floating numbers, bolts, sparks.

var _fx: Array = []


func _process(delta: float) -> void:
	var still: Array = []
	for f in _fx:
		f["t"] += delta
		if f["t"] >= f["dur"]:
			if f.has("done") and f["done"] is Callable and f["done"].is_valid():
				f["done"].call()
		else:
			still.append(f)
	_fx = still
	queue_redraw()


func busy() -> bool:
	return not _fx.is_empty()


func clear() -> void:
	_fx.clear()


func flight(from: Vector2, to: Vector2, type_id: String, magnitude: int, dur: float, arc: float = -80.0, done: Callable = Callable()) -> void:
	_fx.append({"kind": "flight", "from": from, "to": to, "type": type_id, "mag": magnitude, "t": 0.0, "dur": maxf(dur, 0.01), "arc": arc, "done": done})


func ring(pos: Vector2, col: Color, dur: float = 0.5, size: float = 60.0) -> void:
	_fx.append({"kind": "ring", "pos": pos, "col": col, "t": 0.0, "dur": maxf(dur, 0.01), "size": size})


func text(pos: Vector2, s: String, col: Color, dur: float = 1.2, size: int = 20) -> void:
	_fx.append({"kind": "text", "pos": pos, "s": s, "col": col, "t": 0.0, "dur": maxf(dur, 0.01), "size": size})


func bolt(from: Vector2, to: Vector2, col: Color, dur: float = 0.5) -> void:
	var r := DetRng.new(int(from.x * 13 + to.y * 7))
	var pts := PackedVector2Array([from])
	for k in range(1, 7):
		var p := from.lerp(to, k / 7.0) + Vector2(r.between(-12, 12), r.between(-12, 12))
		pts.append(p)
	pts.append(to)
	_fx.append({"kind": "bolt", "pts": pts, "col": col, "t": 0.0, "dur": maxf(dur, 0.01)})


func sparks(pos: Vector2, col: Color, n: int = 14, dur: float = 0.7) -> void:
	var r := DetRng.new(int(pos.x * 31 + pos.y))
	var dirs: Array = []
	for k in n:
		var a := r.range_int(628) / 100.0
		dirs.append(Vector2(cos(a), sin(a)) * (60 + r.range_int(80)))
	_fx.append({"kind": "sparks", "pos": pos, "col": col, "dirs": dirs, "t": 0.0, "dur": maxf(dur, 0.01)})


func banner(pos: Vector2, title: String, sub: String, col: Color, dur: float = 1.8) -> void:
	_fx.append({"kind": "banner", "pos": pos, "title": title, "sub": sub, "col": col, "t": 0.0, "dur": maxf(dur, 0.01)})


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for f in _fx:
		var k: float = f["t"] / f["dur"]
		match f["kind"]:
			"flight":
				var e := k * k * (3.0 - 2.0 * k)
				var p: Vector2 = f["from"].lerp(f["to"], e) + Vector2(0, f["arc"] * 4.0 * e * (1.0 - e))
				var r := 8.0 + sqrt(float(f["mag"])) * 2.2
				for tr in 4:
					var e2 := maxf(0.0, e - tr * 0.04)
					var p2: Vector2 = f["from"].lerp(f["to"], e2) + Vector2(0, f["arc"] * 4.0 * e2 * (1.0 - e2))
					var c := Palette.type_color(f["type"])
					draw_circle(p2, r * (0.7 - tr * 0.12), Color(c.r, c.g, c.b, 0.25 - tr * 0.05))
				Palette.draw_glyph(self, p, f["type"], r)
			"ring":
				var c: Color = f["col"]
				draw_set_transform(f["pos"], 0, Vector2(1, 0.5))
				draw_arc(Vector2.ZERO, f["size"] * k, 0, TAU, 40, Color(c.r, c.g, c.b, 1.0 - k), 4.0 * (1.0 - k) + 1)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			"text":
				var c: Color = f["col"]
				var p: Vector2 = f["pos"] + Vector2(0, -50 * k)
				var a := 1.0 if k < 0.6 else (1.0 - k) / 0.4
				draw_string_outline(font, p + Vector2(-80, 0), f["s"], HORIZONTAL_ALIGNMENT_CENTER, 160, f["size"], 5, Color(0, 0, 0, a))
				draw_string(font, p + Vector2(-80, 0), f["s"], HORIZONTAL_ALIGNMENT_CENTER, 160, f["size"], Color(c.r, c.g, c.b, a))
			"bolt":
				var c: Color = f["col"]
				draw_polyline(f["pts"], Color(c.r, c.g, c.b, 1.0 - k), 3.0, true)
				draw_polyline(f["pts"], Color(1, 1, 1, (1.0 - k) * 0.8), 1.0, true)
			"sparks":
				var c: Color = f["col"]
				for d in f["dirs"]:
					draw_circle(f["pos"] + d * k + Vector2(0, 40 * k * k), 3.0 * (1.0 - k) + 0.5, Color(c.r, c.g, c.b, 1.0 - k))
			"banner":
				var a := minf(1.0, minf(k * 6.0, (1.0 - k) * 4.0))
				var c: Color = f["col"]
				var p: Vector2 = f["pos"]
				draw_rect(Rect2(p.x - 260, p.y - 34, 520, 64), Color(0.05, 0.06, 0.09, 0.85 * a))
				draw_rect(Rect2(p.x - 260, p.y - 34, 520, 3), Color(c.r, c.g, c.b, a))
				draw_string(font, p + Vector2(-260, -4), f["title"], HORIZONTAL_ALIGNMENT_CENTER, 520, 26, Color(c.r, c.g, c.b, a))
				draw_string(font, p + Vector2(-260, 20), f["sub"], HORIZONTAL_ALIGNMENT_CENTER, 520, 14, Color(0.9, 0.9, 0.9, a))
