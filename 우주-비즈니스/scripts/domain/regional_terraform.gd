class_name FrontierRegionalTerraform
extends RefCounted
## Regional facades reuse existing transactions and machines with isolated local stores.
const LOCAL_KEYS=["center","inventory","environment","restoration2","power_supply","power_demand","stored_equipment","delivered","production_paid","time","cells"]
static func enabled(site: Dictionary) -> bool:return site.has("regions")
static func initialize(site: Dictionary,body: Dictionary) -> void:
 var zones:=FrontierSurfaceRegions.zones(body)
 if zones.is_empty():return
 site.regions={};site.regional_version=1;site.regional_paid={};site.regional_observed={}
 for zone in zones:
  var region: Dictionary=zone.duplicate(true)
  for key in LOCAL_KEYS:
   if site.has(key):region[key]=site[key].duplicate(true) if site[key] is Dictionary or site[key] is Array else site[key]
  region.center=zone.center.duplicate();region.inventory=FrontierExpeditionBusiness.inventory();region.cells=[]
  if int(body.planet_tier)==2 and zone.role=="settlement":region.restoration2.salinity=20.0;region.restoration2.soil=60.0
  for offset in (body.regional_rules.cell_offsets if int(body.planet_tier)>1 else [[0,0]]):
   var center: Array=region.center
   region.cells.append({"position":[center[0]+offset[0],center[1],center[2]+offset[1]],"environment":region.environment.duplicate(true),"restoration2":region.get("restoration2",{}).duplicate(true)})
  site.regions[zone.id]=region
 home(site)
static func home(site: Dictionary) -> void:
 if not enabled(site):return
 for key in LOCAL_KEYS:
  if site.regions["region:0"].has(key):site[key]=site.regions["region:0"][key]
static func region_id(site: Dictionary,position: Vector3) -> String:
 var result: String="region:0";var nearest:=INF
 for id in site.get("regions",{}):
  var d:=Vector2(position.x-site.regions[id].center[0],position.z-site.regions[id].center[2]).length_squared()
  if d<nearest:nearest=d;result=id
 return result
static func facade(site: Dictionary,id: String) -> Dictionary:
 var local: Dictionary=site.duplicate(false);var region: Dictionary=site.regions[id]
 for key in LOCAL_KEYS:
  if region.has(key):local[key]=region[key]
  else:local.erase(key)
 local.local_region=id;local.base_deployed=false
 for key in ["buildings","robots","jobs"]:
  local[key]={}
  for entity_id in site[key]:
   var row: Dictionary=site[key][entity_id]
   var owner: String=str(row.get("region_id","region:0"))
   if owner==id:local[key][entity_id]=row
 return local
static func merge(site: Dictionary,local: Dictionary) -> void:
 var id: String=local.local_region;var region: Dictionary=site.regions[id]
 for key in LOCAL_KEYS:
  if local.has(key):region[key]=local[key]
  else:region.erase(key)
 for key in ["buildings","robots","jobs"]:
  for entity_id in site[key].keys():
   if str(site[key][entity_id].get("region_id","region:0"))==id and not local[key].has(entity_id):site[key].erase(entity_id)
  for entity_id in local[key]:local[key][entity_id].region_id=id;site[key][entity_id]=local[key][entity_id]
 for key in ["state","production_lease","coop_workload","workload_eligible"]:
  if local.has(key):site[key]=local[key]
  else:site.erase(key)
 home(site)
static func apply(world: Dictionary,actor: String,kind: String,args: Dictionary,active: Dictionary) -> String:
 var site: Dictionary=FrontierExpeditionBusiness.site(world)
 if not enabled(site) or kind in ["business_settle","business_register","business_lease","business_lease_release"]:
  return FrontierExpeditionBusiness.apply_local(world,actor,kind,args,active)
 var id:=region_id(site,FrontierCrewWorld.vector(world.crew.members[actor].position))
 var local:=facade(site,id);world.business.sites[world.location]=local
 var error:=FrontierExpeditionBusiness.apply_local(world,actor,kind,args,active)
 merge(site,local);world.business.sites[world.location]=site
 return error
static func tick(world: Dictionary,dt: float) -> void:
 var site:=FrontierExpeditionBusiness.site(world)
 for actor in world.crew.members:
  if FrontierShuttles.location(world,actor)==world.location and world.crew.members[actor].area=="surface":observe(site,FrontierCrewWorld.vector(world.crew.members[actor].position))
 for id in site.regions:
  var local:=facade(site,id);world.business.sites[world.location]=local
  FrontierExpeditionIndustry.tick_local(world,dt)
  merge(site,local)
 world.business.sites[world.location]=site
 var tier: int=FrontierUniverse.body_from_id(world.manifest,world.location).planet_tier
 if site.state=="active":
  for id in site.regions:
   if id=="region:0" or site.regional_paid.has(id) or not ready(site.regions[id]):continue
   var total:=FrontierCoopWorkload.reward(site,tier)
   var amount:=floori(total*float(FrontierSurfaceRegions.config().stage_fraction))
   site.regional_paid[id]=amount;world.business.credits+=amount
static func environment(world: Dictionary,site: Dictionary,dt: float) -> void:
 var body:=FrontierUniverse.body_from_id(world.manifest,world.location)
 var radius: float=body.regional_rules.facility_radius
 for b in site.buildings.values():
  if not b.active or b.type not in ["atmosphere","thermal","water","biolab"]:continue
  var cells: Array=[]
  for cell in site.cells:
   var p:=FrontierCrewWorld.vector(cell.position)
   if Vector2(p.x-b.position[0],p.z-b.position[2]).length()<=radius:cells.append(cell)
  b.working=false
  if cells.is_empty():b.status="복원 구획이 영향 범위 밖입니다";continue
  for cell in cells:
   var target: Dictionary=site.duplicate(false);target.environment=cell.environment;target.restoration2=cell.restoration2
   var before: Dictionary=cell.environment.duplicate();var previous: Dictionary=cell.restoration2.duplicate();var work: float=b.work;var treatment: float=b.get("treatment_work",0)
   FrontierExpeditionIndustry._process_facility(world,target,b,dt*FrontierProgressionResearch.multiplier(FrontierProgressionResearch.shared(world))/cells.size())
   FrontierCoopWorkload.distribute(target,before,previous)
   b.working=b.working or before!=cell.environment or previous!=cell.restoration2 or work!=float(b.work) or treatment!=float(b.get("treatment_work",0))
  if b.working:b.status="지역 처리 중" if "필요" not in str(b.status) else "부분 가동 · "+b.status
 for cell in site.cells:
  var scores:=FrontierEvaluator.scores(cell.environment)
  var role: String=site.regions[site.local_region].role
  var ok: bool=FrontierProductionTier2.restoration_ready(cell) and minf(scores.atmosphere,minf(scores.temperature,scores.water))>=60 and float(cell.environment.ecology)>=20
  if role=="water":ok=float(scores.water)>=60 and float(cell.restoration2.get("salinity",0))<=20
  elif role=="soil":ok=float(cell.restoration2.get("soil",0))>=60
  cell.environment.stable_seconds=minf(120,float(cell.environment.stable_seconds)+dt) if ok else 0.0
 # Preserve averages only as display values; contract readiness inspects cells.
 for key in site.environment:
  var amount:=0.0
  for cell in site.cells:amount+=float(cell.environment.get(key,0))
  site.environment[key]=amount/site.cells.size()
 for key in ["salinity","soil"]:
  if not site.get("restoration2",{}).has(key):continue
  var amount:=0.0
  for cell in site.cells:amount+=float(cell.restoration2.get(key,0))
  site.restoration2[key]=amount/site.cells.size()
static func ready(region: Dictionary) -> bool:
 var count:=0
 for cell in region.get("cells",[]):
  if float(cell.environment.stable_seconds)>=float(FrontierExpeditionBusiness.config().contract_stable_seconds):count+=1
 return count>=mini(region.get("cells",[]).size(),int(FrontierSurfaceRegions.config().required_cells))
static func settlement_reason(site: Dictionary) -> String:
 for region in site.get("regions",{}).values():
  if not ready(region):return region.name+"의 복원 구획 %d곳을 안정시켜야 합니다. Tab 지도를 확인하세요."%mini(region.cells.size(),int(FrontierSurfaceRegions.config().required_cells))
 return ""
static func paid(site: Dictionary) -> int:
 var amount:=0
 for value in site.get("regional_paid",{}).values():amount+=int(value)
 return amount
static func observe(site: Dictionary,position: Vector3) -> void:
 if not enabled(site):return
 var id:=region_id(site,position)
 if position.distance_to(FrontierCrewWorld.vector(site.regions[id].center))<100:site.regional_observed[id]=true
static func local_public(site: Dictionary,position: Vector3) -> Dictionary:
 if not enabled(site):return site
 var result:=facade(site,region_id(site,position))
 result.slot_capacity=FrontierItemInventory.warehouse_capacity(result)
 result.buildings=site.buildings;result.robots=site.robots;result.jobs=site.jobs
 result.current_region=result.local_region;result.erase("local_region")
 return result
static func valid(site: Dictionary,body: Dictionary) -> bool:
 if not enabled(site):return not body.has("regional_rules") or FrontierSurfaceRegions.zones(body).is_empty()
 if not site.regions is Dictionary or not site.get("regional_paid") is Dictionary or not site.get("regional_observed") is Dictionary:return false
 var expected:=FrontierSurfaceRegions.zones(body)
 if site.regions.size()!=expected.size():return false
 for zone in expected:
  var r: Variant=site.regions.get(zone.id)
  if not r is Dictionary or not FrontierUniverse._vector3_array(r.get("center")) or FrontierCrewWorld.vector(r.center).distance_to(FrontierCrewWorld.vector(zone.center))>.001 or not FrontierExpeditionBusiness.valid_inventory(r.get("inventory")):return false
  if not r.get("cells") is Array or r.cells.size()!=(body.regional_rules.cell_offsets.size() if int(body.planet_tier)>1 else 1):return false
  for i in r.cells.size():
   var cell: Variant=r.cells[i]
   if not cell is Dictionary or not FrontierUniverse._vector3_array(cell.get("position")):return false
   var offset: Array=body.regional_rules.cell_offsets[i]
   if FrontierCrewWorld.vector(cell.position).distance_to(Vector3(r.center[0]+offset[0],r.center[1],r.center[2]+offset[1]))>.001:return false
   var e: Variant=cell.get("environment")
   if not e is Dictionary:return false
   for key in ["temperature","pressure","oxygen","toxicity","water","ecology","stable_seconds"]:
    var limits: Array={"temperature":[-273,1000],"pressure":[0,10],"oxygen":[0,1],"toxicity":[0,100],"water":[0,100],"ecology":[0,100],"stable_seconds":[0,120]}[key]
    if not FrontierUniverse._finite(e.get(key),limits[0],limits[1]):return false
   if not cell.get("restoration2") is Dictionary:return false
   for key in ["salinity","soil"]:
    if cell.restoration2.has(key) and not FrontierUniverse._finite(cell.restoration2[key],0,100):return false
 for id in site.regional_paid:
  if id=="region:0" or not site.regions.has(id) or int(site.regional_paid[id])!=floori(FrontierCoopWorkload.reward(site,int(body.planet_tier))*float(body.regional_rules.stage_fraction)):return false
 for key in ["buildings","robots","jobs"]:
  for row in site[key].values():
   if not site.regions.has(str(row.get("region_id",""))):return false
 return true
