class_name CausalGraph
extends RefCounted
## Static directed graph of system dependencies, loaded from content data.
## "support" edges:  healthy source helps target; failing source drains it.
## "pressure" edges: a thriving source wears the target down (negative feedback).

var edges: Array = []  # Array[Dictionary] {from, to, weight, kind}


func _init() -> void:
	edges = ContentDB.data()["causal_edges"].duplicate(true)


func neighbors(system_id: String) -> Array[String]:
	## Undirected adjacency, in deterministic data order, without duplicates.
	var out: Array[String] = []
	for e in edges:
		if e["from"] == system_id and not out.has(String(e["to"])):
			out.append(String(e["to"]))
		elif e["to"] == system_id and not out.has(String(e["from"])):
			out.append(String(e["from"]))
	return out


func are_adjacent(a: String, b: String) -> bool:
	return neighbors(a).has(b)


func outgoing(system_id: String) -> Array:
	var out: Array = []
	for e in edges:
		if e["from"] == system_id:
			out.append(e)
	return out


func strongest_dependent(system_id: String) -> String:
	var best := ""
	var best_w := -1
	for e in outgoing(system_id):
		if e["kind"] == "support" and int(e["weight"]) > best_w:
			best_w = int(e["weight"])
			best = String(e["to"])
	return best


## Computes health deltas each edge produces this turn. Pure function.
## Returns Array of {from, to, delta, kind}.
static func edge_delta(edge: Dictionary, source_health: int, source_collapsed: bool) -> int:
	var w := int(edge["weight"])
	if edge["kind"] == "pressure":
		# Thriving industry wears the environment down.
		if source_collapsed:
			return 0
		return -mini(3, int(maxi(0, source_health - 60) * w / 200))
	# support
	if source_collapsed:
		return -int(ceili(30.0 * w / 100.0))
	var raw := (source_health - 50) * w
	if raw >= 0:
		# Diminishing returns on the upside.
		return mini(2, int(raw / 400))
	return maxi(-8, -int(ceili(float(-raw) / 200.0)))


func propagate(systems: Dictionary) -> Array:
	var out: Array = []
	for e in edges:
		var src: CivilizationSystem = systems[e["from"]]
		var d := edge_delta(e, src.health, src.collapsed)
		if d != 0:
			out.append({"from": e["from"], "to": e["to"], "delta": d, "kind": e["kind"]})
	return out
