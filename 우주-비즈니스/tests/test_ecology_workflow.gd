extends "res://tests/test_ecology_ui.gd"
## End-to-end resources and real scene transitions; test movement places the player at controlled sites.
func harvest(app: FrontierPlanetExploration,amount: int) -> bool:
	app.set_physics_process(false)
	for index in amount:
		var z: float=-float(index)*5
		app.player.position=Vector3(0,app.terrain.field.height(0,z)+1.1,z)
		app.player.velocity=Vector3.ZERO;app.player.rotation.y=-PI/2;app.head.rotation.x=-.4;app.camera.rotation=Vector3.ZERO
		if not await ready_world(app):return false
		if not app.dig():printerr("HARVEST_MISS ",index," ",app.message.text);return false
		if not await ready_world(app):return false
	check(int(app.logistics.hand_rock)==amount,"physical excavations create exactly one unit each")
	if not app.courier.request_pickup():return false
	var deadline:=Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline and int(app.logistics.depot_rock)<amount:await physics_frame
	check(app.logistics.depot_rock==amount and app.logistics.hand_rock==0 and app.logistics.robot.cargo==0,"physical courier conserves mined resources on delivery")
	if int(app.logistics.depot_rock)!=amount:
		printerr("HARVEST_COURIER ",app.courier.reason," ",app.courier.position);return false
	app.player.position=Vector3(0,3,0);app.player.rotation=Vector3.ZERO;app.head.rotation=Vector3(-.1,0,0);app.camera.rotation=Vector3.ZERO
	return await ready_world(app)

func run() -> void:
	if "--exploration-test" not in OS.get_cmdline_user_args():printerr("FAIL: isolated test flag required");quit(1);return
	root.size=Vector2i(1280,800)
	var world:=FrontierUniverse.new_world(71491)
	world.location=FrontierUniverse.body_id(world.manifest,15)
	world.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"))
	world.terrain_settings_hash=FrontierUniverse.fingerprint(world.terrain_settings)
	world.surface_positions={world.location:[0,4,0]};world.mode="surface"
	var store:=FrontierWorldStore.new("user://test_exploration_ui.json")
	check(store.write(world),"new expedition starts without granted materials or specimens")
	var app: FrontierPlanetExploration=load("res://scenes/app/planet_exploration.tscn").instantiate();root.add_child(app);current_scene=app
	check(await ready_world(app),"source planet loads")
	var mined: bool=await harvest(app,3)
	check(mined,"mine and physically deliver experimental material on planet A")
	if not mined:await finish(app,store);return
	var observed: Dictionary={}
	for row in app.ecology_view.encounters.values():
		if row.layer!="surface" or row.status!="active":continue
		for direction in 8:
			face(app,row,2,float(direction)*TAU/8);await physics_frame
			if app.ecology_view.target(app.camera).get("id")==row.id:observed=row;break
		if not observed.is_empty():break
	check(not observed.is_empty(),"seeded native life remains observable after terrain edits")
	if observed.is_empty():await finish(app,store);return
	check(app.ecology_action("scan") and app.ecology_action("collect"),"scanned source specimen enters actual expedition cargo")
	var sample_id: String=app.state.ecology.specimens.keys()[0]
	app.player.position=Vector3(0,3,0)
	check(app.ecology_action("analyze",observed.form_id) and app.logistics.depot_rock==0,"research consumes only the three actually mined units")
	app.return_to_orbit()
	for i in 40:
		await process_frame
		if current_scene is FrontierSpaceFlight:break
	var flight:=current_scene as FrontierSpaceFlight
	check(flight!=null,"source planet departure opens actual 3D ship flight")
	if flight==null:await finish(current_scene,store);return
	flight.set_physics_process(false);flight._select(21);flight.start_travel()
	for step in 3000:
		flight.step_flight(.05)
		if flight.jump_remaining<=0 and not flight.autopilot:break
	check(flight.current_system==5 and flight.land(),"ship travels to another star system and physically approaches destination before landing")
	for i in 40:
		await process_frame
		if current_scene is FrontierPlanetExploration:break
	app=current_scene as FrontierPlanetExploration
	check(app!=null and FrontierUniverse.ordinal_of(app.state.manifest,app.body_id)==21,"destination scene preserves selected million-address planet identity")
	if app==null:await finish(current_scene,store);return
	check(await ready_world(app),"destination planet loads through real flight handoff")
	check(app.state.ecology.specimens[sample_id].state=="cargo" and app.logistics.depot_rock==0,"unique specimen travels with ship while local mine depot stays on its planet")
	mined=await harvest(app,6)
	check(mined,"mine and physically deliver habitat construction materials on planet B")
	if not mined:await finish(app,store);return
	check(app.ecology_action("restore","basalt") and app.logistics.depot_rock==0,"local habitat consumes the six newly mined units")
	check(app.ecology_action("introduce",sample_id),"researched transported specimen establishes on compatible destination")
	await create_timer(3).timeout
	check(app.ecology_view.actors.has(sample_id),"destination renders the original transported authored form")
	app.save_surface()
	var saved:=store.read_state()
	check(saved.ecology.specimens[sample_id].destination==app.body_id and saved.terrain_edits.size()==2,"ecology and both planets' physical excavation histories persist together")
	print("ECOLOGY_WORKFLOW_CHECKS ",checks," FAILURES ",failures," mined=9 granted=0 planets=16,22")
	await finish(app,store)

func finish(app: Node,store: FrontierWorldStore) -> void:
	if is_instance_valid(app):app.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(store.path+suffix):DirAccess.remove_absolute(store.path+suffix)
	quit(1 if failures else 0)
