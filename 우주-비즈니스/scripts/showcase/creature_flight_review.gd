extends "res://scripts/showcase/creature_remodel_field.gd"
## The existing seeded flight path drives the new folding and landing clips.
func run() -> void:
	folder=ProjectSettings.globalize_path("res://../output/creature-remodel/flight");DirAccess.make_dir_recursive_absolute(folder)
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
	var form: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/creature_remodel_flight.json")).forms[0]
	var original:=FrontierEcologyCatalog.form(form.source_id);Actor.RemodelRegistry.entry(original);Actor.RemodelRegistry.entries[original.id]=form
	var ready_scenes: Array=[]
	for lod in ["near","far"]:
		var gltf:=GLTFDocument.new();var state:=GLTFState.new();assert(gltf.append_from_file("res://"+str(form.lods[lod].path).trim_prefix("우주-비즈니스/"),state)==OK)
		var model:=gltf.generate_scene(state);var packed:=PackedScene.new();assert(packed.pack(model)==OK);model.free();ready_scenes.append(packed)
	var actor:=Actor.new();actor.configure(original,{"scale":1.,"palette":original.palette},ready_scenes,true,form);stage.add_child(actor);actor.set_process(false)
	var row: Dictionary={"id":"flight-remodel-review","form_id":original.id,"yaw":0.,"status":"active","introduced":false}
	var seed_phase: float=float(FrontierUniverse.derive(field.seed_value,"flight:"+str(row.id))%48000)/1000.
	var probe:=func(at: Vector3,_reach: float):return {"point":Vector3(at.x,field.height(at.x,at.z),at.z),"normal":field.normal(at)}
	var phases: Dictionary={};var clips: Dictionary={};var root_error:=0.;var records: Array=[];var max_foot_error:=0.
	for i in 1441:
		var t:=i/30.;var motion:=FrontierEcologyPlacement.flight_pose(field,row,home,t-seed_phase)
		actor.position=motion.point;actor.basis=motion.basis;actor.flight_blend=motion.blend;actor.flight_clock=motion.clock;actor.state="move" if motion.blend>.0001 else "idle"
		actor.drive_ground(motion.point,motion.basis,1./30.,probe,false,0);actor._process(1./30.)
		root_error=maxf(root_error,actor.global_position.distance_to(motion.point));max_foot_error=maxf(max_foot_error,actor.ground_motion.grounded_error)
		phases[motion.phase]=true;clips[actor.ground_motion.wanted_clip]=true
		var center: Vector3=motion.point+Vector3.UP*1.25;camera.position=center+Vector3(6,4.3,9);camera.look_at(center)
		title.text="겹막 활공수 · "+str(motion.phase)+" · "+actor.ground_motion.wanted_clip
		if i in [60,375,435,540,1080,1320,1410] or "--video" in OS.get_cmdline_user_args() and i%2==0:
			await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/veilglider_%04d.png"%i)
		if i%30==0:records.append({"time":t,"phase":motion.phase,"blend":motion.blend,"clip":actor.ground_motion.wanted_clip,"pose_clock":actor.ground_motion.pose_clock})
	assert(root_error<.00001 and phases.size()==4 and clips.size()==4 and max_foot_error<.025)
	# Introduced and dormant animals retain the authoritative grounded state.
	for key in ["introduced","dormant"]:
		row.introduced=key=="introduced";row.status="dormant" if key=="dormant" else "active"
		var motion:=FrontierEcologyPlacement.flight_pose(field,row,home,25.-seed_phase)
		assert(motion.blend==0 and motion.point==home)
	FileAccess.open(folder+"/evidence.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"actual_seeded_flight_path":true,"root_error":root_error,"max_ground_foot_error":max_foot_error,"phases":phases.keys(),"clips":clips.keys(),"dormant_and_introduced_remain_grounded":true,"records":records},"\t"))
	print("REMODEL_FLIGHT ",phases.keys()," ",clips.keys()," root=",root_error," ground=",max_foot_error);quit()
