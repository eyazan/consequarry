extends RefCounted
## Writes reports/balance_summary.md from a batch summary dictionary.
static func write_md(summary: Dictionary) -> void:
	var f := FileAccess.open("res://reports/balance_summary.md", FileAccess.WRITE)
	f.store_line("# Balance Summary (auto-generated)\n")
	f.store_line("Generated %s with Godot %s. %d runs in %.1f s. **Bot results are not human engagement evidence.**\n" % [summary["generated_at"], summary["engine"], summary["total_runs"], summary["elapsed_s"]])
	f.store_line("| Strategy | Runs | Win % | Avg final avg health | Avg final min health | Main loss reason | ms/run |")
	f.store_line("|---|---|---|---|---|---|---|")
	for s in summary["strategies"]:
		var r: Dictionary = summary["strategies"][s]
		var worst := ""
		var worst_n := -1
		for k in r["outcome_reasons"]:
			if k != "victory" and int(r["outcome_reasons"][k]) > worst_n:
				worst_n = int(r["outcome_reasons"][k])
				worst = k
		f.store_line("| %s | %d | %.1f | %.1f | %.1f | %s | %.2f |" % [s, r["runs"], r["win_rate"] * 100.0, r["avg_final_avg_health"], r["avg_final_min_health"], worst, r["avg_ms_per_run"]])
	f.store_line("\n- Invariant-failure runs: %d" % summary["invariant_failure_runs"])
	f.store_line("- Determinism re-check failures: %d / 50" % summary["determinism_recheck_failures"])
	f.store_line("- Seeds lost by every strategy (expert sample of %d): %d" % [summary["expert_sample_size"], summary["seeds_lost_by_all_strategies_in_expert_sample"]])
	f.store_line("- Dominant-strategy flags (>85%% win): %s" % str(summary["dominant_strategy_flags"]))
	f.store_line("- Peak static memory: %.1f MB" % summary["peak_static_memory_mb"])
	f.close()
