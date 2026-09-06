extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,800)
	var app: FrontierSpaceFlight=load("res://scenes/app/exploration.tscn").instantiate()
	root.add_child(app)
	app.set_physics_process(false)
	for i in 60:await process_frame
	var samples: Array[float]=[]
	var start:=Time.get_ticks_usec()
	for i in 240:
		var before:=Time.get_ticks_usec()
		app.speed=40
		app.step_flight(1.0/60.0)
		await process_frame
		samples.append((Time.get_ticks_usec()-before)/1000.0)
	var average: float=(Time.get_ticks_usec()-start)/1000.0/samples.size()
	samples.sort()
	var result: Dictionary={"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"resolution":[1280,800],"frames":samples.size(),"mean_frame_ms":average,"p95_frame_ms":samples[int(samples.size()*.95)],"static_memory_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"logical_planets":app.state.manifest.settings.planet_count,"active_planets":app.planets.size(),"scope":"single local ship and four orbital planets, no ground or multiplayer"}
	var path:=ProjectSettings.globalize_path("res://../test-results/space-flight/benchmark.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("SPACE_BENCHMARK ",JSON.stringify(result))
	app.queue_free();await process_frame;quit()
