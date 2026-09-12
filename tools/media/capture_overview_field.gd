extends "capture_gameplay.gd"
var installations: Dictionary={}
func frames(n: int) -> void:
 for i in n:await process_frame
func position_on_ground(x: float,z: float) -> Vector3:
 var f:=app.surface_world.terrain.field
 return Vector3(x,f.height(x,z)+.15,z)
func place_fixture(kind: String,tier: int=1) -> Dictionary:
 var world: Dictionary=app.session.authority.world;var site:=FrontierExpeditionBusiness.site(world)
 var field:=app.surface_world.terrain.field;var p:=Vector3.INF
 for z in range(-20,41,10):
  if p.is_finite():break
  for x in range(-35,36,10):
   var q:=FrontierExpeditionBusiness.ground(field,x,z,maxf(3,FrontierCatalog.entry("buildings",kind).radius))
   if not q.is_finite():continue
   var clear:=true
   for b in site.buildings.values():
    if FrontierCrewWorld.vector(b.position).distance_to(q)<9:clear=false
   if clear:p=q;break
 if not p.is_finite():return {}
 var id: String="overview:facility:"+str(site.buildings.size())
 var region:=FrontierFreeTerraform.district_id(site,p)
 if not site.regions.has(region):site.regions[region]=FrontierFreeTerraform.district(site,region)
 var b: Dictionary={"id":id,"type":kind,"tier":tier,"position":FrontierExpeditionBusiness.array(p),"active":false,"enabled":true,"work":0.0,"status":"준비","yaw":0.0,"region_id":region}
 site.buildings[id]=b;installations[kind]=b;return b
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--dest="):dest=arg.trim_prefix("--dest=")
 assert("--crew-ui-test" in OS.get_cmdline_user_args());DirAccess.make_dir_recursive_absolute(dest)
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame
 FrontierClientSettings.ensure(self).values.music_volume=0.0
 var character:=FrontierPlayerProfile.new_character("탐험가",2);owner=character.character_id
 app.profile.data={"version":1,"character":character,"sessions":{}};app.profile.save()
 var core:=FrontierCrewAuthority.new();core.start(FrontierUniverse.new_world(71491),character,func(_w):return true)
 var world: Dictionary=core.world;var body:=FrontierUniverse.body(world.manifest,11)
 world.crew.phase="playing";world.crew.navigation.solar_opening.elapsed=world.crew.navigation.solar_opening.duration
 world.location=body.id;world.navigation_target=body.id
 var nav: Dictionary=world.crew.navigation;nav.system=body.system_ordinal;nav.target=11;nav.mode="idle";nav.speed=0.0
 var best_time:=0.0;var best_height:=-2.0
 for time in range(0,20001,80):
  var sky:=FrontierPlanetaryCycles.sky_state(body,float(time),{})
  if sky.sun_height>best_height:best_time=float(time);best_height=sky.sun_height
 nav.orbit_time=best_time
 nav.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(11,world.manifest,best_time)+Vector3.UP*(FrontierUniverse.navigation_radius(body)+1))
 world.crew.members[owner].ready=true
 var error:=FrontierCrewSurface.apply(world,owner,"land",{},{1:owner})
 if not error.is_empty():printerr("LAND_SETUP ",error);quit(1);return
 var loadout: Dictionary=world.crew.members[owner].loadout
 for pair in [["terrain_1",1],["pulse_2",2],["miner_2",3]]:loadout.items["overview:"+pair[0]]=pair[0];loadout.slots[pair[1]]="overview:"+pair[0]
 if not app.world_store.write(world):printerr("SAVE ",app.world_store.last_error);quit(1);return
 app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not app.preparing_first_snapshot and not has_meta("startup_loader"),120):printerr("FIELD_START_FAILED");quit(1);return
 app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2
 app.outside=false;app.exterior_view.hide();app.if_flight_view();app.mouse_resume_guard=false
 app.session.response_received.connect(func(_seq,result):
  if not result.get("ok",false):print("REQUEST_ERROR ",result))
 await industry();await rover();await cave();await combat()
 FileAccess.open(dest+"/segments.json",FileAccess.WRITE).store_string(JSON.stringify({"segments":segments,"evidence":evidence},"  "))
 await app.session.close_session();app.queue_free();await process_frame;quit()
func industry() -> void:
 var world: Dictionary=app.session.authority.world;var site:=FrontierExpeditionBusiness.site(world)
 site.state="active";world.business.active=world.location;FrontierCoopWorkload.activate(site,app.surface_world.body,1)
 for i in 6:place_fixture("solar",2)
 for kind in ["factory","charger","water","biolab","thermal","atmosphere"]:place_fixture(kind,2)
 for region in site.regions.values():
  for resource in ["iron","copper","stone","ice","crystal","refined_iron","copper_coil","reinforced_frame","soil_base","mineral_filter"]:
   if not FrontierCatalog.entry("resources",resource).is_empty():region.inventory[resource]=200
 # Later-game prepared restoration state, then entirely normal running simulation.
 FrontierFreeTerraform.ensure_cells(site,app.surface_world.body,Vector2.ZERO,90)
 for cell in site.free_terraform.cells.values():
  cell.environment.merge({"oxygen":.21,"pressure":1.0,"toxicity":2.0,"temperature":18.0,"water":75.0,"ecology":68.0},true)
  cell.restoration2.merge({"salinity":5.0,"soil":80.0},true);cell.treated=true
 for air in site.free_terraform.air:air[0]=.21;air[1]=1.0;air[2]=2.0
 site.free_terraform.revision+=1
 print("INDUSTRY_WORLD_VALIDATION ",FrontierUniverse.validate_world(world))
 app.session._publish_surface();app.session._publish()
 var factory: Dictionary=installations.factory;var p:=FrontierCrewWorld.vector(factory.position)
 move_before_clip(position_on_ground(p.x,p.z+7));aim(p+Vector3.UP*1.2)
 await until(func():return app.surface_world.ready_at(app.actors[owner].position) and app.surface_world.business_view.nodes.has(factory.id),90);await frames(30)
 app.session.send_request("business_produce",{"building_id":factory.id,"product":"refined_iron"})
 start_clip("factory_production")
 for i in 160:aim(p+Vector3.UP*1.2);await process_frame
 end_clip();await still("factory")
 var bio: Dictionary=installations.biolab;p=FrontierCrewWorld.vector(bio.position)
 move_before_clip(position_on_ground(p.x+5,p.z+8));aim(p+Vector3.UP*1.2);await frames(15)
 start_clip("restored_industry")
 for i in 180:app.test_direction=Vector2(.2,0);aim(p+Vector3.UP*1.2);await process_frame
 app.test_direction=Vector2.ZERO;end_clip();await still("restored")
 app.toggle_navigation();app.planet_map.modes.current_tab=1;app.planet_map.refresh()
 var panel: FrontierTerraformPanel=app.planet_map.terraform;panel.focus=Vector2.ZERO;panel.chosen=Vector2.ZERO;panel.layer=2;panel.for_buttons();panel.refresh();await frames(15)
 start_clip("terraform_map");await frames(100);end_clip();await still("terraform-map");app.close_menus()
 # A previously manufactured robot receives the normal player work order.
 world=app.session.authority.world;site=FrontierExpeditionBusiness.site(world)
 for row in FrontierExpeditionBusiness.veins(app.surface_world.body,Vector3.ZERO):
  if int(row.required_tier)>2 or row.get("underground",false):continue
  var q:=FrontierMineralWorld.point(app.surface_world.terrain.field,row)
  if not q.is_finite() or Vector2(q.x,q.z).length()>200:continue
  ore=row;ore_point=q;break
 if ore.is_empty():printerr("NO_ROBOT_ORE");return
 var rp:=FrontierExpeditionBusiness.ground(app.surface_world.terrain.field,ore_point.x-1.8,ore_point.z)
 var robot: Dictionary={"id":"overview:robot","grade":"B","tier":2,"position":FrontierExpeditionBusiness.array(rp),"battery":100.0,"cargo":FrontierExpeditionBusiness.inventory(),"phase":"idle","target":"","path":[],"status":"작업 배정 대기","work":0.0,"charging":false,"region_id":"region:0"}
 if not FrontierCatalog.table("grades").has("B"):robot.grade=FrontierCatalog.table("grades").keys()[0]
 FrontierRobotWork.ensure(robot);site.robots[robot.id]=robot
 print("ROBOT_WORLD_VALIDATION ",FrontierUniverse.validate_world(world))
 move_before_clip(position_on_ground(ore_point.x+4,ore_point.z+5));aim(ore_point+Vector3.UP*.7);app.session._publish_surface();app.session._publish();await frames(25)
 app.session.send_request("business_assign",{"vein_id":ore.id,"robot_id":robot.id})
 start_clip("robot_mining");await frames(210);end_clip();await still("robot")
 site=FrontierExpeditionBusiness.site(app.session.authority.world)
 evidence["robot_cargo"]=site.robots.get(robot.id,{}).get("cargo",{});evidence["factory"]=site.buildings[factory.id].get("production",{});evidence["terraform_cells"]=site.free_terraform.cells.size()
func rover() -> void:
 var world: Dictionary=app.session.authority.world
 var p:=FrontierRovers.safe(world,position_on_ground(40,45),2.5)
 if not p.is_finite():p=position_on_ground(45,35)
 var f:=FrontierRovers.ensure(world);f.counter+=1;var id: String="rover:"+str(int(f.counter))
 var r: Dictionary={"id":id,"definition":FrontierRovers.config().definition,"owner_world_id":world.crew.world_id,"location_kind":"surface","body_id":world.location,"position":FrontierExpeditionBusiness.array(p),"rotation":[0.0,0.0,0.0],"upgrade_level":0,"battery":float(FrontierRovers.config().battery),"health":float(FrontierRovers.config().health),"cargo":FrontierExpeditionBusiness.inventory(),"equipment":{},"speed":0.0,"steering":0.0,"overturned":false,"distance":0.0,"event":"complete","event_serial":1}
 f.vehicles[id]=r;app.session._publish();app.session._publish_surface()
 move_before_clip(FrontierRovers.point(r,[-2.3,0,0])+Vector3.UP*.15);await until(func():return app.rovers.actors.has(id) and app.surface_world.ready_at(app.actors[owner].position),60);await frames(20)
 app.session.send_request("rover_enter",{"id":id,"seat":0});await frames(20)
 app.rovers.chase=true;app.rovers.test_controls=[1.0,.12,0.0,0.0]
 start_clip("rover_drive");await frames(180);end_clip();await still("rover")
 app.rovers.test_controls=[0.0,0.0,1.0,0.0];await frames(40);app.session.send_request("rover_exit",{"id":id});await until(func():return app.rovers.seat().is_empty(),10)
 evidence["rover_distance"]=FrontierRovers.fleet(app.session.authority.world).vehicles[id].distance
func cave() -> void:
 var field:=app.surface_world.terrain.field
 if field.caves==null:printerr("NO_CAVES");return
 var graph: Dictionary={}
 for x in range(-3,4):
  if not graph.is_empty():break
  for z in range(-3,4):
   var candidate: Dictionary=field.caves.system_at(x*500,z*500)
   if not candidate.chambers.is_empty():graph=candidate;break
 if graph.is_empty():printerr("NO_CAVE_CHAMBER");return
 var center: Vector3=graph.chambers[0].center;var p:=center
 for i in 220:
  if field.density(p)>0:break
  p.y-=.1
 p.y+=.2
 move_before_clip(p);await until(func():return app.surface_world.ready_at(p),100);await frames(15)
 var target:=center+Vector3(3,0,-9);target.y=p.y+1.0
 aim(target);app.session.send_request("equipment_select",{"slot":1});await frames(15)
 start_clip("underground_dig")
 for i in 210:
  app.test_direction=Vector2(0,-1) if i<75 else Vector2.ZERO
  if i>45 and app.dig_timer<=0:app.use_equipped()
  await process_frame
 app.test_direction=Vector2.ZERO;end_clip();await still("cave");evidence["cave_position"]=FrontierExpeditionBusiness.array(p)
func combat() -> void:
 var body: Dictionary=app.surface_world.body;var field:=app.surface_world.terrain.field;var found: Dictionary={}
 for x in range(-3,4):
  if not found.is_empty():break
  for z in range(-3,4):
   for row in FrontierExplorationIncidents.tile(body,field,Vector2i(x,z)):
    if row.template=="illuti_dormant_combat_robot":found=row;break
   if not found.is_empty():break
 if found.is_empty():printerr("NO_NATIVE_ROBOT_INCIDENT");return
 var id:=FrontierExplorationIncidents.key(found);var world: Dictionary=app.session.authority.world
 world.incidents.records[id]=FrontierExplorationIncidents.create(found)
 var target:=FrontierExplorationIncidents.point(found,Vector3(0,1.4,0));var p:=FrontierExplorationIncidents.point(found,Vector3(0,.15,10))
 p.y=field.height(p.x,p.z)+.15;move_before_clip(p);aim(target);app.session._publish();app.session._publish_surface()
 await until(func():return app.surface_world.ready_at(p) and app.surface_world.incidents.models.has(id),100)
 app.session.send_request("equipment_select",{"slot":2});await frames(20)
 start_clip("coopertech_encounter")
 for i in 240:
  aim(target)
  if i>45 and app.dig_timer<=0:app.use_equipped()
  await process_frame
 end_clip();await still("combat");evidence["combat_hp"]=app.session.authority.world.incidents.records[id].hp
