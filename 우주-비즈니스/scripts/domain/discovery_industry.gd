class_name FrontierDiscoveryIndustry
extends RefCounted
## Optional discovery designs use existing shared licenses and local industrial stores.
static var _config: Dictionary={}
static var _indexed_records: Dictionary={}
static var _indexed_count: int=-1
static var _heat_sources: Dictionary={}
static var _evidence_projects: Dictionary={}
static func config() -> Dictionary:
 if _config.is_empty():
  _config=JSON.parse_string(FileAccess.get_file_as_string("res://data/discovery_industry.json"))
  _config.buildings.merge(FrontierDiscoveryExhibits.buildings())
  _config.projects.merge(FrontierDiscoveryExhibits.projects())
  _config.buildings.merge(FrontierDiscoveryUtilities.config().buildings)
  _config.projects.merge(FrontierDiscoveryUtilities.config().projects)
 return _config
static func building(kind: String) -> bool:return config().buildings.has(kind)
static func proof(world: Dictionary,key: String) -> bool:
 if not building(key):return true
 var state: Dictionary=world.get(config().projects[key].get("source","discoveries"),{})
 if state.has("research_evidence"):return bool(state.research_evidence.get(key,false)) # Public UI view only.
 for row in state.get("records",{}).values():
  if evidence_matches(row,key):return true
 return false
static func evidence_matches(row: Dictionary,key: String) -> bool:
 return row.get("claimed",false) and row.get("template","") in config().projects[key].discoveries
static func collect_evidence(row: Dictionary,source: String,result: Dictionary) -> void:
 if not row.get("claimed",false):return
 if _evidence_projects.is_empty():
  for key in config().projects:
   var d: Dictionary=config().projects[key]
   for template in d.discoveries:
    var index: String=str(d.get("source","discoveries"))+":"+str(template)
    if not _evidence_projects.has(index):_evidence_projects[index]=[]
    _evidence_projects[index].append(key)
 for key in _evidence_projects.get(source+":"+str(row.get("template","")),[]):result[key]=true
static func hint(template: String,finished: bool) -> String:
 for key in config().projects:
  if not FrontierDiscoveryExhibits.is_exhibit(key) and template in config().projects[key].discoveries:
   return ("연구 가능  " if finished else "조사 완료 후 연구  ")+str(config().projects[key].name)+"\n"+str(config().projects[key].effect)+"\n착륙선 F → 연구 → 공동 설비"
 return ""
static func conditions(world: Dictionary,site: Dictionary,b: Dictionary) -> Dictionary:
 var kind: String=b.get("type","")
 if not building(kind) or FrontierDiscoveryExhibits.is_exhibit(kind):return {"ready":true,"reason":"장식 배치 가능" if FrontierDiscoveryExhibits.is_exhibit(kind) else ""}
 if FrontierDiscoveryUtilities.building(kind):return FrontierDiscoveryUtilities.conditions(site,b)
 if kind=="dew_condenser":
  var body:=FrontierUniverse.body_from_id(world.manifest,world.location)
  var profile:=FrontierEcology.profile(body)
  var cfg: Dictionary=config().condenser
  var pressure: float=float(profile.pressure)*(100.0 if not profile.has("pressure_unit") and not body.get("terrain_traits",{}).is_empty() else 1.0)
  var moisture:=float(profile.moisture);var temperature:=float(site.environment.temperature)
  if pressure<float(cfg.minimum_pressure):return {"ready":false,"reason":"대기 부족  %.0f / %.0f kPa"%[pressure,float(cfg.minimum_pressure)]}
  if moisture<float(cfg.minimum_moisture):return {"ready":false,"reason":"습도 부족  %.0f / %.0f%%"%[moisture*100,float(cfg.minimum_moisture)*100]}
  if temperature<float(cfg.minimum_temperature) or temperature>float(cfg.maximum_temperature):return {"ready":false,"reason":"집수 온도 범위  %.0f~%.0f°C 필요"%[float(cfg.minimum_temperature),float(cfg.maximum_temperature)]}
  return {"ready":true,"reason":"습도 %.0f%%  집수 가능"%(moisture*100)}
 var nearest:=INF
 for row in heat_sources(world):
  if not row.get("claimed",false):continue
  nearest=minf(nearest,FrontierCrewWorld.vector(row.position).distance_to(FrontierCrewWorld.vector(b.position)))
 var radius:=float(config().geothermal.source_radius)
 if nearest>radius:return {"ready":false,"reason":"조사 완료한 열수 굴뚝 %.0fm 이내 필요"%radius}
 return {"ready":true,"reason":"열수 굴뚝 %.0fm  발전 가능"%nearest}
static func heat_sources(world: Dictionary) -> Array:
 var records: Dictionary=world.get("discoveries",{}).get("records",{})
 # Records only append during play. References keep stage/claimed updates live;
 # replacement transaction dictionaries rebuild this bounded, non-persistent index.
 if not is_same(records,_indexed_records) or records.size()!=_indexed_count:
  _indexed_records=records;_indexed_count=records.size();_heat_sources={}
  for row in records.values():
   if row.get("template","")!="thermal_chimneys":continue
   var body_id:=str(row.get("body_id",""))
   if not _heat_sources.has(body_id):_heat_sources[body_id]=[]
   _heat_sources[body_id].append(row)
 return _heat_sources.get(str(world.get("location","")),[])
static func tick(site: Dictionary,dt: float) -> void:
 for b in site.buildings.values():
  if b.type=="geothermal_generator":
   b.working=b.active
   if b.active:b.status="열수 발전  %.0f kW"%(-float(config().buildings.geothermal_generator.power)*FrontierProductionTier2.factor(b))
  if b.type!="dew_condenser" or not b.active:continue
  var room:=FrontierItemInventory.warehouse_room(site,"ice")
  if room<=0:b.status="현장 창고 필요 또는 얼음 보관함 가득 참";b.working=false;continue
  var seconds:=float(config().condenser.seconds)
  b.work+=dt*FrontierProductionTier2.factor(b)
  var count:=mini(room,floori(float(b.work)/seconds))
  if count>0:site.inventory.ice=int(site.inventory.get("ice",0))+count;b.work-=count*seconds
  b.work=minf(float(b.work),seconds)
  b.working=true;b.status="응결수 냉각  얼음 1개 / %.0f초  %.0f초 남음"%[seconds/FrontierProductionTier2.factor(b),(seconds-float(b.work))/FrontierProductionTier2.factor(b)]
static func name(b: Dictionary) -> String:
 return ("강화 " if int(b.get("tier",1))==2 else "")+str(config().buildings[b.type].name)
