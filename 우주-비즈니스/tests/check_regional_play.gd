extends "res://tests/check_facility_interactions.gd"
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
 if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 root.size=Vector2i(1280,800)
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
 await process_frame
 app.world_store.write(FrontierUniverse.new_world(71491));app.start_solo()
 if not await until(func():return app.session.active,15):quit(1);return
 if not await until(func():return app.flight!=null and not app.preparing_first_snapshot and not has_meta("startup_loader"),60):quit(1);return
 app.onboarding.letter.hide()
 var world: Dictionary=app.session.authority.world
 var ordinal:=31;var body:=FrontierUniverse.body(world.manifest,ordinal)
 var nav: Dictionary=world.crew.navigation
 nav.system=int(body.system_ordinal);nav.target=ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
 var p:=FrontierCrewNavigation.center(ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.radius(body)+30)
 nav.position=[p.x,p.y,p.z];nav.direction=[0,0,-1];world.location=body.id
 app.session._publish();await process_frame;app.travel_action("land")
 check(await until(func():return app.surface_world!=null and not app.arrival.active,90),"new T2 landing")
 if app.surface_world==null:quit(1);return
 app.close_menus();app.toggle_navigation();await create_timer(1).timeout
 check(app.planet_map.visible and not app.navigation_frame.visible,"Tab opens planet map on surface")
 check(app.any_menu_open() and not app._mouse_look_allowed(),"map blocks gameplay input")
 app.planet_map.focus=Vector2.ZERO;app.planet_map.meters_per_pixel=2.5;app.planet_map.canvas.queue_redraw()
 await capture("planet-map-resources")
 app.planet_map.layers.select(1);app.planet_map.canvas.queue_redraw();await capture("planet-map-environment")
 root.size=Vector2i(960,640);await create_timer(.4).timeout;await capture("planet-map-960")
 check(app.planet_map.canvas.size.y>=200 and app.planet_map.detail.get_global_rect().end.y<=app.planet_map.get_global_rect().end.y,"small-screen map and details fit")
 root.size=Vector2i(1280,800);app.toggle_navigation();check(not app.planet_map.visible,"Tab closes map")
 var site:=FrontierExpeditionBusiness.site(app.session.authority.world)
 site.state="active";app.session.authority.world.business.active=body.id
 FrontierCoopWorkload.activate(site,body,1)
 # A restored water district is a saved render fixture; neighbouring districts stay native.
 var zone: Dictionary=site.regions["region:1"]
 for cell in zone.cells:
  cell.environment.water=85.0;cell.environment.temperature=18.0;cell.environment.pressure=1.0;cell.environment.oxygen=.21;cell.environment.toxicity=0.0;cell.environment.ecology=70.0;cell.environment.stable_seconds=30.0
  cell.restoration2.salinity=0.0;cell.restoration2.soil=80.0
 FrontierRegionalTerraform.tick(app.session.authority.world,0)
 app.session._publish_surface()
 var at:=FrontierCrewWorld.vector(zone.center)
 at.y=app.surface_world.terrain.field.height(at.x,at.z)
 move_to(at+Vector3(0,1,12));app.camera.look_at(at+Vector3.UP*1);app.yaw=app.camera.rotation.y;app.pitch=app.camera.rotation.x
 check(await until(func():return app.surface_world.ready_at(app.actors[app.session.latest.self_id].position),60),"external district streams")
 app.session._publish_surface();await create_timer(5).timeout
 check(int(app.surface_world.terrain.material.get_shader_parameter("region_count"))==15,"terrain renders independent regional cells")
 await capture("external-restoration")
 app.toggle_navigation();app.planet_map.focus=Vector2.ZERO;app.planet_map.meters_per_pixel=2.5;app.planet_map.layers.select(1);app.planet_map.selected="region:1";app.planet_map.refresh()
 await capture("regional-progress")
 app.close_menus()
 var err:=FrontierExpeditionBusiness.validate(app.session.authority.world.business,app.session.manifest)
 check(err.is_empty(),"live region save validation: "+err)
 await app.session.close_session();print("REGIONAL_PLAY_FAILURES ",failures);quit(1 if failures else 0)
