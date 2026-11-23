class_name Msg
extends RefCounted
## Language-neutral message: an English format key plus arguments.
## The simulation stores these; the UI translates the key (and any string
## arguments that are content names) through Loc. English text is still
## produced for logs, tests and run reports.


static func make(key: String, args: Array = []) -> Dictionary:
	return {"k": key, "a": args}


static func en(m: Dictionary) -> String:
	if m.is_empty():
		return ""
	var args: Array = m.get("a", [])
	return String(m["k"]) % args if not args.is_empty() else String(m["k"])
