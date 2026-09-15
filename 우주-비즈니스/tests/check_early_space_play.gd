extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/early-space-play"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder="+folder not in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 for file in ["world.json","profile.json"]:DirAccess.copy_absolute("/tmp/followup-stellar-play/"+file,folder+"/"+file)
 root.size=Vector2i(960,640);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.flight!=null and not app.preparing_first_snapshot and not has_meta("startup_loader"),"flight ready",90):quit(1);return
 app.onboarding.letter.hide();app.onboarding.hide();app.onboarding.set_process(false);app.close_menus()
 app.set_process(false);app.set_physics_process(false);app.session.set_physics_process(false)
 var flight:=app.flight;flight.set_process(false)
 flight.presentation_blocked=false;flight.scan_enabled=true;flight.transit_overlay.arrival_age=100
 var ordinal: int=flight.planets.keys()[0]
 var entry: Dictionary=flight.planets[ordinal]
 flight.camera.global_position=entry.node.global_position+Vector3.BACK*float(entry.radius)*5
 flight.camera.look_at(entry.node.global_position)
 flight.scanned.clear();flight.scan_held=true;flight._update_planet_scan(3);flight._update_scan_surface(false)
 check(flight.scan_progress==1 and flight.scan_completion_left>0 and flight.scan_optics.scanned_subject!=null,"first scan completion highlights planet")
 flight.scan_held=false;flight._update_planet_scan(2);flight._update_scan_surface(false)
 check(flight.scan_progress==1 and flight.scan_optics.scanned_subject==null and not flight.transit_overlay.scan_body.is_empty(),"known planet shows data without highlight")
 await capture("known-planet")
 flight.scan_held=true;flight._update_planet_scan(.1);flight._update_scan_surface(false)
 check(flight.scan_optics.scanned_subject!=null,"holding T highlights known planet")
 await capture("held-scan")
 flight.scan_held=false
 var cfg: Dictionary=FrontierUniverse.presentation().stellar_transition
 flight.departure_origin=Vector3.ZERO;flight.departure_heading=Vector3.FORWARD
 var distances: Array=[]
 for progress in [.23,.26,.29]:
  distances.append(flight._display_position({"mode":"jump","transit":{"progress":progress}}).length())
 check(float(distances[0])<10 and float(distances[2])-float(distances[1])>float(distances[1])-float(distances[0]),"slow departure accelerates progressively: "+str(distances))
 var a:=app.session.authority;var nav: Dictionary=a.world.crew.navigation
 var station: Dictionary={}
 for index in range(1,100):
  station=FrontierSpaceStation.definition(a.world.manifest,index)
  if not station.is_empty():nav.system=index;break
 nav.mode="idle";nav.speed=0;nav.position=station.position.duplicate();nav.station_id=station.id
 var actor: String=app.session.latest.self_id
 a.world.crew.members[actor].aboard=true
 app.session._publish();app.station_market.update_snapshot(app.session.latest);app.open_menu(app.station_market)
 app.station_market.mode="ships";app.station_market.rebuild();app.station_market.open_logistics()
 await create_timer(.4).timeout;await capture("station-logistics")
 var opened:=false
 for child in app.station_market.get_children():
  if child is FrontierGameModal:opened=child.visible;child.cancel()
 check(opened,"transportation upgrade is available from ship seller")
 print("EARLY_SPACE_PLAY ",checks," failures ",failures)
 await app.session.close_session();app.queue_free();await process_frame;quit(1 if failures else 0)
