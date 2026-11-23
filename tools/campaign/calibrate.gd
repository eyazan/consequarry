extends SceneTree
## Tunes every campaign level with bots:
##  1. binary-searches the level's magnitude_percent so the good bot wins about
##     target(d) = 98% (first level) .. 78% (last level);
##  2. sets 2★/3★ average-health bars from the good bot's winning runs.
## Writes data/campaign_stars.json (merged by generate_levels.py) and
## reports/campaign_calibration.md.
## Usage: godot --headless --script res://tools/campaign/calibrate.gd -- [seeds] [search_seeds]
## Bot results are not human evidence; this only keeps levels winnable and ordered.

const GOOD := "recovery_focused"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 100
	var ns := int(args[1]) if args.size() > 1 else 50
	var levels := Campaign.levels()
	var out := {}
	var md := ["# Campaign calibration (auto-generated)\n",
		"Search: %d seeds per step; final measurement: %d seeds. Bots are not human evidence.\n" % [ns, n],
		"| # | Name | Systems | Magnitude % | Target good-win % | Good-bot win % | Random win % | 2★ / 3★ avg bars |", "|---|---|---|---|---|---|---|---|"]
	for idx in levels.size():
		var lv: Dictionary = levels[idx]
		var id := String(lv["id"])
		var d := float(idx) / float(maxi(1, levels.size() - 1))
		var target := 98.0 - 20.0 * d
		var target_random := maxf(5.0, 80.0 - 100.0 * d)
		var lo := 30
		var hi := 220
		var best_mag := int(lv["magnitude_percent"])
		var verify := args.has("verify")
		for _step in (0 if verify else 7):
			var mid := (lo + hi) / 2
			lv["magnitude_percent"] = mid
			var rate := 100.0 * int(_play(id, GOOD, ns, 70000)["wins"]) / ns
			var rrate := 100.0 * int(_play(id, "random", ns, 71000)["wins"]) / ns
			if rate >= target and rrate >= target_random:
				best_mag = mid
				lo = mid + 1
			else:
				hi = mid - 1
		lv["magnitude_percent"] = best_mag
		var good := _play(id, GOOD, n, 50000)
		var rnd := _play(id, "random", n, 50000)
		var avgs: Array = good["victory_avgs"]
		avgs.sort()
		var p25 := int(avgs[int(avgs.size() * 0.25)]) if not avgs.is_empty() else 50
		var p60 := int(avgs[int(avgs.size() * 0.60)]) if not avgs.is_empty() else 60
		var three := maxi(p60, p25 + 3)
		var good_rate := 100.0 * int(good["wins"]) / n
		var rnd_rate := 100.0 * int(rnd["wins"]) / n
		out[id] = {"min_health": int(lv["win"]["min_health"]), "two": p25, "three": three, "magnitude_percent": best_mag}
		md.append("| %d | %s | %d | %d | %.0f | %.0f | %.0f | %d / %d |" % [idx + 1, lv["name"], lv["systems"].size(), best_mag, target, good_rate, rnd_rate, p25, three])
		print("%s %-14s mag=%3d target=%4.0f good=%5.1f%% random=%5.1f%% stars=%d/%d" % [id, lv["name"], best_mag, target, good_rate, rnd_rate, p25, three])
	if not args.has("verify"):
		var f := FileAccess.open("res://data/campaign_stars.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(out, " ", true))
		f.close()
	if args.has("verify"):
		md.insert(1, "Verification pass (no search): measured with the shipped data/campaign.json.\n")
	var g := FileAccess.open("res://reports/campaign_calibration.md", FileAccess.WRITE)
	g.store_string("\n".join(md) + "\n")
	g.close()
	quit()


func _play(level_id: String, strategy: String, n: int, seed_base: int) -> Dictionary:
	var wins := 0
	var avgs: Array = []
	for k in n:
		var w := SimulationEngine.new_run(level_id, seed_base + k)
		var rng := DetRng.new(k * 13 + 7)
		var guard := 0
		while not w.is_over() and guard < 20:
			guard += 1
			BotStrategies.play_turn(w, strategy, rng)
			SimulationEngine.end_turn(w)
		if w.outcome == "victory":
			wins += 1
			avgs.append(w.average_health())
	return {"wins": wins, "victory_avgs": avgs}
