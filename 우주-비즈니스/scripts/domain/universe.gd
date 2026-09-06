class_name FrontierUniverse
extends RefCounted
## A bounded logical address space. No planet list is allocated or saved.
const CONFIG_PATH := "res://data/galaxy.json"
const STREAMS := ["terrain", "resource", "discovery", "ecology", "civilization", "tier"]

static func config() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))

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
	for orbit in int(cfg.planets_per_system): ids.append(body_id(m, index * int(cfg.planets_per_system) + orbit))
	return {"id": id, "ordinal": index, "seed": seed_value, "band": band, "progress": progress,
		"sector_id": m.id + ":sector:%d" % (index / int(cfg.systems_per_sector)),
		"map_position": [cos(angle) * radius, sin(angle) * radius], "body_ids": ids}

static func body(m: Dictionary, ordinal: int) -> Dictionary:
	if ordinal < 0 or ordinal >= int(m.settings.planet_count): return {}
	var cfg: Dictionary = m.settings
	var s: Dictionary = system(m, ordinal / int(cfg.planets_per_system))
	var id := body_id(m, ordinal)
	var seed_value: int = derive(int(s.seed), id)
	var streams: Dictionary = {}
	for stream in STREAMS: streams[stream] = derive(seed_value, id + ":" + stream)
	return {"id": id, "ordinal": ordinal, "system_id": s.id, "system_ordinal": s.ordinal,
		"seed": seed_value, "name": "개척 %08d" % (ordinal + 1),
		"planet_tier": pick_tier(streams.tier, cfg.tier_weights[int(s.band)]),
		"kind": cfg.planet_kinds[ordinal % cfg.planet_kinds.size()], "streams": streams,
		"origin": "fictional", "reference_id": "", "surface_origin": "seed_generated"}

static func body_from_id(m: Dictionary, id: String) -> Dictionary:
	return body(m, ordinal_of(m, id))

static func new_world(seed_value: int) -> Dictionary:
	var manifest: Dictionary = generate(seed_value)
	return {"version": 2, "manifest": manifest, "manifest_hash": fingerprint(manifest),
		"visited": {}, "terrain_edits": {}, "location": body_id(manifest, 0), "flight_position": [0.0, 0.0, 80.0]}

static func fingerprint(value: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)), "", true).sha256_text()

static func validate_world(value: Variant) -> String:
	if not value is Dictionary or value.get("version") != 2: return "지원하지 않는 탐험 저장 버전입니다. 원본을 보존하세요."
	if not value.get("manifest") is Dictionary: return "은하 생성 기록이 없습니다."
	var m: Dictionary = value.manifest
	if not m.get("settings") is Dictionary or m.settings.get("generator_version") != "galaxy-v2": return "호환되는 은하 생성기가 필요합니다."
	if value.get("manifest_hash") != fingerprint(m): return "은하 원형 기록이 손상됐습니다."
	if m.settings.get("planet_count") != 1000000 or m.settings.get("planets_per_system") != 4: return "은하 주소 범위가 올바르지 않습니다."
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
