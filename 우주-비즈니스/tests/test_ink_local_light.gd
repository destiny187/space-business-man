extends SceneTree
var failures:=0
func _initialize() -> void:call_deferred("run")
func sample() -> float:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var pixel:=root.get_texture().get_image().get_pixel(320,240)
	return (pixel.r+pixel.g+pixel.b)/3.0
func run() -> void:
	root.size=Vector2i(640,480)
	var stage:=Node3D.new();root.add_child(stage)
	var world:=WorldEnvironment.new();var environment:=Environment.new()
	environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.BLACK
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_DISABLED
	world.environment=environment;stage.add_child(world)
	var camera:=Camera3D.new();stage.add_child(camera);camera.current=true
	var wall:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(8,8)
	wall.mesh=quad;wall.position.z=-12
	var material:=ShaderMaterial.new();material.shader=load("res://assets/materials/ink/cel.gdshader")
	material.set_shader_parameter("base_color",Color(.45,.4,.3));material.set_shader_parameter("rough",.96)
	wall.material_override=material;stage.add_child(wall)
	var lamp:=SpotLight3D.new();lamp.light_energy=10;lamp.spot_range=60;lamp.spot_angle=48;stage.add_child(lamp)
	var far_value: float=await sample()
	wall.position.z=-3
	var near_value: float=await sample()
	lamp.visible=false
	var dark_value: float=await sample()
	for condition in [far_value>dark_value+.08,near_value>far_value+.05,dark_value<.02]:
		if not condition:failures+=1
	print("INK_LOCAL_LIGHT near=",near_value," far=",far_value," off=",dark_value," CHECKS 3 FAILURES ",failures)
	if failures:printerr("FAIL: local lamp must retain distance falloff without directional shadow threshold")
	stage.queue_free();await process_frame
	quit(1 if failures else 0)
