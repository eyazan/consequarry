class_name CivilizationSystem
extends RefCounted
## One of the six interconnected systems (energy, agriculture, ...).

var id: String = ""
var health: int = 50
var max_health: int = 100
var base_capacity: int = 12
var capacity_used: int = 0
var collapsed: bool = false
var crisis_cooldown: int = 0
var scarred: bool = false


func capacity(memory: WorldMemory) -> int:
	var loss := memory.capacity_loss(id)
	return maxi(4, base_capacity - loss)


func remaining_capacity(memory: WorldMemory) -> int:
	return maxi(0, capacity(memory) - capacity_used)


func apply_delta(delta: int) -> int:
	## Returns overflow above max_health (only for positive deltas).
	if collapsed:
		return maxi(0, delta)
	var before := health
	health = clampi(health + delta, 0, max_health)
	var overflow := 0
	if delta > 0:
		overflow = maxi(0, before + delta - max_health)
	if health <= 0:
		health = 0
		collapsed = true
	return overflow


func to_dict() -> Dictionary:
	return {"id": id, "health": health, "max_health": max_health, "base_capacity": base_capacity,
		"capacity_used": capacity_used, "collapsed": collapsed, "crisis_cooldown": crisis_cooldown,
		"scarred": scarred}


static func from_dict(d: Dictionary) -> CivilizationSystem:
	var s := CivilizationSystem.new()
	s.id = String(d["id"])
	s.health = int(d["health"])
	s.max_health = int(d["max_health"])
	s.base_capacity = int(d["base_capacity"])
	s.capacity_used = int(d["capacity_used"])
	s.collapsed = bool(d["collapsed"])
	s.crisis_cooldown = int(d["crisis_cooldown"])
	s.scarred = bool(d["scarred"])
	return s
