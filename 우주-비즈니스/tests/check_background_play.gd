extends "res://tests/test_solo_entry.gd"
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
 if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 root.size=Vector2i(1280,800)
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active,"saved ground ready",120):quit(1);return
 app.onboarding.letter.hide();app.close_menus()
 await create_timer(.3).timeout
 var clock_before:=app.flight.orbit_clock
 var authoritative_before:=float(app.session.latest.crew.navigation.orbit_time)
 var routes_before:=FrontierStellarRoutes.built
 var menu_before:=app.business_panel.vessel_terminal.heading.text
 app.business_panel.vessel_terminal.heading.text="hidden sentinel"
 await create_timer(.5).timeout
 check(app.flight.visual_suspended and app.flight.orbit_clock==clock_before,"hidden flight visual clock stopped")
 check(float(app.session.latest.crew.navigation.orbit_time)>authoritative_before,"host time continues while visuals sleep")
 check(FrontierStellarRoutes.built==routes_before,"ground leaves route preparation idle")
 check(app.business_panel.vessel_terminal.heading.text=="hidden sentinel","hidden vessel terminal not rebuilt")
 app.open_station("ship")
 check(app.business_panel.vessel_terminal.heading.text!="hidden sentinel","opening terminal applies latest snapshot immediately")
 app.close_menus()
 app.session.checkpoint_timer=0
 await physics_frame;await physics_frame
 check(app.session.store.checkpoint_thread!=null or app.session.checkpoint_timer>0,"periodic checkpoint scheduled")
 check(app.session.store.finish_pending(),"periodic checkpoint completes")
 await capture("ground")
 var actor: CharacterBody3D=app.actors[app.session.latest.self_id]
 var ship:=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)
 actor.position=ship+Vector3(3,1,3);actor.position.y=app.surface_world.terrain.field.height(actor.position.x,actor.position.z)+.1
 app.session.authority.update_position(1,actor.position);app.session._publish();app.station_action("launch")
 check(app.arrival.active,"approved launch starts")
 if not await until(func():return not app.arrival.active and app.surface_world==null,"launch returns to flight",45):quit(1);return
 await create_timer(.4).timeout
 check(not app.flight.visual_suspended and app.flight.pending_navigation.is_empty(),"latest navigation restored after launch")
 check(app.flight.current_system==int(app.session.latest.crew.navigation.system),"restored flight uses current system")
 await capture("flight")
 app.navigation_ui.open_galaxy();await create_timer(.4).timeout
 clock_before=app.flight.orbit_clock
 await create_timer(.3).timeout
 check(app.flight.visual_suspended and app.flight.orbit_clock==clock_before,"galaxy map suspends hidden flight")
 app.close_menus();await create_timer(.4).timeout
 check(not app.flight.visual_suspended and app.flight.pending_navigation.is_empty() and app.flight.orbit_clock>clock_before,"map close restores latest orbit state")
 app.outside=false;app.if_flight_view();app.navigation_ui.open_galaxy();await create_timer(.2).timeout
 app.close_menus();await create_timer(.3).timeout
 check(app.space_view.render_target_update_mode==SubViewport.UPDATE_ALWAYS and not app.flight.visual_suspended,"cabin window resumes after galaxy map")
 check(app.session.store.begin_checkpoint(app.session.authority.world),"checkpoint queued before exit")
 check(await app.session.close_session(),"exit joins worker and saves final state")
 check(app.world_store.checkpoint_thread==null and not app.world_store.read_state().is_empty(),"final save reloads with no worker left")
 app.queue_free();await process_frame
 print("BACKGROUND PLAY checks ",checks," failures ",failures);quit(1 if failures else 0)
