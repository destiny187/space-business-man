extends SceneTree

# A frozen, deterministic 30-robot scene isolates rendering from simulation.
# Run without VSync to expose headroom, with identical cameras for every preset.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,800)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var label: String = "balanced"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--label="): label = argument.trim_prefix("--label=")
	if not FrontierGraphics.data().profiles.has(label):
		push_error("Select performance, balanced or high; the historical before capture is immutable.")
		quit(1)
		return
	var app: Node = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(app)
	app.smoke_mode = true
	app._smoke_setup()
	var sample: Dictionary = app.campaign.planet.robots[0].duplicate(true)
	for i in range(29):
		var robot: Dictionary = sample.duplicate(true)
		robot.id = "render_"+str(i)
		robot.position = [float(i%6)*4-12,float(i/6)*4+20]
		robot.path = []
		app.campaign.planet.robots.append(robot)
	app.campaign.planet.environment = {"oxygen":0.21,"pressure":1.0,"toxicity":0,"temperature":18,"water":100,"ecology":100,"stable_seconds":120}
	app.world.sync()
	app.ui.hide()
	app.set_process(false)
	app.world.set_process(false)
	app.world.set_physics_process(false)
	app.world.controls_enabled = false
	if label != "before" and app.world.has_method("apply_graphics"):
		app.world.apply_graphics(label)
	var destination: String = ProjectSettings.globalize_path("res://../test-results/graphics/"+label)
	DirAccess.make_dir_recursive_absolute(destination)
	var results: Array = []
	for shot in [
		["settlement",Vector3(23,19,29),Vector3(0,0,-3)],
		["materials",Vector3(7,3.8,10),Vector3(0,1.7,0)],
		["water",Vector3(-27,6,-27),Vector3(-43,0,-46)],
		["landscape",Vector3(5,2.3,4),Vector3(-35,5,-55)]
	]:
		app.world.orbital_camera.position = shot[1]
		app.world.orbital_camera.look_at(shot[2])
		await create_timer(3.0).timeout
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(destination.path_join(shot[0]+".png")) == OK)
		var frames: Array[float] = []
		var gpu_times: Array[float] = []
		var cpu_sum: float = 0
		var last: int = Time.get_ticks_usec()
		for i in range(240):
			await process_frame
			var now: int = Time.get_ticks_usec()
			frames.append((now-last)/1000.0)
			gpu_times.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			cpu_sum += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
			last = now
		frames.sort()
		gpu_times.sort()
		var gpu_sum: float = 0
		for value in gpu_times: gpu_sum += value
		var sum: float = 0
		for value in frames: sum += value
		results.append({"view":shot[0],"gpu_mean_ms":gpu_sum/240.0 if gpu_sum > 0 else null,"gpu_p95_ms":gpu_times[228] if gpu_sum > 0 else null,"render_cpu_mean_ms":cpu_sum/240.0,"mean_ms":sum/frames.size(),"p95_ms":frames[228],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	var report: Dictionary = {"label":label,"gpu":RenderingServer.get_video_adapter_name(),"resolution":[1280,800],"vsync":false,"frozen_simulation":true,"robots":30,"ecology":100,"samples_per_view":240,"views":results}
	var file := FileAccess.open(destination.path_join("performance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("RENDER_CAPTURE ",JSON.stringify(report))
	app._shutdown()
