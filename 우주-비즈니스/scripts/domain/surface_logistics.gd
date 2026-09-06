class_name FrontierSurfaceLogistics
extends RefCounted
static func config() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_logistics.json"))
static func create() -> Dictionary:
	return {"version":1,"hand_rock":0,"depot_rock":0,"robot":{"id":"locus-courier-01","position":[-4.0,3.0,4.0],"cargo":0,"phase":"idle","target":[-4.0,2.0,4.0]},"deliveries":0}
static func validate(value: Variant,terrain_settings: Dictionary={}) -> String:
	if not value is Dictionary or value.get("version")!=1:return "물류 저장 버전 오류"
	for name in ["hand_rock","depot_rock","deliveries"]:
		if not FrontierUniverse._finite(value.get(name),0,100000000) or value[name]!=floorf(value[name]):return "물류 수량 오류"
	var robot: Variant=value.get("robot")
	if not robot is Dictionary or robot.get("id")!="locus-courier-01":return "운반 로봇 기록 오류"
	if not FrontierUniverse._finite(robot.get("cargo"),0,int(config().cargo_capacity)) or robot.cargo!=floorf(robot.cargo):return "로봇 화물 범위 오류"
	if not FrontierUniverse._vector3_array(robot.get("position")) or not FrontierUniverse._vector3_array(robot.get("target")):return "로봇 위치 오류"
	if robot.get("phase") not in ["idle","pickup","return"]:return "로봇 작업 상태 오류"
	var bounds: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json")) if terrain_settings.is_empty() else terrain_settings
	for point in [robot.position,robot.target]:
		if absf(point[0])>float(bounds.region_half_extent) or absf(point[2])>float(bounds.region_half_extent) or point[1]<float(bounds.minimum_depth)+2 or point[1]>float(bounds.maximum_height)+float(bounds.cell_size)*int(bounds.chunk_cells)-2:return "로봇이 탐사 가능 영역 밖에 있습니다."
	if robot.phase=="return" and robot.target!=[-4.0,2.0,4.0]:return "로봇 하역 위치 오류"
	return ""
static func load_cargo(state: Dictionary) -> int:
	var amount: int=mini(int(state.hand_rock),int(config().cargo_capacity)-int(state.robot.cargo))
	state.hand_rock-=amount;state.robot.cargo+=amount
	return amount
static func unload(state: Dictionary) -> int:
	var amount:=int(state.robot.cargo)
	if amount==0:return 0
	state.depot_rock+=amount;state.robot.cargo=0;state.deliveries+=1
	return amount
