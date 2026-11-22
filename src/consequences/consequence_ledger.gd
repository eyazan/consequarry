class_name ConsequenceLedger
extends RefCounted
## Auditable record of every consequence ever created in a run.
## Invariants (see docs/design/FORMULAS.md):
##  I1  closed c:  c.landed_amount + sum(children.original) == c.original_magnitude
##  I2  pending c: c.current_magnitude == c.original_magnitude and landed_amount == 0
##  I3  sum(root originals) == sum(landed) + sum(pending current)

var items: Dictionary = {}  # int -> Consequence
var next_id: int = 1
var entries: Array = []  # Array of Dictionary {turn, kind, id, text}


func create(type: String, source: String, magnitude: int, destination: String,
		turn: int, land_turn: int, parent: Consequence = null) -> Consequence:
	assert(magnitude > 0, "consequence magnitude must be positive")
	var c := Consequence.new()
	c.id = next_id
	next_id += 1
	c.type = type
	c.source = source
	c.original_magnitude = magnitude
	c.current_magnitude = magnitude
	c.destination = destination
	c.created_turn = turn
	c.land_turn = land_turn
	if parent != null:
		c.parent_id = parent.id
		c.depth = parent.depth + 1
		parent.children.append(c.id)
	c.history.append("T%d created by %s -> %s (%d)" % [turn, source, destination, magnitude])
	items[c.id] = c
	record(turn, "create", c.id, "%s %s %d -> %s" % [source, type, magnitude, destination])
	return c


func record(turn: int, kind: String, id: int, text: String) -> void:
	entries.append({"turn": turn, "kind": kind, "id": id, "text": text})


func get_c(id: int) -> Consequence:
	return items.get(id, null)


## Deterministic list of pending consequences, sorted by id.
func pending() -> Array[Consequence]:
	var out: Array[Consequence] = []
	var ids := items.keys()
	ids.sort()
	for id in ids:
		var c: Consequence = items[id]
		if c.is_pending():
			out.append(c)
	return out


func pending_landing_on(turn: int) -> Array[Consequence]:
	var out: Array[Consequence] = []
	for c in pending():
		if c.land_turn <= turn:
			out.append(c)
	return out


func close_landed(c: Consequence, amount: int, turn: int) -> void:
	c.landed_amount = amount
	c.current_magnitude = 0
	c.state = Consequence.State.LANDED
	c.history.append("T%d landed %d on %s" % [turn, amount, c.destination])


func close_passed_on(c: Consequence, new_state: Consequence.State, turn: int, note: String) -> void:
	c.current_magnitude = 0
	c.state = new_state
	c.history.append("T%d %s" % [turn, note])


func totals() -> Dictionary:
	var roots := 0
	var landed := 0
	var pending_sum := 0
	for c: Consequence in items.values():
		if c.parent_id == -1:
			roots += c.original_magnitude
		landed += c.landed_amount
		if c.is_pending():
			pending_sum += c.current_magnitude
	return {"created_roots": roots, "landed": landed, "pending": pending_sum}


## Returns a list of human-readable invariant violations. Empty == healthy.
func verify() -> Array[String]:
	var errors: Array[String] = []
	for c: Consequence in items.values():
		if c.original_magnitude <= 0:
			errors.append("C%d non-positive magnitude" % c.id)
		if c.is_pending():
			if c.current_magnitude != c.original_magnitude or c.landed_amount != 0:
				errors.append("C%d pending but partially resolved" % c.id)
		else:
			var passed := 0
			for ch in c.children:
				var child: Consequence = items.get(ch, null)
				if child == null:
					errors.append("C%d missing child %d" % [c.id, ch])
				else:
					passed += child.original_magnitude
			if c.landed_amount + passed != c.original_magnitude:
				errors.append("C%d leaks: landed %d + passed %d != %d" % [c.id, c.landed_amount, passed, c.original_magnitude])
	var t := totals()
	if t["created_roots"] != t["landed"] + t["pending"]:
		errors.append("Global conservation broken: roots %d != landed %d + pending %d" % [t["created_roots"], t["landed"], t["pending"]])
	return errors


func to_dict() -> Dictionary:
	var arr: Array = []
	var ids := items.keys()
	ids.sort()
	for id in ids:
		arr.append(items[id].to_dict())
	return {"next_id": next_id, "items": arr, "entries": entries.duplicate(true)}


static func from_dict(d: Dictionary) -> ConsequenceLedger:
	var l := ConsequenceLedger.new()
	l.next_id = int(d["next_id"])
	for cd in d["items"]:
		var c := Consequence.from_dict(cd)
		l.items[c.id] = c
	l.entries = d["entries"].duplicate(true)
	return l
