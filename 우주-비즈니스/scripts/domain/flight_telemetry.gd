class_name FrontierFlightTelemetry
extends RefCounted
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/flight_experience.json"))
	return _config
static func read(manifest: Dictionary,nav: Dictionary) -> Dictionary:
	var result: Dictionary={"distance":0.0,"eta":-1.0,"closing":0.0,"name":"","same_system":false}
	var ordinal:=int(nav.target)
	var body:=FrontierUniverse.body(manifest,ordinal)
	result.name=body.name
	result.same_system=FrontierUniverse.system_index(manifest,ordinal)==int(nav.system)
	if nav.mode=="jump":result.eta=float(nav.jump_left);return result
	if nav.get("station_target",false):
		var station:=FrontierSpaceStation.definition(manifest,int(nav.system),int(nav.get("first_stellar_system",-1)))
		if not station.is_empty():
			var offset:=FrontierCrewWorld.vector(station.position)-FrontierCrewWorld.vector(nav.position)
			result.name=station.name;result.same_system=true
			result.distance=maxf(0,offset.length()-float(FrontierSpaceStation.config().approach_distance))
			result.closing=offset.normalized().dot(FrontierCrewWorld.vector(nav.direction))*float(nav.speed)
			if result.distance<=3:result.eta=0.0
			elif result.closing>1:result.eta=result.distance/result.closing
			return result
	if not result.same_system:return result
	var offset:=FrontierUniverse.position(manifest,ordinal,float(nav.get("orbit_time",0)))-FrontierCrewWorld.vector(nav.position)
	result.distance=maxf(0,offset.length()-FrontierUniverse.navigation_radius(body)-float(manifest.settings.flight.arrival_clearance))
	result.closing=offset.normalized().dot(FrontierCrewWorld.vector(nav.direction))*float(nav.speed)
	if result.distance<=3:result.eta=0.0
	elif result.closing>1:result.eta=result.distance/result.closing
	return result
static func distance_label(distance: float) -> String:
	return "%.1f km"%(distance/1000.0) if distance>=1000 else "%.0f m"%distance
static func eta_label(value: Dictionary) -> String:
	if not value.same_system:return "성간 항로 선택"
	if float(value.eta)==0:return "접근 완료"
	if float(value.eta)<0:return "목적지 방향으로 비행"
	if float(value.eta)>=3600:return "예상 1시간 이상"
	return "예상 %d:%02d"%[int(ceil(value.eta))/60,int(ceil(value.eta))%60]
