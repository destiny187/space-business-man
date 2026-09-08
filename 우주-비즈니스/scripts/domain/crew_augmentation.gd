class_name FrontierCrewAugmentation
extends RefCounted
## Character growth belongs to the host world's member, not equipped items or profiles.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/crew_augmentation.json"))
	return _config
static func create(mobility: int=0) -> Dictionary:
	return {"version":1,"levels":{"mobility":mobility,"combat":0,"vitality":0}}
static func ensure(member: Dictionary) -> void:
	# Run after save validation. Retain the paid speed once, independently of bag upgrades.
	if not member.has("augmentation"):member.augmentation=create(FrontierProgressionResearch.personal(member,"logistics"))
static func level(member: Dictionary,key: String) -> int:
	if not member.has("augmentation"):
		return FrontierProgressionResearch.personal(member,"logistics") if key=="mobility" else 0
	return int(member.augmentation.levels.get(key,0))
static func multiplier(member: Dictionary,key: String) -> float:
	return 1.0+float(config().fields[key].increment)*level(member,key)
static func maximum_health(member: Dictionary) -> float:
	return float(FrontierCrewVitals.config().maximum_health)*multiplier(member,"vitality")
static func validate(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=2 or value.get("version")!=1:return false
	var levels: Variant=value.get("levels")
	if not levels is Dictionary or levels.size()!=config().fields.size():return false
	for key in config().fields:
		if not FrontierExpeditionBusiness.integer(levels.get(key),0,int(config().maximum_level)):return false
	return true
