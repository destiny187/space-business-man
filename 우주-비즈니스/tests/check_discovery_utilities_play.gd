extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/discovery-utilities-play"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder="+folder not in OS.get_cmdline_user_args():quit(2);return
 root.size=Vector2i(960,640);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"utility expedition ready",90):quit(1);return
 app.onboarding.letter.hide();app.onboarding.set_process(false);app.onboarding.hide();app.close_menus();app.set_physics_process(false);app.set_process(false)
 root.size=Vector2i(960,640);root.content_scale_size=root.size
 var core:=app.session.authority;var world: Dictionary=core.world;var field:=app.surface_world.terrain.field;var actor: String=world.crew.owner_id
 var sample_key:=""
 # Session resume can restore the profile bag. The fixture's unique sample remains in its physical stock.
 for stock in FrontierSpecimenItems.stocks(world):
  for key in stock.keys():
   if FrontierDiscoveryUtilities.specimen_allowed(key):sample_key=key;stock.erase(key);break
 world.business.bags[actor]={"iron":150,"stone":200,"copper":100,"ice":0,"crystal":0}
 if sample_key.is_empty():check(false,"fixture real specimen preserved on entry");quit(1);return
 world.business.bags[actor][sample_key]=1
 var standing:=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)+Vector3(3,0,3);standing.y=field.height(standing.x,standing.z)+.1
 world.crew.members[actor].position=FrontierExpeditionBusiness.array(standing);app.actors[actor].position=standing;app.session._publish();app.session._publish_surface();await process_frame
 app.open_station("ship");app.business_panel.vessel_terminal.cards.research.pressed.emit();await process_frame
 var research: FrontierFacilityResearchPanel=app.stations.research_tabs.get_child(1);research.category.select(0)
 for key in FrontierDiscoveryUtilities.config().buildings:
  research.selected=key;research.signature="";research.refresh();await process_frame
  await until(func():return not research.action.disabled,"completed discovery unlocks "+key,5)
  research.action.pressed.emit()
  if not await until(func():return FrontierFacilityResearch.owned(core.world.business,key),"paid shared research "+key,20):quit(1);return
 app.close_menus();var placed: Dictionary={}
 for kind in FrontierDiscoveryUtilities.config().buildings:
  world=core.world;var def:=FrontierFacilityResearch.construction(kind);var at:=Vector3.INF
  for x in range(16,85,4):
   if at.is_finite():break
   for z in range(16,85,4):
    var p:=FrontierExpeditionBusiness.ground(field,x,z,float(def.radius))
    if not p.is_finite():continue
    standing=p+Vector3(0,0,6);standing.y=field.height(standing.x,standing.z)+.1;world.crew.members[actor].position=FrontierExpeditionBusiness.array(standing)
    if FrontierExpeditionBusiness.build_reason(world,actor,kind,p,{1:actor}).is_empty():at=p;break
  if not at.is_finite():check(false,"utility placement "+kind);quit(1);return
  app.actors[actor].position=standing;app.camera.set_as_top_level(true);app.camera.position=at+Vector3(5,4,-7);app.camera.look_at(at+Vector3.UP)
  app.session._publish();app.session._publish_surface();app.open_station("build");app.business_panel.build_category.select(0);app.business_panel.refresh_building_cost();await process_frame
  check(app.business_panel.building_cards[kind].visible,"functional B card "+kind)
  app.business_panel.building_cards[kind].pressed.emit();check(app.placement_kind==kind,"real placement ghost "+kind);app.close_menus()
  var count: int=FrontierExpeditionBusiness.site(core.world).buildings.size()
  app.session.send_request("business_build",{"building":kind,"position":FrontierExpeditionBusiness.array(at),"yaw":0.})
  if not await until(func():return FrontierExpeditionBusiness.site(core.world).buildings.size()==count+1,"paid construction "+kind,20):quit(1);return
  var id:=""
  for b in FrontierExpeditionBusiness.site(core.world).buildings.values():
   if b.type==kind:id=b.id;break
  placed[kind]=id
  if not await until(func():return app.surface_world.business_view.nodes.has(id),"Blender model placed "+kind,25):quit(1);return
  app.placement_kind="";app.cancel_placement();app.open_station(kind,id);await create_timer(.5).timeout
  check(app.business_panel.utility_panel.visible,"F utility controls "+kind)
  await capture("inspect-"+kind);app.close_menus();await capture("field-"+kind)
 # Keep finite controlled inputs while checking the authoritative power and wet-foundation paths.
 app.session.set_physics_process(false)
 if core.autonomous_pending():await until(func():return core.resolve_autonomous(),"controlled utility input ready",10)
 world=core.world;var site:=FrontierExpeditionBusiness.site(world)
 var tank: Dictionary=site.buildings[placed.luminous_vivarium]
 standing=FrontierCrewWorld.vector(tank.position)+Vector3(0,0,3);standing.y=field.height(standing.x,standing.z)+.1
 world.crew.members[actor].position=FrontierExpeditionBusiness.array(standing);app.actors[actor].position=standing;app.session._publish();app.session._publish_surface();await process_frame
 app.open_station("luminous_vivarium",tank.id);await process_frame
 var controls:=app.business_panel.utility_panel
 check(not controls.install.disabled and controls.sample.item_count==1,"F shows actual carried compatible specimen")
 controls.install.pressed.emit()
 if not await until(func():return not FrontierExpeditionBusiness.site(core.world).buildings[tank.id].get("specimen_stock",{}).is_empty(),"host installs specimen from F",20):quit(1);return
 app.close_menus();world=core.world;site=FrontierExpeditionBusiness.site(world);tank=site.buildings[tank.id]
 for b in site.buildings.values():
  if b.type not in ["shell_refuge","resonance_garden","luminous_vivarium","flood_sentinel"]:b.enabled=false
 site.environment.temperature=20
 FrontierExpeditionIndustry.power(world,site);FrontierDiscoveryUtilities.tick(world,site,1.1);app.session._publish();app.session._publish_surface();await create_timer(.3).timeout
 var tank_view: FrontierDiscoveryUtilityView=app.surface_world.business_view.nodes[tank.id].get_node("DiscoveryUtility")
 check(tank.active and tank_view.lamp.visible and tank_view.lamp.omni_range==10 and FrontierSpecimenItems.validate(world).is_empty(),"real sample and power produce 10m lamp without duplication")
 app.camera.position=FrontierCrewWorld.vector(tank.position)+Vector3(3,2.6,-4);app.camera.look_at(FrontierCrewWorld.vector(tank.position)+Vector3.UP);await capture("living-tank")
 site.environment.temperature=60;FrontierExpeditionIndustry.power(world,site);FrontierDiscoveryUtilities.tick(world,site,1.1);app.session._publish();app.session._publish_surface();await process_frame
 check(not tank.active and not tank_view.lamp.visible,"temperature failure turns lamp off")
 site.environment.temperature=20
 var alarm: Dictionary=site.buildings[placed.flood_sentinel];var garden: Dictionary=site.buildings[placed.resonance_garden]
 var water_before: Dictionary=world.surface_water.get(world.location,FrontierSurfaceWater.create()).duplicate(true)
 var target: Dictionary=site.buildings[placed.shell_refuge];var p:=FrontierCrewWorld.vector(target.position)+Vector3.UP*.1
 world.surface_water[world.location]=FrontierSurfaceWater.create();world.surface_water[world.location].cells[FrontierSurfaceWater.key(FrontierSurfaceWater.cell(p))]=[1.,0.]
 FrontierExpeditionIndustry.power(world,site);FrontierDiscoveryUtilities.tick(world,site,1.1)
 standing=FrontierCrewWorld.vector(alarm.position)+Vector3(0,0,3);world.crew.members[actor].position=FrontierExpeditionBusiness.array(standing);app.actors[actor].position=standing;app.session._publish();app.session._publish_surface();await create_timer(.15).timeout
 var alarm_view: FrontierDiscoveryUtilityView=app.surface_world.business_view.nodes[alarm.id].get_node("DiscoveryUtility")
 check(alarm.active and not alarm.get("alarm_target","").is_empty() and alarm_view.speaker.playing,"actual water cell triggers nearby facility alarm sound")
 app.open_station("flood_sentinel",alarm.id);await process_frame;controls.mute.pressed.emit()
 if not await until(func():return FrontierExpeditionBusiness.site(core.world).buildings[alarm.id].get("muted",false),"F mutes alarm",20):quit(1);return
 app.close_menus();await process_frame;check(not alarm_view.speaker.playing,"muted alarm keeps water detection but silences speaker")
 world=core.world;site=FrontierExpeditionBusiness.site(world);alarm=site.buildings[alarm.id];garden=site.buildings[garden.id]
 world.surface_water[world.location]=water_before;FrontierDiscoveryUtilities.tick(world,site,1.1)
 check(alarm.alarm_target.is_empty(),"alarm clears when foundation dries")
 standing=FrontierCrewWorld.vector(garden.position)+Vector3(0,0,3);world.crew.members[actor].position=FrontierExpeditionBusiness.array(standing);app.actors[actor].position=standing
 FrontierExpeditionIndustry.power(world,site);FrontierDiscoveryUtilities.tick(world,site,1.1);app.session._publish();app.session._publish_surface();await create_timer(.3).timeout
 var garden_view: FrontierDiscoveryUtilityView=app.surface_world.business_view.nodes[garden.id].get_node("DiscoveryUtility")
 check(garden_view.speaker.playing and garden_view.speaker.max_distance==16,"proximity resonance plays existing authored audio")
 app.open_station("resonance_garden",garden.id);await create_timer(.3).timeout;check(not garden_view.speaker.playing,"menu blocks proximity audio")
 controls.tone.pressed.emit()
 if not await until(func():return FrontierExpeditionBusiness.site(core.world).buildings[garden.id].get("resonance_tone",1)==2,"F changes resonance pitch",20):quit(1);return
 app.close_menus();await create_timer(.3).timeout;check(is_equal_approx(garden_view.speaker.pitch_scale,1.18),"speaker follows accepted pitch")
 var shell_id: String=placed.shell_refuge;var shell_node: Node3D=app.surface_world.business_view.nodes[shell_id]
 var query:=PhysicsRayQueryParameters3D.create(shell_node.to_global(Vector3(0,1.2,-3)),shell_node.to_global(Vector3(0,1.2,3)));query.collision_mask=1
 var hit:=app.surface_world.get_world_3d().direct_space_state.intersect_ray(query)
 check(hit.is_empty() or hit.collider!=shell_node,"shell center is a walkable opening")
 check(await app.session.close_session(),"new utility state saves")
 var loaded:=FrontierWorldStore.new(folder+"/world.json").read_state()
 check(not loaded.is_empty() and not FrontierExpeditionBusiness.site(loaded).buildings[placed.luminous_vivarium].specimen_stock.is_empty() and FrontierSpecimenItems.validate(loaded).is_empty(),"installed specimen and licenses survive reload")
 app.queue_free();await process_frame;print("UTILITY_PLAY checks ",checks," failures ",failures);quit(1 if failures else 0)
