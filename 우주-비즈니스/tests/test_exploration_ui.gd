extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:failures+=1;printerr("FAIL: "+message)
func run() -> void:
	root.size=Vector2i(1280,800)
	var main: Node=load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	await process_frame
	var launch: Button
	for item in main.find_children("*","Button",true,false):
		if item.text=="우주 탐험  →":launch=item
	check(launch!=null,"main menu exposes 3D exploration")
	if launch==null:quit(1);return
	launch.pressed.emit()
	for i in 30:
		await process_frame
		if current_scene is FrontierSpaceFlight:break
	var app:=current_scene as FrontierSpaceFlight
	check(app!=null,"main menu launches actual flight scene")
	if app==null:quit(1);return
	app.set_physics_process(false)
	await process_frame
	await process_frame
	check(app.planets.size()==4,"only local system is rendered")
	check(app._flight_basis(Vector3.UP).is_finite() and app._flight_basis(Vector3.DOWN).is_finite(),"polar approaches keep valid orientation")
	check(app.ship.get_child_count()>0,"actual ship model aboard 3D scene")
	var path:=ProjectSettings.globalize_path("res://../test-results/space-flight")
	DirAccess.make_dir_recursive_absolute(path)
	await capture(path,"departure")
	var before:=app.ship.position
	app.speed=100
	for i in 10:app.step_flight(.1)
	check(app.ship.position.distance_to(before)>99,"thrust moves through 3D space")
	app._select(0);app.start_travel()
	for i in 2000:
		app.step_flight(.05)
		if not app.autopilot:break
	check(not app.autopilot and app.state.visited.has(FrontierUniverse.body_id(app.state.manifest,0)),"continuous approach reaches surveyed orbit")
	check(app.travel_distance>1000,"flight covers actual local distance")
	var p: Dictionary=app.planets[0]
	check(app.ship.position.distance_to(p.node.position)>p.radius+90,"arrival stays outside terrain")
	await capture(path,"orbit")
	app._select(999999);app.start_travel()
	for i in 10:app.step_flight(.1)
	await capture(path,"jump")
	check(app.jump_remaining>0 and app.camera.fov>65,"jump has animated travel state")
	check(not app.cursor_label.visible,"jump hides stale markers from departed orbit")
	for i in 50:app.step_flight(.1)
	await process_frame
	check(app.current_system==249999 and app.planets.size()==4,"last of one million targets streams bounded system")
	check(app.planets.has(999999),"selected distant planet exists in 3D")
	app.save_flight()
	check(app.store.read_state().flight_position==app.state.flight_position,"save restores actual local ship position")
	app.address.text="1000001";var target:=app.target_ordinal;app._address_target()
	check(app.target_ordinal==target,"invalid target cannot start travel")
	await capture(path,"distant_system")
	root.size=Vector2i(960,640)
	await capture(path,"compact")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(app.store.path+suffix):DirAccess.remove_absolute(app.store.path+suffix)
	app.queue_free();await process_frame
	print("SPACE_FLIGHT_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
func capture(path: String,id: String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(path.path_join(id+".png"))==OK,"capture "+id)
