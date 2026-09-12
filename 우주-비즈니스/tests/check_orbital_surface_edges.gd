extends "res://tests/check_orbital_surfaces.gd"
func run() -> void:
	if not "--crew-folder=/tmp/orbital-surface-check" in OS.get_cmdline_user_args():quit(2);return
	folder=ProjectSettings.globalize_path("res://../docs/production/media/orbital-surfaces")
	settings=FrontierClientSettings.ensure(self);settings._preset(1);settings.set_quality("planet_surface",2)
	stage=Node3D.new();root.add_child(stage);current_scene=stage
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-20,0);sun.light_energy=1.8;stage.add_child(sun)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("101923");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_energy=.4;stage.add_child(environment)
	camera=Camera3D.new();camera.far=100000;stage.add_child(camera);camera.make_current()
	manifest=FrontierUniverse.new_world(71503).manifest;factory=FrontierSpaceFlight.new();factory.state={"manifest":manifest}
	var specimens: Array=[{"id":"earth","body":FrontierUniverse.body(manifest,2)}]
	for family in ["oxidized","banded"]:
		for ordinal in range(8,10000):
			var body:=FrontierUniverse.body(manifest,ordinal)
			if body.traits.id==family:specimens.append({"id":family,"body":body});break
	var board:=Image.create(4*320,3*320,false,Image.FORMAT_RGB8)
	var row:=0
	for specimen in specimens:
		var body: Dictionary=specimen.body;var node:=render_body(body);var radius:=FrontierUniverse.radius(body)
		for mat in materials(node):mat.set_shader_parameter("visual_time",0.)
		if node is FrontierSolarPlanet:
			for cloud in node.clouds:cloud.hide()
		var index:=0
		for axis in [Vector3(0,1,.02),Vector3(0,-1,.02),Vector3(-1,.03,.0),Vector3(.15,.1,1)]:
			camera.position=axis.normalized()*radius*(13. if index==3 else 1.25);camera.look_at(Vector3.ZERO)
			await pause_render()
			var shot:=root.get_texture().get_image();var side:=mini(shot.get_width(),shot.get_height());shot=shot.get_region(Rect2i((shot.get_width()-side)/2,0,side,side));shot.resize(320,320,Image.INTERPOLATE_LANCZOS);shot.convert(Image.FORMAT_RGB8)
			board.blit_rect(shot,Rect2i(0,0,320,320),Vector2i(index*320,row*320));index+=1
		var loaded: Array=materials(node)
		check(loaded.all(func(m: ShaderMaterial):return m.get_shader_parameter("orbital_maps_enabled")==true),specimen.id+" maps retained at distant LOD")
		check(node.distant.visible if node is FrontierSolarPlanet else node.get_node("OrbitalLOD").distant,specimen.id+" original distant mesh selected")
		node.free();await process_frame;row+=1
	board.save_png(folder+"/poles-seam-far.png")
	FileAccess.open(folder+"/edge-verification.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":["earth","oxidized","banded"],"columns":["north pole, 1.25 radii","south pole, 1.25 radii","longitude seam, 1.25 radii","distant LOD, 13 radii"]},"  "))
	factory.free();print("ORBITAL_SURFACE_EDGES ",checks," FAILURES ",failures);quit(1 if failures else 0)
