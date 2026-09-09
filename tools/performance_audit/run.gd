extends "res://tests/test_solo_entry.gd"
const COUNTERS=preload("res://tests/perf_counters.gd")
const OUT="/tmp/performance-deep-audit-20260909"
var samples: Array=[]
func run() -> void:
 folder=OUT
 if "--crew-folder="+OUT not in OS.get_cmdline_user_args():quit(2);return
 root.size=Vector2i(1280,800)
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active,"saved ground loaded",120):quit(1);return
 var prefs:=FrontierClientSettings.ensure(self)
 prefs.values=FrontierClientSettings.DEFAULTS.duplicate();prefs.values.fps=0;prefs.values.vsync=false;prefs.apply_all()
 app.onboarding.letter.hide();app.close_menus();app.yaw=.5;app.pitch=-.12
 var s:=app.surface_world
 if not await until(func():return s.terrain.jobs.is_empty() and s.terrain.staged.is_empty() and s.distant.task_id==-1 and s.distant.queued.is_empty(),"streaming settled",60):quit(1);return
 await create_timer(2).timeout
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"/baseline.png")
 var inventory: Array=[]
 for n in root.find_children("*","SubViewport",true,false):inventory.append({"path":str(n.get_path()),"size":str(n.size),"update_mode":n.render_target_update_mode,"disable_3d":n.disable_3d})
 FileAccess.open(OUT+"/viewports.json",FileAccess.WRITE).store_string(JSON.stringify(inventory,"  "))
 if "--targeted" in OS.get_cmdline_user_args():
  await targeted();return
 await measure("active_baseline")
 COUNTERS.active=true
 await measure("active_profiled",180)
 COUNTERS.active=false
 var rows: Array=COUNTERS.rows.values();rows.sort_custom(func(a,b):return a.usec>b.usec)
 var totals: Array=COUNTERS.frames.values();totals.sort()
 var profile: Dictionary={"callbacks":rows,"frames":totals.size(),"frame_callback_p95_ms":totals[int(totals.size()*.95)]/1000.0,"spikes":COUNTERS.spikes,"note":"Inclusive outer process/physics callbacks; nested inherited callbacks not double counted. Native engine/render/physics time and callbacks outside these entry points are not included. Instrumented temporary project; frame count includes warmup."}
 FileAccess.open(OUT+"/cpu-profile.json",FileAccess.WRITE).store_string(JSON.stringify(profile,"  "))
 print("CPU_TOP ",JSON.stringify(rows.slice(0,12)))
 if "--profile-only" in OS.get_cmdline_user_args():
  FileAccess.open(OUT+"/results.json",FileAccess.WRITE).store_string(JSON.stringify({"samples":samples,"note":"Post-fix ground profile; no renderer omissions."},"  "))
  await app.session.close_session();app.queue_free();await process_frame;quit();return
 # Freeze simulation and pose so renderer variants compare the same visible scene.
 paused=true
 await measure("frozen_baseline")
 root.disable_3d=true;await measure("frozen_no_3d");root.disable_3d=false
 root.scaling_3d_scale=.5;await measure("frozen_half_scale");root.scaling_3d_scale=1.0
 var lights: Array=[]
 for n in root.find_children("*","Light3D",true,false):
  if n.shadow_enabled:lights.append(n);n.shadow_enabled=false
 await measure("frozen_no_shadows")
 for n in lights:n.shadow_enabled=true
 var env: Environment=s.environment
 var effects: Dictionary={}
 for key in ["ssao_enabled","ssil_enabled","ssr_enabled","glow_enabled"]:effects[key]=env.get(key);env.set(key,false)
 await measure("frozen_no_post")
 for key in effects:env.set(key,effects[key])
 var contours: Array=[]
 for n in root.find_children("InkContours","MeshInstance3D",true,false):
  if n.visible:contours.append(n);n.hide()
 await measure("frozen_no_contours")
 for n in contours:n.show()
 var old_sky: Shader=s.atmosphere.material.shader
 var flat_sky:=Shader.new();flat_sky.code="shader_type sky; void sky(){ COLOR=vec3(.15,.2,.3); }"
 s.atmosphere.material.shader=flat_sky;await measure("frozen_flat_sky");s.atmosphere.material.shader=old_sky
 var terrain_mat: ShaderMaterial=s.terrain.material
 var old_terrain: Shader=terrain_mat.shader
 var flat_terrain:=Shader.new();flat_terrain.code="shader_type spatial; void fragment(){ ALBEDO=vec3(.25,.3,.2); ROUGHNESS=.9; }"
 terrain_mat.shader=flat_terrain;await measure("frozen_simple_terrain_material");terrain_mat.shader=old_terrain
 s.surface_details.hide();await measure("frozen_no_surface_details");s.surface_details.show()
 s.landing_ship.hide();await measure("frozen_no_landing_ship");s.landing_ship.show()
 if s.presence!=null:s.presence.hide()
 if s.hydrology!=null:s.hydrology.hide()
 await measure("frozen_no_presence_water")
 if s.presence!=null:s.presence.show()
 if s.hydrology!=null:s.hydrology.show()
 await measure("frozen_return")
 paused=false
 await measure("active_return")
 var result: Dictionary={"samples":samples,"gpu":RenderingServer.get_video_adapter_name(),"size":str(root.size),"settings":prefs.values,"position":str(s.viewer.position),"body":s.body.id,"root_mesh_nodes":root.find_children("*","MeshInstance3D",true,false).size(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"note":"Temporary diagnostic omissions only. Frozen conditions hold game scripts/physics/pose; shader TIME and GPU effects may differ. One-at-a-time changes restored. GPU timing unavailable."}
 FileAccess.open(OUT+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 await app.session.close_session();app.queue_free();await process_frame;quit()
func measure(label: String,count: int=120) -> void:
 for i in 20:await process_frame
 var timings: Array[float]=[];var draws:=0.0;var primitives:=0.0
 var previous:=Time.get_ticks_usec()
 for i in count:
  await process_frame
  var now:=Time.get_ticks_usec();timings.append((now-previous)/1000.0);previous=now
  draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)/count
  primitives+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)/count
 timings.sort();var total:=0.0
 for t in timings:total+=t
 var mean:=total/count
 var row: Dictionary={"label":label,"frames":count,"mean_ms":mean,"fps":1000.0/mean,"p95_ms":timings[int(count*.95)],"max_ms":timings[-1],"draw_calls":draws,"primitives":primitives}
 samples.append(row);print("PROBE ",JSON.stringify(row))
 FileAccess.open(OUT+"/partial.json",FileAccess.WRITE).store_string(JSON.stringify(samples,"  "))

func targeted() -> void:
 COUNTERS.active=true
 await measure("target_baseline",260)
 COUNTERS.active=false
 FileAccess.open(OUT+"/target-cpu.json",FileAccess.WRITE).store_string(JSON.stringify({"callbacks":COUNTERS.rows.values(),"frames":COUNTERS.frames.size(),"extra":COUNTERS.extra,"spikes":COUNTERS.spikes},"  "))
 var routes: Dictionary={"before":FrontierStellarRoutes.built,"total":FrontierStellarRoutes.points.size()}
 var snapshots_before: int=app.session.snapshot_serial
 app.flight.set_process(false)
 await measure("target_no_hidden_flight")
 app.flight.set_process(true)
 COUNTERS.skip_routes=true
 await measure("target_no_route_build")
 COUNTERS.skip_routes=false
 var viewports: Array=[]
 for n in root.find_children("*","SubViewport",true,false):
  viewports.append({"node":n,"disabled":n.disable_3d});n.disable_3d=true
 await measure("target_no_subviewport_3d")
 for row in viewports:row.node.disable_3d=row.disabled
 app.flight.set_process(false);COUNTERS.skip_routes=true
 await measure("target_no_hidden_flight_or_routes")
 app.flight.set_process(true);COUNTERS.skip_routes=false
 await measure("target_return",180)
 routes.after=FrontierStellarRoutes.built
 FileAccess.open(OUT+"/target-results.json",FileAccess.WRITE).store_string(JSON.stringify({"samples":samples,"routes":routes,"snapshots_during_probes":app.session.snapshot_serial-snapshots_before,"note":"Only hidden flight visual callback / route index building / subviewport 3D disabled temporarily, separately and restored. World simulation, physics, current ground view continue."},"  "))
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"/target-return.png")
 await app.session.close_session();app.queue_free();await process_frame;quit()
