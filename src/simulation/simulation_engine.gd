class_name SimulationEngine
extends RefCounted
## Deterministic rules engine. Stateless: every function takes a WorldState.
## Resolution order per turn (docs/design/FORMULAS.md):
##   begin_turn: refresh AP/capacity -> spawn this turn's events -> roll forecast
##   player interventions (validated, applied immediately, logged)
##   end_turn:   land consequences (id order) -> apply queued causal effects ->
##               queue new causal effects -> regen -> scars -> cascades ->
##               instability decay -> evaluate -> next turn


static func _r(key: String) -> int:
	return int(ContentDB.rules()[key])


# ---------------------------------------------------------------- run setup

static func new_run(scenario_id: String, run_seed: int) -> WorldState:
	var sc := ContentDB.scenario_def(scenario_id)
	assert(not sc.is_empty(), "unknown scenario " + scenario_id)
	var w := WorldState.new()
	w.scenario_id = scenario_id
	w.run_seed = run_seed
	w.rng.set_seed(run_seed)
	w.max_turns = int(sc["turns"])
	w.actions_per_turn = int(sc["actions_per_turn"])
	for sd in ContentDB.data()["systems"]:
		var s := CivilizationSystem.new()
		s.id = String(sd["id"])
		# Small seeded variation so no two valleys start identical.
		var base_health := int(sc.get("start_health", {}).get(s.id, sd["start_health"]))
		s.health = base_health + w.rng.between(-4, 4)
		s.base_capacity = int(sd["capacity"])
		w.systems[s.id] = s
	w.forecast = EventDirector.roll_events(w, 1)
	begin_turn(w)
	return w


static func begin_turn(w: WorldState) -> void:
	w.action_points = w.actions_per_turn
	if w.reserve >= _r("reserve_for_bonus_action"):
		w.reserve -= _r("reserve_for_bonus_action")
		w.action_points += 1
	w.transform_used.clear()
	for s: CivilizationSystem in w.systems.values():
		s.capacity_used = 0
		if s.crisis_cooldown > 0:
			s.crisis_cooldown -= 1
	w.current_events = w.forecast.duplicate()
	for event_id in w.current_events:
		var ed := ContentDB.event_def(event_id)
		for spec in ed["consequences"]:
			var m := EventDirector.scaled_magnitude(w, event_id, int(spec["magnitude"]))
			w.ledger.create(String(spec["type"]), "event:" + event_id, m, String(spec["to"]), w.turn, w.turn)
		var seen := w.memory.add(w.memory.events_seen, event_id)
		if seen == 2:
			w.memory.note_msg(w.turn, String(ed["focus"]), "%s again: the valley has learned. Future %s hit softer.", [ed["name"], ed["name"]])
	w.forecast = EventDirector.roll_events(w, w.turn + 1) if w.turn < w.max_turns else []


# ---------------------------------------------------------------- interventions

static func cost_of(w: WorldState, i: Intervention) -> int:
	if i.kind == Intervention.CRISIS:
		var d := ContentDB.intervention_def("crisis")
		return int(d["base_cost"]) + int(d["escalation"]) * w.crises_used
	return int(ContentDB.intervention_def(i.kind).get("cost", 1))


## Returns "" if valid, otherwise the English reason (see validate_msg).
static func validate(w: WorldState, i: Intervention) -> String:
	return Msg.en(validate_msg(w, i))


## Returns {} if valid, otherwise a translatable Msg explaining why not.
static func validate_msg(w: WorldState, i: Intervention) -> Dictionary:
	if w.is_over():
		return Msg.make("The run is over.")
	var cost := cost_of(w, i)
	if cost > w.action_points:
		return Msg.make("Not enough actions (%d needed).", [cost])
	if i.kind == Intervention.CRISIS:
		return _validate_crisis(w, i)
	var c := w.ledger.get_c(i.consequence_id)
	if c == null or not c.is_pending():
		return Msg.make("That consequence no longer exists.")
	if c.land_turn != w.turn:
		return Msg.make("Only consequences arriving this season can be handled.")
	match i.kind:
		Intervention.REDIRECT:
			if c.redirects >= int(ContentDB.intervention_def("redirect")["max_per_consequence"]):
				return Msg.make("Already redirected twice; it resists further routing.")
			return _validate_target(w, c, i.target)
		Intervention.SPLIT:
			if c.current_magnitude < int(ContentDB.intervention_def("split")["min_magnitude"]):
				return Msg.make("Too small to split.")
			return _validate_target(w, c, i.target)
		Intervention.DELAY:
			if c.delays >= int(ContentDB.intervention_def("delay")["max_per_consequence"]):
				return Msg.make("Cannot be postponed again.")
			if c.land_turn + 1 > w.max_turns:
				return Msg.make("Nothing can be postponed past the final season.")
			return {}
		Intervention.TRANSFORM:
			var rule := ContentDB.transformation_def(i.rule_id)
			if rule.is_empty():
				return Msg.make("Unknown transformation.")
			if rule["input"] != c.type:
				return Msg.make("%s only converts %s.", [rule["name"], rule["input"]])
			if rule["at"] != c.destination:
				return Msg.make("Must first reach %s.", [ContentDB.system_def(rule["at"])["name"]])
			var site := w.system(rule["at"])
			if site.collapsed or site.health < int(rule["min_health"]):
				return Msg.make("%s is too weak to run %s (needs %d).", [ContentDB.system_def(rule["at"])["name"], rule["name"], int(rule["min_health"])])
			var used := int(w.transform_used.get(i.rule_id, 0))
			if used + c.current_magnitude > int(rule["capacity_per_turn"]):
				return Msg.make("Over capacity this season (%d/%d). Split it first.", [used, int(rule["capacity_per_turn"])])
			return {}
	return Msg.make("Unknown action.")


static func _validate_target(w: WorldState, c: Consequence, target: String) -> Dictionary:
	if not w.systems.has(target):
		return Msg.make("Unknown system.")
	if target == c.destination:
		return Msg.make("Already headed there.")
	if not w.graph.are_adjacent(c.destination, target):
		return Msg.make("Not causally connected to %s.", [ContentDB.system_def(c.destination)["name"]])
	if w.system(target).collapsed:
		return Msg.make("A collapsed system cannot receive anything.")
	return {}


static func _validate_crisis(w: WorldState, i: Intervention) -> Dictionary:
	var cd := ContentDB.crisis_for_system(i.system)
	if cd.is_empty():
		return Msg.make("No controlled crisis available there.")
	var s := w.system(i.system)
	if s.collapsed:
		return Msg.make("Collapsed.")
	if s.crisis_cooldown > 0:
		return Msg.make("Cooling down (%d seasons).", [s.crisis_cooldown])
	var max_delay := int(cd["gain"]["delay"])
	for h in cd["harm"]:
		max_delay = maxi(max_delay, int(h["delay"]))
	if w.turn + max_delay > w.max_turns:
		return Msg.make("Too late in the run: its fallout would outlive the record.")
	return {}


static func apply(w: WorldState, i: Intervention) -> String:
	var err := validate(w, i)
	if err != "":
		return err
	w.action_points -= cost_of(w, i)
	var entry := i.to_dict()
	entry["turn"] = w.turn
	w.actions_log.append(entry)
	w.last_focus_id = -1
	match i.kind:
		Intervention.REDIRECT: w.last_focus_id = _do_redirect(w, i).id
		Intervention.SPLIT: _do_split(w, i)
		Intervention.DELAY: _do_delay(w, i)
		Intervention.TRANSFORM: _do_transform(w, i)
		Intervention.CRISIS: _do_crisis(w, i)
	return ""


static func _do_redirect(w: WorldState, i: Intervention) -> Consequence:
	## Rerouting is never clean: leak_percent of the magnitude stays behind
	## (the parent closes and two children carry the full magnitude onwards).
	var c := w.ledger.get_c(i.consequence_id)
	var from := c.destination
	var m := c.current_magnitude
	var moved: Consequence
	var leak := 0
	if m >= 3:
		leak = maxi(1, ContentDB.pct(m, _r("redirect_leak_percent")))
	if leak > 0:
		w.ledger.close_passed_on(c, Consequence.State.SPLIT, w.turn, "redirected %s -> %s, %d leaked" % [from, i.target, leak])
		moved = w.ledger.create(c.type, "redirect:C%d" % c.id, m - leak, i.target, w.turn, c.land_turn, c)
		var stay := w.ledger.create(c.type, "leak:C%d" % c.id, leak, from, w.turn, c.land_turn, c)
		moved.redirects = c.redirects + 1
		moved.delays = c.delays
		stay.redirects = c.redirects + 1
		stay.delays = c.delays
	else:
		c.destination = i.target
		c.redirects += 1
		c.history.append("T%d redirected %s -> %s" % [w.turn, from, i.target])
		w.ledger.record(w.turn, "redirect", c.id, "%s -> %s" % [from, i.target])
		moved = c
	var n := w.memory.add(w.memory.redirects_in, i.target)
	if n % _r("redirects_per_capacity_loss") == 0:
		w.memory.note_msg(w.turn, i.target, "%s grows dependent on absorbing others' problems: capacity -1.", [ContentDB.system_def(i.target)["name"]])
	return moved


static func _do_split(w: WorldState, i: Intervention) -> void:
	var c := w.ledger.get_c(i.consequence_id)
	var half := c.current_magnitude / 2
	var keep := c.current_magnitude - half
	w.ledger.close_passed_on(c, Consequence.State.SPLIT, w.turn, "split %d/%d" % [keep, half])
	var a := w.ledger.create(c.type, "split:C%d" % c.id, keep, c.destination, w.turn, c.land_turn, c)
	var b := w.ledger.create(c.type, "split:C%d" % c.id, half, i.target, w.turn, c.land_turn, c)
	for ch in [a, b]:
		ch.redirects = c.redirects
		ch.delays = c.delays
	w.memory.add(w.memory.redirects_in, i.target)


static func _do_delay(w: WorldState, i: Intervention) -> void:
	var c := w.ledger.get_c(i.consequence_id)
	c.land_turn += 1
	c.delays += 1
	c.history.append("T%d delayed to T%d" % [w.turn, c.land_turn])
	w.ledger.record(w.turn, "delay", c.id, "to T%d" % c.land_turn)
	var strain := maxi(1, int(ceili(c.current_magnitude * int(ContentDB.intervention_def("delay")["strain_percent"]) / 100.0)))
	w.ledger.create(c.type, "delay:C%d" % c.id, strain, c.destination, w.turn, c.land_turn)


static func _do_transform(w: WorldState, i: Intervention) -> void:
	var c := w.ledger.get_c(i.consequence_id)
	var rule := ContentDB.transformation_def(i.rule_id)
	var eff := int(rule["efficiency"]) + w.memory.adaptation(i.rule_id)
	var m := c.current_magnitude
	var out := clampi(ContentDB.pct(m, eff), 1, maxi(1, m - 1))
	var residue := m - out
	w.transform_used[i.rule_id] = int(w.transform_used.get(i.rule_id, 0)) + m
	w.ledger.close_passed_on(c, Consequence.State.TRANSFORMED, w.turn, "transformed by %s" % rule["name"])
	w.ledger.create(String(rule["output"]), "transform:" + i.rule_id, out, String(rule["output_to"]), w.turn, c.land_turn, c)
	if residue > 0:
		w.ledger.create(String(rule["residue"]), "residue:" + i.rule_id, residue, String(rule["residue_to"]), w.turn, c.land_turn, c)
	var before := w.memory.adaptation(i.rule_id)
	w.memory.add(w.memory.transforms, i.rule_id)
	var after := w.memory.adaptation(i.rule_id)
	if after > before:
		w.memory.note_msg(w.turn, String(rule["at"]), "%s refined: efficiency now %d%%.", [rule["name"], int(rule["efficiency"]) + after])


static func _do_crisis(w: WorldState, i: Intervention) -> void:
	var cd := ContentDB.crisis_for_system(i.system)
	var prior := int(w.memory.crises.get(i.system, 0))
	var yield_pct := w.memory.crisis_yield_percent(i.system)
	var gain: Dictionary = cd["gain"]
	var gm := maxi(1, ContentDB.pct(int(gain["magnitude"]), yield_pct))
	w.ledger.create(String(gain["type"]), "crisis:" + String(cd["id"]), gm, String(gain["to"]), w.turn, w.turn + int(gain["delay"]))
	for h in cd["harm"]:
		w.ledger.create(String(h["type"]), "crisis:" + String(cd["id"]), int(h["magnitude"]), String(h["to"]), w.turn, w.turn + int(h["delay"]))
	w.instability = mini(100, w.instability + int(cd["instability"]) + 3 * prior)
	w.crises_used += 1
	w.system(i.system).crisis_cooldown = int(ContentDB.intervention_def("crisis")["cooldown"])
	w.memory.add(w.memory.crises, i.system)
	if prior >= 1:
		w.memory.note_msg(w.turn, i.system, "%s resists repeated %s: yield %d%%.", [ContentDB.system_def(i.system)["name"], cd["name"], w.memory.crisis_yield_percent(i.system)])


## Every currently valid intervention (used by bots and tests).
static func available_actions(w: WorldState) -> Array[Intervention]:
	var out: Array[Intervention] = []
	if w.is_over():
		return out
	for c in w.ledger.pending():
		if c.land_turn != w.turn:
			continue
		for n in w.graph.neighbors(c.destination):
			for cand in [Intervention.redirect(c.id, n), Intervention.split(c.id, n)]:
				if validate(w, cand) == "":
					out.append(cand)
		var d := Intervention.delay(c.id)
		if validate(w, d) == "":
			out.append(d)
		for rule in ContentDB.data()["transformations"]:
			var t := Intervention.transform(c.id, String(rule["id"]))
			if validate(w, t) == "":
				out.append(t)
	for sid in w.systems:
		var k := Intervention.crisis(sid)
		if validate(w, k) == "":
			out.append(k)
	return out


## Predicted health change if `magnitude` of `type` landed on `dest` now.
## Pure: does not mutate the world. Ignores spill (shown separately).
## before_id: only consequences resolving earlier (lower id) claim capacity first;
## -1 means "a new consequence" (resolves after everything already pending).
static func preview_landing(w: WorldState, type: String, magnitude: int, dest: String, before_id: int = -1) -> Dictionary:
	var s := w.system(dest)
	var vuln := ContentDB.vulnerability(type, dest)
	if ContentDB.is_positive(type):
		var heal := ContentDB.pct(magnitude, vuln)
		return {"delta": mini(heal, s.max_health - s.health), "absorbed": 0, "spill": 0}
	# Capacity already claimed by other consequences landing here this turn.
	var claimed := 0
	for c in w.ledger.pending_landing_on(w.turn):
		if c.destination == dest and not ContentDB.is_positive(c.type) and (before_id < 0 or c.id < before_id):
			claimed += c.current_magnitude
	var remaining := maxi(0, s.remaining_capacity(w.memory) - claimed)
	var absorbed := mini(magnitude, remaining)
	var excess := magnitude - absorbed
	var spill := excess / 2 if excess >= _r("spill_min") * 2 and _spill_target(w, dest) != "" else 0
	var landed := magnitude - spill
	var effect := ContentDB.pct(absorbed, vuln * _r("absorb_effect_percent") / 100) + ContentDB.pct(landed - absorbed, vuln)
	effect = ContentDB.pct(effect, 100 - w.memory.resilience(dest))
	return {"delta": -mini(effect, s.health), "absorbed": absorbed, "spill": spill}


## Follows routing (split/redirect/leak) back to the consequence's true origin,
## so post-mortems blame the event, not the routing step. Returns a source key
## ("event:flood" or "event:flood|routed") that the UI turns into text.
static func origin_key(w: WorldState, c: Consequence) -> String:
	var cur := c
	var routed := false
	var guard := 0
	while guard < 32 and cur.parent_id >= 0 and (cur.source.begins_with("split:") or cur.source.begins_with("redirect:") or cur.source.begins_with("leak:")):
		routed = true
		cur = w.ledger.get_c(cur.parent_id)
		guard += 1
	return cur.source + ("|routed" if routed else "")


## Translatable description of a source key (see origin_key).
static func source_msg(source: String) -> Dictionary:
	var routed := source.ends_with("|routed")
	var src := source.trim_suffix("|routed")
	var parts := src.split(":")
	var kind := parts[0]
	var rest := parts[1] if parts.size() > 1 else ""
	var m: Dictionary
	match kind:
		"event": m = Msg.make("%s", [ContentDB.event_def(rest).get("name", rest)])
		"crisis": m = Msg.make("%s (your crisis)", [ContentDB.crisis_def(rest).get("name", rest)])
		"transform": m = Msg.make("%s", [ContentDB.transformation_def(rest).get("name", rest)])
		"residue": m = Msg.make("%s residue", [ContentDB.transformation_def(rest).get("name", rest)])
		"spill": m = Msg.make("Overflow from %s", [ContentDB.system_def(rest).get("name", rest)])
		"cascade": m = Msg.make("Failure of %s", [ContentDB.system_def(rest).get("name", rest)])
		"delay": m = Msg.make("Deferred strain")
		"redirect": m = Msg.make("Rerouted")
		"leak": m = Msg.make("Rerouting leak")
		"split": m = Msg.make("Split share")
		_: m = Msg.make("%s", [src])
	if routed:
		m = Msg.make("%s (routed)", [Msg.en(m)])
		m["inner"] = source_msg(src)
	return m


## English description of a source key.
static func source_label(source: String) -> String:
	return Msg.en(source_msg(source))


# ---------------------------------------------------------------- resolution

## Resolves the turn. Returns a report the presentation layer animates.
static func end_turn(w: WorldState) -> Dictionary:
	var report := {"turn": w.turn, "landings": [], "effects": [], "regen": [], "cascades": [],
		"scars": [], "collapses": [], "outcome": "", "memory_from": w.memory.chronicle.size()}
	if w.is_over():
		return report
	_land_consequences(w, report)
	# Delayed causal effects queued last turn land now.
	for e in w.queued_effects:
		var t := w.system(e["to"])
		if not t.collapsed:
			var was := t.collapsed
			t.apply_delta(int(e["delta"]))
			report["effects"].append(e)
			if t.collapsed and not was:
				report["collapses"].append(t.id)
	w.queued_effects = w.graph.propagate(w.systems)
	_regen(w, report)
	_scars_and_cascades(w, report)
	w.instability = clampi(w.instability - _r("instability_decay"), 0, 100)
	w.history.append(_snapshot(w))
	_evaluate(w, report)
	report["outcome"] = w.outcome
	if not w.is_over():
		w.turn += 1
		begin_turn(w)
	return report


static func _land_consequences(w: WorldState, report: Dictionary) -> void:
	var absorb_pct := _r("absorb_effect_percent")
	for c in w.ledger.pending_landing_on(w.turn):
		var s := w.system(c.destination)
		var m := c.current_magnitude
		var vuln := ContentDB.vulnerability(c.type, s.id)
		var landing := {"id": c.id, "type": c.type, "to": s.id, "source": c.source, "amount": m,
			"delta": 0, "absorbed": 0, "spill_id": -1, "spill_to": ""}
		if ContentDB.is_positive(c.type):
			var heal := ContentDB.pct(m, vuln)
			var before := s.health
			var overflow := s.apply_delta(heal)
			w.reserve += overflow
			landing["delta"] = s.health - before
			landing["reserve"] = overflow
			w.ledger.close_landed(c, m, w.turn)
		else:
			var absorbed := mini(m, s.remaining_capacity(w.memory))
			var excess := m - absorbed
			var spill := 0
			var dependent := _spill_target(w, s.id)
			if excess >= _r("spill_min") * 2 and c.depth < _r("spill_max_depth") and dependent != "" and not s.collapsed:
				spill = excess / 2
			var landed := m - spill
			s.capacity_used += absorbed
			var effect := ContentDB.pct(absorbed, vuln * absorb_pct / 100) + ContentDB.pct(landed - absorbed, vuln)
			effect = ContentDB.pct(effect, 100 - w.memory.resilience(s.id))
			var before := s.health
			var was_collapsed := s.collapsed
			s.apply_delta(-effect)
			landing["delta"] = s.health - before
			if before - s.health > 0:
				var bucket: Dictionary = w.damage_by_source.get(s.id, {})
				var label := origin_key(w, c)
				bucket[label] = int(bucket.get(label, 0)) + (before - s.health)
				w.damage_by_source[s.id] = bucket
			landing["absorbed"] = absorbed
			var r_before := w.memory.resilience(s.id)
			w.memory.add(w.memory.harm_absorbed, s.id, landed)
			if w.memory.resilience(s.id) / 5 > r_before / 5:
				w.memory.note_msg(w.turn, s.id, "%s hardens from repeated hits: resilience %d%%.", [ContentDB.system_def(s.id)["name"], w.memory.resilience(s.id)])
			w.ledger.close_landed(c, landed, w.turn)
			if spill > 0:
				var child := w.ledger.create(c.type, "spill:" + s.id, spill, dependent, w.turn, w.turn + 1, c)
				landing["spill_id"] = child.id
				landing["spill_to"] = dependent
				w.instability = mini(100, w.instability + _r("instability_per_spill"))
			if s.collapsed and not was_collapsed:
				report["collapses"].append(s.id)
		report["landings"].append(landing)


static func _spill_target(w: WorldState, system_id: String) -> String:
	var best := ""
	var best_w := -1
	for e in w.graph.outgoing(system_id):
		var t := w.system(e["to"])
		if not t.collapsed and int(e["weight"]) > best_w:
			best_w = int(e["weight"])
			best = t.id
	return best


static func _regen(w: WorldState, report: Dictionary) -> void:
	for s: CivilizationSystem in w.systems.values():
		if s.collapsed or s.health < _r("regen_threshold"):
			continue
		var amount := _r("regen_low") if s.health < _r("regen_high_threshold") else _r("regen_high")
		var before := s.health
		s.apply_delta(amount)
		if s.health != before:
			report["regen"].append({"system": s.id, "delta": s.health - before})


static func _scars_and_cascades(w: WorldState, report: Dictionary) -> void:
	for s: CivilizationSystem in w.systems.values():
		if not s.scarred and s.health < _r("scar_threshold"):
			s.scarred = true
			s.max_health -= _r("scar_amount")
			w.memory.add(w.memory.scars, s.id)
			w.memory.note_msg(w.turn, s.id, "%s is scarred: it will never fully recover (max %d).", [ContentDB.system_def(s.id)["name"], s.max_health])
			report["scars"].append(s.id)
		var target := w.graph.strongest_dependent(s.id)
		if target == "" or w.system(target).collapsed:
			continue
		var mag := 0
		if s.collapsed and s.id in report["collapses"]:
			mag = 10
			w.memory.note_msg(w.turn, s.id, "%s COLLAPSED. Its dependents will feel it.", [ContentDB.system_def(s.id)["name"]])
		elif not s.collapsed and s.health < _r("cascade_threshold"):
			mag = 4 + (_r("cascade_threshold") - s.health) / 3
		if mag > 0:
			var c := w.ledger.create("damage", "cascade:" + s.id, mag, target, w.turn, w.turn + 1)
			w.instability = mini(100, w.instability + _r("instability_per_cascade"))
			report["cascades"].append({"from": s.id, "to": target, "id": c.id, "amount": mag})


static func _snapshot(w: WorldState) -> Dictionary:
	var h := {}
	for id in w.systems:
		h[id] = w.system(id).health
	return {"turn": w.turn, "health": h, "instability": w.instability, "reserve": w.reserve}


static func _evaluate(w: WorldState, _report: Dictionary) -> void:
	var sc := w.scenario()
	var loss: Dictionary = sc["loss"]
	for crit in loss["critical"]:
		if w.system(crit).collapsed:
			w.outcome = "defeat"
			_set_reason(w, "%s collapsed. Without people, there is no civilization.", [ContentDB.system_def(crit)["name"]])
			return
	if w.collapsed_count() >= int(loss["max_collapsed"]):
		w.outcome = "defeat"
		_set_reason(w, "%d systems collapsed. The valley can no longer hold together.", [w.collapsed_count()])
		return
	if w.instability >= int(loss["max_instability"]):
		w.outcome = "defeat"
		_set_reason(w, "Instability reached 100. Order dissolved.", [])
		return
	if w.turn >= w.max_turns:
		var win: Dictionary = sc["win"]
		if w.average_health() >= int(win["avg_health"]) and w.min_health() >= int(win["min_health"]):
			w.outcome = "victory"
			_set_reason(w, "The valley endures: average health %d, weakest system %d.", [w.average_health(), w.min_health()])
		else:
			w.outcome = "defeat"
			_set_reason(w, "Survived, but unsustainably: average %d (need %d), weakest %d (need %d).", [w.average_health(), int(win["avg_health"]), w.min_health(), int(win["min_health"])])


static func _set_reason(w: WorldState, key: String, args: Array) -> void:
	w.outcome_msg = Msg.make(key, args)
	w.outcome_reason = Msg.en(w.outcome_msg)
