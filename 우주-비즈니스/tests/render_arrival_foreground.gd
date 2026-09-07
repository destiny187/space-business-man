extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1280,800)
 var stage:=Control.new();root.add_child(stage);stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var background:=ColorRect.new();stage.add_child(background);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var clouds:=ShaderMaterial.new();clouds.shader=load("res://assets/materials/space/arrival_cloud.gdshader");clouds.set_shader_parameter("cover",1.0);clouds.set_shader_parameter("tint",Color("ca7950"));background.material=clouds
 var vessel=load("res://scripts/ui/arrival_vessel.gd").new();stage.add_child(vessel);vessel.configure({})
 vessel.camera.position=Vector3(0,8,28.5);vessel.camera.look_at(Vector3.ZERO)
 var foreground:=ColorRect.new();stage.add_child(foreground);foreground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var material:=ShaderMaterial.new();material.shader=load("res://assets/materials/space/arrival_flow.gdshader");material.set_shader_parameter("strength",1.0);material.set_shader_parameter("tint",Color("ca7950"));foreground.material=material
 for i in 12:await process_frame
 var folder:=ProjectSettings.globalize_path("res://../test-results/arrival-foreground")
 DirAccess.make_dir_recursive_absolute(folder)
 for time in [0.0,0.8,1.6]:
  material.set_shader_parameter("flow_time",time)
  await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(folder+"/cloud-%.1f.png"%time)
 print("FOREGROUND RENDER PASS: real INK hull with three animated foreground cloud phases")
 stage.queue_free();await process_frame;quit()
