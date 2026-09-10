extends "res://tests/test_solo_entry.gd"
var examples: Dictionary={}
var m: Dictionary={}
func run() -> void:
	if "--crew-folder=/tmp/corporate-regions-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(2);return
	folder=ProjectSettings.globalize_path("res://../docs/production/media/corporate-space");DirAccess.make_dir_recursive_absolute("/tmp/corporate-regions-play")
	examples=JSON.parse_string(FileAccess.get_file_as_string("/tmp/corporations-sp07/examples.json"))
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var owner:=FrontierPlayerProfile.new_character("기업 항로 화면",2);var core:=FrontierCrewAuthority.new();core.start(FrontierUniverse.new_world(61739),owner,func(_w):return true)
	m=core.world.manifest
	check(FrontierWorldStore.new("/tmp/corporate-regions-play/world.json").write(core.world),"isolated current expedition save")
	var profile:=FrontierPlayerProfile.new("/tmp/corporate-regions-play/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"current expedition opens with corporate rules",45):quit(1);return
	app.onboarding.letter.hide();app.close_menus();FrontierClientSettings.ensure(self).values.tutorial_mode=2
	app.outside=true;app.exterior_view.show();app.if_flight_view();app.set_process(false);app.session.set_physics_process(false)
	app.flight.set_process(false);app.flight.scan_enabled=true;app.flight.presentation_blocked=false;app.flight.soundscape.blocked=false;app.flight.camera.set_as_top_level(true);app.flight.transit_overlay.hide()
	for theme in ["industry","restricted","frontier","declining","managed","wild"]:
		var index:=int(examples[theme]);var sites:=FrontierCorporateSites.profile(m,index)
		var nav: Dictionary=app.session.authority.world.crew.navigation;nav.system=index;nav.target=FrontierUniverse.first_ordinal(m,index);nav.orbit_time=0;nav.traffic_patrols={};nav.traffic_observers=[];nav.speed=0;nav.mode="idle"
		app.flight.update_navigation(nav)
		check(app.flight.corporate_models.size()==sites.sites.size(),theme+" loads only local site models")
		if sites.sites.is_empty():
			check(not is_instance_valid(app.flight.traffic),"unoccupied region has no traffic nodes");continue
		var site: Dictionary=FrontierCorporateSites.definition(m,sites.sites[0].id,0);var point:=FrontierCrewWorld.vector(site.position)
		app.flight.camera.global_position=point+Vector3(340,280,610);app.flight.camera.look_at(point)
		app.flight.corporate_view.update(0,false)
		if is_instance_valid(app.flight.traffic):app.flight.traffic.update(.02,0,false)
		if theme=="industry":
			await capture("region-site-unidentified")
			check(float(app.flight.corporate_view.selected.get("progress",-1))<1,"unidentified site shows scan progress")
		for k in 21:
			var t:=float(k)*.1;nav.orbit_time=t;app.flight.update_orbits(t)
			point=FrontierCrewWorld.vector(FrontierCorporateSites.definition(m,site.id,t).position)
			app.flight.camera.global_position=point+Vector3(340,280,610);app.flight.camera.look_at(point)
			if is_instance_valid(app.flight.traffic):app.flight.traffic.update(.1,t,false)
			app.flight.corporate_view.update(t,false);await create_timer(.02).timeout
		check(app.navigation_journal.data.bodies.get(FrontierUniverse.body_id(m,int(site.body)),{}).get("scanned",false),theme+" actual gaze publishes persistent body/site identification")
		if theme in ["industry","restricted"]:
			check(app.flight.corporate_view.mechanisms.size()>0 and app.flight.corporate_view.mechanisms[0].node.rotation.length()>.01,theme+" role machinery visibly moves")
		check(app.flight.soundscape.library.last_played.has("sfx_orbital_complete"),theme+" identification completion cue played")
		await capture("region-"+theme+"-game")
		if theme=="industry":
			await show_map(index,"region-map-partial")
			app.navigation_journal.scanned(int(sites.sites[1].body));await show_map(index,"region-map-route")
		if theme=="managed":
			var body:=FrontierUniverse.body(m,int(site.body));var node: Node3D=app.flight.planets[int(site.body)].node;var radius:=FrontierUniverse.navigation_radius(body)
			app.flight.camera.global_position=node.global_position+Vector3(0,radius*.8,radius*2.7);app.flight.camera.look_at(node.global_position)
			app.flight.corporate_view.update(2.1,true);app.flight.traffic.update(.1,2.1,true)
			await capture("region-managed-planet")
		# Deterministic review timestamp during actual cargo transfer at the selected berth.
		if theme=="frontier":
			var t:=0.0
			while t<1700:
				var row:=FrontierRegionalTraffic.sample(m,index,0,t)
				if row.stage=="unload" and float(row.u)>.2 and row.from==site.id:break
				t+=2
			nav.orbit_time=t;app.flight.update_navigation(nav)
			point=FrontierCrewWorld.vector(FrontierCorporateSites.definition(m,site.id,t).position)
			app.flight.camera.global_position=point+Vector3(390,320,590);app.flight.camera.look_at(point+Vector3(-100,10,30))
			app.flight.corporate_view.update(t,true);app.flight.traffic.update(1,t,false);await capture("region-lotus-unloading")
			var moving:=false
			for visual in app.flight.traffic.models.values():
				for pod in visual.pods:
					if pod.node.position.distance_to(pod.home)>1:moving=true
			check(moving,"regional cargo animates physical transfer pods")
			root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("region-traffic-960")
			app.flight.traffic.update(.1,t,true);app.flight.corporate_view.update(t,true)
			check(app.flight.traffic.selected.is_empty() and app.flight.corporate_view.selected.is_empty(),"menus suppress corporate gaze and traffic overlays")
			root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var journal:=FrontierNavigationJournal.new();journal.configure(m,app.session.world_id,app.session.latest.self_id)
	check(journal.data.bodies==app.navigation_journal.data.bodies,"site scan flags survive local journal reload")
	app.queue_free();await process_frame;await process_frame
	print("CORPORATE_REGIONS_PLAY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
func show_map(index: int,name_value: String) -> void:
	var layer:=CanvasLayer.new();layer.layer=50;root.add_child(layer)
	var chart: Control=load("res://scripts/ui/galaxy_chart.gd").new();layer.add_child(chart);chart.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);chart.size=Vector2(root.size)
	chart.manifest=m;chart.journal=app.navigation_journal;chart.system_index=index;chart.current_system=index;chart.ship_position=app.flight.camera.global_position;chart.queue_redraw()
	await capture(name_value);layer.queue_free();await process_frame
