class_name FrontierTerraformTier3
extends RefCounted
## Host-owned regional pollution budget. Supplies are consumed from the local facade.
static var _config: Dictionary={}
static func config() -> Dictionary:
 if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/terraforming_tier3.json"))
 return _config
static func enabled(body: Dictionary) -> bool:return int(body.get("planet_tier",0))==3 and body.get("regional_rules",{}).has("tier3")
static func profile_id(body: Dictionary) -> String:
 return ["acid_water","reactive_gas"][FrontierUniverse.derive(int(body.streams.terrain),"terraform3-profile")%2]
static func initialize(site: Dictionary,body: Dictionary) -> void:
 if not enabled(body):return
 var rules: Dictionary=body.regional_rules.tier3.duplicate(true)
 site.tier3={"version":1,"profile":profile_id(body),"rules":rules,"suppression":0.0,"controlled_seconds":0.0,"supply_seconds":0.0,"source_status":"유입원 제어 장치 필요","created":0.0,"removed":0.0,"initial_mass":0.0,"trend":0.0}
 site.workload_eligible=true
 for region in site.regions.values():
  region.tier3_stable_seconds=float(rules.stable_seconds)
  region.tier3_goal="source" if region.role=="source" else ("recovery" if region.role=="recovery" else "clean")
  region.restoration2={"salinity":20.0,"soil":60.0 if region.role=="settlement" else 10.0}
  for cell in region.cells:
   cell.pollution=0.0 if region.role=="settlement" else float(rules.starting_pollution)
   cell.colonization=0.0;cell.restoration2=region.restoration2.duplicate()
   site.tier3.initial_mass+=float(cell.pollution)
 FrontierRegionalTerraform.home(site)
static func name(row: Dictionary) -> String:
 return config().upgrades.get(row.get("type",""),{}).get("name",FrontierCatalog.entry("buildings",row.get("type","")).get("name","시설")) if int(row.get("tier",1))==3 else FrontierCatalog.entry("buildings",row.get("type","")).get("name","시설")
static func radius(row: Dictionary) -> float:
 return float(config().upgrades[row.type].support_radius) if int(row.get("tier",1))==3 and config().upgrades.has(row.get("type","")) else float(FrontierCatalog.entry("buildings",row.get("type","")).get("radius",1))
static func power(row: Dictionary) -> float:
 return float(config().upgrades[row.type].power) if int(row.get("tier",1))==3 and config().upgrades.has(row.type) else float(FrontierCatalog.entry("buildings",row.type).power)
static func fuel(site: Dictionary,b: Dictionary,item: String,dt: float,seconds: float) -> float:
 if dt<=0:return 0.0
 var stored: float=b.get("t3_fuel",0)
 if stored<dt:
  var count:=mini(int(site.inventory.get(item,0)),ceili((dt-stored)/seconds))
  if count>0:site.inventory[item]-=count;stored+=count*seconds
 var used:=minf(stored,dt);b.t3_fuel=maxf(0,stored-used)
 return used
static func mass(site: Dictionary) -> float:
 var amount:=0.0
 for region in site.regions.values():
  for cell in region.cells:amount+=float(cell.get("pollution",0))
 return amount
static func begin(world: Dictionary,site: Dictionary,dt: float) -> void:
 if not site.has("tier3") or not FrontierPlanetSupply.operating(site):return
 var record: Dictionary=site.tier3;var rules: Dictionary=record.rules;var profile: Dictionary=rules.profiles[record.profile]
 var before:=mass(site);var source:=FrontierRegionalTerraform.facade(site,"region:1")
 world.business.sites[world.location]=source;FrontierExpeditionIndustry.power(world,source)
 record.suppression=0.0;record.supply_seconds=0.0;record.source_status="유입원 제어 장치 필요"
 var controller: Dictionary={}
 for b in source.buildings.values():
  if b.type=="source_control":b.t3_control_fraction=0.0
 # One control head per source avoids multiplying suppression with duplicate machines.
 for b in source.buildings.values():
  if b.type!="source_control":continue
  if Vector2(b.position[0]-source.center[0],b.position[2]-source.center[2]).length()>float(rules.source_radius):b.status="유입원 48m 이내 배치 필요";continue
  if not b.active:record.source_status=b.status;continue
  controller=b;break
 if not controller.is_empty():
  var used:=fuel(source,controller,profile.item,dt,float(rules.source_pack_seconds))
  var fraction:=used/dt if dt>0 else (1.0 if float(controller.get("t3_fuel",0))>0 or int(source.inventory.get(profile.item,0))>0 else 0.0)
  record.suppression=float(rules.suppression)*fraction
  record.supply_seconds=float(controller.get("t3_fuel",0))+int(source.inventory.get(profile.item,0))*float(rules.source_pack_seconds)
  controller.working=used>0;controller.status="유입 억제 중" if fraction>=.999 else FrontierProductionTier2.product(profile.item).name+" 보급 필요"
  record.source_status=controller.status
  controller.t3_control_fraction=fraction
 var coefficient: float=site.get("coop_workload",{}).get("coefficient",1)
 var created:=float(rules.source_rate)*(1-float(record.suppression))*dt
 # Stored pollutant is concentration in one base region volume. Cooperative volume
 # slows removal, while inflow concentration remains independent of crew size.
 for cell in source.cells:cell.pollution+=created/source.cells.size()
 record.created+=created
 record.controlled_seconds=minf(float(rules.stable_seconds),float(record.controlled_seconds)+dt) if float(record.suppression)>=float(rules.controlled_minimum) else 0.0
 FrontierRegionalTerraform.merge(site,source);world.business.sites[world.location]=site
 # Snapshot both edges before applying, so one frame cannot leap across two links.
 var transfers: Array=[]
 for edge in [["region:1","region:2"],["region:2","region:3"]]:
  var origin: Dictionary=site.regions[edge[0]];var destination: Dictionary=site.regions[edge[1]]
  for i in origin.cells.size():
   var quantity:=minf(float(origin.cells[i].pollution),minf(float(origin.cells[i].pollution)*float(rules.transfer_fraction_per_second)*dt,float(rules.transfer_limit_per_second)*dt/origin.cells.size()))
   transfers.append([origin.cells[i],destination.cells[i],quantity])
 for movement in transfers:movement[0].pollution-=movement[2];movement[1].pollution+=movement[2]
 record.trend=(mass(site)-before)/dt if dt>0 else 0.0
static func process(world: Dictionary,site: Dictionary,dt: float) -> void:
 if not site.has("tier3"):return
 var record: Dictionary=site.tier3;var rules: Dictionary=record.rules;var profile: Dictionary=rules.profiles[record.profile]
 var radius: float=FrontierUniverse.body_from_id(world.manifest,world.location).regional_rules.facility_radius
 var coefficient: float=site.get("coop_workload",{}).get("coefficient",1)
 for b in site.buildings.values():
  if not b.active or int(b.get("tier",1))<3:continue
  var covered: Array=[]
  for cell in site.cells:
   if Vector2(cell.position[0]-b.position[0],cell.position[2]-b.position[2]).length()<=radius:covered.append(cell)
  if covered.is_empty():continue
  var quantity:=0.0
  for cell in covered:quantity+=float(cell.pollution)
  var used:=0.0
  if b.type==profile.treatment and quantity>0:
   used=fuel(site,b,profile.item,dt,float(rules.treatment_pack_seconds))
  elif b.type=="source_control":
   used=dt*float(b.get("t3_control_fraction",0));b.status=record.source_status;b.working=used>0
  if b.type==profile.treatment or b.type=="source_control":
   var removed:=0.0;var budget:=used*float(rules.treatment_rate)/coefficient
   # Proportional removal preserves the budget and avoids shared-timer cell starvation.
   for cell in covered:
    var amount:=minf(float(cell.pollution),budget*float(cell.pollution)/quantity) if quantity>0 else 0.0
    cell.pollution-=amount;removed+=amount
   record.removed+=removed;b.working=b.get("working",false) or removed>0
   if b.type!="source_control" and quantity>0:b.status="선택 정화 중" if used>=dt else FrontierProductionTier2.product(profile.item).name+" 보급 필요"
  if b.type=="biolab" and site.regions[site.local_region].role=="recovery":
   var viable: Array=[]
   for cell in covered:
    var scores:=FrontierEvaluator.scores(cell.environment)
    if float(cell.pollution)<=float(rules.pollution_limit) and float(cell.restoration2.soil)>=60 and minf(scores.atmosphere,minf(scores.temperature,scores.water))>=60 and float(cell.colonization)<100:viable.append(cell)
   if viable.is_empty():b.status="정화·급수·온도·토양 조건 필요";continue
   used=fuel(site,b,"pioneer_culture",dt,float(rules.culture_pack_seconds))
   for cell in viable:cell.colonization=minf(100,float(cell.colonization)+used*float(rules.colonization_rate)/coefficient/viable.size())
   b.working=b.get("working",false) or used>0;b.status="선구종 정착 중" if used>=dt else "선구종 정착 팩 보급 필요"
static func stable(site: Dictionary,cell: Dictionary,basic: bool) -> bool:
 var rules: Dictionary=site.tier3.rules
 var role: String=site.regions[site.local_region].role
 var clean: bool=float(cell.pollution)<=float(rules.pollution_limit)
 if role=="source":return clean and float(site.tier3.suppression)>=float(rules.controlled_minimum)
 if role=="water":return clean and float(FrontierEvaluator.scores(cell.environment).water)>=60 and float(cell.restoration2.salinity)<=20
 if role=="air":return clean and float(FrontierEvaluator.scores(cell.environment).atmosphere)>=60
 if role=="recovery":return clean and basic and float(cell.colonization)>=float(rules.colonization_goal)
 return basic and clean
static func ready(site: Dictionary,region: Dictionary) -> bool:
 var amount:=0
 for cell in region.cells:
  if float(cell.environment.stable_seconds)>=float(site.tier3.rules.stable_seconds):amount+=1
 return amount>=int(site.tier3.rules.required_cells)
static func detail(site: Dictionary,region: Dictionary) -> String:
 var record: Dictionary=site.tier3;var value:=0.0;var planted:=0.0
 for cell in region.cells:value+=float(cell.pollution);planted+=float(cell.colonization)
 var profile: Dictionary=record.rules.profiles[record.profile]
 return "%s · 잔류 %.1f / 목표 ≤%.0f · 정착 %.0f%%\n유입 억제 %.0f%% · 보급 %.0f초 · %s"%[profile.name,value/region.cells.size(),float(record.rules.pollution_limit),planted/region.cells.size(),float(record.suppression)*100,float(record.supply_seconds),record.source_status]
static func valid(site: Dictionary,body: Dictionary) -> bool:
 if not enabled(body):return not site.has("tier3")
 var r: Variant=site.get("tier3")
 if not r is Dictionary or r.get("version")!=1 or r.get("profile")!=profile_id(body) or not r.get("rules") is Dictionary:return false
 if FrontierUniverse.fingerprint(r.rules)!=FrontierUniverse.fingerprint(body.regional_rules.tier3):return false
 for key in ["created","removed","initial_mass","supply_seconds","controlled_seconds","suppression"]:
  if not FrontierUniverse._finite(r.get(key),0,float(r.rules.maximum_mass)):return false
 if not FrontierUniverse._finite(r.get("trend"),-1000000,1000000) or not r.get("source_status") is String:return false
 if float(r.suppression)>1 or float(r.controlled_seconds)>float(r.rules.stable_seconds)+.001:return false
 for region in site.regions.values():
  for cell in region.cells:
   if not FrontierUniverse._finite(cell.get("pollution"),0,float(r.rules.maximum_mass)) or not FrontierUniverse._finite(cell.get("colonization"),0,100):return false
 var expected:=float(r.initial_mass)+float(r.created)-float(r.removed)
 return absf(mass(site)-expected)<maxf(.01,absf(expected)*.0001)
