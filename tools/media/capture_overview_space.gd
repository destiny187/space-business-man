extends "capture_gameplay.gd"
func frames(n: int) -> void:
 for i in n:
  if i%30==0:root.grab_focus()
  await process_frame
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--dest="):dest=arg.trim_prefix("--dest=")
 assert("--crew-ui-test" in OS.get_cmdline_user_args());DirAccess.make_dir_recursive_absolute(dest)
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame
 FrontierClientSettings.ensure(self).values.music_volume=0.0
 var character:=FrontierPlayerProfile.new_character("탐험가",2)
 app.profile.data={"version":1,"character":character,"sessions":{}};app.profile.save()
 if not app.world_store.write(FrontierUniverse.new_world(71491)):printerr("SAVE ",app.world_store.last_error);quit(1);return
 app.start_solo()
 if not await until(func():return app.session.active and app.flight!=null and not app.preparing_first_snapshot and not has_meta("startup_loader"),100):printerr("NO_START");quit(1);return
 owner=app.session.latest.self_id
 app.session.response_received.connect(func(_seq,result):
  if not result.get("ok",false):print("REQUEST_ERROR ",result))
 print("OPENING_ELAPSED ",app.session.latest.crew.navigation.get("solar_opening",{}))
 root.grab_focus();start_clip("earth_sol_start");await frames(265);end_clip();await still("opening-end")
 await until(func():return not app.solar_opening_active(),30)
 app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.close_menus()
 app.navigation_ui.open_galaxy();await frames(10)
 start_clip("galaxy_route");await frames(90);end_clip();await still("galaxy")
 app.close_menus();app.navigation_ui.start_route(277)
 if await until(func():return app.session.latest.crew.navigation.mode!="idle",15):
  app.close_menus();start_clip("stellar_departure");await frames(390);end_clip();await still("flight")
 else:printerr("ROUTE_FAILED")
 await until(func():return app.session.latest.crew.navigation.mode=="idle",90)
 # The normal ship interior and physical augmentation station.
 app.outside=false;app.exterior_view.hide();app.if_flight_view();app.close_menus()
 var station: FrontierCrewStation=app.stations.cabin.get_node("Station_augmentation")
 move_before_clip(station.global_position+station.global_basis.z*2.1+Vector3.UP*.1);aim(station.interaction_point());await frames(20)
 var world: Dictionary=app.session.authority.world
 if not world.has("business"):world.business=FrontierExpeditionBusiness.create()
 world.business.bags[owner]=FrontierExpeditionBusiness.inventory()
 world.business.bags[owner].merge({"sapphire":12,"ruby":12,"emerald":12},true)
 print("GROWTH_WORLD_VALIDATION ",FrontierUniverse.validate_world(world));app.session._publish()
 start_clip("ship_augmentation")
 await frames(25);app.stations.navigate("augmentation");await frames(25)
 var page: FrontierAugmentationPanel=app.stations.augmentation
 page.gems.sapphire.pressed.emit();await frames(22);page.action.pressed.emit();await frames(100)
 evidence["augmentation"]=FrontierCrewAugmentation.level(app.session.authority.world.crew.members[owner],"mobility")
 end_clip();await still("augmentation");app.close_menus()
 # Start the real landing flow from a valid nearby orbit; cruise waiting is omitted.
 world=app.session.authority.world
 var body:=FrontierUniverse.body(world.manifest,8);var nav: Dictionary=world.crew.navigation
 nav.system=body.system_ordinal;nav.target=8;nav.mode="idle";nav.speed=0.0
 var p:=FrontierCrewNavigation.center(8,world.manifest,float(nav.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(body)+1)
 nav.position=FrontierExpeditionBusiness.array(p);nav.direction=[0,-1,0];world.location=body.id;world.navigation_target=body.id
 app.outside=true;app.exterior_view.show();app.if_flight_view();app.session._publish();await frames(25)
 start_clip("planet_approach");await frames(100);end_clip()
 nav.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(8,world.manifest,float(nav.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(body)+1));app.session._publish()
 app.travel_action("land")
 if await until(func():return app.surface_world!=null and app.arrival.active,90):
  start_clip("landing");await frames(300);end_clip();await still("landing")
 evidence["landed"]=app.surface_world!=null
 FileAccess.open(dest+"/segments.json",FileAccess.WRITE).store_string(JSON.stringify({"segments":segments,"evidence":evidence},"  "))
 await app.session.close_session();app.queue_free();await process_frame;quit()
