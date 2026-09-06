extends SceneTree
var checks:=0
var failures:=0
var samples: Array[float]=[]
var previous_time:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+label)
func measure_frame() -> void:
	var now:=Time.get_ticks_usec()
	if previous_time:samples.append((now-previous_time)/1000.0)
	previous_time=now
func ready(app: FrontierPlanetExploration) -> bool:
	var until:=Time.get_ticks_msec()+25000
	while Time.get_ticks_msec()<until:
		await process_frame
		if app.terrain.jobs.is_empty() and app.terrain.chunks.size()==app.terrain.wanted.size() and app.terrain.batch.is_empty():return true
	return false
func run() -> void:
	if "--exploration-test" not in OS.get_cmdline_user_args():
		printerr("Required isolated-save flag: -- --exploration-test");quit(1);return
	root.size=Vector2i(1280,800)
	var store:=FrontierWorldStore.new("user://test_exploration_ui.json")
	var state:=FrontierUniverse.new_world(71491)
	check(store.write(state),"isolated world")
	var app: FrontierPlanetExploration=load("res://scenes/app/planet_exploration.tscn").instantiate()
	root.add_child(app);current_scene=app
	check(await ready(app),"player and courier interests load")
	check(app.courier.wheels.size()==6,"six independent wheel pivots")
	check(not app.courier.request_pickup(),"empty hands cannot create cargo")
	app.movement_input=Vector2(0,-1)
	var until:=Time.get_ticks_msec()+25000
	while Time.get_ticks_msec()<until and app.player.position.x<82:
		var t: float=clampf((app.player.position.x+4-14)/82,0,1)
		var direction:=Vector2(4,sin(t*PI)*5-app.player.position.z).normalized()
		app.player.rotation.y=atan2(-direction.x,-direction.y)
		await physics_frame
	app.movement_input=Vector2.ZERO
	check(app.player.position.x>=82,"player physically reaches underground pickup")
	app.head.rotation.x=0;app.player.rotation.y=-PI
	await physics_frame
	check(app.dig(),"real excavation creates a carried rock sample")
	check(await ready(app),"excavated collision settles")
	check(app.logistics.hand_rock==1,"one sample recorded")
	check(app.courier.request_pickup(),"dispatch courier to actual player position")
	process_frame.connect(measure_frame)
	until=Time.get_ticks_msec()+55000
	while Time.get_ticks_msec()<until and app.logistics.robot.cargo==0:
		if app.player.position.distance_to(app.courier.position)>2:app.player.look_at(Vector3(app.courier.position.x,app.player.position.y,app.courier.position.z))
		await physics_frame
	process_frame.disconnect(measure_frame)
	check(app.logistics.robot.cargo==1 and app.logistics.hand_rock==0,"physical rendezvous transfers cargo once")
	check(app.courier.position.y<-15,"courier enters underground using generated route")
	check(absf(app.courier.wheels[0].rotation.x)>.1,"travel rotates real wheel geometry")
	var output:=ProjectSettings.globalize_path("res://../test-results/courier")
	DirAccess.make_dir_recursive_absolute(output)
	await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/pickup.png")==OK,"actual underground rendezvous capture")
	app.save_surface()
	var restored:=store.read_state()
	check(restored.surface_logistics[app.body_id].robot.cargo==1,"mid-delivery cargo persists")
	app.queue_free();await process_frame
	app=load("res://scenes/app/planet_exploration.tscn").instantiate();root.add_child(app);current_scene=app
	check(await ready(app),"world and courier reopen with independent interests")
	until=Time.get_ticks_msec()+55000
	while Time.get_ticks_msec()<until and app.logistics.depot_rock==0:await physics_frame
	check(app.logistics.depot_rock==1 and app.logistics.robot.cargo==0 and app.logistics.hand_rock==0,"restored courier returns and deposits without duplication")
	check(app.logistics.deliveries==1,"delivery counted once")
	check(app.courier.position.distance_to(Vector3(-4,2.75,4))<3,"cargo was transported to physical depot")
	await create_timer(2).timeout
	check(app.logistics.depot_rock==1 and app.logistics.deliveries==1,"idle frames do not repeat unloading")
	samples.sort()
	var measurement: Dictionary={"scope":"one player and one courier, underground pickup, concurrently used local M2","frames":samples.size(),"mean_ms":0.0,"p95_ms":0.0,"static_memory_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,"path":app.courier.path_metrics}
	if not samples.is_empty():
		for value in samples:measurement.mean_ms+=value/samples.size()
		measurement.p95_ms=samples[mini(samples.size()-1,ceili(samples.size()*.95)-1)]
	FileAccess.open(output+"/measurement.json",FileAccess.WRITE).store_string(JSON.stringify(measurement,"\t"))
	print("COURIER_MEASUREMENT ",JSON.stringify(measurement))
	print("COURIER_CHECKS ",checks," FAILURES ",failures," position=",app.courier.position," status=",app.courier.reason)
	app.queue_free();await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(store.path+suffix):DirAccess.remove_absolute(store.path+suffix)
	quit(1 if failures else 0)
