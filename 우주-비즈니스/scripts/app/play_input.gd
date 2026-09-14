class_name FrontierPlayInput
extends RefCounted
## Local action map. Unrelated contexts may reuse a physical key.
static var overrides: Dictionary={}
static var entries: Dictionary={}
static var toggles: Dictionary={}
static var held: Dictionary={}
static func definitions() -> Dictionary:
	if entries.is_empty():entries=JSON.parse_string(FileAccess.get_file_as_string("res://data/play_input.json"))
	return entries
static func default_code(id: String) -> int:
	var value: Variant=definitions()[id].key
	return OS.find_keycode_from_string(value) if value is String else int(value)
static func code(id: String) -> int:return int(overrides.get(id,default_code(id)))
static func text(id: String) -> String:return OS.get_keycode_string(code(id))
static func pressed(id: String) -> bool:return Input.is_physical_key_pressed(code(id))
static func matches(event: InputEvent,id: String) -> bool:return event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==code(id)
static func action(event: InputEvent,ids: Array) -> String:
	for id in ids:
		if matches(event,id):return id
	return ""
static func configure(value: Dictionary) -> void:
	overrides=value.duplicate();toggles.clear();held.clear()
static func conflict(values: Dictionary,id: String,key: int) -> String:
	if key<=0 or key in [KEY_ESCAPE,KEY_F10]:return "Esc와 F10은 메뉴 열기·취소에 사용합니다."
	for other in definitions():
		if other==id or int(values.get(other,default_code(other)))!=key:continue
		var contexts: Array=definitions()[id].contexts
		var others: Array=definitions()[other].contexts
		if "global" in contexts or "global" in others or contexts.any(func(c):return c in others):return str(definitions()[other].label)+"에 이미 사용 중인 키입니다."
	return ""
static func sanitize(value: Variant) -> Dictionary:
	var result: Dictionary={}
	if not value is Dictionary:return result
	for id in definitions():
		var key: Variant=value.get(id)
		if (key is int or key is float) and is_finite(float(key)) and key==floorf(key) and key>0 and key<=KEY_SPECIAL+0xFFFF and key not in [KEY_ESCAPE,KEY_F10]:result[id]=int(key)
	# Validate complete mappings, including two keys exchanged by the player.
	for id in result.keys():
		if not conflict(result,id,result[id]).is_empty():result.erase(id)
	return result
static func rebind(values: Dictionary,id: String,key: int) -> String:
	if not definitions().has(id):return "없는 조작입니다."
	var reason:=conflict(values,id,key)
	if not reason.is_empty():return reason
	values[id]=key;configure(values);return ""
static func release_toggles() -> void:
	toggles.clear()
	held["sprint"]=pressed("sprint");held["aim"]=Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
static func state(id: String,down: bool,enabled: bool,toggle: bool) -> bool:
	if not enabled:toggles[id]=false;held[id]=down;return false
	if down and not held.get(id,false):toggles[id]=not toggles.get(id,false)
	held[id]=down
	return bool(toggles.get(id,false)) if toggle else down
static func hint(source: String,context: String) -> String:
	# Simultaneous replacement prevents a remapped key from being replaced twice.
	var mapping: Dictionary={}
	for id in definitions():
		var row: Dictionary=definitions()[id]
		if "global" in row.contexts or context in row.contexts:mapping[OS.get_keycode_string(default_code(id))]=text(id)
	var regex:=RegEx.new();regex.compile("(?<![A-Za-z0-9_])(?:Space|Shift|Ctrl|Alt|Tab|F8|[A-Z])(?![A-Za-z0-9_])")
	var result:="";var offset:=0
	for found in regex.search_all(source):
		result+=source.substr(offset,found.get_start()-offset)+str(mapping.get(found.get_string(),found.get_string()));offset=found.get_end()
	return result+source.substr(offset)
