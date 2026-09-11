extends "res://tests/check_weather_play.gd"
## Continue the isolated weather save: reconnection, build cards and journal rendering.
func run() -> void:
	folder="/tmp/space-weather-play"
	if "--crew-folder=/tmp/space-weather-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(1);return
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	var store:=FrontierWorldStore.new(folder+"/world.json");var saved:=store.read_state()
	check(not saved.is_empty(),"read isolated weather save")
	if saved.is_empty():quit(1);return
	var before: Dictionary=saved.weather.duplicate(true);var body_id: String=saved.location
	weather_actor=saved.crew.owner_id
	for row in saved.business.sites[body_id].buildings.values():
		if row.type=="field_canopy":canopy_point=FrontierCrewWorld.vector(row.position)
		elif row.type=="grounding_mast":mast_point=FrontierCrewWorld.vector(row.position)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"resume Forward+ ready",100):quit(1);return
	var resumed: Dictionary=app.session.authority.world.weather
	check(resumed.planets[body_id].event.serial==before.planets[body_id].event.serial and resumed.planets[body_id].event.center==before.planets[body_id].event.center,"resume keeps front identity and fixed location")
	check(resumed.planets[body_id].next_hazard==before.planets[body_id].next_hazard,"resume does not reroll cooldown")
	check(app.session.authority.weather_presence[weather_actor].grace>0,"resume protects player while warning and terrain become ready")
	app.close_menus();app.onboarding.letter.hide();app.outside=false;app.exterior_view.hide();app.if_flight_view()
	app.open_station("build")
	app.business_panel.building.select(app.business_panel.building.item_count-1);app.business_panel.refresh_building_cost()
	check(app.business_panel.building_cards.has("field_canopy") and app.business_panel.building_cards.has("grounding_mast"),"both authored facility cards available")
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	await process_frame
	var card: Control=app.business_panel.building_cards.grounding_mast
	var parent:=card.get_parent()
	while parent!=null and parent!=app:
		if parent is ScrollContainer:parent.ensure_control_visible(card)
		parent=parent.get_parent()
	await capture("weather-build-960")
	app.close_menus();var actor: CharacterBody3D=app.actors[weather_actor]
	look(actor,mast_point+Vector3(8,0,5),mast_point+Vector3(0,-1,0));app.pitch=-1.0;await process_frame;app.begin_placement("grounding_mast");await create_timer(.6).timeout
	await capture("mast-placement-960");check(app.placement_ghost.find_children("*","MeshInstance3D",true,false).size()>1,"mast placement includes visual protection footprint")
	check(app.placement_ghost.visible,"placement ghost visible on actual ground ray")
	if "--weather-ui-only" in OS.get_cmdline_user_args():
		app.cancel_placement();await app.session.close_session();app.queue_free();await process_frame;await process_frame;await RenderingServer.frame_post_draw;print("WEATHER_UI_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0);return
	app.cancel_placement();root.size=Vector2i(1280,800);root.content_scale_size=root.size
	look(actor,canopy_point+Vector3(8,0,8),canopy_point+Vector3.UP*1.5)
	set_weather("rain",-8);await create_timer(2).timeout
	var weather:=app.surface_world.weather_view
	check(weather.rain.playing and AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("Ambience"),0)>-75,"weather ambience reaches the live mixer")
	var target:=FrontierPlanetWeather.target(app.session.authority.world,weather_actor,Vector3.UP)
	if not target.is_empty():FrontierPlanetWeather.observe(app.session.authority.world,target)
	var entries:=FrontierDiscoveryIndex.page(app.session.authority.world,"","weather",body_id,0)
	check(entries.total>0,"resumed weather journal entry")
	for journal in app.find_children("*","HBoxContainer",true,false):
		if journal is FrontierSurveyJournal:
			journal.select(entries.entries[0]);check(journal.details.get_child_count()>2,"weather journal detail includes icon and response");break
	await app.session.close_session();app.queue_free();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	print("WEATHER_RESUME_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
