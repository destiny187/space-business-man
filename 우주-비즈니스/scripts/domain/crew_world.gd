class_name FrontierCrewWorld
extends RefCounted
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/crew.json"))
	return _config
static func content_hash() -> String:
	return (FileAccess.get_file_as_string("res://data/wildlife_combat.json")+FileAccess.get_file_as_string("res://data/combat_cover.json")+FileAccess.get_file_as_string("res://data/firearms.json")+FileAccess.get_file_as_string("res://data/planet_weather.json")+FileAccess.get_file_as_string("res://data/station_economy.json")+FileAccess.get_file_as_string("res://data/terraforming_tier4.json")+FileAccess.get_file_as_string("res://data/remote_incidents.json")+FileAccess.get_file_as_string("res://data/storm_archive.json")+FileAccess.get_file_as_string("res://data/species_functions.json")+FileAccess.get_file_as_string("res://data/wildlife_behavior.json")+FileAccess.get_file_as_string("res://data/corporate_space.json")+FileAccess.get_file_as_string("res://data/corporations.json")+FileAccess.get_file_as_string("res://data/native_incidents.json")+FileAccess.get_file_as_string("res://data/suit_modules.json")+FileAccess.get_file_as_string("res://data/terraforming_tier3.json")+FileAccess.get_file_as_string("res://data/facility_blueprints.json")+FileAccess.get_file_as_string("res://data/regional_terraforming.json")+FileAccess.get_file_as_string("res://data/exploration_discoveries.json")+FileAccess.get_file_as_string("res://data/exploration_incidents.json")+FileAccess.get_file_as_string("res://data/suit_appearance.json")+FileAccess.get_file_as_string("res://data/lotus_support.json")+FileAccess.get_file_as_string("res://data/inventory.json")+FileAccess.get_file_as_string("res://data/water_interactions.json")+FileAccess.get_file_as_string("res://data/facility_water_bounds.json")+FileAccess.get_file_as_string("res://data/surface_water_physics.json")+FileAccess.get_file_as_string("res://data/expedition_research.json")+FileAccess.get_file_as_string("res://data/crew_stations.json")+FileAccess.get_file_as_string("res://data/crew_augmentation.json")+FileAccess.get_file_as_string("res://data/early_access.json")+FileAccess.get_file_as_string("res://data/shuttles.json")+FileAccess.get_file_as_string("res://data/planet_supply.json")+FileAccess.get_file_as_string("res://data/planetary_cycles.json")+FileAccess.get_file_as_string("res://data/rovers.json")+FileAccess.get_file_as_string("res://data/coop_workload.json")+FileAccess.get_file_as_string("res://data/progression_research.json")+FileAccess.get_file_as_string("res://data/ground_progression.json")+FileAccess.get_file_as_string("res://data/robot_work.json")+FileAccess.get_file_as_string("res://data/crew_locomotion.json")+FileAccess.get_file_as_string("res://data/crew.json")+FileAccess.get_file_as_string("res://data/galaxy.json")+FileAccess.get_file_as_string("res://data/space_presentation.json")+FileAccess.get_file_as_string("res://data/terrain.json")+FileAccess.get_file_as_string("res://data/underground.json")+FileAccess.get_file_as_string("res://data/crew_surface.json")+FileAccess.get_file_as_string("res://data/ecology.json")+FrontierEcologyCatalog.signature()+FrontierEcologyCatalog.extension_signature()+FrontierEcologyCatalog.flora_signature()+FrontierEcologyCatalog.biota_signature()+FileAccess.get_file_as_string("res://data/native_biota.json")+FileAccess.get_file_as_string("res://data/ecology_expansion.json")+FrontierExpeditionBusiness.signature()+FrontierFieldEngineering.signature()+FrontierVesselRefit.signature()+FileAccess.get_file_as_string("res://data/equipment.json")+FileAccess.get_file_as_string("res://data/production_tier2.json")+FileAccess.get_file_as_string("res://data/landing_resources.json")+FileAccess.get_file_as_string("res://data/mineral_world.json")+FileAccess.get_file_as_string("res://data/minerals.json")+FileAccess.get_file_as_string("res://data/planet_diversity.json")+FileAccess.get_file_as_string("res://data/system_diversity.json")+FileAccess.get_file_as_string("res://data/surface_details.json")+FileAccess.get_file_as_string("res://data/flight_experience.json")+FileAccess.get_file_as_string("res://data/stellar_navigation.json")+FileAccess.get_file_as_string("res://data/space_stations.json")+FileAccess.get_file_as_string("res://data/celestial_names.json")).sha256_text()
static func create(owner: Dictionary) -> Dictionary:
	return {"version":1,"world_id":FrontierPlayerProfile.token(),"owner_id":owner.character_id,"revision":0,"pilot_id":owner.character_id,"members":{owner.character_id:member(owner,"",0)},"rock":int(config().starting_rock),"recovery":{},"receipts":{}}
static func member(profile: Dictionary,hash_value: String,index: int) -> Dictionary:
	return {"augmentation":FrontierCrewAugmentation.create(),"vitals":FrontierCrewVitals.create(),"loadout":FrontierEquipment.create(profile),"profile":profile.duplicate(true),"capability_hash":hash_value,"position":config().spawn_positions[index%6].duplicate(),"area":"cabin","aboard":true,"ready":false,"carried":0,"last_sequence":0}
static func vector(value: Array) -> Vector3:return Vector3(value[0],value[1],value[2])
static func validate(value: Variant) -> String:
	if not value is Dictionary or value.get("version")!=1 or not FrontierPlayerProfile.identifier(value.get("world_id")):return "협동 세계 버전·ID 오류"
	if not value.get("members") is Dictionary or not value.members.has(value.get("owner_id")) or not value.members.has(value.get("pilot_id")):return "승무원 소유·조종 기록 오류"
	if not FrontierUniverse._finite(value.get("revision"),0,9007199254740000) or value.revision!=floorf(value.revision):return "협동 변경 순번 오류"
	if not FrontierUniverse._finite(value.get("rock"),0,100000000) or value.rock!=floorf(value.rock):return "공동 창고 수량 오류"
	if not value.get("cargo",{}) is Dictionary:return "우주선 화물 기록 오류"
	for resource in value.get("cargo",{}):
		if resource=="stone" or FrontierCatalog.entry("resources",resource).is_empty() or not FrontierExpeditionBusiness.integer(value.cargo[resource],0,100000000):return "우주선 화물 수량 오류"
	if not value.get("cargo_equipment",{}) is Dictionary:return "우주선 장비 기록 오류"
	for key in value.get("cargo_equipment",{}):
		var stored: Variant=value.cargo_equipment[key]
		if not stored is Dictionary or not stored.get("owner") is String or not stored.get("item_id") is String or key!=stored.owner+"/"+stored.item_id or not FrontierEquipment.config().items.has(stored.get("definition","")):return "우주선 장비 소유 오류"
	if not value.get("receipts") is Dictionary or value.receipts.size()>128 or not value.get("recovery") is Dictionary:return "공동 거래 기록 오류"
	if value.has("landing"):
		if not value.landing is Dictionary:return "공동 착륙 기록 오류"
		if not value.landing.is_empty() and (not value.landing.get("body_id") is String or not FrontierUniverse._finite(value.landing.get("epoch"),1,9007199254740000)):return "공동 착륙 주소·순번 오류"
	if value.has("navigation"):
		var navigation_error:=FrontierCrewNavigation.validate(value.navigation)
		if not navigation_error.is_empty():return navigation_error
	if value.has("survey") and not FrontierSurfaceSurvey.valid(value.survey):return "광물 조사 기록 오류"
	if value.has("corporations") and not FrontierCorporations.valid(value.corporations):return "기업 식별 기록 오류"
	if value.has("corporate_traces") and not FrontierCorporateTraces.valid(value.corporate_traces):return "기업 활동 조사 기록 오류"
	if value.has("freight_records") and not FrontierFreightSalvage.valid(value.freight_records,value):return "유실 화물 적재 기록 오류"
	if not FrontierWildlifeCombat.valid(value):return "생물 교전 기록 오류"
	if value.has("wildlife_stops"):
		if not value.wildlife_stops is Dictionary or not value.get("combat",{}) is Dictionary:return "생물 정지 기록 형식 오류"
		for key in value.wildlife_stops:
			var stop: Variant=value.wildlife_stops[key]
			if not key is String or value.get("combat",{}).get(key,1)!=0 or not stop is Dictionary or not FrontierUniverse._vector3_array(stop.get("position")) or not FrontierUniverse._finite(stop.get("yaw"),-PI-.001,PI+.001):return "생물 정지 위치 오류"
	if value.has("combat"):
		if not value.combat is Dictionary:return "전투 기록 형식 오류"
		for target_id in value.combat:
			if not target_id is String or not FrontierUniverse._finite(value.combat[target_id],0,int(FrontierWildlifeCombat.config().maximum_health)):return "개체 체력 기록 오류"
	for id in value.members:
		var record: Variant=value.members[id]
		if not record is Dictionary:return "승무원 형식 오류"
		var error:=FrontierPlayerProfile.validate_character(record.get("profile"))
		if not error.is_empty() or id!=record.profile.character_id:return "승무원 캐릭터·장비 오류"
		if record.has("shuttle_recalled") and not record.shuttle_recalled is bool:return "소형선 회수 기록 오류"
		if record.has("loadout") and not FrontierEquipment.validate(record.loadout).is_empty():return "아이템·장착 기록 오류"
		if record.has("suit_dyes") and not FrontierSuitDye.validate(record.suit_dyes):return "탐험복 염색 기록 오류"
		if record.has("augmentation") and not FrontierCrewAugmentation.validate(record.augmentation):return "신체 증강 기록 오류"
		if record.has("modules") and not FrontierSuitModules.validate(record.modules):return "내장 모듈 기록 오류"
		if record.has("vitals") and not FrontierCrewVitals.validate(record.vitals,record):return "탐험복 체력·스태미나 기록 오류"
		if not record.get("capability_hash") is String or (id!=value.owner_id and not FrontierPlayerProfile.identifier(record.capability_hash,64)):return "재접속 자격 오류"
		if not FrontierUniverse._vector3_array(record.get("position")) or record.get("area") not in ["cabin","surface"]:return "승무원 위치 오류"
		if not record.get("ready") is bool or not record.get("aboard") is bool:return "탑승 준비 기록 오류"
		if not FrontierUniverse._finite(record.get("carried"),0,int(config().backpack_capacity)) or record.carried!=floorf(record.carried):return "운반 화물 오류"
		if not FrontierUniverse._finite(record.get("last_sequence"),0,9007199254740000) or record.last_sequence!=floorf(record.last_sequence):return "개인 요청 순번 오류"
	var shuttle_error:=FrontierShuttles.validate(value)
	if not shuttle_error.is_empty():return shuttle_error
	for id in value.recovery:
		var crate: Variant=value.recovery[id]
		if not id is String or not crate is Dictionary or not FrontierUniverse._vector3_array(crate.get("position")) or crate.get("area") not in ["cabin","surface"]:return "회수 보관 위치 오류"
		if not FrontierUniverse._finite(crate.get("rock"),1,int(config().backpack_capacity)) or crate.rock!=floorf(crate.rock):return "회수 화물 수량 오류"
	for id in value.receipts:
		var receipt: Variant=value.receipts[id]
		if not id is String or not receipt is Dictionary or not receipt.get("result") is Dictionary or not FrontierPlayerProfile.identifier(receipt.get("digest"),64):return "거래 수령 기록 오류"
	return ""
static func public_snapshot(value: Dictionary,active: Dictionary) -> Dictionary:
	var result:=value.duplicate()
	result.erase("survey");result.erase("receipts");result.erase("corporate_traces");result.erase("freight_records");result=result.duplicate(true)
	if value.has("corporate_traces"):
		result.corporate_traces=FrontierCorporateTraces.snapshot(value.corporate_traces,int(value.navigation.system))
	if value.has("freight_records"):result.freight_records=FrontierFreightSalvage.snapshot(value.freight_records,int(value.navigation.system))
	# Keep movement snapshots bounded; the full saved history is queried on demand.
	if value.has("survey"):
		result.survey={}
		var keys: Array=value.survey.keys()
		for key in keys.slice(maxi(0,keys.size()-256)):result.survey[key]=value.survey[key].duplicate(true)
	if result.has("wildlife_encounters"):
		var prefix: String=str(result.get("landing",{}).get("body_id",""))+"/"
		for key in result.wildlife_encounters.keys():
			if not key.begins_with(prefix):result.wildlife_encounters.erase(key)
	if result.has("wildlife_stops"):
		var prefix: String=str(result.get("landing",{}).get("body_id",""))+"/"
		for key in result.wildlife_stops.keys():
			if not key.begins_with(prefix):result.wildlife_stops.erase(key)
	for id in result.members:
		result.members[id].erase("capability_hash")
		result.members[id].connected=id in active.values()
	return result
static func apply(value: Dictionary,actor: String,kind: String,args: Dictionary,active: Dictionary) -> String:
	var member: Dictionary=value.members[actor]
	match kind:
		"ready":
			if not args.get("value") is bool:return "준비 상태 오류"
			if args.value and not member.aboard and (member.area!="surface" or value.get("landing",{}).is_empty() or vector(member.position).distance_to(vector(FrontierCrewSurface.config().ship_position))>float(FrontierCrewSurface.config().boarding_distance)):return "우주선으로 돌아와 준비 상태를 선택하세요."
			member.ready=args.value
		"pilot":
			if actor!=value.owner_id:return "호스트만 조종 권한을 넘길 수 있습니다."
			if not args.get("character_id") is String or args.character_id not in active.values():return "연결된 승무원을 선택하세요."
			value.pilot_id=args.character_id
		"withdraw", "deposit":
			if member.area!="cabin" or vector(member.position).distance_to(vector(config().locker_position))>float(config().interaction_distance):return "공동 보관함에 가까이 이동하세요."
			if not FrontierUniverse._finite(args.get("amount"),1,int(config().backpack_capacity)) or args.amount!=floorf(args.amount):return "옮길 수량이 올바르지 않습니다."
			var amount:=int(args.amount)
			if kind=="withdraw":
				if int(value.rock)<amount or int(member.carried)+amount>int(config().backpack_capacity):return "창고 잔량 또는 배낭 공간이 부족합니다."
				value.rock-=amount;member.carried+=amount
			else:
				if int(member.carried)<amount:return "운반 중인 화물이 부족합니다."
				member.carried-=amount;value.rock+=amount
		"recover":
			if not args.get("crate_id") is String or not value.recovery.has(args.crate_id):return "이미 회수된 화물입니다."
			var crate: Dictionary=value.recovery[args.crate_id]
			if crate.area=="surface" and crate.get("body_id","")!=value.get("landing",{}).get("body_id",""):return "이 화물은 다른 행성에 남아 있습니다."
			if member.area!=crate.area or vector(member.position).distance_to(vector(crate.position))>float(config().interaction_distance):return "화물 위치에 가까이 이동하세요."
			if int(member.carried)+int(crate.rock)>int(config().backpack_capacity):return "배낭 공간이 부족합니다."
			member.carried+=crate.rock;value.recovery.erase(args.crate_id)
		_:return "지원하지 않는 협동 작업입니다."
	return ""
static func disconnect_member(value: Dictionary,actor: String) -> void:
	var member: Dictionary=value.members[actor]
	member.ready=false
	if int(member.carried)>0 and not member.has("shuttle_id") and not member.get("shuttle_recalled",false):
		var id: String=actor+":"+str(int(value.revision))
		value.recovery[id]={"position":member.position.duplicate(),"area":member.area,"rock":int(member.carried)}
		if member.area=="surface":value.recovery[id]["body_id"]=value.get("shuttles",{}).get(actor,{}).get("location","") if member.has("shuttle_id") else value.get("landing",{}).get("body_id","")
		member.carried=0
	if value.pilot_id==actor:value.pilot_id=value.owner_id
