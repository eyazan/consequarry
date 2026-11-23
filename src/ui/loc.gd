class_name Loc
extends RefCounted
## Presentation-side translation helpers. Keys are the English source strings
## (localization/strings.csv). Simulation code never calls this.


static func t(s: String) -> String:
	return String(TranslationServer.translate(s))


## Translates a Msg (key + args); string arguments are translated too, since
## they are content names such as "Energy" or "Flood".
static func m(msg: Dictionary) -> String:
	if msg.is_empty():
		return ""
	if msg.has("inner"):
		return t(String(msg["k"])) % [m(msg["inner"])]
	var args: Array = []
	for a in msg.get("a", []):
		args.append(t(a) if a is String else a)
	var key := t(String(msg["k"]))
	return key % args if not args.is_empty() else key


static func sys(id: String) -> String:
	return t(String(ContentDB.system_def(id).get("name", id)))


static func typ(id: String) -> String:
	return t(String(ContentDB.type_def(id).get("name", id)))


static func event(id: String) -> String:
	return t(String(ContentDB.event_def(id).get("name", id)))


static func event_text(id: String) -> String:
	return t(String(ContentDB.event_def(id).get("text", "")))


static func scenario(id: String) -> String:
	return t(String(ContentDB.scenario_def(id).get("name", id)))


static func scenario_desc(id: String) -> String:
	return t(String(ContentDB.scenario_def(id).get("description", "")))


static func source(key: String) -> String:
	return m(SimulationEngine.source_msg(key))


## A world-memory chronicle entry (new entries carry key/args; old saves only text).
static func note(entry: Dictionary) -> String:
	if entry.has("k"):
		return m({"k": entry["k"], "a": entry.get("a", [])})
	return t(String(entry.get("text", "")))


static func outcome(w: WorldState) -> String:
	return m(w.outcome_msg) if not w.outcome_msg.is_empty() else t(w.outcome_reason)


## Locale-aware upper case (Turkish dotted/dotless i).
static func upper(s: String) -> String:
	if TranslationServer.get_locale().begins_with("tr"):
		s = s.replace("i", "İ").replace("ı", "I")
	return s.to_upper()
