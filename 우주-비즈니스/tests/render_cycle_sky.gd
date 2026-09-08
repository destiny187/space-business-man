extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,800);root.msaa_3d=Viewport.MSAA_4X;root.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
	var stage:=Node3D.new();root.add_child(stage)
	var camera:=Camera3D.new();camera.current=true;camera.fov=90;stage.add_child(camera)
	var light:=DirectionalLight3D.new();stage.add_child(light)
	var environment:=Environment.new();environment.background_mode=Environment.BG_SKY;environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var world:=WorldEnvironment.new();world.environment=environment;stage.add_child(world)
	var manifest:=FrontierUniverse.generate(71491);var body:=FrontierUniverse.body(manifest,61916)
	var air=load("res://scripts/world/surface_atmosphere.gd").new();air.configure(body,environment,light)
	air.configure_cycles(manifest,FrontierPlanetaryCycles.landing_region(body,0),0)
	# Controlled restored-atmosphere fixture, separate from the native thin-atmosphere play capture.
	air.current=air.appearance(body,{"pressure":1.0,"toxicity":0.0,"temperature":18.0,"water":75.0})
	var path:=ProjectSettings.globalize_path("res://../docs/production/media/cycles/")
	DirAccess.make_dir_recursive_absolute(path)
	for phase in [0.0,.25,.5,.75]:
		air.clock_seconds=float(body.astro.mean_solar_seconds)/60*phase;air.update_cycles();air.paint()
		var direction: Vector3=air.sky_state.sun_direction
		if phase==0:camera.look_at(direction,Vector3.RIGHT if absf(direction.y)>.99 else Vector3.UP)
		elif phase!=.5:camera.look_at(Vector3(direction.x,.20,direction.z).normalized())
		await create_timer(.6).timeout;await RenderingServer.frame_post_draw
		print("SKY_SAMPLE ",phase," direction=",direction," camera=",-camera.global_basis.z," radius=",air.material.get_shader_parameter("sun_radius"))
		root.get_texture().get_image().save_png(path+"restored-sky-"+str(int(phase*4))+".png")
	air.clock_seconds=0;air.current.cloud_amount=0.0;air.update_cycles();air.paint()
	camera.look_at(air.sky_state.sun_direction)
	await create_timer(.6).timeout;await RenderingServer.frame_post_draw
	var clear_image:=root.get_texture().get_image()
	clear_image.save_png(path+"clear-sun.png")
	assert(clear_image.get_pixel(640,400).get_luminance()>clear_image.get_pixel(680,400).get_luminance()+.15)
	var original_basis: Basis=air.material.get_shader_parameter("stars_basis")
	var original_cloud: Vector2=air.material.get_shader_parameter("cloud_offset")
	air.clock_seconds+=40;air.update_cycles();air.paint()
	assert(not original_basis.is_equal_approx(air.material.get_shader_parameter("stars_basis")))
	assert(not original_cloud.is_equal_approx(air.material.get_shader_parameter("cloud_offset")))
	var locked:=FrontierUniverse.body(manifest,304)
	air.body=locked;air.sky_region={};air.clock_seconds=0;air.update_cycles();air.paint()
	var before: Vector3=air.sky_state.sun_direction
	air.clock_seconds=float(locked.astro.orbit_seconds)/60*.25;air.update_cycles();air.paint()
	assert(before.distance_to(air.sky_state.sun_direction)<.0001)
	print("CYCLES_SKY_RENDER_OK / sun, cloud flow, inertial stars, synchronous direction")
	quit()
