extends "res://tests/test_solo_entry.gd"
func snap(path: String) -> void:
 await create_timer(.3).timeout;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)
func run() -> void:
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder=/tmp/water-quality-play-20260909" not in OS.get_cmdline_user_args():quit(2);return
 root.size=Vector2i(1280,800)
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.preparing_first_snapshot,"isolated expedition ready",60):quit(1);return
 app.onboarding.letter.hide();app.close_menus()
 var settings:=FrontierClientSettings.ensure(self);settings.values.tutorial_mode=2
 var s:=app.surface_world;var a:=app.session.authority;var actor: String=app.session.latest.self_id
 var out:=ProjectSettings.globalize_path("res://../docs/production/media/water-quality");DirAccess.make_dir_recursive_absolute(out)
 check(settings.quality_controls.has("water"),"dedicated water quality menu exists")
 var at:=Vector3.INF;var closest:=INF
 for x in range(-240,241,12):
  for z in range(-240,241,12):
   var h:=s.terrain.field.height(x,z)
   var d:=Vector2(x,z).length()
   if h< -6 and d<closest:at=Vector3(x,-4,z);closest=d
 check(at.is_finite(),"native ocean location found")
 if not at.is_finite():quit(1);return
 print("OCEAN_REVIEW ",at)
 app.actors[actor].position=at+Vector3.UP*2;a.update_position(1,app.actors[actor].position);app.session._publish()
 s.atmosphere.cycles={};s.atmosphere.daylight=1;s.atmosphere.sun.rotation_degrees=Vector3(-38,-35,0);s.atmosphere.sun.light_energy=1.5
 var camera:=Camera3D.new();app.add_child(camera);camera.far=1200;camera.position=at+Vector3(10,4.0,12);camera.look_at(at+Vector3(-4,0,-5));camera.make_current()
 if not await until(func():return s.physical_water.mask_ready and s.ready_at(app.actors[actor].position),"coast collision and original-ground mask ready",65):quit(1);return
 await create_timer(.5).timeout
 # Lock presentation time only during comparisons. Host water physics and saved mean level are unchanged.
 var depth:=s.water_depth(at-Vector3.UP*.5)
 var records: Array=[]
 for quality in [0,2,1]:
  settings.set_quality("water",quality)
  check(int(s.hydrology.material.get_shader_parameter("water_quality"))==quality and int(s.physical_water.material.get_shader_parameter("water_quality"))==quality and int(s.hydrology.ocean.material_override.get_shader_parameter("water_quality"))==quality,"ocean, river and physical pool switch together: "+str(quality))
  var mesh: Mesh=s.hydrology.ocean.mesh
  var count: int=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
  check(count==4 if quality==0 else count>2000,"appropriate ocean mesh complexity: "+str(quality))
  check(is_equal_approx(s.water_depth(at-Vector3.UP*.5),depth),"visual option preserves water depth: "+str(quality))
  s.hydrology.set_process(false);s.hydrology.ocean.material_override.set_shader_parameter("flow_time",7.0)
  await snap(out+("/low.png" if quality==0 else "/ultra.png" if quality==2 else "/medium.png"))
  records.append({"quality":quality,"ocean_vertices":count})
  s.hydrology.set_process(true)
 settings.set_quality("water",2)
 var before:=root.get_texture().get_image();await create_timer(.5).timeout;await RenderingServer.frame_post_draw
 check(before.get_data()!=root.get_texture().get_image().get_data(),"highest water surface animates")
 settings.load_settings();check(int(settings.values.water_quality)==2,"water quality persists in isolated local settings")
 check(FrontierWaterQuality.ocean_mesh(2)==s.hydrology.ocean.mesh,"high resolution ocean mesh is reused")
 settings.open();await snap(out+"/settings.png")
 check(await app.session.close_session(),"session checkpoints after live quality changes")
 FileAccess.open(out+"/verification.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"mesh_levels":records,"scope":"One Forward+ expedition: native ocean comparison, all three material bindings, isolated settings save, mean water depth, mesh reuse. No full-game FPS benchmark."},"  "))
 app.queue_free();await process_frame;print("WATER_QUALITY_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)
