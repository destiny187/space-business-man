class_name FrontierShuttles
extends RefCounted
## One pilot per local-system utility craft; inventories and movement belong to this host world.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/shuttles.json"))
	return _config
static func fleet(world: Dictionary) -> Dictionary:return world.get("crew",{}).get("shuttles",{})
static func aboard(world: Dictionary,actor: String) -> bool:
	return not str(world.crew.members.get(actor,{}).get("shuttle_id","")).is_empty()
static func location(world: Dictionary,actor: String) -> String:
	return str(fleet(world).get(actor,{}).get("location",world.location)) if aboard(world,actor) else str(world.location)
static func area_key(world: Dictionary,actor: String) -> String:
	if aboard(world,actor):
		var ship: Dictionary=fleet(world)[actor]
		return "surface:"+str(ship.location) if not ship.landing.is_empty() else "shuttle:"+actor
	return "surface:"+str(world.crew.landing.body_id) if FrontierCrewSurface.landed(world) else "cabin"
static func context(world: Dictionary,actor: String) -> Dictionary:
	if not aboard(world,actor):return world
	var ship: Dictionary=fleet(world)[actor]
	var local:=world.duplicate();local.crew=world.crew.duplicate()
	local.crew.members={actor:world.crew.members[actor]}
	local.crew.pilot_id=actor
	local.vessel={}
	local.navigation_capabilities=FrontierVesselAccess.capabilities(world.get("vessel",{}))
	local.mothership_location=world.location
	for key in ["navigation","landing","cargo","cargo_equipment","rock"]:local.crew[key]=ship[key]
	local.location=ship.location;local.navigation_target=ship.navigation_target;local.flight_position=ship.navigation.position
	local.crew["cargo_slots"]=int(config().cargo_slots)
	local["local_shuttle"]=actor
	return local
static func commit(world: Dictionary,local: Dictionary,actor: String) -> void:
	if not local.has("local_shuttle"):return
	var ship: Dictionary=fleet(world)[actor]
	for key in ["navigation","landing","cargo","cargo_equipment","rock"]:ship[key]=local.crew[key]
	ship.location=local.location;ship.navigation_target=local.navigation_target
	for key in ["survey","combat","wildlife_stops","wildlife_encounters","corporations"]:
		if local.crew.has(key):world.crew[key]=local.crew[key]
	for key in ["incidents","terrain_edits","discoveries","surface_water","expedition_research","business","engineering","ecology","terrain_settings","terrain_settings_hash","celestial_regions"]:
		if local.has(key):world[key]=local[key]
static func peer_group(world: Dictionary,actor: String,peers: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for peer in peers:
		if (aboard(world,actor) and peers[peer]==actor) or (not aboard(world,actor) and not aboard(world,peers[peer])):result[peer]=peers[peer]
	return result
static func factory_busy(world: Dictionary,body_id: String,id: String) -> bool:
	for ship in fleet(world).values():
		if ship.state=="assembling" and ship.location==body_id and ship.factory_id==id:return true
	return false
static func guard(world: Dictionary,actor: String,kind: String,args: Dictionary) -> String:
	if kind=="land" and not FrontierFreightSalvage.carried(FrontierFreightSalvage.records(world),FrontierFreightSalvage.carrier(context(world,actor))).is_empty():return "외부 회수 포드를 지정 항만에 인계한 뒤 착륙하세요."
	var body_id:=location(world,actor)
	var facility_id:=str(args.get("factory_id",args.get("building_id",args.get("facility_id",""))))
	if kind in ["business_craft","business_produce","business_facility_upgrade","business_research_prototype","business_research_trial","business_demolish","rover_craft"] and factory_busy(world,body_id,facility_id):return "소형선 조립이 끝난 뒤 제작소를 사용하세요."
	if kind in ["business_settle","business_lease_release"]:
		for craft in fleet(world).values():
			if craft.state=="assembling" and craft.location==body_id:return "소형선 조립을 마친 뒤 거점을 인계하세요."
	if aboard(world,actor):
		var ship: Dictionary=fleet(world)[actor]
		if kind in ["navigate","land"]:
			var ordinal: Variant=args.get("ordinal",ship.navigation.target)
			if not FrontierExpeditionBusiness.integer(ordinal,0,int(world.manifest.settings.planet_count)-1):return "행성 주소 오류"
			if FrontierUniverse.system_index(world.manifest,int(ordinal))!=int(ship.system):return "소형선은 같은 항성계 안에서만 이동합니다. 성간 이동은 공동 원정선에 합류하세요."
		if kind in ["research_contribute","augmentation_upgrade","business_robot_deploy","business_robot_recover","surface_study","surface_analyze","surface_introduce","surface_restore","surface_resupply"]:return "FINCH는 자원 운송선입니다. 로봇 격납고·표본 연구·신체 증강은 공동 원정선을 이용하세요."
		if kind=="tutorial_depart" or kind.begins_with("vessel_") or kind.begins_with("station_") or kind.begins_with("rover_") or kind=="pilot":return "공동 원정선으로 복귀한 뒤 사용할 수 있습니다."
		if kind=="depart" and FrontierUniverse.system_index(world.manifest,int(ship.navigation.target))!=int(ship.system):return "소형선에는 성간 추진기가 없습니다."
	else:
		if kind in ["business_demolish","business_settle"]:
			for ship in fleet(world).values():
				if ship.state=="assembling" and ship.location==world.location and (kind=="business_settle" or args.get("building_id","")==ship.factory_id):return "소형선 조립을 마친 뒤 시설을 인계하거나 철거하세요."
		if kind in ["depart","land","launch","surface_board"]:
			for id in fleet(world):
				if aboard(world,id) or fleet(world)[id].state=="assembling":return "조립 또는 운송 중인 소형선이 있습니다. 승무원이 원정선에 합류한 뒤 함께 출발하세요."
	return ""
static func deployed(ship: Dictionary,body_id: String) -> bool:
	return ship.get("state")=="docked" and ship.get("deployment",{}).get("body_id","")==body_id
static func pad(world: Dictionary,actor: String) -> Vector3:
	var ship: Dictionary=fleet(world).get(actor,{})
	return FrontierCrewWorld.vector(ship.deployment.position) if deployed(ship,world.location) else Vector3.INF
static func deployment_access(world: Dictionary,actor: String,holder: String) -> String:
	var member: Dictionary=world.crew.members.get(actor,{})
	var craft: Dictionary=fleet(world).get(holder,{})
	if aboard(world,actor) or not FrontierCrewSurface.landed(world) or member.get("aboard",true):return "공동 착륙선 밖에서 소형선을 호출하세요."
	if FrontierCrewWorld.vector(member.position).distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))>float(FrontierCrewSurface.config().boarding_distance):return "착륙선 단말 가까이에서 호출하세요."
	if craft.get("state","")!="docked":return "격납 중인 소형선을 선택하세요."
	if holder!=actor and not craft.get("company",false):return "자신의 소형선 또는 공용선을 선택하세요."
	return ""
static func deployment_reason(world: Dictionary,actor: String,holder: String,p: Vector3) -> String:
	var error:=deployment_access(world,actor,holder)
	if not error.is_empty():return error
	if not p.is_finite():return "지면을 선택하세요."
	var origin:=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)
	var radius:=float(config().deployment_radius)
	if p.distance_to(origin)>float(config().deployment_range):return "착륙선 주변에서 위치를 선택하세요."
	if Vector2(p.x-origin.x,p.z-origin.z).length()<13+radius:return "착륙선 진입로를 비워 두세요."
	var field:=FrontierCrewSurface.field(world)
	var floor:=FrontierExpeditionBusiness.ground(field,p.x,p.z,radius)
	if not floor.is_finite() or absf(floor.y-p.y)>.5:return "소형선을 지지할 평탄한 지면이 필요합니다."
	var site: Dictionary=world.get("business",{}).get("sites",{}).get(world.location,{})
	if site.get("base_deployed",false) and p.distance_to(FrontierCrewWorld.vector(site.center))<radius+4:return "창고 진입로를 비워 두세요."
	for building in site.get("buildings",{}).values():
		if p.distance_to(FrontierCrewWorld.vector(building.position))<radius+FrontierTerraformTier3.radius(building)+1.5:return "시설과 호출 위치가 겹칩니다."
	for robot in site.get("robots",{}).values():
		if p.distance_to(FrontierCrewWorld.vector(robot.position))<radius+2:return "로봇이 호출 위치에 있습니다."
	for id in world.crew.members:
		if area_key(world,id)=="surface:"+world.location and p.distance_to(FrontierCrewWorld.vector(world.crew.members[id].position))<radius+1:return "승무원이 호출 위치에 있습니다."
	for id in fleet(world):
		if id!=holder and deployed(fleet(world)[id],world.location) and p.distance_to(pad(world,id))<radius*2+2:return "다른 소형선과 위치가 겹칩니다."
	for rover in FrontierRovers.fleet(world).vehicles.values():
		if rover.location_kind=="surface" and rover.body_id==world.location and p.distance_to(FrontierRovers.point(rover))<radius+4:return "차량과 호출 위치가 겹칩니다."
	for vein in FrontierExpeditionBusiness.clearance_veins(FrontierUniverse.body_from_id(world.manifest,world.location),p):
		if not vein.get("underground",false) and int(site.get("remaining",{}).get(vein.id,vein.capacity))>0 and Vector2(vein.position[0]-p.x,vein.position[2]-p.z).length()<radius+2:return "광맥과 호출 위치가 겹칩니다."
	if FrontierLotusSupport.blocks(world,world.location,p,radius):return "보급 투하 공간을 비워 두세요."
	if FrontierSurfaceWater.depth(world.get("surface_water",{}).get(world.location,FrontierSurfaceWater.create()),p)>.05:return "물 밖의 지면을 선택하세요."
	var body:=FrontierUniverse.body_from_id(world.manifest,world.location)
	if FrontierSurfaceDrainage.liquid(body.get("terrain_traits",{})) and p.y< -3.9:return "물 밖의 지면을 선택하세요."
	return ""
static func stow_docked(world: Dictionary) -> void:
	for craft in fleet(world).values():
		if craft.state=="docked":craft.erase("deployment")
static func apply(world: Dictionary,actor: String,kind: String,args: Dictionary) -> String:
	var member: Dictionary=world.crew.members[actor]
	if kind in ["shuttle_deploy","shuttle_stow"]:
		var holder:=str(args.get("holder",actor))
		var error:=deployment_access(world,actor,holder)
		if not error.is_empty():return error
		var craft: Dictionary=fleet(world)[holder]
		if kind=="shuttle_stow":craft.erase("deployment");return ""
		if not FrontierUniverse._vector3_array(args.get("position")) or not FrontierUniverse._finite(args.get("yaw",0),-TAU,TAU):return "소형선 호출 위치 오류"
		var p:=FrontierCrewWorld.vector(args.position)
		error=deployment_reason(world,actor,holder,p)
		if not error.is_empty():return error
		craft.deployment={"body_id":world.location,"position":args.position.duplicate(),"yaw":float(args.get("yaw",0)),"time":float(world.crew.navigation.orbit_time)}
		return ""
	if kind=="shuttle_recall":
		if actor!=world.crew.owner_id:return "호스트만 이탈 승무원을 회수할 수 있습니다."
		if aboard(world,actor):return "공동 원정선에 합류한 뒤 회수하세요."
		var target: String=str(args.get("character_id",""))
		if target==actor or not aboard(world,target) or fleet(world).get(target,{}).get("state")!="sortie":return "회수할 이탈 소형선이 없습니다."
		var craft: Dictionary=fleet(world)[target]
		# No transfer: craft cargo, bag and owned equipment keep their original ledgers.
		craft.erase("deployment");craft.state="docked";craft.location=world.location;craft.navigation_target=world.location
		craft.system=int(world.crew.navigation.system);craft.navigation=world.crew.navigation.duplicate(true)
		craft.navigation.mode="idle";craft.navigation.speed=0.0;craft.navigation.boosting=false;craft.navigation.manual=true
		craft.navigation.target=FrontierUniverse.ordinal_of(world.manifest,world.location)
		craft.landing=world.crew.get("landing",{}).duplicate(true)
		var rescued: Dictionary=world.crew.members[target]
		rescued.erase("shuttle_id");rescued["shuttle_recalled"]=true
		FrontierCrewSurface.spawn_member(world,rescued,int(craft.pad_slot))
		return ""
	if kind=="shuttle_build":
		if aboard(world,actor) or not FrontierCrewSurface.landed(world) or member.aboard:return "공동 원정선의 착륙 현장에서 제작하세요."
		if not world.crew.has("shuttles"):world.crew.shuttles={}
		if fleet(world).has(actor):return "이미 제작 중이거나 보유한 소형선이 있습니다."
		if fleet(world).size()>=int(config().maximum):return "소형선 보유 한도입니다."
		var site:=FrontierExpeditionBusiness.site(world)
		var factory: Dictionary=site.get("buildings",{}).get(str(args.get("factory_id","")),{})
		if not FrontierPlanetSupply.operating(site) or factory.get("type")!="factory" or int(factory.get("tier",1))<2:return "운영 중인 거점의 Mk.2 이상 제작소가 필요합니다."
		if factory_busy(world,world.location,str(factory.id)) or FrontierRovers.factory_busy(world,str(factory.id)) or not factory.get("production",{}).is_empty() or FrontierFieldEngineering.uses(world,world.location,str(factory.id)):return "제작소의 기존 작업을 먼저 완료하세요."
		for job in site.jobs.values():
			if job.factory_id==factory.id:return "로봇 조립을 먼저 완료하세요."
		if FrontierCrewWorld.vector(member.position).distance_to(FrontierCrewWorld.vector(factory.position))>8:return "제작소 8m 안에서 조립을 요청하세요."
		if not FrontierExpeditionBusiness.affordable(FrontierExpeditionBusiness.bag(world,actor),config().cost):return "가방에 소형선 조립 부품을 준비하세요."
		FrontierExpeditionBusiness.transfer(world.business.bags[actor],config().cost,-1)
		var nav: Dictionary=world.crew.navigation.duplicate(true)
		fleet(world)[actor]={"state":"assembling","pad_slot":fleet(world).size(),"progress":0.0,"factory_id":factory.id,"system":int(nav.system),"location":world.location,"navigation_target":world.location,"navigation":nav,"landing":world.crew.landing.duplicate(),"cargo":{},"cargo_equipment":{},"rock":0}
		return ""
	if kind=="shuttle_board" and not fleet(world).has(actor):
		for holder in fleet(world).keys():
			var loan: Dictionary=fleet(world)[holder]
			if not loan.get("company",false) or not deployed(loan,world.location):continue
			if not loan.cargo_equipment.is_empty():return "공용 FINCH의 개인 장비를 먼저 내려 주세요."
			if not FrontierCrewSurface.landed(world) or member.aboard or FrontierCrewWorld.vector(member.position).distance_to(pad(world,holder))>float(config().interaction_distance):return "Lotus 공용 FINCH 가까이에서 탑승하세요."
			FrontierFreightSalvage.reassign(world,holder,actor)
			fleet(world)[actor]=loan;fleet(world).erase(holder);break
	var ship: Dictionary=fleet(world).get(actor,{})
	if ship.is_empty() or ship.state=="assembling":return "소형선 조립을 먼저 완료하세요."
	if kind=="shuttle_board":
		if aboard(world,actor):return "이미 소형선으로 출동 중입니다."
		if not FrontierCrewSurface.landed(world) or member.aboard:return "착륙 후 소형선에 접근하세요."
		if not deployed(ship,world.location):return "착륙선 단말에서 소형선을 먼저 호출하세요."
		if float(world.crew.navigation.orbit_time)-float(ship.deployment.time)<float(config().deployment_seconds):return "소형선이 내려오는 중입니다."
		if FrontierCrewWorld.vector(member.position).distance_to(pad(world,actor))>float(config().interaction_distance):return "소형선 6m 안으로 접근하세요."
		ship.location=world.location;ship.navigation_target=world.location;ship.system=int(world.crew.navigation.system)
		ship.navigation=world.crew.navigation.duplicate(true);ship.landing=world.crew.landing.duplicate()
		member.shuttle_id=actor;member.aboard=true;member.ready=true
		var local:=context(world,actor)
		FrontierCrewSurface.launch_if_boarded(local,{1:actor})
		commit(world,local,actor);ship.state="sortie";return ""
	if kind=="shuttle_dock":
		if not aboard(world,actor):return "복귀할 출동 기록이 없습니다."
		if not FrontierCrewSurface.landed(world) or ship.landing.is_empty() or ship.location!=world.location:return "공동 원정선이 있는 행성에 착륙한 뒤 합류하세요."
		if FrontierCrewWorld.vector(member.position).distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))>float(FrontierCrewSurface.config().boarding_distance):return "공동 원정선 가까이 돌아오세요."
		member.erase("shuttle_id");member.aboard=false;member.ready=false;ship.state="docked";ship.erase("deployment")
		return ""
	return "지원하지 않는 소형선 작업입니다."
static func manufacture(world: Dictionary,dt: float) -> void:
	for ship in fleet(world).values():
		if ship.state!="assembling":continue
		var site: Dictionary=world.get("business",{}).get("sites",{}).get(ship.location,{})
		var factory: Dictionary=site.get("buildings",{}).get(ship.factory_id,{})
		if not FrontierPlanetSupply.operating(site) or not factory.get("active",false):continue
		ship.progress=minf(float(config().seconds),float(ship.progress)+dt*FrontierProductionTier2.factor(factory));factory.working=true;factory.status="소형선 조립 중"
		if ship.progress>=float(config().seconds):ship.state="docked"
static func resume(world: Dictionary,actor: String) -> void:
	if not aboard(world,actor):return
	var nav: Dictionary=fleet(world)[actor].navigation
	nav.speed=0.0;nav.boosting=false;nav.mode="idle";nav.manual=true
static func validate(crew: Dictionary) -> String:
	if not crew.get("shuttles",{}) is Dictionary or crew.get("shuttles",{}).size()>int(config().maximum):return "소형선 함대 형식 오류"
	for id in crew.get("shuttles",{}):
		var ship: Variant=crew.shuttles[id]
		if not crew.members.has(id) or not ship is Dictionary or ship.get("state") not in ["assembling","docked","sortie"]:return "소형선 소유·상태 오류"
		if ship.has("deployment"):
			var deployment: Variant=ship.deployment
			if not deployment is Dictionary or not deployment.get("body_id") is String or not FrontierUniverse._vector3_array(deployment.get("position")) or not FrontierUniverse._finite(deployment.get("yaw"),-TAU,TAU) or not FrontierUniverse._finite(deployment.get("time"),0,9007199254740000):return "소형선 호출 기록 오류"
		if not FrontierExpeditionBusiness.integer(ship.get("pad_slot",0),0,5):return "소형선 주기 위치 오류"
		if not FrontierExpeditionBusiness.integer(ship.get("system"),0,249999) or not FrontierUniverse._finite(ship.get("progress"),0,float(config().seconds)):return "소형선 진행 오류"
		if not ship.get("location") is String or not ship.get("navigation_target") is String or not ship.get("landing") is Dictionary:return "소형선 위치 오류"
		if not FrontierCrewNavigation.validate(ship.get("navigation")).is_empty() or ship.navigation.mode=="jump" or int(ship.navigation.system)!=int(ship.system):return "소형선 항로 오류"
		if not ship.get("cargo") is Dictionary or not ship.get("cargo_equipment") is Dictionary or not FrontierExpeditionBusiness.integer(ship.get("rock"),0,FrontierItemInventory.limit()):return "소형선 화물 오류"
		for resource in ship.cargo:
			if FrontierCatalog.entry("resources",resource).is_empty() or not FrontierExpeditionBusiness.integer(ship.cargo[resource],0,FrontierItemInventory.limit()):return "소형선 화물 수량 오류"
		var cargo: Dictionary=ship.cargo.duplicate();cargo.stone=int(ship.rock)
		if FrontierItemInventory.used(cargo,ship.cargo_equipment.size())>int(config().cargo_slots):return "소형선 화물 한도 초과"
		for key in ship.cargo_equipment:
			var item: Variant=ship.cargo_equipment[key]
			if not item is Dictionary or item.get("owner")!=id or not item.get("item_id") is String or key!=id+"/"+item.item_id or not FrontierEquipment.config().items.has(item.get("definition","")):return "소형선 장비 소유 오류"
		if str(crew.members[id].get("shuttle_id",""))!=id and ship.state=="sortie":return "소형선 탑승 소유 오류"
	for id in crew.members:
		if crew.members[id].has("shuttle_id") and (crew.members[id].shuttle_id!=id or not crew.get("shuttles",{}).has(id) or crew.shuttles[id].state!="sortie"):return "소형선 탑승 기록 오류"
	return ""

static func validate_world(world: Dictionary) -> String:
	for id in fleet(world):
		var ship: Dictionary=fleet(world)[id]
		if ship.has("deployment") and FrontierUniverse.ordinal_of(world.manifest,ship.deployment.body_id)<0:return "소형선 호출 행성 오류"
		for body_id in [ship.location,ship.navigation_target]:
			var ordinal:=FrontierUniverse.ordinal_of(world.manifest,str(body_id))
			if ordinal<0 or FrontierUniverse.system_index(world.manifest,ordinal)!=int(ship.system):return "소형선 항성계 주소 오류"
		if FrontierUniverse.system_index(world.manifest,int(ship.navigation.target))!=int(ship.system):return "소형선 성간 목적지 오류"
		if not ship.landing.is_empty():
			if ship.landing.get("body_id","")!=ship.location or ship.navigation.mode!="idle" or not world.get("ecology",{}).get("planets",{}).has(ship.location):return "소형선 착륙 기록 오류"
	return ""
