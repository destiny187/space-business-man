extends "res://tests/test_solo_entry.gd"
func run() -> void:
 var runtime:="/tmp/t3-station-play"
 if not "--crew-folder=/tmp/t3-station-play" in OS.get_cmdline_user_args() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(runtime)
 folder=ProjectSettings.globalize_path("res://../docs/production/media/t3-progression")
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame
 app.world_store.write(FrontierUniverse.new_world(71504));app.start_solo()
 if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"actual station session ready",80):quit(1);return
 var world: Dictionary=app.session.authority.world;var index:=1;var station: Dictionary={}
 while station.is_empty():
  station=FrontierSpaceStation.definition(world.manifest,index)
  if station.is_empty():index+=1
 world.crew.navigation.system=index;world.crew.navigation.mode="idle";world.crew.navigation.speed=0
 world.crew.navigation.position=FrontierExpeditionBusiness.array(FrontierCrewWorld.vector(station.position)+Vector3(0,0,1100));world.flight_position=world.crew.navigation.position.duplicate()
 if not world.has("business"):world.business=FrontierExpeditionBusiness.create()
 app.session._publish();await create_timer(.5).timeout;app.close_menus();app.onboarding.letter.hide()
 var panel: FrontierStationMarketPanel=app.station_market
 app.open_menu(panel);panel.mode="blueprints";panel.rebuild();await capture("station-blueprints-1280")
 check(panel.grid.get_child_count()==6,"six physical design cards")
 var before:=int(app.session.authority.world.business.credits)
 panel.selected="facility_factory_mk3";panel.refresh_detail();panel.buy.pressed.emit()
 check(await until(func():return FrontierFacilityBlueprints.owned(app.session.authority.world,"facility_factory_mk3"),"UI purchase commits common design",8),"purchase")
 check(int(app.session.authority.world.business.credits)==before-1200 and panel.buy.disabled,"UI updates funds and ownership")
 root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("station-blueprints-960")
 check(panel.buy.get_global_rect().end.y<640 and panel.get_global_rect().end.x<=960,"purchase and detail fit small screen")
 # Switching to other existing tabs must restore the ship preview camera and resource cards.
 panel.mode="ships";panel.selected="";panel.rebuild();await process_frame
 check(panel.preview_camera.size==13,"ship camera restored")
 panel.mode="goods";panel.selected="";panel.rebuild();check(not panel.grid.get_children().is_empty(),"existing goods remain available")
 check(await app.session.close_session(),"purchase written to disk")
 check(FrontierFacilityBlueprints.owned(FrontierWorldStore.new(runtime+"/world.json").read_state(),"facility_factory_mk3"),"design reloads")
 app.queue_free();await process_frame;print("T3_STATION_PLAY ",checks," CHECKS / ",failures," FAILURES");quit(1 if failures else 0)
