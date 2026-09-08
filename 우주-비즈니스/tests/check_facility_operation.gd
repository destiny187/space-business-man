extends "res://tests/check_facility_interactions.gd"
## Bounded rendered review of accepted mining, survey, weapon and cancellation.
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	if "--facility-stopped-review" in OS.get_cmdline_user_args():
		var saved:=FrontierWorldStore.new(folder+"/world.json").read_state()
		check(not saved.is_empty(),"saved operating fixture readable")
		if not saved.is_empty():verify_completed_facilities(saved)
		print("FACILITY_STOPPED_FAILURES ",failures);quit(1 if failures else 0);return
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	app.world_store.write(FrontierUniverse.new_world(71491));app.start_solo()
	if not await until(func():return app.session.active,15):quit(1);return
	app.onboarding.letter.hide()
	var world: Dictionary=app.session.authority.world
	var ordinal:=FrontierUniverse.first_ordinal(world.manifest,23)
	while not FrontierUniverse.landable(FrontierUniverse.body(world.manifest,ordinal)):ordinal+=1
	var body:=FrontierUniverse.body(world.manifest,ordinal)
	var nav: Dictionary=world.crew.navigation
	nav.system=23;nav.target=ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
	var point:=FrontierCrewNavigation.center(ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.radius(body)+30)
	nav.position=[point.x,point.y,point.z];nav.direction=[0,0,-1];world.location=body.id
	app.session._publish();await process_frame;app.travel_action("land")
	if not await until(func():return app.surface_world!=null and not app.arrival.active,90):check(false,"landing");quit(1);return
	app.close_menus();app.session.send_request("business_register",{})
	var site:=FrontierExpeditionBusiness.site(app.session.authority.world)
	site.state="active";site.erase("restoration2")
	site.environment={"temperature":25.0,"pressure":.95,"oxygen":.18,"toxicity":10.0,"water":50.0,"ecology":0.0,"stable_seconds":0.0}
	site.inventory.ice=30
	var spots: Array[Vector3]=[]
	for x in range(-40,41,6):
		for z in range(-40,41,6):
			var p:=FrontierExpeditionBusiness.ground(app.surface_world.terrain.field,x,z,2.4)
			if p.is_finite():spots.append(p)
	spots.sort_custom(func(a: Vector3,b: Vector3):return a.distance_squared_to(Vector3.ZERO)<b.distance_squared_to(Vector3.ZERO))
	var used: Array[Vector3]=[]
	for kind in ["atmosphere","thermal","water","biolab","solar","solar"]:
		for p in spots:
			if used.any(func(other: Vector3):return other.distance_to(p)<6):continue
			var bid: String=kind if not site.buildings.has(kind) else kind+"2"
			site.buildings[bid]={"id":bid,"type":kind,"position":FrontierExpeditionBusiness.array(p),"yaw":0.0,"enabled":true,"active":false,"status":"전력 확인 중","work":0.0}
			used.append(p);break
	check(site.buildings.size()==6,"supported facility fixture")
	app.session._publish_surface()
	for kind in ["atmosphere","thermal","water","biolab"]:
		check(await until(func():return app.surface_world.business_view.nodes.has(kind),30),kind+" model loaded")
		var p:=FrontierExpeditionBusiness.point(FrontierExpeditionBusiness.site(app.session.authority.world).buildings[kind].position)
		var viewer:=p+Vector3(4,0,4);viewer.y=app.surface_world.terrain.field.height(viewer.x,viewer.z)+.2;move_to(viewer)
		app.test_camera_position=p+Vector3(6,4.4,6);await create_timer(.2).timeout
		app.camera.look_at(p+Vector3.UP*1.6);app.yaw=app.camera.rotation.y;app.pitch=app.camera.rotation.x
		await create_timer(.6).timeout
		var row: Dictionary=FrontierExpeditionBusiness.site(app.session.authority.world).buildings[kind]
		check(row.get("working",false),kind+" actual processing")
		var parts: Array=app.surface_world.business_view.nodes[kind].get_meta("parts")
		check(not parts.is_empty(),kind+" Blender mechanism connected")
		var part: Node3D=parts[0];var before:=part.transform
		await create_timer(.16).timeout;check(part.transform!=before,kind+" mechanism moves")
		check(app.feedback.audio.emitters.has(kind),kind+" positional work sound")
		await capture(kind+"-working")
	# Record the real SFX bus rather than a synthetic mix, including a complete loop boundary.
	var recorder:=AudioEffectRecord.new();var bus:=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,recorder)
	recorder.set_recording_active(true);await create_timer(6.5).timeout;recorder.set_recording_active(false)
	var recording:=recorder.get_recording();recording.save_to_wav(folder+"/facility-runtime.wav");AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	check(recording.get_length()>6,"facility SFX bus recorded across loop boundary")
	site=FrontierExpeditionBusiness.site(app.session.authority.world);site.inventory.ice=0
	await create_timer(1.1).timeout
	site=FrontierExpeditionBusiness.site(app.session.authority.world)
	check(not site.buildings.water.working and "얼음" in site.buildings.water.status,"water immediately waits without ice")
	check(not site.buildings.biolab.working,"biolab stops without feedstock")
	var p:=FrontierExpeditionBusiness.point(site.buildings.water.position)
	var viewer:=p+Vector3(4,0,4);viewer.y=app.surface_world.terrain.field.height(viewer.x,viewer.z)+.2;move_to(viewer)
	app.test_camera_position=p+Vector3(6,4.4,6);await create_timer(.3).timeout;app.camera.look_at(p+Vector3.UP*1.6);app.yaw=app.camera.rotation.y;app.pitch=app.camera.rotation.x
	await create_timer(.5).timeout
	check(not app.feedback.audio.emitters.has("water"),"missing-input facility loses its work loop")
	await capture("water-waiting")
	app.session.send_request("business_toggle",{"building_id":"water"})
	check(not FrontierExpeditionBusiness.site(app.session.authority.world).buildings.water.enabled,"host toggle disables facility")
	var isolated: Dictionary=app.session.authority.world.duplicate(true)
	var fixture:=FrontierExpeditionBusiness.site(isolated)
	verify_completed_facilities(isolated)
	fixture.buildings.solar.enabled=false;fixture.buildings.solar2.enabled=false
	FrontierExpeditionIndustry.power(isolated,fixture);FrontierExpeditionIndustry.environment(isolated,fixture,1)
	check(not fixture.buildings.atmosphere.active and not fixture.buildings.atmosphere.working,"power loss stops facility")
	check(await app.session.close_session(),"operating facility state saved")
	print("FACILITY_OPERATION_FAILURES ",failures);quit(1 if failures else 0)

func verify_completed_facilities(world: Dictionary) -> void:
	var fixture:=FrontierExpeditionBusiness.site(world)
	# Runtime environment values are floats. Integer fixture values otherwise cause
	# a type-only Dictionary difference when cooperative distribution normalizes them.
	fixture.environment.temperature=18.0;fixture.environment.oxygen=.21
	fixture.environment.pressure=1.0;fixture.environment.toxicity=0.0
	FrontierExpeditionIndustry.power(world,fixture);FrontierExpeditionIndustry.environment(world,fixture,1)
	check(not fixture.buildings.thermal.working and not fixture.buildings.atmosphere.working,"completed facilities stop processing")
