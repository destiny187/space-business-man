extends "res://tests/check_incident_play.gd"
func run() -> void:
 folder="/tmp/native-event-play"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder=/tmp/native-event-play" not in OS.get_cmdline_user_args():quit(2);return
 var kind: String="scavenger"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--role="):kind=arg.trim_prefix("--role=")
 var fixtures: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("/tmp/native-incidents/play.json"))
 if not fixtures.has(kind):quit(2);return
 var source: Dictionary=fixtures[kind].row;var body: Dictionary=fixtures[kind].body;var f:=FrontierExplorationIncidents.field(body)
 var owner:=FrontierPlayerProfile.new_character("현지 생물 확인",0);incident_actor=owner.character_id
 var core:=FrontierCrewAuthority.new();check(core.start(FrontierUniverse.new_world(71491),owner,func(_w):return true),"host start")
 var world: Dictionary=core.world;world.crew.phase="playing"
 body=FrontierUniverse.body(world.manifest,int(body.ordinal))
 world.location=body.id;world.navigation_target=body.id;world.crew.navigation.system=body.system_ordinal;world.crew.navigation.target=body.ordinal
 world.crew.navigation.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(int(body.ordinal),world.manifest,float(world.crew.navigation.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(body)+1))
 world.crew.members[incident_actor].ready=true
 check(FrontierCrewSurface.apply(world,incident_actor,"land",{},{1:incident_actor}).is_empty(),"natural native planet landing")
 var row:=FrontierExplorationIncidents.create(source);var id:=FrontierExplorationIncidents.key(row)
 var at:=FrontierNativeIncidents.position(row);var is_cave: bool=kind=="cave";var p:=at+Vector3(maxf(8,FrontierNativeIncidents.radius(row.native)+6),0,0)
 if is_cave:p=at+Vector3(0,0,2.5)
 else:
  var closest:=INF
  for i in 16:
   var candidate:=at+Vector3.RIGHT.rotated(Vector3.UP,float(i)*TAU/16)*maxf(8,FrontierNativeIncidents.radius(row.native)+3)
   candidate.y=f.height(candidate.x,candidate.z)
   var slope:=absf(candidate.y-at.y)
   if slope<closest:p=candidate;closest=slope
 world.crew.members[incident_actor].position=FrontierExplorationIncidents.array(p+Vector3.UP*.3)
 world.incidents.records[id]=row
 world.business.bags[incident_actor]=FrontierExpeditionBusiness.inventory()
 DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,800);root.content_scale_size=root.size
 var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(world),"native fixture saved "+store.last_error)
 var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 app.session.response_received.connect(func(_seq,result):
  if not result.get("ok",false):print("NATIVE_RESPONSE_ERROR ",result))
 app.session.authority.save_world=func(draft):
  var saved:=app.session.store.write(draft)
  if not saved:
   print("NATIVE_SAVE_ERROR ",app.session.store.last_error)
   for event in draft.incidents.records.values():
    if not FrontierNativeIncidents.validate(draft,event):print("NATIVE_INVALID ",event," expected ",FrontierNativeIncidents.choose(FrontierUniverse.body_from_id(draft.manifest,event.body_id),event))
  return saved
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"native Forward+ ready",100):quit(1);return
 app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
 if not await visit(source,p,at+Vector3.UP*float(row.native.height)*.5,is_cave):quit(1);return
 var nodes: Dictionary=app.surface_world.incidents.models[id]
 check(nodes.has("creature") and nodes.has("native_solid"),"real native model and collider")
 check(nodes.creature.definition.id==row.native.form_id,"actual local species model")
 if kind=="guardian":check(nodes.young.size()==2,"same-species young at nest")
 print("NATIVE_VISUAL ",row.native," position ",nodes.creature.global_position," scale ",nodes.creature.global_basis.get_scale()," model ",nodes.creature.models[0].transform)
 await capture(kind+"-encounter")
 app.test_scan=true
 var deadline:=Time.get_ticks_msec()+28000
 while Time.get_ticks_msec()<deadline and not app.session.authority.world.incidents.records[id].native_observed:
  var live: Dictionary=app.session.authority.world.incidents.records[id]
  var target:=FrontierNativeIncidents.position(live)+Vector3.UP*float(live.native.height)*.5
  var actor: CharacterBody3D=app.actors[incident_actor];var aim:=target-actor.position-Vector3.UP*1.72
  app.yaw=atan2(-aim.x,-aim.z);app.pitch=atan2(aim.y,Vector2(aim.x,aim.z).length())
  await create_timer(.1).timeout
 app.test_scan=false
 check(app.session.authority.world.incidents.records[id].native_observed,"held E observes actual native individual")
 if not app.session.authority.world.incidents.records[id].native_observed:
  print("NATIVE_SCAN_DEBUG ",app.session.authority.scans," actor ",app.actors[incident_actor].position," creature ",FrontierNativeIncidents.position(app.session.authority.world.incidents.records[id]));quit(1);return
 if not await until(func():return FrontierNativeIncidents.available(app.session.authority.world.incidents.records[id]),"movement releases field reward",45):quit(1);return
 var cargo:=FrontierExplorationIncidents.cargo_point(row);var approach:=cargo+Vector3(2,0,0);approach.y=float(row.position[1])+.3
 if not await visit(source,approach,cargo,is_cave):quit(1);return
 await create_timer(.3).timeout
 check(app.surface_world.incidents.selected.get("part")=="cargo","real native reward target")
 app.surface_world.incidents.interact();await create_timer(.5).timeout
 if not app.session.latest.incidents.records[id].claimed:
  print("NATIVE_RECOVER_DEBUG ",app.session.authority.world.incidents.records[id]," selected ",app.surface_world.incidents.selected);await capture(kind+"-recover-failed");quit(1);return
 check(app.session.latest.incidents.records[id].claimed,"F recovers observed native reward")
 check(app.session.latest.crew.members[incident_actor].modules.items.has("module:"+id.sha256_text().substr(0,24)),"native event gives owned module")
 await capture(kind+"-recovered")
 app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(4);app.survey_journal.refresh();await create_timer(.5).timeout
 var entry: Dictionary={"kind":"incident","name":FrontierExplorationIncidents.definition(row.template).name,"row":app.session.latest.incidents.records[id],"key":id}
 app.survey_journal.select(entry);await capture(kind+"-journal")
 check(await app.session.close_session(),"native identity/progress save")
 var loaded:=FrontierWorldStore.new(folder+"/world.json");var restored:=loaded.read_state()
 check(not restored.is_empty() and restored.incidents.records[id].native==JSON.parse_string(JSON.stringify(row.native)),"saved native identity reload")
 app.queue_free();await process_frame;await process_frame
 print("NATIVE_PLAY ",kind," CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
