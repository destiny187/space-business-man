extends "res://tests/test_solo_entry.gd"
func run() -> void:
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder=/tmp/surface-water-play-20260909" not in OS.get_cmdline_user_args():quit(2);return
 root.size=Vector2i(1280,800)
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null,"resume physical water fixture",55):quit(1);return
 app.onboarding.letter.hide();app.close_menus()
 var s:=app.surface_world;var a:=app.session.authority;var actor: String=app.session.latest.self_id
 var p:=Vector3.INF
 for x in range(80,500,4):
  for z in range(-300,300,4):
   var h:=s.terrain.field.height(x,z)
   if h< -4.4 and h> -5.0:p=Vector3(x,h,z);break
  if p.is_finite():break
 check(p.is_finite() and s.hydrology.native_liquid,"fixture contains native ocean shallows")
 if not p.is_finite():quit(1);return
 var avatar: CharacterBody3D=app.actors[actor]
 avatar.position=p+Vector3(0,4,0);a.world.crew.members[actor].position=[avatar.position.x,avatar.position.y,avatar.position.z]
 app.test_direction=Vector2.ZERO
 if not await until(func():return s.ready_at(avatar.position),"shore collision loads",45):quit(1);return
 # A host-authored excavation opens below the original sea floor, using the normal edit replica.
 var center:=p-Vector3.UP*1.4
 if not a.world.terrain_edits.has(s.body.id):a.world.terrain_edits[s.body.id]=[]
 a.world.terrain_edits[s.body.id].append({"center":[center.x,center.y,center.z],"radius":2.5})
 a.water_timer=0;app.session._publish_surface()
 if not await until(func():return s.applied_edits==a.world.terrain_edits[s.body.id].size() and s.terrain.batch.is_empty(),"excavation mesh and collision installed",25):quit(1);return
 if not await until(func():return a.world.get("surface_water",{}).get(s.body.id,{}).get("cells",{}).size()>5,"ocean reservoir feeds edited cells",25):quit(1);return
 if not await until(func():return s.physical_water.visual.mesh!=null,"host water snapshot creates INK mesh",20):quit(1);return
 await create_timer(9).timeout
 var solver: FrontierSurfaceWater=a.water_solvers[s.body.id]
 var below:=0.0
 for k in solver.record.cells:
  var c:=FrontierSurfaceWater.point(k)
  if c.y<p.y-.5:below+=float(solver.record.cells[k][0])
 check(below>.2,"water enters excavated volume below original sea floor")
 check(s.water_depth(p+Vector3.UP*.05)>.15,"surface replica supplies local water depth")
 var packet:=FrontierCrewSurfaceReplica.packet(a.world,actor)
 check(FrontierCrewSurfaceReplica.validate(packet,app.session.manifest),"water packet passes planet and ecology validation")
 check(not FrontierCrewSurfaceReplica.encode(packet).is_empty(),"water fits existing compressed surface transport")
 check(FrontierUniverse.validate_world(a.world).is_empty(),"saved host world validates with fluid cells")
 var sound: Dictionary=s.hydrology.nearest_water(center)
 check(sound.get("physical",false),"flooded cave supplies causal spatial water sound")
 s.presence.scenery.water=sound;s.presence.sounds.update(.5,false)
 check(s.presence.sounds.water_sources.river.playing,"existing ElevenLabs river stream plays at physical water")
 var camera:=Camera3D.new();app.add_child(camera);camera.fov=65;camera.position=p+Vector3(6,18,8);camera.look_at(center);camera.make_current();app.feedback.handheld.visible=false
 FrontierClientSettings.ensure(self).values.tutorial_mode=2
 s.atmosphere.cycles={};s.atmosphere.sun.rotation_degrees=Vector3(-45,-35,0);s.atmosphere.sun.light_energy=1.8
 await create_timer(.5).timeout;await RenderingServer.frame_post_draw
 # Inspect the flooded cut from below the native ocean plane as well.
 var out:=ProjectSettings.globalize_path("res://../docs/production/media/surface-water")
 DirAccess.make_dir_recursive_absolute(out);root.get_texture().get_image().save_png(out+"/excavated-shore.png")
 camera.position=center+Vector3(.4,-.3,.4);camera.look_at(center+Vector3(1.2,.8,0))
 var lamp:=OmniLight3D.new();camera.add_child(lamp);lamp.omni_range=8;lamp.light_energy=2;lamp.shadow_enabled=false
 await create_timer(.3).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/flooded-cut.png")
 var report: Dictionary={"checks":checks,"failures":failures,"cells":solver.record.cells.size(),"volume_below_original_floor":below,"solver_maximum_ms":solver.maximum_usec/1000.0,"water_mesh_maximum_ms":s.physical_water.maximum_usec/1000.0,"compressed_packet_bytes":FrontierCrewSurfaceReplica.encode(packet).size(),"position":[p.x,p.y,p.z],"scope":"One resumed Forward+ host, edited shore, replica codec, depth, sound source, validated checkpoint. No multi-client soak or total FPS assertion."}
 check(await app.session.close_session(),"fluid world checkpoint saves")
 report.checks=checks;report.failures=failures
 FileAccess.open(out+"/verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 app.queue_free();await process_frame
 print("WATER_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)
