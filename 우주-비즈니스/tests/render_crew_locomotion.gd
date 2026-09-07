extends SceneTree
var stage: Node3D
var poses: Array[FrontierCrewPose]=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1440,900)
	stage=Node3D.new();root.add_child(stage);current_scene=stage
	var audio:=FrontierAudio.new();stage.add_child(audio)
	var environment:=WorldEnvironment.new();var env:=Environment.new();environment.environment=env
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("253642");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("adc4d0");env.ambient_light_energy=.45;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;stage.add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-30,0);light.light_energy=1.4;light.shadow_enabled=true;stage.add_child(light)
	var floor:=StaticBody3D.new();stage.add_child(floor)
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(30,.1,20);collision.shape=shape;collision.position.y=-.05;floor.add_child(collision)
	var mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(30,20);mesh.mesh=plane
	var material:=StandardMaterial3D.new();material.albedo_color=Color("677273");mesh.material_override=material;floor.add_child(mesh)
	var cache: Dictionary={};FrontierInkStyle.apply(floor,cache);FrontierInkStyle.attach(stage)
	var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(3.4,3.6,8.8);camera.look_at(Vector3(0,.8,0));camera.current=true
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8.8
	var states: Array[String]=["idle","walk","run","rise","land"]
	for i in states.size():
		var model: Node3D=load("res://assets/models/crew/surveyor_suit.glb").instantiate();stage.add_child(model);model.position=Vector3((i-2)*1.55,0,0);FrontierInkStyle.apply(model,cache)
		var pose:=FrontierCrewPose.new();stage.add_child(pose);pose.position=model.position;pose.configure(model);poses.append(pose)
		var motion:=FrontierCrewLocomotion.create();motion.grounded=states[i]!="rise";motion.state=states[i];motion.velocity=[0,3 if i==3 else 0,-(6 if i==2 else 3 if i==1 else 0)];motion.phase=1.2;motion.yaw=PI
		if i==3:model.position.y=.45
		for frame in 50:pose.animate(motion,1.0/60,false,false)
		if i==4:pose.compression=.75;pose.animate(motion,.016,false,false)
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	var out:=ProjectSettings.globalize_path("res://../docs/production/media/crew-locomotion/ink-poses.png")
	root.get_texture().get_image().save_png(out)
	print("INK_POSES ",out)
	for pose in poses:
		assert(pose.bones.size()==13)
		print("KNEE ",pose.skeleton.get_bone_pose_rotation(pose.bones.shin_L)," REST ",pose.rest.shin_L)
	await create_timer(.2).timeout;quit()
