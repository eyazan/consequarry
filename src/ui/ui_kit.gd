class_name UIKit
extends RefCounted
## Theme and small widget helpers so UI code stays declarative.


static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 15
	var panel := StyleBoxFlat.new()
	panel.bg_color = Palette.PANEL
	panel.border_color = Color(1, 1, 1, 0.07)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(10)
	panel.set_content_margin_all(12)
	th.set_stylebox("panel", "PanelContainer", panel)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(7)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 7
		sb.content_margin_bottom = 7
		match state:
			"normal": sb.bg_color = Palette.PANEL_LIGHT
			"hover": sb.bg_color = Palette.PANEL_LIGHT.lightened(0.15)
			"pressed": sb.bg_color = Palette.ACCENT.darkened(0.3)
			"disabled": sb.bg_color = Color(0.15, 0.16, 0.2, 0.8)
			"focus":
				sb.bg_color = Color(0, 0, 0, 0)
				sb.border_color = Palette.ACCENT
				sb.set_border_width_all(2)
		th.set_stylebox(state, "Button", sb)
	th.set_color("font_color", "Button", Palette.TEXT)
	th.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.55))
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_color", "Label", Palette.TEXT)
	th.set_color("default_color", "RichTextLabel", Palette.TEXT)
	var tip := StyleBoxFlat.new()
	tip.bg_color = Color(0.05, 0.06, 0.09, 0.96)
	tip.set_corner_radius_all(6)
	tip.set_content_margin_all(8)
	th.set_stylebox("panel", "TooltipPanel", tip)
	var line := StyleBoxFlat.new()
	line.bg_color = Palette.PANEL_LIGHT
	line.set_corner_radius_all(6)
	line.set_content_margin_all(8)
	th.set_stylebox("normal", "LineEdit", line)
	return th


static func label(text: String, size: int = 15, color: Color = Palette.TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func rich(bbcode: String, size: int = 14) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = Loc.t(bbcode)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


static func button(text: String, cb: Callable, tooltip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tooltip
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_ALL
	return b


## Controls parented to a CanvasLayer do not inherit a size; keep them viewport-sized.
static func fill_viewport(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vp := c.get_viewport()
	var fit := func():
		c.position = Vector2.ZERO
		c.size = vp.get_visible_rect().size
	fit.call()
	vp.size_changed.connect(fit)


static func hex(c: Color) -> String:
	return c.to_html(false)


static func clear(node: Node) -> void:
	for ch in node.get_children():
		node.remove_child(ch)
		ch.queue_free()
