extends SceneTree
## Headless unit/integration test runner.
## Usage: godot --headless --script res://tests/run_tests.gd
## Exit code 0 = all passed, 1 = failures.

var passed := 0
var failed := 0
var failures: Array[String] = []
var current := ""


func _init() -> void:
	var tests := [
		"test_rng_determinism", "test_new_run_deterministic", "test_full_run_determinism",
		"test_conservation_random_play", "test_bounds_and_nan", "test_save_load_roundtrip",
		"test_redirect", "test_split_conserves", "test_delay_strain", "test_transform",
		"test_transform_capacity", "test_crisis_escalation", "test_memory_adaptation",
		"test_memory_dependency", "test_memory_familiarity", "test_runs_terminate",
		"test_spill_depth_bounded", "test_tutorial_script", "test_no_crisis_fallout_past_end",
		"test_collapsed_target_rejected", "test_save_system_file", "test_seed_code", "test_preview_matches_resolution", "test_scenarios", "test_daily_and_score", "test_localization", "test_music", "test_campaign",
	]
	for t in tests:
		current = t
		var before := failed
		call(t)
		print(("PASS  " if failed == before else "FAIL  ") + t)
		if failed == before:
			passed += 1
	print("\n%d passed, %d failed" % [passed, failed])
	for f in failures:
		print("  - " + f)
	quit(0 if failed == 0 else 1)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failed += 1
		failures.append("%s: %s" % [current, msg])


func _play_random(w: WorldState, rng: DetRng, verify_each: bool = false) -> void:
	while not w.is_over():
		BotStrategies.play_turn(w, "random", rng)
		if verify_each:
			var errs := w.ledger.verify()
			check(errs.is_empty(), "ledger after actions: %s" % str(errs))
		SimulationEngine.end_turn(w)
		if verify_each:
			var errs2 := w.ledger.verify()
			check(errs2.is_empty(), "ledger after turn: %s" % str(errs2))


func _first_pending(w: WorldState, type: String = "", dest: String = "") -> Consequence:
	for c in w.ledger.pending():
		if c.land_turn == w.turn and (type == "" or c.type == type) and (dest == "" or c.destination == dest):
			return c
	return null


# ------------------------------------------------------------------ tests

func test_rng_determinism() -> void:
	var a := DetRng.new(42)
	var b := DetRng.new(42)
	for i in 1000:
		check(a.next_u32() == b.next_u32(), "diverged at %d" % i)
	var c := DetRng.new(43)
	check(DetRng.new(42).next_u32() != c.next_u32(), "different seeds same output")


func test_new_run_deterministic() -> void:
	var w1 := SimulationEngine.new_run("p0_valley", 1234)
	var w2 := SimulationEngine.new_run("p0_valley", 1234)
	check(w1.state_hash() == w2.state_hash(), "same seed different initial state")
	var w3 := SimulationEngine.new_run("p0_valley", 1235)
	check(w1.state_hash() != w3.state_hash(), "different seeds identical state")


func test_full_run_determinism() -> void:
	for s in [1, 77, 9001]:
		var w1 := SimulationEngine.new_run("p0_valley", s)
		var w2 := SimulationEngine.new_run("p0_valley", s)
		_play_random(w1, DetRng.new(s * 3))
		_play_random(w2, DetRng.new(s * 3))
		check(w1.state_hash() == w2.state_hash(), "seed %d diverged" % s)


func test_conservation_random_play() -> void:
	for s in range(100, 130):
		var w := SimulationEngine.new_run("p0_valley", s)
		_play_random(w, DetRng.new(s), true)


func test_bounds_and_nan() -> void:
	for s in range(200, 260):
		var w := SimulationEngine.new_run("p0_valley", s)
		var rng := DetRng.new(s)
		while not w.is_over():
			BotStrategies.play_turn(w, "crisis_focused" if s % 2 == 0 else "random", rng)
			SimulationEngine.end_turn(w)
			for sys: CivilizationSystem in w.systems.values():
				check(sys.health >= 0 and sys.health <= sys.max_health, "health out of bounds %s=%d" % [sys.id, sys.health])
				check(sys.max_health > 0, "max health <= 0")
			check(w.instability >= 0 and w.instability <= 100, "instability out of bounds")
			check(w.reserve >= 0, "negative reserve")
			check(w.action_points >= 0, "negative AP")


func test_save_load_roundtrip() -> void:
	var w := SimulationEngine.new_run("p0_valley", 555)
	var rng := DetRng.new(9)
	for _i in 5:
		BotStrategies.play_turn(w, "random", rng)
		SimulationEngine.end_turn(w)
	var saved := JSON.stringify(w.to_dict())
	var restored := WorldState.from_dict(JSON.parse_string(saved))
	check(restored.state_hash() == w.state_hash(), "hash changed after roundtrip")
	var rng_a := DetRng.new(31)
	var rng_b := DetRng.new(31)
	while not w.is_over():
		BotStrategies.play_turn(w, "balanced", rng_a)
		SimulationEngine.end_turn(w)
	while not restored.is_over():
		BotStrategies.play_turn(restored, "balanced", rng_b)
		SimulationEngine.end_turn(restored)
	check(restored.state_hash() == w.state_hash(), "continuation diverged after load")


func test_redirect() -> void:
	var w := SimulationEngine.new_run("tutorial", 1)
	var heat := _first_pending(w, "heat", "industry")
	check(heat != null, "tutorial must start with heat at industry")
	if heat == null:
		return
	var err := SimulationEngine.apply(w, Intervention.redirect(heat.id, "energy"))
	check(err == "", "redirect failed: " + err)
	var moved := w.ledger.get_c(w.last_focus_id)
	check(moved != null and moved.destination == "energy", "destination not changed")
	check(heat.children.size() == 2, "redirect should leak part of the magnitude")
	check(w.ledger.verify().is_empty(), "ledger invalid after redirect")
	check(w.action_points == 2, "AP not spent")
	var bad := SimulationEngine.apply(w, Intervention.redirect(moved.id, "agriculture"))
	check(bad != "", "redirect to non-adjacent system should fail")


func test_split_conserves() -> void:
	var w := SimulationEngine.new_run("tutorial", 1)
	var heat := _first_pending(w, "heat")
	var m := heat.current_magnitude
	var err := SimulationEngine.apply(w, Intervention.split(heat.id, "energy"))
	check(err == "", "split failed: " + err)
	check(heat.children.size() == 2, "split should create 2 children")
	var total := 0
	for ch in heat.children:
		total += w.ledger.get_c(ch).original_magnitude
	check(total == m, "split leaked magnitude")
	check(w.ledger.verify().is_empty(), "ledger invalid after split")


func test_delay_strain() -> void:
	var w := SimulationEngine.new_run("tutorial", 1)
	var dmg := _first_pending(w, "damage")
	var before_total: int = w.ledger.totals()["created_roots"]
	var err := SimulationEngine.apply(w, Intervention.delay(dmg.id))
	check(err == "", "delay failed: " + err)
	check(dmg.land_turn == 2, "not delayed")
	var after_total: int = w.ledger.totals()["created_roots"]
	check(after_total > before_total, "delay should create strain consequence")
	SimulationEngine.apply(w, Intervention.delay(dmg.id))
	# delays are only allowed for consequences arriving this turn, so second delay must fail
	check(dmg.land_turn == 2, "second delay in same turn should be rejected (not arriving this season)")


func test_transform() -> void:
	var w := SimulationEngine.new_run("tutorial", 1)
	var heat := _first_pending(w, "heat", "industry")
	var bad := SimulationEngine.apply(w, Intervention.transform(heat.id, "thermal_capture"))
	check(bad != "", "transform away from site should fail")
	SimulationEngine.apply(w, Intervention.redirect(heat.id, "energy"))
	var moved := w.ledger.get_c(w.last_focus_id)
	var err := SimulationEngine.apply(w, Intervention.transform(moved.id, "thermal_capture"))
	check(err == "", "transform failed: " + err)
	var types: Array = []
	for ch in moved.children:
		types.append(w.ledger.get_c(ch).type)
	check(types.has("surplus") and types.has("pollution"), "transform should yield surplus + residue")
	check(w.ledger.verify().is_empty(), "ledger invalid after transform")


func test_transform_capacity() -> void:
	var w := SimulationEngine.new_run("tutorial", 1)
	var c := w.ledger.create("heat", "test", 30, "energy", w.turn, w.turn)
	var err := SimulationEngine.apply(w, Intervention.transform(c.id, "thermal_capture"))
	check(err != "", "transform above capacity should fail")


func test_crisis_escalation() -> void:
	var w := SimulationEngine.new_run("p0_valley", 3)
	w.action_points = 20
	var c1 := SimulationEngine.cost_of(w, Intervention.crisis("energy"))
	check(SimulationEngine.apply(w, Intervention.crisis("energy")) == "", "first crisis failed")
	var c2 := SimulationEngine.cost_of(w, Intervention.crisis("industry"))
	check(c2 > c1, "crisis cost should escalate")
	check(SimulationEngine.apply(w, Intervention.crisis("energy")) != "", "cooldown not enforced")
	check(w.instability > 0, "crisis should raise instability")


func test_memory_adaptation() -> void:
	var w := SimulationEngine.new_run("tutorial", 1)
	check(w.memory.adaptation("thermal_capture") == 0, "fresh adaptation")
	var heat := _first_pending(w, "heat", "industry")
	SimulationEngine.apply(w, Intervention.redirect(heat.id, "energy"))
	SimulationEngine.apply(w, Intervention.transform(w.last_focus_id, "thermal_capture"))
	check(w.memory.adaptation("thermal_capture") > 0, "adaptation should grow")


func test_memory_dependency() -> void:
	var w := SimulationEngine.new_run("p0_valley", 4)
	var cap_before := w.system("energy").capacity(w.memory)
	w.memory.redirects_in["energy"] = 6
	check(w.system("energy").capacity(w.memory) < cap_before, "dependency should reduce capacity")


func test_memory_familiarity() -> void:
	var w := SimulationEngine.new_run("p0_valley", 5)
	var m1 := EventDirector.scaled_magnitude(w, "flood", 20)
	w.memory.events_seen["flood"] = 3
	var m2 := EventDirector.scaled_magnitude(w, "flood", 20)
	check(m2 < m1, "familiar events should be weaker")


func test_runs_terminate() -> void:
	for s in range(300, 340):
		var w := SimulationEngine.new_run("p0_valley", s)
		var turns := 0
		while not w.is_over() and turns < 50:
			SimulationEngine.end_turn(w)
			turns += 1
		check(w.is_over(), "run did not terminate")
		check(turns <= 12, "run exceeded max turns")


func test_spill_depth_bounded() -> void:
	for s in range(400, 430):
		var w := SimulationEngine.new_run("p0_valley", s)
		_play_random(w, DetRng.new(s))
		for c: Consequence in w.ledger.items.values():
			if c.source.begins_with("spill:"):
				check(c.depth <= int(ContentDB.rules()["spill_max_depth"]) + 3, "spill depth unbounded")


func test_tutorial_script() -> void:
	var w := SimulationEngine.new_run("tutorial", 999)
	check(w.current_events == ["industrial_accident"], "tutorial turn 1 event")
	check(w.forecast == ["labor_strike"], "tutorial turn 2 forecast")


func test_no_crisis_fallout_past_end() -> void:
	var w := SimulationEngine.new_run("p0_valley", 6)
	w.turn = w.max_turns
	w.action_points = 10
	check(SimulationEngine.validate(w, Intervention.crisis("energy")) != "", "crisis with fallout after end must be blocked")


func test_collapsed_target_rejected() -> void:
	var w := SimulationEngine.new_run("tutorial", 1)
	w.system("energy").health = 0
	w.system("energy").collapsed = true
	var heat := _first_pending(w, "heat", "industry")
	check(SimulationEngine.validate(w, Intervention.redirect(heat.id, "energy")) != "", "redirect into collapsed")


func test_save_system_file() -> void:
	var w := SimulationEngine.new_run("p0_valley", 77)
	var path := "user://test_save.json"
	check(SaveSystem.save_world(w, path), "save failed")
	var loaded := SaveSystem.load_world(path)
	check(loaded != null and loaded.state_hash() == w.state_hash(), "file roundtrip mismatch")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(SaveSystem.load_world("user://does_not_exist.json") == null, "missing file must return null")


func test_seed_code() -> void:
	for v in [0, 1, 12345, 2147483647, 99999999]:
		check(SeedCode.decode(SeedCode.encode(v)) == v, "seed code roundtrip %d" % v)
	check(SeedCode.decode("nonsense") == -1, "invalid code accepted")


func test_preview_matches_resolution() -> void:
	# For every consequence landing this turn, the exact preview must equal the resolution.
	for seed_v in range(500, 540):
		var w := SimulationEngine.new_run("p0_valley", seed_v)
		var previews := {}
		for c in w.ledger.pending_landing_on(w.turn):
			if not ContentDB.is_positive(c.type):
				previews[c.id] = SimulationEngine.preview_landing(w, c.type, c.current_magnitude, c.destination, c.id)
		var health_before := {}
		for id in w.systems:
			health_before[id] = w.system(id).health
		var report := SimulationEngine.end_turn(w)
		var seen_dest := {}
		for l in report["landings"]:
			# Only the first landing per system is independent of earlier health clamping.
			if previews.has(l["id"]) and not seen_dest.has(l["to"]):
				check(l["delta"] == previews[l["id"]]["delta"], "seed %d C%d preview %d vs actual %d" % [seed_v, l["id"], previews[l["id"]]["delta"], l["delta"]])
				check(l["absorbed"] == previews[l["id"]]["absorbed"], "absorbed mismatch")
			seen_dest[l["to"]] = true


func test_scenarios() -> void:
	for sid in ["p0_valley", "dry_season", "boomtown"]:
		var a := SimulationEngine.new_run(sid, 4242)
		var b := SimulationEngine.new_run(sid, 4242)
		_play_random(a, DetRng.new(3), true)
		_play_random(b, DetRng.new(3))
		check(a.state_hash() == b.state_hash(), "%s not deterministic" % sid)
		check(a.is_over(), "%s did not finish" % sid)
	var d := SimulationEngine.new_run("dry_season", 1)
	check(absi(d.system("agriculture").health - 62) <= 4, "dry_season start health override not applied")
	var bt := SimulationEngine.new_run("boomtown", 1)
	check(absi(bt.system("industry").health - 84) <= 4, "boomtown start health override not applied")
	# Event weighting: heat-themed events dominate a dry season.
	var heat := 0
	var other := 0
	for k in 200:
		var w := SimulationEngine.new_run("dry_season", 1000 + k)
		for e in w.current_events:
			if e == "heatwave" or e == "wildfire":
				heat += 1
			else:
				other += 1
	check(heat * 3 > other, "dry season should favour heat events (%d vs %d)" % [heat, other])


func test_daily_and_score() -> void:
	var a := SeedCode.daily({"year": 2026, "month": 11, "day": 23})
	var b := SeedCode.daily({"year": 2026, "month": 11, "day": 23})
	var c := SeedCode.daily({"year": 2026, "month": 11, "day": 24})
	check(a == b, "daily not stable for a date")
	check(a["seed"] != c["seed"], "daily seed should change per day")
	check(a["scenario"] != c["scenario"], "daily scenario should rotate")
	check(ContentDB.scenario_def(a["scenario"]).size() > 0, "daily scenario exists")
	var w := SimulationEngine.new_run("p0_valley", 9)
	w.daily_date = "2026-11-23"
	var r := WorldState.from_dict(w.to_dict())
	check(r.daily_date == "2026-11-23", "daily date not saved")
	_play_random(w, DetRng.new(9))
	check(w.score() >= 0, "score negative")
	var v := w.clone()
	v.outcome = "victory"
	check(v.score() > w.score() or w.outcome == "victory", "victory must dominate score")


func test_localization() -> void:
	var before := TranslationServer.get_locale()
	TranslationServer.set_locale("tr")
	check(Loc.t("Energy") == "Enerji", "Turkish translation not loaded (got %s)" % Loc.t("Energy"))
	check(Loc.sys("population") == "Nüfus", "system name not translated")
	check(Loc.upper("Enerji") == "ENERJİ", "Turkish dotted capital I")
	# Engine messages translate with their arguments, including content names.
	var w := SimulationEngine.new_run("tutorial", 1)
	var heat := _first_pending(w, "heat", "industry")
	var m := SimulationEngine.validate_msg(w, Intervention.redirect(heat.id, "agriculture"))
	check(not m.is_empty(), "expected a validation message")
	check(Loc.m(m).contains("Sanayi"), "validation args not translated: %s" % Loc.m(m))
	check(Loc.source("event:flood|routed") == "Sel (yönlendirilmiş)", "routed source label: %s" % Loc.source("event:flood|routed"))
	# Every chronicle note and outcome of a full run renders without format errors.
	var r := SimulationEngine.new_run("p0_valley", 77)
	_play_random(r, DetRng.new(5))
	for e in r.memory.chronicle:
		check(Loc.note(e) != "", "empty translated note")
	check(Loc.outcome(r) != "", "empty translated outcome")
	TranslationServer.set_locale("en")
	check(Loc.t("Energy") == "Energy", "English fallback")
	TranslationServer.set_locale(before)


func test_music() -> void:
	var n := Music.total_samples()
	check(n > 22050 * 8 and n < 22050 * 30, "music loop length %d" % n)
	var peak := 0.0
	for i in range(0, n, 97):
		var v := Music.sample(i)
		check(not is_nan(v) and absf(v) <= 1.0, "sample out of range at %d" % i)
		peak = maxf(peak, absf(v))
	check(peak > 0.2, "music is silent (peak %.3f)" % peak)
	check(absf(Music.sample(n - 1) - Music.sample(0)) < 0.05, "loop seam would click")


func test_campaign() -> void:
	var levels := Campaign.levels()
	check(levels.size() == 30, "expected 30 levels, got %d" % levels.size())
	for lv in levels:
		var id := String(lv["id"])
		var w := SimulationEngine.new_run(id, 777)
		check(w.systems.size() == lv["systems"].size(), "%s: wrong district count" % id)
		for e in w.graph.edges:
			check(w.systems.has(e["from"]) and w.systems.has(e["to"]), "%s: edge to missing district" % id)
		for c in w.ledger.pending():
			check(w.systems.has(c.destination), "%s: trouble aimed at missing district" % id)
		_play_random(w, DetRng.new(5), true)
		check(w.is_over(), "%s did not finish" % id)
		var st := Campaign.stars(w)
		check(st >= 0 and st <= 3, "%s stars out of range" % id)
		check((st > 0) == (w.outcome == "victory"), "%s stars vs outcome" % id)
		var w2 := SimulationEngine.new_run(id, 777)
		_play_random(w2, DetRng.new(5))
		check(w.state_hash() == w2.state_hash(), "%s not deterministic" % id)
	# Moves unlock gradually.
	var l1 := SimulationEngine.new_run("lvl_01", 1)
	var heat := _first_pending(l1, "heat")
	check(heat != null, "lvl_01 should open with a heat trouble")
	if heat:
		check(SimulationEngine.validate(l1, Intervention.split(heat.id, "energy")) == "Not unlocked yet.", "split must be locked on level 1")
		check(SimulationEngine.validate(l1, Intervention.redirect(heat.id, "energy")) == "", "redirect allowed on level 1")
		SimulationEngine.apply(l1, Intervention.redirect(heat.id, "energy"))
		check(heat.children.is_empty() and heat.destination == "energy", "no leak on level 1")
	check(Campaign.next_level_id("lvl_01") == "lvl_02", "next level")
	check(Campaign.next_level_id("lvl_30") == "", "last level has no next")
