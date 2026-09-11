class_name FrontierMineralWorld
extends RefCounted
## Lazy, addressable deposits. Saved rules + seed define geology, not visits.
static var _rules: Dictionary={}
static func rules() -> Dictionary:
	if _rules.is_empty():_rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/mineral_world.json"))
	return _rules
static func profile(body: Dictionary,rules: Dictionary) -> Dictionary:
	if body.kind in ["gas_giant","ice_giant"]:return {}
	var options: Array=[]
	for id in rules.profiles:
		if rules.profiles[id].kind==body.kind:options.append(id)
	if int(rules.get("version",1))>=2:options.sort()
	var seed_value: int=int(body.streams.resource)
	var id: String=options[FrontierUniverse.derive(seed_value,"geology")%options.size()]
	if body.get("reference_id","")=="solar:2":id="weathered"
	if int(rules.get("version",1))>=2 and body.has("traits") and body.traits.geology in options:id=body.traits.geology
	var p: Dictionary=rules.profiles[id].duplicate(true)
	if int(rules.get("version",1))>=2:
		var secondary_id: String=options[FrontierUniverse.derive(seed_value,"secondary-geology")%options.size()]
		if secondary_id!=id:
			p.name+=" + "+str(rules.profiles[secondary_id].name)
			for material in rules.profiles[secondary_id].primary:
				if material not in p.primary and material not in p.secondary:p.secondary.append(material)
			for gem in rules.profiles[secondary_id].gems:
				if gem not in p.gems:p.gems.append(gem)
	p.id=id;p.version=1;p.rules=rules
	p.exotic=""
	if int(body.planet_tier)>=int(rules.exotic_min_tier):
		p.exotic=rules.get("exotic_materials",["stellarite_ore","darkstone_ore"])[FrontierUniverse.derive(seed_value,"exotic-family")%2]
	return p
static func enabled(body: Dictionary) -> bool:return not body.get("mineral_profile",{}).is_empty()
static func summary(body: Dictionary) -> String:
	if not FrontierUniverse.landable(body):return "착륙 불가 · 지표 광맥 없음"
	if not enabled(body):return "기존 자원 분포"
	var p: Dictionary=body.mineral_profile
	var labels: PackedStringArray=[]
	for id in p.primary:labels.append(FrontierMinerals.entry(id).name)
	return FrontierGroundExploration.summary(body)+p.name+" · 주력 "+" / ".join(labels)+"\n지하 보석 탐사 가능"+(" · 특이 소재 반응" if not p.exotic.is_empty() else "")
static func region(body: Dictionary,x: int,z: int) -> Array:
	if not enabled(body):return []
	var profile: Dictionary=body.mineral_profile
	var rules: Dictionary=profile.rules
	if absi(x)>int(rules.tile_limit) or absi(z)>int(rules.tile_limit):return []
	var result: Array=[]
	var field:=FrontierSurfaceRegions.field(body)
	for slot in int(rules.surface_slots)+int(rules.underground_slots):
		if body.has("regional_rules") and slot<int(rules.surface_slots):continue
		var id: String="ore1:%d:%d:%d"%[x,z,slot]
		var seed_value: int=FrontierUniverse.derive(int(body.streams.resource),id)
		var below: bool=slot>=int(rules.surface_slots)
		var pool: Array=profile.primary if seed_value%4!=0 else profile.secondary
		var resource: String=pool[FrontierUniverse.derive(seed_value,"material")%pool.size()]
		if below and seed_value%100<int(rules.gem_chance_percent):resource=profile.gems[seed_value%profile.gems.size()]
		if below and not profile.exotic.is_empty() and FrontierUniverse.derive(seed_value,"exotic")%100<int(rules.exotic_chance_percent):resource=profile.exotic
		var px: float=(x+float(FrontierUniverse.derive(seed_value,"x")%8000)/10000.0+.1)*float(rules.tile_size)
		var pz: float=(z+float(FrontierUniverse.derive(seed_value,"z")%8000)/10000.0+.1)*float(rules.tile_size)
		if absf(px)>float(rules.get("region_half_extent",8192)) or absf(pz)>float(rules.get("region_half_extent",8192)):continue
		if body.has("ground_rules") and Vector2(px,pz).length()<float(body.ground_rules.near_resource_radius):continue
		if int(body.get("ground_rules",{}).get("version",0))>=2 and int(body.planet_tier)==2 and resource in ["silicon","phosphate"] and Vector2(px,pz).length()<float(body.ground_rules.expedition.radius):continue
		var depth: float=float(rules.depth_min)+float(FrontierUniverse.derive(seed_value,"depth")%int(rules.depth_max-rules.depth_min+1)) if below else 0.0
		var y: float=maxf(-64,field.height(px,pz)-depth) if below else 0.0
		var capacity:=int(rules.gem_capacity) if FrontierMinerals.entry(resource).category=="gem" else int(rules.base_capacity)+seed_value%int(rules.capacity_spread)
		if int(rules.get("version",1))>=3 and FrontierMinerals.entry(resource).category!="gem":
			capacity+=maxi(0,int(body.planet_tier)-1)*int(rules.capacity_per_tier)+mini(int(rules.capacity_distance_cap),floori(Vector2(px,pz).length()/1000.0)*int(rules.capacity_per_km))
		result.append({"id":id,"resource":resource,"required_tier":int(rules.get("resource_tiers",rules().resource_tiers).get(resource,1)),"capacity":capacity,"position":[px,y,pz],"underground":below,"quality":1+FrontierUniverse.derive(seed_value,"quality")%int(rules.get("quality_levels",3))})
	if body.has("regional_rules"):result.append_array(FrontierSurfaceRegions.surface(body,x,z))
	result.append_array(preload("res://scripts/domain/deep_deposits.gd").region(body,field,x,z))
	return result
static func nearby(body: Dictionary,point: Vector3=Vector3.ZERO,cache: Variant=null) -> Array:
	if not enabled(body):return []
	var rules: Dictionary=body.mineral_profile.rules
	var x: int=floori(point.x/float(rules.tile_size));var z: int=floori(point.z/float(rules.tile_size))
	var result: Array=[]
	for dx in range(-int(rules.view_radius),int(rules.view_radius)+1):
		for dz in range(-int(rules.view_radius),int(rules.view_radius)+1):
			var key:=Vector2i(x+dx,z+dz)
			if cache==null:result.append_array(region(body,key.x,key.y))
			else:
				if not cache.has(key):cache[key]=region(body,key.x,key.y)
				result.append_array(cache[key])
	return result
static func find(body: Dictionary,id: String) -> Dictionary:
	var parts: PackedStringArray=id.split(":")
	if parts.size()!=4 or parts[0]!="ore1":return {}
	for i in range(1,4):
		if not parts[i].is_valid_int() or str(int(parts[i]))!=parts[i]:return {}
	for row in region(body,int(parts[1]),int(parts[2])):
		if row.id==id:return row
	return {}
static func tier(id: String) -> int:
	return int(rules().resource_tiers.get(id,1))
static func point(field: FrontierTerrainField,row: Dictionary) -> Vector3:
	if not row.get("underground",false):return FrontierExpeditionBusiness.ground(field,row.position[0],row.position[2])
	var p:=Vector3(row.position[0],row.position[1],row.position[2])
	# A buried deposit is neither visible nor mineable until its upper face is exposed.
	if field.density(p+Vector3.UP*.6)>0:return Vector3.INF
	for step in 9:
		var floor_point: Vector3=p-Vector3.UP*float(step)*.5
		if field.density(floor_point-Vector3.UP*.4)>0 and field.density(floor_point+Vector3.UP*.3)<=0:return floor_point
	return Vector3.INF
