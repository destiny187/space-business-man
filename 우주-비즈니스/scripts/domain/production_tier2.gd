class_name FrontierProductionTier2
extends RefCounted
## Shared products use the existing host inventory and atomic command transaction.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/production_tier2.json"))
	return _config
static func product(id: String) -> Dictionary:return config().products.get(id,{})
static func factor(row: Dictionary) -> float:
	return float(config().facility_upgrades.get(row.get("type",""),{}).get("factor",1)) if int(row.get("tier",1))==2 else 1.0
static func robot_capacity(row: Dictionary) -> int:
	return int(config().robot_upgrade.capacity) if int(row.get("tier",1))==2 else int(FrontierExpeditionBusiness.config().robot_capacity)
static func apply(world: Dictionary,actor: String,kind: String,args: Dictionary) -> String:
	var site:=FrontierExpeditionBusiness.site(world)
	var position:=FrontierCrewWorld.vector(world.crew.members[actor].position)
	if kind=="business_withdraw":
		if position.distance_to(FrontierCrewWorld.vector(site.center))>float(FrontierExpeditionBusiness.config().deposit_range):return "현장 창고 9m 이내에서 인수하세요."
		var id:=str(args.get("resource",""))
		if FrontierCatalog.entry("resources",id).is_empty() or not FrontierExpeditionBusiness.integer(args.get("amount"),1,96):return "인수할 품목과 수량을 확인하세요."
		var amount:=int(args.amount)
		if int(site.inventory.get(id,0))<amount:return "공동 창고의 수량이 부족합니다."
		if not world.business.bags.has(actor):world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
		var bag: Dictionary=world.business.bags[actor]
		if FrontierExpeditionBusiness.total(bag)+amount>int(FrontierExpeditionBusiness.config().bag_capacity):return "배낭 여유 공간이 부족합니다."
		site.inventory[id]-=amount;bag[id]=int(bag.get(id,0))+amount;return ""
	var id:=str(args.get("building_id",args.get("robot_id","")))
	var robot: bool=kind=="business_robot_upgrade"
	var rows: Dictionary=site.robots if robot else site.buildings
	if not rows.has(id):return "개조할 대상이나 생산할 제작소를 선택하세요."
	var row: Dictionary=rows[id]
	if position.distance_to(FrontierCrewWorld.vector(row.position))>8:return "대상 8m 이내로 접근하세요."
	if kind=="business_produce":
		if row.type!="factory":return "현장 제작소에서 제품을 생산하세요."
		if not row.get("production",{}).is_empty():return "이 제작소는 제품을 생산 중입니다."
		for job in site.jobs.values():
			if job.factory_id==id:return "로봇 제작을 먼저 완료하세요."
		if FrontierFieldEngineering.uses(world,world.location,id):return "공학 실험을 먼저 완료하세요."
		var key:=str(args.get("product",""));var recipe:=product(key)
		if recipe.is_empty():return "지원하지 않는 제품입니다."
		if not FrontierExpeditionBusiness.affordable(site.inventory,recipe.cost):return "현장 창고의 가공 재료가 부족합니다."
		FrontierExpeditionBusiness.transfer(site.inventory,recipe.cost,-1)
		row.production={"product":key,"progress":0.0};return ""
	if kind not in ["business_facility_upgrade","business_robot_upgrade"]:return "지원하지 않는 생산 작업입니다."
	if int(row.get("tier",1))>=2:return "현재 최고 단계인 Mk.2입니다."
	var def: Dictionary=config().robot_upgrade if robot else config().facility_upgrades.get(row.type,{})
	if def.is_empty():return "이 시설은 현재 개조 대상이 아닙니다."
	if not robot:
		if not row.get("production",{}).is_empty() or FrontierFieldEngineering.uses(world,world.location,id):return "진행 중인 제작·실험을 먼저 완료하세요."
		for job in site.jobs.values():
			if job.factory_id==id:return "로봇 제작을 먼저 완료하세요."
	if not FrontierExpeditionBusiness.affordable(site.inventory,def.cost):return "현장 창고의 Mk.2 부품이 부족합니다."
	FrontierExpeditionBusiness.transfer(site.inventory,def.cost,-1);row.tier=2;return ""
static func tick(site: Dictionary,dt: float) -> void:
	for row in site.buildings.values():
		var job: Dictionary=row.get("production",{})
		if job.is_empty():continue
		var recipe:=product(job.product)
		if not row.active:continue
		job.progress=minf(float(recipe.seconds),float(job.progress)+dt*factor(row))
		row.status=recipe.name+" · %d%%"%int(float(job.progress)/float(recipe.seconds)*100)
		if float(job.progress)<float(recipe.seconds):continue
		site.inventory[job.product]=int(site.inventory.get(job.product,0))+int(recipe.amount)
		row.production={};row.product_serial=int(row.get("product_serial",0))+1;row.status=recipe.name+" · 생산 완료"
static func restoration_ready(site: Dictionary) -> bool:
	var r: Dictionary=site.get("restoration2",{})
	return r.is_empty() or (float(r.salinity)<=float(config().restoration.salinity_target) and float(r.soil)>=float(config().restoration.soil_target))
static func restore(site: Dictionary,b: Dictionary,dt: float) -> void:
	if int(b.get("tier",1))!=2:return
	var cfg: Dictionary=config().restoration
	var r: Dictionary=site.get("restoration2",{})
	var item: String="";var needed:=false
	if b.type=="water" and not r.is_empty():item="mineral_filter";needed=float(r.salinity)>0
	elif b.type=="biolab" and not r.is_empty():item="soil_base";needed=float(r.soil)<100
	elif b.type=="atmosphere":item="mineral_filter";needed=float(site.environment.toxicity)>0
	if not needed:return
	if int(site.inventory.get(item,0))<=0:b.status=product(item).name+" 공급 필요";return
	b.treatment_work=float(b.get("treatment_work",0))+dt
	var cycle: float=cfg.soil_cycle if item=="soil_base" else cfg.filter_cycle
	if float(b.treatment_work)<cycle:return
	b.treatment_work-=cycle;site.inventory[item]-=1
	if b.type=="water":r.salinity=maxf(0,float(r.salinity)-float(cfg.salt_per_filter))
	elif b.type=="biolab":r.soil=minf(100,float(r.soil)+float(cfg.soil_per_pack))
	else:site.environment.toxicity=maxf(0,float(site.environment.toxicity)-float(cfg.salt_per_filter))
static func validate_building(b: Dictionary) -> bool:
	if not FrontierExpeditionBusiness.integer(b.get("tier",1),1,2):return false
	if int(b.get("tier",1))==2 and not config().facility_upgrades.has(b.type):return false
	if not FrontierUniverse._finite(b.get("treatment_work",0),0,10000000) or not FrontierExpeditionBusiness.integer(b.get("product_serial",0),0,100000000):return false
	var job: Variant=b.get("production",{})
	if not job is Dictionary:return false
	if job.is_empty():return true
	if b.type!="factory" or not job.get("product") is String or product(job.product).is_empty():return false
	return FrontierUniverse._finite(job.get("progress"),0,float(product(job.product).seconds))
