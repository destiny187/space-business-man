extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:failures+=1;printerr("FAIL: "+message)
func ready_world(app: FrontierPlanetExploration) -> bool:
	var deadline:=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if app.terrain.jobs.is_empty() and app.terrain.chunks.size()==app.terrain.wanted.size() and app.terrain.batch.is_empty():
			await create_timer(2).timeout
			return true
	return false
func capture(id: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	var directory:=ProjectSettings.globalize_path("res://../test-results/ecology")
	DirAccess.make_dir_recursive_absolute(directory)
	check(root.get_texture().get_image().save_png(directory.path_join(id+".png"))==OK,"capture "+id)
func face(app: FrontierPlanetExploration,row: Dictionary,distance: float=6,angle: float=0) -> void:
	var form:=FrontierEcologyCatalog.form(row.form_id)
	var height: float=(form.geometry.near.max[1]-form.geometry.near.floor_y)*FrontierEcologyCatalog.look(form.id,row.look_id).scale
	app.player.position=row.point+Vector3(sin(angle)*distance,1.5,cos(angle)*distance)
	if row.layer=="surface":app.player.position.y=app.terrain.field.height(app.player.position.x,app.player.position.z)+1.5
	app.player.velocity=Vector3.ZERO
	app.player.rotation.y=0
	app.camera.look_at(row.point+Vector3.UP*maxf(.35,height*.5),Vector3.UP)
func run() -> void:
	if "--exploration-test" not in OS.get_cmdline_user_args():printerr("FAIL: isolated test flag required");quit(1);return
	root.size=Vector2i(1280,800)
	var world:=FrontierUniverse.new_world(71491)
	world.location=FrontierUniverse.body_id(world.manifest,15)
	world.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"))
	world.terrain_settings_hash=FrontierUniverse.fingerprint(world.terrain_settings)
	world.surface_positions={world.location:[0,4,0]};world.mode="surface"
	world.surface_logistics={world.location:FrontierSurfaceLogistics.create()};world.surface_logistics[world.location].depot_rock=40
	var store:=FrontierWorldStore.new("user://test_exploration_ui.json")
	check(store.write(world),"isolated seeded world written")
	var app: FrontierPlanetExploration=load("res://scenes/app/planet_exploration.tscn").instantiate()
	root.add_child(app);current_scene=app
	check(await ready_world(app),"terrain and ecology finish loading")
	check(not app.ecology_view.actors.is_empty(),"authored creatures appear in actual planet scene")
	check(app.ecology_view.actors.size()<=int(FrontierEcologyCatalog.config().max_actors),"visible population obeys actor budget")
	var encounter: Dictionary={}
	app.set_physics_process(false)
	var options: Array=app.ecology_view.encounters.values()
	options.sort_custom(func(a: Dictionary,b: Dictionary):return int(FrontierEcologyCatalog.form(a.form_id).category=="animal")>int(FrontierEcologyCatalog.form(b.form_id).category=="animal"))
	for row in options:
		if row.layer!="surface" or row.status!="active":continue
		for direction in 8:
			face(app,row,6,float(direction)*TAU/8)
			await physics_frame
			if app.ecology_view.target(app.camera).get("id")==row.id:encounter=row;break
		if not encounter.is_empty():break
	check(not encounter.is_empty(),"suitable native creature is visible from a physically clear viewpoint")
	if encounter.is_empty():app.queue_free();await process_frame;quit(1);return
	await create_timer(.5).timeout
	check(app.ecology_view.target(app.camera).get("id")==encounter.id,"scanner targets actual visible rendered creature")
	var actor: Node3D=app.ecology_view.actors[encounter.id]
	check(actor.models.size()==2 and actor.models[0].visible,"near and far authored LODs load with near active")
	actor.lod_override=1;await process_frame;await process_frame
	check(actor.models[1].visible and not actor.models[0].visible,"far LOD replaces near geometry")
	actor.lod_override=-1;await process_frame;await process_frame
	await capture("native-scan")
	app.scan_held=true
	await create_timer(1.9).timeout
	check(app.state.ecology.observations.size()==1,"holding scan completes real timed observation")
	check(store.read_state().get("ecology",{}).get("observations",{}).size()==1,"scan persists before success feedback")
	if app.state.ecology.observations.is_empty():app.queue_free();await process_frame;quit(1);return
	var saved_position:=app.player.position
	var saved_camera:=app.camera.global_transform
	app.camera.rotate_y(PI)
	check(app.ecology_view.target(app.camera).is_empty(),"scanner does not select creatures behind the camera")
	app.camera.global_transform=saved_camera
	app.player.position=encounter.point-Vector3.UP*4
	app.camera.look_at(encounter.point+Vector3.UP,Vector3.FORWARD)
	await physics_frame
	check(app.ecology_view.target(app.camera).is_empty(),"scanner cannot see through the solid terrain floor")
	app.player.position=Vector3(0,3,0)
	var before_failure: Dictionary=app.state.duplicate(true)
	app.store=FrontierWorldStore.new("user://ecology_missing_directory_for_test/world.json")
	check(not app.ecology_action("analyze",encounter.form_id) and app.state==before_failure,"failed durable transaction preserves research and supplies")
	app.store=store
	app.player.position=saved_position;app.camera.global_transform=saved_camera
	var id: String=encounter.form_id
	for direction in 8:
		face(app,encounter,2.0,float(direction)*TAU/8);await physics_frame
		if app.ecology_view.target(app.camera).get("id")==encounter.id:break
	check(app.ecology_action("collect"),"in-range scanned creature becomes one physical cargo specimen")
	var sample_id: String=app.state.ecology.specimens.keys()[0] if not app.state.ecology.specimens.is_empty() else ""
	await create_timer(1).timeout
	check(not app.ecology_view.actors.has(encounter.id),"collected model despawns without duplicate resource")
	app.player.position=Vector3(0,3,0)
	app.camera.rotation=Vector3.ZERO
	check(app.ecology_action("analyze",id),"near-ship analysis uses stored material")
	app.toggle_journal();await process_frame
	await capture("research-cargo")
	check(app.journal.visible and app.journal.form_ids.has(id) and app.journal.sample_ids.has(sample_id),"journal exposes scanned lineage and real cargo")
	check(app.journal.get_global_rect().position.x>=0 and app.journal.get_global_rect().position.y>=0 and app.journal.get_global_rect().end.x<=root.size.x and app.journal.get_global_rect().end.y<=root.size.y,"journal fits 1280x800 viewport")
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640)
	await process_frame;await process_frame
	var rect:=app.journal.get_global_rect()
	check(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=960 and rect.end.y<=640,"journal fits minimum 960x640 window")
	await capture("journal-small")
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	await process_frame;await process_frame
	app.toggle_journal()
	# Save, reload a second planet through the same persistent world and inspect the real actor there.
	app.save_surface()
	var travel:=store.read_state()
	travel.location=FrontierUniverse.body_id(travel.manifest,21)
	travel.surface_positions[travel.location]=[0,4,0]
	travel.surface_logistics[travel.location]=FrontierSurfaceLogistics.create();travel.surface_logistics[travel.location].depot_rock=20
	check(store.write(travel),"travel preserves original ecology and physical cargo")
	app.queue_free();await process_frame
	app=load("res://scenes/app/planet_exploration.tscn").instantiate();root.add_child(app);current_scene=app
	check(await ready_world(app),"second planet terrain loads")
	app.set_physics_process(false);app.player.position=Vector3(0,3,0);app.player.rotation.y=0;app.camera.rotation=Vector3.ZERO
	check(app.ecology_action("restore","basalt"),"player installs actual local restoration area")
	check(app.ecology_action("introduce",sample_id),"cargo specimen transfers into destination plot")
	await create_timer(2).timeout
	check(app.ecology_view.actors.has(sample_id),"transplanted authored creature renders on planet B")
	if app.ecology_view.encounters.has(sample_id):face(app,app.ecology_view.encounters[sample_id],7)
	await physics_frame;await capture("transplanted")
	check(app.state.ecology.planets[app.body_id].plot.biomass>0,"actual play advances plot biomass")
	app.save_surface()
	var persisted:=store.read_state()
	check(persisted.ecology.specimens[sample_id].state=="introduced" and persisted.ecology.specimens[sample_id].destination==app.body_id,"A to B transfer survives save with one specimen identity")
	print("ECOLOGY_RENDER_METRICS actors=",app.ecology_view.actors.size()," max_load_ms=",app.ecology_view.max_load_ms," max_refresh_ms=",app.ecology_view.max_refresh_ms)
	app.queue_free();await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(store.path+suffix):DirAccess.remove_absolute(store.path+suffix)
	print("ECOLOGY_UI_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
