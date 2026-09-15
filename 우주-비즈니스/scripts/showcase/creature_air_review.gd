extends "res://scripts/showcase/creature_remodel_field.gd"
## Per-anatomy seeded flight, or isolated atmospheric pose review. No placement changes.
func run() -> void:
	folder=ProjectSettings.globalize_path("res://../output/creature-remodel/r05");DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1100,800);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X
	stage=Node3D.new();root.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("cbd5d0");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("bdccce");env.environment.ambient_light_energy=.6;stage.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-52,-30,0);sun.shadow_enabled=true;stage.add_child(sun)
	var field:=FrontierTerrainField.new();field.configure(4703)
	var home:=Vector3(0,field.height(0,0),0)
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-22,23):
		for x in range(-22,23):
			for i in [0,2,1,1,2,3]:
				var px: float=x+(i%2);var pz: float=z+floori(i/2.)
				var p:=Vector3(px,field.height(px,pz),pz);surface.set_normal(field.normal(p));surface.add_vertex(p)
	var ground:=MeshInstance3D.new();ground.mesh=surface.commit();var mat:=StandardMaterial3D.new();mat.albedo_color=Color("aeb8a7");ground.material_override=Ink.material(mat,{});stage.add_child(ground)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.8;camera.far=100;camera.current=true;stage.add_child(camera);Ink.attach(stage,true)
	title=Label.new();title.position=Vector2(24,18);title.add_theme_font_override("font",load("res://assets/fonts/NotoSansKR.ttf"));title.add_theme_font_size_override("font_size",23);title.add_theme_color_override("font_color",Color("203a36"));root.add_child(title)
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/creature_remodel_r05.json"))
	var filter:=Array(OS.get_cmdline_user_args()).filter(func(x):return not x.begins_with("--"))
	for form in manifest.forms:
		if not filter.is_empty() and form.id not in filter:continue
		await review_air(form,field)
	print("REMODEL_AIR_DONE");quit()

func review_air(form: Dictionary,field: FrontierTerrainField) -> void:
	var home:=Vector3(0,field.height(0,0),0)
	var original:=FrontierEcologyCatalog.form(form.source_id);Actor.RemodelRegistry.entry(original);Actor.RemodelRegistry.entries[original.id]=form
	var ready_scenes: Array=[]
	for lod in ["near","far"]:
		var gltf:=GLTFDocument.new();var state:=GLTFState.new();assert(gltf.append_from_file("res://"+str(form.lods[lod].path).trim_prefix("우주-비즈니스/"),state)==OK)
		var model:=gltf.generate_scene(state);var packed:=PackedScene.new();assert(packed.pack(model)==OK);model.free();ready_scenes.append(packed)
	var actor:=Actor.new();actor.configure(original,{"scale":1.,"palette":original.palette},ready_scenes,form);stage.add_child(actor);actor.set_process(false)
	var row: Dictionary={"id":"flight-remodel-review","form_id":original.id,"yaw":0.,"status":"active","introduced":false}
	var seed_phase: float=float(FrontierUniverse.derive(field.seed_value,"flight:"+str(row.id))%48000)/1000.
	var probe:=func(at: Vector3,_reach: float):return {"point":Vector3(at.x,field.height(at.x,at.z),at.z),"normal":field.normal(at)}
	var phases: Dictionary={};var clips: Dictionary={};var root_error:=0.;var records: Array=[];var max_foot_error:=0.
	for i in (1441 if form.air_motion else 121):
		var t:=i/30.;var motion: Dictionary=FrontierEcologyPlacement.flight_pose(field,row,home,t-seed_phase) if form.air_motion else {"point":home+Vector3.UP*2.,"basis":Basis.IDENTITY,"blend":-1.,"clock":t,"phase":"atmosphere-pose"}
		actor.position=motion.point;actor.basis=motion.basis;actor.flight_blend=motion.blend;actor.flight_clock=motion.clock;actor.state="move" if motion.blend>.0001 else "idle"
		actor.drive_ground(motion.point,motion.basis,1./30.,probe,false,0);actor._process(1./30.)
		root_error=maxf(root_error,actor.global_position.distance_to(motion.point));max_foot_error=maxf(max_foot_error,actor.ground_motion.grounded_error)
		phases[motion.phase]=true;clips[actor.ground_motion.wanted_clip]=true
		var center: Vector3=motion.point+Vector3.UP*1.1;camera.size=maxf(float(form.lods.near.max[0])-float(form.lods.near.min[0]),float(form.lods.near.max[1])-float(form.lods.near.min[1]))*1.35+1.5;camera.position=center+Vector3(6,4.3,9);camera.look_at(center)
		title.text=str(form.name)+"  "+str(motion.phase)+"  "+actor.ground_motion.wanted_clip
		if i in [0,60,120,375,435,540,1080,1320,1410] or "--video" in OS.get_cmdline_user_args() and i%2==0:
			await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/"+str(form.id)+"_%04d.png"%i)
		if i%30==0:records.append({"time":t,"phase":motion.phase,"blend":motion.blend,"clip":actor.ground_motion.wanted_clip,"pose_clock":actor.ground_motion.pose_clock})
	assert(root_error<.00001 and max_foot_error<.025)
	if form.air_motion:assert(phases.size()==4 and clips.size()==4)
	# Introduced and dormant animals retain the authoritative grounded state.
	for key in (["introduced","dormant"] if form.air_motion else []):
		row.introduced=key=="introduced";row.status="dormant" if key=="dormant" else "active"
		var motion:=FrontierEcologyPlacement.flight_pose(field,row,home,25.-seed_phase)
		assert(motion.blend==0 and motion.point==home)
	FileAccess.open(folder+"/"+str(form.id)+"_evidence.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"id":form.id,"actual_seeded_flight_path":form.air_motion,"asset_sha256":{"near":form.lods.near.sha256,"far":form.lods.far.sha256},"root_error":root_error,"max_ground_foot_error":max_foot_error,"phases":phases.keys(),"clips":clips.keys(),"dormant_and_introduced_remain_grounded":form.air_motion,"records":records},"\t"))
	print("REMODEL_AIR ",form.id," ",phases.keys()," ",clips.keys()," root=",root_error," ground=",max_foot_error);actor.free()
