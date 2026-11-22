extends SceneTree
## Regenerates reports/balance_summary.md from reports/simulation_results.json.
## Usage: godot --headless --script res://tools/summarize_report.gd


func _init() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://reports/simulation_results.json"))
	if d is Dictionary:
		preload("res://tools/report_writer.gd").write_md(d)
		print("wrote reports/balance_summary.md")
	quit()
