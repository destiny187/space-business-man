extends "res://tests/test_crew_surface.gd"
func run() -> void:
	var app_script=load("res://scripts/app/crew_expedition.gd")
	check(app_script!=null,"Entry script loads")
	var core:=FrontierCrewAuthority.new();var owner:=FrontierPlayerProfile.new_character("성간 항해 검증",0)
	check(core.start(FrontierUniverse.new_world(71491),owner,persist),"Host world")
	check(request(core,1,"start_game").ok,"Start")
	var nav: Dictionary=core.world.crew.navigation
	var before:=FrontierCrewWorld.vector(nav.position)
	FrontierCrewNavigation.steer(core.world,[1.0,.3,0.0],.1)
	check(FrontierCrewWorld.vector(nav.position)!=before,"Manual propulsion")
	for i in 20:FrontierCrewNavigation.steer(core.world,[0.0,0.0,0.0],.1)
	check(nav.speed==0,"Release brakes")
	nav.position=[19999.0,0.0,0.0];nav.direction=[1.0,0.0,0.0];nav.speed=700
	FrontierCrewNavigation.steer(core.world,[1.0,0.0,0.0],.1)
	check(FrontierCrewWorld.vector(nav.position).length()<=20000 and nav.boundary,"System boundary")
	check(not core.input(1,1,[0,0],[0,0,-1],false,false,[NAN,0,0]),"Reject invalid controls")
	ready_all(core)
	check(request(core,1,"navigate",{"ordinal":10}).ok,"Choose another system")
	check(request(core,1,"depart").ok,"Free departure")
	nav=core.world.crew.navigation
	var flight:=FrontierCrewFlightView.new();flight.state={"manifest":core.world.manifest};root.add_child(flight)
	root.size=Vector2i(1280,800);flight.exterior=true
	flight.last_phase="직접 조종"
	var stages: Dictionary={};var last_progress: float=-1
	for i in 125:
		FrontierCrewNavigation.step(core.world,.1)
		nav=core.world.crew.navigation
		check(FrontierCrewNavigation.validate(nav).is_empty(),"Valid transit/save state")
		if nav.mode=="jump":
			check(nav.transit.progress>=last_progress,"Monotonic progress");last_progress=nav.transit.progress
			stages[FrontierCrewNavigation.phase(nav)]=true
		if i in [8,58,112]:
			flight.update_navigation(nav)
			await create_timer(.25).timeout
			await RenderingServer.frame_post_draw
			var folder:=ProjectSettings.globalize_path("res://../docs/production/media/stellar-cruise")
			DirAccess.make_dir_recursive_absolute(folder)
			root.get_texture().get_image().save_png(folder+"/phase-%03d.png"%i)
	check(flight.engine.stream!=null and flight.transit_audio.last_played.has("sfx_robot_charge"),"Existing ElevenLabs charge and engine connected")
	check(stages.size()==5,"Charge acceleration cruise braking entry")
	check(nav.system==1 and nav.mode=="approach","Destination system arrival")
	check(nav.transit.galaxy_position==nav.transit.to,"Continuous route reaches destination")
	check(FrontierUniverse.validate_world(JSON.parse_string(JSON.stringify(core.world))).is_empty(),"Reload")
	for i in 1200:
		FrontierCrewNavigation.step(core.world,.1)
		if nav.mode=="idle":break
	check(nav.mode=="idle" and core.world.location==FrontierUniverse.body_id(core.world.manifest,10),"Approach completes")
	ready_all(core);check(request(core,1,"land").ok,"Landing remains connected")
	print("STELLAR CRUISE ",checks," checks ",failures," failures")
	quit(0 if failures==0 else 1)
