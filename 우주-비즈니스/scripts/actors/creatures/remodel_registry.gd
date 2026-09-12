extends RefCounted
## Presentation overlay. Original species, origins, combat data and save hashes are untouched.
static var entries: Dictionary={}
static var loaded:=false

static func entry(form: Dictionary) -> Dictionary:
	if not loaded:
		loaded=true
		var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/creature_remodel_runtime.json"))
		for path in manifest.sources:
			for row in JSON.parse_string(FileAccess.get_file_as_string(path)).forms:
				if row.source_id in manifest.enabled_ground_species:entries[row.source_id]=row
	return entries.get(form.get("id",""),{})

static func path(form: Dictionary,lod: String) -> String:
	var row:=entry(form)
	return "res://"+str((row if not row.is_empty() else form).lods[lod].path).trim_prefix("우주-비즈니스/")

static func bounds(form: Dictionary,lod: String="near") -> Dictionary:
	var row:=entry(form)
	if row.is_empty():return form.geometry[lod]
	var geometry: Dictionary=row.lods[lod].duplicate()
	geometry.floor_y=geometry.min[1]
	return geometry
