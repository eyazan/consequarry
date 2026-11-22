class_name BotStrategies
extends RefCounted
## Simulated player strategies for automated balancing.
## These approximate play styles; they are NOT evidence of human behaviour.

const NAMES: Array[String] = ["passive", "random", "conservative", "aggressive", "greedy",
	"balanced", "crisis_focused", "recovery_focused", "expert"]


## Plays the whole current turn (until no AP or strategy stops).
static func play_turn(w: WorldState, strategy: String, rng: DetRng) -> void:
	var guard := 0
	while w.action_points > 0 and guard < 12:
		guard += 1
		var actions := SimulationEngine.available_actions(w)
		if actions.is_empty():
			return
		var pick: Intervention = null
		match strategy:
			"passive": pick = null
			"random": pick = actions[rng.range_int(actions.size())] if rng.chance_percent(80) else null
			"expert": pick = _lookahead(w, actions)
			_: pick = _best_by_score(w, actions, strategy)
		if pick == null:
			return
		var err := SimulationEngine.apply(w, pick)
		assert(err == "", "bot chose invalid action: " + err)


static func _best_by_score(w: WorldState, actions: Array[Intervention], strategy: String) -> Intervention:
	var best: Intervention = null
	var best_score := 0
	for a in actions:
		var s := _score(w, a, strategy)
		if s > best_score:
			best_score = s
			best = a
	return best


## Expected immediate harm-points of a consequence landing on a system.
static func _harm(w: WorldState, type: String, system_id: String, magnitude: int) -> int:
	if ContentDB.is_positive(type):
		return -magnitude
	var s := w.system(system_id)
	var weakness := 100 + maxi(0, 50 - s.health) * 3
	return ContentDB.pct(ContentDB.pct(magnitude, ContentDB.vulnerability(type, system_id)), weakness)


static func _score(w: WorldState, a: Intervention, strategy: String) -> int:
	var c: Consequence = w.ledger.get_c(a.consequence_id) if a.consequence_id >= 0 else null
	match a.kind:
		Intervention.REDIRECT:
			var gain := _harm(w, c.type, c.destination, c.current_magnitude) - _harm(w, c.type, a.target, c.current_magnitude)
			# Redirecting towards a transformation site is worth extra to greedy players.
			if strategy == "greedy" or strategy == "balanced":
				for r in ContentDB.data()["transformations"]:
					if r["input"] == c.type and r["at"] == a.target:
						gain += c.current_magnitude / 2
			if strategy == "aggressive" or strategy == "crisis_focused":
				gain /= 2
			if strategy == "recovery_focused" and w.system(c.destination).health < 45:
				gain += 6
			return gain
		Intervention.SPLIT:
			var half := c.current_magnitude / 2
			var gain := _harm(w, c.type, c.destination, half) - _harm(w, c.type, a.target, half)
			if strategy == "conservative":
				gain += 2
			return gain - 1
		Intervention.DELAY:
			if strategy == "recovery_focused" and w.system(c.destination).health < 35:
				return 8
			if strategy == "conservative" and w.system(c.destination).health < 30:
				return 5
			return 0
		Intervention.TRANSFORM:
			var base := c.current_magnitude
			match strategy:
				"greedy", "aggressive": return base * 2
				"balanced": return base + _harm(w, c.type, c.destination, c.current_magnitude) / 2
				"conservative", "recovery_focused": return base / 2
				_: return base
		Intervention.CRISIS:
			match strategy:
				"crisis_focused": return 30
				"aggressive": return 14 if w.instability < 60 else 0
				"greedy": return 6 if w.instability < 30 else 0
				_: return 0
	return 0


## One-ply lookahead: try each action on a clone, resolve the turn, evaluate.
static func _lookahead(w: WorldState, actions: Array[Intervention]) -> Intervention:
	var baseline := _evaluate_after_turn(w, null)
	var best: Intervention = null
	var best_value := baseline
	for a in actions:
		var v := _evaluate_after_turn(w, a)
		if v > best_value:
			best_value = v
			best = a
	return best


static func _evaluate_after_turn(w: WorldState, a: Intervention) -> int:
	var sim := w.clone()
	if a != null:
		SimulationEngine.apply(sim, a)
	var turn_before := sim.turn
	SimulationEngine.end_turn(sim)
	var value := 0
	for s: CivilizationSystem in sim.systems.values():
		value += s.health * 10
		if s.health < 30:
			value -= (30 - s.health) * 12
		if s.collapsed:
			value -= 2000
	value -= sim.instability * 6
	value += sim.reserve * 4
	# Pending harm next turn counts against the state.
	for c in sim.ledger.pending():
		if not ContentDB.is_positive(c.type) and c.land_turn <= turn_before + 1:
			value -= c.current_magnitude * 4
	if sim.outcome == "defeat":
		value -= 100000
	elif sim.outcome == "victory":
		value += 100000
	return value
