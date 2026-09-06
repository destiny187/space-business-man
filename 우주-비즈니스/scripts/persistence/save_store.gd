class_name FrontierSaveStore
extends RefCounted

var path: String
var last_error: String = ""

func _init(save_path: String = "user://campaign.json") -> void:
	path = save_path

func write(state: Dictionary) -> bool:
	last_error = ""
	var invalid: String = validate(state)
	if not invalid.is_empty():
		last_error = invalid
		return false
	var serialized: String = JSON.stringify(state,"",true,true)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "저장 파일을 만들 수 없습니다: %s" % error_string(FileAccess.get_open_error())
		return false
	file.store_string(serialized)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		last_error = "저장 실패: %s" % error_string(write_error)
		return false
	if JSON.parse_string(FileAccess.get_file_as_string(path + ".tmp")) == null:
		last_error = "저장 데이터 확인 실패"
		return false
	if FileAccess.file_exists(path) and not _parse(path).is_empty():
		var backup_error: Error = DirAccess.copy_absolute(path, path + ".bak")
		if backup_error != OK:
			last_error = "백업 저장 실패"
			return false
	var rename_error: Error = DirAccess.rename_absolute(path + ".tmp", path)
	if rename_error != OK:
		last_error = "저장 파일 교체 실패: %s" % error_string(rename_error)
		return false
	return true

func read_state() -> Dictionary:
	last_error = ""
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parsed: Dictionary = _parse(candidate)
		if not parsed.is_empty():
			if candidate.ends_with(".bak"):
				last_error = "최근 정상 백업에서 복구했습니다."
			return parsed
	last_error = "유효한 저장 파일이 없습니다."
	return {}

func _parse(candidate: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(candidate)) != OK: return {}
	if not parser.data is Dictionary or not validate(parser.data).is_empty(): return {}
	return parser.data

static func validate(state: Dictionary) -> String:
	return FrontierSaveSchema.validate(state)
