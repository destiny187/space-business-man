extends "res://tests/test_solo_entry.gd"
var stage: Node3D
var camera: Camera3D
var settings: FrontierClientSettings
var manifest: Dictionary
var factory: FrontierSpaceFlight
var measurements: Array=[]
func pause_render() -> void:
	await create_timer(.12).timeout;await RenderingServer.frame_post_draw
func render_body(body: Dictionary) -> Node3D:
	var entry:=factory._create_planet(int(body.system_ordinal),int(body.ordinal)-FrontierUniverse.first_ordinal(manifest,int(body.system_ordinal)))
	var node: Node3D=entry.node;factory.remove_child(node);stage.add_child(node)
	node.position=Vector3.ZERO
	if node is FrontierSolarPlanet:
		node.set_epoch(0.,body)
	else:node.basis=Basis.IDENTITY.scaled(Vector3.ONE*FrontierUniverse.radius(body))
	return node
func materials(node: Node3D) -> Array:
	if node is FrontierSolarPlanet:return node.surfaces.map(func(n: Node3D):return n.material_override)
	return [node.material_override]
func tile(image: Image) -> Image:
	var side:=mini(image.get_width(),image.get_height())
	var result:=image.get_region(Rect2i((image.get_width()-side)/2,0,side,side));result.resize(256,256,Image.INTERPOLATE_LANCZOS);result.convert(Image.FORMAT_RGB8);return result
func position_camera(body: Dictionary,distance: float) -> void:
	var radius:=FrontierUniverse.radius(body)
	camera.position=Vector3(.15,.10,1.).normalized()*radius*distance;camera.look_at(Vector3.ZERO)
func run() -> void:
	if not "--crew-folder=/tmp/orbital-surface-check" in OS.get_cmdline_user_args():quit(2);return
	folder=ProjectSettings.globalize_path("res://../docs/production/media/orbital-surfaces");DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1024,768);settings=FrontierClientSettings.ensure(self)
	settings.values.fps=0;settings.values.vsync=false;settings.values.ssao=false;settings.values.ssil=false;settings.values.ssr=false;settings.values.glow=false;settings.values.msaa=1;settings.apply_all()
	stage=Node3D.new();root.add_child(stage);current_scene=stage
	var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("101923");world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=.45;stage.add_child(world)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-24,-28,0);sun.light_energy=1.7;stage.add_child(sun)
	camera=Camera3D.new();camera.far=100000;camera.near=.1;camera.fov=55;stage.add_child(camera);camera.make_current()
	manifest=FrontierUniverse.new_world(71503).manifest
	factory=FrontierSpaceFlight.new();factory.state={"manifest":manifest}
	var specimens: Dictionary={}
	var archetypes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_diversity.json")).archetypes
	for ordinal in range(8,10000):
		var body:=FrontierUniverse.body(manifest,ordinal)
		if not specimens.has(body.traits.id):specimens[body.traits.id]=body
		if specimens.size()==archetypes.size():break
	var rows: Array=[]
	for id in archetypes:rows.append({"id":id,"body":specimens[id]})
	for i in 8:
		var body:=FrontierUniverse.body(manifest,i)
		# Include authored unrestored Mars as well as the current Space Y restoration.
		if i==3:body=body.duplicate(true);body.erase("management")
		rows.append({"id":FrontierSolarPlanet.ASSETS[i],"body":body})
	rows.append({"id":"mars_restored","body":FrontierUniverse.body(manifest,3)})
	check(rows.size()==27,"all 18 generated families + 8 solar bodies + restored Mars")
	var gallery:=Image.create(9*256,3*256,false,Image.FORMAT_RGB8)
	var close_gallery:=Image.create(9*256,3*256,false,Image.FORMAT_RGB8)
	var caption:=Label.new();caption.position=Vector2(260,18);caption.add_theme_font_size_override("font_size",32);root.add_child(caption)
	settings.set_quality("planet_surface",2)
	var index:=0
	for row in rows:
		var body: Dictionary=row.body
		var node:=render_body(body)
		# The factory resolves the current Solar body, so explicitly rebuild the historical Mars fixture.
		if row.id=="mars":
			node.free();node=FrontierSolarPlanet.new();stage.add_child(node);node.configure(3,FrontierUniverse.radius(body),body)
		caption.text=row.id
		var decoration:=FrontierOrbitalPresentation.new();decoration._decorate(node,body,FrontierUniverse.radius(body));decoration.free()
		position_camera(body,2.5);await pause_render()
		var image:=tile(root.get_texture().get_image());gallery.blit_rect(image,Rect2i(0,0,256,256),Vector2i((index%9)*256,(index/9)*256))
		position_camera(body,1.65);await pause_render()
		image=tile(root.get_texture().get_image());close_gallery.blit_rect(image,Rect2i(0,0,256,256),Vector2i((index%9)*256,(index/9)*256))
		var mats:=materials(node)
		check(mats.all(func(m: ShaderMaterial):return m.get_shader_parameter("orbital_maps_enabled")==true),str(row.id)+" actual factory map bindings / both solar LODs")
		if row.id in ["oxidized","continental","banded","earth","mars_restored"]:
			for quality in [0,1,2]:
				settings.set_quality("planet_surface",quality);await pause_render()
				root.get_texture().get_image().save_png(folder+"/"+row.id+"-"+str(quality)+".png")
				var samples: Array=[]
				for frame in 64:
					var start:=Time.get_ticks_usec();await process_frame;samples.append((Time.get_ticks_usec()-start)/1000.)
				samples.sort();measurements.append({"id":row.id,"quality":quality,"frame_median_ms":samples[32],"frame_p90_ms":samples[57]})
			# Same pose/light/material parameters with the prior shader, if captured before development.
			var previous_path: String="/tmp/orbital-solar-before.gdshader" if node is FrontierSolarPlanet else "/tmp/orbital-planet-before.gdshader"
			if FileAccess.file_exists(previous_path):
				var old:=Shader.new();old.code=FileAccess.get_file_as_string(previous_path)
				var shaders: Array=mats.map(func(m: ShaderMaterial):return m.shader)
				for mat in mats:mat.shader=old
				await pause_render();root.get_texture().get_image().save_png(folder+"/"+row.id+"-before.png")
				for n in mats.size():mats[n].shader=shaders[n]
		node.free();await process_frame;index+=1
	gallery.save_png(folder+"/all-planets.png");close_gallery.save_png(folder+"/all-planets-close.png")
	caption.queue_free()
	for quality in [0,1,2]:
		settings._preset(quality)
		check(settings.values.planet_surface_quality==quality and settings.quality_preset()==quality,"whole preset includes planet detail "+str(quality))
	settings.set_quality("planet_surface",0);check(settings.quality_preset()==3,"individual planet setting becomes custom")
	settings.load_settings();check(settings.values.planet_surface_quality==0,"local planet option survives disk reload")
	for preset in [0,1,2,3]:
		var old_settings:=settings.values.duplicate();old_settings.erase("planet_surface_quality");old_settings.preset=preset
		FileAccess.open(settings.path,FileAccess.WRITE).store_string(JSON.stringify(old_settings));settings.load_settings()
		check(settings.values.planet_surface_quality==(preset if preset!=3 else 1),"old settings migration "+str(preset))
	settings._preset(1);root.size=Vector2i(960,640);settings.open();await pause_render();root.get_texture().get_image().save_png(folder+"/settings-960.png")
	check(settings.quality_controls.has("planet_surface"),"planet quality has a live settings control")
	FileAccess.open(folder+"/verification.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"27 actual factory profiles, neutral Forward+ close/far render; isolated local settings. Timings are frame intervals, not GPU time or full-game benchmarks.","timings":measurements},"  "))
	factory.free();print("ORBITAL_SURFACES ",checks," FAILURES ",failures);quit(1 if failures else 0)
