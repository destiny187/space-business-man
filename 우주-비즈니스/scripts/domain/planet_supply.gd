class_name FrontierPlanetSupply
extends RefCounted
## Persistent production rights and host-session industry, with physical manual freight.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_supply.json"))
	return _config
static func operating(site: Dictionary) -> bool:return site.get("state","") in ["active","supply"]
static func role(body: Dictionary) -> String:
	if not FrontierUniverse.landable(body):return ""
	var geology:=str(body.get("mineral_profile",{}).get("id",body.get("traits",{}).get("geology","")))
	for id in config().roles:
		if geology in config().roles[id].geologies:return id
	return ""
static func role_name(id: String) -> String:return str(config().roles.get(id,{}).get("name","일반 탐사"))
static func count(ledger: Dictionary) -> int:
	var result:=0
	for site in ledger.get("sites",{}).values():
		if site is Dictionary and site.get("production_lease",false)==true:result+=1
	return result
static func apply(world: Dictionary,actor: String,kind: String) -> String:
	if actor!=world.crew.owner_id:return "생산 거점 이용권은 호스트가 관리합니다."
	if FrontierCrewWorld.vector(world.crew.members[actor].position).distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))>float(FrontierCrewSurface.config().boarding_distance):return "착륙선 단말에서 생산 거점 이용권을 관리하세요."
	var body:=FrontierUniverse.body_from_id(world.manifest,world.location)
	var restriction:=FrontierUniverse.landing_restriction(body)
	if not restriction.is_empty():return restriction
	var site:=FrontierExpeditionBusiness.ensure_site(world)
	if kind=="business_lease_release":
		if not site.get("production_lease",false):return "반납할 생산 이용권이 없습니다."
		if site.state=="active":return "진행 중인 복원 계약을 먼저 정산하세요."
		if not site.buildings.is_empty() or not site.robots.is_empty() or not site.jobs.is_empty() or not site.get("stored_equipment",{}).is_empty() or FrontierExpeditionBusiness.total(site.inventory)>0:return "시설을 철거하고 로봇·창고 재고·장비를 모두 회수한 뒤 이용권을 반납하세요."
		site.erase("production_lease");site.state="exploration" if site.settlement.is_empty() else "settled";return ""
	if site.state=="settled":return "이미 인계한 시설·창고의 이용권은 되살릴 수 없습니다. 다른 행성을 선택하세요."
	if site.get("production_lease",false):return "이미 보유한 생산 거점 이용권입니다."
	if count(world.business)>=int(config().maximum_leases):return "생산 거점 한도입니다. 비운 거점의 이용권을 반납하세요."
	if int(world.business.credits)<int(config().lease_price):return "생산 거점 이용권 비용이 부족합니다."
	world.business.credits-=int(config().lease_price);site.production_lease=true
	if site.state=="exploration":site.state="supply"
	return ""
static func production_reason(body: Dictionary,building: Dictionary,recipe: Dictionary) -> String:
	if int(building.get("tier",1))<int(recipe.get("factory_tier",1)):return "Mk.%d 제작소가 필요합니다."%int(recipe.factory_tier)
	var required:=str(recipe.get("supply_role",""))
	if not required.is_empty() and role(body)!=required:return role_name(required)+" 행성에서 현지 부품을 제작·운송하세요."
	return ""
static func settlement_payment(site: Dictionary,tier: int,retain: bool) -> int:
	var reward:=FrontierCoopWorkload.reward(site,tier)
	return floori(reward*float(config().retained_reward_ratio)) if retain else reward
static func summaries(world: Dictionary) -> Array:
	var result: Array=[]
	for id in world.get("business",{}).get("sites",{}):
		var site: Dictionary=world.business.sites[id]
		if not site.get("production_lease",false):continue
		var body:=FrontierUniverse.body_from_id(world.manifest,id)
		var production: Array=[]
		for building in site.buildings.values():
			var job: Dictionary=building.get("production",{})
			if job.is_empty():continue
			production.append({"product":job.product,"progress":float(job.progress),"status":str(building.get("status","")),"active":bool(building.get("active",false))})
		result.append({"ordinal":FrontierUniverse.ordinal_of(world.manifest,id),"name":body.name,"role":role(body),"inventory":site.inventory.duplicate(),"production":production,"state":site.state,"paused":not operating(site),"remote":id!=world.location or not FrontierCrewSurface.landed(world)})
	return result

static func context(world: Dictionary,body_id: String) -> Dictionary:
	# Shallow world/crew copies redirect local rules; site/inventory/ecology stay in the draft ledger.
	var local:=world.duplicate()
	local.crew=world.crew.duplicate()
	local.crew.landing={"body_id":body_id,"epoch":int(world.crew.revision)+1}
	local.location=body_id
	return local
