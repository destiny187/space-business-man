class_name FrontierWorldStore
extends RefCounted

var path: String
var last_error := ""

func _init(save_path: String = "user://exploration_world.json") -> void:
	path = save_path

func write(state: Dictionary) -> bool:
	last_error = FrontierUniverse.validate_world(state)
	if not last_error.is_empty(): return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "탐험 저장 파일을 열 수 없습니다."
		return false
	file.store_string(JSON.stringify(state, "", true, true))
	file.flush()
	var result: Error = file.get_error()
	file.close()
	if result != OK or _read(path + ".tmp").is_empty():
		last_error = "탐험 임시 저장 검증에 실패했습니다."
		return false
	if FileAccess.file_exists(path):
		var backup_path: String = path + ".bak" if not _read(path).is_empty() else path + ".preserved-%d" % Time.get_ticks_usec()
		if DirAccess.copy_absolute(path, backup_path) != OK:
			last_error = "탐험 백업을 만들 수 없습니다."
			return false
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		last_error = "탐험 저장을 교체하지 못했습니다."
		return false
	return true

func read_state() -> Dictionary:
	last_error = ""
	for candidate in [path, path + ".bak"]:
		var state: Dictionary = _read(candidate)
		if not state.is_empty():
			if candidate != path: last_error = "탐험 백업에서 복구했습니다."
			return state
	last_error = "유효한 탐험 저장이 없습니다. 기존 사업 저장은 별도로 보존됩니다."
	return {}

func _read(candidate: String) -> Dictionary:
	if not FileAccess.file_exists(candidate): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(candidate)) != OK: return {}
	return parser.data if FrontierUniverse.validate_world(parser.data).is_empty() else {}
