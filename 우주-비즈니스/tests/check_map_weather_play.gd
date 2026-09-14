extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/playtest-field-research"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder="+folder not in OS.get_cmdline_user_args():quit(2);return
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"landed scene ready",90):quit(1);return
 app.onboarding.welcome_pending=false;app.onboarding.letter.hide();app.onboarding.set_process(false);app.onboarding.hide();app.close_menus();app.set_physics_process(false);app.set_process(false);app.session.set_process(false)
 root.size=Vector2i(960,640);root.content_scale_size=root.size
 var map:=app.planet_map
 app.open_menu(map);map.layers.select(1);map.refresh();await capture("map-loading")
 check(map.layers.item_count==4,"redundant restoration map layer removed")
 if not await until(func():return map.tile_cache.task<0 and map.tile_cache.completed==map.tile_cache.wanted.size(),"stable map tiles finish",90):quit(1);return
 await create_timer(.6).timeout;await capture("map-geology")
 var ids: Dictionary={}
 for row in map.tile_cache.wanted:ids[row.key]=map.tile_cache.tiles[row.key].texture.get_instance_id()
 var geology:=map.geology_cache.duplicate(true)
 map.zoom(2);map.refresh();await create_timer(1).timeout;map.zoom(.5);map.refresh()
 await until(func():return map.tile_cache.task<0,"zoom job completes",30)
 check(ids.keys().all(func(key):return map.tile_cache.tiles.has(key) and map.tile_cache.tiles[key].texture.get_instance_id()==ids[key]),"return zoom reuses textures")
 check(geology.keys().all(func(key):return map.geology_cache.get(key)==geology[key]),"mineral positions remain stable across zoom")
 app.close_menus()
 var surface:=app.surface_world
 surface.preferences.values.view_distance=10000;surface.preferences.apply_all();surface._refresh_distant()
 await until(func():return surface.distant.task_id==-1 and surface.distant.queued.is_empty(),"10km distant mesh completes",90)
 var count:=surface.distant.build_count
 for i in 12:app.camera.rotation.y+=TAU/12;await create_timer(.12).timeout
 check(surface.distant.build_count==count,"full camera turn does not regenerate distant terrain")
 print("DISTANCE ",surface.rendered_distance," FAR ",app.camera.far," TILES ",surface.distant.tiles.size()," WORKER_MS ",surface.distant.last_build_ms," MAX_MAIN_MS ",surface.distant.max_main_ms," FOG ",surface.environment.fog_density)
 app.camera.rotation.x=.12
 await capture("distant-10km")
 var weather:=surface.weather_view
 weather.set_process(false)
 var p:=app.camera.global_position
 var event: Dictionary={"kind":"rain","start":100.0,"end":200.0,"center":[p.x,p.y,p.z],"serial":999,"strikes":[]}
 check(is_zero_approx(FrontierPlanetWeatherView.cloud_amount(event,79,p,20,15)) and is_equal_approx(FrontierPlanetWeatherView.cloud_amount(event,90,p,20,15),.5),"cloud front precedes rain")
 app.session.latest.weather={"body_id":surface.body.id,"clock":130.0,"event":event,"personal":{"sheltered":false}}
 weather.cloud_cover=0;weather.strength=0;weather._process(.1)
 check(weather.strength==0,"rain waits for cloud coverage")
 for i in 25:weather._process(.1)
 await physics_frame;weather._physics_process(.5);weather._process(.1);surface.atmosphere.paint();await capture("rain-clouds")
 print("RAIN ",weather.cloud_cover," ",weather.strength," ",weather.drops.multimesh.visible_instance_count)
 check(weather.cloud_cover>.9 and weather.strength>.7 and weather.drops.multimesh.visible_instance_count>0,"clouds and precipitation render together")
 check(await app.session.close_session(),"close isolated scene")
 app.queue_free();await process_frame;print("MAP_WEATHER ",checks," FAILURES ",failures);quit(1 if failures else 0)
