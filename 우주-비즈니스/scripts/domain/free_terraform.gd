class_name FrontierFreeTerraform
extends RefCounted
const Tier4=preload("res://scripts/domain/terraform_tier4.gd")
## Sparse fixed surface cells, independent supply districts, equal-area atmospheric globe.
static func enabled(body: Dictionary) -> bool:
 var tier:=int(body.get("planet_tier",0));var cfg: Dictionary=body.get("regional_rules",{})
 return cfg.has("free_placement") and (tier in [1,2,3] or (tier==4 and cfg.has("tier4") and cfg.free_placement.targets.has("4")))
static func active(site: Dictionary) -> bool:return site.has("free_terraform")
static func rules(site: Dictionary) -> Dictionary:return site.free_terraform.rules
static func initialize(site: Dictionary,body: Dictionary) -> void:
 var cfg: Dictionary=body.regional_rules.free_placement.duplicate(true)
 var base: Dictionary=site.environment.duplicate(true)
 var restoration: Dictionary=site.get("restoration2",{"salinity":0.0,"soil":60.0}).duplicate(true)
 if FrontierTerraformTier3.enabled(body):restoration={"salinity":35.0,"soil":10.0}
 var air: Array=[]
 for i in int(cfg.air_columns)*int(cfg.air_rows):air.append([float(base.oxygen),float(base.pressure),float(base.toxicity)])
 site.free_terraform={"version":1,"rules":cfg,"tier":int(body.planet_tier),"base":base,"restoration":restoration,"cells":{},"air":air,"revision":0,"area":0.0,"created":0.0,"removed":0.0,"initial_mass":0.0,"source":[],"soil_winners":{}}
 site.regions={};site.regional_paid={};site.regional_observed={};site.regional_version=2
 site.regions["region:0"]=district(site,"region:0");FrontierRegionalTerraform.home(site)
 site.workload_eligible=true
 if FrontierTerraformTier3.enabled(body):
  var center: Array=FrontierSurfaceRegions.zones(body)[1].center
  site.free_terraform.source=center.duplicate()
  var t: Dictionary=FrontierTerraformTier3.rules_for(body).duplicate(true)
  site.tier3={"version":1,"profile":FrontierTerraformTier3.profile_id(body),"rules":t,"suppression":0.0,"controlled_seconds":0.0,"supply_seconds":0.0,"source_status":"오염 구역 내부에 제어 장치 배치","created":0.0,"removed":0.0,"initial_mass":0.0,"trend":0.0}
  ensure_cells(site,body,Vector2(center[0],center[2]),float(cfg.pollution_radius))
static func district_id(site: Dictionary,p: Vector3) -> String:
 var span: float=rules(site).supply_span
 var x:=floori((p.x+span*.5)/span);var z:=floori((p.z+span*.5)/span)
 return "region:0" if x==0 and z==0 else "supply:%d:%d"%[x,z]
static func district(site: Dictionary,id: String) -> Dictionary:
 var center: Array=site.center.duplicate();var span: float=rules(site).supply_span
 if id!="region:0":
  var parts:=id.split(":");center=[float(parts[1])*span,0.0,float(parts[2])*span]
 return {"id":id,"name":"현장 공급 %s"%id.trim_prefix("supply:"),"center":center,"radius":span*.5,"role":"free","inventory":FrontierExpeditionBusiness.inventory(),"environment":site.free_terraform.base.duplicate(true),"restoration2":site.free_terraform.restoration.duplicate(true),"cells":[],"time":0.0,"delivered":0,"production_paid":false,"power_supply":0.0,"power_demand":0.0}
static func key_at(site: Dictionary,p: Vector2) -> String:
 var size: float=rules(site).cell_size
 return "%d:%d"%[floori(p.x/size),floori(p.y/size)]
static func radius(site: Dictionary,b: Dictionary) -> float:
 if int(site.free_terraform.tier)==1 and b.get("type","") in ["water","thermal","biolab"]:return float(rules(site).intro_radius)
 return float(rules(site).radius.get(b.get("type",""),0))
static func in_pollution(site: Dictionary,p: Vector2) -> bool:
 if not site.has("tier3"):return false
 var center: Array=site.free_terraform.source
 return p.distance_to(Vector2(center[0],center[2]))<=float(rules(site).pollution_radius)
static func ensure_cells(site: Dictionary,body: Dictionary,p: Vector2,r: float) -> void:
 var cfg:=rules(site);var size: float=cfg.cell_size;var cells: Dictionary=site.free_terraform.cells
 var terrain:=FrontierSurfaceRegions.field(body)
 for x in range(floori((p.x-r)/size),ceili((p.x+r)/size)):
  for z in range(floori((p.y-r)/size),ceili((p.y+r)/size)):
   var at:=Vector2((x+.5)*size,(z+.5)*size);var key: String="%d:%d"%[x,z]
   if at.distance_to(p)>r or maxf(absf(at.x),absf(at.y))>float(cfg.extent) or cells.has(key) or cells.size()>=int(cfg.max_cells):continue
   var pollution:=float(cfg.pollution_initial) if in_pollution(site,at) else 0.0
   var e: Dictionary=site.free_terraform.base.duplicate(true);var restore: Dictionary=site.free_terraform.restoration.duplicate(true)
   cells[key]={"position":[at.x,terrain.height(at.x,at.y),at.y],"environment":e,"restoration2":restore,"pollution":pollution,"colonization":0.0,"treated":false}
   site.free_terraform.initial_mass+=pollution
static func air_index(site: Dictionary,p: Vector2) -> int:
 var cfg:=rules(site);var lon:=p.x/float(cfg.extent)*PI
 var sine:=clampf(p.y/float(cfg.extent),-.999999,.999999)
 return clampi(floori((sine+1)*.5*int(cfg.air_rows)),0,int(cfg.air_rows)-1)*int(cfg.air_columns)+posmod(floori((lon+PI)/TAU*int(cfg.air_columns)),int(cfg.air_columns))
static func globe_vector(site: Dictionary,p: Vector2) -> Vector3:
 var cfg:=rules(site);var lon:=p.x/float(cfg.extent)*PI;var sy:=clampf(p.y/float(cfg.extent),-1,1);var ring:=sqrt(maxf(0,1-sy*sy))
 return Vector3(sin(lon)*ring,sy,cos(lon)*ring)
static func air_to_cell(site: Dictionary,cell: Dictionary) -> void:
 var a: Array=site.free_terraform.air[air_index(site,Vector2(cell.position[0],cell.position[2]))]
 cell.environment.oxygen=a[0];cell.environment.pressure=a[1];cell.environment.toxicity=a[2]
static func water_gain(site: Dictionary,body: Dictionary,p: Vector2) -> float:
 var f:=FrontierSurfaceRegions.field(body);var local:=f.height(p.x,p.y);var reference:=0.0
 for offset in [Vector2(96,0),Vector2(-96,0),Vector2(0,96),Vector2(0,-96)]:reference+=f.height(p.x+offset.x,p.y+offset.y)*.25
 return 1+clampf((reference-local)/float(rules(site).water_height_span),0,1)*float(rules(site).water_lowland_gain)
static func begin(world: Dictionary,site: Dictionary,dt: float) -> void:
 var body:=FrontierUniverse.body_from_id(world.manifest,world.location)
 site.free_terraform.soil_winners={}
 # Refresh every district before selecting winners; unpowered/flooded machines cannot win.
 for id in site.regions:
  var local:=FrontierRegionalTerraform.facade(site,id);world.business.sites[world.location]=local;FrontierExpeditionIndustry.power(world,local);FrontierRegionalTerraform.merge(site,local)
 world.business.sites[world.location]=site
 for b in site.buildings.values():
  if b.type not in rules(site).radius:continue
  ensure_cells(site,body,Vector2(b.position[0],b.position[2]),radius(site,b))
  if b.type!="biolab" or not b.active:continue
  for key in site.free_terraform.cells:
   var c: Dictionary=site.free_terraform.cells[key];var distance:=Vector2(c.position[0]-b.position[0],c.position[2]-b.position[2]).length()
   if distance>radius(site,b):continue
   var strength:=FrontierProductionTier2.factor(b)*(1-smoothstep(radius(site,b)*.4,radius(site,b),distance))
   var previous: Dictionary=site.free_terraform.soil_winners.get(key,{})
   if strength>float(previous.get("strength",-1)) or (is_equal_approx(strength,float(previous.get("strength",-1))) and str(b.id)<str(previous.get("id",""))):site.free_terraform.soil_winners[key]={"id":b.id,"strength":strength}
 if site.has("tier3"):
  site.tier3.suppression=0.0;site.tier3.supply_seconds=0.0;site.tier3.source_status="오염 구역 내부 제어 장치 필요"
static func covered(site: Dictionary,b: Dictionary) -> Array:
 var result: Array=[];var r:=radius(site,b)
 for key in site.free_terraform.cells:
  var cell: Dictionary=site.free_terraform.cells[key];var distance:=Vector2(cell.position[0]-b.position[0],cell.position[2]-b.position[2]).length()
  if distance>=r:continue
  if b.type=="biolab" and site.free_terraform.soil_winners.get(key,{}).get("id","")!=b.id:continue
  result.append([cell,1-smoothstep(r*.4,r,distance)])
 return result
static func process(world: Dictionary,site: Dictionary,dt: float) -> void:
 var body:=FrontierUniverse.body_from_id(world.manifest,world.location)
 var speed:=FrontierProgressionResearch.multiplier(FrontierProgressionResearch.shared(world))
 for b in site.buildings.values():
  if b.type not in rules(site).radius or not b.active:continue
  var at:=Vector2(b.position[0],b.position[2]);var cells:=covered(site,b)
  if b.type=="atmosphere":
   var index:=air_index(site,at);var a: Array=site.free_terraform.air[index]
   var target: Dictionary=site.duplicate(false);target.environment=site.free_terraform.base.duplicate();target.environment.oxygen=a[0];target.environment.pressure=a[1];target.environment.toxicity=a[2]
   var before: Dictionary=target.environment.duplicate();var old:=float(b.get("treatment_work",0))
   FrontierExpeditionIndustry._process_facility(world,target,b,dt*speed/float(rules(site).air_volume));FrontierCoopWorkload.distribute(target,before,{})
   a[0]=target.environment.oxygen;a[1]=target.environment.pressure;a[2]=target.environment.toxicity
   b.working=before!=target.environment or old!=float(b.get("treatment_work",0))
  elif b.type!="source_control":
   if Tier4.protected_machine(site,b):
    var used:=Tier4.thermal_seconds(site,b,dt*speed)
    local_machine(world,site,body,b,cells,used)
    specialized(site,b,cells,used,true)
    continue
   local_machine(world,site,body,b,cells,dt*speed)
  if site.has("tier3"):specialized(site,b,cells,dt*speed)
static func specialized(site: Dictionary,b: Dictionary,cells: Array,dt: float,paid: bool=false) -> void:
 if int(b.get("tier",1))<3:return
 var record: Dictionary=site.tier3;var r: Dictionary=record.rules;var profile: Dictionary=r.profiles[record.profile]
 var coefficient: float=site.get("coop_workload",{}).get("coefficient",1)
 var inside:=in_pollution(site,Vector2(b.position[0],b.position[2]))
 if b.type in [profile.treatment,"source_control"]:
  if not inside:b.status="오염 전문 처리: 구역 내부 설치 필요";return
  var quantity:=0.0
  for pair in cells:quantity+=float(pair[0].pollution)
  if quantity<=0 and b.type!="source_control":return
  var seconds: float=r.source_pack_seconds if b.type=="source_control" else r.treatment_pack_seconds
  var used:=dt if paid else FrontierTerraformTier3.fuel(site,b,profile.item,dt,seconds)
  var budget:=used*float(r.treatment_rate)*float(rules(site).specialized_rate_factor)/coefficient
  for pair in cells:
   var c: Dictionary=pair[0];var amount:=minf(float(c.pollution),budget*float(c.pollution)/quantity) if quantity>0 else 0.0
   c.pollution-=amount;site.free_terraform.removed+=amount;c.treated=c.treated or amount>0
  b.working=b.get("working",false) or used>0;b.status="오염 처리 중" if used>0 else "전문 처리 팩 보급 필요"
  if b.type=="source_control":
   var suppression:=float(r.suppression)*used/dt if dt>0 else 0.0
   if suppression>float(record.suppression):record.suppression=suppression;record.source_status=b.status
   record.supply_seconds+=float(b.get("t3_fuel",0))+int(site.inventory.get(profile.item,0))*seconds
 if b.type=="biolab":
  var viable: Array=[]
  for pair in cells:
   var c: Dictionary=pair[0];var scores:=FrontierEvaluator.scores(c.environment)
   if float(c.pollution)<=float(r.pollution_limit) and float(c.restoration2.soil)>=60 and minf(scores.atmosphere,minf(scores.temperature,scores.water))>=60 and float(c.colonization)<100:viable.append(c)
  if viable.is_empty():return
  var used:=FrontierTerraformTier3.fuel(site,b,"pioneer_culture",dt,float(r.culture_pack_seconds))
  for c in viable:c.colonization=minf(100,float(c.colonization)+used*float(r.colonization_rate)*float(rules(site).surface_capacity)/coefficient/viable.size());c.treated=c.treated or used>0
  b.working=b.get("working",false) or used>0
static func finish(site: Dictionary,dt: float) -> void:
 var cfg:=rules(site);var air: Array=site.free_terraform.air;var snapshot: Array=air.duplicate(true)
 var cols:=int(cfg.air_columns);var rows:=int(cfg.air_rows);var blend:=minf(.20,float(cfg.air_mix)*dt)
 # Equal-area latitude bands, periodic longitude. Pair exchanges conserve each quantity.
 for z in rows:
  for x in cols:
   var i:=z*cols+x
   var neighbors: Array=[z*cols+(x+1)%cols]
   if z+1<rows:neighbors.append((z+1)*cols+x)
   for j in neighbors:
    for channel in 3:
     var delta: float=(float(snapshot[j][channel])-float(snapshot[i][channel]))*blend
     air[i][channel]+=delta;air[j][channel]-=delta
 if site.has("tier3"):
  var source_cells: Array=[]
  for c in site.free_terraform.cells.values():
   if in_pollution(site,Vector2(c.position[0],c.position[2])):source_cells.append(c)
  var quantity: float=(float(site.tier3.rules.source_rate) if Tier4.active(site) else float(cfg.pollution_rate))*(1-float(site.tier3.suppression))*dt
  for c in source_cells:c.pollution+=quantity/maxi(1,source_cells.size())
  site.free_terraform.created+=quantity
  site.tier3.controlled_seconds=minf(120,float(site.tier3.controlled_seconds)+dt) if float(site.tier3.suppression)>=.9 else 0.0
 Tier4.drift(site,dt)
 var area:=0.0;var duration: float=cfg.targets[str(int(site.free_terraform.tier))].stable
 for c in site.free_terraform.cells.values():
  air_to_cell(site,c)
  var scores:=FrontierEvaluator.scores(c.environment)
  var ok: bool=c.treated and minf(scores.atmosphere,minf(scores.temperature,scores.water))>=60 and float(c.environment.ecology)>=20 and FrontierProductionTier2.restoration_ready(c)
  if site.has("tier3"):ok=ok and float(c.pollution)<=float(cfg.pollution_target) and float(c.colonization)>=60
  c.environment.stable_seconds=minf(120,float(c.environment.stable_seconds)+dt) if ok else 0.0
  if float(c.environment.stable_seconds)>=duration:area+=float(cfg.cell_size)*float(cfg.cell_size)
 site.free_terraform.area=area;site.free_terraform.revision+=1;site.free_terraform.soil_winners={}
 # Regional summaries are presentation only; completion uses the area ledger.
 for region in site.regions.values():
  var sample:=sample(site,Vector2(region.center[0],region.center[2]));region.environment=sample.environment.duplicate();region.restoration2=sample.restoration2.duplicate()
 FrontierRegionalTerraform.home(site)
static func sample(site: Dictionary,p: Vector2) -> Dictionary:
 var cell: Dictionary=site.free_terraform.cells.get(key_at(site,p),{})
 if cell.is_empty():cell={"environment":site.free_terraform.base.duplicate(),"restoration2":site.free_terraform.restoration.duplicate(),"pollution":0.0,"colonization":0.0}
 else:cell=cell.duplicate(true)
 air_to_cell(site,{"position":[p.x,0,p.y],"environment":cell.environment})
 return cell
static func goal(site: Dictionary) -> float:return float(rules(site).targets[str(int(site.free_terraform.tier))].area)
static func progress(site: Dictionary) -> float:return clampf(float(site.free_terraform.area)/goal(site),0,1)
static func pollution_average(site: Dictionary) -> float:
 var value:=0.0;var count:=0
 for c in site.free_terraform.cells.values():
  if in_pollution(site,Vector2(c.position[0],c.position[2])):value+=float(c.pollution);count+=1
 return value/maxi(1,count)
static func settlement_reason(site: Dictionary) -> String:
 if float(site.free_terraform.area)<goal(site):return "생활권 복원 면적 %.0f / %.0f m² · 테라포밍 탭을 확인하세요."%[float(site.free_terraform.area),goal(site)]
 if site.has("tier3") and (pollution_average(site)>float(rules(site).pollution_target) or float(site.tier3.controlled_seconds)<float(rules(site).targets[str(int(site.free_terraform.tier))].stable)):return "오염 구역 내부에서 잔류 오염을 처리하고 유입 억제를 유지하세요."
 return ""
static func detail(site: Dictionary) -> String:
 var result: String="생활권 %.0f / %.0f m² · %.0f초 유지"%[float(site.free_terraform.area),goal(site),float(rules(site).targets[str(int(site.free_terraform.tier))].stable)]
 if site.has("tier3"):result+="\n오염 구역 잔류 %.1f / %.0f · 유입 억제 %.0f%%"%[pollution_average(site),float(rules(site).pollution_target),float(site.tier3.suppression)*100]
 return result
static func valid(site: Dictionary,body: Dictionary) -> bool:
 if not enabled(body):return not active(site)
 var f: Variant=site.get("free_terraform")
 if not f is Dictionary or f.get("version")!=1 or f.get("tier")!=int(body.planet_tier) or not f.get("rules") is Dictionary:return false
 if FrontierUniverse.fingerprint(f.rules)!=FrontierUniverse.fingerprint(body.regional_rules.free_placement):return false
 if not f.get("cells") is Dictionary or f.cells.size()>int(f.rules.max_cells) or not f.get("air") is Array or f.air.size()!=int(f.rules.air_columns)*int(f.rules.air_rows):return false
 for a in f.air:
  if not a is Array or a.size()!=3 or not FrontierUniverse._finite(a[0],0,1) or not FrontierUniverse._finite(a[1],0,10) or not FrontierUniverse._finite(a[2],0,100):return false
 var mass:=0.0;var area:=0.0
 for key in f.cells:
  var c: Variant=f.cells[key]
  if not c is Dictionary or not FrontierUniverse._vector3_array(c.get("position")) or key!=key_at(site,Vector2(c.position[0],c.position[2])) or not c.get("treated") is bool:return false
  if not valid_environment(c.get("environment")) or not c.get("restoration2") is Dictionary:return false
  for name in ["soil","salinity"]:
   if not FrontierUniverse._finite(c.restoration2.get(name),0,100):return false
  if not FrontierUniverse._finite(c.get("pollution"),0,1e8) or not FrontierUniverse._finite(c.get("colonization"),0,100):return false
  mass+=float(c.pollution)
  if float(c.environment.stable_seconds)>=float(f.rules.targets[str(int(f.tier))].stable):area+=float(f.rules.cell_size)*float(f.rules.cell_size)
 for key in ["initial_mass","created","removed","area"]:
  if not FrontierUniverse._finite(f.get(key),0,1e12):return false
 if absf(mass-(float(f.initial_mass)+float(f.created)-float(f.removed)))>maxf(.01,mass*.0001) or not is_equal_approx(area,float(f.area)):return false
 if not site.get("regions") is Dictionary or not site.regions.has("region:0"):return false
 for id in site.regions:
  var r: Variant=site.regions[id]
  if not r is Dictionary or r.get("id")!=id or not FrontierUniverse._vector3_array(r.get("center")) or district_id(site,FrontierCrewWorld.vector(r.center))!=id:return false
  if not FrontierExpeditionBusiness.valid_inventory(r.get("inventory")) or not valid_environment(r.get("environment")):return false
  if not r.get("restoration2") is Dictionary or not r.get("cells") is Array or not r.cells.is_empty():return false
  for key in ["soil","salinity"]:
   if not FrontierUniverse._finite(r.restoration2.get(key),0,100):return false
 for group in ["buildings","robots","jobs"]:
  for row in site[group].values():
   if not site.regions.has(row.get("region_id","")):return false
 if not site.get("regional_paid") is Dictionary:return false
 for id in site.regional_paid:
  if id not in ["area:0","area:1"] or int(site.regional_paid[id])!=floori(FrontierCoopWorkload.reward(site,int(body.planet_tier))*float(f.rules.stage_fraction)):return false
 if FrontierTerraformTier3.enabled(body):
  var r: Variant=site.get("tier3")
  if not r is Dictionary or r.get("profile")!=FrontierTerraformTier3.profile_id(body) or not r.get("rules") is Dictionary:return false
  if FrontierUniverse.fingerprint(r.rules)!=FrontierUniverse.fingerprint(FrontierTerraformTier3.rules_for(body)) or not FrontierUniverse._vector3_array(f.get("source")):return false
  if FrontierCrewWorld.vector(f.source).distance_to(FrontierCrewWorld.vector(FrontierSurfaceRegions.zones(body)[1].center))>.001:return false
  if not FrontierUniverse._finite(r.get("suppression"),0,1) or not FrontierUniverse._finite(r.get("controlled_seconds"),0,120) or not FrontierUniverse._finite(r.get("supply_seconds"),0,1e12) or not r.get("source_status") is String:return false
 elif site.has("tier3"):return false
 return true
static func valid_environment(e: Variant) -> bool:
 if not e is Dictionary:return false
 var limits: Dictionary={"oxygen":[0,1],"pressure":[0,10],"temperature":[-273,1000],"water":[0,100],"toxicity":[0,100],"ecology":[0,100],"stable_seconds":[0,120]}
 for key in limits:
  if not FrontierUniverse._finite(e.get(key),limits[key][0],limits[key][1]):return false
 return true
static func visual_regions(site: Dictionary) -> Array:
 var result: Array=[]
 for cell in site.free_terraform.cells.values():
  var e: Dictionary=cell.environment.duplicate();e.merge(cell.restoration2,true);e.toxicity=maxf(float(e.toxicity),float(cell.pollution))
  result.append({"center":FrontierCrewWorld.vector(cell.position),"radius":float(rules(site).cell_size)*.72,"state":FrontierSurfaceRecovery.conditions(e),"environment":cell.environment,"restoration2":cell.restoration2,"pollution":float(cell.pollution)})
 return result
static func shader(material: ShaderMaterial,body: Dictionary,site: Dictionary) -> void:
 preload("res://scripts/world/terraform_texture_atlas.gd").apply(material,str(body.id),site.free_terraform)
static func spread(cells: Array,table: String,key: String,budget: float,target: float) -> float:
 var pending: Array=cells.duplicate();var used:=0.0
 # Redistribution after clamping uses only remaining demand; total output stays bounded.
 while budget>.000001 and not pending.is_empty():
  var weight:=0.0
  for pair in pending:weight+=float(pair[1])
  if weight<=0:break
  var spent:=0.0;var next: Array=[]
  for pair in pending:
   var cell: Dictionary=pair[0];var current: float=cell[table][key];var demand:=absf(target-current)
   var amount:=minf(demand,budget*float(pair[1])/weight)
   cell[table][key]=move_toward(current,target,amount);cell.treated=cell.treated or amount>0
   spent+=amount
   if demand>amount+.000001:next.append(pair)
  used+=spent;budget-=spent;pending=next
  if spent<.000001:break
 return used
static func input_cycles(site: Dictionary,b: Dictionary,item: String,dt: float,cycle: float,timer: String) -> int:
 if int(site.inventory.get(item,0))<=0:b.status=FrontierCatalog.entry("resources",item).get("name",item)+" 보급 필요";return 0
 var elapsed:=float(b.get(timer,0))+dt
 var count:=mini(int(site.inventory[item]),floori(elapsed/cycle))
 site.inventory[item]-=count;b[timer]=maxf(0,elapsed-count*cycle)
 if int(site.inventory[item])==0:b[timer]=minf(float(b[timer]),cycle)
 b.working=true
 return count
static func local_machine(world: Dictionary,site: Dictionary,body: Dictionary,b: Dictionary,cells: Array,dt: float) -> void:
 if cells.is_empty():b.status="새 처리 면적 없음";return
 var cfg:=FrontierExpeditionBusiness.config();var factor:=FrontierProductionTier2.factor(b)*FrontierFieldEngineering.factor(world,b)
 var coefficient: float=site.get("coop_workload",{}).get("coefficient",1)/float(rules(site).surface_capacity)
 var needed: Array=[]
 if b.type=="thermal":
  b.working=spread(cells,"environment","temperature",float(cfg.thermal_rate)*dt*factor/coefficient,18)>0
  return
 for pair in cells:
  var c: Dictionary=pair[0];air_to_cell(site,c)
  if b.type=="water" and float(c.environment.water)<100:needed.append(pair)
  elif b.type=="biolab":
   var scores:=FrontierEvaluator.scores(c.environment)
   if minf(scores.atmosphere,minf(scores.temperature,scores.water))>=60 and FrontierProductionTier2.restoration_ready(c) and float(c.environment.ecology)<100:needed.append(pair)
 if not needed.is_empty():
  if b.type=="water":
   var gain:=water_gain(site,body,Vector2(b.position[0],b.position[2]))
   var count:=input_cycles(site,b,"ice",dt,float(cfg.water_cycle_seconds)/factor,"work")
   spread(needed,"environment","water",count*float(cfg.water_per_ice)*gain*(1.5 if int(b.get("tier",1))==3 else 1.0)/coefficient,100)
   b.status+=" · 저지대 ×%.2f"%gain
  elif b.type=="biolab":
   var proxy: Dictionary={"t3_fuel":float(b.get("bio_fuel",0))}
   var used:=FrontierTerraformTier3.fuel(site,proxy,"ice",dt,float(cfg.biolab_nutrient_seconds));b.bio_fuel=proxy.t3_fuel
   b.working=spread(needed,"environment","ecology",used*float(cfg.biolab_rate)*factor/coefficient,100)>0
 elif b.type=="biolab":b.status="토양·급수·온도·대기 조건 확인"
 if int(b.get("tier",1))<2:return
 var restore: Dictionary=FrontierProductionTier2.config().restoration
 var key: String="salinity" if b.type=="water" else "soil"
 var target:=0.0 if b.type=="water" else 100.0
 needed=[]
 for pair in cells:
  if absf(float(pair[0].restoration2[key])-target)>.001:needed.append(pair)
 if needed.is_empty():return
 var item: String=site.free_terraform.restoration.get("inputs",{}).get(b.type,"mineral_filter" if b.type=="water" else "soil_base")
 var cycle: float=restore.filter_cycle if b.type=="water" else restore.soil_cycle
 var amount: float=restore.salt_per_filter if b.type=="water" else restore.soil_per_pack
 var count:=input_cycles(site,b,item,dt,cycle,"treatment_work")
 spread(needed,"restoration2",key,count*amount/coefficient,target)

static func supply_at(site: Dictionary,p: Vector3) -> String:
 var id:=district_id(site,p);var distance:=9.0
 for row in site.buildings.values():
  if row.type!="storage" or row.get("submerged",false):continue
  var d:=p.distance_to(FrontierCrewWorld.vector(row.position))
  if d<distance:distance=d;id=str(row.region_id)
 return id
