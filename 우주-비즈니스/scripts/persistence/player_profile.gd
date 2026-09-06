class_name FrontierPlayerProfile
extends RefCounted
var path: String
var data: Dictionary={}
var error:=""
func _init(file_path: String="user://player_profile.json") -> void:path=file_path
static func token(bytes: int=16) -> String:return Crypto.new().generate_random_bytes(bytes).hex_encode()
static func identifier(value: Variant,length: int=32) -> bool:
	if not value is String or value.length()!=length:return false
	for character in value:
		if character not in "0123456789abcdef":return false
	return true
static func new_character(name: String,tint: int=0) -> Dictionary:
	var equipment: Array=[]
	for definition in ["pressure_suit","survey_scanner","rock_tool"]:
		equipment.append({"id":token(),"definition":definition,"grade":"standard","traits":[]})
	return {"character_id":token(),"name":name,"tint":tint,"equipment":equipment}
static func validate_character(value: Variant) -> String:
	if not value is Dictionary or not identifier(value.get("character_id")):return "캐릭터 ID 오류"
	if not value.get("name") is String or value.name.strip_edges().is_empty() or value.name.length()>24:return "캐릭터 이름 오류"
	for index in value.name.length():
		if value.name.unicode_at(index)<32 or value.name.unicode_at(index)==127:return "캐릭터 이름에 제어 문자를 사용할 수 없습니다."
	if not FrontierUniverse._finite(value.get("tint"),0,5) or value.tint!=floorf(value.tint):return "캐릭터 외형 오류"
	if not value.get("equipment") is Array or value.equipment.size()!=3:return "반입 장비 목록 오류"
	var cfg: Dictionary=FrontierCrewWorld.config()
	var ids: Dictionary={};var definitions: Dictionary={}
	for item in value.equipment:
		if not item is Dictionary or not identifier(item.get("id")) or ids.has(item.id):return "장비 식별자 오류"
		if item.get("definition") not in cfg.equipment or definitions.has(item.definition):return "현재 버전이 지원하지 않는 장비입니다. 원본은 보존됩니다."
		if item.get("grade") not in cfg.grades or not item.get("traits") is Array or item.traits.size()>3:return "장비 등급·특성 오류"
		var traits: Dictionary={}
		for gear_trait in item.traits:
			if gear_trait not in cfg.traits or traits.has(gear_trait):return "지원하지 않는 장비 특성입니다."
			traits[gear_trait]=true
		ids[item.id]=true;definitions[item.definition]=true
	return ""
func ensure(name: String="탐험가") -> bool:
	if FileAccess.file_exists(path):
		var parser:=JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path))!=OK or not parser.data is Dictionary:error="개인 프로필을 읽을 수 없습니다. 원본을 보존했습니다.";return false
		data=parser.data
		if data.get("version")!=1 or not data.get("sessions") is Dictionary:error="개인 프로필 버전 오류";return false
		error=validate_character(data.get("character"))
		if not error.is_empty():return false
		for world_id in data.sessions:
			if not identifier(world_id) or not identifier(data.sessions[world_id],64):error="재접속 자격 기록 오류";return false
		return true
	data={"version":1,"character":new_character(name),"sessions":{}}
	return save()
func save() -> bool:
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:error="개인 프로필을 저장할 수 없습니다.";return false
	file.store_string(JSON.stringify(data));file.flush();var result:=file.get_error();file.close()
	if result!=OK:error="개인 프로필 기록 오류";return false
	if FileAccess.file_exists(path) and DirAccess.copy_absolute(path,path+".bak")!=OK:error="개인 프로필 백업 오류";return false
	if DirAccess.rename_absolute(path+".tmp",path)!=OK:error="개인 프로필 교체 오류";return false
	return true
func remember(world_id: String,capability: String) -> bool:
	if not identifier(world_id) or not identifier(capability,64):error="호스트 재접속 자격 형식 오류";return false
	var previous: Dictionary=data.duplicate(true)
	data.sessions[world_id]=capability
	if save():return true
	data=previous;return false
