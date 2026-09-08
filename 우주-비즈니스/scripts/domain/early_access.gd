class_name FrontierEarlyAccess
extends RefCounted
## Access rules are separate from the historical business ledger hash.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/early_access.json"))
	return _config
static func available(ledger: Dictionary,technology: String) -> bool:
	return technology.is_empty() or technology in config().open_technologies or technology in ledger.get("technologies",[])
