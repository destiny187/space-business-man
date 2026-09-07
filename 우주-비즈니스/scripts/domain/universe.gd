class_name FrontierUniverse
extends RefCounted
## A bounded logical address space. No planet list is allocated or saved.
const CONFIG_PATH := "res://data/galaxy.json"
const STREAMS := ["terrain", "resource", "discovery", "ecology", "civilization", "tier"]

static func config() -> Dictionary:
	var value: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	value.system_rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/system_diversity.json"))
	value.planet_rules=FrontierPlanetTraits.rules().duplicate(true)
	value.resource_rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/mineral_world.json"))
	return value

static func derive(seed_value: int, stream_name: String) -> int:
	return ("%d:%s" % [seed_value, stream_name]).sha256_text().substr(0, 8).hex_to_int() & 0x7fffffff

static func pick_tier(seed_value: int, weights: Array) -> int:
	var roll: int = seed_value % 100
	for i in weights.size():
		roll -= int(weights[i])
		if roll < 0: return i + 1
	return 1

static func generate(seed_value: int, settings: Dictionary = {}) -> Dictionary:
	var cfg: Dictionary = config() if settings.is_empty() else settings.duplicate(true)
	var catalog_path: String = "res://data/astronomy/%s/catalog.json" % cfg.catalog_version
	return {"schema_version": 2, "id": "galaxy:%s:%d" % [cfg.generator_version, seed_value],
		"seed": seed_value, "settings": cfg,
		"catalog": JSON.parse_string(FileAccess.get_file_as_string(catalog_path))}

static func body_id(m: Dictionary, ordinal: int) -> String:
	return m.id + ":planet:%d" % ordinal

static func ordinal_of(m: Dictionary, id: String) -> int:
	var prefix: String = m.id + ":planet:"
	if not id.begins_with(prefix): return -1
	var suffix: String = id.substr(prefix.length())
	if not suffix.is_valid_int() or str(int(suffix)) != suffix: return -1
	var ordinal := int(suffix)
	return ordinal if ordinal >= 0 and ordinal < int(m.settings.planet_count) else -1

static func map_position(m: Dictionary,index: int) -> Vector2:
	var cfg: Dictionary=m.settings
	var count: int=int(cfg.planet_count)/int(cfg.planets_per_system)
	var band: int=mini(index/(count/cfg.tier_weights.size()),cfg.tier_weights.size()-1)
	var seed_value:=derive(int(m.seed),m.id+":system:%d"%index)
	var fraction:=float(derive(seed_value,"radius")%1000000)/1000000.0
	var radius:=lerpf(float(cfg.outer_radius),float(cfg.inner_radius),(float(band)+fraction)/float(cfg.tier_weights.size()))
	var angle:=float(derive(seed_value,"angle")%1000000)/1000000.0*TAU
	return Vector2(cos(angle)*radius,sin(angle)*radius)

static func system(m: Dictionary, index: int) -> Dictionary:
	var cfg: Dictionary = m.settings
	var count: int = int(cfg.planet_count) / int(cfg.planets_per_system)
	if index < 0 or index >= count: return {}
	var per_band: int = count / cfg.tier_weights.size()
	var band: int = mini(index / per_band, cfg.tier_weights.size() - 1)
	var id: String = m.id + ":system:%d" % index
	var seed_value: int = derive(int(m.seed), id)
	var fraction: float = float(derive(seed_value, "radius") % 1000000) / 1000000.0
	var progress: float = (float(band) + fraction) / float(cfg.tier_weights.size())
	var radius: float = lerpf(float(cfg.outer_radius), float(cfg.inner_radius), progress)
	var angle: float = float(derive(seed_value, "angle") % 1000000) / 1000000.0 * TAU
	var ids: Array = []
	for orbit in body_count(m,index): ids.append(body_id(m, first_ordinal(m,index) + orbit))
	return {"id": id, "ordinal": index, "seed": seed_value, "band": band, "progress": progress,
		"sector_id": m.id + ":sector:%d" % (index / int(cfg.systems_per_sector)),
		"map_position": [cos(angle) * radius, sin(angle) * radius], "body_ids": ids,
		"star": {"id":id+":star", "name":FrontierCelestialNames.system_name(seed_value,index), "spectral_type":"G" if index==0 else ["M","K","G","F","A"][derive(seed_value,"star")%5]}}

static func body(m: Dictionary, ordinal: int) -> Dictionary:
	if ordinal < 0 or ordinal >= int(m.settings.planet_count): return {}
	var cfg: Dictionary = m.settings
	var s: Dictionary = system(m, system_index(m,ordinal))
	var id := body_id(m, ordinal)
	var seed_value: int = derive(int(s.seed), id)
	var streams: Dictionary = {}
	for stream in STREAMS: streams[stream] = derive(seed_value, id + ":" + stream)
	var result: Dictionary={"id": id, "ordinal": ordinal, "system_id": s.id, "system_ordinal": s.ordinal,
		"seed": seed_value, "name": FrontierCelestialNames.planet_name(s.star.name,ordinal-first_ordinal(m,int(s.ordinal))),
		"planet_tier": pick_tier(streams.tier, cfg.tier_weights[int(s.band)]),
		"kind": cfg.planet_kinds[ordinal % cfg.planet_kinds.size()], "streams": streams,
		"origin": "fictional", "reference_id": "", "surface_origin": "seed_generated"}
	if cfg.generator_version=="galaxy-v3":
		var orbit: int=ordinal-first_ordinal(m,int(s.ordinal))
		result.kind=cfg.planet_kinds[derive(seed_value,"body_kind")%cfg.planet_kinds.size()]
		if int(s.ordinal)==0:
			result.name=FrontierCelestialNames.rules().solar_planets[orbit];result.kind=cfg.solar_kinds[orbit]
			result.origin="solar_reference";result.reference_id="solar:"+str(orbit);result.planet_tier=1
		if cfg.has("system_rules") and int(s.ordinal)>0:
			var layout:=system_layout(m,int(s.ordinal))
			if orbit==0:result.kind="basalt"
			elif layout.theme=="giant_court" and orbit%2==1:result.kind="gas_giant"
		result.landable=result.kind not in ["gas_giant","ice_giant"]
		result.orbit={"radius":orbit_radius(m,int(s.ordinal),orbit),"phase":float(derive(seed_value,"orbit")%1000000)/1000000.0*TAU,"period":float(cfg.orbit_period_seconds)*pow(1.0+orbit,.9)}
		result.star_id=s.star.id
	if result.origin=="fictional" and cfg.has("system_rules"):
		var layout:=system_layout(m,int(s.ordinal))
		result.rings=(result.kind in ["gas_giant","ice_giant"] and (layout.theme=="giant_court" or derive(seed_value,"rings")%3==0))
		result.moons=1+derive(seed_value,"moons")%2 if layout.theme=="satellites" or result.kind in ["gas_giant","ice_giant"] else 0
	if result.origin=="fictional":result.traits=FrontierPlanetTraits.make(result,cfg.get("planet_rules",{}))
	result.terrain_traits=result.get("traits",{}) if cfg.has("planet_rules") else {}
	if cfg.has("resource_rules"):result.mineral_profile=FrontierMineralWorld.profile(result,cfg.resource_rules)
	return result

static func landable(body_value: Dictionary) -> bool:
	return body_value.get("origin","")!="solar_reference" and body_value.get("landable",true)

static func kind_label(body_value: Dictionary) -> String:
	return {"basalt":"암석형", "glacial":"빙하 암석형", "sulfur":"황산 암석형", "gas_giant":"가스 거대행성", "ice_giant":"얼음 거대행성"}.get(body_value.kind,"미확인")

static func radius(body_value: Dictionary) -> float:
	var cfg:=presentation()
	var solar: String=body_value.get("reference_id","")
	if solar.begins_with("solar:"):return float(cfg.solar_radii[int(solar.trim_prefix("solar:"))])
	var limits: Array=cfg.giant_radius_range if body_value.kind in ["gas_giant","ice_giant"] else cfg.rock_radius_range
	return lerpf(limits[0],limits[1],float(body_value.seed%1000)/999.0)

static func navigation_radius(body_value: Dictionary) -> float:
	# Ring geometry is part of the safe approach envelope, never a landing surface.
	var extent: float={"solar:5":2.26,"solar:6":1.805}.get(body_value.get("reference_id",""),1.0)
	if body_value.get("rings",false):extent=maxf(extent,2.25)
	return radius(body_value)*extent

static func position(m: Dictionary,ordinal: int,elapsed: float=0.0) -> Vector3:
	if m.is_empty() or m.settings.generator_version=="galaxy-v2":
		return [Vector3(-620,-130,-2400),Vector3(1150,340,-3600),Vector3(-2100,450,-4900),Vector3(2400,-500,-6000)][ordinal%4]
	var b:=body(m,ordinal)
	var angle: float=float(b.orbit.phase)+elapsed/float(b.orbit.period)*TAU
	return orbit_point(b,angle)

static func body_from_id(m: Dictionary, id: String) -> Dictionary:
	return body(m, ordinal_of(m, id))

static func new_world(seed_value: int) -> Dictionary:
	var manifest: Dictionary = generate(seed_value)
	var start: int=int(manifest.settings.get("starting_ordinal",0))
	var point:=position(manifest,start)+Vector3(0,0,radius(body(manifest,start))+float(manifest.settings.flight.arrival_clearance))
	return {"version": 2, "manifest": manifest, "manifest_hash": fingerprint(manifest),
		"visited": {}, "terrain_edits": {}, "location": body_id(manifest, start), "flight_position": [point.x,point.y,point.z]}

static func fingerprint(value: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)), "", true).sha256_text()

static func validate_world(value: Variant) -> String:
	if not value is Dictionary or value.get("version") != 2: return "지원하지 않는 탐험 저장 버전입니다. 원본을 보존하세요."
	if not value.get("manifest") is Dictionary: return "은하 생성 기록이 없습니다."
	var m: Dictionary = value.manifest
	if not m.get("settings") is Dictionary or m.settings.get("generator_version") not in ["galaxy-v2","galaxy-v3"]: return "호환되는 은하 생성기가 필요합니다."
	if value.get("manifest_hash") != fingerprint(m): return "은하 원형 기록이 손상됐습니다."
	if m.settings.has("system_rules"):
		var rules: Variant=m.settings.system_rules
		if not rules is Dictionary or rules.get("version")!=1 or rules.get("pair_planets")!=16 or rules.get("minimum_planets")!=4 or rules.get("maximum_planets")!=12:return "항성계 배치 규칙이 올바르지 않습니다."
	if m.settings.get("planet_count") != 1000000 or m.settings.get("planets_per_system") != (8 if m.settings.generator_version=="galaxy-v3" else 4): return "은하 주소 범위가 올바르지 않습니다."
	if not m.get("id") is String or not m.get("catalog") is Dictionary: return "은하 형식이 올바르지 않습니다."
	if not value.get("visited") is Dictionary or not value.get("terrain_edits") is Dictionary: return "세계 변경 기록 형식이 올바르지 않습니다."
	if not value.get("location") is String or ordinal_of(m, value.location) < 0: return "저장 위치를 찾을 수 없습니다."
	if value.has("navigation_target") and (not value.navigation_target is String or ordinal_of(m,value.navigation_target)<0): return "항법 목표가 올바르지 않습니다."
	for id in value.visited:
		if not id is String or ordinal_of(m, id) < 0 or not value.visited[id] is bool: return "방문 기록이 올바르지 않습니다."
	var position_value: Variant = value.get("flight_position")
	if not position_value is Array or position_value.size() != 3: return "항해 위치 형식 오류"
	for axis in position_value:
		if not (axis is int or axis is float) or not is_finite(axis) or absf(axis) > 100000: return "항해 위치 범위 오류"
	if value.has("crew"):
		var crew_error: String=FrontierCrewWorld.validate(value.crew)
		if not crew_error.is_empty():return crew_error
		var landing_error: String=FrontierCrewSurface.validate_world(value)
		if not landing_error.is_empty():return landing_error
	if value.has("ecology"):
		var ecology_error: String=FrontierEcology.validate(value.ecology,m)
		if not ecology_error.is_empty():return ecology_error
	if value.has("engineering") and not value.engineering is Dictionary:return "현장 연구 형식 오류"
	if value.has("vessel"):
		if not value.has("crew") or not value.has("business"):return "원정선 소유 세계·사업 장부 누락"
		var vessel_error: String=FrontierVesselRefit.validate(value.vessel,int(m.seed),value.get("crew",{}).get("world_id",""))
		if not vessel_error.is_empty():return vessel_error
	if value.has("business"):
		var business_error: String=FrontierExpeditionBusiness.validate(value.business,m)
		if not business_error.is_empty():return business_error
		var constraint_error: String=FrontierVesselRefit.constraints(value)
		if not constraint_error.is_empty():return constraint_error
	if value.has("business") or value.has("engineering"):
		var engineering_error: String=FrontierFieldEngineering.validate_world(value)
		if not engineering_error.is_empty():return engineering_error
	return _validate_terrain(value)

static func _finite(value: Variant,low: float,high: float) -> bool:
	return (value is float or value is int) and is_finite(value) and value>=low and value<=high

static func _vector3_array(value: Variant) -> bool:
	if not value is Array or value.size()!=3:return false
	for axis in value:
		if not _finite(axis,-100000,100000):return false
	return true

static func _validate_terrain(value: Dictionary) -> String:
	if value.get("mode","space") not in ["space","surface"]:return "탐험 모드가 올바르지 않습니다."
	if value.has("terrain_settings"):
		var cfg: Variant=value.terrain_settings
		if not cfg is Dictionary or value.get("terrain_settings_hash")!=fingerprint(cfg):return "지형 생성 설정이 손상됐습니다."
		if cfg.get("generator_version")!="terrain-v1":return "지원하지 않는 지형 생성기입니다."
		for key in ["chunk_cells","active_radius","vertical_radius","worker_limit"]:
			if not _finite(cfg.get(key),1,24) or float(cfg[key])!=floorf(cfg[key]):return "지형 생성 수량 오류"
		if cfg.active_radius>4 or cfg.vertical_radius>2 or cfg.worker_limit>4:return "지형 활성 범위 오류"
		if not _finite(cfg.get("cell_size"),.5,4):return "지형 격자 크기 오류"
		for key in ["region_half_extent","maximum_height","dig_radius","dig_range","dig_interval","walk_speed","sprint_speed","gravity","jump_speed"]:
			if not _finite(cfg.get(key),.01,100000):return "지형 설정값 오류: "+key
		if not _finite(cfg.get("minimum_depth"),-1000,-1):return "지하 범위 오류"
	for id in value.terrain_edits:
		if not id is String or ordinal_of(value.manifest,id)<0 or not value.terrain_edits[id] is Array:return "굴착 기록 형식 오류"
		for edit in value.terrain_edits[id]:
			if not edit is Dictionary or not _vector3_array(edit.get("center")) or not _finite(edit.get("radius"),.1,16):return "굴착 범위 오류"
	if value.has("surface_positions"):
		if not value.surface_positions is Dictionary:return "지표 위치 기록 오류"
		for id in value.surface_positions:
			if not id is String or ordinal_of(value.manifest,id)<0 or not _vector3_array(value.surface_positions[id]):return "지표 위치 범위 오류"
	if value.get("mode","space")=="surface" or not value.terrain_edits.is_empty() or not value.get("surface_positions",{}).is_empty():
		if not value.has("terrain_settings"):return "지표 기록에 고정 생성 설정이 필요합니다."
	if value.has("terrain_settings"):
		var cfg: Dictionary=value.terrain_settings
		var span: float=float(cfg.cell_size)*int(cfg.chunk_cells)
		for point in value.get("surface_positions",{}).values():
			if absf(point[0])>float(cfg.region_half_extent) or absf(point[2])>float(cfg.region_half_extent) or point[1]<float(cfg.minimum_depth)+2 or point[1]>float(cfg.maximum_height)+span-2:return "저장된 지표 위치가 탐사 영역 밖입니다."
	if value.has("surface_logistics"):
		if not value.surface_logistics is Dictionary:return "행성별 물류 기록 오류"
		for id in value.surface_logistics:
			if not id is String or ordinal_of(value.manifest,id)<0:return "물류 행성 주소 오류"
			var error: String=FrontierSurfaceLogistics.validate(value.surface_logistics[id],value.get("terrain_settings",{}))
			if not error.is_empty():return error
	return ""

## One central celestial entity, separate from the million planet addresses.
static func central_body(manifest: Dictionary) -> Dictionary:
	var definition: Dictionary=manifest.settings.central_body if manifest.settings.has("central_body") else config().central_body
	var result: Dictionary=definition.duplicate(true)
	result.id=manifest.id+":central_black_hole"
	result.landable=false
	return result

static func central_view(manifest: Dictionary,system_index: int,local_viewer: Vector3=Vector3.ZERO) -> Dictionary:
	var core:=central_body(manifest)
	var system_value:=system(manifest,system_index)
	if system_value.is_empty():return {"visible":false}
	var unit: float=core.galaxy_units_to_flight_units
	var origin:=Vector3(system_value.map_position[0],0,system_value.map_position[1])*unit
	var center:=Vector3(core.galaxy_position[0],core.galaxy_position[1],core.galaxy_position[2])*unit
	var relative: Vector3=center-origin-local_viewer
	var distance: float=relative.length()
	return {"id":core.id,"visible":distance/unit<=float(core.visible_within_galaxy_units),"direction":relative.normalized(),"distance_galaxy_units":distance/unit,"angular_scale":float(core.model_scale_galaxy_units)*unit/maxf(distance,1.0)}

static func landing_restriction(body: Dictionary) -> String:
	if body.get("origin","")=="solar_reference":return "태양계 · 테라포밍 불가 행성입니다. 착륙할 수 없습니다."
	if not landable(body):return "착륙할 표면이 없습니다. 궤도 탐사만 가능합니다."
	return ""

static func orbit_point(body: Dictionary,angle: float) -> Vector3:
	var tilt: float=deg_to_rad(float(presentation().inclination_min_degrees)+float(derive(int(body.seed),"inclination")%10000)/10000.0*float(presentation().inclination_range_degrees))
	var node: float=float(derive(int(body.seed),"ascending-node")%10000)/10000.0*TAU
	var point:=Vector3(cos(angle),0,sin(angle))*float(body.orbit.radius)
	return point.rotated(Vector3.RIGHT,tilt).rotated(Vector3.UP,node)

static var _presentation: Dictionary={}
static func presentation() -> Dictionary:
	if _presentation.is_empty():_presentation=JSON.parse_string(FileAccess.get_file_as_string("res://data/space_presentation.json"))
	return _presentation

# Paired variable-length systems preserve all one million contiguous addresses.
# Solar system and its pair remain eight bodies each; no prefix table is allocated.
static func _pair_first_count(m: Dictionary,pair: int) -> int:
	if pair==0:return 8
	var cfg: Dictionary=m.settings.system_rules
	return int(cfg.minimum_planets)+derive(int(m.seed),"system-pair-v1:%d"%pair)%(int(cfg.maximum_planets)-int(cfg.minimum_planets)+1)
static func body_count(m: Dictionary,index: int) -> int:
	if not m.settings.has("system_rules"):return int(m.settings.planets_per_system)
	var first:=_pair_first_count(m,index/2)
	return first if index%2==0 else int(m.settings.system_rules.pair_planets)-first
static func first_ordinal(m: Dictionary,index: int) -> int:
	if not m.settings.has("system_rules"):return index*int(m.settings.planets_per_system)
	return (index/2)*int(m.settings.system_rules.pair_planets)+(0 if index%2==0 else _pair_first_count(m,index/2))
static func system_index(m: Dictionary,ordinal: int) -> int:
	if not m.settings.has("system_rules"):return ordinal/int(m.settings.planets_per_system)
	var pair: int=ordinal/int(m.settings.system_rules.pair_planets)
	return pair*2+(1 if ordinal%int(m.settings.system_rules.pair_planets)>=_pair_first_count(m,pair) else 0)
static func system_layout(m: Dictionary,index: int) -> Dictionary:
	if not m.settings.has("system_rules") or index==0:
		return {"theme":"solar" if index==0 else "legacy","star_radius":presentation().star_radius,"warning":presentation().star_warning_radius,"damage":presentation().star_damage_radius,"boundary":presentation().system_boundary,"belt_radius":0.0}
	var cfg: Dictionary=m.settings.system_rules
	var seed_value:=derive(int(m.seed),"system-layout-v1:%d"%index)
	var star: float=lerpf(cfg.star_radius_range[0],cfg.star_radius_range[1],float(seed_value%1000)/999.0)
	var theme: String=cfg.themes[derive(seed_value,"theme")%cfg.themes.size()]
	return {"theme":theme,"star_radius":star,"warning":star*4.0,"damage":star*2.53,"boundary":cfg.boundary,"belt_radius":(orbit_radius(m,index,0)+orbit_radius(m,index,1))*.5 if theme=="debris" else 0.0}
static func orbit_radius(m: Dictionary,index: int,orbit: int) -> float:
	if not m.settings.has("system_rules") or index==0:return float(presentation().orbit_radii[orbit])
	var cfg: Dictionary=m.settings.system_rules
	var seed_value:=derive(int(m.seed),"system-layout-v1:%d"%index)
	var inner: float=lerpf(cfg.star_radius_range[0],cfg.star_radius_range[1],float(seed_value%1000)/999.0)*4.0+2600.0
	var outer: float=lerpf(cfg.outer_radius_range[0],cfg.outer_radius_range[1],float(derive(seed_value,"extent")%1000)/999.0)
	var total:=0.0;var part:=0.0
	for i in range(1,body_count(m,index)):
		var weight:=.85+float(derive(seed_value,"gap:%d"%i)%1000)/3330.0
		total+=weight
		if i<=orbit:part+=weight
	return lerpf(inner,outer,part/maxf(total,1))
static func entry_position(m: Dictionary,ordinal: int,elapsed: float,extra: float=0.0) -> Vector3:
	var b:=body(m,ordinal);var target:=position(m,ordinal,elapsed)
	var outward:=target.normalized()
	if m.settings.has("system_rules"):
		outward=(outward+Vector3.UP*.55+outward.cross(Vector3.UP)*.25).normalized()
	var clearance: float=navigation_radius(b)+float(m.settings.flight.arrival_clearance)+1200
	if int(b.get("moons",0))>0 or b.get("rings",false):clearance=maxf(clearance,radius(b)*7.5)
	return target+outward*(clearance+extra)
static func star_settings(m: Dictionary,index: int) -> Dictionary:
	var result:=presentation().duplicate(true)
	var layout:=system_layout(m,index)
	result.star_radius=layout.star_radius;result.star_warning_radius=layout.warning;result.star_damage_radius=layout.damage;result.system_boundary=layout.boundary
	return result
static func moon_offset(body_value: Dictionary,index: int,elapsed: float) -> Vector3:
	var seed_value:=derive(int(body_value.seed),"moon:%d"%index)
	var angle:=float(seed_value%10000)/10000.0*TAU+elapsed*.00012/(index+1)
	return Vector3(cos(angle),sin(angle)*.3,sin(angle))*(3.2+index*1.35)*radius(body_value)
static func moon_radius(body_value: Dictionary,index: int) -> float:
	return radius(body_value)*(.16+float(derive(int(body_value.seed),"moon-size:%d"%index)%100)/1000.0)

static func showcase_ordinal(m: Dictionary,index: int) -> int:
	var first:=first_ordinal(m,index)
	return first+1 if system_layout(m,index).theme=="giant_court" else first
