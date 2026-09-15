extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/discovery-industry-play"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder="+folder not in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 var owner:=FrontierPlayerProfile.new_character("발견 산업 확인",0)
 var core:=FrontierCrewAuthority.new()
 check(core.start(FrontierUniverse.new_world(71503),owner,func(_world):return true),"isolated discovery expedition")
 var world: Dictionary=core.world;var body: Dictionary={}
 for ordinal in range(8,2500):
  var candidate:=FrontierUniverse.body(world.manifest,ordinal)
  if not FrontierUniverse.landable(candidate) or int(candidate.planet_tier)!=2:continue
  var climate:=FrontierEcology.profile(candidate)
  if float(climate.moisture)>=.18 and float(candidate.traits.temperature)>35 and float(candidate.traits.temperature)<=55 and FrontierExplorationDiscoveries.eligible(candidate,FrontierExplorationDiscoveries.definition("thermal_chimneys")):
   body=candidate;break
 if body.is_empty():check(false,"warm humid T2 fixture");quit(1);return
 print("DISCOVERY_FIXTURE ",body.id," ",FrontierEcology.profile(body))
 var actor: String=owner.character_id;var nav: Dictionary=world.crew.navigation
 nav.system=body.system_ordinal;nav.target=body.ordinal;nav.mode="idle";nav.erase("solar_opening")
 nav.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(body.ordinal,world.manifest,float(nav.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(body)+2))
 world.crew.members[actor].ready=true;core.phase="playing";world.crew.phase="playing"
 check(FrontierCrewSurface.apply(world,actor,"land",{"ordinal":body.ordinal},{1:actor}).is_empty(),"land warm humid world")
 var field:=FrontierCrewSurface.field(world);var discoveries: Dictionary={}
 for row in FrontierExplorationDiscoveries.nearby(body,field,Vector3.ZERO):
  if row.template in ["dew_basin","thermal_chimneys"]:discoveries[row.template]=row
 if discoveries.size()!=2:check(false,"both actual seeded POI templates nearby");quit(1);return
 # Existing multi-stage excavation/observation was tested separately; fixture completes its original record.
 for row in discoveries.values():
  FrontierExplorationDiscoveries.scan(world,row,actor)
  var record:=FrontierExplorationDiscoveries.progress(world,row)
  record.stage=FrontierExplorationDiscoveries.definition(row.template).stages.size();record.scanned_stage=record.stage;record.claimed=true
 world.business.credits=5000;world.business.bags[actor]=FrontierExpeditionBusiness.inventory();world.business.bags[actor].iron=150;world.business.bags[actor].copper=100
 var store:=FrontierWorldStore.new(folder+"/world.json")
 check(store.write(world),"valid fixture persists: "+store.last_error)
 var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
 root.size=Vector2i(960,640);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"actual world ready",90):quit(1);return
 app.onboarding.letter.hide();app.onboarding.set_process(false);app.onboarding.hide();app.close_menus();app.set_physics_process(false);app.set_process(false)
 core=app.session.authority;world=core.world;field=app.surface_world.terrain.field
 root.size=Vector2i(960,640);root.content_scale_size=root.size
 world.business.bags[actor]=FrontierExpeditionBusiness.inventory();world.business.bags[actor].iron=80;world.business.bags[actor].copper=50
 var standing:=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)+Vector3(3,0,3);standing.y=field.height(standing.x,standing.z)+.1
 world.crew.members[actor].position=FrontierExpeditionBusiness.array(standing);app.actors[actor].position=standing
 app.session._publish();await process_frame
 app.open_station("ship");app.business_panel.vessel_terminal.cards.research.pressed.emit();await process_frame
 var research: FrontierFacilityResearchPanel=app.stations.research_tabs.get_child(1)
 for key in ["dew_condenser","geothermal_generator"]:
  research.selected=key;research.signature="";research.refresh();await process_frame
  check(not research.action.disabled,"discovery proof enables "+key)
  await capture("research-"+key)
  check(research.action.get_global_rect().end.y<=640,"research action fits 960 window")
  research.action.pressed.emit()
  if not await until(func():return FrontierFacilityResearch.owned(core.world.business,key),"research transaction "+key,20):quit(1);return
 app.close_menus()
 var anchor:=FrontierCrewWorld.vector(discoveries.thermal_chimneys.position)
 var district:="";var ids: Dictionary={}
 for kind in ["storage","geothermal_generator","dew_condenser"]:
  world=core.world
  var def:=FrontierFacilityResearch.construction(kind)
  for resource in def.cost:world.business.bags[actor][resource]=int(world.business.bags[actor].get(resource,0))+int(def.cost[resource])
  var at:=Vector3.INF
  for dx in range(-24,25,4):
   if at.is_finite():break
   for dz in range(-24,25,4):
    var p:=FrontierExpeditionBusiness.ground(field,anchor.x+dx,anchor.z+dz,float(def.radius))
    if not p.is_finite():continue
    var region:=FrontierRegionalTerraform.region_id(FrontierExpeditionBusiness.site(world),p)
    if not district.is_empty() and region!=district:continue
    standing=p+Vector3(0,0,6);standing.y=field.height(standing.x,standing.z)+.1
    world.crew.members[actor].position=FrontierExpeditionBusiness.array(standing)
    if FrontierExpeditionBusiness.build_reason(world,actor,kind,p,{1:actor}).is_empty():at=p;district=region;break
  if not at.is_finite():check(false,"valid nearby placement "+kind);quit(1);return
  app.actors[actor].position=standing;app.camera.set_as_top_level(true);app.camera.position=at+Vector3(5,4,-7);app.camera.look_at(at+Vector3.UP*1.3)
  app.session._publish()
  await until(func():return app.surface_world.ready_at(at),"streamed target ground",30)
  app.toggle_business();app.business_panel.refresh_building_cost();await process_frame
  check(app.business_panel.building_cards[kind].visible,"unlocked construction card "+kind)
  await capture("build-"+kind);app.close_menus()
  var count: int=FrontierExpeditionBusiness.site(core.world).buildings.size()
  app.session.send_request("business_build",{"building":kind,"position":FrontierExpeditionBusiness.array(at),"yaw":0.0})
  if not await until(func():return FrontierExpeditionBusiness.site(core.world).buildings.size()>count,"host constructs "+kind,20):quit(1);return
  var site:=FrontierExpeditionBusiness.site(core.world)
  for id in site.buildings:
   if site.buildings[id].type==kind:ids[kind]=id
  await until(func():return app.surface_world.business_view.nodes.has(ids[kind]),"field model "+kind,20)
  await create_timer(2.).timeout;await capture("placed-"+kind)
 var site:=FrontierExpeditionBusiness.site(core.world)
 check(await until(func():return FrontierExpeditionBusiness.site(core.world).buildings[ids.dew_condenser].get("working",false),"real climate and power start condenser",20),"environment-driven activation")
 check(await until(func():return int(FrontierExpeditionBusiness.site(core.world).regions[district].inventory.ice)>0,"condensed ice reaches district warehouse",25),"actual output")
 var node: Node3D=app.surface_world.business_view.nodes[ids.dew_condenser]
 var fan: Node3D=node.find_child("Anim_Fan_Condenser",true,false);var pose:=fan.transform
 await create_timer(.4).timeout;check(fan.transform!=pose,"condenser fan responds to host working state")
 await capture("working-condenser")
 app.open_station("dew_condenser",ids.dew_condenser);await create_timer(.3).timeout
 var production:=app.business_panel.production_panel
 check(production.upgrade.text=="설비 강화" and not production.description.text.contains("Mk."),"facility F panel uses enhancement language")
 for resource in FrontierDiscoveryIndustry.config().upgrades.dew_condenser.cost:FrontierExpeditionBusiness.site(core.world).regions[district].inventory[resource]=FrontierDiscoveryIndustry.config().upgrades.dew_condenser.cost[resource]
 app.session._publish();production.refresh();await process_frame
 if not await until(func():return not production.upgrade.disabled,"visible enhancement uses facility district stock",10):quit(1);return
 check(production.upgrade.is_visible_in_tree() and production.upgrade.get_global_rect().end.y<=640,"enhancement action remains outside scroll")
 await capture("enhancement")
 production.upgrade.pressed.emit()
 if not await until(func():return int(FrontierExpeditionBusiness.site(core.world).buildings[ids.dew_condenser].tier)==2,"one paid enhancement",20):quit(1);return
 await until(func():return production.upgrade.text=="강화 완료","no third upgrade offered",5)
 app.close_menus();await create_timer(.5).timeout;await capture("enhanced-condenser")
 check(await app.session.close_session(),"new designs and production save")
 var loaded:=store.read_state()
 check(not loaded.is_empty() and FrontierFacilityResearch.owned(loaded.business,"dew_condenser") and int(FrontierExpeditionBusiness.site(loaded).buildings[ids.dew_condenser].tier)==2,"new licenses and enhanced facility reload")
 app.queue_free();await process_frame;print("DISCOVERY_PLAY checks ",checks," failures ",failures);quit(1 if failures else 0)
