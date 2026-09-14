extends "res://tests/check_incident_play.gd"
const Mission=preload("res://scripts/domain/active_missions.gd")
var fixture_data: Dictionary
var live_key: String
func place_at(p: Vector3,target: Vector3) -> void:
 var actor: CharacterBody3D=app.actors[incident_actor];actor.position=p;actor.velocity=Vector3.ZERO;app.session.authority.update_position(1,p)
 var d:=target-p-Vector3.UP*1.72;app.yaw=atan2(-d.x,-d.z);app.pitch=atan2(d.y,Vector2(d.x,d.z).length());app.session.authority.motions[incident_actor]=FrontierCrewLocomotion.create()
func current() -> Dictionary:return app.session.authority.world.incidents.records[live_key]
func use_part(part: String,tool: bool=false) -> bool:
 var target: Dictionary={}
 for t in Mission.targets(current()):
  if t.part==part:target=t;break
 if target.is_empty():check(false,"play target "+part);return false
 var at: Vector3=target.point;place_at(at+Vector3(0,-1.1,1.5),at)
 if tool:
  var slot:=0 if part.begins_with("mine_") else 1
  app.session.authority.resolve_autonomous(true);app.session._publish();app.session.send_request("equipment_select",{"slot":slot});await create_timer(.25).timeout
 else:await create_timer(.15).timeout
 var view:=app.surface_world.incidents
 if view.selected.get("part")!=part:
  print("AIM_DEBUG ",part," got ",view.selected," actor ",app.actors[incident_actor].position," target ",at)
 check(view.selected.get("part")==part,"actual view selects "+part)
 if view.selected.get("part")!=part:return false
 var serial:=int(current().serial)
 if tool:app.use_equipped()
 else:view.interact()
 var done:=await until(func():return int(current().serial)>serial,"host executes "+part,6)
 if tool:await create_timer(.65).timeout
 return done
func run() -> void:
 folder="/tmp/active-missions-play"
 if "--crew-folder=/tmp/active-missions-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 fixture_data=JSON.parse_string(FileAccess.get_file_as_string("/tmp/active-missions/fixtures.json"));incident_actor=fixture_data.owner.character_id
 var world: Dictionary=fixture_data.world;world.incidents.records.clear()
 var first: Dictionary=fixture_data.sources.cliff_relay_run[0];live_key=FrontierExplorationIncidents.key(first);world.incidents.records[live_key]=FrontierExplorationIncidents.create(first)
 var member: Dictionary=world.crew.members[incident_actor];member.position=Mission.arr(Mission.vec(first.position)+Vector3(0,1,6));member.loadout.items["fixture:mine"]="miner_3";member.loadout.items["fixture:terrain"]="terrain_1";member.loadout.items["fixture:gun"]="pulse_2";member.loadout.items["fixture:jet"]="jetpack_2";member.loadout.back_slot="fixture:jet";member.loadout.slots[0]="fixture:mine";member.loadout.slots[1]="fixture:terrain";member.loadout.slots[2]="fixture:gun";member.loadout.selected=0
 world.business.bags[incident_actor]=FrontierExpeditionBusiness.inventory()
 var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(world),"play fixture saved "+store.last_error)
 var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":fixture_data.owner,"sessions":{}};profile.save()
 if failures:quit(1);return
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"actual Forward+ expedition loaded",100):quit(1);return
 app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
 app.session.response_received.connect(func(_seq,result):
  if not result.get("ok",false):print("MISSION_RESPONSE ",result))
 var recorder:=AudioEffectRecord.new();var bus:=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,recorder);recorder.set_recording_active(true)
 for template in fixture_data.sources:
  if "--vehicles-only" in OS.get_cmdline_user_args() and template not in ["runaway_convoy_intercept","stranded_survey_rover"]:continue
  if "--cliff-material" in OS.get_cmdline_user_args() and template!="cliff_relay_run":continue
  if "--review-only" in OS.get_cmdline_user_args() and template not in ["cliff_relay_run","freighter_rescue_chain"]:continue
  app.session.authority.resolve_autonomous(true)
  var sources: Array=fixture_data.sources[template];var source: Dictionary=sources[0];live_key=FrontierExplorationIncidents.key(source)
  app.session.authority.world.incidents.records.clear()
  for r in sources:app.session.authority.world.incidents.records[FrontierExplorationIncidents.key(r)]=FrontierExplorationIncidents.create(r)
  var m: Dictionary=app.session.authority.world.crew.members[incident_actor];m.vitals.protection=10000
  app.session.authority.world.business.bags[incident_actor]=FrontierExpeditionBusiness.inventory()
  for ammo in FrontierFirearms.config().ammunition:app.session.authority.world.business.bags[incident_actor][ammo]=200
  app.session._publish()
  var center:=Mission.vec(source.position)
  place_at(center+Vector3(12,2,26),center+Vector3.UP*4)
  if not await until(func():return app.surface_world.ready_at(app.actors[incident_actor].position) and app.surface_world.incidents.models.has(live_key),"mission model ready "+template,60):continue
  if template=="cliff_relay_run":place_at(center+Vector3(40,2,50),center+Vector3(7,13,7));await create_timer(.3).timeout
  await capture(template+"-start")
  if "--review-only" in OS.get_cmdline_user_args():
   if template=="freighter_rescue_chain":
    await use_part("crate_0");app.surface_world.incidents.surface.session.send_request("surface_incident",app.surface_world.incidents.action_args(live_key,"drop"));await create_timer(.4).timeout
    check(current().carrier=="" and not current().cargo_ground.is_empty(),"actual host drops cargo")
    var n:Dictionary=app.surface_world.incidents.models[live_key]
    check(n.cargo.visible and not n.units[0].visible,"dropped cargo has one visible instance")
    await capture("rescue-dropped-cargo");await use_part("crate_0");await use_part("delivery")
   continue
  if template=="cliff_relay_run":
   for i in 3:
    for j in 8:
     if int(current().mission.steps[i])>0:break
     if not await use_part("rotate_"+str(i)):break
   await capture("relay-linked")
   await use_part("finish")
  elif template=="runaway_convoy_intercept":
   await use_part("barrier")
   var before: Array=current().mission.moving.duplicate();await create_timer(.4).timeout;check(current().mission.moving!=before,"moving vehicle interpolates")
   # Real finite-speed weapon input, tracking the exposed side drive.
   app.session.authority.resolve_autonomous(true);app.session._publish();app.session.send_request("equipment_select",{"slot":2});await create_timer(.3).timeout
   for shot in 28:
    if current().open:break
    var drive:=Mission.vec(current().mission.moving)+Vector3(1.25,.75,0).rotated(Vector3.UP,float(current().mission.moving_yaw))
    place_at(drive+Vector3(6,1,2),drive);await create_timer(.07).timeout;app.firearm.shoot();await create_timer(.25).timeout
   check(current().open,"actual firearm stops moving drive")
   if current().open:await use_part("cargo");await capture("convoy-carried");await use_part("delivery")
  elif template=="coopertech_relay_raid":
   for i in current().mission.steps.size():await use_part("power_"+str(i))
   await capture("vault-open");await use_part("cargo");await use_part("delivery")
  elif template=="vent_field_extraction":
   await create_timer(2).timeout;await capture("vents-warning")
   for i in current().mission.steps.size():await use_part("mine_"+str(i),true)
   await use_part("finish")
  elif template=="aerial_sensor_recovery":
   var anchor:=Mission.vec(current().mission.anchors[0]);place_at(center+Vector3(12,1,8),anchor)
   await until(func():return float(current().mission.observed)>=float(Mission.rules(current()).observe_seconds),"observe native airborne rig",15)
   await until(func():return Mission.bird_away(current()),"native flier leaves landing perch",20)
   await capture("sensor-flight");await use_part("cargo");await use_part("delivery")
  elif template=="stranded_survey_rover":
   for i in current().mission.steps.size():
    for j in int(Mission.rules(current()).blocker_hits):await use_part("clear_"+str(i),true)
   await use_part("battery");await capture("rover-battery");await use_part("socket");await use_part("rover_toggle")
   var end:=Time.get_ticks_msec()+45000
   while not current().open and Time.get_ticks_msec()<end:
    var p:=Mission.vec(current().mission.moving);place_at(p+Vector3(5,0,5),p+Vector3.UP);await create_timer(.25).timeout
   check(current().open,"escort repaired rover through physical cleared route");await capture("rover-arrived")
   if current().open:await use_part("finish")
  elif template=="freighter_rescue_chain":
   for i in current().mission.steps.size():await use_part("crate_"+str(i));await use_part("delivery")
   await use_part("finish")
  check(current().claimed,"campaign completed "+template)
  if failures>8:break
 app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(4);app.survey_journal.refresh();root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("mission-journal-960");app.close_menus()
 recorder.set_recording_active(false);recorder.get_recording().save_to_wav(folder+"/mission-runtime.wav");AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
 check(await app.session.close_session(),"actual mission save closes")
 check(not store.read_state().is_empty(),"mission session reloads")
 app.queue_free();await process_frame;print("ACTIVE_MISSION_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)
