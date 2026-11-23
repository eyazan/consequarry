class_name TutorialOverlay
extends Control
## Interactive tutorial. Steps advance on player actions (not just "Next"),
## so the signature mechanic is performed by the player within the first minute.

signal finished

# Each step teaches one thing. "target" tells GameView what to point at.
const STEPS := [
	{"text": "[b]Welcome![/b] Troubles keep hitting this town: accidents, heat, pollution, unrest.\nYou can't stop them. [b]You choose where they land.[/b]", "wait": "next", "target": {}},
	{"text": "Each floating shape is a trouble falling on the district below it. The number is its size.\n\n[color=#ffb347]Tap the orange shape above Industry.[/color]", "wait": "select_heat", "target": {"kind": "orb", "type": "heat", "dest": "industry"}},
	{"text": "The panel shows what happens if you do nothing: Industry gets hurt.\n\n[color=#ffb347]Tap Redirect.[/color]", "wait": "redirect_mode", "target": {"kind": "action", "id": "redirect", "orb": {"type": "heat", "dest": "industry"}}},
	{"text": "Heat barely hurts Energy.\n\n[color=#ffb347]Tap the glowing Energy district.[/color]", "wait": "redirect_energy", "target": {"kind": "district", "id": "energy", "via": "redirect", "orb": {"type": "heat", "dest": "industry"}}},
	{"text": "Moved! A small piece always stays behind.\nEnergy can turn heat into power.\n\n[color=#ffb347]Tap Transform.[/color]", "wait": "transform", "target": {"kind": "action", "id": "transform", "orb": {"type": "heat", "dest": "energy"}}},
	{"text": "Heat became a [color=#62e3a8]green bonus[/color] that heals Energy. A little purple smoke goes to Environment. Every fix has a cost.\n\n[color=#ffb347]Tap END to finish the season.[/color]", "wait": "end_turn", "target": {"kind": "end"}},
	{"text": "[b]That's the whole game.[/b] Each season, tap the big dangerous shapes and send them where they hurt less. You have 3 moves per season.\n\n[b]Win:[/b] survive 12 seasons with every district above 25 health.\nNot sure what to do? Tap [b]Hint[/b].", "wait": "next", "target": {"kind": "hint"}},
]

var step := 0
var panel: PanelContainer
var text: RichTextLabel
var next_btn: Button


func _ready() -> void:
	UIKit.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = PanelContainer.new()
	panel.position = Vector2(10, 58) if GameSettings.compact else Vector2(10, 282)
	panel.custom_minimum_size = Vector2(250, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.09, 0.06, 0.95)
	sb.border_color = Palette.ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var head := HBoxContainer.new()
	var t := UIKit.label("TUTORIAL", 12, Palette.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.button("Skip", _finish))
	vb.add_child(head)
	text = UIKit.rich("", 11 if GameSettings.compact else 14)
	text.custom_minimum_size = Vector2(222, 0)
	vb.add_child(text)
	next_btn = UIKit.button("Next ▶", _advance)
	next_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	vb.add_child(next_btn)
	_show()


func _show() -> void:
	var s: Dictionary = STEPS[step]
	text.text = "[color=#ffb347]%d/%d[/color]  %s" % [step + 1, STEPS.size(), Loc.t(String(s["text"]))]
	next_btn.visible = s["wait"] == "next"
	next_btn.text = "Start playing ▶" if step == STEPS.size() - 1 else "Next ▶"


func _advance() -> void:
	step += 1
	if step >= STEPS.size():
		_finish()
	else:
		_show()


func _finish() -> void:
	GameSettings.tutorial_done = true
	GameSettings.save_settings()
	finished.emit()
	queue_free()


## Called by GameView on player actions. If the player performs a later step
## early, the tutorial fast-forwards instead of getting stuck.
func notify(event: String, data: Dictionary = {}) -> void:
	for j in range(step, STEPS.size()):
		if _matches(String(STEPS[j]["wait"]), event, data):
			step = j
			_advance()
			return


func _matches(wait: String, event: String, data: Dictionary) -> bool:
	match wait:
		"select_heat": return event == "select" and data.get("type", "") == "heat" and data.get("dest", "") == "industry"
		"redirect_mode": return event == "mode" and data.get("mode", "") == "redirect"
		"redirect_energy": return event == "redirect" and data.get("target", "") == "energy"
		"transform": return event == "transform"
		"end_turn": return event == "end_turn_done"
	return false


func current_wait() -> String:
	return STEPS[step]["wait"]


## What the on-screen pointer should show for the current step.
func target() -> Dictionary:
	return STEPS[step].get("target", {})
