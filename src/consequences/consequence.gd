class_name Consequence
extends RefCounted
## A discrete, routable outcome. Magnitude is conserved: when a consequence closes,
## landed_amount + sum(child magnitudes) == original_magnitude.

enum State { PENDING, LANDED, SPLIT, TRANSFORMED }

var id: int = -1
var type: String = ""
var source: String = ""
var original_magnitude: int = 0
var current_magnitude: int = 0
var destination: String = ""
var created_turn: int = 0
var land_turn: int = 0
var parent_id: int = -1
var depth: int = 0
var state: State = State.PENDING
var landed_amount: int = 0
var children: Array[int] = []
var history: Array[String] = []
var redirects: int = 0
var delays: int = 0


func duration() -> int:
	return land_turn - created_turn


func is_pending() -> bool:
	return state == State.PENDING


func to_dict() -> Dictionary:
	return {
		"id": id, "type": type, "source": source,
		"original_magnitude": original_magnitude, "current_magnitude": current_magnitude,
		"destination": destination, "created_turn": created_turn, "land_turn": land_turn,
		"parent_id": parent_id, "depth": depth, "state": int(state),
		"landed_amount": landed_amount, "children": children.duplicate(),
		"history": history.duplicate(), "redirects": redirects, "delays": delays,
	}


static func from_dict(d: Dictionary) -> Consequence:
	var c := Consequence.new()
	c.id = int(d["id"])
	c.type = String(d["type"])
	c.source = String(d["source"])
	c.original_magnitude = int(d["original_magnitude"])
	c.current_magnitude = int(d["current_magnitude"])
	c.destination = String(d["destination"])
	c.created_turn = int(d["created_turn"])
	c.land_turn = int(d["land_turn"])
	c.parent_id = int(d["parent_id"])
	c.depth = int(d["depth"])
	c.state = int(d["state"]) as State
	c.landed_amount = int(d["landed_amount"])
	for ch in d["children"]:
		c.children.append(int(ch))
	for h in d["history"]:
		c.history.append(String(h))
	c.redirects = int(d["redirects"])
	c.delays = int(d["delays"])
	return c
