extends SceneTree
## Native GPU test: both cameras, moving contours, actual game compositions.
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func frame() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	root.size = Vector2i(1440,900)
	await check_sloping_depth()
	await check_transparent_feedback()
	var dest := ProjectSettings.globalize_path("res://../docs/production/media/ink-catalog/")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="):dest=argument.trim_prefix("--capture-output=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(dest)
	var app: Node = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(app)
	app.smoke_mode = true
	app._smoke_setup()
	app.set_process(false)
	app.world.set_process(false)
	app.world.set_physics_process(false)
	app.world.apply_graphics("high")
	for mode in ["orbit","first-person"]:
		if mode == "first-person":
			app.world.toggle_camera()
			app.world.player.position = Vector3(10,.2,19)
			app.world.player.rotation.y = .4
			app.world.head.rotation.x = -.12
		await create_timer(1.5).timeout
		var ink: Image = await frame()
		app.world.outline.set_shader_parameter("strength",0.)
		var plain: Image = await frame()
		var changed := 0
		# Screen-space contrast, sampled across the full image, proves the quad survives camera changes.
		check(ink.get_size()==plain.get_size(),"comparable render dimensions")
		for y in range(0,mini(ink.get_height(),plain.get_height()),3):
			for x in range(0,mini(ink.get_width(),plain.get_width()),3):
				var a := ink.get_pixel(x,y)
				var b := plain.get_pixel(x,y)
				if b.get_luminance()-a.get_luminance() > .035: changed += 1
		check(changed > 150,"visible contours in "+mode+": "+str(changed))
		app.world.outline.set_shader_parameter("strength",1.)
		ink = await frame()
		check(ink.save_png(dest+"game-"+mode+".png") == OK,"save "+mode)
	app.world.toggle_camera()
	app.campaign.planet.environment.ecology = 85
	app.campaign.planet.environment.water = 80
	app.campaign.planet.environment.toxicity = 5
	app.world.sync()
	app.world.orbital_camera.position = Vector3(-17,19,-12)
	app.world.orbital_camera.look_at(Vector3(-39,0,-40))
	await create_timer(1.5).timeout
	var green: Image = await frame()
	check(green.save_png(dest+"game-ecology.png") == OK,"save living environment")
	app._show_menu("build")
	await create_timer(.5).timeout
	var ui: Image = await frame()
	check(ui.save_png(dest+"game-catalog-ui.png") == OK,"save production previews")
	print("INK_RENDERING_TESTS checks=%d failures=%d" % [checks,failures])
	if failures == 0: app._shutdown()
	else: quit(1)

func check_sloping_depth() -> void:
	# Regression: depth changes rapidly near a perspective horizon, but a plane has no edge.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,512)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2000,2000)
	plane.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(.7,.7,.7)
	plane.material_override = mat
	stage.add_child(plane)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0,1.8,0)
	camera.look_at(Vector3(0,1.65,-10))
	camera.far = 2000
	camera.current = true
	FrontierInkStyle.attach(stage)
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	var shot := viewport.get_texture().get_image()
	var dark := 0
	for y in range(270,350):
		for x in range(100,412):
			if shot.get_pixel(x,y).get_luminance() < .05: dark += 1
	check(dark < 100,"continuous ground avoids false black horizon: "+str(dark))
	viewport.queue_free()
	await process_frame

func check_transparent_feedback() -> void:
	var viewport:=SubViewport.new();viewport.size=Vector2i(256,256);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var stage:=Node3D.new();viewport.add_child(stage)
	var world:=WorldEnvironment.new();var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(.03,.06,.09);world.environment=environment;stage.add_child(world)
	var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(0,0,4);camera.current=true
	var ghost:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(2,2,1);ghost.mesh=box
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_color=Color(1,.04,.02,.7);ghost.material_override=material;stage.add_child(ghost)
	FrontierInkStyle.attach(stage)
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	var shot:=viewport.get_texture().get_image()
	var center:=shot.get_pixel(128,128)
	check(center.r>center.b+.25,"transparent construction ghost survives ink compositing")
	ghost.hide()
	var effects:=FrontierEffects.new();stage.add_child(effects);effects.running=false
	effects.burst(Vector3.ZERO,Color(1,.05,.02),32)
	for effect in effects.active:effect.node.scale=Vector3.ONE*.25
	await create_timer(.2).timeout;await RenderingServer.frame_post_draw
	shot=viewport.get_texture().get_image();center=shot.get_pixel(128,128)
	check(center.r>center.b+.2,"actual pooled effect shader survives ink compositing")
	viewport.queue_free();await process_frame
