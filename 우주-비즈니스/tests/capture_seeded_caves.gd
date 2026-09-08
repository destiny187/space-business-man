extends SceneTree
## Uses the game's streamer, collision mesh, terrain shader and INK pass; no user saves.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,800)
	var output:=ProjectSettings.globalize_path("res://../test-results/seeded-caves")
	DirAccess.make_dir_recursive_absolute(output)
	var cfg: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/underground.json"))
	for family in ["sediment","ice"]:
		var stage:=Node3D.new();root.add_child(stage)
		var env:=WorldEnvironment.new();env.environment=Environment.new();stage.add_child(env)
		env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("142333")
		env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color=Color("9facbd");env.environment.ambient_light_energy=.3
		var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-30,0);sun.shadow_enabled=true;stage.add_child(sun)
		var camera:=Camera3D.new();camera.fov=75;camera.far=180;stage.add_child(camera);camera.current=true
		var lamp:=SpotLight3D.new();lamp.light_energy=10;lamp.spot_range=60;lamp.spot_angle=65;camera.add_child(lamp)
		var mat:=ShaderMaterial.new();mat.shader=load("res://assets/materials/space/terrain.gdshader")
		mat.set_shader_parameter("rock_color",Color("72432e") if family=="sediment" else Color("47748e"))
		mat.set_shader_parameter("dust_color",Color("b6764a") if family=="sediment" else Color("b2d8df"))
		var rules: Dictionary=cfg.profiles[family].duplicate(true)
		for key in ["version","region_size","occupancy","maximum_depth"]:rules[key]=cfg[key]
		var terrain:=FrontierTerrainStreamer.new()
		terrain.configure(71491,[],mat,{}, {"underground":rules})
		stage.add_child(terrain);FrontierInkStyle.attach(stage)
		var graph:=terrain.field.caves.system_at(0,0)
		for pose in ["entrance","interior"]:
			var index:=0 if pose=="entrance" else 3
			var start: Vector3=graph.nodes[index];var end: Vector3=graph.nodes[index+1]
			if pose=="interior":end=graph.chambers[0].center
			var radius: float=graph.segments[0].radius
			camera.position=start-(end-start).normalized()*8 if pose=="entrance" else start-Vector3.UP*(radius*.7-1.7)
			camera.look_at(end-Vector3.UP*(radius*.7-1.7))
			terrain.update_interests([camera.position])
			var deadline:=Time.get_ticks_msec()+60000
			while not terrain.ready_for([camera.position]) and Time.get_ticks_msec()<deadline:await process_frame
			if not terrain.ready_for([camera.position]):printerr("FAIL: cave streaming timeout");quit(1);return
			await physics_frame;await physics_frame
			var hit:=stage.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.position,camera.position-Vector3.UP*16))
			if pose=="interior" and hit.is_empty():printerr("FAIL: missing actual cave floor collision");quit(1);return
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output+"/"+family+"-"+pose+".png")
			print("CAVE_RENDER ",family," ",pose," chunks=",terrain.chunks.size()," floor=",not hit.is_empty())
		stage.queue_free();await process_frame
	quit(0)
