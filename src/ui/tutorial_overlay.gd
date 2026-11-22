class_name TutorialOverlay
extends Control
## Interactive tutorial. Steps advance on player actions (not just "Next"),
## so the signature mechanic is performed by the player within the first minute.

signal finished

const STEPS := [
	{"text": "[b]You don't build this valley.[/b] Its people do.\nYou decide where the [color=#ffb347]consequences[/color] of what they do end up.", "wait": "next"},
	{"text": "A refinery line just ruptured. The glowing orbs are its consequences. [b]They cannot vanish[/b] — only be moved, split, delayed or transformed.\n\n[color=#ffb347]Click the orange Heat orb above Industry.[/color]", "wait": "select_heat"},
	{"text": "Heat would hurt Industry. [b]Energy barely minds heat[/b] (see its vulnerability).\n\n[color=#ffb347]Press Redirect, then click the glowing Energy district.[/color]", "wait": "redirect_energy"},
	{"text": "Notice the small orb left at Industry: [b]20% always leaks[/b]. Rerouting is never clean.\n\n[color=#ffb347]Now select the Heat at Energy and press Transform: Thermal Capture.[/color]", "wait": "transform"},
	{"text": "Heat became green [b]Surplus[/b] (it heals Energy) — but exhaust [color=#9a7bd6]Pollution[/color] now heads to Environment. Every gain has a residue.\n\n[color=#ffb347]Press END SEASON (Space) and watch where everything lands.[/color]", "wait": "end_turn"},
	{"text": "Pipes are [b]causal links[/b]: healthy systems support neighbours, failing ones drag them down next season (numbers on the pipes). The left panel forecasts next season's event.", "wait": "next"},
	{"text": "[b]Win:[/b] after 12 seasons, average health ≥ 55 and every system ≥ 25.\n[b]Lose:[/b] Population collapses, two systems collapse, or instability reaches 100.\nClick a district to see its weaknesses and its [b]Controlled Crisis[/b] — powerful, but the valley remembers.", "wait": "next"},
]

var step := 0
var panel: PanelContainer
var text: RichTextLabel
var next_btn: Button


func _ready() -> void:
	UIKit.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = PanelContainer.new()
	panel.position = Vector2(10, 282)
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
	text = UIKit.rich("", 13)
	text.custom_minimum_size = Vector2(222, 0)
	vb.add_child(text)
	next_btn = UIKit.button("Next ▶", _advance)
	next_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	vb.add_child(next_btn)
	_show()


func _show() -> void:
	var s: Dictionary = STEPS[step]
	text.text = "[color=#ffb347]%d/%d[/color]  %s" % [step + 1, STEPS.size(), s["text"]]
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


## Called by GameView on player actions.
func notify(event: String, data: Dictionary = {}) -> void:
	var wait: String = STEPS[step]["wait"]
	var ok := false
	match wait:
		"select_heat": ok = event == "select" and data.get("type", "") == "heat"
		"redirect_energy": ok = event == "redirect" and data.get("target", "") == "energy"
		"transform": ok = event == "transform"
		"end_turn": ok = event == "end_turn_done"
	if ok:
		_advance()


func current_wait() -> String:
	return STEPS[step]["wait"]
