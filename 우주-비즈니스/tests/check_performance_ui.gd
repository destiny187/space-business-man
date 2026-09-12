extends "res://tests/test_solo_entry.gd"
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
 if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not has_meta("startup_loader"),"surface loaded",100):quit(1);return
 var prefs:=FrontierClientSettings.ensure(self)
 for group in prefs.graphics_groups():prefs._merge_quality(group,2 if group=="anti_aliasing" else 1)
 prefs.values.fps=60;prefs.apply_all();app.onboarding.letter.hide();app.close_menus()
 app.toggle_navigation()
 var map:=app.planet_map
 if not await until(func():return map.texture!=null and map.bake_task<0,"map raster installed",15):quit(1);return
 await capture("map")
 map.zoom(.8);map.refresh();map.zoom(.8);map.refresh()
 if not await until(func():return map.map_key==map._bake_key() and map.bake_task<0,"latest zoom wins queued work",15):quit(1);return
 await capture("map-zoom")
 app.close_menus();app.set_physics_process(false)
 var panel:=app.business_panel
 var site: Dictionary=app.session.surface.business.sites[app.surface_world.body.id]
 var factory_id:=""
 for id in site.buildings:
  if site.buildings[id].type=="factory":factory_id=id;break
 check(not factory_id.is_empty(),"fixture has a factory")
 if not factory_id.is_empty():
  panel.set_context("factory",factory_id);app.open_menu(panel)
  panel.update(app.session.surface.business,app.surface_world.body.id,app.session.latest.self_id,int(app.surface_world.body.planet_tier),app.session.surface.get("engineering",{}),app.session.surface.ecology,app.surface_world.body)
  check(panel.production_panel.is_visible_in_tree(),"opening factory paints current production tab")
  panel.warehouse_key="hidden sentinel"
  panel.update(app.session.surface.business,app.surface_world.body.id,app.session.latest.self_id,int(app.surface_world.body.planet_tier),app.session.surface.get("engineering",{}),app.session.surface.ecology,app.surface_world.body)
  check(panel.warehouse_key=="hidden sentinel","hidden warehouse does not rebuild")
  panel.factory_category.select(1);panel._factory_page()
  check(panel.robot_factory.is_visible_in_tree(),"switching tab shows robot factory immediately")
  await capture("factory")
  panel.set_context("base");panel._flush_paint()
  check(panel.warehouse_key!="hidden sentinel","opening warehouse applies current inventory")
 app.close_menus();check(await app.session.close_session(),"session closes after draining pending saves")
 app.queue_free();await process_frame
 print("PERFORMANCE_UI ",checks," failures ",failures);quit(1 if failures else 0)
