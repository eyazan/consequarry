class_name EventDirector
extends RefCounted
## Chooses which events fire. Deterministic given the world RNG.
## Weak systems attract events that focus on them (crises breed crises),
## but the same event never fires twice in one turn.


static func roll_events(w: WorldState, for_turn: int) -> Array:
	var sc := w.scenario()
	var scripted: Dictionary = sc.get("scripted_events", {})
	if scripted.has(str(for_turn)):
		return Array(scripted[str(for_turn)]).duplicate()
	var count := int(sc["events_per_turn"])
	if w.instability >= int(sc["extra_event_instability"]):
		count += 1
	if for_turn >= int(sc["extra_event_from_turn"]) and w.rng.chance_percent(40):
		count += 1
	count = mini(count, 3)
	# Only events whose focus and targets exist in this world (and, for campaign
	# levels, that the level's event pool allows).
	var pool: Array = sc.get("events", [])
	var defs: Array = []
	for e in ContentDB.data()["events"]:
		if not pool.is_empty() and not pool.has(e["id"]):
			continue
		var ok: bool = w.systems.has(e["focus"])
		for spec in e["consequences"]:
			ok = ok and w.systems.has(spec["to"])
		if ok:
			defs.append(e)
	var chosen: Array = []
	for _i in count:
		var weights: Array = []
		for e in defs:
			var wgt := int(e["weight"]) * int(sc.get("event_weights", {}).get(e["id"], 100)) / 10
			if chosen.has(e["id"]):
				wgt = 0
			else:
				var focus: CivilizationSystem = w.systems[e["focus"]]
				if focus.collapsed:
					wgt = wgt / 2
				elif focus.health < 45:
					wgt = wgt * 3 / 2
			weights.append(wgt)
		var idx := w.rng.weighted_index(weights)
		if idx >= 0:
			chosen.append(String(defs[idx]["id"]))
	return chosen


## Magnitude after turn scaling, instability and familiarity (world memory).
static func scaled_magnitude(w: WorldState, event_id: String, base: int) -> int:
	var r := ContentDB.rules()
	var turn_scale := int(w.scenario().get("magnitude_turn_scale", r["magnitude_turn_scale"]))
	var scale := 100 + turn_scale * (w.turn - 1) + w.instability / 5
	var m := ContentDB.pct(base, scale)
	m = ContentDB.pct(m, 100 - w.memory.event_familiarity_percent(event_id))
	m = ContentDB.pct(m, int(w.scenario().get("magnitude_percent", 100)))
	return maxi(1, m)
