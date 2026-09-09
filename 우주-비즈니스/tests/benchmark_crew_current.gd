extends "res://tests/test_solo_entry.gd"
## Focused performance diagnosis. Requires an isolated test folder; never uses normal saves.
## --ground-only / --cpu-only require the saved fixture created by a full run.
## Removal variants are temporary diagnostic probes, not production quality changes.
func run() -> void:
 folder="/tmp/performance-audit-20260909"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder=/tmp/performance-audit-20260909" not in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 if "--ground-only" in OS.get_cmdline_user_args() or "--cpu-only" in OS.get_cmdline_user_args() or "--verify-controls-only" in OS.get_cmdline_user_args():
  root.size=Vector2i(1280,800)
  app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
  if not await until(func():return app.surface_world!=null and not app.arrival.active,"saved ground loaded",90):quit(1);return
  var settings:=FrontierClientSettings.ensure(self)
  settings.values=FrontierClientSettings.DEFAULTS.duplicate();settings.values.fps=0;settings.values.vsync=false;settings.apply_all()
  await measure_ground();return
 var owner:=FrontierPlayerProfile.new_character("성능 진단",1)
 FrontierWorldStore.new(folder+"/world.json").write(FrontierUniverse.new_world(71491))
 var profile_store:=FrontierPlayerProfile.new(folder+"/profile.json");profile_store.data={"version":1,"character":owner,"sessions":{}};profile_store.save()
 root.size=Vector2i(1280,800)
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.session.active and app.flight!=null,"actual expedition started",50):quit(1);return
 var prefs:=FrontierClientSettings.ensure(self)
 prefs.values=FrontierClientSettings.DEFAULTS.duplicate()
 prefs.values.fps=0;prefs.values.vsync=false;prefs.apply_all()
 app.onboarding.letter.hide();app.close_menus()
 await create_timer(2).timeout
 results.append(await measure("space_balanced"))
 if "--verify-optimization" not in OS.get_cmdline_user_args():
  var space_shader: Shader=app.flight.sky_material.shader
  var flat_space:=Shader.new();flat_space.code="shader_type sky; void sky(){COLOR=vec3(.005,.01,.02);}"
  app.flight.sky_material.shader=flat_space
  results.append(await measure("space_simple_sky"))
  app.flight.sky_material.shader=space_shader
  prefs.values.scale=.5;prefs.apply_all()
  results.append(await measure("space_half_render_scale"))
  prefs.values.scale=1.0;prefs.apply_all()
  results.append(await measure("space_balanced_return"))
  var contours:=app.flight.find_children("InkContours","MeshInstance3D",true,false)
  for contour in contours:contour.hide()
  results.append(await measure("space_without_contour"))
  for contour in contours:contour.show()
  if "--space-only" in OS.get_cmdline_user_args():
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(folder+"/space-baseline.png")
   FileAccess.open(folder+"/space-audit.json",FileAccess.WRITE).store_string(JSON.stringify({"results":results,"size":root.size,"space_size":app.space_view.size,"settings":prefs.values,"letter_visible":app.onboarding.letter.visible,"node_count":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)},"  "))
   await app.session.close_session();app.queue_free();await process_frame;quit();return
 else:
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/optimized-space.png")
 app.onboarding.letter.hide();app.close_menus()
 var world: Dictionary=app.session.authority.world
 var small: bool="--finch" in OS.get_cmdline_user_args()
 var selected: Dictionary={}
 for system in range(1,80):
  for i in FrontierUniverse.body_count(world.manifest,system):
   var ordinal:=FrontierUniverse.first_ordinal(world.manifest,system)+i
   var body:=FrontierUniverse.body(world.manifest,ordinal)
   var p:=FrontierLandingSurfaceEffects.profile(body)
   if FrontierUniverse.landable(body) and (p.air<.35 if small else p.air>.6):selected={"body":body,"system":system,"ordinal":ordinal};break
  if not selected.is_empty():break
 check(not selected.is_empty(),"requested atmospheric environment exists")
 if selected.is_empty():quit(1);return
 var nav: Dictionary=world.crew.navigation
 var body: Dictionary=selected.body
 nav.system=selected.system;nav.target=selected.ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
 var point:=FrontierCrewNavigation.center(selected.ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.navigation_radius(body)+30)
 nav.position=[point.x,point.y,point.z];nav.direction=[0,0,-1];world.location=body.id;world.navigation_target=body.id
 if small:
  var actor: String=app.session.latest.self_id
  if not world.crew.has("shuttles"):world.crew.shuttles={}
  world.crew.shuttles[actor]={"state":"sortie","pad_slot":0,"progress":1.0,"factory_id":"fixture","system":selected.system,"location":body.id,"navigation_target":body.id,"navigation":nav.duplicate(true),"landing":{},"cargo":{},"cargo_equipment":{},"rock":0}
  world.crew.members[actor].shuttle_id=actor
 app.session._publish();await create_timer(.8).timeout
 app.travel_action("land")
 if not await until(func():return app.surface_world!=null and not app.arrival.active,"landing completes",110):quit(1);return
 await measure_ground()

func measure_ground() -> void:
 var prefs:=FrontierClientSettings.ensure(self)
 var surface:=app.surface_world
 if not await until(func():return surface.terrain.jobs.is_empty() and surface.distant.task_id==-1 and surface.distant.queued.is_empty(),"streaming settled",45):quit(1);return
 if "--verify-controls-only" in OS.get_cmdline_user_args():
  app.onboarding.letter.hide();app.close_menus()
  await verify_controls()
  FileAccess.open(folder+"/optimized-controls.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
  print("OPTIMIZED_CONTROLS_CHECKS ",checks," FAILURES ",failures)
  await app.session.close_session();app.queue_free();await process_frame;quit(1 if failures else 0);return
 app.yaw=.5;app.pitch=-.12
 await create_timer(2).timeout
 if "--cpu-only" in OS.get_cmdline_user_args():
  await measure_cpu();return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder+"/baseline.png")
 results.append(await measure("ground_balanced"))
 if "--verify-optimization" in OS.get_cmdline_user_args():
  await verify_play();return
 surface.distant.hide()
 results.append(await measure("without_distant"));surface.distant.show()
 var previous_shadows: bool=surface.atmosphere.sun.shadow_enabled
 surface.atmosphere.sun.shadow_enabled=false;surface.lamp.shadow_enabled=false
 results.append(await measure("without_shadows"))
 surface.atmosphere.sun.shadow_enabled=previous_shadows;surface.lamp.shadow_enabled=true
 surface.environment.ssao_enabled=false;surface.environment.glow_enabled=false
 results.append(await measure("without_ssao_glow"))
 surface.environment.ssao_enabled=true;surface.environment.glow_enabled=true
 prefs.values.scale=.5;prefs.apply_all()
 results.append(await measure("half_render_scale"))
 prefs.values.scale=1.0;prefs.apply_all()
 var original_sky: Shader=surface.atmosphere.material.shader
 var simple:=Shader.new();simple.code="shader_type sky; void sky(){COLOR=mix(vec3(.5,.6,.7),vec3(.1,.2,.3),max(EYEDIR.y,0.));}"
 surface.atmosphere.material.shader=simple
 results.append(await measure("simple_sky"))
 surface.atmosphere.material.shader=original_sky;surface.atmosphere.paint()
 surface.landing_ship.hide()
 results.append(await measure("without_landing_ship"));surface.landing_ship.show()
 prefs._preset(0);prefs.values.fps=0;prefs.values.vsync=false;prefs.apply_all()
 if not await until(func():return surface.distant.task_id==-1 and surface.distant.queued.is_empty(),"performance distance settled",45):quit(1);return
 results.append(await measure("ground_performance"))
 prefs._preset(1);prefs.values.fps=0;prefs.values.vsync=false;prefs.apply_all()
 if not await until(func():return surface.distant.task_id==-1 and surface.distant.queued.is_empty(),"balanced distance settled",45):quit(1);return
 results.append(await measure("ground_balanced_return"))
 var moving_start: Vector3=surface.viewer.position
 app.test_direction=Vector2(1,0)
 results.append(await measure("ground_walk",300))
 app.test_direction=Vector2.ZERO
 var context: Dictionary={"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"window_size":root.size,"viewport_size":root.get_visible_rect().size,"body":surface.body.id,"family":surface.body.traits.id,"native_environment":surface.body.traits,"camera":app.camera.position,"walk_distance":surface.viewer.position.distance_to(moving_start),"distant_build_count":surface.distant.build_count,"last_chunk_install_ms":surface.terrain.last_install_ms,"max_chunk_build_ms":surface.terrain.max_build_ms,"space_view_update_mode":app.space_view.render_target_update_mode,"settings":prefs.values.duplicate(),"results":results,"scope":"Single current solo expedition, seed 71491, isolated save, 1280x800 requested. Diagnostic removals are temporary, not fixes. GPU zero means unavailable. Walking crosses new chunks; other ground cases stationary."}
 FileAccess.open(folder+"/audit.json",FileAccess.WRITE).store_string(JSON.stringify(context,"  "))
 print("AUDIT_RESULT ",JSON.stringify(context))
 await app.session.close_session()
 app.queue_free();await process_frame;await process_frame;quit()

var results: Array=[]
func measure(label: String,frames: int=150) -> Dictionary:
 for i in 30:await process_frame
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 var elapsed: Array[float]=[]
 var row: Dictionary={"label":label,"frames":frames,"process_ms":0.0,"physics_ms":0.0,"render_cpu_ms":0.0,"draw_calls":0.0,"primitives":0.0,"gpu_ms":0.0}
 var previous:=Time.get_ticks_usec()
 for i in frames:
  await process_frame
  var now:=Time.get_ticks_usec();elapsed.append((now-previous)/1000.0);previous=now
  row.process_ms+=Performance.get_monitor(Performance.TIME_PROCESS)*1000.0/frames
  row.physics_ms+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0/frames
  row.draw_calls+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)/frames
  row.primitives+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)/frames
  row.render_cpu_ms+=(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())+RenderingServer.get_frame_setup_time_cpu())/frames
  row.gpu_ms+=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())/frames
 elapsed.sort();row.mean_ms=0.0
 for value in elapsed:row.mean_ms+=value/frames
 row.p95_ms=elapsed[mini(frames-1,int(frames*.95))];row.max_ms=elapsed[-1];row.fps=1000.0/row.mean_ms
 if row.gpu_ms==0:row.gpu_ms=null
 FileAccess.open(folder+"/partial.json",FileAccess.WRITE).store_string(JSON.stringify(results+[row],"  "))
 print("AUDIT ",JSON.stringify(row))
 return row

func measure_cpu() -> void:
 var surface:=app.surface_world
 var rows: Array=[]
 var methods: Dictionary={"modal_tree_scan":func():FrontierCursorPolicy.modal_open(self),"feedback_blocked":app.feedback.blocked,"menu_visibility":app.any_menu_open,"terrain_process_idle":func():surface.terrain._process(0.0),"terrain_interests":surface._update_interest,"surface_details_idle":func():surface.surface_details._process(0.0),"surface_hud":app._update_surface_hud,"nearby_target":func():surface.business_view.target(app.camera,surface.viewer),"spaces_sync":app.spaces.sync,"fallback_rebuild":func():surface.distant.rebuild_fallback(surface.terrain.field,surface.terrain.field.key_at(surface.viewer.position),int(surface.config.active_radius),surface.terrain.chunks)}
 for label in methods:
  var values: Array[float]=[]
  for i in 12:
   await process_frame
   var before:=Time.get_ticks_usec();methods[label].call();values.append((Time.get_ticks_usec()-before)/1000.0)
  values.sort();rows.append({"method":label,"median_ms":values[6],"p95_ms":values[11]})
  print("CPU_METHOD ",JSON.stringify(rows[-1]))
 var info: Dictionary={"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"windows":root.find_children("*","Window",true,false).size(),"methods":rows,"note":"Direct synchronous calls in settled actual ground scene. Method cost only, not total contribution per frame."}
 FileAccess.open(folder+"/cpu-methods.json",FileAccess.WRITE).store_string(JSON.stringify(info,"  "))
 await app.session.close_session();app.queue_free();await process_frame;quit()

func verify_play() -> void:
 var surface:=app.surface_world
 var start: Vector3=surface.viewer.position
 var timings: Array[float]=[]
 var deadline:=Time.get_ticks_msec()+45000
 var previous:=Time.get_ticks_usec()
 app.test_direction=Vector2(1,0)
 while surface.viewer.position.distance_to(start)<110 and Time.get_ticks_msec()<deadline:
  await process_frame
  var now:=Time.get_ticks_usec();timings.append((now-previous)/1000.0);previous=now
 app.test_direction=Vector2.ZERO
 timings.sort();var total:=0.0
 for value in timings:total+=value
 var walking: Dictionary={"label":"ground_walk_110m","frames":timings.size(),"distance":surface.viewer.position.distance_to(start),"mean_ms":total/timings.size(),"p95_ms":timings[int(timings.size()*.95)],"max_ms":timings[-1]}
 print("OPTIMIZED_WALK ",JSON.stringify(walking));results.append(walking)
 await until(func():return surface.terrain.jobs.is_empty() and surface.distant.task_id==-1 and surface.distant.queued.is_empty(),"walked terrain settled",40)
 var before:=Time.get_ticks_usec()
 for i in 100:FrontierCursorPolicy.modal_open(self)
 var cursor_ms: float=(Time.get_ticks_usec()-before)/100000.0
 before=Time.get_ticks_usec()
 for i in 10:surface.distant.rebuild_fallback(surface.terrain.field,surface.terrain.field.key_at(surface.viewer.position),int(surface.config.active_radius),surface.terrain.chunks)
 var fallback_ms: float=(Time.get_ticks_usec()-before)/10000.0
 await verify_controls()
 var prefs:=FrontierClientSettings.ensure(self)
 var output: Dictionary={"results":results,"cursor_query_ms":cursor_ms,"fallback_refresh_ms":fallback_ms,"settings":prefs.values,"checks":checks,"failures":failures,"gpu":"Apple M2","size":root.size,"scope":"Current solo, seed 71491. Simulation active. 110m walk, current medium preset, not a frozen identical-clock before/after benchmark."}
 FileAccess.open(folder+"/optimized.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
 print("OPTIMIZATION ",JSON.stringify(output))
 await app.session.close_session();app.queue_free();await process_frame;await process_frame;quit(1 if failures else 0)

func verify_controls() -> void:
 var surface:=app.surface_world
 # An actual input event turns the view; an open settings window blocks it.
 var yaw_before: float=app.yaw
 var move:=InputEventMouseMotion.new();move.relative=Vector2(22,0);move.screen_relative=Vector2(22,0)
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;Input.parse_input_event(move);await process_frame
 check(not is_equal_approx(app.yaw,yaw_before),"mouse motion turns actual ground view")
 var prefs:=FrontierClientSettings.ensure(self);prefs.open();yaw_before=app.yaw
 Input.parse_input_event(move);await process_frame
 check(is_equal_approx(app.yaw,yaw_before),"settings blocks background camera input")
 prefs.close()
 await until(func():return app.feedback.handheld.visible,"equipment returns after settings closes",3)
 # Current actual equipment/effect connection and one local diagnostic dig.
 check(app.feedback.handheld.visible and app.feedback.audio!=null and app.feedback.effects!=null,"equipment model, sound and effect controllers stay connected")
 var edits_before: int=surface.applied_edits
 var aim_at: Vector3=surface.viewer.position+Vector3(2,0,0);aim_at.y=surface.terrain.field.height(aim_at.x,aim_at.z)
 # Only isolated local terrain for the mesher check; saves remain host-owned.
 surface.terrain.dig(aim_at,2.6)
 await until(func():return surface.terrain.batch.is_empty(),"visual collision dig commit completes",15)
 check(surface.applied_edits==edits_before,"diagnostic terrain dig does not forge host save edits")
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/optimized-ground.png")
