extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,800);root.content_scale_size=root.size;root.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
	var stage:=Node3D.new();root.add_child(stage);current_scene=stage
	var room:Node3D=load("res://assets/models/crew/kestrel_cabin.glb").instantiate();stage.add_child(room);FrontierInkStyle.apply(room,{})
	var defs:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/crew_stations.json")).stations
	for key in defs:
		var node:=FrontierCrewStation.new();stage.add_child(node);node.configure(key,defs[key]);node.position=FrontierCrewWorld.vector(defs[key].cabin_position);node.rotation.y=deg_to_rad(float(defs[key].cabin_yaw))
	var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("152b39");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("89aaa8");env.ambient_light_energy=.4;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var environment:=WorldEnvironment.new();environment.environment=env;stage.add_child(environment)
	for z in [-5,1,6]:
		var lamp:=OmniLight3D.new();lamp.position=Vector3(0,3.4,z);lamp.light_color=Color("e3edcd");lamp.light_energy=1.25;lamp.omni_range=7;lamp.shadow_enabled=true;stage.add_child(lamp)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-28,-30,0);sun.light_energy=.25;sun.light_color=Color("c8e5ed");stage.add_child(sun)
	var camera:=Camera3D.new();stage.add_child(camera);camera.fov=76;camera.current=true;FrontierInkStyle.attach(camera)
	var folder:=ProjectSettings.globalize_path("res://../output/advanced-hulls/interior-audit/")
	DirAccess.make_dir_recursive_absolute(folder)
	for shot in [{"id":"front","position":Vector3(0,1.72,4),"target":Vector3(0,1.72,-7.7)},{"id":"aft","position":Vector3(0,1.72,1),"target":Vector3(0,1.6,7.8)},{"id":"research","position":Vector3(0,1.72,2.2),"target":Vector3(3,1.3,4.2)}]:
		camera.position=shot.position;camera.look_at(shot.target)
		await create_timer(.65).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+shot.id+".png");print("CABIN_AUDIT_RENDER ",shot.id)
	quit()
