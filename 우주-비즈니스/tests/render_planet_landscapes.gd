extends SceneTree
## Height-field review from the production sampler; streaming play is checked separately.
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1280,800);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X
 var folder:=ProjectSettings.globalize_path("res://../docs/production/media/planet-variety/landforms")
 DirAccess.make_dir_recursive_absolute(folder)
 var scene:=Node3D.new();root.add_child(scene)
 var env:=WorldEnvironment.new();env.environment=Environment.new();scene.add_child(env)
 env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("9cabb6")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("c6d3df");env.environment.ambient_light_energy=.55
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-38,-30,0);sun.light_energy=1.3;sun.shadow_enabled=true;sun.directional_shadow_max_distance=1800;scene.add_child(sun)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.far=3000
 var mesh:=MeshInstance3D.new();scene.add_child(mesh)
 var source:=StandardMaterial3D.new();source.albedo_color=Color("8f9b9c");source.roughness=.94
 mesh.material_override=FrontierInkStyle.material(source,{})
 FrontierInkStyle.attach(scene)
 var config:=FrontierPlanetTraits.rules();var reports: Dictionary={}
 for id in config.archetypes:
  var traits: Dictionary=config.archetypes[id].duplicate(true)
  if not traits.has("terrain_layout"):continue
  var field:=FrontierTerrainField.new();field.configure(71503,[],24,traits)
  var center:=Vector2(650,650)
  if field.landscape.mode in ["impact","basin","volcanic","spire","karst"]:
   var landmark: Vector4=field.landscape.site_at(650,650);center=Vector2(landmark.x,landmark.y)
  var size:=800.0;var count:=100;var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var indices:=PackedInt32Array()
  var start:=Time.get_ticks_usec()
  for z in count+1:
   for x in count+1:
    var p:=Vector3(center.x-size*.5+x*size/count,0,center.y-size*.5+z*size/count);p.y=field.height(p.x,p.z)
    vertices.append(p)
    var dx:=field.height(p.x+.5,p.z)-field.height(p.x-.5,p.z);var dz:=field.height(p.x,p.z+.5)-field.height(p.x,p.z-.5)
    normals.append(Vector3(-dx,1,-dz).normalized())
  for z in count:
   for x in count:
    var a:=x+z*(count+1);var b:=a+count+1;indices.append_array(PackedInt32Array([a,a+1,b,a+1,b+1,b]))
  mesh.mesh=FrontierTerrainMesher.mesh({"vertices":vertices,"normals":normals,"indices":indices})
  camera.look_at_from_position(Vector3(center.x+370,240,center.y+440),Vector3(center.x,5,center.y))
  reports[id]={"mode":field.landscape.mode,"heightfield_build_ms":(Time.get_ticks_usec()-start)/1000.0,"center":center,"vertices":vertices.size()}
  for i in 12:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(folder+"/"+id+".png")
 FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
 print("LANDFORM_RENDER ",reports.size()," production height fields; fixed gray INK lighting")
 quit()
