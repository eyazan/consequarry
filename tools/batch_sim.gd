extends SceneTree
## Headless batch simulation for balancing.
## Usage: godot --headless --script res://tools/batch_sim.gd -- [runs_per_strategy] [expert_runs] [seed_base]
## Writes reports/simulation_results.json and reports/balance_metrics.csv.
## NOTE: bots approximate play styles; results are NOT human engagement evidence.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 1500
	var expert_runs := int(args[1]) if args.size() > 1 else 300
	var seed_base := int(args[2]) if args.size() > 2 else 10000
	var t0 := Time.get_ticks_msec()
	var results := {}
	var per_seed_outcomes := {}  # seed -> {strategy: outcome}
	var invariant_failures: Array = []
	var peak_mem := 0
	for strategy in BotStrategies.NAMES:
		var n := expert_runs if strategy == "expert" else runs
		var agg := _new_agg()
		var st := Time.get_ticks_usec()
		for k in n:
			var run_seed := seed_base + k
			var r := _run_one(strategy, run_seed)
			_accumulate(agg, r)
			if not r["errors"].is_empty():
				invariant_failures.append({"strategy": strategy, "seed": run_seed, "errors": r["errors"]})
			if not per_seed_outcomes.has(run_seed):
				per_seed_outcomes[run_seed] = {}
			per_seed_outcomes[run_seed][strategy] = r["outcome"]
			peak_mem = maxi(peak_mem, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
		agg["runs"] = n
		agg["avg_ms_per_run"] = snappedf((Time.get_ticks_usec() - st) / 1000.0 / n, 0.01)
		results[strategy] = _finalize_agg(agg)
		print("%-17s runs=%5d win=%5.1f%%  avgH=%5.1f  turns=%4.1f  ms/run=%.2f" % [strategy, n,
			results[strategy]["win_rate"] * 100.0, results[strategy]["avg_final_avg_health"],
			results[strategy]["avg_turns"], agg["avg_ms_per_run"]])
	# Determinism re-check on a sample.
	var det_fail := 0
	for k in 50:
		var a := _run_one("balanced", seed_base + k)
		var b := _run_one("balanced", seed_base + k)
		if a["hash"] != b["hash"]:
			det_fail += 1
	# Unavoidable-defeat probe: seeds where every strategy lost (within expert sample).
	var all_lost := 0
	var expert_only_wins := 0
	for s in per_seed_outcomes:
		var outs: Dictionary = per_seed_outcomes[s]
		if outs.has("expert"):
			var any_win := false
			for v in outs.values():
				if v == "victory":
					any_win = true
			if not any_win:
				all_lost += 1
			if outs["expert"] == "victory" and outs.get("passive", "") != "victory":
				expert_only_wins += 1
	var dominant: Array = []
	for strategy in results:
		if strategy != "expert" and results[strategy]["win_rate"] > 0.85:
			dominant.append(strategy)
	var total_runs := 0
	for strategy in results:
		total_runs += int(results[strategy]["runs"])
	var summary := {
		"generated_at": Time.get_datetime_string_from_system(true),
		"engine": Engine.get_version_info()["string"],
		"seed_base": seed_base, "total_runs": total_runs,
		"elapsed_s": snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.1),
		"peak_static_memory_mb": snappedf(peak_mem / 1048576.0, 0.1),
		"invariant_failure_runs": invariant_failures.size(),
		"invariant_failure_samples": invariant_failures.slice(0, 10),
		"determinism_recheck_failures": det_fail,
		"seeds_lost_by_all_strategies_in_expert_sample": all_lost,
		"expert_sample_size": expert_runs,
		"expert_wins_where_passive_lost": expert_only_wins,
		"dominant_strategy_flags": dominant,
		"strategies": results,
		"disclaimer": "Automated bot results. Not evidence of human engagement or fun.",
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
	var f := FileAccess.open("res://reports/simulation_results.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(summary, "  ", false))
	f.close()
	_write_csv(results)
	preload("res://tools/report_writer.gd").write_md(summary)
	print("total_runs=%d invariant_failures=%d determinism_failures=%d all_lost=%d dominant=%s elapsed=%.1fs mem=%.1fMB" % [
		total_runs, invariant_failures.size(), det_fail, all_lost, str(dominant), summary["elapsed_s"], summary["peak_static_memory_mb"]])
	quit(0 if invariant_failures.is_empty() and det_fail == 0 else 1)


func _run_one(strategy: String, run_seed: int) -> Dictionary:
	var w := SimulationEngine.new_run("p0_valley", run_seed)
	var rng := DetRng.new(run_seed * 7 + 1)
	var errors: Array = []
	var guard := 0
	while not w.is_over() and guard < 40:
		guard += 1
		BotStrategies.play_turn(w, strategy, rng)
		SimulationEngine.end_turn(w)
		for sys: CivilizationSystem in w.systems.values():
			if sys.health < 0 or sys.health > sys.max_health:
				errors.append("health bounds %s" % sys.id)
	if not w.is_over():
		errors.append("did not terminate")
	errors.append_array(w.ledger.verify())
	var kinds := {"redirect": 0, "split": 0, "delay": 0, "transform": 0, "crisis": 0}
	for a in w.actions_log:
		kinds[a["kind"]] += 1
	var collapsed := []
	for sys: CivilizationSystem in w.systems.values():
		if sys.collapsed:
			collapsed.append(sys.id)
	var reason_key: String = "victory"
	if w.outcome == "defeat":
		if w.outcome_reason.begins_with("Survived"):
			reason_key = "unsustainable"
		elif w.outcome_reason.begins_with("Instability"):
			reason_key = "instability"
		elif w.outcome_reason.contains("Without people"):
			reason_key = "population_collapse"
		else:
			reason_key = "multi_collapse"
	return {"outcome": w.outcome, "reason": reason_key, "turns": w.history.size(),
		"avg_health": w.average_health(), "min_health": w.min_health(), "instability": w.instability,
		"reserve": w.reserve, "kinds": kinds, "collapsed": collapsed, "errors": errors,
		"hash": w.state_hash(), "consequences": w.ledger.items.size(),
		"memory_entries": w.memory.chronicle.size()}


func _new_agg() -> Dictionary:
	return {"wins": 0, "n": 0, "sum_avg_health": 0, "sum_min_health": 0, "sum_turns": 0,
		"sum_instability": 0, "reasons": {}, "kinds": {"redirect": 0, "split": 0, "delay": 0, "transform": 0, "crisis": 0},
		"collapse_by_system": {}, "sum_consequences": 0, "sum_memory": 0, "turn_hist": {}}


func _accumulate(agg: Dictionary, r: Dictionary) -> void:
	agg["n"] += 1
	if r["outcome"] == "victory":
		agg["wins"] += 1
	agg["sum_avg_health"] += r["avg_health"]
	agg["sum_min_health"] += r["min_health"]
	agg["sum_turns"] += r["turns"]
	agg["sum_instability"] += r["instability"]
	agg["sum_consequences"] += r["consequences"]
	agg["sum_memory"] += r["memory_entries"]
	agg["reasons"][r["reason"]] = int(agg["reasons"].get(r["reason"], 0)) + 1
	agg["turn_hist"][str(r["turns"])] = int(agg["turn_hist"].get(str(r["turns"]), 0)) + 1
	for k in r["kinds"]:
		agg["kinds"][k] += r["kinds"][k]
	for s in r["collapsed"]:
		agg["collapse_by_system"][s] = int(agg["collapse_by_system"].get(s, 0)) + 1


func _finalize_agg(agg: Dictionary) -> Dictionary:
	var n := float(agg["n"])
	var kinds_avg := {}
	for k in agg["kinds"]:
		kinds_avg[k] = snappedf(agg["kinds"][k] / n, 0.01)
	return {"runs": agg["n"], "win_rate": snappedf(agg["wins"] / n, 0.0001),
		"avg_final_avg_health": snappedf(agg["sum_avg_health"] / n, 0.1),
		"avg_final_min_health": snappedf(agg["sum_min_health"] / n, 0.1),
		"avg_turns": snappedf(agg["sum_turns"] / n, 0.01),
		"avg_final_instability": snappedf(agg["sum_instability"] / n, 0.1),
		"avg_consequences_per_run": snappedf(agg["sum_consequences"] / n, 0.1),
		"avg_memory_entries": snappedf(agg["sum_memory"] / n, 0.1),
		"outcome_reasons": agg["reasons"], "actions_per_run": kinds_avg,
		"collapses_by_system": agg["collapse_by_system"], "turns_survived_histogram": agg["turn_hist"],
		"avg_ms_per_run": agg.get("avg_ms_per_run", 0.0)}


func _write_csv(results: Dictionary) -> void:
	var f := FileAccess.open("res://reports/balance_metrics.csv", FileAccess.WRITE)
	f.store_line("strategy,runs,win_rate,avg_final_avg_health,avg_final_min_health,avg_turns,avg_final_instability,redirect,split,delay,transform,crisis,unsustainable,multi_collapse,population_collapse,instability_loss,avg_ms_per_run")
	for s in results:
		var r: Dictionary = results[s]
		var a: Dictionary = r["actions_per_run"]
		var o: Dictionary = r["outcome_reasons"]
		f.store_line("%s,%d,%.4f,%.1f,%.1f,%.2f,%.1f,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%d,%d,%d,%.2f" % [s, r["runs"], r["win_rate"],
			r["avg_final_avg_health"], r["avg_final_min_health"], r["avg_turns"], r["avg_final_instability"],
			a["redirect"], a["split"], a["delay"], a["transform"], a["crisis"],
			int(o.get("unsustainable", 0)), int(o.get("multi_collapse", 0)), int(o.get("population_collapse", 0)),
			int(o.get("instability", 0)), r["avg_ms_per_run"]])
	f.close()

