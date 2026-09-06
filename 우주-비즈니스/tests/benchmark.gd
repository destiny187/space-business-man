extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,800)
	var app: Node = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(app)
	app.smoke_mode = true
	app._smoke_setup()
	var sample: Dictionary = app.campaign.planet.robots[0].duplicate(true)
	for i in range(29):
		var robot: Dictionary = sample.duplicate(true)
		robot.id = "benchmark_"+str(i)
		robot.position = [float(i%6)*4-12,float(i/6)*4+20]
		robot.path = []
		app.campaign.planet.robots.append(robot)
	app.campaign.planet.environment = {"oxygen":0.21,"pressure":1.0,"toxicity":0,"temperature":18,"water":100,"ecology":100,"stable_seconds":120}
	app.world.sync()
	await create_timer(2.0).timeout
	var frames: Array[float] = []
	var last: int = Time.get_ticks_usec()
	for i in range(180):
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append((now-last)/1000.0)
		last = now
	frames.sort()
	var sum: float = 0
	for value in frames: sum += value
	var report := {"version":"1.2.0","quality":app.world.graphics_key,"vsync":true,"simulation_running":true,"renderer":RenderingServer.get_video_adapter_name(),"robots":app.campaign.planet.robots.size(),"ecology":100,"resolution":[1280,800],"mean_ms":sum/frames.size(),"p95_ms":frames[int(frames.size()*0.95)],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../test-results"))
	var file := FileAccess.open("res://../test-results/performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("RENDER_BENCHMARK ",JSON.stringify(report))
	app._shutdown()
