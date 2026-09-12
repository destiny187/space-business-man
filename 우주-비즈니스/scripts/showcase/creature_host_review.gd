extends "res://tests/check_wildlife_combat.gd"
## Actual host attack steps driving approved skins. Fixture-only registry injection.
const Actor=preload("res://scripts/actors/creatures/bestiary_actor.gd")
const Ink=preload("res://scripts/actors/ink_style.gd")
const Attacks=preload("res://scripts/domain/wildlife_attacks.gd")
var camera: Camera3D
var label: Label
var records: Array=[]
func run() -> void:
	var batch:="combat"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--batch="):batch=argument.trim_prefix("--batch=")
	assert(batch.is_valid_identifier())
	folder=ProjectSettings.globalize_path("res://../output/creature-remodel/"+("combat" if batch=="combat" else "combat-"+batch));DirAccess.make_dir_recursive_absolute(folder)
	check(fixture(),"host terrain fixture")
	if chosen.is_empty():quit(1);return
	root.size=Vector2i(1100,800);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X
	var stage:=Node3D.new();root.add_child(stage)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("cbd5d0");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("bdccce");environment.environment.ambient_light_energy=.65;stage.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-50,-30,0);sun.shadow_enabled=true;stage.add_child(sun)
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-14,20):
		for x in range(-15,16):
			for i in [0,2,1,1,2,3]:
				var px: float=home.x+x+(i%2);var pz: float=home.z+z+floori(i/2.)
				var at:=Vector3(px,field.height(px,pz),pz);surface.set_normal(field.normal(at));surface.add_vertex(at)
	var ground:=MeshInstance3D.new();ground.mesh=surface.commit();var mat:=StandardMaterial3D.new();mat.albedo_color=Color("aeb8a7");ground.material_override=Ink.material(mat,{});stage.add_child(ground)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8.7;camera.far=100;camera.current=true;stage.add_child(camera);Ink.attach(stage,true)
	label=Label.new();label.position=Vector2(24,20);label.add_theme_font_override("font",load("res://assets/fonts/NotoSansKR.ttf"));label.add_theme_font_size_override("font_size",23);label.add_theme_color_override("font_color",Color("203a36"));root.add_child(label)
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/creature_remodel_"+batch+".json"))
	var filter:=Array(OS.get_cmdline_user_args()).filter(func(x):return not x.begins_with("--"))
	for form in manifest.forms:
		if form.get("host_motion","").is_empty():continue
		if not filter.is_empty() and form.id not in filter:continue
		for mode in (["blocked"] if "--blocked-only" in OS.get_cmdline_user_args() else ["hit","miss","blocked"]):await exercise(stage,form,mode)
	FileAccess.open(folder+"/evidence.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"actual_host_step":true,"records":records,"failures":failures},"\t"))
	print("REMODEL_HOST_REVIEW ",records.size()," FAILURES ",failures);quit(1 if failures else 0)

func exercise(stage: Node3D,form: Dictionary,outcome: String) -> void:
	var original:=FrontierEcologyCatalog.form(form.source_id);Actor.RemodelRegistry.entry(original);Actor.RemodelRegistry.entries[original.id]=form
	var row:=chosen.duplicate();row.form_id=original.id;row.look_id=FrontierEcologyCatalog.look_for_seed(original.id,0);row.combat_tier=1;row.point=home;row.home_point=home
	var info:=FrontierWildlifeCombat.profile(row);var before_info:=JSON.stringify(info)
	var look:=FrontierEcologyCatalog.look(row.form_id,row.look_id)
	var ready_scenes: Array=[]
	for lod in ["near","far"]:
		var gltf:=GLTFDocument.new();var state:=GLTFState.new();assert(gltf.append_from_file("res://"+str(form.lods[lod].path).trim_prefix("우주-비즈니스/"),state)==OK)
		var model:=gltf.generate_scene(state);var packed:=PackedScene.new();assert(packed.pack(model)==OK);model.free();ready_scenes.append(packed)
	var actor:=Actor.new();actor.lod_override=0;actor.configure(original,look,ready_scenes);stage.add_child(actor);actor.set_process(false)
	var peer:=Actor.new();peer.load_far=false;peer.configure(original,look,[ready_scenes[0]]);stage.add_child(peer);peer.set_process(false);peer.hide()
	var untouched:=peer.models[0].get_instance_id();var untouched_phase: float=peer.ground_motion.phase
	core.world.crew.combat={};core.world.crew.wildlife_encounters={}
	var live:=FrontierWildlifeCombat.ensure(core.world.crew,body.id,row);live.target=actor_id;live.aim=[0,0,1];live.yaw=0
	var member: Dictionary=core.world.crew.members[actor_id];member.vitals.health=100;member.vitals.protection=0;member.vitals.shield=0
	var distance: float=4.5 if info.behavior in ["charge","leap"] else maxf(1.,float(info.reach)*.65)
	var target:=home+Vector3(0,0,distance);target.y=field.height(target.x,target.z)+.1;member.position=FrontierExplorationIncidents.array(target)
	FrontierWildlifeCombat.set_phase(live,"attack");Attacks.begin(live,info,target,field,row)
	if outcome=="miss":member.position=FrontierExplorationIncidents.array(target+Vector3(5,0,0))
	var probe:=func(at: Vector3,_reach: float):return {"point":Vector3(at.x,field.height(at.x,at.z),at.z),"normal":field.normal(at)}
	var obstacle:=func(_a,_b,_from,to,_radius,_height):return outcome!="blocked" or Vector3(to).z<home.z+minf(2.8,distance*.6)
	var clips: Dictionary={};var max_error:=0.;var root_error:=0.;var damage_events:=0;var prior_health:=100.;var presentation_unchanged:=true;var frame_files: Array=[]
	var max_error_at: Dictionary={}
	var duration: float=info.windup+info.active+info.recovery-.04
	for i in ceili(duration*30):
		live.time+=1./30.;Attacks.step(core.world,row,live,info,[actor_id],field,1./30.,obstacle)
		if live.phase!="attack":break
		var before_live:=JSON.stringify(live)
		actor.apply_combat(live,info,false,core.world.crew.members);var at:=FrontierWildlifeCombat.body_position(live)
		actor.drive_ground(at,FrontierEcologyPlacement.surface_basis(field.normal(at),0),1./30.,probe,false,0);actor._process(1./30.)
		root_error=maxf(root_error,actor.global_position.distance_to(at));clips[actor.ground_motion.wanted_clip]=true
		if actor.ground_motion.grounded_error>max_error:
			max_error=actor.ground_motion.grounded_error;max_error_at={"time":live.time,"clip":actor.ground_motion.wanted_clip,"pose_clock":actor.ground_motion.pose_clock,"reach":actor.ground_motion.reach_debug.duplicate()}
		if float(member.vitals.health)<prior_health:damage_events+=1;prior_health=member.vitals.health
		presentation_unchanged=presentation_unchanged and JSON.stringify(live)==before_live
		var center:=at+Vector3.UP*1.;camera.size=5.4;camera.position=center+Vector3(6,4.2,9);camera.look_at(center)
		label.text=form.name+" · "+str(info.behavior)+" · "+outcome+" · "+actor.ground_motion.wanted_clip
		if "--video" in OS.get_cmdline_user_args() and outcome=="hit" or i in [12,28,40,49,60,78]:
			await process_frame;await RenderingServer.frame_post_draw
			var filename: String=form.id+"_"+outcome+"_%03d.png"%i
			root.get_texture().get_image().save_png(folder+"/"+filename);frame_files.append(filename)
		presentation_unchanged=presentation_unchanged and peer.models[0].get_instance_id()==untouched and is_equal_approx(peer.ground_motion.phase,untouched_phase)
	check(root_error<.00001 and max_error<.025,"host root and charging contact")
	var expected_hits:=2 if info.behavior=="double_sweep" else 1
	check(damage_events==expected_hits if outcome=="hit" else damage_events==0,"host contact outcome "+outcome)
	check(actor.remodel_effects.emitted_contacts==damage_events,"only confirmed host hits create contact effects")
	check(JSON.stringify(info)==before_info,"art does not mutate attack balance")
	check(presentation_unchanged,"presentation preserves host state and unrelated actor")
	if outcome=="hit":
		check(clips.has("charge_loop") if info.behavior=="charge" else (clips.has("leap_air") and clips.has("leap_land") if info.behavior=="leap" else clips.has("attack")),"host-compatible clips")
	records.append({"id":form.id,"outcome":outcome,"host_behavior":info.behavior,"host_speed":info.get("charge_speed",info.speed),"clips":clips.keys(),"root_error":root_error,"max_foot_target_error":max_error,"damage_events":damage_events,"remaining_health":member.vitals.health,"unchanged_balance":true,"unrelated_actor_preserved":presentation_unchanged,"rendered_contacts":actor.remodel_effects.emitted_contacts,"frames":frame_files})
	print("REMODEL_HOST ",form.id," ",outcome," ",clips.keys()," hits=",damage_events," IK=",max_error)
	if max_error>.025:print("HOST_REACH_DIAGNOSTIC ",max_error_at)
	if outcome=="hit":
		var down_live:=live.duplicate(true);down_live.phase="down";down_live.time=1.1
		actor.apply_combat(down_live,info,false);actor._process(1./30.);assert(actor.ground_motion.wanted_clip=="down")
		var skeleton: Skeleton3D=actor.anatomical_skeletons[0];var bone:=skeleton.find_bone("root")
		assert(skeleton.get_bone_global_pose(bone).origin.y<skeleton.get_bone_global_rest(bone).origin.y-.1)
		label.text=form.name+" · 무력화"
		await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/"+form.id+"_down.png")
		actor.combat_override=false;actor.restored_down=true;actor._process(1./30.);assert(is_equal_approx(actor.ground_motion.pose_clock,1.19))
	actor.free();peer.free()
