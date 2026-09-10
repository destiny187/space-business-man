class_name FrontierCooperTechClues
extends RefCounted
## Orbital evidence references one existing seeded ground incident; rewards remain ground-owned.
const TEMPLATE := "illuti_dormant_combat_robot" # Retained save/content ID, displayed as CooperTech.
const STATES := ["지상 좌표 확보","현장 로봇 발견","부품 회수 · 사건 종결"]
static func enabled(m: Dictionary) -> bool:return m.settings.get("corporate_space",{}).get("coopertech_links",{}).get("version",0)==1
static func records(world: Dictionary) -> Dictionary:return world.get("coopertech_clues",{})
static func candidate(world: Dictionary,trace: Dictionary) -> Dictionary:
	var m: Dictionary=world.manifest;var system:=int(trace.system)
	var ordinals: Array=[int(trace.body)]
	for slot in FrontierUniverse.body_count(m,system):
		var ordinal:=system*8+slot
		if ordinal not in ordinals:ordinals.append(ordinal)
	for ordinal in ordinals:
		var body:=FrontierUniverse.body(m,ordinal)
		if not body.landable or int(body.planet_tier)<2:continue
		var field:=FrontierExplorationIncidents.field(body)
		for radius in 3:
			for x in range(-radius,radius+1):
				for z in range(-radius,radius+1):
					if maxi(absi(x),absi(z))!=radius:continue
					for row in FrontierExplorationIncidents.tile(body,field,Vector2i(x,z)):
						if row.template!=TEMPLATE:continue
						var key:=FrontierExplorationIncidents.key(row)
						if FrontierExplorationIncidents.records(world).has(key):return {"body":ordinal,"row":FrontierExplorationIncidents.records(world)[key]}
						var buildings: Dictionary=world.get("business",{}).get("sites",{}).get(body.id,{}).get("buildings",{})
						if buildings.values().any(func(b):return FrontierCrewWorld.vector(b.position).distance_to(FrontierCrewWorld.vector(row.position))<float(FrontierExplorationIncidents.config().exclusion_radius)):continue
						return {"body":ordinal,"row":row}
	return {}
static func capture(world: Dictionary,trace: Dictionary) -> void:
	if not enabled(world.manifest) or trace.company!="coopertech" or records(world).has(trace.id):return
	var found:=candidate(world,trace)
	if found.is_empty():return
	var row: Dictionary=found.row;var key:=FrontierExplorationIncidents.key(row)
	FrontierExplorationIncidents.ensure(world)
	if not world.incidents.records.has(key):world.incidents.records[key]=FrontierExplorationIncidents.create(row)
	if not world.has("coopertech_clues"):world.coopertech_clues={}
	world.coopertech_clues[trace.id]={"body":found.body,"incident":key}
static func describe(world: Dictionary,id: String) -> Dictionary:
	var link: Dictionary=records(world).get(id,{})
	if link.is_empty():return {}
	var row: Dictionary=FrontierExplorationIncidents.records(world).get(link.incident,{})
	if row.is_empty():return {}
	var trace:=FrontierCorporateTraces.definition(world.manifest,id)
	return {"id":id,"incident":link.incident,"body":int(link.body),"body_id":row.body_id,"position":row.position.duplicate(),"stage":2 if row.claimed else (1 if row.seen else 0),"name":"CooperTech 폐기 로봇 추적","model":"incidents/robot","source":trace.get("name","CooperTech 기록"),"source_body":trace.get("body",link.body)}
static func snapshot(world: Dictionary,body_id: String) -> Dictionary:
	var result: Dictionary={};var ids:=records(world).keys();ids.reverse()
	for id in ids:
		var row:=describe(world,id)
		if row.is_empty():continue
		if result.size()<256 or row.body_id==body_id:result[id]=row
	return result
static func validate(world: Dictionary) -> String:
	if not world.has("coopertech_clues"):return ""
	if not enabled(world.manifest) or not world.coopertech_clues is Dictionary or world.coopertech_clues.size()>125000:return "CooperTech 좌표 기록 형식 오류"
	for id in world.coopertech_clues:
		if not id is String or int(FrontierCorporateTraces.records(world).get(id,0))!=2:return "CooperTech 출처 조사 기록 오류"
		var trace:=FrontierCorporateTraces.definition(world.manifest,id)
		var link: Variant=world.coopertech_clues[id]
		if trace.is_empty() or trace.company!="coopertech" or not link is Dictionary or not FrontierExpeditionBusiness.integer(link.get("body"),0,999999) or not link.get("incident") is String:return "CooperTech 좌표 식별 오류"
		var row: Dictionary=FrontierExplorationIncidents.records(world).get(link.incident,{})
		if row.is_empty() or row.template!=TEMPLATE or row.body_id!=FrontierUniverse.body_id(world.manifest,int(link.body)) or int(link.body)/8!=int(trace.system):return "CooperTech 지상 사건 연결 오류"
	return ""
