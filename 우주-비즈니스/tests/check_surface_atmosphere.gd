extends SceneTree
var failures:=0
var app: FrontierCrewExpedition
var folder:=""
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;printerr("FAIL ",label)
	else:print("PASS ",label)
func until(test: Callable,seconds: float=60) -> bool:
	var end:=Time.get_ticks_msec()+int(seconds*1000)
	while not test.call() and Time.get_ticks_msec()<end:await process_frame
	return test.call()
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name+".png")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	app.world_store.write(FrontierUniverse.new_world(71491));app.start_solo()
	if not await until(func():return app.session.active,15):check(false,"session starts");quit(1);return
	app.onboarding.letter.hide()
	var preferences:=FrontierClientSettings.ensure(self)
	preferences.values.view_distance=4096
	var world: Dictionary=app.session.authority.world
	var ordinal:=FrontierUniverse.first_ordinal(world.manifest,23)
	while not FrontierUniverse.landable(FrontierUniverse.body(world.manifest,ordinal)):ordinal+=1
	var body:=FrontierUniverse.body(world.manifest,ordinal)
	var nav: Dictionary=world.crew.navigation
	nav.system=23;nav.target=ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
	var point:=FrontierCrewNavigation.center(ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.radius(body)+30)
	nav.position=[point.x,point.y,point.z];nav.direction=[0,0,-1];world.location=body.id
	app.session._publish();await process_frame;app.travel_action("land")
	if not await until(func():return app.surface_world!=null and not app.arrival.active and app.surface_world.distant.mesh!=null,90):check(false,"landing and 4096 terrain complete");quit(1);return
	var surface:=app.surface_world
	var controller=surface.atmosphere
	var site:=FrontierExpeditionBusiness.site(app.session.authority.world)
	var center:=FrontierCrewWorld.vector(site.center)
	var original: Dictionary=site.environment.duplicate(true)
	app.pitch=.20
	var samples: Array=[{"pressure":0.0,"toxicity":0.0,"temperature":-60.0,"water":0.0},{"pressure":.45,"toxicity":55.0,"temperature":40.0,"water":25.0},{"pressure":1.0,"toxicity":0.0,"temperature":18.0,"water":75.0}]
	var states: Array=[]
	for index in samples.size():
		for key in samples[index]:site.environment[key]=samples[index][key]
		app.session._publish_surface();await process_frame
		# Advance presentation to its settled state; no mutation of persistent simulation rules.
		controller.step(60,center,0,1)
		for frame in 18:await process_frame
		states.append(controller.current.duplicate())
		await capture("sky-stage-"+str(index))
	check(states[0].atmosphere<.01 and states[0].fog<.00001,"vacuum has no atmospheric haze")
	check(states[2].atmosphere>.7 and states[2].cloud_amount>.7,"pressure and water form sky and clouds")
	check(states[1].fog>states[2].fog,"detoxification clears dirty haze")
	var remote: Dictionary=controller.target_at(center+Vector3(1000,0,0))
	var native: Dictionary=controller.appearance(surface.body,{})
	check(remote==native,"regional restoration does not change entire planet")
	controller.step(.1,center,1,0)
	check(is_zero_approx(surface.environment.fog_density),"fog preference respected in caves")
	controller.step(.1,center,1,1)
	check(is_equal_approx(surface.environment.ambient_light_energy,.035),"cave lighting preserved")
	for key in original:site.environment[key]=original[key]
	app.queue_free();await process_frame
	print("SURFACE_ATMOSPHERE_FAILURES ",failures);quit(1 if failures else 0)
