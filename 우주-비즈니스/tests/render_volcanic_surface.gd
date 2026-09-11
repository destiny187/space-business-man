extends SceneTree
## Focused native INK review of the packed lava texture, distance and cooling.
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var folder:=ProjectSettings.globalize_path("res://../output/volcanic-review")
 var reference:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):folder=arg.trim_prefix("--output=")
  if arg.begins_with("--reference-shader="):reference=arg.trim_prefix("--reference-shader=")
 DirAccess.make_dir_recursive_absolute(folder)
 root.size=Vector2i(1280,800);root.msaa_3d=Viewport.MSAA_4X
 var scene:=Node3D.new();root.add_child(scene)
 var world:=WorldEnvironment.new();var env:=Environment.new();world.environment=env;scene.add_child(world)
 env.background_mode=Environment.BG_COLOR;env.background_color=Color("343a45")
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("ccd7e5");env.ambient_light_energy=.4
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-25,0);sun.light_energy=1.15;sun.shadow_enabled=true;scene.add_child(sun)
 var traits: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_diversity.json")).archetypes.volcanic
 var material:=ShaderMaterial.new();material.shader=load("res://assets/materials/space/terrain.gdshader")
 if not reference.is_empty():
  var shader:=Shader.new();shader.code=FileAccess.get_file_as_string(reference);material.shader=shader
  # The previous packed source remains available for an exact visual reference.
  for row in FrontierSurfaceMaterialLibrary.config().materials:
   if row.id=="lava":row.texture="res://assets/textures/surfaces/lava.png"
 traits=traits.duplicate(true);traits.id="volcanic"
 FrontierSurfaceMaterialLibrary.configure(material,{"traits":traits})
 material.set_shader_parameter("rock_color",Color(traits.rock));material.set_shader_parameter("dust_color",Color(traits.dust))
 material.set_shader_parameter("molten",true);material.set_shader_parameter("geology_phase",3.2)
 var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(500,500);ground.mesh=plane;ground.material_override=material;scene.add_child(ground)
 var ledge:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(8,3,4);ledge.mesh=box;ledge.material_override=material;ledge.position=Vector3(8,1.5,-8);scene.add_child(ledge)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.far=1500
 FrontierInkStyle.attach(scene)
 var captures: Array=[]
 for shot in ["close-day","play-day","play-night","backlit","far","cooled"]:
  camera.look_at_from_position(Vector3(0,2.0,3.5),Vector3(0,0,-.8))
  sun.rotation_degrees=Vector3(-48,-25,0);sun.light_energy=1.15;env.ambient_light_energy=.4
  if shot.begins_with("play") or shot=="backlit":camera.look_at_from_position(Vector3(0,3,11),Vector3(0,0,-5))
  if shot=="play-night":sun.light_energy=.07;env.ambient_light_energy=.10
  if shot=="backlit":sun.rotation_degrees=Vector3(-12,165,0);env.ambient_light_energy=.2
  if shot=="far":camera.look_at_from_position(Vector3(0,70,145),Vector3(0,0,-20))
  if shot=="cooled":
   material.set_shader_parameter("region_count",1)
   material.set_shader_parameter("region_points",PackedVector4Array([Vector4(0,0,0,10000)]))
   material.set_shader_parameter("region_values",PackedVector4Array([Vector4(80,0,0,1.8)]))
   material.set_shader_parameter("region_extras",PackedVector4Array([Vector4.ZERO]))
  for i in 20:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(folder+"/"+shot+".png")
  captures.append(shot)
 print("VOLCANIC_NATIVE_REVIEW ",captures)
 quit()
