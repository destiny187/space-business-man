extends SceneTree
var stage: Node3D
var camera: Camera3D
var solar: FrontierSolarPlanet
var label: Label
var folder: String
var checks:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failed+=1;printerr("FAIL ",message)
	else:print("PASS ",message)
func capture(name_value: String) -> void:
	await create_timer(.25).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name_value+".png")
func run() -> void:
	folder=ProjectSettings.globalize_path("res://../docs/production/media/ink-life/planets/game")
	if "--seeded-only" in OS.get_cmdline_user_args():folder=ProjectSettings.globalize_path("res://../docs/production/media/planet-surfaces-v2/orbit")
	DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(900,900)
	stage=Node3D.new();root.add_child(stage)
	var world:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("0e1c2d");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("a1b4ca");env.ambient_light_energy=.35;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;world.environment=env;stage.add_child(world)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-35,0);light.light_energy=1.6;light.shadow_enabled=true;stage.add_child(light)
	camera=Camera3D.new();camera.position=Vector3(2.4,1.3,6);camera.look_at_from_position(camera.position,Vector3.ZERO);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.1;camera.near=.01;camera.far=100;stage.add_child(camera);camera.current=true
	FrontierInkStyle.attach(camera,true);root.msaa_3d=Viewport.MSAA_4X
	var layer:=CanvasLayer.new();stage.add_child(layer);label=Label.new();label.position=Vector2(38,28);label.add_theme_font_override("font",load("res://assets/fonts/NotoSansKR.ttf"));label.add_theme_font_size_override("font_size",28);layer.add_child(label)
	var data: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/solar-system/manifest.json"))
	for i in (range(0) if "--rings-only" in OS.get_cmdline_user_args() or "--seeded-only" in OS.get_cmdline_user_args() else range(8)):
		solar=FrontierSolarPlanet.new();stage.add_child(solar);solar.configure(i,1)
		camera.size=5.4 if i==5 else (4.2 if i==6 else 3.0)
		label.text="%02d  /  %s\n"%[i+1,data[i].name]+FrontierSolarPlanet.ASSETS[i].to_upper()
		check(solar.detail!=null and solar.distant!=null,"Blender high/low loaded "+data[i].id)
		var painted:=false
		for mesh in solar.detail.find_children("*","MeshInstance3D",true,false):
			var mat: Material=mesh.get_active_material(0)
			if mat is ShaderMaterial and mat.shader==FrontierInkStyle.CEL and mat.get_shader_parameter("use_vertex_color"):painted=true
		check(painted,"INK vertex paint connected "+data[i].id)
		await capture(FrontierSolarPlanet.ASSETS[i])
		camera.position=Vector3(0,0,15);await process_frame;solar._process(0);check(solar.distant.visible and not solar.detail.visible,"solar distant LOD "+data[i].id)
		camera.position=Vector3(2.4,1.3,6);camera.look_at(Vector3.ZERO);solar._process(0)
		solar.set_epoch(30);check(absf(solar.surfaces[0].rotation.y)>.01,"shared epoch spins "+data[i].id)
		stage.remove_child(solar);solar.queue_free();await process_frame
	root.remove_child(stage);stage.queue_free();await process_frame
	# The production flight view must instantiate these exact assets, not sphere proxies.
	root.size=Vector2i(1280,800)
	var flight:=FrontierCrewFlightView.new();flight.state={"manifest":FrontierUniverse.generate(1976)};root.add_child(flight)
	await process_frame
	check(flight.planets.size()==8,"production flight renders eight Blender planets")
	for i in ([] if "--rings-only" in OS.get_cmdline_user_args() or "--seeded-only" in OS.get_cmdline_user_args() else [2,5]):
		var body:=FrontierUniverse.body(flight.state.manifest,i)
		var target:=FrontierUniverse.position(flight.state.manifest,i)
		var position:=target+Vector3(0,FrontierUniverse.radius(body)*.35,FrontierUniverse.radius(body)*(4.0 if i==5 else 3.4))
		var direction: Vector3=(target-position).normalized()
		flight.exterior=true;flight.update_navigation({"system":0,"target":i,"position":[position.x,position.y,position.z],"direction":[direction.x,direction.y,direction.z],"mode":"idle","speed":0.0,"orbit_time":0.0})
		flight.ship.position=position;flight.ship.basis=flight._flight_basis(direction)
		check(flight.planets[i].node is FrontierSolarPlanet,"production view uses Blender "+str(i))
		await capture("game-"+FrontierSolarPlanet.ASSETS[i])

	var samples:Dictionary={}
	for ordinal in range(8,500):
		var b:=FrontierUniverse.body(flight.state.manifest,ordinal)
		if not samples.has(b.traits.id):samples[b.traits.id]=b
	check(samples.size()==FrontierPlanetTraits.rules().archetypes.size(),"all seeded planet types available")
	flight.ship.hide();flight.ui_root.hide();flight.transit_overlay.hide();flight.set_process(false)
	var review_camera:=Camera3D.new();flight.add_child(review_camera);review_camera.current=true;review_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;review_camera.size=2.8;review_camera.far=100
	var key:=DirectionalLight3D.new();flight.add_child(key);key.rotation_degrees=Vector3(-30,-35,0);key.light_energy=1.3
	for id in FrontierPlanetTraits.rules().archetypes:
		var b:Dictionary=samples[id]
		if "--rings-only" in OS.get_cmdline_user_args() and not b.get("rings",false):continue
		review_camera.size=5.2 if b.get("rings",false) else 2.8
		flight._load_system(int(b.system_ordinal))
		var node:MeshInstance3D=flight.planets[int(b.ordinal)].node
		flight.planets.erase(int(b.ordinal));node.position=Vector3.ZERO;node.scale=Vector3.ONE
		for entry in flight.planets.values():entry.node.hide()
		flight.system_art.hide()
		if flight.galactic_core!=null:flight.galactic_core.hide()
		var lod:Node=node.get_node("OrbitalLOD")
		review_camera.look_at_from_position(Vector3(2.4,1.3,6),Vector3.ZERO);lod._process(0)
		check(node.mesh==lod.near_mesh,id+" near mesh")
		await capture("seeded-"+id)
		review_camera.look_at_from_position(Vector3(4.8,2.6,15),Vector3.ZERO);lod._process(0)
		check(node.mesh==lod.far_mesh and lod.shell.mesh==lod.far_mesh,id+" distant surface and air shell")
		await capture("seeded-"+id+"-far")
		review_camera.position=Vector3(0,0,6);lod._process(0);check(node.mesh==lod.near_mesh,id+" returns near")
		node.queue_free();await process_frame
	var result={"checks":checks,"failed":failed,"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"scope":"seeded ring framing and LOD checks" if "--rings-only" in OS.get_cmdline_user_args() else "%d seeded types; actual production loader; near/far geometry and return" % samples.size()}
	var output:=FileAccess.open(folder+("/ring-framing.json" if "--rings-only" in OS.get_cmdline_user_args() else "/verification.json"),FileAccess.WRITE);output.store_string(JSON.stringify(result,"\t"));output.close()
	print("SOLAR RENDER ",JSON.stringify(result));quit(1 if failed else 0)
