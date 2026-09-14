extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1100,800)
 var stage:=Node3D.new();root.add_child(stage)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("ced7d0");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("bdccce");env.environment.ambient_light_energy=.5;stage.add_child(env)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.shadow_enabled=true;stage.add_child(sun)
 var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(12,12);ground.mesh=plane;stage.add_child(ground)
 var model: Node3D=load("res://assets/models/"+str(FrontierSuitAppearance.config().model)+".glb").instantiate();stage.add_child(model)
 var pose:=FrontierCrewPose.new();stage.add_child(pose);pose.configure(model)
 var jet:=preload("res://scripts/actors/jetpack_visual.gd").new();stage.add_child(jet);jet.configure(model,pose.skeleton)
 FrontierInkStyle.apply(model,{});FrontierInkStyle.attach(stage,true)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.65;camera.current=true;stage.add_child(camera);camera.position=Vector3(3,2.3,4);camera.look_at(Vector3(0,1,0))
 var motion:=FrontierCrewLocomotion.create();motion.state="rise";motion.velocity=[0,6,0]
 jet.sync(true,true,true,false)
 for frame in 15:pose.animate(motion,1./30.,false,false);await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/flight-combat/worn-studio.png"))
 print("JETPACK_STUDIO_OK");quit()
