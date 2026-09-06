class_name FrontierMinerals
extends RefCounted
## Seed-generation metadata, separate from the active economy's legacy resource table.
## Tags describe candidate habitats, not a finalized distribution or abundance rule.
static var _data: Dictionary = {}
static func all() -> Dictionary:
	if _data.is_empty():
		_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/minerals.json"))
	return _data.resources
static func entry(id: String) -> Dictionary:
	return all().get(id,{})
static func candidates(geology: Array,depth: String,landable: bool=true) -> Array[String]:
	var result: Array[String]=[]
	if not landable:return result
	for id in all():
		var row: Dictionary=entry(id)
		if depth not in row.depth_tags:continue
		for tag in geology:
			if tag in row.geology_tags:
				result.append(id);break
	result.sort()
	return result

## Version 1 appearance is derived, never rolled from a client's global RNG.
## Dedicated salts keep rotation/scale stable when unrelated generation changes.
static func appearance(resource_id: String,planet_seed: int,vein_id: String) -> Dictionary:
	var row: Dictionary=entry(resource_id)
	if row.is_empty():return {}
	var key: String="mineral-visual-v1:"+resource_id+":"+vein_id
	var variants: Array=row.get("variants",[{"id":"a","model":row.model}])
	var variant: Dictionary=variants[FrontierUniverse.derive(planet_seed,key+":shape")%variants.size()]
	var yaw: float=float(FrontierUniverse.derive(planet_seed,key+":yaw")%1000000)/1000000.0*TAU
	var size: float=lerpf(.85,1.15,float(FrontierUniverse.derive(planet_seed,key+":size")%1000000)/999999.0)
	return {"version":1,"variant":variant.id,"model":variant.model,"yaw":yaw,"scale":size}

static func apply_appearance(visual: Node3D,value: Dictionary,base_scale: float=1.0) -> void:
	if value.is_empty():return
	visual.rotation.y=float(value.yaw)
	visual.scale=Vector3.ONE*base_scale*float(value.scale)
	visual.set_meta("original_scale",visual.scale)
