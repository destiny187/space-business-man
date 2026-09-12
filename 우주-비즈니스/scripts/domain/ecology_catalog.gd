class_name FrontierEcologyCatalog
extends RefCounted
## Authored identities stay independent of JSON ordering and visual resource loading.
static var _forms: Dictionary={}
static var _looks: Dictionary={}
static var _pools: Dictionary={}
static var _config: Dictionary={}
static var _signature: String=""
static var _extension_signature: String=""
static var _visual_compatibility: Dictionary={}
static var _expanded_pools: Dictionary={}
static var _flora_pools: Dictionary={}
static var _flora_signature: String=""
static var _biota_signature: String=""
static var _biota_habitats: Dictionary={}
static var _appearance_rows: Array=[]
static var _expansion: Dictionary={}

static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/ecology.json"))
	return _config

static func expansion() -> Dictionary:
	if _expansion.is_empty():_expansion=JSON.parse_string(FileAccess.get_file_as_string("res://data/ecology_expansion.json"))
	return _expansion

static func placement_config(body: Dictionary) -> Dictionary:
	var result:=config().duplicate(true)
	for key in ["active_radius","max_actors"]:
		if body.get("ecology_rules",{}).has(key):result[key]=body.ecology_rules[key]
	return result

static func ground_form(row: Dictionary) -> bool:
	return row.get("locomotion_medium","") in ["ground","surface_air"] or row.get("family","") in config().ground_families

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
	_expanded_pools=_pools.duplicate(true)
	var extra_forms:="res://data/bestiary/xenofauna_forms.json"
	var extra_looks:="res://data/bestiary/xenofauna_appearances.json"
	_appearance_rows=JSON.parse_string(looks_text).appearances
	if FileAccess.file_exists(extra_forms) and FileAccess.file_exists(extra_looks):
		var extension_text:=FileAccess.get_file_as_string(extra_forms)
		var appearance_text:=FileAccess.get_file_as_string(extra_looks)
		_extension_signature=(extension_text.sha256_text()+appearance_text.sha256_text()).sha256_text()
		for row in JSON.parse_string(extension_text).forms:
			_forms[row.id]=row
			if not ground_form(row):continue
			var key: String=row.environment+":"+row.category
			if not _expanded_pools.has(key):_expanded_pools[key]=[]
			_expanded_pools[key].append(row.id)
		_appearance_rows.append_array(JSON.parse_string(appearance_text).appearances)
	for pool in _expanded_pools.values():pool.sort()
	_flora_pools=_expanded_pools.duplicate(true)
	var flora_forms:="res://data/bestiary/xenoflora_forms.json"
	var flora_looks:="res://data/bestiary/xenoflora_appearances.json"
	if FileAccess.file_exists(flora_forms) and FileAccess.file_exists(flora_looks):
		var forms_extension:=FileAccess.get_file_as_string(flora_forms)
		var looks_extension:=FileAccess.get_file_as_string(flora_looks)
		_flora_signature=(forms_extension.sha256_text()+looks_extension.sha256_text()).sha256_text()
		for row in JSON.parse_string(forms_extension).forms:
			_forms[row.id]=row
			if not ground_form(row):continue
			var key: String=row.environment+":"+row.category
			if not _flora_pools.has(key):_flora_pools[key]=[]
			_flora_pools[key].append(row.id)
		_appearance_rows.append_array(JSON.parse_string(looks_extension).appearances)
	for pool in _flora_pools.values():pool.sort()
	var biota_forms:="res://data/bestiary/biota_forms.json"
	var biota_looks:="res://data/bestiary/biota_appearances.json"
	if FileAccess.file_exists(biota_forms) and FileAccess.file_exists(biota_looks):
		var biota_text:=FileAccess.get_file_as_string(biota_forms)
		var variants_text:=FileAccess.get_file_as_string(biota_looks)
		var habitat_text:=FileAccess.get_file_as_string("res://data/bestiary/biota_habitats.json")
		_biota_signature=(biota_text.sha256_text()+variants_text.sha256_text()+habitat_text.sha256_text()).sha256_text()
		for row in JSON.parse_string(biota_text).forms:_forms[row.id]=row
		_appearance_rows.append_array(JSON.parse_string(variants_text).appearances)
	for row in _appearance_rows:
		if not _looks.has(row.form_id):_looks[row.form_id]={}
		_looks[row.form_id][row.id]=row

static func signature() -> String:
	prepare();return _signature

static func extension_signature() -> String:
	prepare();return _extension_signature

static func extension_compatible(saved: String) -> bool:
	var current:=extension_signature()
	if saved==current:return true
	if _visual_compatibility.is_empty():_visual_compatibility=JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/catalog_compatibility.json"))
	# A reviewed pair of exact digests, never a blanket bypass for future catalogue edits.
	return saved in _visual_compatibility.xenofauna.get(current,[])

static func flora_signature() -> String:
	prepare();return _flora_signature

static func biota_signature() -> String:
	prepare();return _biota_signature

static func look_for_seed(id: String,seed_value: int) -> String:
	prepare();var choices: Array=_looks[id].keys();choices.sort()
	return str(choices[seed_value%choices.size()])

static func habitat(definition: Dictionary) -> Dictionary:
	if definition.get("environment","")=="gas_cloud" and not definition.has("adaptation_id"):
		if _biota_habitats.is_empty():_biota_habitats=JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/biota_habitats.json")).profiles
		return _biota_habitats.gas_cloud
	if definition.has("adaptation_id"):
		if _biota_habitats.is_empty():_biota_habitats=JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/biota_habitats.json")).profiles
		var result: Dictionary=_biota_habitats[definition.adaptation_id].duplicate(true)
		if definition.get("environment","")=="cave":result.temperature=[2,32];result.moisture=[.25,.9];result.label="지하 "+str(result.label)
		return result
	return config().habitats.get(definition.get("environment","basalt"),config().habitats.basalt)

static func all_forms() -> Array:
	prepare();return _forms.values()

static func all_appearances() -> Array:
	prepare();return _appearance_rows

static func model_key(definition: Dictionary) -> String:
	return str(definition.lods.near.path).trim_prefix("우주-비즈니스/assets/models/").trim_suffix(".glb")

static func choose_diverse(seed_value: int,environment: String,category: String,count: int,flora_enabled: bool=false) -> Array:
	prepare()
	var pools: Dictionary=_flora_pools if flora_enabled else _expanded_pools
	var pool: Array=pools.get(environment+":"+category,[]).duplicate()
	pool.sort_custom(func(a,b):return FrontierUniverse.derive(seed_value,a)<FrontierUniverse.derive(seed_value,b))
	var result: Array=[];var families: Dictionary={}
	for unique in [true,false]:
		for id in pool:
			if result.size()>=count:return result
			if unique and families.has(_forms[id].family):continue
			if result.any(func(row):return row.form_id==id):continue
			var looks: Array=_looks[id].keys();looks.sort()
			result.append({"form_id":id,"look_id":looks[FrontierUniverse.derive(seed_value,"appearance:"+id)%looks.size()]})
			families[_forms[id].family]=true
	return result

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
