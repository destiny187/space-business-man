extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,900);root.msaa_3d=Viewport.MSAA_4X;root.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
	var stage:=Node3D.new();root.add_child(stage)
	var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("182b30");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("bfd6dc");env.ambient_light_energy=.55;environment.environment=env;stage.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-42,-32,0);sun.light_energy=1.3;sun.shadow_enabled=true;stage.add_child(sun)
	var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(200,200);floor_mesh.mesh=plane
	var material:=StandardMaterial3D.new();material.albedo_color=Color("63767a");floor_mesh.material_override=FrontierInkStyle.material(material,{});stage.add_child(floor_mesh)
	var definitions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/crew_stations.json")).stations
	var nodes: Array=[]
	for key in definitions:
		var station:=FrontierCrewStation.new();stage.add_child(station);station.configure(key,definitions[key]);station.position.x=-1.65 if key=="augmentation" else 1.65;nodes.append(station)
	var camera:=Camera3D.new();camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=7.4;camera.near=.03;stage.add_child(camera);FrontierInkStyle.attach(stage,true)
	camera.position=Vector3(5,3.8,8);camera.look_at(Vector3(0,1.2,0))
	var directory:=ProjectSettings.globalize_path("res://../docs/production/media/crew-stations")
	for pose in ["idle","inspection"]:
		for node in nodes:node.present(.6,pose=="inspection")
		await create_timer(.5).timeout
		for i in 8:await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory+"/stations-ink-"+pose+".png")
		print("STATION_RENDER ",pose)
	quit()
