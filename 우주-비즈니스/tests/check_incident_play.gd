extends "res://tests/check_lotus_play.gd"
var incident_actor: String
var fixtures: Dictionary
func run() -> void:
 folder="/tmp/incident-play"
 if "--crew-folder=/tmp/incident-play" not in OS.get_cmdline_user_args():quit(1);return
 DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,800);root.content_scale_size=root.size
 fixtures=JSON.parse_string(FileAccess.get_file_as_string("/tmp/exploration-incident-play/fixture.json"))
 var owner:=FrontierPlayerProfile.new_character("현장 사건 검수",2);incident_actor=owner.character_id
 var core:=FrontierCrewAuthority.new();check(core.start(FrontierUniverse.new_world(71491),owner,func(_w):return true),"start")
 var world: Dictionary=core.world;var destination:=8 if "--t1-only" in OS.get_cmdline_user_args() or "--t1-wreck-only" in OS.get_cmdline_user_args() else 11;var planet:=FrontierUniverse.body(world.manifest,destination)
 world.location=planet.id;world.navigation_target=planet.id;world.crew.navigation.system=planet.system_ordinal;world.crew.navigation.target=destination
 world.crew.navigation.position=FrontierExplorationIncidents.array(FrontierCrewNavigation.center(destination,world.manifest,float(world.crew.navigation.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(planet)+1))
 world.crew.members[incident_actor].ready=true
 check(FrontierCrewSurface.apply(world,incident_actor,"land",{},{1:incident_actor}).is_empty(),"land fixture")
 world.business.bags[incident_actor]=FrontierExpeditionBusiness.inventory();world.business.bags[incident_actor].copper=12
 var loadout: Dictionary=world.crew.members[incident_actor].loadout
 for pair in [["terrain_1",1],["pulse_2",2],["miner_2",3]]:loadout.items["fixture:"+pair[0]]=pair[0];loadout.slots[pair[1]]="fixture:"+pair[0]
 for template in fixtures.rows:
  if fixtures.ordinals[template]!=destination:continue
  var row: Dictionary=fixtures.rows[template];world.incidents.records[FrontierExplorationIncidents.key(row)]=FrontierExplorationIncidents.create(row)
 var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(world),"isolated save "+store.last_error)
 var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"Forward+ landed",80):quit(1);return
 app.session.response_received.connect(func(_seq,result):
  if not result.get("ok",false):print("INCIDENT_RESPONSE_ERROR ",result))
 app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
 var actor: CharacterBody3D=app.actors[incident_actor]
 app.session.authority.world.business.bags[incident_actor].copper=12
 var row: Dictionary
 var id: String
 if "--t1-only" in OS.get_cmdline_user_args() or "--t1-wreck-only" in OS.get_cmdline_user_args():
  if "--t1-wreck-only" not in OS.get_cmdline_user_args():
   row=fixtures.rows.scavenger_cache;id=FrontierExplorationIncidents.key(row)
   if not await visit(row,FrontierCrewWorld.vector(row.position)+Vector3(0,0,8),FrontierCrewWorld.vector(row.position)):quit(1);return
   check(app.surface_world.incidents.models[id].has("creature"),"existing native creature rig present")
   await capture("scavenger-trail");await action(row,"cargo",false,1)
   row=fixtures.rows.cliff_cargo;id=FrontierExplorationIncidents.key(row)
   if not await visit(row,FrontierCrewWorld.vector(row.position)+Vector3(8,0,10),FrontierCrewWorld.vector(row.position)+Vector3.UP*4):quit(1);return
   await capture("cliff-route");await action(row,"cargo",false,1,true)
   check(FrontierExplorationIncidents.carriers(app.session.authority.world,incident_actor),"cliff physical carry")
   await action(row,"delivery",false,1)
   check(app.session.authority.world.incidents.records[id].claimed,"cliff return delivery")
  app.session.authority.world.business.bags[incident_actor]=FrontierExpeditionBusiness.inventory()
  row=fixtures.rows.wreck_beacon_trail;id=FrontierExplorationIncidents.key(row)
  for i in 3:await action(row,"hatch",true,1)
  await action(row,"cargo",false,1)
  check(app.session.authority.world.incidents.records[id].claimed,"T1 wreck grants usable tool")
  app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(4);app.survey_journal.refresh();root.size=Vector2i(960,640);root.content_scale_size=root.size
  await capture("incident-journal-960")
  check(not app.survey_journal.selected_entry.is_empty() and app.survey_journal.selected_entry.kind=="incident","incident journal model and record")
  await finish("T1");return
 if "--extras-only" in OS.get_cmdline_user_args() or "--drone-only" in OS.get_cmdline_user_args():
  if "--drone-only" not in OS.get_cmdline_user_args():
   row=fixtures.rows.icebound_cargo;id=FrontierExplorationIncidents.key(row)
   for i in 4:await action(row,"ice",true,1)
   await action(row,"cargo",false,1);await capture("ice-open")
   check(app.session.authority.world.incidents.records[id].claimed,"ice barrier and physical cargo")
  row=fixtures.rows.roaming_cargo_drone;id=FrontierExplorationIncidents.key(row)
  for i in 3:await action(row,"drone",true,2)
  await action(row,"cargo",false,2);await capture("drone-carried")
  check(FrontierExplorationIncidents.carriers(app.session.authority.world,incident_actor),"drone cargo held")
  var event:=InputEventKey.new();event.pressed=true;event.physical_keycode=KEY_X;app.surface_world.incidents._unhandled_input(event);await create_timer(.3).timeout
  check(not FrontierExplorationIncidents.carriers(app.session.authority.world,incident_actor),"X drops actual cargo")
  await action(row,"cargo",false,2);await action(row,"delivery",false,2)
  check(app.session.authority.world.incidents.records[id].claimed,"drone delivery")
  await finish("T2_EXTRAS");return
 if "--seismic-only" not in OS.get_cmdline_user_args():
  row=fixtures.rows.buried_power_chain
  if not await visit(row,FrontierExplorationIncidents.point(row,Vector3(0,0,9)),FrontierExplorationIncidents.point(row,Vector3(0,1.6,2.4))):quit(1);return
  await capture("wreck-sealed")
  # Work through the same view target and host request used by F and tool fire.
  await action(row,"repair",false,1);await action(row,"battery",false,1)
  check(FrontierExplorationIncidents.carriers(app.session.authority.world,incident_actor),"battery carried by actual actor")
  await capture("battery-carried")
  await action(row,"socket",false,1)
  for i in 3:await action(row,"hatch",true,1)
  id=FrontierExplorationIncidents.key(row)
  check(app.session.authority.world.incidents.records[id].open,"real tool opens hatch")
  await capture("wreck-open")
  await action(row,"cargo",false,1)
  check(app.session.authority.world.incidents.records[id].claimed,"physical cargo claimed")
  row=fixtures.rows.illuti_dormant_combat_robot
  if not await visit(row,FrontierExplorationIncidents.point(row,Vector3(0,0,10)),FrontierExplorationIncidents.point(row,Vector3(0,1.5,0))):quit(1);return
  id=FrontierExplorationIncidents.key(row)
  await until(func():return app.session.authority.world.incidents.records[id].phase=="aiming","robot visibly telegraphs",15)
  await capture("illuti-aim")
  var robot_before: float=app.session.authority.world.crew.members[incident_actor].vitals.health
  await create_timer(2.8).timeout
  check(app.session.authority.world.crew.members[incident_actor].vitals.health<robot_before,"telegraphed shot hits health")
  for i in 12:
   if app.session.authority.world.incidents.records[id].hp<=0:break
   await action(row,"robot",true,2)
  await action(row,"cargo",false,2);await capture("illuti-salvage")
 row=fixtures.rows.seismic_gem_chamber
 var entrance:=FrontierCrewWorld.vector(row.relay)
 if not await visit(row,entrance,entrance+Vector3.DOWN,true):quit(1);return
 id=FrontierExplorationIncidents.key(row)
 await until(func():return app.session.authority.world.incidents.records[id].open,"earthquake opens real terrain",12)
 await until(func():return app.surface_world.incoming.size()>0,"carved passage reaches renderer",12)
 var chamber:=FrontierCrewWorld.vector(row.position)
 # Stand on the newly created cave floor, not on the surface above it.
 actor.position=chamber+Vector3(0,-7,3);app.session.authority.update_position(1,actor.position)
 var target:=FrontierExplorationIncidents.point(row,Vector3(0,-7.2,-1));var d:=target-actor.position-Vector3.UP*1.72
 app.yaw=atan2(-d.x,-d.z);app.pitch=atan2(d.y,Vector2(d.x,d.z).length())
 await until(func():return app.surface_world.ready_at(actor.position),"new cave collision ready",40)
 await capture("seismic-chamber")
 app.session.authority.world.business.bags[incident_actor]=FrontierExpeditionBusiness.inventory()
 await action(row,"gems",true,3,true)
 check(int(app.session.latest.inventory.get("sapphire",0))>=1,"Mk2 physically mines sapphire")
 var incident_view:=app.surface_world.incidents
 for sound in ["sfx_incident_quake","sfx_incident_robot_wake","sfx_incident_beacon"]:check(incident_view.audio.stream(sound)!=null,"ElevenLabs "+sound)
 app.open_menu(app.navigation_ui.pause_frame);await process_frame;check(incident_view.blocked(),"menu blocks event interaction");app.close_menus()
 check(await app.session.close_session(),"save incident progress")
 app.queue_free();await process_frame;await process_frame
 print("INCIDENT_PLAY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
func visit(row: Dictionary,p: Vector3,target: Vector3,underground: bool=false) -> bool:
 var actor: CharacterBody3D=app.actors[incident_actor]
 if underground:
  actor.position=p;app.session.authority.update_position(1,p);var d:=target-p-Vector3.UP*1.72;app.yaw=atan2(-d.x,-d.z);app.pitch=atan2(d.y,Vector2(d.x,d.z).length())
 else:look(actor,p,target)
 actor.velocity=Vector3.ZERO
 app.session.authority.motions[incident_actor]=FrontierCrewLocomotion.create()
 var id:=FrontierExplorationIncidents.key(row)
 return await until(func():return app.surface_world.ready_at(actor.position) and app.surface_world.incidents.models.has(id),"stream incident "+row.template,55)
func action(source: Dictionary,part: String,use_tool: bool,slot: int,underground: bool=false) -> void:
 var id:=FrontierExplorationIncidents.key(source);var row: Dictionary=app.session.authority.world.incidents.records[id];var at:=Vector3.ZERO
 for t in FrontierExplorationIncidents.targets(row):
  if t.part==part:at=t.point;break
 if at==Vector3.ZERO:check(false,"missing scene part "+part);return
 var p:=at+Vector3(0,0,2.4).rotated(Vector3.UP,float(row.yaw));p.y=at.y-.6
 if part=="hatch":p=FrontierExplorationIncidents.point(row,Vector3(0,0,5.4))
 if not await visit(source,p,at,underground):return
 app.session.send_request("equipment_select",{"slot":slot});await create_timer(.55).timeout
 var view:=app.surface_world.incidents
 if part=="drone":
  for attempt in 8:
   var live: Dictionary=app.session.authority.world.incidents.records[id];var moving:=FrontierExplorationIncidents.moving_point(live)
   var observer:=moving+Vector3(sin(attempt*TAU/8)*4.2,0,cos(attempt*TAU/8)*4.2)
   look(app.actors[incident_actor],observer,moving);app.actors[incident_actor].velocity=Vector3.ZERO
   await create_timer(.12).timeout
   if view.selected.get("part")=="drone":break
 check(view.selected.get("part")==part,"view aims "+part+": "+str(view.selected))
 if use_tool:app.use_equipped()
 else:view.interact()
 await create_timer(.65).timeout

func finish(label: String) -> void:
 check(await app.session.close_session(),"save "+label);app.queue_free();await process_frame;await process_frame
 print("INCIDENT_"+label+"_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
