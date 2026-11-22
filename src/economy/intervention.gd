class_name Intervention
extends RefCounted
## A player (or bot) action. Plain value object; validated by SimulationEngine.

const REDIRECT := "redirect"
const SPLIT := "split"
const DELAY := "delay"
const TRANSFORM := "transform"
const CRISIS := "crisis"

var kind: String = ""
var consequence_id: int = -1
var target: String = ""     # redirect/split target system
var rule_id: String = ""    # transform rule
var system: String = ""     # crisis system


static func redirect(cid: int, to: String) -> Intervention:
	var i := Intervention.new()
	i.kind = REDIRECT
	i.consequence_id = cid
	i.target = to
	return i


static func split(cid: int, to: String) -> Intervention:
	var i := Intervention.new()
	i.kind = SPLIT
	i.consequence_id = cid
	i.target = to
	return i


static func delay(cid: int) -> Intervention:
	var i := Intervention.new()
	i.kind = DELAY
	i.consequence_id = cid
	return i


static func transform(cid: int, rule: String) -> Intervention:
	var i := Intervention.new()
	i.kind = TRANSFORM
	i.consequence_id = cid
	i.rule_id = rule
	return i


static func crisis(system_id: String) -> Intervention:
	var i := Intervention.new()
	i.kind = CRISIS
	i.system = system_id
	return i


func describe() -> String:
	match kind:
		REDIRECT: return "Redirect C%d -> %s" % [consequence_id, target]
		SPLIT: return "Split C%d -> %s" % [consequence_id, target]
		DELAY: return "Delay C%d" % consequence_id
		TRANSFORM: return "Transform C%d via %s" % [consequence_id, rule_id]
		CRISIS: return "Controlled crisis at %s" % system
	return "?"


func to_dict() -> Dictionary:
	return {"kind": kind, "consequence_id": consequence_id, "target": target, "rule_id": rule_id, "system": system}


static func from_dict(d: Dictionary) -> Intervention:
	var i := Intervention.new()
	i.kind = String(d["kind"])
	i.consequence_id = int(d["consequence_id"])
	i.target = String(d["target"])
	i.rule_id = String(d["rule_id"])
	i.system = String(d["system"])
	return i
