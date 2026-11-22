extends SceneTree
## Probes "unwinnable" seeds (known issue K-11).
## 1) Runs the 8 heuristic bots on a seed range and lists seeds none of them win.
## 2) Replays those seeds with a rollout planner: each season it tries several
##    candidate plans (heuristic + random), simulates each to the END of the run
##    with a fixed policy, and keeps the best. If even this loses, the seed is a
##    strong candidate for an unavoidable defeat.
## Usage: godot --headless --script res://tools/seed_probe.gd -- <seed_base> <count> <random_plans>

const HEURISTICS := ["conservative", "recovery_focused", "balanced", "crisis_focused", "aggressive", "greedy"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var base := int(args[0]) if args.size() > 0 else 10000
	var count := int(args[1]) if args.size() > 1 else 300
	var n_random := int(args[2]) if args.size() > 2 else 12
	var all_lost: Array = []
	for k in count:
		var s := base + k
		var won := false
		for strat in BotStrategies.NAMES:
			if strat == "expert":
				continue
			var w := SimulationEngine.new_run("p0_valley", s)
			var rng := DetRng.new(s * 7 + 1)
			while not w.is_over():
				BotStrategies.play_turn(w, strat, rng)
				SimulationEngine.end_turn(w)
			if w.outcome == "victory":
				won = true
				break
		if not won:
			all_lost.append(s)
	print("seeds lost by all heuristic bots: %d / %d" % [all_lost.size(), count])
	var rescued := 0
	var still_lost: Array = []
	var details: Array = []
	for s in all_lost:
		var r := _planner_run(s, n_random)
		details.append({"seed": s, "outcome": r["outcome"], "avg": r["avg"], "min": r["min"], "reason": r["reason"]})
		if r["outcome"] == "victory":
			rescued += 1
		else:
			still_lost.append(s)
		print("  seed %d -> %s (avg %d, min %d) %s" % [s, r["outcome"], r["avg"], r["min"], r["reason"]])
	print("planner rescued %d / %d; still lost: %s" % [rescued, all_lost.size(), str(still_lost)])
	var f := FileAccess.open("res://reports/seed_probe.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"seed_base": base, "count": count, "random_plans": n_random,
		"lost_by_all_heuristics": all_lost, "planner_rescued": rescued, "still_lost": still_lost, "details": details}, "  "))
	f.close()
	quit()


func _planner_run(s: int, n_random: int) -> Dictionary:
	var w := SimulationEngine.new_run("p0_valley", s)
	var rng := DetRng.new(s * 31 + 5)
	while not w.is_over():
		var best: WorldState = null
		var best_score: int = -1000000000
		var candidates: Array = []
		for h in HEURISTICS:
			candidates.append(h)
		for _i in n_random:
			candidates.append("random")
		candidates.append("passive")
		for strat in candidates:
			var c := w.clone()
			BotStrategies.play_turn(c, strat, rng)
			for policy in ["conservative", "recovery_focused"]:
				var sc: int = _rollout(c, String(policy), rng)
				if sc > best_score:
					best_score = sc
					best = c
		w = best
		SimulationEngine.end_turn(w)
	return {"outcome": w.outcome, "avg": w.average_health(), "min": w.min_health(), "reason": w.outcome_reason}


func _rollout(start: WorldState, policy: String, rng: DetRng) -> int:
	var r := start.clone()
	SimulationEngine.end_turn(r)
	while not r.is_over():
		BotStrategies.play_turn(r, policy, rng)
		SimulationEngine.end_turn(r)
	var score := r.average_health() * 10 + r.min_health() * 20 - r.collapsed_count() * 500 - r.instability * 2
	if r.outcome == "victory":
		score += 100000
	return score
