class_name GlyphIcon
extends Control
## Draws a consequence-type glyph inside UI layouts.

var type_id := "damage"
var r := 7.0


static func make(t: String, size: float = 18.0) -> GlyphIcon:
	var g := GlyphIcon.new()
	g.type_id = t
	g.r = size * 0.36
	g.custom_minimum_size = Vector2(size, size)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


func _draw() -> void:
	Palette.draw_glyph(self, size * 0.5, type_id, r, 1.0, true)
