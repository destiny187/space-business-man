class_name FrontierEcologyCatalog
extends RefCounted
## Authored identities stay independent of JSON ordering and visual resource loading.
static var _forms: Dictionary={}
static var _looks: Dictionary={}
static var _pools: Dictionary={}
static var _config: Dictionary={}
static var _signature: String=""

static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/ecology.json"))
	return _config

static func prepare() -> void:
	if not _forms.is_empty():return
	var forms_text:=FileAccess.get_file_as_string("res://data/bestiary/forms.json")
	var looks_text:=FileAccess.get_file_as_string("res://data/bestiary/appearances.json")
	_signature=(forms_text.sha256_text()+looks_text.sha256_text()).sha256_text()
	for row in JSON.parse_string(forms_text).forms:
		_forms[row.id]=row
		if row.family not in config().ground_families:continue
		var key: String=row.environment+":"+row.category
		if not _pools.has(key):_pools[key]=[]
		_pools[key].append(row.id)
	for pool in _pools.values():pool.sort()
	for row in JSON.parse_string(looks_text).appearances:
		if not _looks.has(row.form_id):_looks[row.form_id]={}
		_looks[row.form_id][row.id]=row

static func signature() -> String:
	prepare();return _signature

static func form(id: String) -> Dictionary:
	prepare();return _forms.get(id,{})

static func look(form_id: String,id: String) -> Dictionary:
	prepare();return _looks.get(form_id,{}).get(id,{})

static func choose(seed_value: int,environment: String,category: String) -> Dictionary:
	prepare()
	var pool: Array=_pools.get(environment+":"+category,[])
	if pool.is_empty():return {}
	var id: String=pool[FrontierUniverse.derive(seed_value,"form")%pool.size()]
	var looks: Array=_looks[id].keys();looks.sort()
	return {"form_id":id,"look_id":looks[FrontierUniverse.derive(seed_value,"appearance")%looks.size()]}
