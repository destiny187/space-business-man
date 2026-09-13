extends "res://tests/check_ground_combat.gd"
var squad_sources: Array=[]
func squad_fixture() -> Dictionary:
 var owner:=fixture()
 if owner.is_empty():return {}
 var body:=FrontierUniverse.body_from_id(core.world.manifest,core.world.location);var f:=FrontierCrewSurface.field(core.world)
 for x in range(-3,4):
  for z in range(-3,4):
   var candidates:=FrontierExplorationIncidents.tile(body,f,Vector2i(x,z))
   var grouped: Array=candidates.filter(func(r):return FrontierCooperTechSquads.enabled(r))
   if grouped.any(func(r):return r.robot_role=="bastion") and grouped.any(func(r):return r.robot_role=="raptor"):squad_sources=grouped;break
  if not squad_sources.is_empty():break
 check(squad_sources.size()==3,"natural T3 mixed squad includes both new roles")
 if squad_sources.is_empty():return {}
 core.world.incidents.records.clear()
 for row in squad_sources:core.world.incidents.records[FrontierExplorationIncidents.key(row)]=FrontierExplorationIncidents.create(row)
 source=squad_sources[0];robot_key=FrontierExplorationIncidents.key(source)
 var at:=FrontierCrewWorld.vector(source.home)+Vector3(0,0,53);at.y=f.height(at.x,at.z)+.1;core.world.crew.members[actor_id].position=FrontierExplorationIncidents.array(at)
 return owner
func run() -> void:
 var owner:=squad_fixture()
 if owner.is_empty():quit(1);return
 if "--play" in OS.get_cmdline_user_args():await play_squads(owner);return
 var world: Dictionary=core.world;var f:=FrontierCrewSurface.field(world);var body:=FrontierUniverse.body_from_id(world.manifest,world.location)
 var modes: Dictionary={};var roles: Dictionary={}
 for tier in range(1,6):
  var copy:=body.duplicate(true);copy.planet_tier=tier;var generated: Array=[]
  for x in range(-3,4):
   for z in range(-3,4):
    var rows:=FrontierCooperTechSquads.spawn(copy,f,Vector2i(x,z),[])
    if rows.is_empty():continue
    modes[rows[0].start_mode]=true
    for row in rows:roles[row.robot_role]=true
    if generated.is_empty():generated=rows
  check(not generated.is_empty() and generated.size()==int(FrontierCooperTechSquads.config().tiers[str(tier)].count),"T%d group population"%tier)
  check(generated==FrontierCooperTechSquads.spawn(copy,f,Vector2i(int(str(generated[0].squad_id).split(":")[1]),int(str(generated[0].squad_id).split(":")[2])),[]),"T%d deterministic population and path"%tier)
  var row:=FrontierExplorationIncidents.create(generated[0]);check(FrontierCooperTechSquads.validate(row),"T%d persistent role stats and patrol"%tier)
 check(modes.size()==2 and roles.size()==3,"sleeping and active cases / three chassis")
 var robot: Dictionary=world.incidents.records[robot_key]
 for r in world.incidents.records.values():r.phase="idle";r.alarmed=false
 FrontierCooperTechSquads.alert(world,robot)
 check(world.incidents.records.values().all(func(r):return r.phase=="waking"),"damage wakes only the linked dormant squad")
 var other:=FrontierExplorationIncidents.create(source);other.id+="unrelated";other.squad_id+="unrelated";other.phase="idle";world.incidents.records[FrontierExplorationIncidents.key(other)]=other
 FrontierCooperTechSquads.alert(world,robot);check(other.phase=="idle","unrelated group stays dormant");world.incidents.records.erase(FrontierExplorationIncidents.key(other))
 robot.phase="patrol";var before:=FrontierCrewWorld.vector(robot.position)
 for i in 8:robot.age+=.25;robot.time+=.25;FrontierCooperTechSquads.tick(world,robot,.25,[actor_id],f,Callable())
 check(before.distance_to(FrontierCrewWorld.vector(robot.position))>.5,"awake patrol actually moves on terrain")
 var after: Array=robot.position.duplicate();check(not FrontierCooperTechSquads.move(world,robot,f,FrontierCrewWorld.vector(robot.path[robot.patrol_index]),.25,actor_id,func(_a,_o,_d,_r):return 0.0) and after==robot.position,"physical blocker prevents robot travel")
 # Reproduce the former stationary gunfight: aiming and firing must maneuver.
 for candidate in world.incidents.records.values():
  if candidate.robot_role!="raptor":continue
  var member_at:=FrontierCrewWorld.vector(candidate.position)+Vector3(0,0,10)
  member_at.y=f.height(member_at.x,member_at.z)+.1;world.crew.members[actor_id].position=FrontierExplorationIncidents.array(member_at)
  for phase in ["aiming","firing","cooling"]:
   candidate.phase=phase;candidate.time=0;candidate.age=3.0
   var origin: Array=candidate.position.duplicate()
   var changed:=FrontierCooperTechSquads.tick(world,candidate,.25,[actor_id],f,Callable())
   check(origin!=candidate.position and not changed,"maneuver during "+phase+" without extra atomic save")
   origin=candidate.position.duplicate()
   check(not FrontierCooperTechSquads.maneuver(world,candidate,f,actor_id,.25,func(_a,_o,_d,_r):return 0.0) and origin==candidate.position,"combat movement respects physical blockers")
  break
 # Locked mortar target and a delayed impact, with real suit shielding.
 var member: Dictionary=world.crew.members[actor_id];var cfg:=FrontierCooperTechSquads.spec(robot)
 var at:=FrontierCrewWorld.vector(robot.position)+Vector3(0,0,-9);at.y=f.height(at.x,at.z)+.1;member.position=FrontierExplorationIncidents.array(at)
 FrontierCooperTechSquads.aim_at(world,robot,actor_id);var locked: Array=robot.aim.duplicate();member.position[0]+=5;robot.time=cfg.aim_seconds
 FrontierCooperTechSquads.tick(world,robot,.25,[actor_id],f,Callable());check(robot.phase=="projectile" and robot.aim==locked,"mortar locks warning point and has real travel time")
 var vitals: Dictionary=member.vitals.duplicate(true);robot.time=.8;FrontierCooperTechSquads.tick(world,robot,.25,[actor_id],f,Callable());check(member.vitals==vitals,"leaving mortar mark avoids damage")
 member.position=locked.duplicate();robot.phase="cooling";FrontierCooperTechSquads.aim_at(world,robot,actor_id);FrontierCooperTechSquads.shoot(world,robot,f,[actor_id],Callable());check(member.vitals!=vitals,"standing in marked blast damages suit")
 check(FrontierExplorationIncidents.validate(world).is_empty(),"new combat states validate with scaled health and shields: "+FrontierExplorationIncidents.validate(world))
 var store:=FrontierWorldStore.new("/tmp/coopertech-squads-rules/world.json");DirAccess.make_dir_recursive_absolute("/tmp/coopertech-squads-rules")
 check(store.write(world),"atomic save accepts squads: "+store.last_error)
 var loaded:=store.read_state();check(not loaded.is_empty() and loaded.incidents.records[robot_key].position==robot.position and loaded.incidents.records[robot_key].hp==robot.hp,"reload preserves movement and health")
 # Scope: far unrelated incidents remain shared while local simulation gets private rows.
 var far:=FrontierExplorationIncidents.create(source);far.id+="far";far.squad_id+="far";far.position=[7000,0,7000];far.relay=far.position.duplicate();world.incidents.records[FrontierExplorationIncidents.key(far)]=far
 var draft:=preload("res://scripts/persistence/world_draft.gd").incidents(world,[actor_id]);check(is_same(draft.incidents.records[FrontierExplorationIncidents.key(far)],far) and not is_same(draft.incidents.records[robot_key],robot),"one local tick copies nearby incidents only")
 print("COOPERTECH_RULES ",checks," FAILURES ",failures);quit(1 if failures else 0)
func relocate(at: Vector3) -> void:
 core.resolve_autonomous(true)
 at.y=app.surface_world.terrain.field.height(at.x,at.z)+.15
 app.actors[actor_id].position=at;app.actors[actor_id].velocity=Vector3.ZERO;core.update_position(1,at);core.motions[actor_id]=FrontierCrewLocomotion.create()
func play_squads(owner: Dictionary) -> void:
 folder="/tmp/coopertech-squads-play"
 if not "--crew-ui-test" in OS.get_cmdline_user_args() or not ("--crew-folder="+folder) in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,800);root.content_scale_size=root.size
 for row in core.world.incidents.records.values():row.phase="idle";row.time=0;row.start_mode="dormant"
 var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(core.world),"save isolated play fixture: "+store.last_error)
 var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"Forward+ expedition loaded",90):quit(1);return
 app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view();core=app.session.authority
 var position:=FrontierCrewWorld.vector(source.home)+Vector3(0,0,40);relocate(position)
 if not await until(func():return app.surface_world.ready_at(app.actors[actor_id].position) and squad_sources.all(func(r):return app.surface_world.incidents.models.has(FrontierExplorationIncidents.key(r))),"all three squad models and collision streamed",70):quit(1);return
 var view:=app.surface_world.incidents
 for row in squad_sources:
  var nodes: Dictionary=view.models[FrontierExplorationIncidents.key(row)]
  if row.robot_role=="sentry":continue
  check(nodes.robot_animation!=null and nodes.robot_animation.has_animation("walk") and nodes.main.find_children("*","Skeleton3D",true,false).size()==1,"dedicated skeleton and seven clips "+row.robot_role)
 look_at_point(FrontierCrewWorld.vector(source.home)+Vector3.UP*1.5);await capture("dormant-squad")
 core.resolve_autonomous(true)
 var row: Dictionary=core.world.incidents.records[robot_key]
 # Choose a real clear firing lane outside the dormant wake radius.
 for i in 16:
  var angle:=float(i)*TAU/16.0;var at:=FrontierCrewWorld.vector(row.position)+Vector3(sin(angle)*24,0,cos(angle)*24);at.y=app.surface_world.terrain.field.height(at.x,at.z)+.15
  var from:=at+Vector3.UP*1.72;var to:=FrontierCrewWorld.vector(row.position)+Vector3.UP*2.1
  if not squad_sources.all(func(r):return at.distance_to(FrontierCrewWorld.vector(r.position))>float(FrontierCooperTechSquads.spec(r).wake_distance)+2):continue
  if app._shot_obstacle_distance(actor_id,from,(to-from).normalized(),from.distance_to(to))<from.distance_to(to)-.4:continue
  relocate(at);break
 look_at_point(FrontierCrewWorld.vector(row.position)+Vector3.UP*2.1);await create_timer(.35).timeout;core.resolve_autonomous(true);app.firearm.shoot()
 await until(func():return core.world.incidents.records[robot_key].hp<float(FrontierCooperTechSquads.spec(row).health) or core.world.incidents.records[robot_key].shield<float(FrontierCooperTechSquads.spec(row).shield),"real player bullet hits new robot",5)
 check(squad_sources.all(func(r):return core.world.incidents.records[FrontierExplorationIncidents.key(r)].phase!="idle"),"live shot wakes dormant squad")
 await capture("squad-waking")
 relocate(FrontierCrewWorld.vector(row.position)+Vector3(0,0,-13));look_at_point(FrontierCrewWorld.vector(row.position)+Vector3.UP*2.1)
 var bus:=AudioServer.get_bus_index("SFX");var recorder:=AudioEffectRecord.new();AudioServer.add_bus_effect(bus,recorder);recorder.set_recording_active(true)
 if await until(func():return core.world.incidents.records[robot_key].phase=="aiming","BASTION warns before firing",15):
  await capture("bastion-aiming")
 if await until(func():return core.world.incidents.records[robot_key].phase=="projectile","BASTION launches visible shell",8):
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/bastion-projectile.png")
 await until(func():return core.world.incidents.records[robot_key].phase=="cooling","BASTION enters recovery window",8)
 check(view.audio.last_played.has("sfx_gun_plasma") and view.audio.last_played.has("sfx_incident_robot_wake"),"ElevenLabs wake and artillery cues play")
 var raptor_id: String=""
 for r in squad_sources:
  if r.robot_role=="raptor":raptor_id=FrontierExplorationIncidents.key(r)
 core.resolve_autonomous(true);core.world.crew.members[actor_id].vitals.health=100.0
 relocate(FrontierCrewWorld.vector(core.world.incidents.records[raptor_id].position)+Vector3(0,0,-10));look_at_point(FrontierCrewWorld.vector(core.world.incidents.records[raptor_id].position)+Vector3.UP)
 if await until(func():return core.world.incidents.records[raptor_id].phase=="aiming","RAPTOR acquires player",15):await capture("raptor-engagement")
 var before_attack:=int(core.world.incidents.records[raptor_id].attack_serial)
 await until(func():
  core.world.crew.members[actor_id].vitals.health=100.0
  return int(core.world.incidents.records[raptor_id].attack_serial)>=before_attack+2,"RAPTOR performs distinct burst shots",12)
 # Show already-active patrol using the same seeded formation, at an observation distance.
 relocate(FrontierCrewWorld.vector(source.home)+Vector3(0,0,60));core.resolve_autonomous(true)
 for r in squad_sources:
  var current: Dictionary=core.world.incidents.records[FrontierExplorationIncidents.key(r)];current.phase="patrol";current.time=0;current.alarmed=false
 var previous: Array=core.world.incidents.records[robot_key].position.duplicate();await create_timer(2).timeout
 check(previous!=core.world.incidents.records[robot_key].position,"patrol positions advance in live host snapshots")
 look_at_point(FrontierCrewWorld.vector(source.home)+Vector3.UP);await capture("active-patrol")
 app.open_menu(app.inventory_panel);await create_timer(.4).timeout
 check(view.attack_effects.bullets.active.is_empty() and view.attack_effects.blasts.items.is_empty() and view.attack_effects.shells.is_empty(),"menu clears enemy tracers, ordnance and blast particles")
 check(view.models.values().all(func(n):return not n.has("robot_motor") or not n.robot_motor.playing or n.robot_motor.stream_paused),"menu pauses robot motor audio")
 app.close_menus();recorder.set_recording_active(false);var recording:=recorder.get_recording();recording.save_to_wav(folder+"/squad-runtime.wav");AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
 check(await app.session.close_session(),"live squad damage and positions persist")
 app.queue_free();await process_frame;await process_frame
 print("COOPERTECH_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)
