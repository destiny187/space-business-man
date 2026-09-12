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
static func pad(world: Dictionary,actor: String) -> Vector3:
	var point:=FrontierCrewWorld.vector(config().pad)
	point.x+=float(fleet(world).get(actor,{}).get("pad_slot",fleet(world).size()))*7.0
	if FrontierCrewSurface.landed(world):point.y=FrontierCrewSurface.field(world).height(point.x,point.z)
	return point
static func apply(world: Dictionary,actor: String,kind: String,args: Dictionary) -> String:
	var member: Dictionary=world.crew.members[actor]
	if kind=="shuttle_recall":
		if actor!=world.crew.owner_id:return "호스트만 이탈 승무원을 회수할 수 있습니다."
		if aboard(world,actor):return "공동 원정선에 합류한 뒤 회수하세요."
		var target: String=str(args.get("character_id",""))
		if target==actor or not aboard(world,target) or fleet(world).get(target,{}).get("state")!="sortie":return "회수할 이탈 소형선이 없습니다."
		var craft: Dictionary=fleet(world)[target]
		# No transfer: craft cargo, bag and owned equipment keep their original ledgers.
		craft.state="docked";craft.location=world.location;craft.navigation_target=world.location
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
		var dock:=pad(world,actor)
		if not FrontierExpeditionBusiness.ground(FrontierCrewSurface.field(world),dock.x,dock.z,3).is_finite():return "소형선 착륙대의 평탄한 공간을 확보하세요."
		FrontierExpeditionBusiness.transfer(world.business.bags[actor],config().cost,-1)
		var nav: Dictionary=world.crew.navigation.duplicate(true)
		fleet(world)[actor]={"state":"assembling","pad_slot":fleet(world).size(),"progress":0.0,"factory_id":factory.id,"system":int(nav.system),"location":world.location,"navigation_target":world.location,"navigation":nav,"landing":world.crew.landing.duplicate(),"cargo":{},"cargo_equipment":{},"rock":0}
		return ""
	if kind=="shuttle_board" and not fleet(world).has(actor):
		for holder in fleet(world).keys():
			var loan: Dictionary=fleet(world)[holder]
			if not loan.get("company",false) or loan.state!="docked":continue
			if not loan.cargo_equipment.is_empty():return "공용 FINCH의 개인 장비를 먼저 내려 주세요."
			if not FrontierCrewSurface.landed(world) or member.aboard or FrontierCrewWorld.vector(member.position).distance_to(pad(world,holder))>float(config().interaction_distance):return "Lotus 공용 FINCH 가까이에서 탑승하세요."
			FrontierFreightSalvage.reassign(world,holder,actor)
			fleet(world)[actor]=loan;fleet(world).erase(holder);break
	var ship: Dictionary=fleet(world).get(actor,{})
	if ship.is_empty() or ship.state=="assembling":return "소형선 조립을 먼저 완료하세요."
	if kind=="shuttle_board":
		if aboard(world,actor):return "이미 소형선으로 출동 중입니다."
		if not FrontierCrewSurface.landed(world) or member.aboard:return "착륙 후 소형선에 접근하세요."
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
		member.erase("shuttle_id");member.aboard=false;member.ready=false;ship.state="docked"
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
		for body_id in [ship.location,ship.navigation_target]:
			var ordinal:=FrontierUniverse.ordinal_of(world.manifest,str(body_id))
			if ordinal<0 or FrontierUniverse.system_index(world.manifest,ordinal)!=int(ship.system):return "소형선 항성계 주소 오류"
		if FrontierUniverse.system_index(world.manifest,int(ship.navigation.target))!=int(ship.system):return "소형선 성간 목적지 오류"
		if not ship.landing.is_empty():
			if ship.landing.get("body_id","")!=ship.location or ship.navigation.mode!="idle" or not world.get("ecology",{}).get("planets",{}).has(ship.location):return "소형선 착륙 기록 오류"
	return ""
