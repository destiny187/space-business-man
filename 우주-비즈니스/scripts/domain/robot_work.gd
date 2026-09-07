class_name FrontierRobotWork
extends RefCounted
## Host-side search. Capability (Mk) and manufacturing quality are separate axes.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/robot_work.json"))
	return _config
static func tier(robot: Dictionary) -> int:return int(config().capability_tiers.get(str(int(robot.get("tier",1))),1))
static func ensure(robot: Dictionary) -> void:
	if not robot.has("auto_enabled"):robot.auto_enabled=true
	if not robot.has("resource_filter"):robot.resource_filter=""
	if not robot.has("anchor"):robot.anchor=robot.position.duplicate()
	if not robot.has("manual_target"):robot.manual_target=""
	if not robot.has("search_wait"):robot.search_wait=0.0
static func reason(world: Dictionary,robot: Dictionary,vein: Dictionary) -> String:
	if vein.is_empty():return "채광할 광맥이 없습니다."
	var site:=FrontierExpeditionBusiness.site(world)
	if int(site.remaining.get(vein.id,vein.capacity))<=0:return "광맥이 고갈됐습니다."
	if vein.get("underground",false):return "지하 광맥은 수동 채집하세요."
	if int(vein.required_tier)>tier(robot):return "채광 능력 Mk.%d 로봇이 필요합니다."%int(vein.required_tier)
	if FrontierExpeditionBusiness.thermal_locked(FrontierUniverse.body_from_id(world.manifest,world.location),site,vein):return "고온 광맥 · 구역 냉각 필요"
	if not FrontierExpeditionBusiness.ground(FrontierCrewSurface.field(world),vein.position[0],vein.position[2]).is_finite():return "광맥 토대가 없어 접근할 수 없습니다."
	return ""
static func route(world: Dictionary,robot: Dictionary,vein: Dictionary) -> Dictionary:
	var start:=FrontierExpeditionBusiness.point(robot.position)
	var goal:=FrontierExpeditionBusiness.ground(FrontierCrewSurface.field(world),vein.position[0],vein.position[2])
	if not goal.is_finite():return {}
	if start.distance_to(goal)<2.5:return {"path":[],"distance":start.distance_to(goal)}
	var nav:=FrontierTerrainNavigation.new()
	var result:=nav.find_path(FrontierCrewSurface.field(world),start,goal,FrontierSurfaceLogistics.config().navigation,FrontierExpeditionIndustry.obstacles(world))
	if result.points.is_empty():return {}
	var path: Array=[];var distance:=0.0;var previous:=start
	for point in result.points:
		distance+=previous.distance_to(point);previous=point;path.append(FrontierExpeditionBusiness.array(point))
	if path.size()>1:path.pop_front()
	return {"path":path,"distance":distance}
static func assign(site: Dictionary,robot: Dictionary,vein: Dictionary,path: Array=[]) -> void:
	site.remaining[vein.id]=int(site.remaining.get(vein.id,vein.capacity))
	robot.target=vein.id;robot.work=0.0;robot.path=path.duplicate(true)
	robot.phase="return" if FrontierExpeditionBusiness.total(robot.cargo)>0 else "outbound"
	if robot.phase=="return" or robot.charging:robot.path=[]
	robot.status="광맥으로 이동"
static func search(world: Dictionary,robot: Dictionary) -> bool:
	ensure(robot)
	var site:=FrontierExpeditionBusiness.site(world)
	var center:=FrontierExpeditionBusiness.point(robot.anchor)
	var candidates: Array=[]
	for vein in FrontierExpeditionBusiness.veins(FrontierUniverse.body_from_id(world.manifest,world.location),center):
		if not robot.resource_filter.is_empty() and vein.resource!=robot.resource_filter:continue
		if Vector2(vein.position[0]-center.x,vein.position[2]-center.z).length()>float(config().auto_radius):continue
		if not reason(world,robot,vein).is_empty():continue
		var reserved:=false
		for other in site.robots.values():
			if other.id!=robot.id and other.get("manual_target","")==vein.id:reserved=true;break
		if not reserved:candidates.append(vein)
	var origin:=FrontierExpeditionBusiness.point(robot.position)
	candidates.sort_custom(func(a: Dictionary,b: Dictionary):
		var da:=Vector2(a.position[0]-origin.x,a.position[2]-origin.z).length_squared();var db:=Vector2(b.position[0]-origin.x,b.position[2]-origin.z).length_squared()
		return a.id<b.id if is_equal_approx(da,db) else da<db)
	var best: Dictionary={};var best_route: Dictionary={};var distance:=INF
	for vein in candidates.slice(0,int(config().path_candidates)):
		if Vector2(vein.position[0]-origin.x,vein.position[2]-origin.z).length()>=distance:break
		var path:=route(world,robot,vein)
		if not path.is_empty() and float(path.distance)<distance:best=vein;best_route=path;distance=path.distance
	if best.is_empty():robot.status="자동 대기 · 범위 안 채광 가능한 광맥 없음";return false
	assign(site,robot,best,best_route.path);return true
static func order(world: Dictionary,actor: String,args: Dictionary) -> String:
	var site:=FrontierExpeditionBusiness.site(world)
	var body:=FrontierUniverse.body_from_id(world.manifest,world.location)
	var vein:=FrontierExpeditionBusiness.find_vein(body,str(args.get("vein_id","")))
	if vein.is_empty():return "광맥을 조준하세요."
	var player:=FrontierExpeditionBusiness.point(world.crew.members[actor].position)
	var at:=FrontierMineralWorld.point(FrontierCrewSurface.field(world),vein)
	if not at.is_finite() or player.distance_to(at)>float(config().command_distance) or not FrontierCrewSurface.visible_in_field(FrontierCrewSurface.field(world),player+Vector3.UP*1.72,at+Vector3.UP):return "보이는 광맥 8m 앞에서 로봇에게 지시하세요."
	var explicit:=str(args.get("robot_id",""))
	if not explicit.is_empty() and not site.robots.has(explicit):return "선택한 로봇이 이 현장에 없습니다. 자동 선정을 선택하세요."
	for robot in site.robots.values():
		if robot.get("manual_target","")==vein.id:
			if explicit.is_empty() or robot.id==explicit:return ""
			return "이미 다른 로봇 한 대가 이 광맥을 담당합니다."
	var candidates: Array=[]
	for robot in site.robots.values():
		if not explicit.is_empty() and robot.id!=explicit:continue
		var error:=reason(world,robot,vein)
		if player.distance_to(FrontierExpeditionBusiness.point(robot.position))>float(config().communication_radius):error="선택 로봇이 통신 범위 250m 밖에 있습니다."
		if float(robot.battery)<=0:error="선택 로봇에 긴급 충전이 필요합니다."
		if not error.is_empty():
			if not explicit.is_empty():return error
			continue
		if explicit.is_empty() and (robot.charging or float(robot.battery)<25 or FrontierExpeditionBusiness.total(robot.cargo)>0 or not robot.get("manual_target","").is_empty()):continue
		var path:=route(world,robot,vein)
		if path.is_empty():
			if not explicit.is_empty():return "선택 로봇에서 광맥까지 통과 가능한 경로가 없습니다."
			continue
		var quality:=float(FrontierCatalog.entry("grades",robot.grade).multiplier)
		var speed:=float(FrontierCatalog.entry("robots","miner").speed)*quality*(float(FrontierProductionTier2.config().robot_upgrade.speed_factor) if int(robot.get("tier",1))==2 else 1.0)
		var amount:=float(FrontierProductionTier2.config().robot_upgrade.mine_amount) if int(robot.get("tier",1))==2 else float(FrontierExpeditionBusiness.config().robot_mine_amount)
		candidates.append({"robot":robot,"path":path.path,"rank":[tier(robot),quality,amount*quality],"eta":float(path.distance)/speed})
	if candidates.is_empty():return "범위 안에 작업 가능한 로봇이 없습니다. 충전·운반·등급·경로를 확인하세요."
	candidates.sort_custom(func(a: Dictionary,b: Dictionary):
		for i in 3:
			if a.rank[i]!=b.rank[i]:return a.rank[i]>b.rank[i]
		return a.robot.id<b.robot.id if is_equal_approx(a.eta,b.eta) else a.eta<b.eta)
	var chosen: Dictionary=candidates[0].robot
	ensure(chosen);chosen.auto_enabled=true;chosen.manual_target=vein.id
	assign(site,chosen,vein,candidates[0].path)
	for other in site.robots.values():
		if other.id!=chosen.id and other.target==vein.id:
			other.target="";other.path=[];other.phase="return" if FrontierExpeditionBusiness.total(other.cargo)>0 else "idle"
	return ""
