extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var output:=SubViewport.new();output.size=Vector2i(1100,1500);output.own_world_3d=true;output.msaa_3d=Viewport.MSAA_4X;output.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(output)
	var scene:=Node3D.new();output.add_child(scene)
	var world:=WorldEnvironment.new();var env:=Environment.new();world.environment=env;scene.add_child(world)
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("9da6ad")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("dae0e5");env.ambient_light_energy=.5
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-25,0);light.light_energy=1.4;light.shadow_enabled=true;scene.add_child(light)
	var cfg: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_details.json"))
	var cache: Dictionary={};var index:=0
	for id in cfg.families:
		for path in cfg.families[id].models:
			var model: Node3D=load(path).instantiate();scene.add_child(model);FrontierInkStyle.apply(model,cache)
			model.position=Vector3((index%4-1.5)*1.5,0,(index/4-4)*1.4);index+=1
	var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(100,100);ground.mesh=plane;ground.position.y=-.04
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("929ca4");ground.material_override=FrontierInkStyle.material(mat,cache);scene.add_child(ground)
	var camera:=Camera3D.new();scene.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=11.7;camera.current=true;camera.look_at_from_position(Vector3(0,15,9),Vector3.ZERO)
	FrontierInkStyle.attach(scene,true)
	for i in 20:await process_frame
	await RenderingServer.frame_post_draw
	output.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/production/media/surface-details/godot-catalog.png"))
	print("INK_SURFACE_CATALOG ",index);quit()
