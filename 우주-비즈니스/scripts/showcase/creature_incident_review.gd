extends "res://scripts/showcase/creature_remodel_field.gd"
## Actual imported actors with saved-native identity, giant scale and guardian clock adapters.
const NativeView=preload("res://scripts/world/native_incident_view.gd")
const NativeMotion=preload("res://scripts/actors/creatures/incident_motion.gd")
func run() -> void:
	folder=ProjectSettings.globalize_path("res://../output/creature-remodel/incidents");DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1100,800);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X
	stage=Node3D.new();root.add_child(stage)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("cbd5d0");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("bdccce");environment.environment.ambient_light_energy=.55;stage.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-52,-30,0);sun.shadow_enabled=true;stage.add_child(sun);terrain_mesh()
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.far=120;camera.current=true;stage.add_child(camera);Ink.attach(stage,true)
	title=Label.new();title.position=Vector2(24,20);title.add_theme_font_override("font",load("res://assets/fonts/NotoSansKR.ttf"));title.add_theme_font_size_override("font_size",24);title.add_theme_color_override("font_color",Color("203a36"));root.add_child(title)
	for test in [{"id":"bio_pentapalm_03","role":"giant","factor":4.},{"id":"bio_pendulum_grazer_01","role":"scavenger","factor":1.},{"id":"biota_spindle_armor_26","role":"guardian","factor":1.}]:
		if "--giant-only" in OS.get_cmdline_user_args() and test.role!="giant":continue
		await review_incident(test)
		if report.size()==0 or report[-1].id!=test.id:push_error("Incomplete incident render "+test.id);quit(1);return
	FileAccess.open(folder+"/evidence.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"scope":"saved-native presentation adapter; host row and peer preserved; no new damage or placement","records":report},"\t"))
	print("REMODEL_INCIDENT_DONE ",report.size());quit()

func review_incident(test: Dictionary) -> void:
	var original:=FrontierEcologyCatalog.form(test.id);var look_id:=FrontierEcologyCatalog.look_for_seed(test.id,0)
	var base:=FrontierEcologyCatalog.look(test.id,look_id);var geometry: Dictionary=original.geometry.near
	var old_dimensions: Vector3=FrontierCrewWorld.vector(geometry.max)-FrontierCrewWorld.vector(geometry.min)
	var native: Dictionary={"form_id":test.id,"look_id":look_id,"role":test.role,"factor":test.factor,"palette":base.palette.duplicate(),"height":old_dimensions.y*float(base.scale)*test.factor,"width":old_dimensions.x*float(base.scale)*test.factor,"length":old_dimensions.z*float(base.scale)*test.factor}
	var row: Dictionary={"native":native,"native_alert":0.,"native_attack":0,"native_wait":0.,"native_observed":false}
	var native_before:=native.duplicate(true)
	var actor:=NativeView.make_actor(native,FrontierNativeIncidents.look(native));stage.add_child(actor);actor.set_process(false);actor.lod_override=0
	assert(not actor.remodel.is_empty() and is_equal_approx(actor.base_scale,float(base.scale)*float(test.factor)))
	var peer:=NativeView.make_actor(native,FrontierNativeIncidents.look(native));stage.add_child(peer);peer.set_process(false);peer.hide()
	var peer_skeleton: Skeleton3D=peer.anatomical_skeletons[0];var peer_poses: Array=[]
	for i in peer_skeleton.get_bone_count():peer_poses.append(peer_skeleton.get_bone_pose(i))
	var dimensions:=NativeView.displayed_dimensions(actor,native);var center:=NativeView.displayed_center(actor,native)
	assert(is_equal_approx(center.y,dimensions.y*.5))
	var unscaled: Dictionary=actor.remodel.lods.near
	assert(dimensions.is_equal_approx((FrontierCrewWorld.vector(unscaled.max)-FrontierCrewWorld.vector(unscaled.min))*actor.base_scale))
	var at:=Vector3(0,height(0,0),0);var max_error:=0.;var socket_motion:=0.;var first_socket:=Vector3.ZERO;var worst: Dictionary={}
	var cfg: Dictionary=FrontierNativeIncidents.config();var snapshot: Dictionary={}
	for i in 180:
		var t:=float(i)/30.;var label:="거대 개체  세 축 4배" if test.role=="giant" else "운반 개체  말단 구강"
		if test.role=="guardian":
			var warning_time:=float(cfg.guard_warning)
			row.native_alert=minf(t,warning_time)
			if t>=warning_time:row.native_attack=1;row.native_wait=maxf(0,float(cfg.guard_cooldown)-(t-warning_time))
			if t>4.8:row.native_alert=0.;row.native_wait=0.
			actor.incident_pose=NativeMotion.sample(actor,row);label="둥지 보호  실제 경고/시도 시계"
			if i==30:assert(not actor.incident_pose.is_empty())
			if i==165:assert(actor.incident_pose.is_empty())
			var wanted: String="stressed" if row.native_alert>0 else "idle"
			if actor.state!=wanted:actor.set_state(wanted)
		else:
			if actor.state!="move":actor.set_state("move")
			var speed:=float(cfg.roles[test.role].speed)/sqrt(float(test.factor));at.z+=speed/30.;at.y=height(at.x,at.z)
		actor.drive_ground(at,frame_at(at,0),1./30.,probe,false,0);actor._process(1./30.)
		if actor.ground_motion.grounded_error>max_error:
			max_error=actor.ground_motion.grounded_error;worst={"frame":i,"reach":actor.ground_motion.reach_debug.duplicate(),"scale":actor.base_scale,"clip":actor.ground_motion.wanted_clip}
		assert(actor.global_position.distance_to(at)<.00001)
		assert(native==native_before and peer.incident_pose.is_empty() and peer.global_position==Vector3.ZERO)
		var socket: Vector3=actor.mouth_marker.global_position
		if i==0:first_socket=socket
		else:socket_motion=maxf(socket_motion,socket.distance_to(first_socket))
		for j in peer_skeleton.get_bone_count():assert(peer_skeleton.get_bone_pose(j)==peer_poses[j])
		var focus:=actor.global_transform*center;camera.size=maxf(dimensions.x,maxf(dimensions.y,dimensions.z))*1.0+1.5;camera.position=focus+Vector3(4.2,3.,7.5)*maxf(1,actor.base_scale);camera.look_at(focus);title.text=str(original.name)+"  "+label
		if i in [0,30,60,90,120,150,179]:
			await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/"+test.id+"_%03d.png"%i)
	if max_error>=.025 or socket_motion<=.01:print("INCIDENT_DIAGNOSTIC ",test.id," max=",max_error," socket=",socket_motion," ",worst)
	assert(max_error<.025 and socket_motion>.01)
	report.append({"id":test.id,"role":test.role,"factor":test.factor,"source_id_preserved":true,"native_saved_fields_unchanged":true,"peer_unchanged":true,"max_foot_target_error":max_error,"mouth_socket_motion":socket_motion,"displayed_dimensions":[dimensions.x,dimensions.y,dimensions.z]})
	print("REMODEL_INCIDENT ",test.id," ",test.role," IK=",max_error);actor.free();peer.free()
