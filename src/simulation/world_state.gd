class_name WorldState
extends RefCounted
## Complete, serializable state of a run. The presentation layer only reads it.

const SAVE_VERSION := 1

var scenario_id: String = ""
var run_seed: int = 0
var turn: int = 1
var max_turns: int = 12
var actions_per_turn: int = 3
var action_points: int = 3
var instability: int = 0
var reserve: int = 0
var crises_used: int = 0
var transform_used: Dictionary = {}   # rule id -> magnitude used this turn
var systems: Dictionary = {}          # id -> CivilizationSystem (data order)
var ledger := ConsequenceLedger.new()
var memory := WorldMemory.new()
var graph := CausalGraph.new()
var rng := DetRng.new()
var forecast: Array = []              # event ids rolled for next turn
var current_events: Array = []        # event ids that fired this turn
var queued_effects: Array = []        # causal deltas to apply at next resolution
var actions_log: Array = []           # Intervention dicts with turn
var history: Array = []               # per-turn {turn, health:{}, instability, reserve}
var damage_by_source: Dictionary = {} # system -> {source label -> health lost}
var outcome: String = ""              # "", "victory", "defeat"
var outcome_reason: String = ""
var outcome_msg: Dictionary = {}      # translatable form of outcome_reason
var daily_date: String = ""          # "YYYY-MM-DD" when this is the daily valley
var last_focus_id: int = -1           # transient UI hint (not saved)


func scenario() -> Dictionary:
	return ContentDB.scenario_def(scenario_id)


func system(id: String) -> CivilizationSystem:
	return systems[id]


func average_health() -> int:
	var total := 0
	for s: CivilizationSystem in systems.values():
		total += s.health
	return int(total / systems.size())


func min_health() -> int:
	var m := 1000
	for s: CivilizationSystem in systems.values():
		m = mini(m, s.health)
	return m


func collapsed_count() -> int:
	var n := 0
	for s: CivilizationSystem in systems.values():
		if s.collapsed:
			n += 1
	return n


## Stability index shown to the player: average health minus pressure from
## instability and pending harm this turn.
func stability_index() -> int:
	var pending_harm := 0
	for c in ledger.pending():
		if c.land_turn <= turn and not ContentDB.is_positive(c.type):
			pending_harm += c.current_magnitude
	return clampi(average_health() - instability / 4 - pending_harm / 6, 0, 100)


func is_over() -> bool:
	return outcome != ""


func to_dict() -> Dictionary:
	var sys := {}
	for id in systems:
		sys[id] = systems[id].to_dict()
	return {
		"save_version": SAVE_VERSION,
		"scenario_id": scenario_id, "seed": run_seed, "turn": turn, "max_turns": max_turns,
		"actions_per_turn": actions_per_turn, "action_points": action_points,
		"instability": instability, "reserve": reserve, "crises_used": crises_used,
		"transform_used": transform_used.duplicate(), "systems": sys,
		"ledger": ledger.to_dict(), "memory": memory.to_dict(), "rng_state": rng.state,
		"forecast": forecast.duplicate(), "current_events": current_events.duplicate(),
		"queued_effects": queued_effects.duplicate(true), "actions_log": actions_log.duplicate(true),
		"history": history.duplicate(true), "damage_by_source": damage_by_source.duplicate(true), "outcome": outcome, "outcome_reason": outcome_reason, "daily_date": daily_date, "outcome_msg": outcome_msg.duplicate(true),
	}


## JSON turns every number into float; the simulation is integer-only, so
## integral floats are restored to int recursively.
static func intify(v: Variant) -> Variant:
	if v is float and is_equal_approx(v, roundf(v)):
		return int(v)
	if v is Array:
		return v.map(func(x): return intify(x))
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = intify(v[k])
		return out
	return v


static func from_dict(raw: Dictionary) -> WorldState:
	var d: Dictionary = intify(raw)
	assert(int(d.get("save_version", 0)) == SAVE_VERSION, "unsupported save version")
	var w := WorldState.new()
	w.scenario_id = String(d["scenario_id"])
	w.run_seed = int(d["seed"])
	w.turn = int(d["turn"])
	w.max_turns = int(d["max_turns"])
	w.actions_per_turn = int(d["actions_per_turn"])
	w.action_points = int(d["action_points"])
	w.instability = int(d["instability"])
	w.reserve = int(d["reserve"])
	w.crises_used = int(d["crises_used"])
	for k in d["transform_used"]:
		w.transform_used[String(k)] = int(d["transform_used"][k])
	for id in ContentDB.system_ids():
		if d["systems"].has(id):
			w.systems[id] = CivilizationSystem.from_dict(d["systems"][id])
	w.graph = CausalGraph.new(w.systems.keys())
	w.ledger = ConsequenceLedger.from_dict(d["ledger"])
	w.memory = WorldMemory.from_dict(d["memory"])
	w.rng.state = int(d["rng_state"])
	w.forecast = Array(d["forecast"]).map(func(x): return String(x))
	w.current_events = Array(d["current_events"]).map(func(x): return String(x))
	w.queued_effects = []
	for e in d["queued_effects"]:
		w.queued_effects.append({"from": String(e["from"]), "to": String(e["to"]), "delta": int(e["delta"]), "kind": String(e["kind"])})
	w.actions_log = d["actions_log"].duplicate(true)
	w.history = d["history"].duplicate(true)
	w.damage_by_source = d.get("damage_by_source", {}).duplicate(true)
	w.outcome = String(d["outcome"])
	w.outcome_reason = String(d["outcome_reason"])
	w.daily_date = String(d.get("daily_date", ""))
	w.outcome_msg = d.get("outcome_msg", {}).duplicate(true)
	return w


## Stable fingerprint of the full state, used by determinism tests.
func state_hash() -> String:
	return JSON.stringify(to_dict(), "", true).md5_text()


func clone() -> WorldState:
	return WorldState.from_dict(to_dict())


## Run score for comparing attempts (daily valley, shared seeds).
## Victory dominates; then health, the weakest system and reserves; instability costs.
func score() -> int:
	var sc := average_health() * 10 + min_health() * 5 + reserve - instability * 2 + history.size() * 20
	if outcome == "victory":
		sc += 1000
	return maxi(0, sc)
