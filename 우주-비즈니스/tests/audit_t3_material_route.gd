extends "res://tests/test_crew_surface.gd"
## One economic route: no injected goods, facilities, licenses or power.
## Arrival/foot positions and elapsed production seconds are controlled; travel/hazards are not timed.
var core: FrontierCrewAuthority
var actor: String
var factories: Dictionary={}
var stores: Dictionary={}
var mines: Dictionary={}
var extracted: Dictionary={}
var operation_count:=0
var production_seconds:=0
func command(kind: String,args: Dictionary={}) -> bool:
 core.advance_time(core.now+1.0);operation_count+=1
 var response:=request(core,1,kind,args)
 if not response.ok:check(false,kind+" "+str(args)+" "+str(response.get("error",response)))
 return response.ok
func site() -> Dictionary:return FrontierExpeditionBusiness.site(core.world)
func bag() -> Dictionary:return FrontierExpeditionBusiness.bag(core.world,actor)
func move(point: Vector3) -> void:core.world.crew.members[actor].position=FrontierExpeditionBusiness.array(point)
func visit(body: Dictionary) -> void:
 core.world.location=body.id;core.world.navigation_target=body.id
 core.world.crew.navigation.target=int(body.ordinal);core.world.crew.navigation.system=int(body.system_ordinal)
 core.world.crew.landing={"body_id":body.id,"epoch":1}
 core.world.crew.members[actor].aboard=false;core.world.crew.members[actor].area="surface"
 FrontierEcology.ensure_planet(core.world.ecology,body);FrontierExpeditionBusiness.ensure_site(core.world)
 move(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
func building(id: String) -> Dictionary:return site().buildings[id]
func warehouse() -> Vector3:return FrontierCrewWorld.vector(building(stores[core.world.location]).position)
func stock() -> Dictionary:
 var id: String=building(stores[core.world.location]).get("region_id","region:0")
 return site().regions[id].inventory if site().has("regions") else site().inventory
func raw_to_bag(id: String,amount: int) -> bool:
 var ship_amount:=int(core.world.crew.rock) if id=="stone" else int(core.world.crew.cargo.get(id,0))
 var take:=mini(maxi(0,amount-int(bag().get(id,0))),ship_amount)
 if take>0:
  move(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
  if not command("withdraw",{"resource":id,"amount":take}):return false
 if int(bag().get(id,0))>=amount:return true
 var body:=FrontierUniverse.body_from_id(core.world.manifest,core.world.location);var field:=FrontierCrewSurface.field(core.world)
 var key: String=body.id+":"+id
 var capacity:=0
 for found in mines.get(key,[]):capacity+=int(site().remaining.get(found.row.id,found.row.capacity))
 if capacity<amount-int(bag().get(id,0)):mines.erase(key)
 if not mines.has(key):
  mines[key]=[]
  capacity=0
  for radius in range(0,7):
   for x in range(-radius,radius+1):
    for z in range(-radius,radius+1):
     if maxi(absi(x),absi(z))!=radius:continue
     var rows:=FrontierMineralWorld.region(body,x,z)
     if x==0 and z==0:rows.append_array(FrontierExpeditionBusiness.starter_veins(body))
     for row in rows:
      if row.resource!=id or row.get("underground",false):continue
      var point:=FrontierMineralWorld.point(field,row)
      if point.is_finite() and int(site().remaining.get(row.id,row.capacity))>0:
       mines[key].append({"row":row,"point":point});capacity+=int(site().remaining.get(row.id,row.capacity))
   if capacity>=amount-int(bag().get(id,0)):break
 for found in mines[key]:
  var row: Dictionary=found.row;var point: Vector3=found.point
  move(point+Vector3.UP*.1)
  while int(bag().get(id,0))<amount and int(site().remaining.get(row.id,row.capacity))>0:
   var before:=int(bag().get(id,0))
   if not command("business_mine",{"vein_id":row.id}):return false
   extracted[id]=int(extracted.get(id,0))+int(bag().get(id,0))-before
  if int(bag().get(id,0))>=amount:return true
 check(false,"accessible seeded ore supply for "+id);return false
func deposit_bag() -> bool:
 if FrontierExpeditionBusiness.total(bag())==0:return true
 move(warehouse()+Vector3(0,0,4));return command("business_deposit",{"all_resources":true})
func build(kind: String) -> bool:
 for id in FrontierCatalog.entry("buildings",kind).cost:
  if not raw_to_bag(id,int(FrontierCatalog.entry("buildings",kind).cost[id])):return false
 var point:=Vector3.INF;var field:=FrontierCrewSurface.field(core.world)
 for x in range(24,145,10):
  if point.is_finite():break
  for z in range(24,145,10):
   var p:=FrontierExpeditionBusiness.ground(field,x,z,3)
   if not p.is_finite():continue
   if stores.has(core.world.location) and FrontierRegionalTerraform.region_id(site(),p)!=building(stores[core.world.location]).get("region_id","region:0"):continue
   move(p+Vector3(0,0,6))
   if FrontierExpeditionBusiness.build_reason(core.world,actor,kind,p,core.peers).is_empty():point=p;break
 if not point.is_finite():check(false,"valid build position "+kind);return false
 var ids: Array=site().buildings.keys()
 if not command("business_build",{"building":kind,"position":FrontierExpeditionBusiness.array(point)}):return false
 for id in site().buildings:
  if id in ids:continue
  if kind=="storage":stores[core.world.location]=id
  if kind=="factory":factories[core.world.location]=id
 return deposit_bag()
func make(cost: Dictionary) -> bool:
 var estimate:=FrontierProductionPlan.estimate(cost,stock())
 if not estimate.error.is_empty():check(false,estimate.error);return false
 for id in estimate.raw:
  if not raw_to_bag(id,int(estimate.raw[id])) or not deposit_bag():return false
 for step in estimate.steps:
  var remaining:=int(step.batches)
  while remaining>0:
   var batches:=mini(remaining,20);remaining-=batches
   move(FrontierCrewWorld.vector(building(factories[core.world.location]).position)+Vector3(0,0,4))
   if not command("business_produce",{"building_id":factories[core.world.location],"product":step.id,"batches":batches}):return false
   for second in 600:
    FrontierExpeditionIndustry.tick(core.world,1);production_seconds+=1
    if building(factories[core.world.location]).get("production",{}).is_empty():break
   if not building(factories[core.world.location]).get("production",{}).is_empty():check(false,"powered production completes: "+step.id+" "+str(building(factories[core.world.location])));return false
 check(FrontierExpeditionBusiness.affordable(stock(),cost),"quoted inputs yield requested goods "+str(cost))
 return failures==0
func upgrade_factory() -> bool:
 if not make(FrontierProductionTier2.upgrade_definition(building(factories[core.world.location])).cost):return false
 move(FrontierCrewWorld.vector(building(factories[core.world.location]).position)+Vector3(0,0,4))
 return command("business_facility_upgrade",{"building_id":factories[core.world.location]})
func load_ship(id: String,amount: int) -> bool:
 move(warehouse()+Vector3(0,0,4))
 if not command("business_withdraw",{"resource":id,"amount":amount}):return false
 move(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
 return command("deposit",{"resource":id,"amount":amount})
func run() -> void:
 core=FrontierCrewAuthority.new();var owner:=FrontierPlayerProfile.new_character("T3 재료 경로",0);actor=owner.character_id
 if not core.start(FrontierUniverse.new_world(71503),owner,persist) or not command("start_game"):quit(1);return
 var station: Dictionary={};var index:=1
 while station.is_empty():station=FrontierSpaceStation.definition(core.world.manifest,index);index+=1
 var nav: Dictionary=core.world.crew.navigation;nav.system=index-1;nav.mode="idle";nav.speed=0
 nav.position=FrontierExpeditionBusiness.array(FrontierCrewWorld.vector(station.position)+Vector3(0,0,1100));core.world.flight_position=nav.position.duplicate()
 if not command("station_blueprint",{"item":"facility_factory_mk3"}):quit(1);return
 core.world.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"));core.world.terrain_settings_hash=FrontierUniverse.fingerprint(core.world.terrain_settings);core.world.ecology=FrontierEcology.create()
 var metal: Dictionary={};var cold: Dictionary={}
 for ordinal in range(8,600):
  var body:=FrontierUniverse.body(core.world.manifest,ordinal)
  if not FrontierUniverse.landable(body):continue
  if body.get("mineral_profile",{}).get("id")=="metallic" and metal.is_empty():metal=body
  if body.get("mineral_profile",{}).get("id")=="cryogenic" and cold.is_empty():cold=body
  if not metal.is_empty() and not cold.is_empty():break
 check(not metal.is_empty() and not cold.is_empty(),"natural metal and cold supply planets")
 if failures:quit(1);return
 print("ROUTE_PLANETS ",metal.ordinal," ",cold.ordinal)
 visit(metal)
 if not command("business_lease"):quit(1);return
 for kind in ["storage","solar","factory"]:
  if not build(kind):quit(1);return
 if not upgrade_factory() or not make(FrontierEquipment.config().items.miner_2.cost):quit(1);return
 for id in FrontierEquipment.config().items.miner_2.cost:
  move(warehouse()+Vector3(0,0,4))
  if not command("business_withdraw",{"resource":id,"amount":int(FrontierEquipment.config().items.miner_2.cost[id])}):quit(1);return
 if not command("equipment_craft",{"definition":"miner_2"}):quit(1);return
 var member: Dictionary=core.world.crew.members[actor];var tool_id: String="crafted:"+str(int(member.loadout.counter))
 if not command("equipment_equip",{"item_id":tool_id,"slot":0}) or not make({"alloy_frame":2}) or not load_ship("alloy_frame",2):quit(1);return
 # New worlds deliberately omit one basic deposit. Bring its construction/processing budget.
 var absent:=FrontierGroundProgression.absent_starter(cold)
 var cold_cost:=FrontierProductionPlan.facility_cost("factory",0)
 for kind in ["storage","solar"]:FrontierExpeditionBusiness.transfer(cold_cost,FrontierCatalog.entry("buildings",kind).cost,1)
 var cold_plan:=FrontierProductionPlan.estimate(cold_cost,{"alloy_frame":int(core.world.crew.cargo.get("alloy_frame",0))})
 if cold_plan.raw.has(absent):
  var amount:=int(cold_plan.raw[absent])
  if not raw_to_bag(absent,amount):quit(1);return
  move(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
  if not command("deposit",{"resource":absent,"amount":amount}) or not deposit_bag():quit(1);return
  print("SHORTFALL_FREIGHT ",absent," ",amount)
 var remote_stock:=FrontierUniverse.fingerprint(stock())
 visit(cold)
 if not command("business_lease"):quit(1);return
 for kind in ["storage","solar","factory"]:
  if not build(kind):quit(1);return
 if not upgrade_factory() or not make({"cryo_cell":2}):quit(1);return
 move(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
 if not command("withdraw",{"resource":"alloy_frame","amount":2}) or not deposit_bag() or not upgrade_factory():quit(1);return
 check(int(building(factories[cold.id]).tier)==3,"starter goods and mined materials install first Mk.3")
 check(int(core.world.business.credits)==3800,"two real leases and factory blueprint leave 3800 Cr")
 var destination: String=core.world.location;visit(metal)
 check(FrontierUniverse.fingerprint(stock())==remote_stock,"transport does not consume remote warehouse stock implicitly")
 visit(FrontierUniverse.body_from_id(core.world.manifest,destination))
 check(FrontierUniverse.validate_world(core.world).is_empty(),"material route preserves valid save")
 var folder:="/tmp/t3-material-route";DirAccess.make_dir_recursive_absolute(folder)
 check(FrontierWorldStore.new(folder+"/world.json").write(core.world),"save constructed supply route")
 print("T3_MATERIAL_ROUTE ",JSON.stringify({"checks":checks,"failures":failures,"commands":operation_count,"mined":extracted,"production_seconds":production_seconds,"credits":core.world.business.credits,"planets":[metal.ordinal,cold.ordinal]}))
 quit(1 if failures else 0)
