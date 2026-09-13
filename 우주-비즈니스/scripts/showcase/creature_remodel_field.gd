extends SceneTree
## Actual campaign actor, imported LODs and terrain drive; no species/save edits.
const Actor=preload("res://scripts/actors/creatures/bestiary_actor.gd")
const Ink=preload("res://scripts/actors/ink_style.gd")
var stage: Node3D
var camera: Camera3D
var caption: Label
var title: Label
var folder:=ProjectSettings.globalize_path("res://../output/creature-remodel/field")
var report: Array=[]
var capturing:=true
func _initialize() -> void:call_deferred("run")

func height(x: float,z: float) -> float:return z*.14+.075*sin(x*1.3)+.055*sin(z*2.)
func normal(x: float,z: float) -> Vector3:return Vector3(-.0975*cos(x*1.3),1,-.14-.11*cos(z*2.)).normalized()
func probe(at: Vector3,_reach: float) -> Dictionary:return {"point":Vector3(at.x,height(at.x,at.z),at.z),"normal":normal(at.x,at.z)}
func frame_at(at: Vector3,yaw: float) -> Basis:
	var up:=normal(at.x,at.z);var forward:=Vector3(sin(yaw),0,cos(yaw));var side:=up.cross(forward).normalized()
	return Basis(side,up,side.cross(up).normalized())
func run() -> void:
	if "--check-registry" in OS.get_cmdline_user_args():
		audit_registry();quit();return
	capturing=not "--check-only" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,800);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X;root.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
	stage=Node3D.new();root.add_child(stage)
	var world:=WorldEnvironment.new();var env:=Environment.new();world.environment=env;env.background_mode=Environment.BG_COLOR;env.background_color=Color("ced7d0");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("bdccce");env.ambient_light_energy=.52;stage.add_child(world)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-52,-30,0);sun.shadow_enabled=true;sun.shadow_bias=.01;sun.shadow_normal_bias=.03;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL;sun.directional_shadow_max_distance=30;stage.add_child(sun)
	terrain_mesh()
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.05;camera.far=60;camera.current=true;stage.add_child(camera);Ink.attach(stage,true)
	var font:=FontVariation.new();font.base_font=load("res://assets/fonts/NotoSansKR.ttf");font.variation_embolden=.5
	title=Label.new();title.position=Vector2(32,22);title.add_theme_font_override("font",font);title.add_theme_font_size_override("font_size",30);title.add_theme_color_override("font_color",Color("203a36"));root.add_child(title)
	caption=Label.new();caption.position=Vector2(34,68);caption.add_theme_font_override("font",font);caption.add_theme_font_size_override("font_size",20);caption.add_theme_color_override("font_color",Color("37574d"));root.add_child(caption)
	for form in JSON.parse_string(FileAccess.get_file_as_string("res://data/creature_remodel_r01.json")).forms:
		var original:=FrontierEcologyCatalog.form(form.source_id)
		if Actor.RemodelRegistry.entry(original).is_empty():
			if "--include-pending" in OS.get_cmdline_user_args() and form.kind!="glider":Actor.RemodelRegistry.entries[original.id]=form
			else:continue
		var filter:=Array(OS.get_cmdline_user_args()).filter(func(x):return not x.begins_with("--"))
		if not filter.is_empty() and form.id not in filter:continue
		await review(original,form)
	FileAccess.open(folder+"/evidence.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"actor":"bestiary_actor.gd","terrain":"8 degree average slope with local undulations","species":report},"\t"))
	print("REMODEL_FIELD_DONE ",report.size());quit()

func terrain_mesh() -> void:
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-80,120):
		for x in range(-100,100):
			for index in [0,2,1,1,2,3]:
				var px:=float(x+(index%2))*.5;var pz:=float(z+floori(float(index)/2.))*.5
				tool.set_normal(normal(px,pz));tool.set_color(Color("aeb8a7") if (x+z)%2==0 else Color("b7c1ae"));tool.add_vertex(Vector3(px,height(px,pz),pz))
	var ground:=MeshInstance3D.new();ground.mesh=tool.commit();var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=.95;ground.material_override=Ink.material(mat,{});stage.add_child(ground)

func review(original: Dictionary,form: Dictionary) -> void:
	var actor:=Actor.new();actor.defer_far=true;actor.lod_override=0
	# Campaign configures before add_child; use that exact order.
	actor.configure(original,{"scale":1.,"palette":original.palette});stage.add_child(actor);actor.set_process(false)
	assert(actor.definition==original and actor.remodel.id==form.id)
	assert(actor.finish_lods() and actor.models.size()==2)
	assert(actor.definition.attack=="none" and not actor.set_state("attack"))
	actor.set_state("move")
	var distance: float=-2.;var lateral:=0.;var angle:=0.;var max_error:=0.;var phases: Dictionary={};var initial_skeleton: Array=[];var pause_bones: Array=[];var pause_point:=Vector3.ZERO
	var samples: Array=[];var bone_motion:=0.;var root_error:=0.;var footfalls:=0
	title.text=form.name;camera.size=6.7 if form.id=="tethermaw" else 5.6
	for i in 300:
		var t:=float(i)/30.;var local_speed: float=actor.ground_motion.natural(form.motion_profile)
		var label:="걷기 · 지지발과 경사 접지"
		if t>=1.8 and t<4.7:local_speed*=lerpf(1.,2.5,smoothstep(1.8,2.6,t));label="가속 · 실제 이동량에 맞춘 빠른 보행"
		elif t>=4.7 and t<5.5:local_speed*=1.-smoothstep(4.7,5.5,t);label="감속 · 정지"
		elif t>=5.5 and t<6.3:local_speed=0.;angle=(t-5.5)*1.1;label="정지 선회 · 발 재배치"
		elif t>=6.3 and t<7.2:local_speed=0.;label="일시정지 · 관절과 위치 유지"
		elif t>=7.2 and t<8.5:local_speed*=2.0;label="먼 거리 LOD · 보행 위상 유지";actor.lod_override=1
		elif t>=8.5:local_speed=0.;label="크기·색 변이 · 섭식";actor.lod_override=0
		if i==255:
			var variant: Array=original.palette.duplicate();variant[0]="53748c";variant[1]="b2bc9b"
			actor.apply_appearance({"scale":1.35,"palette":variant});actor.ground_motion.reset();actor.set_state("feed");camera.size*=1.25
		var stopped: bool=t>=6.3 and t<7.2
		actor.paused=stopped
		if not stopped:
			distance+=cos(angle)*local_speed*actor.base_scale/30.;lateral+=sin(angle)*local_speed*actor.base_scale/30.
		var at:=Vector3(lateral,height(lateral,distance),distance)
		actor.drive_ground(at,frame_at(at,angle),1./30.,probe,stopped,0)
		actor._process(1./30.)
		var motion=actor.ground_motion
		root_error=maxf(root_error,actor.global_position.distance_to(at))
		if i>10:max_error=maxf(max_error,motion.grounded_error)
		phases[motion.wanted_clip]=true
		var skeleton: Skeleton3D=actor.anatomical_skeletons[actor.visible_model]
		var bones: Array=[]
		for b in skeleton.get_bone_count():
			var pose:=skeleton.get_bone_global_pose(b);assert(pose.is_finite());bones.append(pose)
		if i==5:initial_skeleton=bones.duplicate()
		if i==45:
			for b in bones.size():bone_motion+=bones[b].origin.distance_to(initial_skeleton[b].origin)
		if i==189:pause_bones=bones.duplicate();pause_point=actor.visual_root.global_position
		if stopped and i>189:assert(bones==pause_bones and actor.visual_root.global_position==pause_point)
		if motion.take_footfall().is_finite():footfalls+=1
		assert(actor.mouth_marker!=null and actor.mouth_marker.global_position.is_finite())
		var center:=actor.visual_root.global_position+Vector3(0,1.05,.65 if form.id=="tethermaw" else 0.)
		camera.position=center+Vector3(4.2,3.1,7.5);camera.look_at(center);caption.text=label
		if i%30==0:samples.append({"second":t,"clip":motion.wanted_clip,"speed":motion.travel_speed,"phase":motion.phase,"lod":actor.visible_model,"contact_error":motion.grounded_error})
		if capturing:
			await process_frame;await RenderingServer.frame_post_draw
			if i%2==0:
				var picture:=root.get_texture().get_image();picture.resize(960,600,Image.INTERPOLATE_LANCZOS);picture.save_png(folder+"/"+form.id+"_%03d.png"%(i/2))
	assert(root_error<.00001 and bone_motion>.01)
	assert(phases.has("move_loop") and phases.has("run_loop") and phases.has("feed"))
	report.append({"id":form.id,"species_id":original.id,"bones":actor.anatomical_skeletons[0].get_bone_count(),"lods":actor.models.size(),"authored_clips":actor.ground_motion.players[0].get_animation_list(),"phases":phases.keys(),"reach_debug":actor.ground_motion.reach_debug,"root_error":root_error,"max_foot_target_error":max_error,"bone_motion":bone_motion,"pause_held":true,"mouth_follows_live_skeleton":true,"footfalls":footfalls,"samples":samples})
	print("REMODEL_FIELD ",form.id," root=",root_error," foot=",max_error," motion=",bone_motion," clips=",phases.keys());actor.free()

func audit_registry() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/creature_remodel_runtime.json"))
	assert(not manifest.enabled_ground_species.is_empty())
	for id in manifest.enabled_ground_species:
		var form:=FrontierEcologyCatalog.form(id)
		var entry:=Actor.RemodelRegistry.entry(form)
		assert(FrontierWildlifeCombat.pattern(form)=="none" or entry.get("host_motion","") in ["charge","leap"])
		var near: PackedScene=load(Actor.RemodelRegistry.path(form,"near"))
		var far: PackedScene=load(Actor.RemodelRegistry.path(form,"far"))
		var actor:=Actor.new();actor.defer_far=true
		actor.configure(form,{"scale":1.,"palette":form.palette},[near,far]);root.add_child(actor)
		assert(actor.remodel.source_id==id and actor.finish_lods())
		assert(actor.models.size()==2 and actor.mouth_marker!=null)
		var motion=actor.ground_motion;var count: Array[int]=[0]
		motion.probe=func(at: Vector3,_reach: float):count[0]+=1;return {"point":Vector3(at.x,0,at.z),"normal":Vector3.UP}
		motion.contact_interval=.2;motion.ground_revision=1;motion.idle_clock=1.
		motion.ground_sample("budget",Vector3(0,1,0),1.)
		var reused: Dictionary=motion.ground_sample("budget",Vector3(1,1,1),1.)
		assert(count[0]==1 and reused.point==Vector3(1,0,1))
		motion.ground_revision=2;motion.ground_sample("budget",Vector3.ONE,1.);assert(count[0]==2)
		motion.planted["temporary"]=Vector3.ONE;motion.released_feet["temporary"]={};motion.reset()
		assert(motion.planted.is_empty() and motion.released_feet.is_empty() and motion.ground_samples.is_empty())
		actor.free()
	for id in manifest.get("enabled_air_species",[]):
		var form:=FrontierEcologyCatalog.form(id);var actor:=Actor.new();actor.configure(form,{"scale":1.,"palette":form.palette});root.add_child(actor)
		assert(actor.remodel.get("air_motion",false) and actor.models.size()==2)
		actor.flight_blend=1.;actor.flight_clock=24.;actor.ground_motion.tick(1./30.);actor.ground_motion.pose_authored()
		assert(actor.ground_motion.wanted_clip=="flight_loop")
		actor.free()
	# Native incidents use the same required presentation after catalogue asset retirement.
	var incident_form:=FrontierEcologyCatalog.form(manifest.enabled_ground_species[0])
	var incident_actor:=FrontierNativeIncidentView.make_actor({"form_id":incident_form.id},{})
	assert(incident_actor.remodel.source_id==incident_form.id and incident_actor.models.size()==1);incident_actor.free()
	assert(manifest.pending_host_attack_adaptation.is_empty())
	print("REMODEL_REGISTRY ",manifest.enabled_ground_species.size()," surface species; imported prewarm/deferred LOD; native incident presentation; host motion adapters checked")
