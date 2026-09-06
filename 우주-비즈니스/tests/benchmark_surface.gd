extends SceneTree
func _initialize() -> void:call_deferred("run")
func measure(label: String) -> Dictionary:
	for i in 30:await process_frame
	var elapsed: Array[float]=[]
	var result: Dictionary={"label":label,"frames":180,"render_cpu_ms":0.0,"render_gpu_ms":0.0,"process_ms":0.0,"physics_ms":0.0}
	var previous:=Time.get_ticks_usec()
	for i in 180:
		await process_frame
		var now:=Time.get_ticks_usec();elapsed.append((now-previous)/1000.0);previous=now
		result.render_cpu_ms+=(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())+RenderingServer.get_frame_setup_time_cpu())/180
		result.render_gpu_ms+=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())/180
		result.process_ms+=Performance.get_monitor(Performance.TIME_PROCESS)*1000/180
		result.physics_ms+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000/180
	elapsed.sort();result.mean_ms=0.0
	for value in elapsed:result.mean_ms+=value/180
	result.p95_ms=elapsed[170]
	result.draw_calls=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return result
func run() -> void:
	root.size=Vector2i(1280,800)
	var store:=FrontierWorldStore.new("user://test_exploration_ui.json")
	store.write(FrontierUniverse.new_world(71491))
	var app: FrontierPlanetExploration=load("res://scenes/app/planet_exploration.tscn").instantiate();root.add_child(app)
	var until:=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<until:
		await process_frame
		if app.terrain.jobs.is_empty() and app.terrain.chunks.size()==app.terrain.wanted.size():break
	app.player.rotation.y=.5
	app.head.rotation.x=-.2
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var results: Array=[]
	results.append(await measure("full"))
	app.courier.visible=false
	results.append(await measure("diagnostic_without_courier"));app.courier.visible=true
	app.environment.ssao_enabled=false
	results.append(await measure("diagnostic_without_ssao"));app.environment.ssao_enabled=true
	for node in app.camera.get_children():
		if node is SpotLight3D:node.shadow_enabled=false
	results.append(await measure("diagnostic_without_lamp_shadow"))
	var output:=ProjectSettings.globalize_path("res://../test-results/courier")
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output+"/surface_profile.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	print("SURFACE_PROFILE ",JSON.stringify(results))
	app.queue_free();await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(store.path+suffix):DirAccess.remove_absolute(store.path+suffix)
	quit()
