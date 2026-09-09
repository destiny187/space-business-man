class_name FrontierWorldStore
extends RefCounted

var path: String
var last_error := ""

func _init(save_path: String = "user://exploration_world.json") -> void:
	path = save_path

# Only periodic checkpoints use the worker. Transactions join it before writing,
# so an older checkpoint can never replace a newer acknowledged transaction.
var checkpoint_thread: Thread
var verified_digest: String=""

func write(state: Dictionary) -> bool:
	if not finish_pending():return false
	last_error=FrontierUniverse.validate_world(state)
	if not last_error.is_empty():return false
	return _accept_write(_write_snapshot(path,state,verified_digest))

func begin_checkpoint(state: Dictionary) -> bool:
	if checkpoint_thread!=null:
		if checkpoint_thread.is_alive():return true # One bounded job; next checkpoint uses the latest state.
		if not finish_pending():return false
	last_error=FrontierUniverse.validate_world(state)
	if not last_error.is_empty():return false
	var frozen:=state.duplicate(true)
	checkpoint_thread=Thread.new()
	var result:=checkpoint_thread.start(_write_snapshot.bind(path,frozen,verified_digest))
	if result!=OK:
		checkpoint_thread=null;last_error="체크포인트 저장 작업을 시작할 수 없습니다.";return false
	return true

func poll_checkpoint() -> bool:
	if checkpoint_thread==null or checkpoint_thread.is_alive():return true
	return finish_pending()

func finish_pending() -> bool:
	if checkpoint_thread==null:return true
	var result: Dictionary=checkpoint_thread.wait_to_finish()
	checkpoint_thread=null
	return _accept_write(result)

func _accept_write(result: Dictionary) -> bool:
	last_error=result.get("error","")
	if not last_error.is_empty():return false
	verified_digest=result.digest
	return true

# Pure JSON/file work only. Domain validation and mutable configuration caches
# stay on the main thread; the worker owns a deep snapshot and no scene objects.
static func _write_snapshot(save_path: String,state: Dictionary,previous_digest: String) -> Dictionary:
	var encoded:=JSON.stringify(state,"",true,true)
	var file:=FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file==null:return {"error":"탐험 저장 파일을 열 수 없습니다."}
	file.store_string(encoded);file.flush()
	var result:=file.get_error();file.close()
	var recorded:=FileAccess.get_file_as_string(save_path+".tmp")
	# Exact readback plus JSON decoding preserves serialization/write validation
	# without re-running the full domain validator for identical snapshot bytes.
	var parser:=JSON.new()
	if result!=OK or recorded!=encoded or parser.parse(recorded)!=OK or not parser.data is Dictionary:
		return {"error":"탐험 임시 저장 검증에 실패했습니다."}
	if FileAccess.file_exists(save_path):
		var old:=FileAccess.get_file_as_string(save_path)
		var known_good:=not previous_digest.is_empty() and old.sha256_text()==previous_digest
		var backup_path:=save_path+".bak" if known_good else save_path+".preserved-%d"%Time.get_ticks_usec()
		if DirAccess.copy_absolute(save_path,backup_path)!=OK:return {"error":"탐험 백업을 만들 수 없습니다."}
	if DirAccess.rename_absolute(save_path+".tmp",save_path)!=OK:return {"error":"탐험 저장을 교체하지 못했습니다."}
	return {"digest":encoded.sha256_text()}

func read_state() -> Dictionary:
	if not finish_pending():return {}
	last_error = ""
	for candidate in [path, path + ".bak"]:
		var state: Dictionary = _read(candidate)
		if not state.is_empty():
			if candidate != path: last_error = "탐험 백업에서 복구했습니다."
			return state
	if last_error.is_empty():last_error = "유효한 탐험 저장이 없습니다. 기존 사업 저장은 별도로 보존됩니다."
	return {}

func _read(candidate: String) -> Dictionary:
	if not FileAccess.file_exists(candidate): return {}
	var parser := JSON.new()
	var encoded:=FileAccess.get_file_as_string(candidate)
	if parser.parse(encoded) != OK: return {}
	var error: String=FrontierUniverse.validate_world(parser.data)
	if not error.is_empty():
		if last_error.is_empty():last_error=error
		return {}
	if candidate==path:verified_digest=encoded.sha256_text()
	FrontierExpeditionResearch.ensure(parser.data)
	return parser.data

func has_history() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak")
