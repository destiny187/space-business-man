extends "res://tests/test_solo_entry.gd"
## Paired same-session probes: only the removed rendering work is toggled.
var samples: Array=[]
var timing_available:=false
var current_preview: FrontierEquipmentPreview
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
 if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 root.size=Vector2i(1280,800)
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.flight!=null and app.session.active and not app.arrival.active,"saved space ready",60):quit(1);return
 var settings:=FrontierClientSettings.ensure(self)
 settings.values=FrontierClientSettings.DEFAULTS.duplicate();settings.values.vsync=false;settings.values.fps=0;settings.apply_all()
 app.onboarding.letter.hide();app.close_menus();app.outside=true;app.exterior_view.show();app.if_flight_view()
 DisplayServer.window_move_to_foreground()
 # Complete the finite navigation index before timing either condition.
 var deadline:=Time.get_ticks_msec()+60000
 while Time.get_ticks_msec()<deadline:
  FrontierStellarRoutes.build(app.session.manifest,int(app.session.latest.crew.navigation.system),1500)
  if FrontierStellarRoutes.built>=FrontierStellarRoutes.points.size():break
  await process_frame
 check(FrontierStellarRoutes.built==FrontierStellarRoutes.points.size(),"route preparation complete before measurements")
 timing_available=RenderingServer.has_method("viewport_set_measure_render_time")
 for vp in [root,app.space_view]:enable_timing(vp)
 await create_timer(2).timeout
 # ABBA ordering reduces simple warmup/thermal drift; two short blocks per mode.
 for optimized in [false,true,true,false]:
  set_cabin_optimization(optimized)
  await measure("external",optimized,root)
 set_cabin_optimization(true)
 await capture("external-measured")
 app.outside=false;app.exterior_view.hide();app.if_flight_view();await create_timer(.2).timeout
 check(not root.disable_3d,"cabin restored after comparison")
 app.outside=true;app.exterior_view.show();app.if_flight_view()
 app.toggle_shipyard();await create_timer(.4).timeout
 current_preview=app.shipyard_panel.preview.view;enable_timing(current_preview.viewport)
 check(current_preview.is_visible_in_tree(),"real shipyard preview visible")
 for optimized in [false,true,true,false]:
  current_preview.continuous_rendering=not optimized
  await measure("shipyard",optimized,current_preview.viewport)
 current_preview.continuous_rendering=false
 await create_timer(.2).timeout
 check(current_preview.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"preview returns to cached rendering")
 await capture("shipyard-measured")
 var result: Dictionary={"samples":samples,"checks":checks,"failures":failures,"settings":settings.values,"preview_size":str(current_preview.viewport.size),"gpu":RenderingServer.get_video_adapter_name(),"size":str(root.size),"timing_api":timing_available,"route_built":FrontierStellarRoutes.built,"note":"Current game, same session ABBA. External: only covered main 3D pass toggled. Shipyard: only static preview continuous rendering toggled; covered pass remains disabled. Live simulation continues. Not an old-checkout comparison or ground FPS benchmark. GPU timing of zero is unavailable, not zero cost. Per-viewport counters may retain the last rendered frame while disabled; use the global draw delta for submitted work."}
 FileAccess.open(folder+"/comparison.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 await app.session.close_session();app.queue_free();await process_frame
 check(not root.disable_3d,"root render restored on exit")
 print("RENDER COMPARISON failures ",failures);quit(1 if failures else 0)
func enable_timing(vp: Viewport) -> void:
 if timing_available:RenderingServer.call("viewport_set_measure_render_time",vp.get_viewport_rid(),true)
func set_cabin_optimization(enabled: bool) -> void:
 if RenderingServer.frame_pre_draw.is_connected(app._sync_main_render):RenderingServer.frame_pre_draw.disconnect(app._sync_main_render)
 root.disable_3d=false;app.main_render_suspended=false
 if enabled:RenderingServer.frame_pre_draw.connect(app._sync_main_render);app._sync_main_render()
func measure(scene: String,optimized: bool,target: Viewport) -> void:
 for i in 45:await process_frame
 var times: Array[float]=[]
 var count:=360
 var main_draws:=0.0;var target_draws:=0.0;var all_draws:=0.0;var triangles:=0.0
 var cpu:=0.0;var gpu:=0.0
 var previous:=Time.get_ticks_usec()
 for i in count:
  await process_frame
  var now:=Time.get_ticks_usec();times.append((now-previous)/1000.0);previous=now
  main_draws+=root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
  target_draws+=target.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
  all_draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
  triangles+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
  if timing_available:
   cpu+=float(RenderingServer.call("viewport_get_measured_render_time_cpu",target.get_viewport_rid()))
   gpu+=float(RenderingServer.call("viewport_get_measured_render_time_gpu",target.get_viewport_rid()))
 var total:=0.0
 for t in times:total+=t
 times.sort()
 var row: Dictionary={"scene":scene,"optimized":optimized,"frames":count,"mean_ms":total/count,"fps":1000.0/(total/count),"median_ms":times[count/2],"p95_ms":times[int(count*.95)],"max_ms":times[-1],"main_draws":main_draws/count,"target_draws":target_draws/count,"all_draws":all_draws/count,"primitives":triangles/count,"target_render_cpu_ms":cpu/count,"target_render_gpu_ms":gpu/count}
 samples.append(row);print("MEASURE ",JSON.stringify(row))
 FileAccess.open(folder+"/partial.json",FileAccess.WRITE).store_string(JSON.stringify(samples,"  "))
