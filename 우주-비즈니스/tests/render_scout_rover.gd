extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1440,1000);root.msaa_3d=Viewport.MSAA_4X;root.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA;root.scaling_3d_scale=1.5
	var stage:=Node3D.new();root.add_child(stage)
	var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("111e24");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("bfd6dc");env.ambient_light_energy=.55;environment.environment=env;stage.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-42,-32,0);sun.light_energy=1.3;sun.shadow_enabled=true;stage.add_child(sun)
	var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(200,200);floor_mesh.mesh=plane
	var material:=StandardMaterial3D.new();material.albedo_color=Color("3f5052");floor_mesh.material_override=FrontierInkStyle.material(material,{});stage.add_child(floor_mesh)
	var rover:=FrontierRoverVisual.new();stage.add_child(rover)
	var camera:=Camera3D.new();camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.5;camera.near=.03;stage.add_child(camera);FrontierInkStyle.attach(stage,true)
	var directory:=ProjectSettings.globalize_path("res://../docs/production/media/rover")
	for view in ["front","rear","mechanisms","cockpit"]:
		camera.position=Vector3(6,4.6,-8) if view!="rear" else Vector3(-6,4.3,8);camera.look_at(Vector3(0,1.3,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		rover.pose(.6,.32,[.08,-.06,0.0,.02],Vector2.ONE if view=="mechanisms" else Vector2.ZERO,1 if view=="mechanisms" else 0)
		if view=="cockpit":camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=86;camera.position=rover.socket("Socket_Eye_Driver");camera.rotation=Vector3(-.13,0,0)
		await create_timer(.4).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory+"/scout-ink-"+view+".png")
		print("SCOUT_RENDER ",view)
	var preview:=FrontierEquipmentPreview.new();root.add_child(preview);preview.size=Vector2(480,480);preview.show_model("vehicles/scout_rover")
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	preview.viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://assets/ui/previews/scout_rover.png"))
	print("SCOUT_MECHANISMS ",rover.mechanisms.size());quit()
