extends "res://tests/test_solo_entry.gd"
var review: Node3D
var pose: FrontierCrewPose
var avatar: CharacterBody3D
var actor_id: String
var out: String
func capture_frame(label: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+label+".png")
func mirror() -> void:
 if is_instance_valid(review) and is_instance_valid(avatar):
  review.position=avatar.position
  pose.animate(app.session.authority.motions.get(actor_id,{}),1.0/60,false,false)
func run() -> void:
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder=/tmp/water-interactions-play-20260909" not in OS.get_cmdline_user_args():quit(2);return
 out=ProjectSettings.globalize_path("res://../docs/production/media/water-interactions");DirAccess.make_dir_recursive_absolute(out)
 root.size=Vector2i(1280,800)
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.preparing_first_snapshot,"resume isolated wet-planet fixture",55):quit(1);return
 app.onboarding.letter.hide();app.close_menus();FrontierClientSettings.ensure(self).values.tutorial_mode=2
 var a:=app.session.authority;var s:=app.surface_world;actor_id=app.session.latest.self_id;avatar=app.actors[actor_id]
 var p:=Vector3(-12,s.terrain.field.height(-12,-12),-12);var level:=p.y+2.6
 avatar.position=p+Vector3.UP*3.2;avatar.velocity=Vector3.ZERO;a.update_position(1,avatar.position)
 if not await until(func():return s.ready_at(avatar.position),"local collision ready",60):quit(1);return
 # A fixed basin isolates water contacts and rendering from fluid transport (covered by physical-water checks).
 var record:=FrontierSurfaceWater.create();record.serial=1
 for x in range(floori(p.x)-8,floori(p.x)+9):
  for z in range(floori(p.z)-8,floori(p.z)+9):
   for y in range(floori(p.y),ceili(level)):
    record.cells[FrontierSurfaceWater.key(Vector3i(x,y,z))]=[minf(1,level-y),0.0]
 a.world.surface_water={s.body.id:record};a.water_solvers.clear();a.water_timer=100000
 var solver:=FrontierSurfaceWater.new();solver.configure(s.terrain.field);solver.native=false;solver.record=record;solver.interests=[];a.water_solvers[s.body.id]=solver
 app.session._publish_surface()
 if not await until(func():return s.physical_water.visual.mesh!=null,"controlled water surface mesh ready",30):quit(1);return
 check(s.water_interactions.streams.size()==5,"five generated ElevenLabs contact sounds loaded")
 var camera:=Camera3D.new();app.add_child(camera);camera.position=p+Vector3(5,5.8,6);camera.look_at(p+Vector3.UP*2);camera.make_current()
 var light:=OmniLight3D.new();camera.add_child(light);light.omni_range=18;light.light_energy=.7
 review=Node3D.new();app.add_child(review)
 var model: Node3D=load("res://assets/models/crew/surveyor_suit.glb").instantiate();review.add_child(model);FrontierInkStyle.apply(model,{})
 pose=FrontierCrewPose.new();review.add_child(pose);pose.configure(model);process_frame.connect(mirror)
 var recorder:=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS;AudioServer.add_bus_effect(0,recorder);recorder.set_recording_active(true)
 # Establish dry position before dropping: initial joins/teleports intentionally have no splash.
 avatar.position=p+Vector3.UP*3.2;avatar.velocity=Vector3.ZERO;a.update_position(1,avatar.position)
 a.motions[actor_id]=FrontierCrewLocomotion.create();s.water_interactions.seen.clear()
 var enter_before:=int(s.water_interactions.emitted.enter)
 if not await until(func():return int(s.water_interactions.emitted.enter)>enter_before,"real descent creates one entry splash",8):quit(1);return
 await create_timer(.09).timeout;await capture_frame("entry")
 if "--water-entry-review" in OS.get_cmdline_user_args():
  await app.session.close_session();app.queue_free();await process_frame;print("ENTRY_RENDER_REVIEW_OK");quit();return
 if not await until(func():return a.motions[actor_id].state=="tread" and absf(avatar.velocity.y)<.2 and float(a.motions[actor_id].water_depth)<1.6,"buoyancy settles into treading",20):quit(1);return
 await create_timer(.3).timeout;await capture_frame("treading")
 app.test_direction=Vector2.RIGHT
 if not await until(func():return a.motions[actor_id].state=="swim" and s.water_interactions.emitted.stroke>0,"moving swimmer produces strokes and ripples",5):quit(1);return
 await create_timer(.6).timeout;print("SWIM_DEPTH ",a.motions[actor_id]," POS ",avatar.position);await capture_frame("swimming");app.test_direction=Vector2.ZERO
 check(absf(model.rotation.x)>.3,"existing Blender rig leans into swimming pose")
 var arm:=pose.skeleton.get_bone_pose_rotation(pose.bones.upper_arm_L)
 await create_timer(.4).timeout
 check(arm.angle_to(pose.skeleton.get_bone_pose_rotation(pose.bones.upper_arm_L))>.08,"swimming arms keep stroking after transition settles")
 var loadout: Dictionary=a.world.crew.members[actor_id].loadout;loadout.counter+=1;var item: String="crafted:"+str(loadout.counter);loadout.items[item]="pulse_1";loadout.slots[1]=item;loadout.selected=1
 app.session._publish();app.pitch=-.65
 await create_timer(.3).timeout
 var shot_before:=int(s.water_interactions.emitted.shot)
 app.surface_action("surface_attack")
 if not await until(func():return int(s.water_interactions.emitted.shot)>shot_before,"approved weapon request creates a water impact",5):printerr("HOST ",a.error);quit(1);return
 await create_timer(.08).timeout;await capture_frame("water-shot")
 check(a.motions[actor_id].has("water_shot"),"shot event included in host motion for other observers")
 # Dive via the same movement and camera input as play.
 app.pitch=-1.1;app.test_direction=Vector2(0,-1)
 await create_timer(.8).timeout;app.test_direction=Vector2.ZERO
 check(float(a.motions[actor_id].water_depth)>1.65,"looking down and moving submerges the player")
 await create_timer(.3).timeout;check(s.water_interactions.lowpass.cutoff_hz<6000,"underwater contacts are audibly filtered")
 await capture_frame("underwater")
 # Drain to ankle depth, then walk and leave the water without a teleport.
 var ankle:=FrontierSurfaceWater.create();ankle.serial=2
 for x in range(floori(p.x)-8,floori(p.x)+9):
  for z in range(floori(p.z)-8,floori(p.z)+9):
   var base:=s.terrain.field.height(x+.5,z+.5);var y:=floori(base)
   ankle.cells[FrontierSurfaceWater.key(Vector3i(x,y,z))]=[.16,base-y]
 a.world.surface_water[s.body.id]=ankle;solver.record=ankle;app.session._publish_surface();app.pitch=0
 await create_timer(1).timeout;app.test_direction=Vector2.RIGHT
 await create_timer(1.2).timeout;app.test_direction=Vector2.ZERO
 check(s.water_interactions.emitted.step>0,"shallow walking uses water contacts instead of dry footsteps")
 a.world.surface_water[s.body.id]=FrontierSurfaceWater.create();solver.record=a.world.surface_water[s.body.id];app.session._publish_surface()
 await create_timer(.3).timeout;check(s.water_interactions.emitted.exit>0,"drainage or exit plays a single wet departure")
 recorder.set_recording_active(false);recorder.get_recording().save_to_wav(out+"/game-water-mix.wav");AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
 var fx:=s.water_interactions
 for i in 120:fx.emit_contact("enter",avatar.position+Vector3.UP*.2,1.5)
 check(fx.particles[0].size()<=48 and fx.particles[1].size()<=16 and fx.particles[2].size()<=192 and fx.voices.size()==8,"effect burst stays inside fixed mesh and voice budgets")
 app.toggle_inventory();await create_timer(.1).timeout
 check(fx.particles[0].is_empty() and fx.voices.all(func(v: AudioStreamPlayer3D):return not v.playing),"opening a menu clears effects and stops contact audio")
 app.close_menus();await create_timer(.1).timeout
 check(FrontierUniverse.validate_world(a.world).is_empty(),"world validates after contacts and weapon outcome")
 var result: Dictionary={"checks":checks+1,"failures":failures,"events":fx.emitted.duplicate(),"scope":"One actual Forward+ host; existing Blender rig mirrored by an observer camera; controlled local water levels, real movement and approved weapon request. No six-client load run."}
 check(await app.session.close_session(),"isolated session checkpoints cleanly")
 FileAccess.open(out+"/verification.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 app.queue_free();await process_frame;print("WATER_INTERACTION_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)
