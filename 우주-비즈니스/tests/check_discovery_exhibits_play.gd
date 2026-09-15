extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/discovery-exhibits-play"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder="+folder not in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 var world:=FrontierWorldStore.new("/tmp/discovery-industry-play/world.json").read_state()
 if world.is_empty():quit(2);return
 var actor: String=world.crew.owner_id;var body:=FrontierUniverse.body_from_id(world.manifest,world.location);var field:=FrontierCrewSurface.field(world)
 var poi: Dictionary={};var incident: Dictionary={}
 for row in FrontierExplorationDiscoveries.nearby(body,field,Vector3.ZERO):
  if row.template=="singing_stones":poi=row;break
 if poi.is_empty():
  for row in FrontierExplorationDiscoveries.nearby(body,field,Vector3.ZERO):
   if row.template!="lost_technology_archive":poi=row;break
 for row in FrontierExplorationIncidents.nearby(body,field,Vector3.ZERO):
  if FrontierExplorationIncidents.definition(row.template).mode not in ["native","mission","robot"]:incident=row;break
 if poi.is_empty() or incident.is_empty():check(false,"actual seeded discovery and incident near landing");quit(1);return
 print("EXHIBIT_FIXTURES ",poi.template," ",incident.template)
 FrontierExplorationDiscoveries.scan(world,poi,actor)
 var record:=FrontierExplorationDiscoveries.progress(world,poi);record.stage=FrontierExplorationDiscoveries.definition(poi.template).stages.size();record.scanned_stage=record.stage;record.claimed=true
 var ir:=FrontierExplorationIncidents.create(incident);ir.claimed=true;ir.seen=true;ir.discoverer=actor
 FrontierExplorationIncidents.ensure(world);world.incidents.records[FrontierExplorationIncidents.key(ir)]=ir
 world.business.facility_research=world.business.facility_research.filter(func(key):return not FrontierDiscoveryExhibits.is_exhibit(key))
 world.business.credits=6000;world.business.bags[actor]=FrontierExpeditionBusiness.inventory();world.business.bags[actor].stone=100;world.business.bags[actor].iron=100;world.business.bags[actor].copper=40
 var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(world),"isolated completed source fixture saves: "+store.last_error)
 DirAccess.copy_absolute("/tmp/discovery-industry-play/profile.json",folder+"/profile.json")
 root.size=Vector2i(960,640);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"actual exhibit expedition ready",90):quit(1);return
 app.onboarding.letter.hide();app.onboarding.set_process(false);app.onboarding.hide();app.close_menus();app.set_physics_process(false);app.set_process(false)
 root.size=Vector2i(960,640);root.content_scale_size=root.size
 var core:=app.session.authority;world=core.world;field=app.surface_world.terrain.field
 # Resume chooses the personal bag; prepare exactly the temporary fixture's materials again.
 world.business.bags[actor]=FrontierExpeditionBusiness.inventory();world.business.bags[actor].stone=100;world.business.bags[actor].iron=100;world.business.bags[actor].copper=40
 var standing:=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)+Vector3(3,0,3);standing.y=field.height(standing.x,standing.z)+.1
 world.crew.members[actor].position=FrontierExpeditionBusiness.array(standing);app.actors[actor].position=standing;app.session._publish();await process_frame
 app.open_station("ship");app.business_panel.vessel_terminal.cards.research.pressed.emit();await process_frame
 var research: FrontierFacilityResearchPanel=app.stations.research_tabs.get_child(1);research.category.select(1);research.signature="";research.refresh()
 var kinds: Array=["exhibit_"+poi.template,"exhibit_"+incident.template]
 for kind in kinds:
  research.selected=kind;research.signature="";research.refresh();await process_frame
  await until(func():return research.cards[kind].is_visible_in_tree() and not research.action.disabled,"real research card uses "+kind+" completion evidence",5)
  check(research.action.get_global_rect().end.y<=640,"research action fits small window")
  await capture("research-"+kind)
  research.action.pressed.emit()
  if not await until(func():return FrontierFacilityResearch.owned(core.world.business,kind),"paid research "+kind,20):quit(1);return
 app.close_menus()
 var placed: Array=[]
 for kind in kinds:
  world=core.world;var def:=FrontierFacilityResearch.construction(kind);var at:=Vector3.INF
  for x in range(16,65,4):
   if at.is_finite():break
   for z in range(16,65,4):
    var p:=FrontierExpeditionBusiness.ground(field,x,z,float(def.radius))
    if not p.is_finite():continue
    standing=p+Vector3(0,0,6);standing.y=field.height(standing.x,standing.z)+.1;world.crew.members[actor].position=FrontierExpeditionBusiness.array(standing)
    if FrontierExpeditionBusiness.build_reason(world,actor,kind,p,{1:actor}).is_empty():at=p;break
  if not at.is_finite():check(false,"valid exhibition location");quit(1);return
  app.actors[actor].position=standing;app.camera.set_as_top_level(true);app.camera.position=at+Vector3(4,3,-5);app.camera.look_at(at+Vector3.UP)
  app.session._publish();app.open_station("build");app.business_panel.build_category.select(1);app.business_panel.refresh_building_cost();await process_frame
  check(app.business_panel.building_cards[kind].visible and not app.business_panel.building_cards.solar.visible,"B separates discovered decorations from industry")
  await capture("build-"+kind)
  app.business_panel.building_cards[kind].pressed.emit();check(app.placement_kind==kind,"card starts real placement ghost");app.close_menus()
  var count: int=FrontierExpeditionBusiness.site(core.world).buildings.size()
  app.session.send_request("business_build",{"building":kind,"position":FrontierExpeditionBusiness.array(at),"yaw":PI/2})
  if not await until(func():return FrontierExpeditionBusiness.site(core.world).buildings.size()==count+1,"paid placed "+kind,20):quit(1);return
  var id:=""
  for b in FrontierExpeditionBusiness.site(core.world).buildings.values():
   if b.type==kind:id=b.id;break
  placed.append(id)
  await until(func():return app.surface_world.business_view.nodes.has(id),"authored natural exhibit in field",20)
  app.placement_kind="";app.cancel_placement();app.open_station(kind,id);await create_timer(.4).timeout
  check(not app.business_panel.facility_toggle.visible and app.business_panel.facility_status.text.contains("생산이나 능력치 효과는 없습니다"),"F describes static replica without machine controls")
  await capture("inspect-"+kind);app.close_menus();await capture("field-"+kind)
 # Real journal detail widgets include current effect and non-effect descriptions.
 app.toggle_research();app.research_frame.ecology.get_parent().current_tab=1;await process_frame
 var journal: FrontierSurveyJournal=app.survey_journal
 var page:=FrontierDiscoveryIndex.page(core.world,"","discovery","",0)
 var seen:=false
 for entry in page.entries:
  if entry.row.template!="dew_basin":continue
  journal.select(entry);await process_frame
  for label in journal.details.get_children():
   if label is Label and label.text.contains("4kW") and label.text.contains("12초"):seen=true
  await capture("journal-effects");break
 check(seen,"journal shows real condenser power, climate, output and replica distinction")
 app.close_menus()
 check(await app.session.close_session(),"exhibit placements and licenses save")
 var loaded:=FrontierWorldStore.new(folder+"/world.json").read_state();var saved:=not loaded.is_empty()
 for id in placed:saved=saved and FrontierExpeditionBusiness.site(loaded).buildings.has(id)
 for kind in kinds:saved=saved and FrontierFacilityResearch.owned(loaded.business,kind)
 check(saved,"both POI and incident replicas survive reload with shared licenses")
 app.queue_free();await process_frame;print("EXHIBIT_PLAY checks ",checks," failures ",failures);quit(1 if failures else 0)
