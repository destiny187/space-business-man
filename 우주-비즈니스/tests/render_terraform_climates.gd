extends SceneTree
## Prepared climate/material review, not a simulated full-planet restoration.
var folder:="res://../docs/production/media/terraform-surfaces/climates"
func _initialize() -> void:run.call_deferred()
func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 root.size=Vector2i(1200,800);root.msaa_3d=Viewport.MSAA_4X
 var scene:=Node3D.new();root.add_child(scene)
 var env:=WorldEnvironment.new();env.environment=Environment.new();scene.add_child(env)
 env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("47565e")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("c0cdda");env.environment.ambient_light_energy=.55
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-35,0);sun.light_energy=1.3;sun.shadow_enabled=true;scene.add_child(sun)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.look_at_from_position(Vector3(18,22,35),Vector3(0,0,-3))
 var mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(70,70);plane.subdivide_width=32;plane.subdivide_depth=32;mesh.mesh=plane;scene.add_child(mesh)
 FrontierInkStyle.attach(scene)
 var report: Dictionary={"scope":"Prepared climate states on one material review plane; actual surface binding and free-cell atlas, Forward+ INK. No gameplay duration or whole-planet completion claim.","states":{}}
 for family in ["volcanic","frozen"]:
  var native: Dictionary={"temperature":220.0 if family=="volcanic" else -50.0,"pressure":1.0,"water":0.0 if family=="volcanic" else 70.0,"oxygen":.21,"toxicity":0.0,"ecology":0.0}
  var restoration: Dictionary={"soil":10.0,"salinity":35.0}
  var body: Dictionary={"id":"review:"+family,"seed":17,"kind":"molten" if family=="volcanic" else "glacial","traits":native.duplicate()};body.traits.id=family
  var mat:=ShaderMaterial.new();mat.shader=load("res://assets/materials/space/terrain.gdshader")
  mat.set_shader_parameter("rock_color",Color("493c3b") if family=="volcanic" else Color("6c858d"));mat.set_shader_parameter("molten",family=="volcanic")
  FrontierSurfaceMaterialLibrary.configure(mat,body);mesh.material_override=mat
  var site: Dictionary={"free_terraform":{"base":native,"restoration":restoration,"revision":0,"rules":{"cell_size":12,"extent":8192},"cells":{}}}
  for stage in 3:
   var current: Dictionary=native.duplicate();var amended: Dictionary=restoration.duplicate()
   if stage==1:
    current.temperature=140.0 if family=="volcanic" else 3.0;current.water=20.0 if family=="volcanic" else 70.0;amended.soil=40.0;amended.salinity=25.0
   elif stage==2:
    current.temperature=18.0;current.water=75.0;current.ecology=82.0;amended.soil=90.0;amended.salinity=8.0
   var values:=current.duplicate();values.merge(amended,true)
   var state:=FrontierSurfaceRecovery.conditions(values)
   assert(float(state.life)==0.0 if stage<2 else float(state.life)>.8)
   for x in range(-3,3):
    for z in range(-3,3):
     var p:=Vector2((x+.5)*12,(z+.5)*12)
     # Leave an untreated rim and an intermediate ring to inspect continuous boundaries.
     var weight:=1.0-smoothstep(15.0,33.0,p.length())
     var e:=native.duplicate();var r:=restoration.duplicate()
     for key in current:e[key]=lerpf(float(native[key]),float(current[key]),weight)
     for key in amended:r[key]=lerpf(float(restoration[key]),float(amended[key]),weight)
     site.free_terraform.cells["%d:%d"%[x,z]]={"position":[p.x,0,p.y],"environment":e,"restoration2":r,"pollution":0.0}
   site.free_terraform.revision=stage
   FrontierSurfaceRecovery.shader_regions(mat,body,{"sites":{body.id:site}})
   for frame in 20:await process_frame
   await RenderingServer.frame_post_draw
   var id:="%s-%d"%[family,stage]
   root.get_texture().get_image().save_png(folder+"/"+id+".png")
   report.states[id]={"environment":current,"restoration":amended,"life":state.life}
 FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("TERRAFORM_CLIMATES 6 native/conditioning/restored renders; unsuitable cold/hot life remains zero")
 quit()
