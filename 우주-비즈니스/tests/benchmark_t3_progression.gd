extends "res://tests/check_facility_interactions.gd"
## Known-route benchmark, independent host-controlled characters, native collision movement.
## No teleportation, material grants, free licenses or accelerated production rules.
var players:=1
var core: FrontierCrewAuthority
var started:=0.0
var wall_started:=0
var phase:="startup"
var marks: Dictionary={}
var phase_seconds: Dictionary={}
var goals: Dictionary={}
var walking: Dictionary={}
var walking_seconds: Dictionary={}
var mining_seconds: Dictionary={}
var production_wait_seconds:=0.0
var input_serial:=100000
var factories: Dictionary={}
var stores: Dictionary={}
var mined: Dictionary={}
var transfers: Array=[]
var flights: Array=[]
var jobs: Array=[]
var workers_done:=0
var last_notice:=0
var running:=false
var finalizing:=false
var command_count:=0
var output: Dictionary={}
func now() -> float:return float(app.session.get("elapsed")) if app!=null else 0.0
func actor(peer: int) -> String:return core.peers[peer]
func position(peer: int) -> Vector3:return app.actors[actor(peer)].position
func site() -> Dictionary:return FrontierExpeditionBusiness.site(core.world)
func bag(peer: int) -> Dictionary:return FrontierExpeditionBusiness.bag(core.world,actor(peer))
func stock() -> Dictionary:
 if not stores.has(core.world.location):return {}
 var id: String=site().buildings[stores[core.world.location]].get("region_id","region:0")
 return site().regions[id].inventory if site().has("regions") else site().inventory
func warehouse() -> Vector3:return FrontierCrewWorld.vector(site().buildings[stores[core.world.location]].position)+Vector3(0,0,5)
func factory() -> Dictionary:return site().buildings[factories[core.world.location]]
func fail(message: String) -> void:
 if finalizing or failures>0:return
 failures+=1;printerr("BENCHMARK_FAIL ",message);output.error=message;finish.call_deferred(false)
func milestone(label: String) -> void:
 marks[label]=now()-started;print("MILESTONE ",label," ",snappedf(now()-started,.1));save_status()
func save_status() -> void:
 var data: Dictionary={"players":players,"phase":phase,"seconds":now()-started,"wall_seconds":(Time.get_ticks_msec()-wall_started)/1000.0,"marks":marks,"phase_seconds":phase_seconds,"mined":mined,"credits":core.world.get("business",{}).get("credits",FrontierExpeditionBusiness.config().starting_credits),"flights":flights,"transfers":transfers,"walking_meters":walking,"commands":command_count,"failures":failures,"positions":{}}
 for peer in core.peers:
  if app.actors.has(actor(peer)):data.positions[str(peer)]=FrontierExpeditionBusiness.array(position(peer))
 data.merge(output,true)
 data.walking_seconds=walking_seconds;data.mining_seconds=mining_seconds;data.production_wait_seconds=production_wait_seconds
 FileAccess.open(folder+"/benchmark.json",FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
func _process(delta: float) -> bool:
 if not running or finalizing or core==null:return false
 phase_seconds[phase]=float(phase_seconds.get(phase,0))+minf(delta,.1)
 # Headless has no post-draw event. Keep the native warm-up frame count and animation timers.
 if DisplayServer.get_name()=="headless" and app.arrival.active:app.arrival._frame_drawn()
 if core.stopped:fail(core.error);return false
 for peer in core.peers:
  if not app.actors.has(actor(peer)):continue
  var dir:=Vector2.ZERO
  if goals.has(peer):
   var route: Array=goals[peer]
   while not route.is_empty() and Vector2(position(peer).x-route[0].x,position(peer).z-route[0].z).length()<.45:route.pop_front()
   if route.is_empty():goals.erase(peer)
   else:dir=Vector2(route[0].x-position(peer).x,route[0].z-position(peer).z).normalized()
  if peer==1:app.test_direction=dir.rotated(app.yaw);app.test_sprint=false
  else:
   input_serial+=1;core.input(peer,input_serial,[dir.x,dir.y],[],false,false,[0.0,0.0,0.0],0,true)
 if Time.get_ticks_msec()-last_notice>20000:
  last_notice=Time.get_ticks_msec();print("BENCHMARK_PROGRESS ",players," ",phase," ",snappedf(now()-started,.1));save_status()
 return false
func command(kind: String,args: Dictionary={},peer: int=1) -> bool:
 if failures:return false
 core.advance_time(now());command_count+=1
 var seq:=int(core.world.crew.members[actor(peer)].last_sequence)+1
 var response:=core.request(peer,{"session_id":core.session_id,"sequence":seq,"revision":core.world.crew.revision,"kind":kind,"args":args})
 if peer==1:app.session.next_sequence=maxi(app.session.next_sequence,seq+1)
 if not response.ok:fail(kind+" "+str(args)+" "+str(response));return false
 if kind in ["withdraw","deposit","business_withdraw","business_deposit"]:transfers.append({"at":now()-started,"peer":peer,"kind":kind,"args":args.duplicate()})
 app.session._publish();app.session._publish_surface();return true
func delay(seconds: float) -> void:
 var until_time:=now()+seconds
 while now()<until_time and not failures:await physics_frame
func wait_for(predicate: Callable,limit: float,label: String) -> bool:
 var deadline:=now()+limit
 while not predicate.call() and now()<deadline and not failures:await physics_frame
 if not predicate.call() and not failures:fail(label+" timed out")
 return failures==0
func walking_obstacles() -> Array:
 var obstacles:=FrontierExpeditionIndustry.obstacles(core.world)
 for node in app.surface_world.business_view.nodes.values():
  if node.get_meta("business_kind","")=="vein":obstacles.append({"position":FrontierExpeditionBusiness.array(node.position),"radius":1.1})
 # Surface scatter has physical rock capsules in addition to veins and buildings.
 for node in app.surface_world.find_children("*","CollisionShape3D",true,false):
  if node.disabled or not node.get_parent() is StaticBody3D:continue
  if node.shape is CapsuleShape3D or node.shape is SphereShape3D:
   var scale_value: Vector3=node.global_basis.get_scale()
   obstacles.append({"position":FrontierExpeditionBusiness.array(node.global_position),"radius":float(node.shape.radius)*maxf(absf(scale_value.x),absf(scale_value.z))})
 return obstacles
func walking_route(peer: int,goal: Vector3,origin: Vector3=Vector3.INF) -> Array:
 if not origin.is_finite():origin=position(peer)
 var terrain:=app.surface_world.terrain.field
 var cfg: Dictionary=FrontierSurfaceLogistics.config().navigation.duplicate(true);cfg.search_radius=1200.0;cfg.search_limit=10000
 var obstacles:=walking_obstacles()
 var navigator:=FrontierTerrainNavigation.new()
 navigator.field=terrain;navigator.settings=cfg;navigator.obstacles=obstacles
 if not navigator.clear_at(goal):return []
 var path:=navigator.find_path(terrain,origin,goal,cfg,obstacles)
 if not path.points.is_empty() and not navigator.segment_clear(path.points[-1],goal):
  cfg.step=.75;path=navigator.find_path(terrain,origin,goal,cfg,obstacles)
 if path.points.is_empty() or not navigator.segment_clear(path.points[-1],goal):
  output.path_failure={"result":path,"origin":str(origin),"goal":str(goal),"origin_clear":navigator.clear_at(origin),"goal_clear":navigator.clear_at(goal)}
  return []
 var route: Array=[]
 for p in path.points:route.append(p)
 route.append(goal);return route
func walk(peer: int,destination: Vector3) -> bool:
 if failures:return false
 var terrain:=app.surface_world.terrain.field
 var goal:=FrontierExpeditionBusiness.ground(terrain,destination.x,destination.z)
 if not goal.is_finite():fail("unsupported walking destination "+str(destination));return false
 if position(peer).distance_to(goal)<3:return true
 var route:=walking_route(peer,goal)
 if route.is_empty():fail("walking route "+str(position(peer))+" → "+str(goal));return false
 goals[peer]=route
 var walk_started:=now()
 var last:=position(peer);var deadline:=now()+maxf(90,position(peer).distance_to(goal)/2.0);var stuck:=now();var previous:=last
 var retreating:=false;var attempts:=0
 while (goals.has(peer) or retreating) and not failures:
  await physics_frame
  var current:=position(peer);walking[str(peer)]=float(walking.get(str(peer),0))+current.distance_to(last);last=current
  if current.distance_to(previous)>1:previous=current;stuck=now()
  if retreating and not goals.has(peer):
   route=walking_route(peer,goal)
   if route.is_empty():fail("no route after physical retreat");return false
   goals[peer]=route;retreating=false;stuck=now()
  if now()-stuck>2 and attempts<4:
   var away: Vector3=current-goal;away.y=0;away=away.normalized()
   var body: CharacterBody3D=app.actors[actor(peer)]
   for i in body.get_slide_collision_count():
    var normal:=body.get_slide_collision(i).get_normal()
    if Vector2(normal.x,normal.z).length()>.5:away=Vector3(normal.x,0,normal.z).normalized();break
   var retreat:=FrontierExpeditionBusiness.ground(terrain,current.x+away.x*2,current.z+away.z*2)
   if not retreat.is_finite():fail("no supported retreat");return false
   attempts+=1;output.detours=int(output.get("detours",0))+1
   print("WALK_DETOUR ",peer," ",current," → ",retreat)
   goals[peer]=[retreat];retreating=true;stuck=now();deadline+=30
  if now()>deadline or now()-stuck>20:fail("walking blocked peer %d at %s toward %s"%[peer,current,goal]);return false
 if failures:return false
 app.test_direction=Vector2.ZERO if peer==1 else app.test_direction
 walking_seconds[str(peer)]=float(walking_seconds.get(str(peer),0))+now()-walk_started
 return failures==0
func ready() -> bool:
 for peer in core.peers:
  if not command("ready",{"value":true},peer):return false
 return true
func fly(ordinal: int) -> bool:
 phase="flight"
 var dest:=FrontierUniverse.system_index(core.world.manifest,ordinal)
 while int(core.world.crew.navigation.system)!=dest:
  var from:=int(core.world.crew.navigation.system);var target:=dest;var range_value:=FrontierVesselRefit.stellar_range(core.world)
  var endpoint:=FrontierUniverse.map_position(core.world.manifest,dest)
  if FrontierUniverse.map_position(core.world.manifest,from).distance_to(endpoint)>range_value:
   var best:=INF;target=-1
   for candidate in FrontierStellarRoutes.nearby(core.world.manifest,from,range_value):
    var distance:=FrontierUniverse.map_position(core.world.manifest,candidate.index).distance_to(endpoint)
    if distance<best:best=distance;target=candidate.index
  if target<0 or target==from:fail("no reachable stellar route");return false
  var next:=ordinal if target==dest else FrontierUniverse.first_ordinal(core.world.manifest,target)
  if not command("navigate",{"ordinal":next}) or not ready() or not command("depart"):return false
  flights.append({"from":from,"to":target,"start":now()-started})
  if not await wait_for(func():return core.world.crew.navigation.mode=="idle",60,"stellar transit"):return false
 if not command("navigate",{"ordinal":ordinal}) or not ready() or not command("depart"):return false
 if not await wait_for(func():return core.world.crew.navigation.mode=="idle",1200,"planet approach"):return false
 if not ready() or not command("land"):return false
 phase="landing"
 if not await wait_for(func():return app.surface_world!=null and not app.arrival.active and app.surface_world.ready_at(position(1)),300,"native landing scene"):return false
 app.onboarding.letter.hide();app.close_menus();app.outside=false;app.exterior_view.hide();app.if_flight_view()
 return true
func leave() -> bool:
 phase="boarding"
 for peer in core.peers:
  if not await walk(peer,FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)):return false
 for peer in core.peers:
  if not command("surface_board",{},peer):return false
 return await wait_for(func():return app.surface_world==null and not app.arrival.active,300,"native takeoff scene")
func deposit_bag(peer: int) -> bool:
 if FrontierExpeditionBusiness.total(bag(peer))<=0:return true
 if not await walk(peer,warehouse()):return false
 return command("business_deposit",{"all_resources":true},peer)
func candidates(resource: String,peer: int) -> Array:
 var body:=app.surface_world.body;var field:=app.surface_world.terrain.field;var rows: Array=FrontierExpeditionBusiness.starter_veins(body)
 for x in range(-2,3):
  for z in range(-2,3):rows.append_array(FrontierMineralWorld.region(body,x,z))
 var options: Array=[]
 for row in rows:
  if row.resource!=resource or row.get("underground",false) or int(site().remaining.get(row.id,row.capacity))<=0:continue
  var point:=FrontierMineralWorld.point(field,row)
  if point.is_finite():options.append({"row":row,"point":point,"distance":position(peer).distance_to(point)})
 options.sort_custom(func(a,b):return a.distance<b.distance);return options
func mining_stance(peer: int,point: Vector3) -> Vector3:
 var offset: Vector3=position(peer)-point;offset.y=0
 if offset.length_squared()<.1:offset=Vector3.RIGHT
 var navigator:=FrontierTerrainNavigation.new()
 navigator.field=app.surface_world.terrain.field;navigator.settings=FrontierSurfaceLogistics.config().navigation;navigator.obstacles=walking_obstacles()
 for degrees in [0,45,-45,90,-90,135,-135,180]:
  var p:=point+offset.normalized().rotated(Vector3.UP,deg_to_rad(degrees))*3.5
  var grounded:=FrontierExpeditionBusiness.ground(navigator.field,p.x,p.z)
  if grounded.is_finite() and navigator.clear_at(grounded):return grounded
 return Vector3.INF
func gather_bag(resource: String,amount: int,peer: int=1) -> bool:
 var options:=candidates(resource,peer)
 for found in options:
  var stance:=mining_stance(peer,found.point)
  if not stance.is_finite():continue
  if not await walk(peer,stance):break
  var mine_started:=now()
  while int(bag(peer).get(resource,0))<amount and int(site().remaining.get(found.row.id,found.row.capacity))>0 and not failures:
   var before:=int(bag(peer).get(resource,0))
   if not command("business_mine",{"vein_id":found.row.id},peer):break
   var count:=int(bag(peer).get(resource,0))-before;mined[resource]=int(mined.get(resource,0))+count
   await delay(float(FrontierEquipment.active(core.world.crew.members[actor(peer)]).interval)+.02)
  mining_seconds[str(peer)]=float(mining_seconds.get(str(peer),0))+now()-mine_started
  if int(bag(peer).get(resource,0))>=amount:break
 if failures:return false
 if int(bag(peer).get(resource,0))<amount:fail("insufficient accessible "+resource)
 return failures==0
func worker(peer: int) -> void:
 while not jobs.is_empty() and not failures:
  var selected:=-1
  for i in jobs.size():
   if FrontierMineralWorld.tier(jobs[i].id)<=int(FrontierEquipment.active(core.world.crew.members[actor(peer)]).tier):selected=i;break
  if selected<0:break
  var job: Dictionary=jobs[selected];jobs.remove_at(selected)
  if not await gather_bag(job.id,int(job.amount),peer):break
  if not await deposit_bag(peer):break
 workers_done+=1
func prepare(cost: Dictionary) -> bool:
 phase="gather_and_process"
 var plan:=FrontierProductionPlan.estimate(cost,stock())
 jobs=[]
 for id in plan.raw:
  var needed:=int(plan.raw[id]);var cargo:=int(core.world.crew.rock) if id=="stone" else int(core.world.crew.cargo.get(id,0))
  var amount:=mini(needed,cargo)
  if amount>0:
   if not await walk(1,FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)) or not command("withdraw",{"resource":id,"amount":amount}) or not await deposit_bag(1):return false
   needed-=amount
  while needed>0:
   var portion:=mini(50,needed);jobs.append({"id":id,"amount":portion});needed-=portion
 workers_done=0
 for peer in core.peers:worker(peer)
 if not await wait_for(func():return workers_done==players,1200,"parallel collection"):return false
 if not jobs.is_empty():fail("no suitable miner for remaining ore");return false
 for step in plan.steps:
  if not await walk(1,FrontierCrewWorld.vector(factory().position)+Vector3(0,0,5)):return false
  if not command("business_produce",{"building_id":factory().id,"product":step.id,"batches":int(step.batches)}):return false
  var production_started:=now()
  if not await wait_for(func():return factory().get("production",{}).is_empty(),600,"native powered production"):return false
  production_wait_seconds+=now()-production_started
 if not FrontierExpeditionBusiness.affordable(stock(),cost):fail("quoted goods missing after native production");return false
 return true
func withdraw_cost(cost: Dictionary) -> bool:
 if not await walk(1,warehouse()):return false
 for id in cost:
  if not command("business_withdraw",{"resource":id,"amount":int(cost[id])}):return false
 return true
func build(kind: String) -> bool:
 phase="construction"
 var cost: Dictionary=FrontierCatalog.entry("buildings",kind).cost
 if stores.has(core.world.location):
  if not await prepare(cost) or not await withdraw_cost(cost):return false
 else:
  if not await walk(1,FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)):return false
  for id in cost:
   var cargo:=int(core.world.crew.rock) if id=="stone" else int(core.world.crew.cargo.get(id,0))
   var amount:=mini(maxi(0,int(cost[id])-int(bag(1).get(id,0))),cargo)
   if amount>0 and not command("withdraw",{"resource":id,"amount":amount}):return false
  # A new landing has no warehouse yet: gather missing foundation goods into the builder bag.
  for id in cost:
   if int(bag(1).get(id,0))<int(cost[id]) and not await gather_bag(id,int(cost[id])):return false
 var point:=Vector3.INF;var field:=app.surface_world.terrain.field
 for x in range(24,145,10):
  if point.is_finite():break
  for z in range(24,145,10):
   var p:=FrontierExpeditionBusiness.ground(field,x,z,3)
   if not p.is_finite() or not FrontierExpeditionBusiness.placement(core.world,kind,p,core.peers).is_empty():continue
   if stores.has(core.world.location) and FrontierRegionalTerraform.region_id(site(),p)!=site().buildings[stores[core.world.location]].get("region_id","region:0"):continue
   point=p;break
 if not point.is_finite():fail("buildable flat ground "+kind);return false
 if not await walk(1,point+Vector3(0,0,6)):return false
 var ids: Array=site().buildings.keys()
 if not command("business_build",{"building":kind,"position":FrontierExpeditionBusiness.array(point)}):return false
 for id in site().buildings:
  if id in ids:continue
  if kind=="storage":stores[core.world.location]=id
  if kind=="factory":factories[core.world.location]=id
 return true
func upgrade() -> bool:
 if not await prepare(FrontierProductionTier2.upgrade_definition(factory()).cost):return false
 if not await walk(1,FrontierCrewWorld.vector(factory().position)+Vector3(0,0,5)):return false
 return command("business_facility_upgrade",{"building_id":factory().id})
func freight(id: String,amount: int) -> bool:
 if not await withdraw_cost({id:amount}) or not await walk(1,FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)):return false
 return command("deposit",{"resource":id,"amount":amount})
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
  if arg.begins_with("--benchmark-players="):players=int(arg.trim_prefix("--benchmark-players="))
 if not folder.begins_with("/tmp/t3-benchmark-") or players not in [1,2] or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 if FileAccess.file_exists(folder+"/world.json"):printerr("Use a new benchmark folder; existing saves are preserved.");quit(2);return
 DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(960,640);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
 await process_frame;app.session.set_script(load("res://tests/t3_benchmark_session.gd"))
 app.world_store.write(FrontierUniverse.new_world(71503));app.start_solo()
 if not await until(func():return app.session.active and not app.preparing_first_snapshot and not has_meta("startup_loader"),120):quit(1);return
 core=app.session.authority;app.onboarding.letter.hide();app.close_menus()
 if players==2:
  var guest:=FrontierPlayerProfile.new_character("협동 채집 담당",1)
  var admitted:=core.admit(2,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
  if not admitted.ok or not core.acknowledge(2,core.session_id).ok:quit(1);return
  app.session._publish();await process_frame
 while FrontierStellarRoutes.built<int(core.world.manifest.settings.planet_count)/int(core.world.manifest.settings.planets_per_system):FrontierStellarRoutes.build(core.world.manifest,0,50000)
 started=now();wall_started=Time.get_ticks_msec();running=true;milestone("start")
 # Same visible galaxy route in both runs; no T1/T2 settlement prerequisite exists.
 if not await fly(16408):return
 milestone("first_landing")
 if not await walk(1,FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)) or not command("business_lease"):return
 for kind in ["storage","solar","factory"]:
  if not await build(kind):return
 if not await upgrade():return
 milestone("factory_mk2")
 var miner_cost: Dictionary=FrontierEquipment.config().items.miner_2.cost
 if not await prepare(miner_cost) or not await withdraw_cost(miner_cost) or not command("equipment_craft",{"definition":"miner_2"}):return
 var id: String="crafted:"+str(int(core.world.crew.members[actor(1)].loadout.counter))
 if not command("equipment_equip",{"item_id":id,"slot":0}):return
 if not await prepare({"alloy_frame":2}) or not await freight("alloy_frame",2):return
 # Cold-site foundation + all processing, with the already transported alloy excluded.
 var budget:=FrontierProductionPlan.facility_cost("factory",0)
 for kind in ["storage","solar"]:FrontierExpeditionBusiness.transfer(budget,FrontierCatalog.entry("buildings",kind).cost,1)
 var amount:=int(FrontierProductionPlan.estimate(budget,{"alloy_frame":2}).raw.copper)
 if not await prepare({"copper":amount}) or not await freight("copper",amount):return
 milestone("metal_freight_ready")
 if not await leave() or not await fly(16412):return
 milestone("cold_landing")
 if not await walk(1,FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)) or not command("business_lease"):return
 await complete_cold_route()
func complete_cold_route() -> void:
 for kind in ["storage","solar","factory"]:
  if not await build(kind):return
 if not await upgrade() or not await prepare({"cryo_cell":2}):return
 if not await walk(1,FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)) or not command("withdraw",{"resource":"alloy_frame","amount":2}) or not await deposit_bag(1):return
 if not await prepare(FrontierProductionTier2.upgrade_definition(factory()).cost):return
 milestone("mk3_parts_ready")
 if not await leave():return
 # Station in the nearest reachable neighbouring system, then return to install the design.
 phase="flight"
 if not command("navigate",{"ordinal":FrontierUniverse.first_ordinal(core.world.manifest,12477)}) or not ready() or not command("depart"):return
 flights.append({"from":2051,"to":12477,"start":now()-started})
 if not await wait_for(func():return core.world.crew.navigation.mode=="idle",60,"station system transit") or not ready() or not command("station_approach"):return
 if not await wait_for(func():return FrontierSpaceStation.available(core.world),1200,"station approach") or not command("station_blueprint",{"item":"facility_factory_mk3"}):return
 milestone("blueprint_acquired")
 if not await fly(16412) or not await walk(1,FrontierCrewWorld.vector(factory().position)+Vector3(0,0,5)) or not command("business_facility_upgrade",{"building_id":factory().id}):return
 milestone("factory_mk3")
 if not await leave() or not await fly(356688):return
 milestone("t3_landing")
 output.valid_save=FrontierUniverse.validate_world(core.world).is_empty();output.t3_tier=app.surface_world.body.planet_tier
 await finish(true)
func finish(ok: bool) -> void:
 if finalizing:return
 finalizing=true;running=false;goals.clear();app.test_direction=Vector2.ZERO
 output.completed=ok;save_status()
 if DisplayServer.get_name()!="headless":await capture("benchmark-final")
 await app.session.close_session();app.queue_free();await process_frame
 print("T3_BENCHMARK_DONE ",players," ",ok);quit(0 if ok else 1)
