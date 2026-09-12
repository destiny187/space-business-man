extends RefCounted
## Presentation overlay. Original species, origins, combat data and save hashes are untouched.
static var entries: Dictionary={}
static var loaded:=false
static var entry_paths: Dictionary={}
static var individual_reads:=0

static func entry(form: Dictionary) -> Dictionary:
	if not loaded:
		loaded=true
		var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/creature_remodel_runtime.json"))
		entry_paths=manifest.get("entry_paths",{})
		for path in manifest.sources:
			for row in JSON.parse_string(FileAccess.get_file_as_string(path)).forms:
				if row.source_id in manifest.enabled_ground_species or row.source_id in manifest.get("enabled_air_species",[]):entries[row.source_id]=row
	var id: String=form.get("id","")
	if not entries.has(id) and entry_paths.has(id):
		var row: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(entry_paths[id]))
		assert(row.source_id==id)
		entries[id]=row;individual_reads+=1
	var result: Dictionary=entries.get(id,{})
	# A source GLB can exist before Godot finishes importing it. Keep the previous
	# playable model until both replacement LODs can actually be loaded.
	for asset in result.get("lods",{}).values():
		if not ResourceLoader.exists("res://"+str(asset.path).trim_prefix("우주-비즈니스/")):return {}
	return result

static func path(form: Dictionary,lod: String) -> String:
	var row:=entry(form)
	return "res://"+str((row if not row.is_empty() else form).lods[lod].path).trim_prefix("우주-비즈니스/")

static func bounds(form: Dictionary,lod: String="near") -> Dictionary:
	var row:=entry(form)
	if row.is_empty():return form.geometry[lod]
	var geometry: Dictionary=row.lods[lod].duplicate()
	geometry.floor_y=geometry.min[1]
	return geometry
