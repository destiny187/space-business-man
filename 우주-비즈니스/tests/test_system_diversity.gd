extends "res://tests/test_crew_surface.gd"
func run() -> void:
	var m:=FrontierUniverse.generate(61739)
	var total:=0;var counts: Dictionary={};var addressing:=true
	for index in 125000:
		var count:=FrontierUniverse.body_count(m,index);counts[count]=true
		var first:=FrontierUniverse.first_ordinal(m,index)
		addressing=addressing and first==total and FrontierUniverse.system_index(m,first)==index and FrontierUniverse.system_index(m,first+count-1)==index
		total+=count
	check(total==1000000 and counts.size()==9 and addressing,"all one million addresses map to 4–12 body systems without gaps")
	check(FrontierUniverse.body_count(m,0)==8 and FrontierUniverse.body(m,2).name=="지구","solar start unchanged")
	var restored: Dictionary=JSON.parse_string(JSON.stringify(m))
	check(FrontierUniverse.fingerprint(FrontierUniverse.body(m,921))==FrontierUniverse.fingerprint(FrontierUniverse.body(restored,921)),"variable system save reproduction")
	var legacy:=m.duplicate(true);legacy.settings.erase("system_rules")
	check(FrontierUniverse.first_ordinal(legacy,19)==152 and FrontierUniverse.body_count(legacy,19)==8,"legacy fixed system addresses unchanged")
	var samples: Dictionary={};var orbits_safe:=true
	for index in range(1,100):
		var layout:=FrontierUniverse.system_layout(m,index);samples[layout.theme]=index
		var previous: float=layout.warning
		for i in FrontierUniverse.body_count(m,index):
			var r:=FrontierUniverse.orbit_radius(m,index,i)
			orbits_safe=orbits_safe and r>previous and r<float(layout.boundary)-8000
			previous=r
	check(samples.size()==4 and orbits_safe,"four layouts with ordered safe orbital spacing")
	var core:=FrontierCrewAuthority.new();var owner:=FrontierPlayerProfile.new_character("항성계 다양성",0)
	check(core.start(FrontierUniverse.new_world(61739),owner,persist),"host starts variable world")
	check(request(core,1,"start_game").ok,"host confirms launch")
	var target:=FrontierUniverse.showcase_ordinal(m,int(samples.giant_court))
	check(request(core,1,"navigate",{"ordinal":target}).ok,"host selects variable system target")
	ready_all(core);check(request(core,1,"depart").ok,"host starts interstellar flight")
	FrontierCrewNavigation.step(core.world,12)
	var nav: Dictionary=core.world.crew.navigation
	check(nav.system==FrontierUniverse.system_index(m,target) and nav.mode=="approach","transit arrives in correct variable system")
	check(FrontierCrewWorld.vector(nav.position).is_equal_approx(FrontierUniverse.entry_position(m,target,float(nav.orbit_time))),"server and visual arrival use the same position")
	check(FrontierUniverse.validate_world(JSON.parse_string(JSON.stringify(core.world))).is_empty(),"arrival can be saved")
	for step in 800:
		FrontierCrewNavigation.step(core.world,.1)
		if nav.mode=="idle":break
	check(nav.mode=="idle" and core.world.location==FrontierUniverse.body_id(m,target),"automatic approach completes around moons")
	var target_body:=FrontierUniverse.body(m,target)
	var moon_point:=FrontierUniverse.position(m,target,float(nav.orbit_time))+FrontierUniverse.moon_offset(target_body,0,float(nav.orbit_time))
	var moon_radius:=FrontierUniverse.moon_radius(target_body,0)
	nav.mode="idle";nav.manual=true;nav.position=[moon_point.x,moon_point.y+moon_radius+110,moon_point.z]
	nav.direction=[0,-1,0];nav.speed=700.0;nav.hull=100.0;nav.damage_cooldown=0.0
	var before: Array=nav.position.duplicate()
	FrontierCrewNavigation.steer(core.world,[1,0,0],.5)
	check(FrontierCrewWorld.vector(nav.position).is_equal_approx(FrontierCrewWorld.vector(before)) and float(nav.hull)<100,"manual swept collision protects moons")
	if failures:printerr("SYSTEM FAIL ",failures);quit(1);return
	if "--rules-only" in OS.get_cmdline_user_args():print("SYSTEM PASS ",checks);quit();return
	root.size=Vector2i(1440,900)
	var view:=FrontierCrewFlightView.new();view.state={"manifest":m};root.add_child(view);view.set_process(false);view.ship.hide();view.transit_overlay.hide()
	var out:=ProjectSettings.globalize_path("res://../docs/production/media/system-diversity");DirAccess.make_dir_recursive_absolute(out)
	for theme in ["giant_court","satellites","debris","open"]:
		var index: int=samples[theme];view._load_system(index);view.update_orbits(0)
		var ordinal:=FrontierUniverse.showcase_ordinal(m,index)
		var body:=FrontierUniverse.body(m,ordinal);var center:=FrontierUniverse.position(m,ordinal)
		view.camera.global_position=FrontierUniverse.entry_position(m,ordinal,0)
		view.camera.look_at(center,Vector3.UP)
		if theme=="debris":
			var radius: float=FrontierUniverse.system_layout(m,index).belt_radius
			view.camera.global_position=Vector3(radius*.8,radius*.65,radius*1.5);view.camera.look_at(Vector3.ZERO)
		await create_timer(.5).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+"/"+theme+".png")
	print("SYSTEM PASS ",checks," + 4 Forward+ scenes")
	view.queue_free();await process_frame;quit()
