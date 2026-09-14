extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/playtest-space-scan"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder="+folder not in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 var owner:=FrontierPlayerProfile.new_character("스캔·항로 확인",0)
 var core:=FrontierCrewAuthority.new();core.start(FrontierUniverse.new_world(61739),owner,func(_w):return true)
 var world: Dictionary=core.world
 world.crew.navigation.erase("solar_opening");world.crew.navigation.mode="idle"
 check(FrontierWorldStore.new(folder+"/world.json").write(world),"isolated world")
 var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader") and not app.preparing_first_snapshot,"actual orbital scene",90):quit(1);return
 app.onboarding.letter.hide();app.close_menus();app.outside=true;app.exterior_view.show();app.if_flight_view();app.set_physics_process(false);app.set_process(false)
 var flight:=app.flight;flight.set_process(false);flight.scan_enabled=true;flight.presentation_blocked=false
 flight.traffic.selected={};flight.corporate_view.selected={};flight.trace_view.selected={};flight.freight_view.selected={}
 var entry: Dictionary=flight.planets[3]
 var center: Vector3=entry.node.global_position
 flight.camera.global_position=center+Vector3(0,0,FrontierUniverse.navigation_radius(FrontierUniverse.body(world.manifest,3))*4)
 flight.camera.look_at(center,Vector3.UP)
 flight.scanned.clear();flight.scan_held=false;flight._update_planet_scan(3)
 check(flight.scan_target==3 and flight.scan_progress==0,"looking at planet alone never scans")
 flight.scan_held=true;flight._update_planet_scan(.5)
 check(flight.scan_progress>0 and flight.scan_progress<1,"holding scan progresses on planet")
 flight.scan_held=false;flight._update_planet_scan(.1)
 check(flight.scan_progress==0,"releasing scan resets unfinished analysis")
 flight.scan_held=true;flight._update_planet_scan(3)
 check(flight.scan_progress==1 and not flight.scanned.is_empty(),"explicit scan completes and stores planet result")
 check(FrontierPlayInput.default_code("scan")==KEY_T,"T is common scan default")
 await capture("planet-t-scan")
 var stars=app.navigation_ui.nearby_stars;stars.set_process(false);stars.clear_gaze()
 check(not stars.advance_gaze(Vector3.FORWARD,false,4.9),"no route hints before five seconds")
 check(stars.advance_gaze(Vector3.FORWARD,false,.1),"route hints appear at five seconds")
 check(stars.advance_gaze(Vector3.FORWARD.rotated(Vector3.UP,.5),false,.1),"revealed hints allow aim adjustment")
 check(not stars.advance_gaze(Vector3.FORWARD,true,.1) and stars.gaze_seconds==0,"actual object resets route dwell")
 stars.advance_gaze(Vector3.FORWARD,false,4)
 check(not stars.advance_gaze(Vector3.RIGHT,false,1) and stars.gaze_seconds==1,"turning to different sky starts new dwell")
 check(await app.session.close_session(),"scan session closes")
 app.queue_free();await process_frame;print("SPACE_SCAN_GAZE ",checks," FAILURES ",failures);quit(1 if failures else 0)
