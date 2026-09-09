extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1280,900)
 var stage:=Node3D.new();root.add_child(stage)
 var world:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("192731");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("a2b5b9");env.ambient_light_energy=.35;world.environment=env;stage.add_child(world)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-25,0);light.light_energy=1.5;light.shadow_enabled=true;stage.add_child(light)
 var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(60,60);ground.mesh=plane;ground.position.y=-2.6;var mat:=ShaderMaterial.new();mat.shader=FrontierInkStyle.CEL;mat.set_shader_parameter("base_color",Color("52606a"));ground.material_override=mat;stage.add_child(ground)
 var hull: Node3D=load("res://assets/models/ships/kestrel.glb").instantiate();FrontierInkStyle.apply(hull,{});stage.add_child(hull)
 var refits:=FrontierVesselVisuals.new();hull.add_child(refits)
 var suit: Node3D=load("res://assets/models/crew/surveyor_suit.glb").instantiate();FrontierInkStyle.apply(suit,{});suit.position=Vector3(2.4,-2.6,11);stage.add_child(suit)
 var camera:=Camera3D.new();camera.position=Vector3(21,13,28);stage.add_child(camera);camera.look_at(Vector3(0,-.5,1));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=24;camera.current=true;FrontierInkStyle.attach(stage,true)
 for entry in [["stowed",0.0,0.0],["touchdown",1.0,0.0],["open",1.0,1.0]]:
  refits.landing_override={"deployment":entry[1],"hatch":entry[2]}
  await create_timer(.8).timeout;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/production/media/landing-polish/kestrel-"+entry[0]+"-ink.png"))
 print("LANDING ASSEMBLY INK: stowed, deployed and open with crew scale rendered")
 stage.queue_free();await process_frame;quit()
