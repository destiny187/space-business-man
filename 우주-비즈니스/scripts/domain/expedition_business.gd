class_name FrontierExpeditionBusiness
extends RefCounted
## One host-owned business ledger; autonomous work is committed before publication.
static var _config: Dictionary={}
static var _starter_veins: Array=[]
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/expedition_business.json"))
	return _config
static func signature() -> String:
	return FrontierUniverse.fingerprint(config())+FrontierUniverse.fingerprint(FrontierCatalog.all())
static func create() -> Dictionary:
	return {"version":1,"rules_hash":signature(),"credits":int(config().starting_credits),"technologies":[],"active":"","counter":0,"sites":{},"hangar":{},"bags":{},"crates":{}}
static func inventory() -> Dictionary:
	return {"iron":0,"copper":0,"stone":0,"ice":0,"crystal":0}
static func total(value: Dictionary) -> int:
	var count:=0
	for amount in value.values():count+=int(amount)
	return count
static func point(value: Array) -> Vector3:return Vector3(value[0],value[1],value[2])
static func array(value: Vector3) -> Array:return [value.x,value.y,value.z]
static func affordable(stock: Dictionary,cost: Dictionary) -> bool:
	for key in cost:
		if int(stock.get(key,0))<int(cost[key]):return false
	return true
static func transfer(stock: Dictionary,cost: Dictionary,multiplier: int) -> void:
	for key in cost:stock[key]=int(stock.get(key,0))+int(cost[key])*multiplier
static func identifier(business: Dictionary,prefix: String) -> String:
	business.counter+=1;return prefix+":"+str(int(business.counter))
static func veins(body: Dictionary,center: Vector3=Vector3.ZERO) -> Array:
	var values: Array=[]
	if body.kind in ["gas_giant","ice_giant"]:return values
	if FrontierMineralWorld.enabled(body):values=FrontierMineralWorld.nearby(body,center)
	var types: Array=config().veins
	if FrontierMineralWorld.enabled(body) and body.get("reference_id","")!="solar:2":types=body.mineral_profile.primary+body.mineral_profile.secondary+["stone"]
	for i in types.size():
		var seed_value: int=FrontierUniverse.derive(int(body.streams.resource),"vein:"+str(i))
		var angle: float=float(i)*TAU/float(types.size())+float(seed_value%101)/1000
		var radius: float=config().vein_radius[i%3]
		var p: Array=[sin(angle)*radius,0,cos(angle)*radius]
		if i<config().starter_vein_positions.size():p=[config().starter_vein_positions[i][0]+float(seed_value%11)*.05,0,config().starter_vein_positions[i][1]]
		values.append({"id":"vein:"+str(i),"resource":types[i],"required_tier":FrontierMineralWorld.tier(types[i]),"capacity":int(config().vein_capacity.get(types[i],180))+int(body.planet_tier-1)*20,"position":p})
	# Stable additive IDs preserve depletion of all older deposits.
	if FrontierMineralWorld.enabled(body):values.append_array(starter_veins())
	if FrontierMineralWorld.enabled(body):
		var field:=FrontierTerrainField.new();field.configure(int(body.streams.terrain),[],24.0,body.get("terrain_traits",{}))
		for level in range(-20,-40,-1):
			var p:=Vector3(98,level,0)
			if field.density(p+Vector3.UP*.6)<=0 and field.density(p-Vector3.UP*.6)>0:
				var gem: String=body.mineral_profile.gems[0]
				values.append({"id":"cave:gem:0","resource":gem,"required_tier":FrontierMineralWorld.tier(gem),"capacity":35,"position":[p.x,p.y,p.z],"underground":true,"quality":1})
				break
	return values
static func starter_veins() -> Array:
	if _starter_veins.is_empty():_starter_veins=JSON.parse_string(FileAccess.get_file_as_string("res://data/landing_resources.json"))
	return _starter_veins.duplicate(true)
static func find_vein(body: Dictionary,id: String) -> Dictionary:
	if id.begins_with("ore1:"):return FrontierMineralWorld.find(body,id)
	for row in veins(body):
		if row.id==id:return row
	return {}
static func site(world: Dictionary) -> Dictionary:
	return world.get("business",{}).get("sites",{}).get(world.location,{})
static func bag(world: Dictionary,actor: String) -> Dictionary:
	return world.get("business",{}).get("bags",{}).get(actor,inventory())
static func near_warehouse(current: Dictionary,position: Vector3) -> bool:
	if current.is_empty():return false
	if position.distance_to(point(current.center))<=float(config().deposit_range):return true
	for row in current.get("buildings",{}).values():
		if row.type=="storage" and position.distance_to(point(row.position))<=float(config().deposit_range):return true
	return false
static func ground(field: FrontierTerrainField,x: float,z: float,radius: float=.4) -> Vector3:
	var y: float=field.height(x,z)
	var p:=Vector3(x,y,z)
	if field.density(p+Vector3.UP*.4)>0 or field.density(p-Vector3.UP*.5)<0:return Vector3.INF
	if field.normal(p).y<float(config().minimum_ground_normal):return Vector3.INF
	for offset in [Vector3(radius,0,0),Vector3(-radius,0,0),Vector3(0,0,radius),Vector3(0,0,-radius)]:
		if absf(field.height(x+offset.x,z+offset.z)-y)>.5 or field.density(p+offset-Vector3.UP*.5)<0:return Vector3.INF
	return p
static func placement(world: Dictionary,kind: String,p: Vector3,active: Dictionary) -> String:
	var current:=site(world)
	var def:=FrontierCatalog.entry("buildings",kind)
	if def.is_empty() or kind not in config().buildings:return "건설 설계도를 확인하세요."
	var radius: float=def.radius
	if p.distance_to(point(current.center))>float(config().build_radius):return "개발 거점 65m 이내에 배치하세요."
	if p.distance_to(point(current.center))<radius+4 or p.distance_to(point(FrontierCrewSurface.config().ship_position))<radius+13:return "착륙선과 창고의 진입로를 비워 두세요."
	var floor:=ground(FrontierCrewSurface.field(world),p.x,p.z,radius)
	if not floor.is_finite() or absf(floor.y-p.y)>.5:return "평탄하고 지지되는 지면이 필요합니다."
	for building in current.buildings.values():
		if point(building.position).distance_to(p)<radius+float(FrontierCatalog.entry("buildings",building.type).radius)+1.5:return "시설과 운반 통로가 겹칩니다."
	for id in active.values():
		if point(world.crew.members[id].position).distance_to(p)<radius+1:return "승무원이 배치 구역 안에 있습니다."
	for robot in current.robots.values():
		if point(robot.position).distance_to(p)<radius+1.5:return "로봇이 배치 구역 안에 있습니다."
	var body:=FrontierUniverse.body_from_id(world.manifest,world.location)
	for vein in veins(body):
		if Vector2(vein.position[0]-p.x,vein.position[2]-p.z).length()<radius+2:return "광맥과 채광 접근로를 비워 두세요."
	return ""
static func ensure_site(world: Dictionary) -> Dictionary:
	if not world.has("business"):world.business=create()
	var ledger: Dictionary=world.business
	if ledger.sites.has(world.location):return ledger.sites[world.location]
	var body:=FrontierUniverse.body_from_id(world.manifest,world.location)
	var center:=point(config().base_position);center.y=FrontierCrewSurface.field(world).height(center.x,center.z)
	var source: Dictionary=body.get("traits",FrontierCatalog.entry("planets",body.kind))
	ledger.sites[world.location]={"center":array(center),"state":"exploration","inventory":inventory(),"remaining":{},"buildings":{},"robots":{},"jobs":{},"environment":{"temperature":source.temperature,"pressure":source.pressure,"oxygen":source.oxygen,"toxicity":source.toxicity,"water":source.water,"ecology":0.0,"stable_seconds":0.0},"time":0.0,"delivered":0,"production_paid":false,"settlement":{},"power_supply":2.0,"power_demand":0.0}
	if not FrontierMineralWorld.enabled(body):
		for row in veins(body):ledger.sites[world.location].remaining[row.id]=row.capacity
	if int(body.planet_tier)==2 and body.get("origin","")!="solar_reference":
		var cfg: Dictionary=FrontierProductionTier2.config().restoration
		ledger.sites[world.location].restoration2={"salinity":float(cfg.starting_salinity),"soil":float(cfg.starting_soil)}
	return ledger.sites[world.location]
static func apply(world: Dictionary,actor: String,kind: String,args: Dictionary,active: Dictionary) -> String:
	if not FrontierCrewSurface.landed(world):return "행성에 착륙한 뒤 사업을 운영하세요."
	if (kind=="business_build" or kind.begins_with("business_research_")) and FrontierUniverse.body_from_id(world.manifest,world.location).get("origin","")=="solar_reference":return "태양계는 테라포밍 불가 행성입니다."
	var position:=point(world.crew.members[actor].position)
	var at_ship: bool=position.distance_to(point(FrontierCrewSurface.config().ship_position))<=float(FrontierCrewSurface.config().boarding_distance)
	if not world.has("business"):world.business=create()
	var ledger: Dictionary=world.business
	if kind.begins_with("business_research_"):return FrontierFieldEngineering.apply(world,actor,kind,args)
	if kind=="business_register":
		var restriction:=FrontierUniverse.landing_restriction(FrontierUniverse.body_from_id(world.manifest,world.location))
		if not restriction.is_empty():return restriction
		if actor!=world.crew.owner_id:return "호스트가 공동 개발 사업을 등록합니다."
		if not at_ship:return "착륙선에서 개발 범위를 등록하세요."
		if ledger.sites.has(world.location) and ledger.sites[world.location].state!="exploration":return "이미 등록한 행성입니다."
		if not ledger.active.is_empty():return "진행 중인 개발 사업을 정산한 뒤 새 사업을 등록하세요."
		var registered:=ensure_site(world);registered.state="active";ledger.active=world.location;return ""
	var current:=ensure_site(world)
	var near_base: bool=near_warehouse(current,position)
	if kind=="business_mine":
		var row:=find_vein(FrontierUniverse.body_from_id(world.manifest,world.location),str(args.get("vein_id","")))
		if row.is_empty():return "광맥을 선택하세요."
		if thermal_locked(FrontierUniverse.body_from_id(world.manifest,world.location),current,row):return "고온 광맥입니다. 개발 구역의 온도 조절기로 80°C 이하까지 냉각하세요."
		var floor:=FrontierMineralWorld.point(FrontierCrewSurface.field(world),row)
		if not floor.is_finite() or floor.distance_to(position)>float(config().interaction_range) or not FrontierCrewSurface.visible_in_field(FrontierCrewSurface.field(world),position+Vector3.UP*1.72,floor+Vector3.UP):return "보이는 광맥 8m 안에서 채광하세요."
		var tool:=FrontierEquipment.active(world.crew.members[actor])
		if tool.get("kind")!="miner":return "아이템창에서 자원채집기를 제작·장착하세요."
		if int(tool.tier)<int(row.required_tier):return "이 광물은 %d등급 이상의 자원채집기가 필요합니다."%int(row.required_tier)
		if not ledger.bags.has(actor):ledger.bags[actor]=inventory()
		var amount: int=mini(int(current.remaining.get(row.id,row.capacity)),mini(int(tool.amount),FrontierItemInventory.room(world,actor,row.resource)))
		if amount<=0:return "광맥이 고갈됐거나 배낭이 가득 찼습니다."
		current.remaining[row.id]=int(current.remaining.get(row.id,row.capacity))-amount;ledger.bags[actor][row.resource]=int(ledger.bags[actor].get(row.resource,0))+amount;return ""
	if kind=="business_technology":
		if actor!=world.crew.owner_id:return "공동 기술 구매는 호스트가 진행합니다."
		if not at_ship:return "착륙선 기술 단말에 접근하세요."
		var key: String=str(args.get("technology",""));var def:=FrontierCatalog.entry("technologies",key)
		if key not in config().technologies or key in ledger.technologies:return "구매 가능한 기초 기술을 선택하세요."
		if not def.requires.is_empty() and def.requires not in ledger.technologies:return "선행 기술이 필요합니다."
		if ledger.credits<int(def.price):return "공동 크레딧이 부족합니다."
		ledger.credits-=int(def.price);ledger.technologies.append(key);return ""
	if kind=="business_recover_crate":
		var id: String=str(args.get("crate_id",""))
		if not ledger.crates.has(id):return "이미 회수한 사업 화물입니다."
		var crate: Dictionary=ledger.crates[id]
		if crate.body_id!=world.location or point(crate.position).distance_to(position)>4:return "같은 행성의 회수 화물에 접근하세요."
		if not FrontierItemInventory.fits(world,actor,crate.inventory):return "배낭을 먼저 비우세요."
		if not ledger.bags.has(actor):ledger.bags[actor]=inventory()
		transfer(ledger.bags[actor],crate.inventory,1);ledger.crates.erase(id);return ""
	if current.state=="settled":return "정산된 계약의 시설과 창고는 인계됐습니다."
	if kind=="business_withdraw":return FrontierProductionTier2.apply(world,actor,kind,args)
	if kind=="business_store_equipment":return FrontierItemInventory.warehouse_equipment(world,actor,args)
	if kind=="business_deposit":
		if not near_base:return "현장 창고 9m 이내로 돌아오세요."
		if total(bag(world,actor))==0 and int(world.crew.members[actor].carried)==0:return "반납할 자원이 없습니다."
		var resource:=str(args.get("resource",""))
		if FrontierCatalog.entry("resources",resource).is_empty() or not integer(args.get("amount"),1,int(FrontierItemInventory.config().resource_stack)):return "보관할 아이템을 창고로 끌어놓으세요."
		var amount:=int(args.amount);var stock:=bag(world,actor)
		if int(stock.get(resource,0))<amount:return "배낭의 수량이 부족합니다."
		if not FrontierItemInventory.warehouse_fits(current,{resource:amount}):return "창고가 가득 찼습니다. 아이템을 꺼내거나 창고를 추가 건설하세요."
		stock[resource]-=amount;current.inventory[resource]=int(current.inventory.get(resource,0))+amount;current.delivered+=amount;return ""
	if current.state=="exploration":
		if not ledger.active.is_empty():return "다른 행성의 복원 계약을 정산하면 이곳에서 시설을 운영할 수 있습니다. 채광은 계속 가능합니다."
		current.state="active";ledger.active=world.location
	if current.state!="active":return "정산된 계약의 시설과 창고는 인계됐습니다."
	if kind in ["business_produce","business_facility_upgrade","business_robot_upgrade"]:return FrontierProductionTier2.apply(world,actor,kind,args)
	if kind in ["business_technology","business_supply","business_settle","business_robot_rescue"] and actor!=world.crew.owner_id:return "공동 자금 지출과 정산은 호스트가 확정합니다."
	if kind=="business_supply":
		if not near_base:return "현장 창고에서 보급을 인수하세요."
		var resource: String=str(args.get("resource",""))
		if not config().store_unit_price.has(resource):return "보급 품목 오류"
		var cost: int=int(config().store_unit_price[resource])*20
		if ledger.credits<cost:return "보급 크레딧이 부족합니다."
		if not FrontierItemInventory.warehouse_fits(current,{resource:20}):return "창고 공간이 부족합니다."
		ledger.credits-=cost;current.inventory[resource]+=20;return ""
	if kind=="business_build":
		if not FrontierUniverse._vector3_array(args.get("position")):return "배치 좌표 오류"
		var p:=point(args.position);var key: String=str(args.get("building",""))
		if p.distance_to(position)>12:return "건설할 지점에 가까이 이동하세요."
		var error:=placement(world,key,p,active)
		if not error.is_empty():return error
		var def:=FrontierCatalog.entry("buildings",key)
		if current.buildings.size()>=int(config().max_buildings):return "이 개발 구역의 시설 한도에 도달했습니다."
		if not def.tech.is_empty() and def.tech not in ledger.technologies:return "시설 기술이 필요합니다."
		if not affordable(current.inventory,def.cost):return "현장 창고의 건설 재료가 부족합니다."
		transfer(current.inventory,def.cost,-1)
		var id:=identifier(ledger,"facility");current.buildings[id]={"id":id,"type":key,"position":array(p),"yaw":0.0,"enabled":true,"active":false,"status":"전력 확인 중","work":0.0};return ""
	if kind in ["business_toggle","business_demolish","business_craft"]:
		var id: String=str(args.get("building_id",""))
		if not current.buildings.has(id):return "시설을 선택하세요."
		var building: Dictionary=current.buildings[id]
		if position.distance_to(point(building.position))>float(config().interaction_range):return "시설 8m 이내로 접근하세요."
		if kind=="business_toggle":building.enabled=not building.enabled;return ""
		if kind=="business_demolish":
			if not building.get("production",{}).is_empty():return "제품 생산을 먼저 완료하세요."
			if FrontierFieldEngineering.uses(world,world.location,id):return "진행 중인 공학 실험을 완료한 뒤 철거하세요."
			for job in current.jobs.values():
				if job.factory_id==id:return "제작이 끝난 뒤 제작소를 철거하세요."
			var refund: Dictionary=FrontierCatalog.entry("buildings",building.type).cost.duplicate()
			if int(building.get("tier",1))==2:transfer(refund,FrontierProductionTier2.config().facility_upgrades[building.type].cost,1)
			if not FrontierItemInventory.warehouse_fits(current,refund,-int(FrontierItemInventory.config().warehouse_slots) if building.type=="storage" else 0):return "철거 후 창고 용량과 반환 재료 공간이 부족합니다."
			if int(building.get("tier",1))==2:transfer(current.inventory,FrontierProductionTier2.config().facility_upgrades[building.type].cost,1)
			transfer(current.inventory,FrontierCatalog.entry("buildings",building.type).cost,1);current.buildings.erase(id);return ""
		for job in current.jobs.values():
			if job.factory_id==id:return "이 제작소는 로봇을 제작 중입니다."
		if not building.active or not building.enabled:return "전력이 공급되는 가동 제작소가 필요합니다."
		if not building.get("production",{}).is_empty():return "제품 생산을 먼저 완료하세요."
		if building.type!="factory" or "robotics" not in ledger.technologies:return "기술을 갖춘 제작소가 필요합니다."
		if current.robots.size()+current.jobs.size()>=int(config().max_robots):return "현장 로봇 한도에 도달했습니다."
		if FrontierFieldEngineering.uses(world,world.location,id):return "이 제작소의 공학 시제품 제작을 먼저 완료하세요."
		var def:=FrontierCatalog.entry("robots","miner")
		if not affordable(current.inventory,def.cost):return "로봇 제작 재료가 부족합니다."
		transfer(current.inventory,def.cost,-1)
		var key:=identifier(ledger,"robot")
		var roll: int=FrontierUniverse.derive(int(world.manifest.seed),key)%100
		var grade: String="rare" if roll>=95 else ("improved" if roll>=70 else "standard")
		current.jobs[key]={"id":key,"factory_id":id,"progress":0.0,"seconds":float(def.seconds),"grade":grade};return ""
	if kind in ["business_assign","business_robot_return","business_robot_recover","business_robot_rescue"]:
		var id: String=str(args.get("robot_id",""))
		if not current.robots.has(id):return "현장 로봇을 선택하세요."
		var robot: Dictionary=current.robots[id]
		if kind in ["business_assign","business_robot_return"] and position.distance_to(point(robot.position))>float(config().interaction_range):return "로봇 8m 이내에서 작업을 지시하세요."
		if kind=="business_robot_return":robot.target="";robot.phase="return";robot.path=[];robot.status="작업 중지 · 창고 복귀";return ""
		if kind=="business_assign":
			var target: String=str(args.get("vein_id",""))
			var target_vein:=find_vein(FrontierUniverse.body_from_id(world.manifest,world.location),target)
			if target_vein.is_empty() or int(current.remaining.get(target,target_vein.capacity))<=0:return "채광할 광맥이 없습니다."
			if target_vein.get("underground",false):return "지하 광맥은 수동 채집하세요. 지하 로봇 경로는 아직 지원하지 않습니다."
			current.remaining[target]=int(current.remaining.get(target,target_vein.capacity))
			robot.target=target;robot.phase="return" if total(robot.cargo)>0 else "outbound";robot.path=[];robot.status="경로 조사 중";return ""
		if position.distance_to(point(robot.position))>6:return "로봇에 가까이 접근하세요."
		if kind=="business_robot_rescue":
			if robot.battery>=20:return "긴급 전력이 필요하지 않습니다."
			if ledger.credits<50:return "긴급 충전 비용 50 Cr가 필요합니다."
			ledger.credits-=50;robot.battery=35;robot.path=[];return ""
		if "recovery" not in ledger.technologies or not near_base:return "회수 기술을 갖추고 창고 주변으로 로봇을 돌려보내세요."
		if total(robot.cargo)>0:return "로봇 화물을 먼저 하역하세요."
		if ledger.hangar.size()>=int(FrontierVesselRefit.stats(world).hangar):return "격납고가 가득 찼습니다."
		ledger.hangar[id]=robot.duplicate(true);ledger.hangar[id].path=[];current.robots.erase(id);return FrontierVesselRefit.constraints(world)
	if kind=="business_robot_deploy":
		var id: String=str(args.get("robot_id",""))
		if not near_base or not ledger.hangar.has(id):return "창고 주변에서 운송 로봇을 선택하세요."
		if current.robots.size()+current.jobs.size()>=int(config().max_robots):return "현장 로봇 한도에 도달했습니다."
		var robot: Dictionary=ledger.hangar[id].duplicate(true);robot.position=array(point(current.center)+Vector3(3,0,0));robot.phase="idle";robot.target="";robot.path=[];robot.status="작업 배정 대기";current.robots[id]=robot;ledger.hangar.erase(id);return ""
	if kind=="business_settle":
		if not current.get("stored_equipment",{}).is_empty():return "승무원이 보관한 장비를 먼저 회수하세요."
		if not at_ship:return "착륙선 단말에서 계약 인계를 확정하세요."
		if not FrontierProductionTier2.restoration_ready(current):return "Mk.2 담수 처리·토양 개량이 필요합니다. 염류 20 이하, 토양 60 이상을 달성하세요."
		for facility in current.buildings.values():
			if not facility.get("production",{}).is_empty():return "제품 생산을 먼저 완료하세요."
		var scores:=FrontierEvaluator.scores(current.environment)
		if minf(scores.atmosphere,minf(scores.temperature,scores.water))<float(config().contract_environment_minimum) or current.environment.ecology<float(config().contract_ecology_minimum) or current.environment.stable_seconds<float(config().contract_stable_seconds):return "대기·온도·수자원 60점, 생태 20점, 30초 안정화가 필요합니다."
		if not current.jobs.is_empty():return "진행 중인 로봇 제작을 완료하세요."
		if FrontierFieldEngineering.uses(world,world.location):return "진행 중인 현장 공학 실험을 완료하세요."
		for id in ledger.bags:
			if total(ledger.bags[id])>0:return "승무원의 사업 자원을 모두 창고에 반납하세요."
		var body:=FrontierUniverse.body_from_id(world.manifest,world.location)
		var payment: int=int(config().contract_base_reward)+int(body.planet_tier)*int(config().contract_tier_reward)
		current.settlement={"payment":payment,"scores":scores,"time":current.time};current.state="settled";ledger.credits+=payment;ledger.active=""
		for robot in current.robots.values():robot.phase="idle";robot.path=[];robot.status="계약 인계 완료"
		return ""
	return "지원하지 않는 사업 작업입니다."
static func release_carrier(world: Dictionary,actor: String) -> void:
	if not world.has("business") or total(bag(world,actor))==0:return
	var ledger: Dictionary=world.business
	var id:=identifier(ledger,"business-crate")
	ledger.crates[id]={"body_id":world.location,"position":world.crew.members[actor].position.duplicate(),"inventory":bag(world,actor).duplicate(true)};ledger.bags[actor]=inventory()
static func public_view(world: Dictionary,actor: String) -> Dictionary:
	if not world.has("business"):return {}
	var ledger: Dictionary=world.business
	var view: Dictionary={"version":1,"rules_hash":ledger.rules_hash,"credits":ledger.credits,"technologies":ledger.technologies.duplicate(),"active":ledger.active if ledger.active==world.location else "","hangar_capacity":int(FrontierVesselRefit.stats(world).hangar),"active_elsewhere":ledger.active if ledger.active!=world.location else "","counter":ledger.counter,"sites":{},"hangar":{},"bags":{},"crates":{}}
	# Copy render state directly; do not first duplicate thousands of private waypoints.
	for id in ledger.hangar:view.hangar[id]=visible_robot(ledger.hangar[id])
	if ledger.sites.has(world.location):
		var source: Dictionary=ledger.sites[world.location]
		var current: Dictionary={}
		for key in source:
			if key=="robots":continue
			current[key]=source[key].duplicate(true) if source[key] is Dictionary or source[key] is Array else source[key]
		current.robots={}
		for id in source.robots:current.robots[id]=visible_robot(source.robots[id])
		view.sites[world.location]=current
	if ledger.bags.has(actor):view.bags[actor]=ledger.bags[actor].duplicate(true)
	for id in ledger.crates:
		if ledger.crates[id].body_id==world.location:view.crates[id]=ledger.crates[id].duplicate(true)
	return view
static func visible_robot(source: Dictionary) -> Dictionary:
	var result: Dictionary={"path":[]}
	for key in ["id","grade","battery","phase","target","status","work","charging"]:result[key]=source[key]
	result.tier=int(source.get("tier",1))
	result.position=source.position.duplicate();result.cargo=source.cargo.duplicate()
	return result
static func valid_inventory(value: Variant,maximum: int=100000000) -> bool:
	if not value is Dictionary or value.size()>19+FrontierProductionTier2.config().products.size():return false
	for key in inventory():
		if not value.has(key):return false
	for key in value:
		if FrontierCatalog.entry("resources",key).is_empty() or not integer(value[key],0,maximum):return false
	return true
static func integer(value: Variant,low: int,high: int) -> bool:
	return FrontierUniverse._finite(value,low,high) and value==floorf(value)
static func valid_robot(robot: Variant,id: String) -> bool:
	if not robot is Dictionary or not integer(robot.get("tier",1),1,2) or robot.get("id")!=id or robot.get("grade") not in FrontierCatalog.table("grades"):return false
	if not FrontierUniverse._vector3_array(robot.get("position")) or not FrontierUniverse._finite(robot.get("battery"),0,100) or not valid_inventory(robot.get("cargo"),FrontierProductionTier2.robot_capacity(robot)):return false
	if total(robot.cargo)>FrontierProductionTier2.robot_capacity(robot) or robot.get("phase") not in ["idle","outbound","return"] or not robot.get("target") is String or not robot.get("status") is String or not robot.get("charging") is bool:return false
	if not FrontierUniverse._finite(robot.get("work"),0,1) or not robot.get("path") is Array or robot.path.size()>3500:return false
	for p in robot.path:
		if not FrontierUniverse._vector3_array(p):return false
	return true
static func validate(value: Variant,manifest: Dictionary) -> String:
	if not value is Dictionary or value.get("version")!=1 or value.get("rules_hash")!=signature():return "사업 규칙 버전이 맞지 않습니다. 저장 원본을 보존하세요."
	if not integer(value.get("credits"),0,1000000000) or not integer(value.get("counter"),0,1000000000):return "사업 자금·순번 오류"
	if not value.get("technologies") is Array or not value.get("active") is String:return "사업 기술·활성 계약 오류"
	var techs: Dictionary={}
	for key in value.technologies:
		if key not in config().technologies or techs.has(key):return "사업 기술 중복 또는 정의 오류"
		techs[key]=true
	for key in techs:
		var required: String=FrontierCatalog.entry("technologies",key).requires
		if not required.is_empty() and not techs.has(required):return "사업 기술 선행 조건 오류"
	for key in ["sites","hangar","bags","crates"]:
		if not value.get(key) is Dictionary:return "사업 장부 구조 오류"
	if not value.active.is_empty() and (not value.sites.has(value.active) or not value.sites[value.active] is Dictionary or value.sites[value.active].get("state")!="active"):return "활성 개발 사업 참조 오류"
	if value.hangar.size()>int(FrontierVesselRefit.config().base_hangar)+int(FrontierVesselRefit.definition("cargo").hangar.max()):return "로봇 격납고 한도 오류"
	var robots: Dictionary={}
	for id in value.hangar:
		if not id is String or not valid_robot(value.hangar[id],id) or total(value.hangar[id].cargo)!=0:return "운송 로봇 오류"
		robots[id]=true
	for id in value.bags:
		if not id is String or not valid_inventory(value.bags[id],FrontierItemInventory.limit()) or FrontierItemInventory.used(value.bags[id])>FrontierItemInventory.storage_slots():return "개인 사업 운반량 오류"
	for id in value.crates:
		var crate: Variant=value.crates[id]
		if not id is String or not crate is Dictionary or not crate.get("body_id") is String or FrontierUniverse.ordinal_of(manifest,crate.body_id)<0 or not FrontierUniverse._vector3_array(crate.get("position")) or not valid_inventory(crate.get("inventory"),FrontierItemInventory.limit()) or total(crate.inventory)>FrontierItemInventory.limit():return "사업 회수 화물 오류"
	for id in value.sites:
		if not id is String or FrontierUniverse.ordinal_of(manifest,id)<0:return "개발 행성 주소 오류"
		var current: Variant=value.sites[id]
		if not current is Dictionary or current.get("state") not in ["active","settled","exploration"] or not FrontierUniverse._vector3_array(current.get("center")) or not valid_inventory(current.get("inventory")):return "개발 현장 구조 오류"
		if not current.get("stored_equipment",{}) is Dictionary:return "창고 장비 기록 오류"
		for equipment_key in current.get("stored_equipment",{}):
			var stored: Variant=current.stored_equipment[equipment_key]
			if not stored is Dictionary or not stored.get("owner") is String or not stored.get("item_id") is String or equipment_key!=stored.owner+"/"+stored.item_id or not FrontierEquipment.config().items.has(stored.get("definition","")):return "창고 장비 소유 기록 오류"
		if current.state=="active" and value.active!=id:return "활성 사업은 하나여야 합니다."
		for key in ["remaining","buildings","robots","jobs","environment","settlement"]:
			if not current.get(key) is Dictionary:return "개발 기록 형식 오류"
		if not FrontierUniverse._finite(current.get("time"),0,10000000) or not integer(current.get("delivered"),0,100000000) or not current.get("production_paid") is bool:return "생산 진행 기록 오류"
		if not FrontierUniverse._finite(current.get("power_supply"),0,10000) or not FrontierUniverse._finite(current.get("power_demand"),0,10000):return "전력 기록 오류"
		if current.state=="settled":
			if not integer(current.settlement.get("payment"),0,100000000) or not current.settlement.get("scores") is Dictionary or not FrontierUniverse._finite(current.settlement.get("time"),0,10000000):return "계약 정산 기록 오류"
		elif not current.settlement.is_empty():return "미정산 사업의 지급 기록 오류"
		var body:=FrontierUniverse.body_from_id(manifest,id)
		if FrontierMineralWorld.enabled(body):
			for vein_id in current.remaining:
				if not vein_id is String:return "광맥 ID 오류"
				var row:=find_vein(body,vein_id)
				if row.is_empty() or not integer(current.remaining[vein_id],0,int(row.capacity)):return "고갈 자원 보존 오류"
		else:
			var expected:=veins(body)
			if current.remaining.size()!=expected.size():return "시드 광맥 목록 오류"
			for row in expected:
				if not integer(current.remaining.get(row.id),0,int(row.capacity)):return "고갈 자원 보존 오류"
		if current.buildings.size()>int(config().max_buildings) or current.robots.size()+current.jobs.size()>int(config().max_robots):return "개발 규모 한도 오류"
		for key in current.buildings:
			var b: Variant=current.buildings[key]
			if not b is Dictionary or b.get("id")!=key or b.get("type") not in config().buildings or not FrontierUniverse._vector3_array(b.get("position")) or not FrontierUniverse._finite(b.get("yaw"),-TAU,TAU):return "시설 정의·위치 오류"
			if not FrontierProductionTier2.validate_building(b):return "2티어 생산·개조 기록 오류"
			if not b.get("engineering","") is String or (not b.get("engineering","").is_empty() and FrontierFieldEngineering.definition(b.engineering).get("building")!=b.type):return "시설 개조 정의 오류"
			if not b.get("enabled") is bool or not b.get("active") is bool or not b.get("status") is String or not FrontierUniverse._finite(b.get("work"),0,10000000):return "시설 운영 기록 오류"
		for key in current.robots:
			if not key is String or robots.has(key) or not valid_robot(current.robots[key],key):return "로봇 중복 소유 또는 상태 오류"
			if not current.robots[key].target.is_empty() and not current.remaining.has(current.robots[key].target):return "로봇 대상 광맥 오류"
			robots[key]=true
		for key in current.jobs:
			var job: Variant=current.jobs[key]
			if not key is String or robots.has(key) or not job is Dictionary or job.get("id")!=key or not current.buildings.has(job.get("factory_id","")) or current.buildings[job.factory_id].type!="factory" or job.get("grade") not in FrontierCatalog.table("grades"):return "로봇 제작 예약 오류"
			if job.get("seconds")!=float(FrontierCatalog.entry("robots","miner").seconds) or not FrontierUniverse._finite(job.get("progress"),0,float(job.seconds)):return "로봇 제작 진행 오류"
			robots[key]=true
		var restoration: Variant=current.get("restoration2",{})
		if not restoration is Dictionary:return "2티어 복원 기록 오류"
		if not restoration.is_empty():
			for attribute in ["salinity","soil"]:
				if not FrontierUniverse._finite(restoration.get(attribute),0,100):return "염류·토양 기록 오류"
		var e: Dictionary=current.environment
		for key in ["temperature","pressure","oxygen","toxicity","water","ecology","stable_seconds"]:
			var limits: Array={"temperature":[-273,1000],"pressure":[0,10],"oxygen":[0,1],"toxicity":[0,100],"water":[0,100],"ecology":[0,100],"stable_seconds":[0,120]}[key]
			if not FrontierUniverse._finite(e.get(key),limits[0],limits[1]):return "지역 환경 수치 오류"
	return ""

static func thermal_locked(body: Dictionary,current: Dictionary,row: Dictionary) -> bool:
	if body.get("traits",{}).get("id","")!="volcanic" or int(row.get("required_tier",1))<2:return false
	var p:=point(row.position);var center:=point(current.center)
	return Vector2(p.x-center.x,p.z-center.z).length()>float(config().build_radius) or float(current.environment.temperature)>float(body.traits.get("cooling_threshold",80))
