class_name FrontierFacilityResearch
extends RefCounted
## Shared licenses are separate from historical catalog/save hashes.
static var _config: Dictionary={}
static func config() -> Dictionary:
 if _config.is_empty():
  _config=JSON.parse_string(FileAccess.get_file_as_string("res://data/facility_research.json"))
  _config.projects.merge(FrontierDiscoveryIndustry.config().projects)
 return _config
static func owned(ledger: Dictionary,key: String) -> bool:
 return key in ledger.get("facility_research",[])
static func migrate(world: Dictionary) -> void:
 if not world.has("business"):return
 var ledger: Dictionary=world.business
 if ledger.has("facility_research"):return
 ledger.facility_research=[]
 # Existing upgraded facilities grant their licenses once, including retained outposts.
 for site in ledger.sites.values():
  for row in site.buildings.values():
   if int(row.get("tier",1))>=2 and config().projects.has(row.type) and not owned(ledger,row.type):ledger.facility_research.append(row.type)
static func construction(kind: String) -> Dictionary:
 var definition:=FrontierCatalog.entry("buildings",kind).duplicate(true)
 if kind=="factory":
  definition.name="현장 제작소 Mk.2";definition.tier=2
 return definition
static func gate(ledger: Dictionary,key: String) -> String:
 if not config().projects.has(key) or owned(ledger,key):return ""
 return "착륙선 연구 → 공동 설비에서 "+str(config().projects[key].name)+" 연구가 필요합니다."
static func construction_unlocked(ledger: Dictionary,kind: String) -> bool:
 if (kind=="factory" or FrontierDiscoveryIndustry.building(kind)) and not owned(ledger,kind):return false
 var definition:=construction(kind)
 if not FrontierEarlyAccess.available(ledger,str(definition.get("tech",""))):return false
 var tier:=int(definition.get("tier",1))
 var blueprint:=FrontierFacilityBlueprints.required({"type":kind},tier)
 return tier<3 or blueprint.is_empty() or blueprint in ledger.get("facility_blueprints",[])
static func reason(world: Dictionary,actor: String,key: String) -> String:
 if not config().projects.has(key):return "설비 연구를 선택하세요."
 if actor!=world.crew.owner_id:return "공동 설비 연구는 호스트가 구매합니다."
 if not FrontierCrewSurface.landed(world):return "착륙선 연구 장치에서 구매하세요."
 if FrontierCrewWorld.vector(world.crew.members[actor].position).distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))>float(FrontierCrewSurface.config().boarding_distance):return "착륙선 연구 장치에 접근하세요."
 var ledger: Dictionary=world.get("business",{})
 if owned(ledger,key):return "연구 완료"
 var def: Dictionary=config().projects[key]
 if not FrontierDiscoveryIndustry.proof(world,key):
  var source: Dictionary=FrontierExplorationIncidents.definition(def.discoveries[0]) if def.get("source","")=="incidents" else FrontierExplorationDiscoveries.definition(def.discoveries[0])
  return "먼저 "+str(source.name)+" 조사를 완료하세요."
 if int(ledger.get("credits",0))<int(def.price):return "공동 크레딧이 부족합니다."
 if not FrontierExpeditionBusiness.affordable(FrontierExpeditionBusiness.bag(world,actor),def.cost):return "내 배낭에 연구 재료를 준비하세요."
 return ""
static func apply(world: Dictionary,actor: String,args: Dictionary) -> String:
 var key:=str(args.get("research",""));var error:=reason(world,actor,key)
 if not error.is_empty():return error
 var def: Dictionary=config().projects[key]
 world.business.credits-=int(def.price)
 FrontierExpeditionBusiness.transfer(world.business.bags[actor],def.cost,-1)
 if not world.business.has("facility_research"):world.business.facility_research=[]
 world.business.facility_research.append(key)
 return ""
static func valid(value: Variant) -> bool:
 if not value is Array or value.size()>config().projects.size():return false
 var found: Dictionary={}
 for id in value:
  if not id is String or not config().projects.has(id) or found.has(id):return false
  found[id]=true
 return true
