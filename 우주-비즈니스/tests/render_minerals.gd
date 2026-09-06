extends SceneTree
var stage: Node3D
var camera: Camera3D
var site: FrontierBusinessSiteView
var label: Label
var folder: String
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value:failures.append(message);printerr(message)
func capture(id: String) -> void:
	await create_timer(.18).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+id+".png")
func run() -> void:
	folder=ProjectSettings.globalize_path("res://../docs/production/media/minerals/godot")
	DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1000,800)
	stage=Node3D.new();root.add_child(stage)
	var world:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("182738");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("a1b4ca");env.ambient_light_energy=.55;world.environment=env;stage.add_child(world)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-42,-30,0);light.light_energy=1.4;light.shadow_enabled=true;stage.add_child(light)
	camera=Camera3D.new();camera.position=Vector3(4,3.2,6);camera.look_at_from_position(camera.position,Vector3(0,.8,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.8;camera.near=.01;camera.far=200;stage.add_child(camera);camera.current=true
	FrontierInkStyle.attach(camera,true);root.msaa_3d=Viewport.MSAA_4X;root.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA;root.scaling_3d_scale=1.5
	var layer:=CanvasLayer.new();stage.add_child(layer);label=Label.new();label.position=Vector2(28,24);label.add_theme_font_override("font",load("res://assets/fonts/NotoSansKR.ttf"));label.add_theme_font_size_override("font_size",27);layer.add_child(label)
	var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(200,200);floor_mesh.mesh=plane
	var ground:=StandardMaterial3D.new();ground.albedo_color=Color("33475a");floor_mesh.material_override=FrontierInkStyle.material(ground,{});floor_mesh.position.y=-.15;stage.add_child(floor_mesh)
	site=FrontierBusinessSiteView.new();stage.add_child(site);site.synchronous_resources=true
	check(FrontierMinerals.all().size()==19,"19 definitions required")
	check(FrontierMinerals.candidates(["metallic"],"surface",false).is_empty(),"Gas giants must not receive land deposits")
	for id in FrontierMinerals.all():
		var row: Dictionary=FrontierMinerals.entry(id)
		check(row.variants.size()==2,"Two silhouettes: "+id)
		for variant in row.variants:
			var specimen: String=""
			var expected: Dictionary={}
			for n in 100:
				specimen="preview:"+id+":"+str(n)
				expected=FrontierMinerals.appearance(id,0,specimen)
				if expected.variant==variant.id:break
			check(expected.variant==variant.id,"Both variants selectable: "+id)
			check(expected==FrontierMinerals.appearance(id,0,specimen),"Recreated appearance stays identical: "+id)
			check(expected!=FrontierMinerals.appearance(id,1976,specimen),"Planet seed affects appearance: "+id)
			label.text=row.name+"  /  "+String(variant.id).to_upper()+"\nINK v1 · 시드 고정 배치"
			site._queue_entity(specimen,"ore_"+id,Vector3.ZERO,1.1,"vein");site._load_one_model()
			check(site.nodes.has(specimen),"Production loader: "+id)
			var entity: Node3D=site.nodes[specimen]
			var visual: Node3D=entity.get_meta("visual")
			check(visual.scene_file_path==variant.model,"Correct seeded model: "+id)
			check(is_equal_approx(visual.scale.x,expected.scale) and is_equal_approx(visual.rotation.y,expected.yaw),"Seeded transform: "+id)
			check(visual.get_meta("original_scale")==visual.scale,"Depletion keeps base scale: "+id)
			for mesh in visual.find_children("*","MeshInstance3D",true,false):
				check(not "Basalt" in mesh.name and not "STUDIO" in mesh.name,"No dirt/stand: "+id)
				for i in mesh.mesh.get_surface_count():check(mesh.get_active_material(i) is ShaderMaterial,"Shared INK: "+id)
			await capture(id+("_b" if variant.id=="b" else ""))
			site.nodes.erase(specimen);entity.queue_free();await process_frame
	# Contact check on the same seeded surface-height field used by the expedition.
	floor_mesh.queue_free();await process_frame
	var field:=FrontierTerrainField.new();field.configure(1976)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-50,51):
		for z in range(-50,51):
			for p in [Vector2(x,z),Vector2(x,z+1),Vector2(x+1,z),Vector2(x+1,z),Vector2(x,z+1),Vector2(x+1,z+1)]:
				st.add_vertex(Vector3(p.x,field.height(p.x,p.y),p.y))
	st.generate_normals();var terrain_mesh:=MeshInstance3D.new();terrain_mesh.mesh=st.commit();ground.albedo_color=Color("716356");terrain_mesh.material_override=FrontierInkStyle.material(ground,{});stage.add_child(terrain_mesh)
	var ids: Array[String]=["iron","copper","stone","ice","crystal"]
	for i in ids.size():
		var id: String=ids[i];var x: float=(i-2)*2.7
		site._queue_entity(id,"ore_"+id,Vector3(x,field.height(x,0),0),1.1,"vein");site._load_one_model()
	label.text="기존 채집 광체 5종 · 시드 지표 접지 확인"
	camera.position=Vector3(4,7,15);camera.look_at_from_position(camera.position,Vector3(0,2.7,0));camera.size=15
	await capture("surface-contact")
	var result={"assets":38,"production_loader":true,"deterministic_variants":true,"surface_contact_resources":ids,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"scope":"asset render, production entity loader, seeded height-field contact; full mining/network behavior not re-tested"}
	var output:=FileAccess.open(folder+"/verification.json",FileAccess.WRITE);output.store_string(JSON.stringify(result,"\t"));output.close()
	print("MINERAL RENDER ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
