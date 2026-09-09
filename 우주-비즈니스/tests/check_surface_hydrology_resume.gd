extends "res://tests/test_solo_entry.gd"
func run() -> void:
 if "--crew-folder=/tmp/surface-hydrology-20260909" not in OS.get_cmdline_user_args():quit(2);return
 root.size=Vector2i(1280,800)
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and app.surface_world.presence.assets_ready,"saved scene finishes bounded vegetation loading",55):quit(1);return
 app.onboarding.letter.hide();app.close_menus()
 var s:=app.surface_world;var p:=s.presence;var h:=s.hydrology
 if not await until(func():return h.jobs.is_empty() and h.source_requests.is_empty() and not h.tiles.is_empty(),"saved catchments finish incremental meshes",65):quit(1);return
 check(p.patches.size()==int(p.cfg.patch_count) and p.grass_meshes.size()>0,"all cover patches share prepared grass meshes")
 var source_count:=h.tiles.size();h.accept(s.business_view.ledger);check(h.tiles.size()==source_count,"unchanged snapshot preserves water meshes")
 check(h._protected(Vector3.ZERO),"landing plateau excludes river sources")
 var paused_players:=true
 p.sounds.water_sources.river.play();await create_timer(.1).timeout
 app.open_menu(app.inventory_panel);await process_frame
 var old_time:=p.clock_value
 await create_timer(.3).timeout
 for source in p.sounds.water_sources.values():
  if source.playing and not source.stream_paused:paused_players=false
 check(is_equal_approx(old_time,p.clock_value) and paused_players,"menu freezes time and all active water sources")
 app.close_menus()
 var settings:=FrontierClientSettings.ensure(self);var original: Dictionary=settings.values.duplicate(true)
 settings.values.tutorial_mode=2
 settings._merge_quality("effects",0);p.scenery.animation_left=0;p.scenery.update(.1,false)
 check(p.scenery.haze.multimesh.visible_instance_count==6 and p.scenery.motes.multimesh.visible_instance_count==24,"low effects limits only cosmetic pools")
 settings.values=original;settings.values.tutorial_mode=2
 var out:=ProjectSettings.globalize_path("res://../docs/production/media/surface-hydrology")
 var q: Vector3=s.viewer.position;q.y=s.terrain.field.height(q.x,q.z)
 p.mark(q,Vector3.FORWARD,2);p.scenery.puff(q,8)
 check(not p.traces.is_empty(),"ground tire mark and settling particle pool connected")
 app.feedback.handheld.visible=false
 var camera:=Camera3D.new();app.add_child(camera);camera.fov=65;camera.far=1400;camera.position=q+Vector3(4,3,5);camera.look_at(q);camera.make_current()
 s.atmosphere.cycles={};s.atmosphere.daylight=1;s.atmosphere.sun.rotation_degrees=Vector3(-45,-35,0);s.atmosphere.sun.light_energy=1.8
 await create_timer(.15).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/ground-detail.png")
 var probe:=Vector3.INF
 for row in h.tiles.values():
  if row.node.get_child_count()>0 and row.samples.size()>2:probe=row.samples[1];break
 var water: Dictionary=h.nearest_water(probe) if probe.is_finite() else {"distance":INF}
 check(float(water.distance)<3,"resumed generated river reconstructs its water sound source")
 # A resumed character starts at the landing ship, not at the previous shoreline.
 var native_before:=h.native_liquid;var wet_before: float=h.region.state.wet
 h.native_liquid=false;h.region.state.wet=.8;p.state.wet=.8;h.region_key="";h._schedule()
 check(h.tiles.has("managed"),"restored dry-world region schedules a local watercourse")
 await until(func():return h.jobs.is_empty(),"regional watercourse installs incrementally",12)
 if h.tiles.has("managed"):check(h.tiles.managed.node.get_child_count()>0,"regional watercourse has a rendered surface")
 h.native_liquid=native_before;h.region.state.wet=wet_before
 var current_before: Dictionary=s.atmosphere.current.duplicate(true)
 s.atmosphere.current.atmosphere=0.0;p.scenery.animation_left=0;p.scenery.update(.1,false)
 check(not p.scenery.haze.visible,"vacuum suppresses mid-distance airborne effects")
 s.atmosphere.current=current_before
 s.atmosphere.current.dust=.8;s.atmosphere.current.atmosphere=.75
 var phase_value:=float(int(s.body.seed)%1000)*.013
 s.atmosphere.clock_seconds=fposmod((PI/2-phase_value)*float(p.cfg.wind_period_seconds)/TAU,float(p.cfg.wind_period_seconds))
 camera.position=q+Vector3(20,7,26);camera.look_at(q+Vector3(0,1,-30))
 await create_timer(.3).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/midground-gust.png")
 s.atmosphere.current=current_before
 var report: Dictionary={"checks":checks,"failures":failures,"maximum_hydrology_step_ms":h.maximum_step_usec/1000.0,"catchments":h.tiles.size(),"patches":p.patches.size(),"scope":"Resume, pooled loading, unchanged snapshot, menu audio, effect quality; total game FPS not measured."}
 check(await app.session.close_session(),"resumed world closes cleanly")
 report.checks=checks;report.failures=failures
 FileAccess.open(out+"/resume.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 app.queue_free();await process_frame
 print("SURFACE_HYDROLOGY_RESUME ",checks," FAILURES ",failures);quit(1 if failures else 0)
