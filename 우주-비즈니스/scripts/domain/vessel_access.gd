class_name FrontierVesselAccess
extends RefCounted
## Capabilities belong to the active hull. Role, rarity and jump range remain independent.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/vessel_access.json"))
	return _config
static func capabilities(vessel: Dictionary) -> Dictionary:
	var hull: String=str(vessel.get("hull","kestrel"))
	var result: Dictionary=config().hull_capabilities.get(hull,{}).duplicate()
	var refit: String=str(int(vessel.get("navigation_refits",{}).get(hull,0)))
	for key in config().refits.get(refit,{}).get("capabilities",{}):
		result[key]=maxf(float(result.get(key,0)),float(config().refits[refit].capabilities[key]))
	# Optional authored module capabilities use the existing grade/loadout structure.
	for id in vessel.get("loadout",{}).values():
		var module: Dictionary=vessel.get("modules",{}).get(id,{})
		if module.is_empty():continue
		var def:=FrontierVesselRefit.definition(str(module.type))
		var grade:=FrontierVesselRefit.grade_index(str(module.grade))
		for key in def.get("capabilities",{}):result[key]=float(result.get(key,0))+float(def.capabilities[key][grade])
	return result
static func tier_for(caps: Dictionary) -> int:
	var result:=2
	for tier in range(3,6):
		if not missing(caps,tier).is_empty():break
		result=tier
	return result
static func missing(caps: Dictionary,tier: int) -> Array:
	var result: Array=[]
	for key in config().tier_requirements.get(str(tier),{}):
		var needed:=float(config().tier_requirements[str(tier)][key])
		if float(caps.get(key,0))<needed:result.append({"id":key,"name":config().capabilities[key].name,"current":float(caps.get(key,0)),"required":needed})
	return result
static func reason(caps: Dictionary,tier: int) -> String:
	var gaps:=missing(caps,tier)
	if gaps.is_empty():return ""
	var names:=PackedStringArray()
	for row in gaps:names.append("%s %d/%d"%[row.name,row.current,row.required])
	return "T%d 항해 내성 부족 · %s. 선박 정비(K) 또는 정거장에서 개장·선체 교체하세요."%[tier," · ".join(names)]
static func world_capabilities(world: Dictionary) -> Dictionary:
	return world.get("navigation_capabilities",capabilities(world.get("vessel",{})))
static func system_tier(manifest: Dictionary,index: int) -> int:
	return maxi(2,int(FrontierUniverse.system(manifest,index).get("band",0))+1)
static func departure_tier(manifest: Dictionary,nav: Dictionary,ordinal: int) -> int:
	var index:=FrontierUniverse.system_index(manifest,ordinal)
	# Interstellar arrival is a system entry; planet approach is a separate operation.
	return system_tier(manifest,index) if index!=int(nav.system) else int(FrontierUniverse.body(manifest,ordinal,false).planet_tier)
static func departure_reason(world: Dictionary,ordinal: int) -> String:
	var nav: Dictionary=world.crew.navigation
	var index:=FrontierUniverse.system_index(world.manifest,ordinal)
	# Preserve a way out of old saves and of a deliberately downgraded hull.
	if index!=int(nav.system) and system_tier(world.manifest,index)<system_tier(world.manifest,int(nav.system)):return ""
	if index!=int(nav.system) and not reason(world_capabilities(world),system_tier(world.manifest,int(nav.system))).is_empty():
		if FrontierUniverse.map_position(world.manifest,index).length()>FrontierUniverse.map_position(world.manifest,int(nav.system)).length()+.001:return ""
	return landing_reason(world,ordinal) if index==int(nav.system) else reason(world_capabilities(world),system_tier(world.manifest,index))
static func landing_reason(world: Dictionary,ordinal: int) -> String:
	if world.has("local_shuttle") and FrontierUniverse.body_id(world.manifest,ordinal)==world.get("mothership_location",""):return ""
	return reason(world_capabilities(world),int(FrontierUniverse.body(world.manifest,ordinal,false).planet_tier))
static func next_refit(vessel: Dictionary) -> int:
	# Permanent hull refits do not disappear when optional mission modules are removed.
	var bare:=vessel.duplicate();bare.loadout={}
	return tier_for(capabilities(bare))+1
static func apply(world: Dictionary,tier: int,at_station: bool=false) -> String:
	var vessel: Dictionary=world.vessel
	if tier!=next_refit(vessel) or not config().refits.has(str(tier)):return "현재 선체의 다음 항해 개장 단계를 선택하세요."
	var row: Dictionary=config().refits[str(tier)]
	var credits:=int(row.station_credits if at_station else row.field_credits)
	var site: Dictionary={} if at_station else FrontierExpeditionBusiness.site(world)
	if not at_station and (site.is_empty() or not FrontierPlanetSupply.operating(site)):return "현장 창고와 운영 중인 사업이 필요합니다. 정거장에서는 부품 포함 개장을 구매할 수 있습니다."
	if int(world.business.credits)<credits:return "항해 개장에 필요한 공동 자금 %d Cr가 부족합니다."%credits
	if not at_station and not FrontierExpeditionBusiness.affordable(site.inventory,row.materials):return "항해 개장용 가공 부품을 현장 창고에 준비하세요."
	world.business.credits-=credits
	if not at_station:FrontierExpeditionBusiness.transfer(site.inventory,row.materials,-1)
	if not vessel.has("navigation_refits"):vessel.navigation_refits={}
	vessel.navigation_refits[str(vessel.get("hull","kestrel"))]=tier
	for member in world.crew.members.values():member.ready=false
	return ""
static func validate(vessel: Dictionary) -> String:
	var refits: Variant=vessel.get("navigation_refits",{})
	if not refits is Dictionary:return "선체 항해 개장 기록 오류"
	for hull in refits:
		if hull not in vessel.get("hulls",["kestrel"]) or not FrontierExpeditionBusiness.integer(refits[hull],3,5):return "보유 선체 항해 개장 단계 오류"
	return ""
