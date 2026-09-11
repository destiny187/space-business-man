extends SceneTree
const Palette=preload("res://scripts/world/surface_palette.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1400,950);root.msaa_3d=Viewport.MSAA_4X
 var folder:=ProjectSettings.globalize_path("res://../docs/production/media/terraform-surfaces")
 DirAccess.make_dir_recursive_absolute(folder)
 var cfg:=FrontierSurfaceMaterialLibrary.config();var report: Dictionary={}
 for id in cfg.profiles:
  var chosen: Dictionary={}
  for seed_value in 24:
   var body: Dictionary={"seed":seed_value,"traits":{"id":id}}
   var profile:=FrontierSurfaceMaterialLibrary.profile_for(body)
   assert(profile==FrontierSurfaceMaterialLibrary.profile_for(body))
   chosen[profile.deposit]=true
  var profile:=FrontierSurfaceMaterialLibrary.profile_for({"seed":71503,"traits":{"id":id}})
  var ids:=Palette.ids_for(profile)
  var a:=Palette.texture(ids,cfg.materials);var b:=Palette.texture(ids,cfg.materials)
  assert(a==b and a.get_layers()<=4)
  report[id]={"seeded_deposits":chosen.keys(),"active_maps":ids,"layers":a.get_layers()}
 var scene:=Node3D.new();root.add_child(scene)
 var env:=WorldEnvironment.new();env.environment=Environment.new();scene.add_child(env)
 env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("2a3039")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("c0cdda");env.environment.ambient_light_energy=.55
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-35,0);sun.light_energy=1.3;sun.shadow_enabled=true;scene.add_child(sun)
 var names: Array[String]=["desiccated_clay","stony_loam","talus_fragments","alluvial_pebbles","wind_scoured","ash_drift","humus_crumb","pioneer_mat"]
 for i in names.size():
  var id:=names[i];var ids: Array[String]=[id,"gravel","snow","ice"]
  var mat:=ShaderMaterial.new();mat.shader=load("res://assets/materials/space/terrain.gdshader")
  mat.set_shader_parameter("surface_textures",Palette.texture(ids,cfg.materials));mat.set_shader_parameter("textured_surface",true)
  mat.set_shader_parameter("rock_layer",0);mat.set_shader_parameter("deposit_layer",0)
  mat.set_shader_parameter("rock_meters",4.0);mat.set_shader_parameter("deposit_meters",4.0)
  mat.set_shader_parameter("rock_color",Color("86949b"));mat.set_shader_parameter("dust_color",Color("86949b"))
  var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(3.7,.7,3.7);mesh.mesh=box;mesh.position=Vector3((i%4-1.5)*4.3,0,(i/4-.5)*4.5);mesh.material_override=mat;scene.add_child(mesh)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=12.0;camera.look_at_from_position(Vector3(0,14,12),Vector3.ZERO)
 FrontierInkStyle.attach(scene)
 for frame in 20:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder+"/godot-soils.png")
 FileAccess.open(folder+"/t01-palettes.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("SOIL_REVIEW ",cfg.materials.size()," catalog maps; 12 seeded profiles; active palette <=4; live arrays shared")
 quit()
