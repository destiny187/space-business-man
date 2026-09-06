extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,800)
	var scene: PackedScene = load("res://scenes/app/main.tscn")
	var app: Node = scene.instantiate()
	root.add_child(app)
	await process_frame
	var destination: String = ProjectSettings.globalize_path("res://../test-results/screenshots")
	DirAccess.make_dir_recursive_absolute(destination)
	await capture(destination,"title")
	app.smoke_mode = true
	app._smoke_setup()
	await create_timer(1).timeout
	await capture(destination,"field_orbit")
	app.world.toggle_camera()
	app.world.player.rotation.y = -0.55
	app.world.head.rotation.x = -0.1
	app._update_hud()
	await capture(destination,"field_first_person")
	for page in ["earth","technology","build","robots","planet","journal","settings","pause","help","cargo"]:
		app._show_menu(page)
		await capture(destination,page)
	app.campaign.planet.player.position = app.campaign.planet.events[3].position.duplicate()
	app.campaign.discover(app.campaign.planet.events[3].id)
	app.selected_event = app.campaign.planet.events[3].id
	app._show_menu("event")
	await capture(destination,"civilization")
	app._close_menu()
	app.world.toggle_camera()
	app.campaign.planet.environment = {"oxygen":0.21,"pressure":1.0,"toxicity":0,"temperature":18,"water":100,"ecology":100,"stable_seconds":120}
	app.world.sync()
	app._update_hud()
	await capture(destination,"restored_planet")
	root.size = Vector2i(960,640)
	app._show_menu("settings")
	await capture(destination,"settings_960")
	root.size = Vector2i(1920,1080)
	app._show_menu("earth")
	await capture(destination,"earth_1920")
	print("UI_CAPTURE_COMPLETE ",destination)
	quit()

func capture(destination: String,label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png(destination.path_join(label+".png"))
	assert(result == OK)
	print("CAPTURE ",label)
