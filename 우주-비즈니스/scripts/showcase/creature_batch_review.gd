extends "res://scripts/showcase/creature_remodel_field.gd"
## R02 imported campaign actors. Forced presentation registration is confined to this review.
var video:=false
var batch_name:="r02"
func run() -> void:
	if "--check-scope" in OS.get_cmdline_user_args():
		audit_scope();quit();return
	if "--check-lod" in OS.get_cmdline_user_args():
		audit_lod();quit();return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--batch="):batch_name=argument.trim_prefix("--batch=")
	assert(batch_name.is_valid_identifier())
	folder=ProjectSettings.globalize_path("res://../output/creature-remodel/"+batch_name)
	DirAccess.make_dir_recursive_absolute(folder)
	video="--video" in OS.get_cmdline_user_args()
	root.size=Vector2i(960,720);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X
	stage=Node3D.new();root.add_child(stage)
	var world:=WorldEnvironment.new();var env:=Environment.new();world.environment=env
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("cbd5d0")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("bdccce");env.ambient_light_energy=.52;stage.add_child(world)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-52,-30,0);sun.shadow_enabled=true;sun.shadow_bias=.01;sun.shadow_normal_bias=.03;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL;sun.directional_shadow_max_distance=30;stage.add_child(sun)
	terrain_mesh()
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.05;camera.far=60;camera.current=true;stage.add_child(camera);Ink.attach(stage,true)
	var font:=load("res://assets/fonts/NotoSansKR.ttf")
	title=Label.new();title.position=Vector2(24,18);title.add_theme_font_override("font",font);title.add_theme_font_size_override("font_size",25);title.add_theme_color_override("font_color",Color("203a36"));root.add_child(title)
	caption=Label.new();caption.position=Vector2(26,57);caption.add_theme_font_override("font",font);caption.add_theme_font_size_override("font_size",17);caption.add_theme_color_override("font_color",Color("37574d"));root.add_child(caption)
	var filter:=Array(OS.get_cmdline_user_args()).filter(func(x):return not x.begins_with("--"))
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/creature_remodel_"+batch_name+".json"))
	for form in manifest.forms:
		if not filter.is_empty() and form.id not in filter and form.family not in filter:continue
		var previous: Dictionary={}
		var checkpoint: String=folder+"/"+form.id+"_evidence.json"
		if FileAccess.file_exists(checkpoint):previous=JSON.parse_string(FileAccess.get_file_as_string(checkpoint))
		var matching: bool=previous.get("renderer","")=="forward_plus" and previous.get("species",{}).get("asset_sha256",{})=={"near":form.lods.near.sha256,"far":form.lods.far.sha256}
		matching=matching and int(previous.get("species",{}).get("body_support_version",0))==int(form.get("body_support_version",0))
		if "--unreviewed" in OS.get_cmdline_user_args():
			if matching and int(previous.species.get("authored_pose_capture_version",0))>=2 and int(previous.species.get("contact_metadata_version",0))==int(form.get("contact_metadata_version",0)):continue
		if matching and not video and ("--poses-only" in OS.get_cmdline_user_args() or "--unreviewed" in OS.get_cmdline_user_args()):
			await refresh_poses(form,previous.species)
		else:await review_batch(form)
		if report.is_empty() or report[-1].id!=form.id:
			push_error("Incomplete species review: "+str(form.id));quit(1);return
		FileAccess.open(folder+"/"+form.id+"_evidence.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"species":report[-1]},"\t"))
	var evidence_name:="/diagnostic-evidence.json" if "--diagnostic" in OS.get_cmdline_user_args() else ("/video-evidence.json" if video else "/evidence.json")
	FileAccess.open(folder+evidence_name,FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"actor":"bestiary_actor.gd","species":report},"\t"))
	print("REMODEL_BATCH_DONE ",report.size());quit()

func photograph(id: String,suffix: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+id+"_"+suffix+".png")

func center_camera(actor: Node3D,form: Dictionary) -> void:
	var lo:=Vector3(float(form.lods.near.min[0]),float(form.lods.near.min[1]),float(form.lods.near.min[2]))
	var hi:=Vector3(float(form.lods.near.max[0]),float(form.lods.near.max[1]),float(form.lods.near.max[2]))
	var center: Vector3=actor.visual_root.global_transform*((lo+hi)*.5-Vector3(0,lo.y,0))
	camera.size=maxf(hi.y-lo.y,maxf(hi.x-lo.x,hi.z-lo.z))*.80+1.1
	# Keep the near plane above the sloping ground; radial organs read from a higher view.
	var offset:=Vector3(4.2,6.0,7.5)*1.3 if form.kind=="radial" else Vector3(4.2,3.0,7.5)*1.5
	camera.position=center+offset;camera.look_at(center)

func make_actor(form: Dictionary) -> Node3D:
	var original:=FrontierEcologyCatalog.form(form.source_id)
	assert(not original.is_empty())
	Actor.RemodelRegistry.entry(original);Actor.RemodelRegistry.entries[original.id]=form
	var actor:=Actor.new();actor.defer_far=true;actor.lod_override=0
	var ready_scenes: Array=[]
	if "--direct" in OS.get_cmdline_user_args():
		for lod in ["near","far"]:
			var gltf:=GLTFDocument.new();var state:=GLTFState.new();assert(gltf.append_from_file("res://"+str(form.lods[lod].path).trim_prefix("우주-비즈니스/"),state)==OK)
			var model:=gltf.generate_scene(state);var packed:=PackedScene.new();assert(packed.pack(model)==OK);model.free();ready_scenes.append(packed)
	actor.configure(original,{"scale":1.,"palette":original.palette},ready_scenes,true,form if not ready_scenes.is_empty() else {});stage.add_child(actor);actor.set_process(false)
	assert(actor.finish_lods() and actor.models.size()==2)
	return actor

func capture_attack(actor: Node3D,form: Dictionary) -> Dictionary:
	var motion=actor.ground_motion
	actor.state="attack";motion.clips.fill("")
	var profile: Dictionary=form.motion_profile
	var samples: Array=[{"name":"prepare","time":float(profile.prepare)},{"name":"strike","time":float(profile.release[0])}]
	if profile.release.size()>1:samples.append({"name":"strike_second","time":float(profile.release[1])})
	samples.append({"name":"recover","time":lerpf(float(profile.active_end),float(profile.get("settle",profile.duration)),.5)})
	var positions: Dictionary={}
	for sample in samples:
		motion.wanted_clip="attack";motion.pose_clock=sample.time;motion.pose_step=0.;motion.pose_authored()
		caption.text="공격 기관 · "+str(sample.name);center_camera(actor,form)
		positions[sample.name]={}
		for key in motion.socket_nodes[0]:
			var p: Vector3=motion.socket_nodes[0][key].global_position;assert(p.is_finite());positions[sample.name][key]=[p.x,p.y,p.z]
		var contacts: Array=profile.get("strike_origins",[])
		for index in contacts.size():
			var p: Vector3=motion.socket_point(actor.anatomical_skeletons[0],contacts[index])
			positions[sample.name]["Contact_"+str(index)]=[p.x,p.y,p.z]
		await photograph(form.id,sample.name)
	return positions

func refresh_poses(form: Dictionary,previous: Dictionary) -> void:
	var actor:=make_actor(form);var motion=actor.ground_motion
	title.text=form.name
	var at:=Vector3(0,height(0,0),0);actor.drive_ground(at,frame_at(at,0),1./30.,probe,false,0);actor._process(1./30.)
	var updated:=previous.duplicate(true)
	updated.socket_samples=await capture_attack(actor,form)
	actor.state="move";actor.set_lod(true);motion.wanted_clip="run_loop";motion.pose_clock=.37;motion.pose_step=0.;motion.pose_authored(true)
	caption.text="원거리 LOD · 현재 동작 동기화";center_camera(actor,form);await photograph(form.id,"far")
	updated.authored_pose_capture_version=2;updated.pose_capture_origin=[at.x,at.y,at.z]
	updated.contact_metadata_version=int(form.get("contact_metadata_version",0))
	report.append(updated);print("REMODEL_POSE_REFRESH ",form.id,"; original locomotion evidence preserved");actor.free()

func review_batch(form: Dictionary) -> void:
	var original:=FrontierEcologyCatalog.form(form.source_id)
	var host_pattern: String=FrontierWildlifeCombat.pattern(original)
	if batch_name in ["r02","r03"]:assert(host_pattern=="none")
	var actor:=make_actor(form)
	assert(actor.ground_motion.authored_limbs.size()==int(form.locomotion_chains))
	assert(actor.set_state("attack")== (original.get("attack","none")!="none"));actor.set_state("idle")
	var host_profile:=FrontierWildlifeCombat.profile({"form_id":original.id,"look_id":FrontierEcologyCatalog.look_for_seed(original.id,0),"combat_tier":5})
	var fast_speed: float=host_profile.speed
	var motion=actor.ground_motion;var max_error:=0.;var max_body_error:=0.;var max_body_at: Dictionary={};var max_error_at: Dictionary={};var bone_motion:=0.;var first_bones: Array=[];var root_error:=0.;var phase_checks:=0
	for limb in motion.authored_limbs:
		assert(is_equal_approx(motion.limb_phase(limb.name),float(form.motion_profile.limb_phases[limb.name])));phase_checks+=1
	title.text=form.name;var at:=Vector3(0,height(0,0),0)
	actor.drive_ground(at,frame_at(at,0),1./30.,probe,false,0);actor._process(1./30.);center_camera(actor,form)
	caption.text="형태 · %d개 지지 사지 · %d개 관절"%[form.locomotion_chains,form.bone_count]
	await photograph(form.id,"idle")
	actor.set_state("move")
	var yaw:=0.;var step:=0
	for i in 240:
		var t:=float(i)/30.;var speed: float=motion.natural(form.motion_profile)
		caption.text="걷기 · 경사 지지"
		if i>=45 and i<135:speed=lerpf(speed,fast_speed,smoothstep(45,65,i));caption.text="빠른 도주 · 기존 게임 속도의 보폭과 접지"
		elif i>=135 and i<159:speed=fast_speed*(1.-smoothstep(135,159,i));caption.text="감속 · 발 재배치"
		elif i>=159 and i<189:speed=0.;yaw=(i-159)/30.*.75;caption.text="정지 선회"
		elif i>=189:speed=0.;actor.set_state("feed");caption.text="섭식 · 관절 기관"
		at+=Vector3(sin(yaw),0,cos(yaw))*speed/30.;at.y=height(at.x,at.z)
		actor.drive_ground(at,frame_at(at,yaw),1./30.,probe,false,0);actor._process(1./30.)
		root_error=maxf(root_error,actor.global_position.distance_to(at))
		if motion.body_contact_error>max_body_error:
			max_body_error=motion.body_contact_error;max_body_at={"frame":i,"clip":motion.wanted_clip,"knee":motion.joint_contact_error}
		if motion.grounded_error>max_error:
			max_error=motion.grounded_error;max_error_at={"frame":i,"clip":motion.wanted_clip,"reach":motion.reach_debug.duplicate()}
		var skeleton: Skeleton3D=actor.anatomical_skeletons[0]
		for b in skeleton.get_bone_count():
			var pose:=skeleton.get_bone_global_pose(b);assert(pose.is_finite())
			if i==0:first_bones.append(pose)
			if i==80:bone_motion+=pose.origin.distance_to(first_bones[b].origin)
		center_camera(actor,form)
		if video:await photograph(form.id,"motion_%03d"%step);step+=1
		elif i in [30,110,220]:await photograph(form.id,"walk" if i==30 else ("run" if i==110 else "feed"))
	if max_body_error>=.01:
		push_error("Body contact requires correction: "+str(form.id)+" "+str(max_body_error)+" "+JSON.stringify(max_body_at));actor.free();quit(1);return
	assert(root_error<.00001 and bone_motion>.01)
	# Pose the authored strike for art review; no host attack or new damage is enabled.
	var socket_samples: Dictionary=await capture_attack(actor,form)
	var pose_capture_origin: Array=[at.x,at.y,at.z]
	if video:
		caption.text="공격 기관 · 준비 → 방출·물기 → 회수"
		for i in 84:
			motion.wanted_clip="attack";motion.pose_clock=float(i)/30.;motion.pose_step=1./30.;motion.pose_authored()
			await photograph(form.id,"motion_%03d"%step);step+=1
	actor.state="idle";actor.combat_override=true;actor.combat_phase="down";actor.combat_clock=1.1;motion.tick(1./30.);motion.pose_authored()
	assert(motion.wanted_clip=="down");caption.text="무력화 · 하중 내려놓기";await photograph(form.id,"down")
	if video:
		for i in 36:
			actor.combat_clock=float(i)/30.;motion.tick(1./30.);motion.pose_authored()
			await photograph(form.id,"motion_%03d"%step);step+=1
	actor.combat_override=false;actor.restored_down=true;motion.tick(1./30.);motion.pose_authored()
	assert(motion.wanted_clip=="down" and is_equal_approx(motion.pose_clock,1.19))
	actor.restored_down=false;actor.set_state("move");actor.lod_override=1
	at.z+=.05;at.y=height(at.x,at.z);actor.drive_ground(at,frame_at(at,0),1./30.,probe,false,0);actor._process(1./30.);center_camera(actor,form)
	assert(actor.visible_model==1 and actor.mouth_marker==motion.socket_nodes[1].Socket_Muzzle)
	caption.text="원거리 LOD · 같은 골격과 발사 기관";await photograph(form.id,"far")
	report.append({"id":form.id,"family":form.family,"species_id":original.id,"bone_count":form.bone_count,"clip_count":form.clips.size(),"limb_phase_checks":phase_checks,"root_error":root_error,"max_foot_target_error":max_error,"max_error_at":max_error_at,"bone_motion":bone_motion,"lods":2,"host_attack":host_pattern,"tested_host_flee_speed":fast_speed,"socket_samples":socket_samples,"authored_pose_capture_version":2,"contact_metadata_version":int(form.get("contact_metadata_version",0)),"pose_capture_origin":pose_capture_origin,"asset_sha256":{"near":form.lods.near.sha256,"far":form.lods.far.sha256}})
	report[-1].body_support_version=int(form.get("body_support_version",0));report[-1].max_body_contact_error=max_body_error
	print("REMODEL_BATCH ",form.id," bones=",form.bone_count," feet=",phase_checks," error=",max_error," body=",max_body_error);actor.free()

func audit_lod() -> void:
	var original:=FrontierEcologyCatalog.form("bio_runner_01")
	var actor:=Actor.new();actor.configure(original,{"scale":1.,"palette":original.palette});root.add_child(actor);actor.set_process(false)
	assert(actor.models.size()==2)
	var motion=actor.ground_motion
	actor.set_lod(true);motion.wanted_clip="run_loop";motion.pose_clock=.37;motion.pose_step=0.;motion.pose_authored(true)
	actor.set_lod(false);motion.wanted_clip="attack";motion.pose_clock=1.08;motion.pose_step=0.;motion.pose_authored(true)
	var near_skeleton: Skeleton3D=actor.anatomical_skeletons[0]
	var expected: Dictionary={}
	for bone in near_skeleton.get_bone_count():expected[near_skeleton.get_bone_name(bone)]=near_skeleton.get_bone_global_pose(bone)
	var phase_before: float=motion.phase;var model_before: int=actor.models[1].get_instance_id();var root_before:=actor.global_transform
	actor.set_lod(true);motion.pose_authored(true)
	var far_skeleton: Skeleton3D=actor.anatomical_skeletons[1];var maximum:=0.
	for bone in far_skeleton.get_bone_count():
		var actual:=far_skeleton.get_bone_global_pose(bone);var target: Transform3D=expected[far_skeleton.get_bone_name(bone)]
		maximum=maxf(maximum,actual.origin.distance_to(target.origin))
		for axis in 3:maximum=maxf(maximum,actual.basis[axis].distance_to(target.basis[axis]))
	assert(maximum<.00001)
	assert(motion.phase==phase_before and actor.models[1].get_instance_id()==model_before and actor.global_transform==root_before)
	print("REMODEL_LOD_POSE_SYNC hidden run -> visible strike; maximum transform error=",maximum,"; node, root and gait phase preserved")
	actor.free()

func audit_scope() -> void:
	var original:=FrontierEcologyCatalog.form("bio_hinge_book_01")
	assert(not Actor.RemodelRegistry.entry(original).is_empty())
	var actors: Array=[];var holder:=Node3D.new();root.add_child(holder)
	for i in 2:
		var actor:=Actor.new();actor.load_far=false;actor.configure(original,{"scale":1.,"palette":original.palette})
		holder.add_child(actor);actor.set_process(false);actor.ground_motion.tick(0);actor.ground_motion.pose_authored();actors.append(actor)
	var before: Array=[];var untouched: Skeleton3D=actors[1].anatomical_skeletons[0]
	var untouched_node: int=actors[1].models[0].get_instance_id()
	for b in untouched.get_bone_count():before.append(untouched.get_bone_global_pose(b))
	var actor=actors[0];actor.set_state("move")
	for i in 60:
		var at:=Vector3(0,height(0,float(i)*.05),float(i)*.05)
		actor.drive_ground(at,frame_at(at,0),1./30.,probe,false,0);actor._process(1./30.)
	var phase_before: float=actor.ground_motion.phase;var state_before: String=actor.state
	assert(not actor.set_state("attack") and actor.state==state_before and actor.ground_motion.phase==phase_before)
	actor.restored_down=true;actor.set_state("dormant");actor.ground_motion.tick(1./30.);actor.ground_motion.pose_authored()
	var own_skeleton: Skeleton3D=actor.anatomical_skeletons[0];var root_bone:=own_skeleton.find_bone("root")
	var down_pose:=own_skeleton.get_bone_global_pose(root_bone)
	assert(down_pose.origin.y<own_skeleton.get_bone_global_rest(root_bone).origin.y-.1)
	var down_time: float=actor.ground_motion.pose_clock
	actor.restored_down=true;actor.ground_motion.tick(1./30.);actor.ground_motion.pose_authored();assert(actor.ground_motion.pose_clock==down_time and own_skeleton.get_bone_global_pose(root_bone).is_equal_approx(down_pose))
	assert(actors[1].state=="idle" and actors[1].global_position==Vector3.ZERO and actors[1].models[0].get_instance_id()==untouched_node)
	assert(actors[1].ground_motion.phase==0 and actors[1].ground_motion.ground_samples.is_empty() and actors[1].ground_motion.settling_feet.is_empty())
	for b in untouched.get_bone_count():assert(before[b]==untouched.get_bone_global_pose(b))
	print("REMODEL_SCOPE one actor moved/restored; peer pose, node, phase and caches unchanged; rejected attack and duplicate restored state unchanged; no world save or request publisher invoked")
	# The growing catalogue reads one small entry on demand, once; no full batch manifest scan.
	var lazy_form:=FrontierEcologyCatalog.form("biota_spindle_armor_01")
	var reads_before: int=Actor.RemodelRegistry.individual_reads
	Actor.RemodelRegistry.entry_paths[lazy_form.id]="res://data/creature_remodel/r03/biota_spindle_armor_01.json"
	var entry:=Actor.RemodelRegistry.entry(lazy_form);assert(entry.source_id==lazy_form.id)
	Actor.RemodelRegistry.path(lazy_form,"near");Actor.RemodelRegistry.bounds(lazy_form)
	assert(Actor.RemodelRegistry.individual_reads==reads_before+1)
	print("REMODEL_LAZY_METADATA one individual file read; subsequent path/bounds reuse the cached entry")
	var pending_form:=original.duplicate(true);pending_form.id="review_pending_import"
	var pending_art: Dictionary=Actor.RemodelRegistry.entries[original.id].duplicate(true);pending_art.source_id=pending_form.id
	var valid_lods: Dictionary=pending_art.lods.duplicate(true)
	pending_art.lods.near.path="우주-비즈니스/assets/models/creature_remodel/review_missing_import.glb"
	Actor.RemodelRegistry.entries[pending_form.id]=pending_art
	assert(Actor.RemodelRegistry.entry(pending_form).is_empty())
	var fallback:=Actor.new();fallback.load_far=false;fallback.configure(pending_form,{"scale":1.,"palette":original.palette});holder.add_child(fallback)
	assert(fallback.remodel.is_empty() and fallback.models.size()==1)
	var fallback_node: int=fallback.models[0].get_instance_id()
	pending_art.lods=valid_lods
	assert(not Actor.RemodelRegistry.entry(pending_form).is_empty())
	assert(fallback.remodel.is_empty() and fallback.models[0].get_instance_id()==fallback_node)
	Actor.RemodelRegistry.entries.erase(pending_form.id)
	print("REMODEL_IMPORT_FALLBACK unfinished import keeps prior model; completed resources become available without resetting the existing actor")
	holder.free()
