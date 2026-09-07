class_name FrontierCelestialNames
extends RefCounted
## English proper-name presentation; IDs and generated physical data stay unchanged.
static var _rules: Dictionary={}
static func rules() -> Dictionary:
	if _rules.is_empty():_rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/celestial_names.json"))
	return _rules
static func system_name(seed_value: int,index: int) -> String:
	if index==0:return "Sol"
	var names: Array=rules().star_names
	return "%s %05d"%[names[FrontierUniverse.derive(seed_value,"english-name-v1")%names.size()],index+1]
static func planet_name(system_name_value: String,orbit: int) -> String:
	return system_name_value+" "+String.chr(98+orbit)
