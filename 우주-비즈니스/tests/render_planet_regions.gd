extends SceneTree
const Regions=preload("res://scripts/world/surface_regions.gd")
const Palette=preload("res://scripts/world/surface_palette.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1280,800);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X
 var folder:=ProjectSettings.globalize_path("res://../docs/production/media/planet-variety/regions")
 DirAccess.make_dir_recursive_absolute(folder)
 var scene:=Node3D.new();root.add_child(scene)
 var env:=WorldEnvironment.new();env.environment=Environment.new();scene.add_child(env)
 env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("9cabb6")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("c6d3df");env.environment.ambient_light_energy=.55
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-38,-30,0);sun.light_energy=1.3;sun.shadow_enabled=true;sun.directional_shadow_max_distance=200;scene.add_child(sun)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.far=600
 var mesh:=MeshInstance3D.new();scene.add_child(mesh);FrontierInkStyle.attach(scene)
 var reports: Dictionary={}
 for id in FrontierPlanetTraits.rules().archetypes:
  var traits: Dictionary=FrontierPlanetTraits.rules().archetypes[id].duplicate(true);traits.id=id
  var rules:=Regions.definition(traits)
  if rules.is_empty():continue
  var body: Dictionary={"seed":71503,"traits":traits}
  var profile:=FrontierSurfaceMaterialLibrary.profile_for(body);var ids:=Palette.ids_for(profile)
  assert(ids.size()<=6 and ids.size()>=3)
  var legacy: Dictionary=traits.duplicate(true);legacy.terrain_layout.erase("surface_regions")
  assert(not FrontierSurfaceMaterialLibrary.profile_for({"seed":71503,"traits":legacy}).has("region_rocks"))
  # Pre-diversity saves expose present-day preview traits, but have no terrain rules.
  assert(not FrontierSurfaceMaterialLibrary.profile_for({"seed":71503,"traits":traits,"terrain_traits":{}}).has("region_rocks"))
  var field:=FrontierTerrainField.new();field.configure(71503,[],24,traits)
  var counts: Array[int]=[0,0,0];var points: Dictionary={};var best: Array[float]=[INF,INF,INF]
  var phase:=FrontierSurfaceGeology.phase(traits)
  for z in range(220,1601,35):
   for x in range(220,1601,35):
    var p:=Vector3(x,field.height(x,z),z);var weights:=Regions.weights(p,rules,phase)
    assert(is_equal_approx(weights.x+weights.y+weights.z,1.0) and weights.x>=0 and weights.y>=0 and weights.z>=0)
    assert(weights==Regions.weights(p,JSON.parse_string(JSON.stringify(rules)),phase))
    for zone in 3:
     if weights[zone]>.90:
      counts[zone]+=1
      var slope:=absf(field.height(x+2,z)-field.height(x-2,z))+absf(field.height(x,z+2)-field.height(x,z-2))
      if slope<best[zone]:best[zone]=slope;points[zone]=p
  assert(points.size()==3,id+" has an unreachable geological region")
  reports[id]={"names":rules.names,"rocks":profile.region_rocks,"palette":ids,"sample_counts":counts,"points":points}
  if not id in ["oxidized","frozen","volcanic"]:continue
  var mat:=ShaderMaterial.new();mat.shader=load("res://assets/materials/space/terrain.gdshader")
  mat.set_shader_parameter("rock_color",Color(traits.rock));mat.set_shader_parameter("dust_color",Color(traits.dust));mat.set_shader_parameter("molten",id=="volcanic")
  mat.set_shader_parameter("geology_phase",phase);FrontierSurfaceMaterialLibrary.configure(mat,body);mesh.material_override=mat
  assert((mat.get_shader_parameter("surface_textures") as Texture2DArray).get_layers()==ids.size())
  for zone in 3:
   var center: Vector3=points[zone];var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
   var count:=64
   for z in count+1:
    for x in count+1:
     var p:=center+Vector3((x-count*.5)*2,0,(z-count*.5)*2);p.y=field.height(p.x,p.z)
     vertices.append(p);colors.append(Color.WHITE)
     normals.append(Vector3(field.height(p.x-.5,p.z)-field.height(p.x+.5,p.z),1,field.height(p.x,p.z-.5)-field.height(p.x,p.z+.5)).normalized())
   for z in count:
    for x in count:
     var a:=x+z*(count+1);var b:=a+count+1;indices.append_array(PackedInt32Array([a,a+1,b,a+1,b+1,b]))
   mesh.mesh=FrontierTerrainMesher.mesh({"vertices":vertices,"normals":normals,"colors":colors,"indices":indices})
   camera.look_at_from_position(center+Vector3(0,18,25),center)
   for i in 12:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(folder+"/%s-%d.png"%[id,zone])
 FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
 print("REGIONAL_REVIEW 12 families; saved rules reproduced; old worlds opt out; 3 reachable zones each; palette <=6; 9 close renders")
 quit()
